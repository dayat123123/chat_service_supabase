import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/core/storage/local_values.dart';
import 'package:rendezvous_community/src/features/drafts/data/repositories/post_draft_json.dart';
import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/drafts/domain/repositories/post_draft_repository.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';

class PostDraftRepositoryImpl implements PostDraftRepository {
  PostDraftRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<List<PostDraft>> list() async {
    final value = await _api.rpcValue('get_post_drafts');
    return [
      if (value is List)
        for (final row in value)
          if (row is Map<String, dynamic>) ?postDraftFromJson(row, fromServer: true),
    ];
  }

  @override
  Future<PostDraft> save(PostDraft draft, {DateTime? baseUpdatedAt}) async {
    final json = jsonMap(
      await _api.rpcValue('save_post_draft', {
        'p_client_draft_id': draft.clientDraftId,
        'p_body': draft.body,
        'p_sentiment': draft.sentiment?.name,
        'p_stocks': draft.stocks,
        'p_attachments': [for (final a in draft.attachments) AttachmentModel.fromEntity(a).toJson()],
        'p_poll': pollDraftToJson(draft.poll),
        'p_base_updated_at': baseUpdatedAt?.toUtc().toIso8601String(),
      }),
    );
    return postDraftFromJson(json, fromServer: true) ?? draft;
  }

  @override
  Future<void> delete(String clientDraftId) => _api.rpcValue('delete_post_draft', {'p_client_draft_id': clientDraftId});
}

class PostDraftStoreImpl implements PostDraftStore {
  PostDraftStoreImpl(this._values);

  static const _key = 'post_drafts';

  final LocalValues _values;

  @override
  Future<(List<PostDraft>, Set<String>)> load() async {
    final json = await _values.read(_key) ?? const <String, dynamic>{};
    final drafts = json['drafts'];
    final deleted = json['deleted'];
    return (
      [
        if (drafts is List)
          for (final row in drafts)
            if (row is Map<String, dynamic>) ?postDraftFromJson(row),
      ],
      {
        if (deleted is List)
          for (final id in deleted)
            if (id is String) id,
      },
    );
  }

  @override
  Future<void> write(List<PostDraft> drafts, Set<String> deleted) => _values.write(_key, {
    'drafts': [for (final d in drafts) postDraftToJson(d)],
    'deleted': deleted.toList(),
  });
}
