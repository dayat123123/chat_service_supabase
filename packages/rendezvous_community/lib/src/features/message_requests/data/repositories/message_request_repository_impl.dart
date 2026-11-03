import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/message_requests/data/models/message_request_model.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';

class MessageRequestRepositoryImpl implements MessageRequestRepository {
  MessageRequestRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<List<MessageRequest>> getRequests({int limit = 50, DateTime? before}) async {
    final rows = await _api.rpcRows('get_message_requests', {
      'p_limit': limit,
      'p_before': before?.toUtc().toIso8601String(),
    });
    return [for (final row in rows) MessageRequestModel.fromJson(row).toEntity()];
  }

  @override
  Future<int> requestCount() async => ((await _api.rpcValue('get_message_request_count')) as num?)?.toInt() ?? 0;

  @override
  Future<void> respond(String roomId, MessageRequestAction action) =>
      _api.rpcValue('respond_message_request', {'p_room_id': roomId, 'p_action': action.name});

  @override
  Future<DmRequestState> requestState(String roomId) async =>
      parseDmRequestState(await _api.rpcValue('get_dm_request_state', {'p_room_id': roomId}));

  @override
  Future<DmPolicySettings> dmPolicy() async => parseDmPolicy(await _api.rpcValue('get_dm_policy'));

  @override
  Future<DmPolicySettings> setDmPolicy(DmPolicy policy) async =>
      parseDmPolicy(await _api.rpcValue('set_dm_policy', {'p_policy': policy.name}));
}
