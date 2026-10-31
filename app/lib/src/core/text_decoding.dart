import 'dart:convert';
import 'dart:typed_data';
/// Décode un export Perfecto (Windows-1252) en texte Unicode. Les 32 caractères 0x80-0x9F suivent la table 1252.
String decodeWindows1252(Uint8List bytes) {
  const high = [
    0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
    0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
  ];
  final buf = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80 || b >= 0xA0) {
      buf.writeCharCode(b);
    } else {
      buf.writeCharCode(high[b - 0x80]);
    }
  }
  return buf.toString();
}

/// Le fichier est-il de l'UTF-8 valide ? Sinon on suppose Windows-1252 (export Perfecto).
String decodePerfectoText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return decodeWindows1252(bytes);
  }
}
