import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/local_values.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:rendezvous_community/src/features/drafts/data/repositories/post_draft_repository_impl.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

class _NoMedia extends Fake implements MediaRepository {}

class _Feed extends FakeFeedRepository {
  final clientIds = <String?>[];

  @override
  Future<Post> createPost({
    required String body,
    Sentiment? sentiment,
    List<Attachment> attachments = const [],
    PollDraft? poll,
    String? clientId,
  }) async {
    clientIds.add(clientId);
    return Post(id: 'p-new', author: me, body: body, createdAt: now, cursor: 'c');
  }
}

void main() {
  final t0 = DateTime.utc(2026, 11, 3, 9);
  late FakePostDraftRepository remote;
  late PostDraftStoreImpl local;
  late CommunityDrafts drafts;
  late DateTime clock;

  PostDraft draft(String id, {String body = r'Analisis $BBCA', DateTime? at}) =>
      PostDraft(clientDraftId: id, body: body, stocks: const ['BBCA'], updatedAt: at ?? t0);

  setUp(() {
    clock = t0;
    remote = FakePostDraftRepository()..clock = () => clock;
    local = PostDraftStoreImpl(MemoryLocalValues());
    drafts = CommunityDrafts(remote, local, clock: () => clock);
  });

  test('a saved draft is kept locally and synced to the server', () async {
    final result = await drafts.save(draft('d1'));
    expect(result.status, DraftSyncStatus.synced);
    expect(result.draft.synced, isTrue);
    expect(remote.saved.keys, ['d1']);
    expect((await local.load()).$1.single.serverUpdatedAt, t0);
  });

  test('offline and limit errors keep the draft on the device', () async {
    remote.saveError = const CommunityException(CommunityErrorKind.network);
    expect((await drafts.save(draft('d1'))).status, DraftSyncStatus.localOnly);
    remote.saveError = const CommunityException(CommunityErrorKind.invalidInput, code: 'draft_limit');
    expect((await drafts.save(draft('d2'))).status, DraftSyncStatus.limitReached);
    expect([for (final d in (await local.load()).$1) d.clientDraftId], containsAll(['d1', 'd2']));

    remote.saveError = null;
    remote.listError = const CommunityException(CommunityErrorKind.network);
    expect(await drafts.list(), hasLength(2));
  });

  test('a conflict keeps the newer server version and reports it', () async {
    remote.saved['d1'] = draft('d1', body: 'Versi tablet', at: t0.add(const Duration(minutes: 5)));
    clock = t0;
    remote.saveError = const CommunityException(CommunityErrorKind.invalidInput, code: 'draft_conflict');
    final result = await drafts.save(draft('d1', body: 'Versi lama'));
    expect(result.status, DraftSyncStatus.replaced);
    expect(result.draft.body, 'Versi tablet');
    expect((await local.load()).$1.single.body, 'Versi tablet');
  });

  test('list merges server and local drafts and retries deletions', () async {
    remote.saved['srv'] = draft('srv', at: t0);
    await local.write([draft('mine', at: t0.add(const Duration(minutes: 1)))], {'gone'});
    remote.saved['gone'] = draft('gone');

    final listed = await drafts.list();
    expect([for (final d in listed) d.clientDraftId], ['mine', 'srv']);
    expect(remote.deleted, ['gone']);
    expect((await local.load()).$2, isEmpty);

    await drafts.delete('srv');
    expect(remote.deleted, ['gone', 'srv']);
    expect([for (final d in await drafts.list()) d.clientDraftId], ['mine']);
  });

  test('the composer autosaves with a debounce and publishes with the draft id as client_id', () async {
    final feed = _Feed();
    final cubit = ComposeCubit(feed: feed, media: _NoMedia(), drafts: drafts, draftDelay: Duration.zero);
    addTearDown(cubit.close);

    cubit.bodyChanged(r'Analisis $BBCA');
    cubit.setSentiment(Sentiment.bullish);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final saved = remote.saved[cubit.clientDraftId]!;
    expect(saved.body, r'Analisis $BBCA');
    expect(saved.sentiment, Sentiment.bullish);
    expect(saved.stocks, ['BBCA']);
    expect(cubit.state.draftStatus, DraftSyncStatus.synced);

    final draftId = cubit.clientDraftId;
    await cubit.submit(r'Analisis $BBCA');
    expect(feed.clientIds, [draftId]);
    expect((await local.load()).$1, isEmpty);
    expect(cubit.clientDraftId, isNot(draftId));
  });

  test('a resumed draft fills the composer state', () {
    final cubit = ComposeCubit(
      feed: _Feed(),
      media: _NoMedia(),
      drafts: drafts,
      draft: draft('d9').copyWith(sentiment: Sentiment.bearish, poll: const PollDraft()),
    );
    addTearDown(cubit.close);
    expect(cubit.clientDraftId, 'd9');
    expect(cubit.state.sentiment, Sentiment.bearish);
    expect(cubit.state.poll, isNotNull);
  });

  test('the remote repository maps the draft RPCs', () async {
    final api = mockApi();
    when(() => api.rpcValue('save_post_draft', any())).thenAnswer(
      (_) async => {
        'client_draft_id': 'd1',
        'body': 'Halo',
        'sentiment': 'bullish',
        'stocks': ['BBCA'],
        'attachments': <Object?>[],
        'poll': {
          'options': ['Ya', 'Tidak'],
          'duration_minutes': 360,
        },
        'updated_at': '2026-11-03T09:00:00+00:00',
      },
    );
    final repo = PostDraftRepositoryImpl(api);
    final saved = await repo.save(draft('d1'), baseUpdatedAt: t0);
    expect(saved.poll?.duration, PollDuration.sixHours);
    expect(saved.serverUpdatedAt, t0);
    final params = verify(() => api.rpcValue('save_post_draft', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_client_draft_id'], 'd1');
    expect(params['p_base_updated_at'], '2026-11-03T09:00:00.000Z');
    expect(params['p_stocks'], ['BBCA']);
  });
}
