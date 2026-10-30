import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_models.freezed.dart';
part 'admin_models.g.dart';

const staffRoles = ['cs_agent', 'cs_supervisor', 'cs_admin', 'compliance'];

@freezed
abstract class StaffAccount with _$StaffAccount {
  const factory StaffAccount({
    required String id,
    required String agentCode,
    required String displayName,
    String? email,
    @Default(<String>[]) List<String> roles,
    String? team,
    @Default(5) int maxActiveTickets,
    DateTime? disabledAt,
    @JsonKey(unknownEnumValue: AgentStatus.offline) @Default(AgentStatus.offline) AgentStatus status,
    @Default(0) int activeTickets,
    @Default(false) bool totp,
    DateTime? createdAt,
  }) = _StaffAccount;

  factory StaffAccount.fromJson(Map<String, dynamic> json) => _$StaffAccountFromJson(json);

  const StaffAccount._();

  bool get disabled => disabledAt != null;
}

@freezed
abstract class AccountDraft with _$AccountDraft {
  const factory AccountDraft({
    @JsonKey(includeIfNull: false) String? email,
    required String displayName,
    required List<String> roles,
    required String team,
    required int maxActiveTickets,
    @Default(false) bool disabled,
  }) = _AccountDraft;

  factory AccountDraft.fromJson(Map<String, dynamic> json) => _$AccountDraftFromJson(json);
}

@freezed
abstract class CreatedAccount with _$CreatedAccount {
  const factory CreatedAccount({required StaffAccount agent, required String temporaryPassword}) = _CreatedAccount;

  factory CreatedAccount.fromJson(Map<String, dynamic> json) => _$CreatedAccountFromJson(json);
}

@freezed
abstract class Choice with _$Choice {
  const factory Choice({required String code, required String name}) = _Choice;

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);
}

@freezed
abstract class AdminOptions with _$AdminOptions {
  const factory AdminOptions({
    @Default(<Choice>[]) List<Choice> teams,
    @Default(<Choice>[]) List<Choice> skills,
  }) = _AdminOptions;

  factory AdminOptions.fromJson(Map<String, dynamic> json) => _$AdminOptionsFromJson(json);
}

@freezed
abstract class TopicConfig with _$TopicConfig {
  const factory TopicConfig({
    required String code,
    required String nameId,
    required String nameEn,
    required String skill,
    @Default('P3') String defaultPriority,
    String? helpUrl,
    @Default(100) int sortOrder,
    @Default(true) bool active,
  }) = _TopicConfig;

  factory TopicConfig.fromJson(Map<String, dynamic> json) => _$TopicConfigFromJson(json);
}

@freezed
abstract class QuickReplyConfig with _$QuickReplyConfig {
  const factory QuickReplyConfig({
    String? id,
    required String shortcut,
    required String title,
    required String body,
    @Default('id') String language,
    @Default(true) bool active,
    DateTime? updatedAt,
  }) = _QuickReplyConfig;

  factory QuickReplyConfig.fromJson(Map<String, dynamic> json) => _$QuickReplyConfigFromJson(json);
}

@freezed
abstract class SettingEntry with _$SettingEntry {
  const factory SettingEntry({
    required String key,
    required Object? value,
    String? description,
    @Default(1) int version,
    DateTime? updatedAt,
    String? updatedBy,
  }) = _SettingEntry;

  factory SettingEntry.fromJson(Map<String, dynamic> json) => _$SettingEntryFromJson(json);
}

enum HolidayKind {
  national,
  @JsonValue('collective_leave')
  collectiveLeave,
  exchange,
}

const holidayKindNames = {
  HolidayKind.national: 'national',
  HolidayKind.collectiveLeave: 'collective_leave',
  HolidayKind.exchange: 'exchange',
};

@freezed
abstract class Holiday with _$Holiday {
  const factory Holiday({
    required DateTime day,
    required String name,
    @JsonKey(unknownEnumValue: HolidayKind.national) @Default(HolidayKind.national) HolidayKind kind,
  }) = _Holiday;

  factory Holiday.fromJson(Map<String, dynamic> json) => _$HolidayFromJson(json);
}
