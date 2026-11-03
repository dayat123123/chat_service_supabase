import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';

Map<String, dynamic>? pollDraftToJson(PollDraft? poll) =>
    poll == null ? null : {'options': poll.options, 'duration_minutes': poll.duration.minutes};

PollDraft? pollDraftFromJson(Object? value) {
  if (value is! Map) return null;
  final options = value['options'];
  final minutes = (value['duration_minutes'] as num?)?.toInt();
  return PollDraft(
    options: options is List ? [for (final o in options) o is String ? o : ''] : const ['', ''],
    duration: PollDuration.values.where((d) => d.minutes == minutes).firstOrNull ?? PollDuration.oneDay,
  );
}

Map<String, dynamic> postDraftToJson(PostDraft draft) => {
  'client_draft_id': draft.clientDraftId,
  'body': draft.body,
  'sentiment': draft.sentiment?.name,
  'stocks': draft.stocks,
  'attachments': [for (final a in draft.attachments) AttachmentModel.fromEntity(a).toJson()],
  'poll': pollDraftToJson(draft.poll),
  'updated_at': draft.updatedAt.toUtc().toIso8601String(),
  'server_updated_at': draft.serverUpdatedAt?.toUtc().toIso8601String(),
};

PostDraft? postDraftFromJson(Map<String, dynamic> row, {bool fromServer = false}) {
  final id = row['client_draft_id'];
  final updatedAt = DateTime.tryParse(row['updated_at'] as String? ?? '');
  if (id is! String || updatedAt == null) return null;
  final stocks = row['stocks'];
  return PostDraft(
    clientDraftId: id,
    body: row['body'] as String? ?? '',
    sentiment: Sentiment.values.asNameMap()[row['sentiment']],
    stocks: [
      if (stocks is List)
        for (final s in stocks)
          if (s is String) s,
    ],
    attachments: [for (final a in attachmentsFromJson(row['attachments'])) a.toEntity()],
    poll: pollDraftFromJson(row['poll']),
    updatedAt: updatedAt.toUtc(),
    serverUpdatedAt: fromServer
        ? updatedAt.toUtc()
        : DateTime.tryParse(row['server_updated_at'] as String? ?? '')?.toUtc(),
  );
}
