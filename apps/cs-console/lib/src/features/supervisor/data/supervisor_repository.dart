import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:intl/intl.dart';

class SupervisorRepository {
  SupervisorRepository(this._api);

  final CsApi _api;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<SupervisorOverview> overview() async => SupervisorOverview.fromJson(await _api.object('supervisor_overview'));

  Future<ReportSummary> report(DateTime from, DateTime to) async => ReportSummary.fromJson(
    await _api.object('report_summary', {'p_from': _day.format(from), 'p_to': _day.format(to)}),
  );
}
