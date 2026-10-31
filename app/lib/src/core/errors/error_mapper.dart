import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException, AuthSessionMissingException, FunctionException, FunctionsFetchException, PostgrestException, StorageException;

import 'app_error.dart';
import 'error_log.dart';

/// Messages des contraintes d'unicité (nom de la contrainte ou de l'index → message).
const Map<String, String> _constraintMessages = {
  'accounts_entity_id_code_key': 'Ce numéro de compte existe déjà dans ce plan.',
  'assignments_unique_scope': 'Cette affectation existe déjà.',
  'entities_tax_id_unique': 'Cet IFU existe déjà dans le cabinet.',
  'entities_trade_register_unique': 'Ce RCCM existe déjà dans le cabinet.',
  'entries_number_unique': 'Ce numéro d\'écriture vient d\'être attribué : relancez la validation.',
  'entry_templates_unique': 'Ce code de modèle existe déjà.',
  'fiscal_years_entity_id_start_date_key': 'Un exercice commence déjà à cette date pour ce dossier.',
  'fixed_assets_entity_id_code_key': 'Ce code d\'immobilisation existe déjà.',
  'journals_entity_id_code_key': 'Ce code de journal existe déjà.',
  'journals_one_opening': 'Un journal des à-nouveaux existe déjà pour ce dossier.',
  'journal_templates_cabinet_id_code_key': 'Ce code de journal existe déjà dans le modèle du cabinet.',
  'letterings_account_id_third_party_id_code_key': 'Ce code de lettrage existe déjà.',
  'profiles_cabinet_id_email_key': 'Cette adresse e-mail est déjà utilisée dans le cabinet.',
  'roles_cabinet_id_code_key': 'Ce code de rôle existe déjà.',
  'third_parties_entity_id_code_key': 'Ce code tiers existe déjà dans ce dossier.',
};

/// Marqueurs d'un message natif de PostgreSQL ou de PostgREST (en anglais, avec des noms de tables ou de contraintes) :
/// jamais affiché. Les règles comptables de la base, elles, sont rédigées en français et passent telles quelles.
final RegExp _technical = RegExp(
  r'violates|constraint|relation "|column "|row-level security|permission denied|does not exist|duplicate key|null value|invalid input|'
  r'syntax error|could not|cannot |deadlock|operator does not|function [a-z_.]+\(|unrecognized|out of range|value too long|schema "|role "|'
  r'type "|current transaction|canceling statement|JSON object|PGRST|SQLSTATE|Exception|Error:|ClientException|SocketException',
  caseSensitive: false,
);

final RegExp _network = RegExp(
  r'SocketException|ClientException|Failed host lookup|Connection (refused|closed|reset|terminated)|XMLHttpRequest|Failed to fetch|'
  r'Network is unreachable|HandshakeException|TlsException|WebSocketChannelException|Software caused connection abort',
  caseSensitive: false,
);

class _Mapped {
  const _Mapped(this.kind, this.message, {this.retryable = false});
  final AppErrorKind kind;
  final String message;
  final bool retryable;
}

const _sessionExpired = _Mapped(AppErrorKind.session, 'Votre session a expiré. Reconnectez-vous pour continuer.');
const _offline = _Mapped(AppErrorKind.network, 'Connexion impossible. Vérifiez votre réseau, puis réessayez.', retryable: true);
const _unavailable = _Mapped(AppErrorKind.unavailable, 'Le service est momentanément indisponible. Réessayez dans un instant.', retryable: true);
const _unexpected = _Mapped(AppErrorKind.unknown, 'Une erreur inattendue s\'est produite. Si elle persiste, communiquez la référence à l\'assistance.', retryable: true);

/// Transforme n'importe quelle exception en erreur présentable. Le détail technique est consigné dans le journal ; il n'est jamais renvoyé dans le message.
AppError humanizeError(Object error, [StackTrace? stack]) {
  if (error is AppError) return error;
  final mapped = _classify(error);
  final reference = ErrorLog.instance.nextReference();
  final technical = _describe(error);
  final app = AppError(kind: mapped.kind, message: mapped.message, retryable: mapped.retryable, reference: reference, technical: technical);
  if (mapped.kind != AppErrorKind.businessRule) {
    ErrorLog.instance.record(ErrorLogEntry(reference: reference, time: DateTime.now(), kind: mapped.kind, message: mapped.message, technical: technical, stackTrace: stack?.toString()));
  }
  return app;
}

/// Texte à afficher pour une erreur, précédé s'il y a lieu de l'action tentée (« Invitation impossible : … »).
String errorText(Object error, {String? action}) {
  final text = humanizeError(error).display;
  return action == null ? text : '$action : $text';
}

