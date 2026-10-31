import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'user_summary_model.freezed.dart';
part 'user_summary_model.g.dart';

@freezed
abstract class UserSummaryModel with _$UserSummaryModel {
  const factory UserSummaryModel({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isVerified,
  }) = _UserSummaryModel;

  const UserSummaryModel._();

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) => _$UserSummaryModelFromJson(json);

  UserSummary toEntity() =>
      UserSummary(id: id, username: username, displayName: displayName, avatarUrl: avatarUrl, isVerified: isVerified);
}
