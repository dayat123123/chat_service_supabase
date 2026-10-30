import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/features/supervisor/presentation/report_csv.dart';
import 'package:cs_console/src/l10n/gen/console_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _stats(int created, int resolved, {String? day}) => {
  'day': ?day,
  'created': created,
  'resolved': resolved,
  'avg_claim_minutes': 4.5,
  'avg_first_response_minutes': 6,
  'avg_resolution_minutes': null,
  'avg_rating': 4.5,
  'ratings': 2,
};

void main() {
  final csv = ReportCsv(lookupConsoleLocalizations(const Locale('id')));
  final report = ReportSummary.fromJson({
    'from': '2026-10-29',
    'to': '2026-10-30',
    'totals': _stats(5, 3),
    'daily': [_stats(3, 2, day: '2026-10-29'), _stats(2, 1, day: '2026-10-30')],
    'agents': [
      {
        'id': 'a-1',
        'display_name': '=cmd|calc',
        'agent_code': 'CS-0045',
        'handled': 4,
        'resolved': 3,
        'avg_first_response_minutes': 2.5,
        'avg_rating': 5,
        'ratings': 1,
      },
    ],
    'topics': [
      {'topic': 'orders', 'name': 'Order, Transaksi', 'count': 4},
    ],
  });

  test('sel CSV dinetralkan dari formula dan dikutip bila perlu', () {
    expect(ReportCsv.cell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    expect(ReportCsv.cell('@SUM(A1)'), "'@SUM(A1)");
    expect(ReportCsv.cell('-2+3'), "'-2+3");
    expect(ReportCsv.cell('Sari, W.'), '"Sari, W."');
    expect(ReportCsv.cell(4.5), '4.5');
    expect(ReportCsv.cell(null), '');
  });

  test('CSV harian berisi header, satu baris per hari, dan total', () {
    final lines = csv.build(report, ReportExport.daily).split('\r\n')..removeLast();

    expect(lines, hasLength(4));
    expect(lines.first.split(','), hasLength(8));
    expect(lines[1], '2026-10-29,3,2,4.5,6.0,,4.5,2');
    expect(lines[3], 'Total,5,3,4.5,6.0,,4.5,2');
  });

  test('CSV per CS dan topik aman dari injeksi formula', () {
    expect(csv.build(report, ReportExport.agents).split('\r\n')[1], "'=cmd|calc,CS-0045,4,3,2.5,5.0,1");
    expect(csv.build(report, ReportExport.topics).split('\r\n')[1], 'orders,"Order, Transaksi",4');
  });

  test('nama file memuat jenis laporan dan rentang tanggal', () {
    expect(csv.fileName(report, ReportExport.agents), 'laporan-cs-agents-2026-10-29-2026-10-30.csv');
  });
}
