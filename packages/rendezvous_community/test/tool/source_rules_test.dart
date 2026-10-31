import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_comments.dart';
import '../../tool/check_logging.dart';
import '../../tool/source_files.dart';

void main() {
  group('check_comments', () {
    test('reports line, block, and doc comments with their line numbers', () {
      const source = '''
/// Library entry point.
void main() {
  // explain the loop
  final values = [1, 2]; /* inline */
}
''';
      final violations = findComments('lib/sample.dart', source);
      expect(violations.map((violation) => violation.line), [1, 3, 4]);
      expect(violations.first.text, '/// Library entry point.');
    });

    test('ignores slashes inside string literals', () {
      const source = '''
const url = 'https://example.com/path';
const raw = r'// not a comment';
const multi = """
/* still a string */
""";
''';
      expect(findComments('lib/sample.dart', source), isEmpty);
    });

    test('allows analyzer ignore directives', () {
      const source = '''
// ignore_for_file: avoid_print
void main() {
  // ignore: unused_local_variable
  final unused = 1;
}
''';
      expect(findComments('lib/sample.dart', source), isEmpty);
    });

    test('treats generated files as exempt', () {
      expect(isGenerated('lib/src/core/auth/social_session.freezed.dart'), isTrue);
      expect(isGenerated('lib/src/core/auth/social_session.g.dart'), isTrue);
      expect(isGenerated(r'lib\src\shared\presentation\l10n\gen\community_localizations.dart'), isTrue);
      expect(isGenerated('lib/src/core/auth/token_manager.dart'), isFalse);
    });
  });

  group('check_logging', () {
    test('reports top-level print and debugPrint calls', () {
      const source = '''
void main() {
  print('a');
  debugPrint('b');
  logger.print('c');
}
''';
      final calls = findConsoleCalls('lib/sample.dart', source);
      expect(calls.map((call) => '${call.function}@${call.line}'), ['print@2', 'debugPrint@3']);
    });
  });
}
