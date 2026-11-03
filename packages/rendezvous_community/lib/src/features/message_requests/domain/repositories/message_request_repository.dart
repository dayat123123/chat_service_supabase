import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';

abstract interface class MessageRequestRepository {
  Future<List<MessageRequest>> getRequests({int limit = 50, DateTime? before});

  Future<int> requestCount();

  Future<void> respond(String roomId, MessageRequestAction action);

  Future<DmRequestState> requestState(String roomId);

  Future<DmPolicySettings> dmPolicy();

  Future<DmPolicySettings> setDmPolicy(DmPolicy policy);
}
