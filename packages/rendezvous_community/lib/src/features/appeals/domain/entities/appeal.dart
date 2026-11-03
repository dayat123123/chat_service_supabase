import 'package:freezed_annotation/freezed_annotation.dart';

part 'appeal.freezed.dart';

enum AppealTargetType { sanction, post, comment, message }

enum AppealStatus { pending, accepted, rejected }

enum ModeratedState { hidden, removed }

const minAppealReasonLength = 10;
const maxAppealReasonLength = 1000;

@freezed
abstract class Appeal with _$Appeal {
  const factory Appeal({
    required String id,
    required AppealTargetType targetType,
    required String targetId,
    @Default('') String reason,
    @Default(AppealStatus.pending) AppealStatus status,
    String? decisionNote,
    required DateTime createdAt,
    DateTime? decidedAt,
  }) = _Appeal;
}

@freezed
abstract class ModeratedContent with _$ModeratedContent {
  const factory ModeratedContent({
    required AppealTargetType type,
    required String id,
    required ModeratedState state,
    String? excerpt,
    DateTime? decidedAt,
    Appeal? appeal,
  }) = _ModeratedContent;
}

@freezed
abstract class Sanction with _$Sanction {
  const factory Sanction({
    required String id,
    required String kind,
    String? category,
    String? reason,
    DateTime? startsAt,
    DateTime? endsAt,
  }) = _Sanction;
}
