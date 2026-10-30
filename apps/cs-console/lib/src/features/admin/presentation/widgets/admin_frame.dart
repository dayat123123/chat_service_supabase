import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

class AdminFrame extends StatelessWidget {
  const AdminFrame({super.key, required this.title, this.description, this.action, required this.children});

  final String title;
  final String? description;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ?action,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class AdminLoader<T> extends StatelessWidget {
  const AdminLoader({super.key, required this.builder});

  final Widget Function(BuildContext context, List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminListCubit<T>, AdminListState<T>>(
      builder: (context, state) => switch (state.status) {
        LoadStatus.ready => builder(context, state.items),
        LoadStatus.failure => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(errorText(context, state.error!)),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: context.read<AdminListCubit<T>>().load, child: Text(context.l10n.retry)),
            ],
          ),
        ),
        _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      },
    );
  }
}

class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows, this.numeric = const {}});

  final List<String> columns;
  final List<DataRow> rows;
  final Set<int> numeric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
              showCheckboxColumn: false,
              columns: [
                for (final (i, label) in columns.indexed) DataColumn(label: Text(label), numeric: numeric.contains(i)),
              ],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key, required this.active, this.activeLabel, this.inactiveLabel});

  final bool active;
  final String? activeLabel;
  final String? inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = active ? const Color(0xFF1E9E5A) : scheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        active ? (activeLabel ?? l10n.active) : (inactiveLabel ?? l10n.inactive),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class DialogError extends StatelessWidget {
  const DialogError(this.error, {super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(errorText(context, error!), style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
