import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';

part 'client_config_model.freezed.dart';
part 'client_config_model.g.dart';

Map<String, bool> _flagsFromJson(Object? value) => {
  if (value is Map)
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value == true,
};

Map<String, String?> _versionsFromJson(Object? value) => {
  if (value is Map)
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value is String ? entry.value as String : null,
};

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];

@freezed
abstract class ClientConfigModel with _$ClientConfigModel {
  const factory ClientConfigModel({
    @Default(true) bool socialEnabled,
    @JsonKey(fromJson: _flagsFromJson) @Default(<String, bool>{}) Map<String, bool> flags,
    @JsonKey(fromJson: _versionsFromJson) @Default(<String, String?>{}) Map<String, String?> minVersion,
    @Default(false) bool updateRequired,
    @Default(<String, dynamic>{}) Map<String, dynamic> config,
  }) = _ClientConfigModel;

  const ClientConfigModel._();

  factory ClientConfigModel.fromJson(Map<String, dynamic> json) => _$ClientConfigModelFromJson(json);

  ClientConfig toEntity({DateTime? receivedAt}) {
    final received = (receivedAt ?? DateTime.now()).toUtc();
    final serverTime = DateTime.tryParse(config['server_time'] as String? ?? '');
    final reactions = _strings(config['message_reactions']);
    final windows = _strings(config['trending_windows']);
    return ClientConfig(
      socialEnabled: socialEnabled,
      flags: flags,
      minVersions: minVersion,
      updateRequired: updateRequired,
      editWindow: Duration(minutes: (config['edit_minutes'] as num?)?.toInt() ?? 15),
      messageReactions: reactions.isEmpty ? const ClientConfig().messageReactions : reactions,
      searchMinLength: (config['search_min_length'] as num?)?.toInt() ?? 2,
      notificationTypes: _strings(config['notification_types']),
      trendingWindows: windows.isEmpty ? const ClientConfig().trendingWindows : windows,
      notificationAggregateMinutes: (config['notification_aggregate_minutes'] as num?)?.toInt() ?? 60,
      clockSkew: serverTime == null ? Duration.zero : serverTime.toUtc().difference(received),
      fetchedAt: received,
    );
  }
}
