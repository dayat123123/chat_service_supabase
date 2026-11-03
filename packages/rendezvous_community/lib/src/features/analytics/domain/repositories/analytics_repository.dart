import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';

abstract interface class AnalyticsRepository {
  Future<AnalyticsResult> track(List<AnalyticsEvent> events, {String? platform, String? appVersion});
}
