import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/poll/data/models/poll_model.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/features/poll/domain/repositories/poll_repository.dart';

class PollRepositoryImpl implements PollRepository {
  PollRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Poll> vote(String postId, String optionId) async {
    final result = await _api.rpcValue('vote_poll', {'p_post_id': postId, 'p_option_id': optionId});
    if (result is! Map) {
      throw const CommunityException(CommunityErrorKind.unknown, message: 'vote_poll returned no result');
    }
    return PollModel.fromJson(Map<String, dynamic>.from(result)).toEntity();
  }
}
