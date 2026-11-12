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
}
