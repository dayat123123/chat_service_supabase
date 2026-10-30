import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/poll/data/models/poll_model.dart';
import 'package:olt_social/src/features/poll/domain/entities/poll.dart';
import 'package:olt_social/src/features/poll/domain/repositories/poll_repository.dart';

class PollRepositoryImpl implements PollRepository {
  PollRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Poll> vote(String postId, String optionId) async {
    final result = await _api.rpcValue('vote_poll', {'p_post_id': postId, 'p_option_id': optionId});
    if (result is! Map) throw const OltSocialException(OltSocialErrorKind.unknown, message: 'vote_poll kosong');
    return PollModel.fromJson(Map<String, dynamic>.from(result)).toEntity();
  }
}
