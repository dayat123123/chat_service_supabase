import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/features/poll/data/repositories/poll_repository_impl.dart';

import '../../../support/mock_api.dart';

void main() {
  test('vote calls vote_poll and maps the latest results', () async {
    final api = mockApi();
    when(
      () => api.rpcValue('vote_poll', any()),
    ).thenAnswer((_) async => pollJson(myOptionId: 'o-2', visible: true, total: 4));

    final poll = await PollRepositoryImpl(api).vote('p-1', 'o-2');

    verify(() => api.rpcValue('vote_poll', {'p_post_id': 'p-1', 'p_option_id': 'o-2'})).called(1);
    expect(poll.myOptionId, 'o-2');
    expect(poll.resultsVisible, isTrue);
    expect(poll.options.last.votes, 1);
  });
}
