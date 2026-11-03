import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

part 'post_draft.freezed.dart';

const maxPostDrafts = 20;

enum DraftSyncStatus { synced, localOnly, replaced, limitReached }

@freezed
abstract class PostDraft with _$PostDraft {
  const factory PostDraft({
    required String clientDraftId,
    @Default('') String body,
    Sentiment? sentiment,
    @Default(<String>[]) List<String> stocks,
    @Default(<Attachment>[]) List<Attachment> attachments,
    PollDraft? poll,
    required DateTime updatedAt,
    DateTime? serverUpdatedAt,
  }) = _PostDraft;

  const PostDraft._();

  bool get isEmpty => body.trim().isEmpty && attachments.isEmpty && poll == null;

  bool get synced => serverUpdatedAt != null && !updatedAt.isAfter(serverUpdatedAt!);
}

class DraftSaveResult {
  const DraftSaveResult(this.draft, this.status);

  final PostDraft draft;
  final DraftSyncStatus status;
}
