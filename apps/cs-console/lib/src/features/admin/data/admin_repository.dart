import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  AdminRepository(this._api, this._functions);

  final CsApi _api;
  final FunctionsClient _functions;
  Future<AdminOptions>? _options;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<List<StaffAccount>> accounts() async => [
    for (final row in await _api.list('admin_agents')) StaffAccount.fromJson(row),
  ];

  Future<AdminOptions> options() =>
      _options ??= _api.object('admin_options').then(AdminOptions.fromJson).catchError((Object error) {
        _options = null;
        throw error;
      });

  Future<CreatedAccount> createAccount(AccountDraft draft) async =>
      CreatedAccount.fromJson(await _invoke('cs-admin/agents', HttpMethod.post, draft.toJson()));

  Future<StaffAccount> updateAccount(String id, AccountDraft draft) async {
    final body = draft.toJson()..remove('email');
    final data = await _invoke('cs-admin/agents/$id', HttpMethod.patch, body);
    return StaffAccount.fromJson(data['agent'] as Map<String, dynamic>);
  }

  Future<List<TopicConfig>> topics() async => [
    for (final row in await _api.list('admin_topics')) TopicConfig.fromJson(row),
  ];

  Future<List<TopicConfig>> saveTopic(TopicConfig topic) async => [
    for (final row in await _api.list('admin_save_topic', {
      'p_code': topic.code,
      'p_name_id': topic.nameId,
      'p_name_en': topic.nameEn,
      'p_skill': topic.skill,
      'p_default_priority': topic.defaultPriority,
      'p_help_url': topic.helpUrl,
      'p_sort_order': topic.sortOrder,
      'p_active': topic.active,
    }))
      TopicConfig.fromJson(row),
  ];

  Future<List<QuickReplyConfig>> quickReplies() async => [
    for (final row in await _api.list('admin_quick_replies')) QuickReplyConfig.fromJson(row),
  ];

  Future<List<QuickReplyConfig>> saveQuickReply(QuickReplyConfig reply) async => [
    for (final row in await _api.list('admin_save_quick_reply', {
      'p_id': reply.id,
      'p_shortcut': reply.shortcut,
      'p_title': reply.title,
      'p_body': reply.body,
      'p_language': reply.language,
      'p_active': reply.active,
    }))
      QuickReplyConfig.fromJson(row),
  ];

  Future<List<SettingEntry>> settings() async => [
    for (final row in await _api.list('admin_settings')) SettingEntry.fromJson(row),
  ];

  Future<SettingEntry> setSetting(String key, Object? value) async =>
      SettingEntry.fromJson(await _api.object('admin_set_setting', {'p_key': key, 'p_value': value}));

  Future<List<Holiday>> holidays(int year) async => [
    for (final row in await _api.list('admin_holidays', {'p_year': year})) Holiday.fromJson(row),
  ];

  Future<List<Holiday>> saveHoliday(Holiday holiday) async => [
    for (final row in await _api.list('admin_save_holiday', {
      'p_day': _day.format(holiday.day),
      'p_name': holiday.name,
      'p_kind': holidayKindNames[holiday.kind],
    }))
      Holiday.fromJson(row),
  ];

  Future<List<Holiday>> deleteHoliday(DateTime day) async => [
    for (final row in await _api.list('admin_delete_holiday', {'p_day': _day.format(day)})) Holiday.fromJson(row),
  ];

  Future<Map<String, dynamic>> _invoke(String path, HttpMethod method, Map<String, dynamic> body) async {
    try {
      final response = await _functions.invoke(path, method: method, body: body);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ConsoleError.from(e);
    }
  }
}
