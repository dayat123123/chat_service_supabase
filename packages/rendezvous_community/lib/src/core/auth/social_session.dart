import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'social_session.freezed.dart';

@freezed
abstract class SocialSession with _$SocialSession {
  const factory SocialSession({required String accessToken, required DateTime expiresAt, required UserSummary user}) =
      _SocialSession;
}
