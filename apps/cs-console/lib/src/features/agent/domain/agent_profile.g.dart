// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentSettings _$AgentSettingsFromJson(Map<String, dynamic> json) =>
    _AgentSettings(
      waitWarnMinutes: (json['wait_warn_minutes'] as num?)?.toInt() ?? 5,
      waitLateMinutes: (json['wait_late_minutes'] as num?)?.toInt() ?? 15,
      idleLogoutMinutes: (json['idle_logout_minutes'] as num?)?.toInt() ?? 30,
      assignmentMode: json['assignment_mode'] as String? ?? 'claim',
      outcomes:
          (json['outcomes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
          ) ??
          const <String, Map<String, String>>{},
      revealReasons:
          (json['reveal_reasons'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
          ) ??
          const <String, Map<String, String>>{},
    );

Map<String, dynamic> _$AgentSettingsToJson(_AgentSettings instance) =>
    <String, dynamic>{
      'wait_warn_minutes': instance.waitWarnMinutes,
      'wait_late_minutes': instance.waitLateMinutes,
      'idle_logout_minutes': instance.idleLogoutMinutes,
      'assignment_mode': instance.assignmentMode,
      'outcomes': instance.outcomes,
      'reveal_reasons': instance.revealReasons,
    };

_AgentProfile _$AgentProfileFromJson(Map<String, dynamic> json) =>
    _AgentProfile(
      id: json['id'] as String,
      agentCode: json['agent_code'] as String,
      displayName: json['display_name'] as String,
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      team: json['team'] as String?,
      maxActiveTickets: (json['max_active_tickets'] as num?)?.toInt() ?? 5,
      status:
          $enumDecodeNullable(
            _$AgentStatusEnumMap,
            json['status'],
            unknownValue: AgentStatus.offline,
          ) ??
          AgentStatus.offline,
      activeTickets: (json['active_tickets'] as num?)?.toInt() ?? 0,
      settings: json['settings'] == null
          ? const AgentSettings()
          : AgentSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AgentProfileToJson(_AgentProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agent_code': instance.agentCode,
      'display_name': instance.displayName,
      'roles': instance.roles,
      'team': instance.team,
      'max_active_tickets': instance.maxActiveTickets,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'active_tickets': instance.activeTickets,
      'settings': instance.settings.toJson(),
    };

const _$AgentStatusEnumMap = {
  AgentStatus.online: 'online',
  AgentStatus.busy: 'busy',
  AgentStatus.onBreak: 'break',
  AgentStatus.offline: 'offline',
};

_OnlineAgent _$OnlineAgentFromJson(Map<String, dynamic> json) => _OnlineAgent(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
  agentCode: json['agent_code'] as String?,
  status:
      $enumDecodeNullable(
        _$AgentStatusEnumMap,
        json['status'],
        unknownValue: AgentStatus.offline,
      ) ??
      AgentStatus.offline,
  activeTickets: (json['active_tickets'] as num?)?.toInt() ?? 0,
  maxActiveTickets: (json['max_active_tickets'] as num?)?.toInt() ?? 5,
  canTake: json['can_take'] as bool? ?? false,
);

Map<String, dynamic> _$OnlineAgentToJson(_OnlineAgent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'agent_code': instance.agentCode,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'active_tickets': instance.activeTickets,
      'max_active_tickets': instance.maxActiveTickets,
      'can_take': instance.canTake,
    };
