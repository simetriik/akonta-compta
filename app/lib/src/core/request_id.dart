import 'dart:math';

final _random = Random.secure();

/// Identifiant unique d'une demande de création (UUID v4) : le serveur s'en sert pour ne traiter qu'une fois
/// une demande reçue deux fois (double clic, nouvel essai après coupure réseau).
String newRequestId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
