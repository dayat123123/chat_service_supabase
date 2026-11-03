import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<AnalyticsResult> track(List<AnalyticsEvent> events, {String? platform, String? appVersion}) async {
    final json = jsonMap(
      await _api.rpcValue('track_events', {
        'p_events': [for (final e in events) e.toJson()],
        'p_platform': platform,
        'p_app_version': appVersion,
      }),
    );
    return AnalyticsResult(
      accepted: (json['accepted'] as num?)?.toInt() ?? 0,
      dropped: (json['dropped'] as num?)?.toInt() ?? 0,
      disabled: json['disabled'] == true,
    );
  }
}
