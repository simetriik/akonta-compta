/// Contrôle de cohérence du compte de stock choisi pour l'inventaire (AN-19).
class StockHint {
  const StockHint._();

  /// Avertissement quand le compte n'a pas de stock initial alors qu'un autre compte de stock de la même classe en porte un :
  /// le stock final a probablement été saisi sur le mauvais compte. `null` si tout est cohérent.
  /// [opening] : stock initial par code de compte de stock.
  static String? wrongAccount(String accountCode, Map<String, int> opening) {
    if ((opening[accountCode] ?? 0) != 0) return null;
    final others = opening.entries.where((e) => e.key != accountCode && e.value != 0).map((e) => e.key).toList()..sort();
    if (others.isEmpty) return null;
    return 'Ce compte n\'a pas de stock initial, mais ${others.join(', ')} en porte un : '
        'vérifiez que le stock final est saisi sur le bon compte, sinon la variation sera faussée.';
  }

  /// Préfixe du compte de variation qui correspond à un compte de stock : 311 → 6031 (marchandises), 321 → 6032, 331 → 6033 ;
  /// sinon 73 (variation de production). Évite de proposer le compte de regroupement 603 (AN-37).
  static String variationPrefix(String stockCode) {
    if (stockCode.startsWith('31')) return '6031';
    if (stockCode.startsWith('32')) return '6032';
    if (stockCode.startsWith('33')) return '6033';
    return '73';
  }

  /// Avertissement quand le compte de variation choisi est un compte de regroupement (il a des comptes plus précis dans le plan,
  /// ex. 6030000 et 6031000) : l'état n'y reprend pas la variation. `null` si le compte est précis. [allCodes] : codes du plan.
  static String? groupingVariation(String variationCode, Iterable<String> allCodes) {
    final base = variationCode.replaceFirst(RegExp(r'0+$'), '');
    if (base.isEmpty) return null;
    final children = allCodes.where((c) => c != variationCode && c.startsWith(base)).toList()..sort();
    if (children.isEmpty) return null;
    return '$variationCode est un compte de regroupement : la variation n\'apparaîtrait pas au compte de résultat. '
        'Choisissez un compte précis (${children.take(3).join(', ')}).';
  }
}
