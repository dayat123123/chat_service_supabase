import 'dart:io';

const checkedRoots = ['lib', 'test', 'tool', 'example/lib', 'example/test', 'example/integration_test'];

const _generatedSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart', '.mocks.dart', '.config.dart'];
const _generatedDirectories = ['/l10n/gen/', '/.dart_tool/', '/build/'];

bool isGenerated(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return _generatedSuffixes.any(normalized.endsWith) || _generatedDirectories.any(normalized.contains);
}

Iterable<File> handwrittenDartFiles(Directory packageRoot) sync* {
  for (final root in checkedRoots) {
    final directory = Directory('${packageRoot.path}/$root');
    if (!directory.existsSync()) continue;
    final files = directory.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      if (!isGenerated(file.path)) yield file;
    }
  }
}

String relativePath(Directory packageRoot, File file) =>
    file.path.substring(packageRoot.path.length + 1).replaceAll(r'\', '/');
