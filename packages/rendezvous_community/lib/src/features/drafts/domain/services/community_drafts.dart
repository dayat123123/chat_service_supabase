import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/drafts/domain/repositories/post_draft_repository.dart';

const draftConflictCode = 'draft_conflict';
const draftLimitCode = 'draft_limit';

class CommunityDrafts {
  CommunityDrafts(this._remote, this._local, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final PostDraftRepository _remote;
  final PostDraftStore _local;
  final DateTime Function() _clock;

  DateTime now() => _clock().toUtc();

  Future<List<PostDraft>> list() async {
    final (local, deleted) = await _local.load();
    List<PostDraft> remote;
    try {
      remote = await _remote.list();
    } catch (_) {
      return _sorted(local);
    }
    final pending = {...deleted};
    for (final id in deleted) {
      try {
        await _remote.delete(id);
        pending.remove(id);
      } catch (_) {}
    }
    final merged = <String, PostDraft>{
      for (final draft in remote)
        if (!deleted.contains(draft.clientDraftId)) draft.clientDraftId: draft,
    };
    for (final draft in local) {
      final server = merged[draft.clientDraftId];
      if (server == null) {
        if (draft.serverUpdatedAt == null && !deleted.contains(draft.clientDraftId)) {
          merged[draft.clientDraftId] = draft;
        }
      } else if (draft.updatedAt.isAfter(server.updatedAt)) {
        merged[draft.clientDraftId] = draft.copyWith(serverUpdatedAt: server.serverUpdatedAt);
      }
    }
    final result = _sorted(merged.values);
    await _local.write(result, pending);
    return result;
  }

  Future<DraftSaveResult> save(PostDraft draft) async {
    final edited = draft.copyWith(updatedAt: now());
    await _upsertLocal(edited);
    try {
      return DraftSaveResult(await _push(edited, base: edited.serverUpdatedAt), DraftSyncStatus.synced);
    } catch (e) {
      final error = mapError(e);
      if (error.code == draftConflictCode) return _resolveConflict(edited);
      CommunityLoggers.feed.event(
        Level.FINE,
        'Draft kept on this device',
        fields: {'draftId': edited.clientDraftId, 'kind': error.kind, 'code': error.code},
      );
      return DraftSaveResult(
        edited,
        error.code == draftLimitCode ? DraftSyncStatus.limitReached : DraftSyncStatus.localOnly,
      );
    }
  }

  Future<void> delete(String clientDraftId) async {
    final (local, deleted) = await _local.load();
    final rest = [
      for (final d in local)
        if (d.clientDraftId != clientDraftId) d,
    ];
    await _local.write(rest, {...deleted, clientDraftId});
    try {
      await _remote.delete(clientDraftId);
      await _local.write(rest, deleted.where((id) => id != clientDraftId).toSet());
    } catch (_) {}
  }

  Future<void> published(String clientDraftId) async {
    final (local, deleted) = await _local.load();
    await _local.write([
      for (final d in local)
        if (d.clientDraftId != clientDraftId) d,
    ], deleted);
  }

  Future<PostDraft> _push(PostDraft draft, {DateTime? base}) async {
    final saved = await _remote.save(draft, baseUpdatedAt: base);
    final synced = draft.copyWith(serverUpdatedAt: saved.updatedAt);
    await _upsertLocal(synced);
    return synced;
  }

  Future<DraftSaveResult> _resolveConflict(PostDraft mine) async {
    try {
      final server = (await _remote.list()).where((d) => d.clientDraftId == mine.clientDraftId).firstOrNull;
      if (server != null && server.updatedAt.isAfter(mine.updatedAt)) {
        await _upsertLocal(server);
        return DraftSaveResult(server, DraftSyncStatus.replaced);
      }
      return DraftSaveResult(await _push(mine), DraftSyncStatus.synced);
    } catch (_) {
      return DraftSaveResult(mine, DraftSyncStatus.localOnly);
    }
  }

  Future<void> _upsertLocal(PostDraft draft) async {
    final (local, deleted) = await _local.load();
    await _local.write(
      _sorted([
        draft,
        for (final d in local)
          if (d.clientDraftId != draft.clientDraftId) d,
      ]),
      deleted,
    );
  }

  static List<PostDraft> _sorted(Iterable<PostDraft> drafts) =>
      drafts.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
