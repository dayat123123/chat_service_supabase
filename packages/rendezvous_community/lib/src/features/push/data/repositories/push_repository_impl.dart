import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';
import 'package:rendezvous_community/src/features/push/domain/repositories/push_repository.dart';

class PushRepositoryImpl implements PushRepository {
  PushRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<void> register(CommunityPushRegistration registration) => _api.rpcValue('register_push_device', {
    'p_token': registration.token,
    'p_platform': registration.platform.name,
    'p_locale': registration.locale,
    'p_app_version': registration.appVersion,
  });

  @override
  Future<void> unregister(String token) => _api.rpcValue('unregister_push_device', {'p_token': token});
}
