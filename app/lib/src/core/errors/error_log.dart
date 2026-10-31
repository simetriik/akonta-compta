import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'app_error.dart';

/// Une erreur consignée pour l'ingénieur : le détail technique complet, rattaché à la référence montrée à l'utilisateur.
class ErrorLogEntry {
  const ErrorLogEntry({required this.reference, required this.time, required this.kind, required this.message, required this.technical, this.stackTrace});

  final String reference;
  final DateTime time;
  final AppErrorKind kind;
  final String message;
  final String technical;
  final String? stackTrace;

  String get text => '[$reference] ${time.toIso8601String()} ${kind.name}\nMessage affiché : $message\n$technical${stackTrace == null ? '' : '\n$stackTrace'}';
}

/// Journal technique local à l'appareil : conserve les dernières erreurs en mémoire et les écrit dans la console.
/// Rien n'est envoyé à un service externe.
class ErrorLog extends ChangeNotifier {
  ErrorLog._();

  static final ErrorLog instance = ErrorLog._();
  static const capacity = 50;

  final List<ErrorLogEntry> _entries = [];
  int _sequence = 0;

  /// Les plus récentes d'abord.
  List<ErrorLogEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Référence courte et lisible à la voix : « AK-3F9K ».
  String nextReference() {
    _sequence++;
    final n = (DateTime.now().millisecondsSinceEpoch ~/ 7 + _sequence * 7919) % (36 * 36 * 36 * 36);
    return 'AK-${n.toRadixString(36).toUpperCase().padLeft(4, '0')}';
  }

  void record(ErrorLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > capacity) _entries.removeAt(0);
    developer.log(entry.text, name: 'akonta.erreur', level: 1000);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Tout le journal en texte, pour le copier vers l'ingénieur.
  String export() => _entries.reversed.map((e) => e.text).join('\n\n---\n\n');
}
