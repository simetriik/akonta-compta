/// Type de tiers déduit du compte collectif de rattachement (AN-05).
class ThirdPartyType {
  const ThirdPartyType._();

  /// 40x fournisseurs, 41x clients, 42x personnel ; `null` pour un autre collectif (le type reste au choix de l'utilisateur).
  static String? forCollective(String accountCode) {
    if (accountCode.startsWith('40')) return 'supplier';
    if (accountCode.startsWith('41')) return 'customer';
    if (accountCode.startsWith('42')) return 'employee';
    return null;
  }
}
