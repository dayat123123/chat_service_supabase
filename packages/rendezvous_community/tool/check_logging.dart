import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_files.dart';

const _consoleFunctions = {'print', 'debugPrint'};
const _loggingModule = 'lib/src/core/logging/';

class ConsoleCall {
  const ConsoleCall(this.path, this.line, this.function);

  final String path;
  final int line;
  final String function;

  @override
  String toString() => '$path:$line: $function() is not allowed; use CommunityLoggers instead';
}

class _ConsoleCallVisitor extends RecursiveAstVisitor<void> {
  _ConsoleCallVisitor(this.onCall);

  final void Function(MethodInvocation node) onCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && _consoleFunctions.contains(node.methodName.name)) onCall(node);
    super.visitMethodInvocation(node);
  }
}

List<ConsoleCall> findConsoleCalls(String path, String source) {
  final result = parseString(content: source, path: path, throwIfDiagnostics: false);
  final calls = <ConsoleCall>[];
  result.unit.accept(
    _ConsoleCallVisitor((node) {
      final line = result.lineInfo.getLocation(node.offset).lineNumber;
      calls.add(ConsoleCall(path, line, node.methodName.name));
    }),
  );
  return calls;
}

void main(List<String> args) {
  final packageRoot = Directory(args.isEmpty ? Directory.current.path : args.first).absolute;
  final calls = [
    for (final file in handwrittenDartFiles(packageRoot))
      if (relativePath(packageRoot, file).startsWith('lib/') &&
          !relativePath(packageRoot, file).startsWith(_loggingModule))
        ...findConsoleCalls(relativePath(packageRoot, file), file.readAsStringSync()),
  ];
  if (calls.isEmpty) {
    stdout.writeln('check_logging: library code does not print to the console directly');
    return;
  }
  calls.forEach(stderr.writeln);
  exitCode = 1;
}
