import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/features/post/data/repositories/comment_repository_impl.dart';

import '../../../support/mock_api.dart';

void main() {
  test('getThread forwards thread parameters and maps deleted comments', () async {
    final api = mockApi();
    when(
      () => api.rpcRows('get_comment_thread', any()),
    ).thenAnswer((_) async => [commentRow('c-1'), commentRow('c-2', parentId: 'c-1', depth: 1, deleted: true)]);

    final thread = await CommentRepositoryImpl(
      api,
    ).getThread('p-1', rootCommentId: 'c-0', maxDepth: 4, includeRoot: true);

    final params =
        verify(() => api.rpcRows('get_comment_thread', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_root_comment_id'], 'c-0');
    expect(params['p_max_depth'], 4);
    expect(params['p_include_root'], true);
    expect(thread.first.author!.username, 'sari_invest');
    expect(thread.last.isDeleted, isTrue);
    expect(thread.last.author, isNull);
    expect(thread.last.body, isNull);
  });
}
