/// Erreur présentable à l'utilisateur : un message en français sans jargon, jamais le détail de la base de données.
library;

/// Nature d'une erreur : détermine l'icône éventuelle, la possibilité de réessayer et l'affichage de la référence.
enum AppErrorKind {
  network,

  /// Fonction qui exige une connexion alors que l'appareil est hors ligne.
  offline,
  timeout,
  session,
  forbidden,
  notFound,
  duplicate,
  invalidInput,

  /// Règle métier refusée par la base (équilibre, période verrouillée, permission…) : le message est celui de la règle.
  businessRule,
  unavailable,
  server,
  unknown,
}

class AppError implements Exception {
  const AppError({required this.kind, required this.message, this.retryable = false, this.reference, this.technical = ''});

  /// Refus d'une règle métier ou message rédigé par l'application : affiché tel quel, sans référence.
  const AppError.business(String message) : this(kind: AppErrorKind.businessRule, message: message);

  /// Fonction réservée à l'utilisation en ligne (grand livre, balance, validation…) tentée sans connexion.
  AppError.offline(String capability)
      : this(kind: AppErrorKind.offline, message: '$capability nécessite une connexion internet. Reconnectez-vous pour continuer.', retryable: true);

  final AppErrorKind kind;

  /// Message pour l'utilisateur (français, sans terme technique).
  final String message;

  /// Une nouvelle tentative a une chance d'aboutir (réseau, délai dépassé, service indisponible).
  final bool retryable;

  /// Référence courte retrouvable dans le journal technique (administrateur technique).
  final String? reference;

  /// Détail pour l'ingénieur : jamais affiché à l'écran, consigné dans le journal technique.
  final String technical;

  /// Seules les erreurs inattendues portent leur référence à l'écran : l'utilisateur la transmet à l'assistance.
  bool get showsReference => reference != null && (kind == AppErrorKind.server || kind == AppErrorKind.unknown || kind == AppErrorKind.unavailable);

  String get display => showsReference ? '$message (réf. $reference)' : message;

  /// Évite qu'une interpolation accidentelle (`'$e'`) laisse échapper le détail technique.
  @override
  String toString() => display;
}
