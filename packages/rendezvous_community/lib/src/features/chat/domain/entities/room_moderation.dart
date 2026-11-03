enum RoomModerationAction { hide, mute, escalate }

const roomMuteDurations = [Duration(minutes: 15), Duration(hours: 1), Duration(hours: 6), Duration(hours: 24)];

class RoomModerationResult {
  const RoomModerationResult({
    required this.id,
    required this.action,
    this.targetUserId,
    this.messageId,
    this.muteUntil,
    this.reportId,
  });

  final String id;
  final RoomModerationAction action;
  final String? targetUserId;
  final String? messageId;
  final DateTime? muteUntil;
  final String? reportId;
}
