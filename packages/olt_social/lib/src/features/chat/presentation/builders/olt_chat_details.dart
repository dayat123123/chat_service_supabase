import 'package:flutter/widgets.dart';
import 'package:olt_social/src/core/network/realtime_status.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

class OltMessageDetails {
  const OltMessageDetails({
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
    this.onSenderTap,
    this.onShowActions,
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
  final VoidCallback? onSenderTap;
  final VoidCallback? onShowActions;
}

class OltComposerDetails {
  const OltComposerDetails({
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
    this.extraActions = const [],
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
  final List<Widget> extraActions;
}

class OltRoomHeaderDetails {
  const OltRoomHeaderDetails({
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

class OltTypingDetails {
  const OltTypingDetails({required this.users, required this.text});

  final List<UserSummary> users;
  final String text;
}

class OltConnectionDetails {
  const OltConnectionDetails({required this.status, required this.label});

  final RealtimeStatus status;
  final String label;
}

class OltDayDetails {
  const OltDayDetails({required this.day, required this.label});

  final DateTime day;
  final String label;
}

class OltRoomTileDetails {
  const OltRoomTileDetails({
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

class OltChatListHeaderDetails {
  const OltChatListHeaderDetails({required this.title, required this.onNewGroup, required this.onRefresh});

  final String title;
  final VoidCallback onNewGroup;
  final Future<void> Function() onRefresh;
}

enum OltChatLoad { rooms, moreRooms, messages, olderMessages }

class OltLoadingDetails {
  const OltLoadingDetails(this.kind);

  final OltChatLoad kind;
}

enum OltChatEmpty { rooms, messages, noRoomSelected }

class OltEmptyDetails {
  const OltEmptyDetails({required this.kind, required this.message});

  final OltChatEmpty kind;
  final String message;
}

class OltErrorDetails {
  const OltErrorDetails({required this.error, required this.message, required this.onRetry});

  final Object error;
  final String message;
  final VoidCallback onRetry;
}
