import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Règles d'architecture (clean architecture) : le sens des dépendances est vérifié sur les imports de chaque fichier de `lib/src`.
///
///   presentation ─► application ─► domain ◄─ infrastructure
///        core : noyau partagé (erreurs, formats) ; composition : seul endroit qui relie ports et adaptateurs.
void main() {
  const allowedLayers = <String, Set<String>>{
    'core': {'core'},
    'domain': {'domain'},
    'application': {'application', 'domain', 'core'},
    'infrastructure': {'infrastructure', 'application', 'domain', 'core'},
    'composition': {'composition', 'infrastructure', 'application', 'domain', 'core'},
    'presentation': {'presentation', 'application', 'domain', 'core'},
  };

  // Paquets externes interdits par couche (préfixes d'URI d'import).
  const uiPackages = ['package:flutter/material.dart', 'package:flutter/widgets.dart', 'package:flutter/cupertino.dart', 'package:go_router/', 'package:akonta/design/'];
  const storagePackages = ['package:supabase_flutter/', 'package:drift/', 'package:sqlite3/', 'package:http/', 'package:flutter_secure_storage/', 'package:path_provider/'];
  final forbiddenExternal = <String, List<String>>{
    'core': [...uiPackages, ...storagePackages, 'dart:io'],
    'domain': [...uiPackages, ...storagePackages, 'dart:io', 'package:flutter_riverpod/', 'package:flutter/'],
    'application': [...uiPackages, ...storagePackages, 'dart:io'],
    'infrastructure': uiPackages,
    'presentation': storagePackages,
  };

  final root = Directory('lib/src');
  final files = [for (final f in root.listSync(recursive: true)) if (f is File && f.path.endsWith('.dart')) f];

  String layerOf(String path) {
    final rel = path.replaceAll('\\', '/').split('lib/src/').last;
    final first = rel.split('/').first;
    return rel == 'app.dart' ? 'presentation' : first;
  }

  final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

  List<String> imports(File f) => [for (final m in importRe.allMatches(f.readAsStringSync())) m.group(1)!];

  /// Couche d'un import vers un fichier du projet (null pour un paquet externe).
  String? projectLayer(File from, String uri) {
    if (uri.startsWith('dart:')) return null;
    if (uri.startsWith('package:akonta/src/')) return layerOf(uri.substring('package:akonta/src/'.length));
    if (uri.startsWith('package:')) return null;
    final resolved = File.fromUri(from.uri.resolve(uri)).path;
    return resolved.contains('lib/src/') ? layerOf(resolved) : null;
  }

  test('chaque couche ne dépend que des couches autorisées', () {
    final violations = <String>[];
    for (final f in files) {
      final layer = layerOf(f.path);
      final allowed = allowedLayers[layer];
      if (allowed == null) {
        violations.add('${f.path} : dossier « $layer » inconnu (couches : ${allowedLayers.keys.join(', ')})');
        continue;
      }
      for (final uri in imports(f)) {
        final target = projectLayer(f, uri);
        if (target != null && !allowed.contains(target)) violations.add('${f.path} (couche $layer) importe $uri (couche $target)');
      }
    }
    expect(violations, isEmpty, reason: 'Sens des dépendances violé :\n${violations.join('\n')}');
  });

  test('aucune couche n\'importe un paquet qui lui est interdit', () {
    final violations = <String>[];
    for (final f in files) {
      final layer = layerOf(f.path);
      for (final uri in imports(f)) {
        for (final bad in forbiddenExternal[layer] ?? const <String>[]) {
          if (uri.startsWith(bad)) violations.add('${f.path} (couche $layer) importe $uri');
        }
      }
    }
    expect(violations, isEmpty, reason: 'Paquets interdits :\n${violations.join('\n')}');
  });

  test('l\'ancienne couche data n\'existe plus', () {
    expect(Directory('lib/src/data').existsSync(), isFalse);
  });
}
