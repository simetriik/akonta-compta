/// Taille de page alignée sur le plafond `max_rows` de PostgREST (1 000 par défaut) : une page plus grande serait tronquée en silence.
const supabasePageSize = 1000;

/// Lit toutes les lignes d'une requête par pages successives.
///
/// [fetch] reçoit les bornes `from` et `to` (incluses, comme `range` de PostgREST) et renvoie la page.
/// La lecture s'arrête dès qu'une page est plus courte que [pageSize] : un plafond serveur à 1 000 lignes
/// ne coupe donc plus un plan de comptes de 1 288 comptes.
Future<List<T>> fetchAllPages<T>(Future<List<T>> Function(int from, int to) fetch, {int pageSize = supabasePageSize}) async {
  final all = <T>[];
  var from = 0;
  while (true) {
    final page = await fetch(from, from + pageSize - 1);
    all.addAll(page);
    if (page.length < pageSize) return all;
    from += pageSize;
  }
}
