import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:intl/intl.dart';

enum ReportExport { daily, agents, topics }

class ReportCsv {
  const ReportCsv(this._l10n);

  final ConsoleLocalizations _l10n;

  static final _day = DateFormat('yyyy-MM-dd');
  static final _formula = RegExp(r'^[=+\-@\t\r]');
  static final _quoted = RegExp(r'[",\r\n]');

  String fileName(ReportSummary report, ReportExport kind) =>
      'laporan-cs-${kind.name}-${_day.format(report.from)}-${_day.format(report.to)}.csv';

  String build(ReportSummary report, ReportExport kind) => switch (kind) {
    ReportExport.daily => _rows([
      [
        _l10n.reportDate,
        _l10n.reportCreated,
        _l10n.reportResolved,
        _l10n.reportClaimMinutes,
        _l10n.reportFirstResponseMinutes,
        _l10n.reportResolutionMinutes,
        _l10n.reportAvgRating,
        _l10n.reportRatings,
      ],
      for (final d in report.daily) [d.day == null ? null : _day.format(d.day!), ..._stats(d)],
      [_l10n.reportTotal, ..._stats(report.totals)],
    ]),
    ReportExport.agents => _rows([
      [
        _l10n.reportAgent,
        _l10n.reportAgentCode,
        _l10n.reportHandled,
        _l10n.reportResolved,
        _l10n.reportFirstResponseMinutes,
        _l10n.reportAvgRating,
        _l10n.reportRatings,
      ],
      for (final a in report.agents)
        [a.displayName, a.agentCode, a.handled, a.resolved, a.avgFirstResponseMinutes, a.avgRating, a.ratings],
    ]),
    ReportExport.topics => _rows([
      [_l10n.reportTopicCode, _l10n.reportTopic, _l10n.reportCount],
      for (final t in report.topics) [t.topic, t.name, t.count],
    ]),
  };

  List<Object?> _stats(ReportStats s) => [
    s.created,
    s.resolved,
    s.avgClaimMinutes,
    s.avgFirstResponseMinutes,
    s.avgResolutionMinutes,
    s.avgRating,
    s.ratings,
  ];

  String _rows(List<List<Object?>> rows) => rows.map((row) => '${row.map(cell).join(',')}\r\n').join();

  static String cell(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    var text = value.toString();
    if (_formula.hasMatch(text)) text = "'$text";
    return _quoted.hasMatch(text) ? '"${text.replaceAll('"', '""')}"' : text;
  }
}
