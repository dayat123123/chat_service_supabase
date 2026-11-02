import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';

abstract interface class PollRepository {
  Future<Poll> vote(String postId, String optionId);
}
