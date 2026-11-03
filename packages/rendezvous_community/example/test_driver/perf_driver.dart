import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

const _scenarios = ['feed_scroll', 'chat_scroll'];

double _budget(String name, double fallback) => double.tryParse(Platform.environment[name] ?? '') ?? fallback;

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * p).round();
  return sorted[index];
}

Map<String, Object> _stats(List<num> micros) {
  final ms = [for (final value in micros) value / 1000]..sort();
  final average = ms.isEmpty ? 0.0 : ms.reduce((a, b) => a + b) / ms.length;
  return {
    'average_ms': double.parse(average.toStringAsFixed(2)),
    'p90_ms': double.parse(_percentile(ms, 0.9).toStringAsFixed(2)),
    'p99_ms': double.parse(_percentile(ms, 0.99).toStringAsFixed(2)),
    'worst_ms': double.parse((ms.isEmpty ? 0.0 : ms.last).toStringAsFixed(2)),
  };
}

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) throw StateError('perf test returned no timeline data');
    final p90Build = _budget('PERF_P90_BUILD_MS', 8);
    final p90Raster = _budget('PERF_P90_RASTER_MS', 16);
    final maxFrame = _budget('PERF_MAX_FRAME_MS', 32);
    final failures = <String>[];
    final report = <String, Object?>{
      'budgets': {'p90_build_ms': p90Build, 'p90_raster_ms': p90Raster, 'max_frame_ms_after_first': maxFrame},
      'memory': data['memory'],
    };
    for (final scenario in _scenarios) {
      final timeline = driver.Timeline.fromJson(data[scenario] as Map<String, dynamic>);
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(scenario, pretty: true, includeSummary: true);
      final json = summary.summaryJson;
      final frames = (data['${scenario}_frames'] as Map<String, dynamic>?) ?? json;
      final build = [for (final value in frames['frame_build_times'] as List<dynamic>) value as num];
      final raster = [for (final value in frames['frame_rasterizer_times'] as List<dynamic>) value as num];
      final buildStats = _stats(build);
      final rasterStats = _stats(raster);
      final slow = <String>[
        for (var i = 1; i < build.length; i++)
          if (build[i] / 1000 > maxFrame) 'build#$i=${(build[i] / 1000).toStringAsFixed(1)}ms',
        for (var i = 1; i < raster.length; i++)
          if (raster[i] / 1000 > maxFrame) 'raster#$i=${(raster[i] / 1000).toStringAsFixed(1)}ms',
      ];
      report[scenario] = {
        'frames': build.length,
        'timeline_frames': json['frame_count'],
        'build': buildStats,
        'raster': rasterStats,
        'missed_build_budget': frames['missed_frame_build_budget_count'],
        'missed_raster_budget': frames['missed_frame_rasterizer_budget_count'],
        'slow_frames_after_first': slow,
      };
      if ((buildStats['p90_ms']! as double) > p90Build) failures.add('$scenario p90 build ${buildStats['p90_ms']} ms');
      if ((rasterStats['p90_ms']! as double) > p90Raster) {
        failures.add('$scenario p90 raster ${rasterStats['p90_ms']} ms');
      }
      if (slow.isNotEmpty) failures.add('$scenario frames over $maxFrame ms: ${slow.take(5).join(', ')}');
    }
    final text = const JsonEncoder.withIndent('  ').convert(report);
    final file = File('build/perf_scroll_report.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
    stdout.writeln(text);
    if (failures.isNotEmpty) {
      stderr.writeln('Performance budgets exceeded:\n${failures.join('\n')}');
      exitCode = 1;
      throw StateError(failures.join('; '));
    }
  },
);
