import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/compose/presentation/cubit/compose_cubit.dart';

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

  test('mengelola draf polling: tambah, ubah, batas 2–4 pilihan, durasi, hapus', () {
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

  test('draf polling tidak valid tidak dikirim', () async {
    cubit.addPoll();
    expect(await cubit.submit('IHSG ke mana?'), isNull);
    expect(feed.calls, isEmpty);
    expect((cubit.state.error! as OltSocialException).code, 'invalid_poll_draft');
  });

  test('polling valid dikirim bersama post', () async {
    cubit
      ..addPoll()
      ..setPollOption(0, 'Naik')
      ..setPollOption(1, 'Turun');
    final post = await cubit.submit('IHSG ke mana?');
    expect(post!.id, 'p-new');
    expect((feed.calls.single['poll']! as PollDraft).cleanOptions, ['Naik', 'Turun']);
    expect(cubit.state.poll, isNull);
  });

  test('kirim ulang setelah gagal memakai client_id yang sama (tanpa post ganda)', () async {
    feed.error = const OltSocialException(OltSocialErrorKind.network);
    await cubit.submit('Halo');
    feed.error = null;
    await cubit.submit('Halo');
    await cubit.submit('Post berikutnya');
    expect(feed.calls[0]['clientId'], feed.calls[1]['clientId']);
    expect(feed.calls[2]['clientId'], isNot(feed.calls[1]['clientId']));
  });
}
