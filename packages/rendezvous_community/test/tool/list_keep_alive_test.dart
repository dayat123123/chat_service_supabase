import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/source_files.dart';

const _lazyConstructors = {'builder', 'separated'};

class _LazyList {
  _LazyList(this.location, this.disablesKeepAlive);

  final String location;
  final bool disablesKeepAlive;
}

class _ListCollector extends RecursiveAstVisitor<void> {
  _ListCollector(this.path, this.lineOf);

  final String path;
  final int Function(int offset) lineOf;
  final lists = <_LazyList>[];

  void _check(String? type, String? constructor, ArgumentList arguments, int offset) {
    if (type != 'ListView' || !_lazyConstructors.contains(constructor)) return;
    final disables = arguments.arguments.whereType<NamedExpression>().any(
      (a) =>
          a.name.label.name == 'addAutomaticKeepAlives' &&
          a.expression is BooleanLiteral &&
          !(a.expression as BooleanLiteral).value,
    );
    lists.add(_LazyList('$path:${lineOf(offset)}', disables));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node.constructorName.type.name.lexeme, node.constructorName.name?.name, node.argumentList, node.offset);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier) _check(target.name, node.methodName.name, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }
}

List<_LazyList> _listsIn(String path, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final collector = _ListCollector(path, (offset) => unit.lineInfo.getLocation(offset).lineNumber);
  unit.accept(collector);
  return collector.lists;
}

void main() {
  final packageRoot = Directory.current;
  final lists = [
    for (final file in handwrittenDartFiles(packageRoot))
      if (relativePath(packageRoot, file).startsWith('lib/'))
        ..._listsIn(relativePath(packageRoot, file), file.readAsStringSync()),
  ];

  test('finds the lazy lists of the package', () {
    expect(lists.length, greaterThanOrEqualTo(11));
  });

  test('lazy lists do not keep hovered rows alive offscreen', () {
    expect([
      for (final l in lists)
        if (!l.disablesKeepAlive) l.location,
    ], isEmpty);
  });

  test('the checker reports a list that keeps rows alive', () {
    const source = '''
Widget a() => ListView.builder(itemBuilder: (c, i) => const SizedBox());
Widget b() => ListView.separated(addAutomaticKeepAlives: false, itemBuilder: (c, i) => const SizedBox());
''';
    expect([for (final l in _listsIn('lib/sample.dart', source)) l.disablesKeepAlive], [false, true]);
  });
}
