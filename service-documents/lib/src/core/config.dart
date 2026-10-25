/// Configuration de l'application, injectée à la compilation :
/// `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
/// Les valeurs par défaut visent la pile Supabase locale (`scripts/start.sh`).
/// La clé de service n'est jamais embarquée (conception §11.3).
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// Longueur minimale du mot de passe (conception §10.1).
  static const minPasswordLength = 12;

  /// Déconnexion après inactivité si le cabinet n'a rien paramétré.
  static const defaultInactivityMinutes = 30;
}
