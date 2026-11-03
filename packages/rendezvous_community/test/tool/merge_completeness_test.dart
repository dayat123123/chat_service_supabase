import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/source_files.dart';

const _combiners = {'merge', 'copyWith', 'lerp'};

class _Combiner {
  _Combiner(this.path, this.className, this.method, this.fields, this.arguments);

  final String path;
  final String className;
  final String method;
  final Set<String> fields;
  final Set<String> arguments;

  Set<String> get missing => fields.difference(arguments);
}

class _ArgumentCollector extends RecursiveAstVisitor<void> {
  _ArgumentCollector(this.className);

  final String className;
  final names = <String>{};

  void _collect(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression) names.add(argument.name.label.name);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == className) _collect(node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == className) _collect(node.argumentList);
    super.visitMethodInvocation(node);
  }
}

List<_Combiner> _combinersIn(String path, String source) {
  final unit = parseString(content: source, path: path, throwIfDiagnostics: false).unit;
  final found = <_Combiner>[];
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    final className = declaration.namePart.typeName.lexeme;
    final members = declaration.body is BlockClassBody ? (declaration.body as BlockClassBody).members : <ClassMember>[];
    final fields = <String>{
      for (final member in members.whereType<FieldDeclaration>())
        if (!member.isStatic && member.fields.isFinal)
          for (final variable in member.fields.variables) variable.name.lexeme.replaceFirst('_', ''),
    };
    for (final method in members.whereType<MethodDeclaration>()) {
      final name = method.name.lexeme;
      if (!_combiners.contains(name) || fields.isEmpty) continue;
      final collector = _ArgumentCollector(className);
      method.body.accept(collector);
      if (collector.names.isEmpty) continue;
      found.add(_Combiner(path, className, name, fields, collector.names));
    }
  }
  return found;
}

void main() {
  final packageRoot = Directory.current;
  final combiners = [
    for (final file in handwrittenDartFiles(packageRoot))
      if (relativePath(packageRoot, file).startsWith('lib/'))
        ..._combinersIn(relativePath(packageRoot, file), file.readAsStringSync()),
  ];

  test('finds every builders merge in the package', () {
    final names = {for (final c in combiners) '${c.className}.${c.method}'};
    expect(
      names,
      containsAll([
        'CommunityChatBuilders.merge',
        'CommunityFeedBuilders.merge',
        'CommunityNotificationBuilders.merge',
        'CommunityProfileBuilders.merge',
        'CommunityBadgeBuilders.merge',
        'CommunityBuilders.merge',
        'CommunityTheme.copyWith',
        'CommunityTheme.lerp',
      ]),
    );
  });

  test('merge, copyWith and lerp pass every field of their class', () {
    final incomplete = [
      for (final c in combiners)
        if (c.missing.isNotEmpty) '${c.path}: ${c.className}.${c.method} omits ${c.missing.join(', ')}',
    ];
    expect(incomplete, isEmpty);
  });

  test('the checker reports an omitted field', () {
    const source = '''
class Sample {
  const Sample({this.a, this.b});
  final int? a;
  final int? b;
  Sample merge(Sample other) => Sample(a: other.a ?? a);
}
''';
    expect(_combinersIn('lib/sample.dart', source).single.missing, {'b'});
  });
}
