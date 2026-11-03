import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock_info.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

class CommunityMessageDetails {
  const CommunityMessageDetails({
    required this.message,
    required this.isMine,
    required this.receipt,
    required this.showSender,
    required this.startsGroup,
    required this.timeLabel,
    this.onReply,
    this.onDelete,
    this.onReport,
    this.onRetry,
    this.onDiscard,
    this.onSenderTap,
    this.onShowActions,
    this.reactions = const [],
    this.reactionChoices = const [],
    this.onReact,
    this.onAppeal,
    this.onOpenSharedPost,
    this.senderIsModerator = false,
    this.senderMutedUntil,
    this.onHide,
    this.onMuteSender,
    this.onEscalate,
  });

  final ChatMessage message;
  final bool isMine;
  final ReceiptStatus? receipt;
  final bool showSender;
  final bool startsGroup;
  final String timeLabel;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  final VoidCallback? onSenderTap;
  final VoidCallback? onShowActions;
  final List<MessageReaction> reactions;
  final List<String> reactionChoices;
  final ValueChanged<String>? onReact;
  final VoidCallback? onAppeal;
  final VoidCallback? onOpenSharedPost;
  final bool senderIsModerator;
  final DateTime? senderMutedUntil;
  final VoidCallback? onHide;
  final VoidCallback? onMuteSender;
  final VoidCallback? onEscalate;

  bool get hasModeration => onHide != null || onMuteSender != null || onEscalate != null;
}

class CommunityComposerDetails {
  const CommunityComposerDetails({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.maxLength,
    required this.uploading,
    required this.onSend,
    this.replyTo,
    this.replyPreview,
    this.onCancelReply,
    this.onPickImage,
    this.allowsDocuments = false,
    this.extraActions = const [],
    this.cooldown = Duration.zero,
    this.onSendStockCard,
    this.mutedUntil,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final int maxLength;
  final bool uploading;
  final VoidCallback onSend;
  final ChatMessage? replyTo;
  final String? replyPreview;
  final VoidCallback? onCancelReply;
  final VoidCallback? onPickImage;
  final bool allowsDocuments;
  final List<Widget> extraActions;
  final Duration cooldown;
  final VoidCallback? onSendStockCard;
  final DateTime? mutedUntil;

  bool get coolingDown => cooldown > Duration.zero;

  bool get muted => mutedUntil != null;

  int get cooldownSeconds => (cooldown.inMilliseconds + 999) ~/ 1000;
}

class CommunityRoomHeaderDetails {
  const CommunityRoomHeaderDetails({
    required this.room,
    required this.title,
    required this.subtitle,
    required this.highlightSubtitle,
    required this.online,
    required this.typing,
    required this.memberCount,
    this.onTap,
    this.onToggleMute,
    this.onLeave,
  });

  final ChatRoom room;
  final String title;
  final String subtitle;
  final bool highlightSubtitle;
  final bool online;
  final List<UserSummary> typing;
  final int memberCount;
  final VoidCallback? onTap;
  final VoidCallback? onToggleMute;
  final VoidCallback? onLeave;
}

class CommunityTypingDetails {
  const CommunityTypingDetails({required this.users, required this.text});

  final List<UserSummary> users;
  final String text;
}

class CommunityConnectionDetails {
  const CommunityConnectionDetails({required this.status, required this.label, this.offline = false});

  final RealtimeStatus status;
  final String label;
  final bool offline;
}

class CommunityDayDetails {
  const CommunityDayDetails({required this.day, required this.label});

  final DateTime day;
  final String label;
}

class CommunityRoomTileDetails {
  const CommunityRoomTileDetails({
    required this.room,
    required this.title,
    required this.timeLabel,
    required this.online,
    required this.selected,
    required this.typing,
    required this.onTap,
    this.preview,
    this.typingText,
    this.lastMessageReceipt,
  });

  final ChatRoom room;
  final String title;
  final String timeLabel;
  final bool online;
  final bool selected;
  final List<UserSummary> typing;
  final VoidCallback onTap;
  final String? preview;
  final String? typingText;
  final ReceiptStatus? lastMessageReceipt;
}

class CommunityChatListHeaderDetails {
  const CommunityChatListHeaderDetails({required this.title, required this.onNewGroup, required this.onRefresh});

  final String title;
  final VoidCallback onNewGroup;
  final Future<void> Function() onRefresh;
}

enum CommunityChatLoad { rooms, moreRooms, messages, olderMessages }

class CommunityLoadingDetails {
  const CommunityLoadingDetails(this.kind);

  final CommunityChatLoad kind;
}

enum CommunityChatEmpty { rooms, messages, noRoomSelected }

class CommunityEmptyDetails {
  const CommunityEmptyDetails({required this.kind, required this.message});

  final CommunityChatEmpty kind;
  final String message;
}

class CommunityErrorDetails {
  const CommunityErrorDetails({required this.error, required this.message, required this.onRetry});

  final Object error;
  final String message;
  final VoidCallback onRetry;
}

class CommunityStockCardDetails {
  const CommunityStockCardDetails({required this.code, required this.isMine, this.info, this.onTap});

  final String code;
  final bool isMine;
  final CommunityStockInfo? info;
  final VoidCallback? onTap;
}
