import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';

import '../../../support/fakes.dart';

class _RecordingFeed extends Fake implements FeedRepository {
  final calls = <Map<String, Object?>>[];
  Object? error;

  @override
  Future<Post> createPost({
    required String body,
    Sentiment? sentiment,
    List<Attachment> attachments = const [],
    PollDraft? poll,
    String? clientId,
  }) async {
    calls.add({'body': body, 'poll': poll, 'clientId': clientId});
    final failure = error;
    if (failure != null) throw failure;
    return Post(id: 'p-new', author: me, body: body, createdAt: now, cursor: 'c');
  }
}

class _NoMedia extends Fake implements MediaRepository {}

void main() {
  late _RecordingFeed feed;
  late ComposeCubit cubit;

  setUp(() {
    feed = _RecordingFeed();
    cubit = ComposeCubit(feed: feed, media: _NoMedia());
  });

  tearDown(() => cubit.close());

  test('manages the poll draft: add, edit, 2–4 option limit, duration, remove', () {
    cubit
      ..addPoll()
      ..setPollOption(0, 'Naik')
      ..setPollOption(1, 'Turun')
      ..addPollOption()
      ..addPollOption()
      ..addPollOption()
      ..setPollDuration(PollDuration.sevenDays);
    expect(cubit.state.poll!.options, ['Naik', 'Turun', '', '']);
    expect(cubit.state.poll!.duration, PollDuration.sevenDays);
    expect(cubit.state.canAddImage, isFalse);

    cubit
      ..removePollOption(3)
      ..removePollOption(2)
      ..removePollOption(1);
    expect(cubit.state.poll!.options, ['Naik', 'Turun']);

    cubit.removePoll();
    expect(cubit.state.poll, isNull);
    expect(cubit.state.canAddImage, isTrue);
  });

  test('does not submit an invalid poll draft', () async {
    cubit.addPoll();
    expect(await cubit.submit('IHSG ke mana?'), isNull);
    expect(feed.calls, isEmpty);
    expect((cubit.state.error! as CommunityException).code, 'invalid_poll_draft');
  });

  test('submits a valid poll with the post', () async {
    cubit
      ..addPoll()
      ..setPollOption(0, 'Naik')
      ..setPollOption(1, 'Turun');
    final post = await cubit.submit('IHSG ke mana?');
    expect(post!.id, 'p-new');
    expect((feed.calls.single['poll']! as PollDraft).cleanOptions, ['Naik', 'Turun']);
    expect(cubit.state.poll, isNull);
  });

  test('resending after a failure reuses the same client_id (no duplicate post)', () async {
    feed.error = const CommunityException(CommunityErrorKind.network);
    await cubit.submit('Halo');
    feed.error = null;
    await cubit.submit('Halo');
    await cubit.submit('Post berikutnya');
    expect(feed.calls[0]['clientId'], feed.calls[1]['clientId']);
    expect(feed.calls[2]['clientId'], isNot(feed.calls[1]['clientId']));
  });
}
