import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';

part 'appeal_model.freezed.dart';
part 'appeal_model.g.dart';

@freezed
abstract class AppealModel with _$AppealModel {
  const factory AppealModel({
    required String id,
    required String targetType,
    required String targetId,
    @Default('') String reason,
    @Default('pending') String status,
    String? decisionNote,
    required DateTime createdAt,
    DateTime? decidedAt,
  }) = _AppealModel;

  const AppealModel._();

  factory AppealModel.fromJson(Map<String, dynamic> json) => _$AppealModelFromJson(json);

  Appeal toEntity() => Appeal(
    id: id,
    targetType: AppealTargetType.values.asNameMap()[targetType] ?? AppealTargetType.post,
    targetId: targetId,
    reason: reason,
    status: AppealStatus.values.asNameMap()[status] ?? AppealStatus.pending,
    decisionNote: decisionNote,
    createdAt: createdAt,
    decidedAt: decidedAt,
  );
}

List<ModeratedContent> parseModeratedContent(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map && item['id'] is String)
        ModeratedContent(
          type: AppealTargetType.values.asNameMap()[item['type']] ?? AppealTargetType.post,
          id: item['id'] as String,
          state: item['state'] == 'removed' ? ModeratedState.removed : ModeratedState.hidden,
          excerpt: item['excerpt'] as String?,
          decidedAt: DateTime.tryParse(item['decided_at'] as String? ?? ''),
          appeal: item['appeal'] is Map
              ? AppealModel.fromJson({
                  ...Map<String, dynamic>.from(item['appeal'] as Map),
                  'target_type': item['type'],
                  'target_id': item['id'],
                }).toEntity()
              : null,
        ),
];

@freezed
abstract class SanctionModel with _$SanctionModel {
  const factory SanctionModel({
    required String id,
    required String kind,
    String? category,
    String? reason,
    DateTime? startsAt,
    DateTime? endsAt,
  }) = _SanctionModel;

  const SanctionModel._();

  factory SanctionModel.fromJson(Map<String, dynamic> json) => _$SanctionModelFromJson(json);

  Sanction toEntity() =>
      Sanction(id: id, kind: kind, category: category, reason: reason, startsAt: startsAt, endsAt: endsAt);
}
