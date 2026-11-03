import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'message_request_model.freezed.dart';
part 'message_request_model.g.dart';

@freezed
abstract class MessageRequestModel with _$MessageRequestModel {
  const factory MessageRequestModel({
    required String roomId,
    required String senderId,
    @Default('') String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isVerified,
    @Default(0) int messageCount,
    @Default(false) bool hasImage,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    required DateTime createdAt,
  }) = _MessageRequestModel;

  const MessageRequestModel._();

  factory MessageRequestModel.fromJson(Map<String, dynamic> json) => _$MessageRequestModelFromJson(json);

  MessageRequest toEntity() => MessageRequest(
    roomId: roomId,
    sender: UserSummary(
      id: senderId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
    ),
    messageCount: messageCount,
    hasImage: hasImage,
    lastMessagePreview: lastMessagePreview,
    lastMessageAt: lastMessageAt,
    createdAt: createdAt,
  );
}

DmRequestState parseDmRequestState(Object? value) {
  final json = value is Map ? value : const <String, Object?>{};
  if (json['is_request'] != true) return const DmRequestState();
  return DmRequestState(
    isRequest: true,
    role: DmRequestRole.values.asNameMap()[json['role']],
    declined: json['status'] == 'declined',
    sent: (json['sent'] as num?)?.toInt() ?? 0,
    maxMessages: (json['max_messages'] as num?)?.toInt() ?? defaultRequestMaxMessages,
  );
}

DmPolicySettings parseDmPolicy(Object? value) {
  final json = value is Map ? value : const <String, Object?>{};
  return DmPolicySettings(
    policy: DmPolicy.values.asNameMap()[json['policy']] ?? DmPolicy.everyone,
    requestMaxMessages: (json['request_max_messages'] as num?)?.toInt() ?? defaultRequestMaxMessages,
  );
}
