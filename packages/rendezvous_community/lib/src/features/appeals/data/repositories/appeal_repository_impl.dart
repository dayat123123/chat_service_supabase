import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/appeals/data/models/appeal_model.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/domain/repositories/appeal_repository.dart';

class AppealRepositoryImpl implements AppealRepository {
  AppealRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Appeal> createAppeal(AppealTargetType targetType, String targetId, String reason) async {
    final json = jsonMap(
      await _api.rpcValue('create_appeal', {
        'p_target_type': targetType.name,
        'p_target_id': targetId,
        'p_reason': reason.trim(),
      }),
    );
    return AppealModel.fromJson(json).toEntity();
  }

  @override
  Future<List<Appeal>> myAppeals() async => [
    for (final row in await _api.rpcRows('get_my_appeals')) AppealModel.fromJson(row).toEntity(),
  ];

  @override
  Future<List<ModeratedContent>> myModeratedContent({int limit = 50}) async =>
      parseModeratedContent(await _api.rpcValue('get_my_moderated_content', {'p_limit': limit}));

  @override
  Future<List<Sanction>> mySanctions() async => [
    for (final row in await _api.rpcRows('get_my_sanctions')) SanctionModel.fromJson(row).toEntity(),
  ];
}
