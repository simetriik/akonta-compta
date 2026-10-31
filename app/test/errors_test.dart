import 'dart:async';
import 'dart:io';

import 'package:akonta/src/core/errors/errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException, FunctionException, FunctionsFetchException, PostgrestException, StorageException;

/// Mots qui ne doivent jamais apparaître à l'écran : le vocabulaire de la base de données et de ses erreurs.
final _leaks = RegExp(r'postgres|constraint|relation|policy|violates|column|PGRST|SQLSTATE|exception|row-level|duplicate key|null value|public\.', caseSensitive: false);

AppError h(Object e, [StackTrace? stack]) => humanizeError(e, stack);

void main() {
  setUp(ErrorLog.instance.clear);

  group('règles métier de la base', () {
    test('un message français de la base passe tel quel, avec un point final', () {
      final e = h(const PostgrestException(message: 'Écriture déséquilibrée : 100', code: '23514'));
      expect(e.kind, AppErrorKind.businessRule);
      expect(e.message, 'Écriture déséquilibrée : 100.');
      expect(e.showsReference, isFalse);
    });

    test('une permission refusée rédigée par la base reste lisible', () {
      final e = h(const PostgrestException(message: 'Permission refusée : générer les états financiers', code: '42501'));
      expect(e.kind, AppErrorKind.businessRule);
      expect(e.message, startsWith('Permission refusée'));
    });
  });

  group('erreurs natives de la base', () {
    test('sécurité de ligne : droits insuffisants, sans nom de table', () {
      final e = h(const PostgrestException(message: 'new row violates row-level security policy for table "entities"', code: '42501'));
      expect(e.kind, AppErrorKind.forbidden);
      expect(e.message, 'Vous n\'avez pas les droits nécessaires pour cette action sur ce dossier.');
    });

    test('doublon : message propre à la contrainte connue', () {
      final e = h(const PostgrestException(message: 'duplicate key value violates unique constraint "entities_tax_id_unique"', code: '23505'));
      expect(e.kind, AppErrorKind.duplicate);
      expect(e.message, 'Cet IFU existe déjà dans le cabinet.');
    });

    test('doublon : message général pour une contrainte inconnue', () {
      final e = h(const PostgrestException(message: 'duplicate key value violates unique constraint "x_y_key"', code: '23505'));
      expect(e.message, 'Cet enregistrement existe déjà.');
    });

    test('suppression d\'un élément utilisé ailleurs', () {
      final e = h(const PostgrestException(message: 'update or delete on table "accounts" violates foreign key constraint "entry_lines_account_id_fkey" on table "entry_lines"', code: '23503'));
      expect(e.message, 'Suppression impossible : cet élément est utilisé ailleurs.');
    });

    test('champ obligatoire, valeur invalide, texte trop long', () {
      expect(h(const PostgrestException(message: 'null value in column "name" of relation "entities" violates not-null constraint', code: '23502')).message, 'Un champ obligatoire n\'est pas renseigné.');
      expect(h(const PostgrestException(message: 'invalid input syntax for type uuid: "x"', code: '22P02')).message, 'Une valeur saisie n\'est pas valide.');
      expect(h(const PostgrestException(message: 'value too long for type character varying(200)', code: '22001')).message, 'Un texte saisi est trop long.');
    });

    test('session expirée et élément introuvable', () {
      expect(h(const PostgrestException(message: 'JWT expired', code: 'PGRST301')).kind, AppErrorKind.session);
      expect(h(const PostgrestException(message: 'JSON object requested, multiple (or no) rows returned', code: 'PGRST116')).kind, AppErrorKind.notFound);
    });

    test('erreur inattendue : message général avec référence, détail dans le journal', () {
      final e = h(const PostgrestException(message: 'relation "public.secret_table" does not exist', code: 'XX000'), StackTrace.current);
      expect(e.kind, AppErrorKind.server);
      expect(e.showsReference, isTrue);
      expect(e.display, matches(RegExp(r'\(réf\. AK-[0-9A-Z]{4}\)$')));
      expect(e.technical, contains('secret_table'));
      expect(e.display, isNot(contains('secret_table')));
      expect(ErrorLog.instance.entries.single.reference, e.reference);
      expect(ErrorLog.instance.entries.single.technical, contains('XX000'));
    });
  });

  group('réseau, délais et authentification', () {
    test('réseau : message de reconnexion, nouvelle tentative possible', () {
      for (final e in [const SocketException('Failed host lookup'), Exception('ClientException: Failed to fetch, uri=https://x'), AuthRetryableFetchException(), const FunctionsFetchException()]) {
        final app = h(e);
        expect(app.kind, AppErrorKind.network, reason: '$e');
        expect(app.retryable, isTrue);
      }
    });

    test('délai dépassé', () {
      final e = h(TimeoutException('x'));
      expect(e.kind, AppErrorKind.timeout);
      expect(e.retryable, isTrue);
    });

    test('connexion : identifiants, trop de tentatives, code TOTP, mot de passe faible', () {
      expect(h(const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials')).message, 'E-mail ou mot de passe incorrect.');
      expect(h(const AuthException('Request rate limit reached', statusCode: '429')).message, startsWith('Trop de tentatives'));
      expect(h(const AuthException('Invalid TOTP code entered', code: 'mfa_verification_failed')).message, startsWith('Le code saisi est invalide'));
      expect(h(const AuthException('Password should be at least 12 characters', code: 'weak_password')).message, 'Le mot de passe est trop court ou trop simple.');
      expect(h(const AuthException('JWT expired', statusCode: '401')).kind, AppErrorKind.session);
    });
  });

  group('fonctions serveur et stockage', () {
    test('service indisponible', () {
      expect(h(const FunctionException(status: 502, details: 'Service de documents : 502 upstream')).kind, AppErrorKind.unavailable);
    });

    test('un message rédigé par la fonction passe, sauf s\'il vient d\'un service amont', () {
      expect(h(const FunctionException(status: 404, details: {'error': 'Aucun état financier généré pour cet exercice'})).message, 'Aucun état financier généré pour cet exercice.');
      expect(h(const FunctionException(status: 400, details: {'error': 'Service de documents : 502 boom'})).message, isNot(contains('boom')));
    });

    test('erreur serveur de la fonction : référence, pas de détail', () {
      final e = h(const FunctionException(status: 500, details: 'TypeError: cannot read properties of undefined'));
      expect(e.kind, AppErrorKind.server);
      expect(e.display, isNot(contains('undefined')));
    });

    test('fichier trop volumineux ou refusé', () {
      expect(h(const StorageException('Payload too large', statusCode: '413')).message, 'Le fichier est trop volumineux.');
      expect(h(const StorageException('new row violates row-level security policy', statusCode: '403')).kind, AppErrorKind.forbidden);
    });
  });

  group('contrat du module', () {
    test('une erreur inconnue n\'expose ni son type ni son message', () {
      final e = h(StateError('Bad state: boom interne'));
      expect(e.kind, AppErrorKind.unknown);
      expect(e.display, isNot(contains('boom')));
      expect(e.display, isNot(contains('StateError')));
      expect(e.technical, contains('StateError'));
    });

    test('une AppError traverse sans changement et son toString ne révèle pas le détail', () {
      const app = AppError(kind: AppErrorKind.server, message: 'Message', reference: 'AK-0001', technical: 'secret');
      expect(identical(h(app), app), isTrue);
      expect('$app', 'Message (réf. AK-0001)');
      expect('$app', isNot(contains('secret')));
    });

    test('errorText ajoute l\'action tentée', () {
      expect(errorText(const AuthException('Invalid login credentials', code: 'invalid_credentials'), action: 'Connexion impossible'), 'Connexion impossible : E-mail ou mot de passe incorrect.');
    });

    test('aucun message affiché ne laisse échapper le vocabulaire de la base', () {
      final samples = <Object>[
        const PostgrestException(message: 'new row violates row-level security policy for table "entries"', code: '42501'),
        const PostgrestException(message: 'duplicate key value violates unique constraint "accounts_entity_id_code_key"', code: '23505'),
        const PostgrestException(message: 'null value in column "cabinet_id" of relation "entities" violates not-null constraint', code: '23502'),
        const PostgrestException(message: 'new row for relation "entities" violates check constraint "entities_accounting_system_check"', code: '23514'),
        const PostgrestException(message: 'insert or update on table "entries" violates foreign key constraint "entries_journal_id_fkey"', code: '23503'),
        const PostgrestException(message: 'column "foo" does not exist', code: '42703'),
        const PostgrestException(message: 'function public.nope(uuid) does not exist', code: '42883'),
        const PostgrestException(message: 'Could not find the function public.x in the schema cache', code: 'PGRST202'),
        const PostgrestException(message: 'permission denied for table profiles', code: '42501'),
        const PostgrestException(message: 'canceling statement due to statement timeout', code: '57014'),
        const PostgrestException(message: 'something odd', code: 'XX001', details: 'table accounts', hint: 'check postgres logs'),
        Exception('PostgrestException(message: boom, code: 500)'),
        StateError('relation "x" violates constraint'),
      ];
      for (final s in samples) {
        final shown = h(s).display;
        expect(shown, isNot(matches(_leaks)), reason: 'fuite dans « $shown » pour $s');
      }
    });
  });

  group('journal technique', () {
    test('références distinctes, capacité limitée, export complet', () {
      final refs = {for (var i = 0; i < 60; i++) h(StateError('e$i')).reference};
      expect(refs.length, 60);
      expect(ErrorLog.instance.entries.length, ErrorLog.capacity);
      expect(ErrorLog.instance.export(), contains('StateError'));
      expect(ErrorLog.instance.entries.first.technical, contains('e59'));
    });

    test('une règle métier n\'encombre pas le journal', () {
      h(const PostgrestException(message: 'Période verrouillée', code: '23514'));
      expect(ErrorLog.instance.entries, isEmpty);
    });
  });
}