_Mapped _classify(Object e) {
  if (e is PostgrestException) return _fromPostgrest(e);
  if (e is AuthException) return _fromAuth(e);
  if (e is FunctionException) return _fromFunction(e);
  if (e is StorageException) return _fromStorage(e);
  if (e is TimeoutException) return const _Mapped(AppErrorKind.timeout, 'Le serveur met trop de temps à répondre. Réessayez.', retryable: true);
  if (e is FormatException) return const _Mapped(AppErrorKind.invalidInput, 'Une valeur n\'a pas le bon format.');
  if (_network.hasMatch(e.toString())) return _offline;
  return _unexpected;
}

String? _constraintName(String message) => RegExp(r'constraint "([^"]+)"').firstMatch(message)?.group(1) ?? RegExp(r'unique constraint "?([a-z0-9_]+)"?', caseSensitive: false).firstMatch(message)?.group(1);

_Mapped _fromPostgrest(PostgrestException e) {
  final code = e.code ?? '';
  final message = e.message.trim();
  final native = _technical.hasMatch(message);

  if (code == 'PGRST301' || code == 'PGRST303' || RegExp(r'JWT', caseSensitive: false).hasMatch(message)) return _sessionExpired;
  if (code == 'PGRST116') return const _Mapped(AppErrorKind.notFound, 'Élément introuvable, ou vous n\'y avez pas accès.');
  if (code.startsWith('PGRST') || code == '42883' || code == '42P01' || code == '42703') {
    return const _Mapped(AppErrorKind.server, 'Cette fonction est momentanément indisponible. Réessayez plus tard.');
  }
  if (code == '57014') return const _Mapped(AppErrorKind.timeout, 'L\'opération a pris trop de temps. Réessayez.', retryable: true);
  if (code == '40001' || code == '40P01') return const _Mapped(AppErrorKind.unavailable, 'Une autre opération est en cours sur ces données. Réessayez dans un instant.', retryable: true);
  if (code.startsWith('08') || code == '53300' || code == '57P03') return _unavailable;

  if (!native && message.isNotEmpty && (code.isEmpty || RegExp(r'^(23|42501|P0|22023)').hasMatch(code))) {
    return _Mapped(AppErrorKind.businessRule, _sentence(message)); // règle comptable rédigée en français dans la base
  }

  switch (code) {
    case '23505':
      final named = _constraintMessages[_constraintName(message)];
      return _Mapped(AppErrorKind.duplicate, named ?? 'Cet enregistrement existe déjà.');
    case '23503':
      final deleting = message.contains('update or delete');
      return _Mapped(AppErrorKind.businessRule, deleting ? 'Suppression impossible : cet élément est utilisé ailleurs.' : 'L\'élément choisi n\'existe plus ou n\'est pas disponible.');
    case '23502':
      return const _Mapped(AppErrorKind.invalidInput, 'Un champ obligatoire n\'est pas renseigné.');
    case '23514':
      return const _Mapped(AppErrorKind.invalidInput, 'La valeur saisie n\'est pas acceptée.');
    case '42501':
      return const _Mapped(AppErrorKind.forbidden, 'Vous n\'avez pas les droits nécessaires pour cette action sur ce dossier.');
    case '22001':
      return const _Mapped(AppErrorKind.invalidInput, 'Un texte saisi est trop long.');
    case '22P02' || '22003' || '22007' || '22008' || '22023':
      return const _Mapped(AppErrorKind.invalidInput, 'Une valeur saisie n\'est pas valide.');
  }
  return const _Mapped(AppErrorKind.server, 'Le serveur n\'a pas pu traiter la demande. Si le problème persiste, communiquez la référence à l\'assistance.', retryable: true);
}

