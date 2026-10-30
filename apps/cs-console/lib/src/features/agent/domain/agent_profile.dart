import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_profile.freezed.dart';
part 'agent_profile.g.dart';

enum AgentStatus {
  online,
  busy,
  @JsonValue('break')
  onBreak,
  offline,
}

const agentStatusNames = {
  AgentStatus.online: 'online',
  AgentStatus.busy: 'busy',
  AgentStatus.onBreak: 'break',
  AgentStatus.offline: 'offline',
};

@freezed
abstract class AgentSettings with _$AgentSettings {
  const factory AgentSettings({
    @Default(5) int waitWarnMinutes,
    @Default(15) int waitLateMinutes,
    @Default(30) int idleLogoutMinutes,
    @Default('claim') String assignmentMode,
    @Default(<String, Map<String, String>>{}) Map<String, Map<String, String>> outcomes,
    @Default(<String, Map<String, String>>{}) Map<String, Map<String, String>> revealReasons,
  }) = _AgentSettings;

  factory AgentSettings.fromJson(Map<String, dynamic> json) => _$AgentSettingsFromJson(json);
}

@freezed
abstract class AgentProfile with _$AgentProfile {
  const factory AgentProfile({
    required String id,
    required String agentCode,
    required String displayName,
    @Default(<String>[]) List<String> roles,
    String? team,
    @Default(5) int maxActiveTickets,
    @JsonKey(unknownEnumValue: AgentStatus.offline) @Default(AgentStatus.offline) AgentStatus status,
    @Default(0) int activeTickets,
    @Default(AgentSettings()) AgentSettings settings,
  }) = _AgentProfile;

  factory AgentProfile.fromJson(Map<String, dynamic> json) => _$AgentProfileFromJson(json);

  const AgentProfile._();

  bool get isSupervisor => roles.contains('cs_supervisor');

  bool get isAdmin => roles.contains('cs_admin');

  bool get handlesTickets => isSupervisor || roles.contains('cs_agent');

  bool get atCapacity => activeTickets >= maxActiveTickets;
}

@freezed
abstract class OnlineAgent with _$OnlineAgent {
  const factory OnlineAgent({
    required String id,
    required String displayName,
    String? agentCode,
    @JsonKey(unknownEnumValue: AgentStatus.offline) @Default(AgentStatus.offline) AgentStatus status,
    @Default(0) int activeTickets,
    @Default(5) int maxActiveTickets,
    @Default(false) bool canTake,
  }) = _OnlineAgent;

  factory OnlineAgent.fromJson(Map<String, dynamic> json) => _$OnlineAgentFromJson(json);
}
