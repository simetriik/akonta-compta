import 'dart:async';

import 'app_error.dart';
import 'error_log.dart';

/// Résultat du classement d'une exception : nature, message pour l'utilisateur, nouvelle tentative possible.
class ClassifiedError {
  const ClassifiedError(this.kind, this.message, {this.retryable = false});

  final AppErrorKind kind;
  final String message;
  final bool retryable;
}

/// Classeur propre à un fournisseur de données (Supabase, serveur d'API…) : renvoie null s'il ne reconnaît pas l'exception.
typedef ErrorClassifier = ClassifiedError? Function(Object error);

/// Description technique propre à un fournisseur, pour le journal des erreurs ; null si l'exception n'est pas la sienne.
typedef ErrorDescriber = String? Function(Object error);

/// Marqueurs d'un message natif d'un moteur de base de données (en anglais, avec des noms de tables ou de contraintes) :
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

bool looksTechnical(String message) => _technical.hasMatch(message);

bool looksLikeNetworkFailure(String message) => _network.hasMatch(message);

/// Première lettre en majuscule et point final, sans toucher au reste d'un message déjà rédigé.
String sentenceCase(String s) {
  var t = s.trim();
  if (t.isEmpty) return t;
  t = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?…]$').hasMatch(t) ? t : '$t.';
}

/// Classeurs et descripteurs enregistrés par la composition.
abstract final class ErrorClassifiers {
  static final List<ErrorClassifier> _classifiers = [];
  static final List<ErrorDescriber> _describers = [];

  static void register({required ErrorClassifier classifier, ErrorDescriber? describer}) {
    _classifiers.add(classifier);
    if (describer != null) _describers.add(describer);
  }

  /// Retire les classeurs enregistrés (tests).
  static void reset() {
    _classifiers.clear();
    _describers.clear();
  }
}

const _unexpected = ClassifiedError(AppErrorKind.unknown, 'Une erreur inattendue s\'est produite. Si elle persiste, communiquez la référence à l\'assistance.', retryable: true);
const _offline = ClassifiedError(AppErrorKind.network, 'Connexion impossible. Vérifiez votre réseau, puis réessayez.', retryable: true);

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

/// Vrai si l'exception vient d'un défaut de connexion (réseau, délai, service injoignable, fonction hors ligne) : l'action peut être
/// remise à plus tard. Ne journalise rien.
bool isConnectivityFailure(Object error) {
  if (error is AppError) return error.kind == AppErrorKind.network || error.kind == AppErrorKind.offline || error.kind == AppErrorKind.timeout || error.kind == AppErrorKind.unavailable;
  final kind = _classify(error).kind;
  return kind == AppErrorKind.network || kind == AppErrorKind.offline || kind == AppErrorKind.timeout || kind == AppErrorKind.unavailable;
}

/// Texte à afficher pour une erreur, précédé s'il y a lieu de l'action tentée (« Invitation impossible : … »).
String errorText(Object error, {String? action}) {
  final text = humanizeError(error).display;
  return action == null ? text : '$action : $text';
}

ClassifiedError _classify(Object e) {
  for (final classify in ErrorClassifiers._classifiers) {
    final result = classify(e);
    if (result != null) return result;
  }
  if (e is TimeoutException) return const ClassifiedError(AppErrorKind.timeout, 'Le serveur met trop de temps à répondre. Réessayez.', retryable: true);
  if (e is FormatException) return const ClassifiedError(AppErrorKind.invalidInput, 'Une valeur n\'a pas le bon format.');
  if (_network.hasMatch(e.toString())) return _offline;
  return _unexpected;
}

String _describe(Object e) {
  for (final describe in ErrorClassifiers._describers) {
    final text = describe(e);
    if (text != null) return text;
  }
  return '${e.runtimeType}: $e';
}
