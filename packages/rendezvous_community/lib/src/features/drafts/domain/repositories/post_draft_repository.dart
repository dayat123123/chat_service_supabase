import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';

abstract interface class PostDraftRepository {
  Future<List<PostDraft>> list();

  Future<PostDraft> save(PostDraft draft, {DateTime? baseUpdatedAt});

  Future<void> delete(String clientDraftId);
}

abstract interface class PostDraftStore {
  Future<(List<PostDraft>, Set<String>)> load();

  Future<void> write(List<PostDraft> drafts, Set<String> deleted);
}
