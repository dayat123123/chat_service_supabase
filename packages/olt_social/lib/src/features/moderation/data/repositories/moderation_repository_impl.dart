import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/moderation/domain/entities/report.dart';
import 'package:olt_social/src/features/moderation/domain/repositories/moderation_repository.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  ModerationRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final me = await _api.requireUserId();
    await _api.insertIgnoringDuplicate('reports', {
      'reporter_id': me,
      'target_type': target.name,
      'target_id': targetId,
      'reason': reason.wireName,
      'details': details,
    });
  }
}
