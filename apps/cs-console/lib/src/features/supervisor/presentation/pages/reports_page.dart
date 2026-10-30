import 'package:cs_console/src/core/browser/file_download.dart';
import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/report_cubit.dart';
import 'package:cs_console/src/features/supervisor/presentation/report_csv.dart';
import 'package:cs_console/src/features/supervisor/presentation/widgets/stat_card.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) {
        final report = state.report;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.reportsTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      _rangeText(state.range),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PresetPicker(),
                    const SizedBox(width: 12),
                    _ExportMenu(report: state.status == LoadStatus.ready ? report : null),
                  ],
                ),
              ],
            ),
            if (state.status == LoadStatus.loading) const LinearProgressIndicator(minHeight: 2),
            if (state.status == LoadStatus.failure)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(errorText(context, state.error!)),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: context.read<ReportCubit>().reload, child: Text(l10n.retry)),
                  ],
                ),
              )
            else if (report != null)
              _ReportBody(report: report),
          ],
        );
      },
    );
  }

  static String _rangeText(DateTimeRange range) {
    final format = DateFormat('d MMM yyyy', 'id');
    return range.start == range.end
        ? format.format(range.start)
        : '${format.format(range.start)} – ${format.format(range.end)}';
  }
}

class _PresetPicker extends StatelessWidget {
  const _PresetPicker();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ReportCubit>();
    final preset = context.select((ReportCubit c) => c.state.preset);
    return SegmentedButton<ReportPreset>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: ReportPreset.today, label: Text(l10n.rangeToday)),
        ButtonSegment(value: ReportPreset.week, label: Text(l10n.rangeWeek)),
        ButtonSegment(value: ReportPreset.month, label: Text(l10n.rangeMonth)),
        ButtonSegment(value: ReportPreset.custom, label: Text(l10n.rangeCustom), icon: const Icon(Icons.date_range, size: 18)),
      ],
      selected: {preset},
      emptySelectionAllowed: true,
      onSelectionChanged: (selection) async {
        final picked = selection.firstOrNull ?? cubit.state.preset;
        if (picked != ReportPreset.custom) {
          await cubit.usePreset(picked);
          return;
        }
        final today = cubit.today;
        final range = await showDateRangePicker(
          context: context,
          firstDate: today.subtract(const Duration(days: 730)),
          lastDate: today,
          initialDateRange: cubit.state.range,
          helpText: l10n.rangePickerTitle,
        );
        if (range == null) return;
        if (range.duration.inDays >= ReportCubit.maxDays) {
          if (context.mounted) showNotice(context, l10n.rangeTooLong(ReportCubit.maxDays));
          return;
        }
        await cubit.useRange(range);
      },
    );
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({required this.report});

  final ReportSummary? report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = report;
    return PopupMenuButton<ReportExport>(
      enabled: current != null,
      tooltip: l10n.exportCsv,
      onSelected: (kind) {
        final csv = ReportCsv(l10n);
        downloadCsv(csv.fileName(current!, kind), csv.build(current, kind));
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: ReportExport.daily, child: Text(l10n.exportDaily)),
        PopupMenuItem(value: ReportExport.agents, child: Text(l10n.exportAgents)),
        PopupMenuItem(value: ReportExport.topics, child: Text(l10n.exportTopics)),
      ],
      child: IgnorePointer(
        child: FilledButton.icon(
          onPressed: current == null ? null : () {},
          icon: const Icon(Icons.download, size: 18),
          label: Text(l10n.exportCsv),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final ReportSummary report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = report.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(label: l10n.reportCreated, value: number(totals.created), icon: Icons.confirmation_number_outlined),
            StatCard(
              label: l10n.reportResolved,
              value: number(totals.resolved),
              caption: totals.created == 0 ? null : l10n.percentOfTickets((totals.resolved * 100 / totals.created).round()),
              icon: Icons.task_alt,
            ),
            StatCard(label: l10n.reportClaimTime, value: minutesLabel(totals.avgClaimMinutes), icon: Icons.back_hand_outlined),
            StatCard(
              label: l10n.reportFirstResponse,
              value: minutesLabel(totals.avgFirstResponseMinutes),
              icon: Icons.quickreply_outlined,
            ),
            StatCard(label: l10n.reportDuration, value: minutesLabel(totals.avgResolutionMinutes), icon: Icons.timelapse),
            StatCard(
              label: l10n.reportAvgRating,
              value: totals.avgRating == null ? '–' : '${ratingLabel(totals.avgRating)} ★',
              caption: l10n.ratingCount(totals.ratings),
              icon: Icons.star_outline,
              color: const Color(0xFFB8860B),
            ),
          ],
        ),
        SectionTitle(l10n.reportPerDay),
        _Table(
          columns: [
            l10n.reportDate,
            l10n.reportCreated,
            l10n.reportResolved,
            l10n.reportClaimTime,
            l10n.reportFirstResponse,
            l10n.reportDuration,
            l10n.reportAvgRating,
          ],
          numeric: const {1, 2, 3, 4, 5, 6},
          rows: [
            for (final day in report.daily)
              [
                day.day == null ? '–' : DateFormat('EEE, d MMM', 'id').format(day.day!),
                number(day.created),
                number(day.resolved),
                minutesLabel(day.avgClaimMinutes),
                minutesLabel(day.avgFirstResponseMinutes),
                minutesLabel(day.avgResolutionMinutes),
                ratingLabel(day.avgRating),
              ],
          ],
          empty: l10n.reportEmpty,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final agents = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(l10n.reportPerAgent),
                _Table(
                  columns: [l10n.reportAgent, l10n.reportHandled, l10n.reportResolved, l10n.reportFirstResponse, l10n.reportAvgRating],
                  numeric: const {1, 2, 3, 4},
                  rows: [
                    for (final a in report.agents)
                      [
                        '${a.displayName} (${a.agentCode ?? ''})',
                        number(a.handled),
                        number(a.resolved),
                        minutesLabel(a.avgFirstResponseMinutes),
                        a.avgRating == null ? '–' : '${ratingLabel(a.avgRating)} (${a.ratings})',
                      ],
                  ],
                  empty: l10n.reportEmpty,
                ),
              ],
            );
            final total = report.topics.fold<int>(0, (sum, t) => sum + t.count);
            final topics = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(l10n.reportTopTopics),
                _Table(
                  columns: [l10n.reportTopic, l10n.reportCount, l10n.reportShare],
                  numeric: const {1, 2},
                  rows: [
                    for (final t in report.topics)
                      [t.name, number(t.count), total == 0 ? '–' : '${(t.count * 100 / total).round()}%'],
                  ],
                  empty: l10n.reportEmpty,
                ),
              ],
            );
            if (constraints.maxWidth < 1100) return Column(children: [agents, topics]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: agents),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: topics),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows, required this.empty, this.numeric = const {}});

  final List<String> columns;
  final List<List<String>> rows;
  final Set<int> numeric;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(empty, style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
                    columns: [
                      for (final (i, label) in columns.indexed) DataColumn(label: Text(label), numeric: numeric.contains(i)),
                    ],
                    rows: [
                      for (final row in rows) DataRow(cells: [for (final value in row) DataCell(Text(value))]),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
