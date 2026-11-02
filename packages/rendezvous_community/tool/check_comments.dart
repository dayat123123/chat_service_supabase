import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'source_files.dart';

const _allowedPrefixes = ['// ignore:', '// ignore_for_file:'];

class CommentViolation {
  const CommentViolation(this.path, this.line, this.text);

  final String path;
  final int line;
  final String text;

  @override
  String toString() => '$path:$line: $text';
}

List<CommentViolation> findComments(String path, String source) {
  final result = parseString(content: source, path: path, throwIfDiagnostics: false);
  final violations = <CommentViolation>[];
  Token? token = result.unit.beginToken;
  while (token != null) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      final text = comment.lexeme.trim();
      if (!_allowedPrefixes.any(text.startsWith)) {
        final line = result.lineInfo.getLocation(comment.offset).lineNumber;
        violations.add(CommentViolation(path, line, text.split('\n').first));
      }
      comment = comment.next;
    }
    if (token.type == TokenType.EOF) break;
    token = token.next;
  }
  return violations;
}

void main(List<String> args) {
  final packageRoot = Directory(args.isEmpty ? Directory.current.path : args.first).absolute;
  final violations = [
    for (final file in handwrittenDartFiles(packageRoot))
      ...findComments(relativePath(packageRoot, file), file.readAsStringSync()),
  ];
  if (violations.isEmpty) {
    stdout.writeln('check_comments: no comments found in handwritten Dart files');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln(
    'check_comments: ${violations.length} comment(s) found; move explanations to docs/rendezvous-community',
  );
  exitCode = 1;
}
