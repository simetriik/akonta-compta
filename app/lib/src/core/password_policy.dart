import 'config.dart';

/// Règle de mot de passe, identique à celle de la configuration Auth (12 caractères, minuscule, majuscule, chiffre).
abstract final class PasswordPolicy {
  /// Message d'erreur en français, ou null si le mot de passe convient.
  static String? validate(String? value) {
    final s = value ?? '';
    if (s.isEmpty) return 'Mot de passe requis';
    if (s.length < AppConfig.minPasswordLength) return 'Au moins ${AppConfig.minPasswordLength} caractères';
    if (!RegExp(r'[a-z]').hasMatch(s) || !RegExp(r'[A-Z]').hasMatch(s) || !RegExp(r'[0-9]').hasMatch(s)) {
      return 'Il faut une minuscule, une majuscule et un chiffre';
    }
    return null;
  }

  /// Confirmation : identique à la saisie.
  static String? validateConfirmation(String? value, String original) => value == original ? null : 'Les deux saisies sont différentes';
}
