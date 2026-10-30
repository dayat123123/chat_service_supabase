// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supervisor_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AlertThresholds _$AlertThresholdsFromJson(Map<String, dynamic> json) =>
    _AlertThresholds(
      unclaimedMinutes: (json['unclaimed_minutes'] as num?)?.toInt() ?? 10,
      p1UnclaimedMinutes: (json['p1_unclaimed_minutes'] as num?)?.toInt() ?? 2,
    );

Map<String, dynamic> _$AlertThresholdsToJson(_AlertThresholds instance) =>
    <String, dynamic>{
      'unclaimed_minutes': instance.unclaimedMinutes,
      'p1_unclaimed_minutes': instance.p1UnclaimedMinutes,
    };

_AgentLoad _$AgentLoadFromJson(Map<String, dynamic> json) => _AgentLoad(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
  agentCode: json['agent_code'] as String?,
  roles:
      (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  status:
      $enumDecodeNullable(
        _$AgentStatusEnumMap,
        json['status'],
        unknownValue: AgentStatus.offline,
      ) ??
      AgentStatus.offline,
  connected: json['connected'] as bool? ?? false,
  activeTickets: (json['active_tickets'] as num?)?.toInt() ?? 0,
  maxActiveTickets: (json['max_active_tickets'] as num?)?.toInt() ?? 5,
  resolvedToday: (json['resolved_today'] as num?)?.toInt() ?? 0,
  statusChangedAt: json['status_changed_at'] == null
      ? null
      : DateTime.parse(json['status_changed_at'] as String),
);

Map<String, dynamic> _$AgentLoadToJson(_AgentLoad instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'agent_code': instance.agentCode,
      'roles': instance.roles,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'connected': instance.connected,
      'active_tickets': instance.activeTickets,
      'max_active_tickets': instance.maxActiveTickets,
      'resolved_today': instance.resolvedToday,
      'status_changed_at': instance.statusChangedAt?.toIso8601String(),
    };

const _$AgentStatusEnumMap = {
  AgentStatus.online: 'online',
  AgentStatus.busy: 'busy',
  AgentStatus.onBreak: 'break',
  AgentStatus.offline: 'offline',
};

_SupervisorOverview _$SupervisorOverviewFromJson(Map<String, dynamic> json) =>
    _SupervisorOverview(
      generatedAt: DateTime.parse(json['generated_at'] as String),
      thresholds: json['thresholds'] == null
          ? const AlertThresholds()
          : AlertThresholds.fromJson(
              json['thresholds'] as Map<String, dynamic>,
            ),
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      oldestOpenAt: json['oldest_open_at'] == null
          ? null
          : DateTime.parse(json['oldest_open_at'] as String),
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      resolvedToday: (json['resolved_today'] as num?)?.toInt() ?? 0,
      overdue:
          (json['overdue'] as List<dynamic>?)
              ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Ticket>[],
      flaggedOpen:
          (json['flagged_open'] as List<dynamic>?)
              ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Ticket>[],
      offlineOwned:
          (json['offline_owned'] as List<dynamic>?)
              ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Ticket>[],
      agents:
          (json['agents'] as List<dynamic>?)
              ?.map((e) => AgentLoad.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AgentLoad>[],
    );

Map<String, dynamic> _$SupervisorOverviewToJson(_SupervisorOverview instance) =>
    <String, dynamic>{
      'generated_at': instance.generatedAt.toIso8601String(),
      'thresholds': instance.thresholds.toJson(),
      'open_count': instance.openCount,
      'oldest_open_at': instance.oldestOpenAt?.toIso8601String(),
      'active_count': instance.activeCount,
      'resolved_today': instance.resolvedToday,
      'overdue': instance.overdue.map((e) => e.toJson()).toList(),
      'flagged_open': instance.flaggedOpen.map((e) => e.toJson()).toList(),
      'offline_owned': instance.offlineOwned.map((e) => e.toJson()).toList(),
      'agents': instance.agents.map((e) => e.toJson()).toList(),
    };

_ReportStats _$ReportStatsFromJson(Map<String, dynamic> json) => _ReportStats(
  day: json['day'] == null ? null : DateTime.parse(json['day'] as String),
  created: (json['created'] as num?)?.toInt() ?? 0,
  resolved: (json['resolved'] as num?)?.toInt() ?? 0,
  avgClaimMinutes: (json['avg_claim_minutes'] as num?)?.toDouble(),
  avgFirstResponseMinutes: (json['avg_first_response_minutes'] as num?)
      ?.toDouble(),
  avgResolutionMinutes: (json['avg_resolution_minutes'] as num?)?.toDouble(),
  avgRating: (json['avg_rating'] as num?)?.toDouble(),
  ratings: (json['ratings'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ReportStatsToJson(_ReportStats instance) =>
    <String, dynamic>{
      'day': instance.day?.toIso8601String(),
      'created': instance.created,
      'resolved': instance.resolved,
      'avg_claim_minutes': instance.avgClaimMinutes,
      'avg_first_response_minutes': instance.avgFirstResponseMinutes,
      'avg_resolution_minutes': instance.avgResolutionMinutes,
      'avg_rating': instance.avgRating,
      'ratings': instance.ratings,
    };

_AgentReport _$AgentReportFromJson(Map<String, dynamic> json) => _AgentReport(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
  agentCode: json['agent_code'] as String?,
  handled: (json['handled'] as num?)?.toInt() ?? 0,
  resolved: (json['resolved'] as num?)?.toInt() ?? 0,
  avgFirstResponseMinutes: (json['avg_first_response_minutes'] as num?)
      ?.toDouble(),
  avgRating: (json['avg_rating'] as num?)?.toDouble(),
  ratings: (json['ratings'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$AgentReportToJson(_AgentReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'agent_code': instance.agentCode,
      'handled': instance.handled,
      'resolved': instance.resolved,
      'avg_first_response_minutes': instance.avgFirstResponseMinutes,
      'avg_rating': instance.avgRating,
      'ratings': instance.ratings,
    };

_TopicCount _$TopicCountFromJson(Map<String, dynamic> json) => _TopicCount(
  topic: json['topic'] as String,
  name: json['name'] as String,
  count: (json['count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TopicCountToJson(_TopicCount instance) =>
    <String, dynamic>{
      'topic': instance.topic,
      'name': instance.name,
      'count': instance.count,
    };

_ReportSummary _$ReportSummaryFromJson(Map<String, dynamic> json) =>
    _ReportSummary(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      totals: json['totals'] == null
          ? const ReportStats()
          : ReportStats.fromJson(json['totals'] as Map<String, dynamic>),
      daily:
          (json['daily'] as List<dynamic>?)
              ?.map((e) => ReportStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReportStats>[],
      agents:
          (json['agents'] as List<dynamic>?)
              ?.map((e) => AgentReport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AgentReport>[],
      topics:
          (json['topics'] as List<dynamic>?)
              ?.map((e) => TopicCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TopicCount>[],
    );

Map<String, dynamic> _$ReportSummaryToJson(_ReportSummary instance) =>
    <String, dynamic>{
      'from': instance.from.toIso8601String(),
      'to': instance.to.toIso8601String(),
      'totals': instance.totals.toJson(),
      'daily': instance.daily.map((e) => e.toJson()).toList(),
      'agents': instance.agents.map((e) => e.toJson()).toList(),
      'topics': instance.topics.map((e) => e.toJson()).toList(),
    };
