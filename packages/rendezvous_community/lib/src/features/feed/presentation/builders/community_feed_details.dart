import 'package:flutter/foundation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/pinned_post.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';

class CommunityPostDetails {
  const CommunityPostDetails({
    required this.post,
    required this.isMine,
    required this.timeLabel,
    required this.onLike,
    required this.onOpenAuthor,
    required this.onOpenStock,
    required this.onOpenHashtag,
    this.expanded = false,
    this.source = 'feed',
    this.pinned,
    this.onOpen,
    this.onComment,
    this.onShare,
    this.onToggleBookmark,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.onAppeal,
  });

  final Post post;
  final bool isMine;
  final String timeLabel;
  final bool expanded;
  final String source;
  final PinnedPost? pinned;
  final VoidCallback onLike;
  final VoidCallback onOpenAuthor;
  final ValueChanged<String> onOpenStock;
  final ValueChanged<String> onOpenHashtag;
  final VoidCallback? onOpen;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onAppeal;

  bool get edited => post.editedAt != null;

  bool get canVote => !isMine;
}

class CommunityPinnedMarkerDetails {
  const CommunityPinnedMarkerDetails({required this.pinned, required this.label});

  final PinnedPost pinned;
  final String label;

  bool get announcement => pinned.announcement;

  String? get title => pinned.title;
}

class CommunityLinkPreviewDetails {
  const CommunityLinkPreviewDetails({required this.preview, this.onOpen});

  final LinkPreview preview;
  final VoidCallback? onOpen;
}

class CommunityPollDetails {
  const CommunityPollDetails({
    required this.postId,
    required this.poll,
    required this.canVote,
    required this.closed,
    required this.showResults,
    required this.summary,
    this.pendingOptionId,
    this.onVote,
  });

  final String postId;
  final Poll poll;
  final bool canVote;
  final bool closed;
  final bool showResults;
  final String summary;
  final String? pendingOptionId;
  final ValueChanged<PollOption>? onVote;
}

class CommunityCommentDetails {
  const CommunityCommentDetails({
    required this.comment,
    required this.isMine,
    required this.collapsed,
    required this.timeLabel,
    this.onLike,
    this.onReply,
    this.onToggleCollapse,
    this.onOpenAuthor,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.onAppeal,
  });

  final ThreadComment comment;
  final bool isMine;
  final bool collapsed;
  final String timeLabel;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onOpenAuthor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onAppeal;

  bool get edited => comment.editedAt != null && !comment.isDeleted;
}
