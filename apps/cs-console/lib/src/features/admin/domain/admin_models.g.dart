// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StaffAccount _$StaffAccountFromJson(Map<String, dynamic> json) =>
    _StaffAccount(
      id: json['id'] as String,
      agentCode: json['agent_code'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      team: json['team'] as String?,
      maxActiveTickets: (json['max_active_tickets'] as num?)?.toInt() ?? 5,
      disabledAt: json['disabled_at'] == null
          ? null
          : DateTime.parse(json['disabled_at'] as String),
      status:
          $enumDecodeNullable(
            _$AgentStatusEnumMap,
            json['status'],
            unknownValue: AgentStatus.offline,
          ) ??
          AgentStatus.offline,
      activeTickets: (json['active_tickets'] as num?)?.toInt() ?? 0,
      totp: json['totp'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$StaffAccountToJson(_StaffAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agent_code': instance.agentCode,
      'display_name': instance.displayName,
      'email': instance.email,
      'roles': instance.roles,
      'team': instance.team,
      'max_active_tickets': instance.maxActiveTickets,
      'disabled_at': instance.disabledAt?.toIso8601String(),
      'status': _$AgentStatusEnumMap[instance.status]!,
      'active_tickets': instance.activeTickets,
      'totp': instance.totp,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$AgentStatusEnumMap = {
  AgentStatus.online: 'online',
  AgentStatus.busy: 'busy',
  AgentStatus.onBreak: 'break',
  AgentStatus.offline: 'offline',
};

_AccountDraft _$AccountDraftFromJson(Map<String, dynamic> json) =>
    _AccountDraft(
      email: json['email'] as String?,
      displayName: json['display_name'] as String,
      roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
      team: json['team'] as String,
      maxActiveTickets: (json['max_active_tickets'] as num).toInt(),
      disabled: json['disabled'] as bool? ?? false,
    );

Map<String, dynamic> _$AccountDraftToJson(_AccountDraft instance) =>
    <String, dynamic>{
      'email': ?instance.email,
      'display_name': instance.displayName,
      'roles': instance.roles,
      'team': instance.team,
      'max_active_tickets': instance.maxActiveTickets,
      'disabled': instance.disabled,
    };

_CreatedAccount _$CreatedAccountFromJson(Map<String, dynamic> json) =>
    _CreatedAccount(
      agent: StaffAccount.fromJson(json['agent'] as Map<String, dynamic>),
      temporaryPassword: json['temporary_password'] as String,
    );

Map<String, dynamic> _$CreatedAccountToJson(_CreatedAccount instance) =>
    <String, dynamic>{
      'agent': instance.agent.toJson(),
      'temporary_password': instance.temporaryPassword,
    };

_Choice _$ChoiceFromJson(Map<String, dynamic> json) =>
    _Choice(code: json['code'] as String, name: json['name'] as String);

Map<String, dynamic> _$ChoiceToJson(_Choice instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
};

_AdminOptions _$AdminOptionsFromJson(Map<String, dynamic> json) =>
    _AdminOptions(
      teams:
          (json['teams'] as List<dynamic>?)
              ?.map((e) => Choice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Choice>[],
      skills:
          (json['skills'] as List<dynamic>?)
              ?.map((e) => Choice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Choice>[],
    );

Map<String, dynamic> _$AdminOptionsToJson(_AdminOptions instance) =>
    <String, dynamic>{
      'teams': instance.teams.map((e) => e.toJson()).toList(),
      'skills': instance.skills.map((e) => e.toJson()).toList(),
    };

_TopicConfig _$TopicConfigFromJson(Map<String, dynamic> json) => _TopicConfig(
  code: json['code'] as String,
  nameId: json['name_id'] as String,
  nameEn: json['name_en'] as String,
  skill: json['skill'] as String,
  defaultPriority: json['default_priority'] as String? ?? 'P3',
  helpUrl: json['help_url'] as String?,
  sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
  active: json['active'] as bool? ?? true,
);

Map<String, dynamic> _$TopicConfigToJson(_TopicConfig instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name_id': instance.nameId,
      'name_en': instance.nameEn,
      'skill': instance.skill,
      'default_priority': instance.defaultPriority,
      'help_url': instance.helpUrl,
      'sort_order': instance.sortOrder,
      'active': instance.active,
    };

_QuickReplyConfig _$QuickReplyConfigFromJson(Map<String, dynamic> json) =>
    _QuickReplyConfig(
      id: json['id'] as String?,
      shortcut: json['shortcut'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      language: json['language'] as String? ?? 'id',
      active: json['active'] as bool? ?? true,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$QuickReplyConfigToJson(_QuickReplyConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'shortcut': instance.shortcut,
      'title': instance.title,
      'body': instance.body,
      'language': instance.language,
      'active': instance.active,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

_SettingEntry _$SettingEntryFromJson(Map<String, dynamic> json) =>
    _SettingEntry(
      key: json['key'] as String,
      value: json['value'],
      description: json['description'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );

Map<String, dynamic> _$SettingEntryToJson(_SettingEntry instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'description': instance.description,
      'version': instance.version,
      'updated_at': instance.updatedAt?.toIso8601String(),
      'updated_by': instance.updatedBy,
    };

_Holiday _$HolidayFromJson(Map<String, dynamic> json) => _Holiday(
  day: DateTime.parse(json['day'] as String),
  name: json['name'] as String,
  kind:
      $enumDecodeNullable(
        _$HolidayKindEnumMap,
        json['kind'],
        unknownValue: HolidayKind.national,
      ) ??
      HolidayKind.national,
);

Map<String, dynamic> _$HolidayToJson(_Holiday instance) => <String, dynamic>{
  'day': instance.day.toIso8601String(),
  'name': instance.name,
  'kind': _$HolidayKindEnumMap[instance.kind]!,
};

const _$HolidayKindEnumMap = {
  HolidayKind.national: 'national',
  HolidayKind.collectiveLeave: 'collective_leave',
  HolidayKind.exchange: 'exchange',
};
