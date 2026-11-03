import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/config/data/models/client_config_model.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/domain/repositories/client_config_repository.dart';

class ClientConfigRepositoryImpl implements ClientConfigRepository {
  ClientConfigRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<ClientConfig> fetch({String? platform, String? appVersion}) async {
    final params = {'p_platform': platform, 'p_app_version': appVersion};
    final value = _api.currentUserId == null
        ? await _api.anonymousRpcValue('get_client_config', params)
        : await _api.rpcValue('get_client_config', params);
    if (value is! Map) {
      throw const CommunityException(CommunityErrorKind.unknown, message: 'get_client_config returned no object');
    }
    return ClientConfigModel.fromJson(Map<String, dynamic>.from(value)).toEntity();
  }
}
