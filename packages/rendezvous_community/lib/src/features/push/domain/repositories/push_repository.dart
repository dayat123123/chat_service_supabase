import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';

abstract interface class PushRepository {
  Future<void> register(CommunityPushRegistration registration);

  Future<void> unregister(String token);
}