_Mapped _fromAuth(AuthException e) {
  // Le message (anglais) et le code d'erreur de GoTrue (« invalid_credentials »…) servent tous deux à reconnaître le cas.
  final m = '${e.message} ${e.code ?? ''}'.toLowerCase();
  final status = e.statusCode ?? '';
  bool any(List<String> words) => words.any(m.contains);
  if (e is AuthRetryableFetchException) return _offline;
  if (any(['invalid login credentials', 'invalid_credentials'])) return const _Mapped(AppErrorKind.forbidden, 'E-mail ou mot de passe incorrect.');
  if (any(['too many requests', 'rate limit', 'rate_limit']) || status == '429') {
    return const _Mapped(AppErrorKind.forbidden, 'Trop de tentatives : patientez quelques minutes avant de réessayer.');
  }
  if (any(['email not confirmed', 'email_not_confirmed'])) return const _Mapped(AppErrorKind.forbidden, 'Adresse e-mail non confirmée : utilisez le lien reçu par e-mail.');
  if (any(['already registered', 'already been registered', 'user_already_exists', 'email_exists'])) {
    return const _Mapped(AppErrorKind.duplicate, 'Un compte existe déjà avec cette adresse e-mail.');
  }
  if (any(['totp', 'otp', 'mfa_verification_failed']) || (m.contains('code') && (m.contains('invalid') || m.contains('expired')))) {
    return const _Mapped(AppErrorKind.invalidInput, 'Le code saisi est invalide ou expiré. Vérifiez l\'heure de votre téléphone et réessayez.');
  }
  if (any(['aal2', 'insufficient_aal', 'mfa'])) return const _Mapped(AppErrorKind.session, 'Une vérification en deux étapes est requise pour continuer.');
  if (any(['weak_password']) || (m.contains('password') && any(['weak', 'at least', 'characters']))) {
    return const _Mapped(AppErrorKind.invalidInput, 'Le mot de passe est trop court ou trop simple.');
  }
  if (any(['same password', 'same_password', 'different from the old'])) return const _Mapped(AppErrorKind.invalidInput, 'Le nouveau mot de passe doit être différent de l\'ancien.');
  if (e is AuthSessionMissingException || any(['jwt', 'session', 'refresh_token', 'refresh token', 'not authenticated', 'no_authorization']) || status == '401') {
    return _sessionExpired;
  }
  return const _Mapped(AppErrorKind.unknown, 'L\'authentification a échoué. Réessayez ; si le problème persiste, communiquez la référence à l\'assistance.', retryable: true);
}

_Mapped _fromFunction(FunctionException e) {
  if (e is FunctionsFetchException) return _offline;
  final status = e.status;
  if (status == 401) return _sessionExpired;
  if (status == 502 || status == 503 || status == 504) return _unavailable;
  if (status >= 500) return const _Mapped(AppErrorKind.server, 'Le service n\'a pas pu traiter la demande. Si le problème persiste, communiquez la référence à l\'assistance.', retryable: true);
  final detail = _functionMessage(e.details);
  if (detail != null && !_technical.hasMatch(detail) && !detail.startsWith('Service de documents')) {
    return _Mapped(status == 403 ? AppErrorKind.forbidden : (status == 404 ? AppErrorKind.notFound : AppErrorKind.businessRule), _sentence(detail));
  }
  return switch (status) {
    403 => const _Mapped(AppErrorKind.forbidden, 'Vous n\'avez pas les droits nécessaires pour cette action.'),
    404 => const _Mapped(AppErrorKind.notFound, 'Élément introuvable.'),
    413 => const _Mapped(AppErrorKind.invalidInput, 'Le document est trop volumineux pour être traité.'),
    _ => const _Mapped(AppErrorKind.invalidInput, 'La demande n\'a pas pu être traitée. Vérifiez les informations saisies.'),
  };
}

String? _functionMessage(Object? details) {
  if (details is Map && details['error'] is String) return (details['error'] as String).trim();
  if (details is String && details.trim().isNotEmpty && !details.trim().startsWith('{')) return details.trim();
  return null;
}

_Mapped _fromStorage(StorageException e) {
  final status = e.statusCode ?? '';
  if (status == '401') return _sessionExpired;
  if (status == '403') return const _Mapped(AppErrorKind.forbidden, 'Vous n\'avez pas le droit d\'accéder à ce fichier.');
  if (status == '404') return const _Mapped(AppErrorKind.notFound, 'Fichier introuvable.');
  if (status == '413') return const _Mapped(AppErrorKind.invalidInput, 'Le fichier est trop volumineux.');
  if (status == '415' || status == '400') return const _Mapped(AppErrorKind.invalidInput, 'Ce type de fichier n\'est pas accepté.');
  if (_network.hasMatch(e.message)) return _offline;
  return const _Mapped(AppErrorKind.server, 'Le fichier n\'a pas pu être traité. Réessayez ; si le problème persiste, communiquez la référence à l\'assistance.', retryable: true);
}

/// Première lettre en majuscule et point final, sans toucher au reste d'un message déjà rédigé.
String _sentence(String s) {
  var t = s.trim();
  if (t.isEmpty) return t;
  t = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?…]$').hasMatch(t) ? t : '$t.';
}

String _describe(Object e) {
  if (e is PostgrestException) return 'PostgrestException(code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint})';
  if (e is AuthException) return '${e.runtimeType}(status: ${e.statusCode}, message: ${e.message})';
  if (e is FunctionException) return '${e.runtimeType}(status: ${e.status}, details: ${e.details}, reason: ${e.reasonPhrase})';
  if (e is StorageException) return 'StorageException(status: ${e.statusCode}, error: ${e.error}, message: ${e.message})';
  return '${e.runtimeType}: $e';
}
