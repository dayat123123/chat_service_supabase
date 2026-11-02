import 'dart:convert';
import 'dart:io';

const _allowed = {'MIT', 'BSD', 'Apache-2.0', 'ISC', 'Zlib'};

String classify(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ');
  if (t.contains('GNU AFFERO GENERAL PUBLIC LICENSE')) return 'AGPL';
  if (t.contains('GNU LESSER GENERAL PUBLIC LICENSE') || t.contains('GNU LIBRARY GENERAL PUBLIC')) return 'LGPL';
  if (t.contains('GNU GENERAL PUBLIC LICENSE')) return 'GPL';
  if (t.contains('Mozilla Public License')) return 'MPL';
  if (t.contains('Apache License') && t.contains('Version 2.0')) return 'Apache-2.0';
  if (t.contains('Permission is hereby granted, free of charge')) return 'MIT';
  if (t.contains('Redistribution and use in source and binary forms')) return 'BSD';
  if (t.contains('Permission to use, copy, modify, and/or distribute')) return 'ISC';
  if (t.contains("This software is provided 'as-is'")) return 'Zlib';
  return 'UNKNOWN';
}

Future<void> main() async {
  final result = await Process.run('flutter', ['pub', 'deps', '--json'], runInShell: true);
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    exit(2);
  }
  final deps = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final packages = {
    for (final p in (deps['packages'] as List<dynamic>).cast<Map<String, dynamic>>()) p['name'] as String: p,
  };

  final root = packages.values.firstWhere((p) => p['kind'] == 'root');
  final queue = [for (final name in (root['directDependencies'] as List<dynamic>).cast<String>()) name];
  final runtime = <String>{};
  while (queue.isNotEmpty) {
    final name = queue.removeLast();
    if (!runtime.add(name)) continue;
    queue.addAll(((packages[name]?['dependencies'] as List<dynamic>?) ?? const []).cast<String>());
  }

  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final roots = {
    for (final p in (config['packages'] as List<dynamic>).cast<Map<String, dynamic>>())
      p['name'] as String: Uri.parse(
        '${File('.dart_tool/package_config.json').absolute.uri}',
      ).resolve(p['rootUri'] as String),
  };

  var failed = false;
  final rows = <(String, String, String)>[];
  for (final name in runtime.toList()..sort()) {
    final source = packages[name]?['source'];
    if (source == 'sdk') {
      rows.add((name, 'Flutter SDK (BSD)', 'ok'));
      continue;
    }
    if (source == 'path') {
      rows.add((name, 'this repository', 'ok'));
      continue;
    }
    final dir = Directory.fromUri(roots[name]!);
    final licenseFile = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'(LICENSE|LICENCE|COPYING)', caseSensitive: false).hasMatch(f.uri.pathSegments.last))
        .firstOrNull;
    final license = licenseFile == null ? 'MISSING' : classify(licenseFile.readAsStringSync());
    final ok = _allowed.contains(license);
    failed |= !ok;
    rows.add((name, license, ok ? 'ok' : 'REVIEW'));
  }

  for (final (name, license, status) in rows) {
    stdout.writeln('${name.padRight(36)} ${license.padRight(18)} $status');
  }
  stdout.writeln('\nChecked ${rows.length} runtime packages');
  if (failed) {
    stderr.writeln('Found disallowed or unrecognized licenses; check the REVIEW rows');
    exit(1);
  }
  stdout.writeln('All licenses are permissive (MIT/BSD/Apache-2.0/ISC/Zlib)');
}
