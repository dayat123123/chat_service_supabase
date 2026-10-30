import 'package:cs_console/src/features/supervisor/data/supervisor_repository.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

part 'report_cubit.freezed.dart';

enum ReportPreset { today, week, month, custom }

@freezed
abstract class ReportState with _$ReportState {
  const factory ReportState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(ReportPreset.week) ReportPreset preset,
    required DateTimeRange range,
    ReportSummary? report,
    Object? error,
  }) = _ReportState;
}

class ReportCubit extends Cubit<ReportState> {
  ReportCubit(this._supervisor, {DateTime Function()? today})
    : _today = today ?? _dateOnlyNow,
      super(ReportState(range: _presetRange(ReportPreset.week, (today ?? _dateOnlyNow)())));

  static const maxDays = 93;

  final SupervisorRepository _supervisor;
  final DateTime Function() _today;

  static DateTime _dateOnlyNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTimeRange _presetRange(ReportPreset preset, DateTime today) => switch (preset) {
    ReportPreset.today || ReportPreset.custom => DateTimeRange(start: today, end: today),
    ReportPreset.week => DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
    ReportPreset.month => DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
  };

  DateTime get today => _today();

  Future<void> usePreset(ReportPreset preset) => _load(preset, _presetRange(preset, _today()));

  Future<void> useRange(DateTimeRange range) => _load(ReportPreset.custom, range);

  Future<void> reload() => _load(state.preset, state.range);

  Future<void> _load(ReportPreset preset, DateTimeRange range) async {
    emit(state.copyWith(status: LoadStatus.loading, preset: preset, range: range, error: null));
    try {
      final report = await _supervisor.report(range.start, range.end);
      if (!isClosed && state.range == range) emit(state.copyWith(status: LoadStatus.ready, report: report));
    } catch (e) {
      if (!isClosed && state.range == range) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }
}
