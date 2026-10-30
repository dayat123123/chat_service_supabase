import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'supervisor_models.freezed.dart';
part 'supervisor_models.g.dart';

@freezed
abstract class AlertThresholds with _$AlertThresholds {
  const factory AlertThresholds({
    @Default(10) int unclaimedMinutes,
    @Default(2) int p1UnclaimedMinutes,
  }) = _AlertThresholds;

  factory AlertThresholds.fromJson(Map<String, dynamic> json) => _$AlertThresholdsFromJson(json);
}

@freezed
abstract class AgentLoad with _$AgentLoad {
  const factory AgentLoad({
    required String id,
    required String displayName,
    String? agentCode,
    @Default(<String>[]) List<String> roles,
    @JsonKey(unknownEnumValue: AgentStatus.offline) @Default(AgentStatus.offline) AgentStatus status,
    @Default(false) bool connected,
    @Default(0) int activeTickets,
    @Default(5) int maxActiveTickets,
    @Default(0) int resolvedToday,
    DateTime? statusChangedAt,
  }) = _AgentLoad;

  factory AgentLoad.fromJson(Map<String, dynamic> json) => _$AgentLoadFromJson(json);
}

@freezed
abstract class SupervisorOverview with _$SupervisorOverview {
  const factory SupervisorOverview({
    required DateTime generatedAt,
    @Default(AlertThresholds()) AlertThresholds thresholds,
    @Default(0) int openCount,
    DateTime? oldestOpenAt,
    @Default(0) int activeCount,
    @Default(0) int resolvedToday,
    @Default(<Ticket>[]) List<Ticket> overdue,
    @Default(<Ticket>[]) List<Ticket> flaggedOpen,
    @Default(<Ticket>[]) List<Ticket> offlineOwned,
    @Default(<AgentLoad>[]) List<AgentLoad> agents,
  }) = _SupervisorOverview;

  factory SupervisorOverview.fromJson(Map<String, dynamic> json) => _$SupervisorOverviewFromJson(json);

  const SupervisorOverview._();

  int get onlineCount => agents.where((a) => a.status == AgentStatus.online).length;

  int get attentionCount => {for (final t in [...overdue, ...flaggedOpen, ...offlineOwned]) t.id}.length;
}

@freezed
abstract class ReportStats with _$ReportStats {
  const factory ReportStats({
    DateTime? day,
    @Default(0) int created,
    @Default(0) int resolved,
    double? avgClaimMinutes,
    double? avgFirstResponseMinutes,
    double? avgResolutionMinutes,
    double? avgRating,
    @Default(0) int ratings,
  }) = _ReportStats;

  factory ReportStats.fromJson(Map<String, dynamic> json) => _$ReportStatsFromJson(json);
}

@freezed
abstract class AgentReport with _$AgentReport {
  const factory AgentReport({
    required String id,
    required String displayName,
    String? agentCode,
    @Default(0) int handled,
    @Default(0) int resolved,
    double? avgFirstResponseMinutes,
    double? avgRating,
    @Default(0) int ratings,
  }) = _AgentReport;

  factory AgentReport.fromJson(Map<String, dynamic> json) => _$AgentReportFromJson(json);
}

@freezed
abstract class TopicCount with _$TopicCount {
  const factory TopicCount({required String topic, required String name, @Default(0) int count}) = _TopicCount;

  factory TopicCount.fromJson(Map<String, dynamic> json) => _$TopicCountFromJson(json);
}

@freezed
abstract class ReportSummary with _$ReportSummary {
  const factory ReportSummary({
    required DateTime from,
    required DateTime to,
    @Default(ReportStats()) ReportStats totals,
    @Default(<ReportStats>[]) List<ReportStats> daily,
    @Default(<AgentReport>[]) List<AgentReport> agents,
    @Default(<TopicCount>[]) List<TopicCount> topics,
  }) = _ReportSummary;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => _$ReportSummaryFromJson(json);
}
