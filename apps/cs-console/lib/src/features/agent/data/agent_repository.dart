import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';

class AgentRepository {
  AgentRepository(this._api);

  final CsApi _api;

  Future<AgentProfile> me() async => AgentProfile.fromJson(await _api.object('agent_me'));

  Future<AgentProfile> setStatus(AgentStatus status) async =>
      AgentProfile.fromJson(await _api.object('agent_set_status', {'p_status': agentStatusNames[status]}));

  Future<int> heartbeat() async =>
      ((await _api.object('agent_heartbeat'))['active_tickets'] as num?)?.toInt() ?? 0;

  Future<List<OnlineAgent>> colleagues() async => [
    for (final row in await _api.list('online_agents')) OnlineAgent.fromJson(row),
  ];
}
