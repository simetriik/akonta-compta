/// Configuration de l'application, injectée à la compilation :
/// `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…`.
/// Les valeurs par défaut visent la pile Supabase locale (`scripts/start.sh`).
/// La clé de service n'est jamais embarquée (conception §11.3).
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  /// Clé publiable (anciennement anon) : publique par construction, les droits viennent de la RLS.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  /// Longueur minimale du mot de passe (conception §10.1).
  static const minPasswordLength = 12;

  /// Déconnexion après inactivité si le cabinet n'a rien paramétré.
  static const defaultInactivityMinutes = 30;
}
