import 'dart:async';

import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_tile.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

class TicketColumn extends StatefulWidget {
  const TicketColumn({super.key});

  @override
  State<TicketColumn> createState() => _TicketColumnState();
}

class _TicketColumnState extends State<TicketColumn> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<TicketListCubit, TicketListState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showError(context, state.actionError!),
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            const _Transfers(),
            const _Tabs(),
            const _SearchBar(),
            const _OfflineHint(),
            Expanded(child: _TicketList(now: _now)),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supervisor = context.select((AgentCubit c) => c.state.isSupervisor);
    final state = context.watch<TicketListCubit>().state;
    final lists = state.lists;
    final tabs = [
      (TicketTab.open, l10n.tabOpen, lists.open.length),
      (TicketTab.mine, l10n.tabMine, lists.mine.length),
      (TicketTab.resolvedToday, l10n.tabResolvedToday, lists.resolvedToday.length),
      if (supervisor) (TicketTab.allActive, l10n.tabAllActive, lists.allActive.length),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (tab, label, count) in tabs)
            ChoiceChip(
              label: Text('$label $count'),
              selected: state.tab == tab && state.results == null,
              onSelected: (_) => context.read<TicketListCubit>().selectTab(tab),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TicketListCubit>().state;
    final cubit = context.read<TicketListCubit>();
    final filter = state.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _query,
            onChanged: cubit.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.searchHint,
              prefixIcon: state.searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search, size: 20),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _query.clear();
                        cubit.search('');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterMenu(
                label: l10n.filterTopic,
                value: filter.topic,
                options: {for (final t in state.topics) t.code: t.name},
                onChanged: (v) => cubit.setFilter(filter.copyWith(topic: v)),
              ),
              const SizedBox(width: 6),
              _FilterMenu(
                label: l10n.filterPriority,
                value: filter.priority,
                options: {for (final p in ticketPriorities) p: p},
                onChanged: (v) => cubit.setFilter(filter.copyWith(priority: v)),
              ),
              const SizedBox(width: 6),
              _FilterMenu(
                label: l10n.filterFlag,
                value: filter.flag,
                options: {for (final f in ['complaint', 'fraud', 'vip']) f: flagText(context, f)},
                onChanged: (v) => cubit.setFilter(filter.copyWith(flag: v)),
              ),
              const Spacer(),
              if (!filter.isEmpty)
                IconButton(
                  tooltip: l10n.clearFilters,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cubit.setFilter(const TicketFilter()),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: '', checked: selected == null, child: Text(context.l10n.filterAll)),
        for (final entry in options.entries)
          CheckedPopupMenuItem(value: entry.key, checked: selected == entry.key, child: Text(entry.value)),
      ],
      child: Chip(
        visualDensity: VisualDensity.compact,
        label: Text(selected == null ? label : '$label: ${options[selected] ?? selected}'),
        avatar: Icon(selected == null ? Icons.filter_list : Icons.filter_alt, size: 16),
      ),
    );
  }
}

class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    final status = context.select((AgentCubit c) => c.state.status);
    final tab = context.select((TicketListCubit c) => c.state.tab);
    if (status == AgentStatus.online || tab != TicketTab.open) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(context.l10n.offlineHint, style: TextStyle(color: scheme.onTertiaryContainer)),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final agent = context.watch<AgentCubit>().state;
    final state = context.watch<TicketListCubit>().state;
    final cubit = context.read<TicketListCubit>();
    if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LoadStatus.failure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadFailed),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: cubit.refresh, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final tickets = state.visible;
    if (tickets.isEmpty) {
      final empty = state.results != null
          ? l10n.emptySearch
          : switch (state.tab) {
              TicketTab.open => l10n.emptyOpen,
              TicketTab.mine => l10n.emptyMine,
              TicketTab.resolvedToday => l10n.emptyResolved,
              TicketTab.allActive => l10n.emptyAllActive,
            };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(empty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return ListView.builder(
      itemCount: tickets.length,
      itemBuilder: (context, i) {
        final ticket = tickets[i];
        final canClaim = ticket.isOpen && agent.handlesTickets && agent.status == AgentStatus.online;
        return TicketTile(
          key: ValueKey(ticket.id),
          ticket: ticket,
          topicName: state.topicName(ticket.topic),
          settings: agent.settings,
          now: now,
          selected: state.selectedId == ticket.id,
          showOwner: state.tab == TicketTab.allActive || state.results != null,
          meId: agent.id,
          claiming: state.claiming.contains(ticket.id),
          onTap: () => cubit.select(ticket.id),
          onClaim: canClaim
              ? () async {
                  final claimed = await cubit.claim(ticket);
                  if (claimed != null && context.mounted) await context.read<AgentCubit>().beat();
                }
              : null,
        );
      },
    );
  }
}

class _Transfers extends StatelessWidget {
  const _Transfers();

  @override
  Widget build(BuildContext context) {
    final lists = context.select((TicketListCubit c) => c.state.lists);
    if (lists.transfersIn.isEmpty && lists.transfersOut.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<TicketListCubit>();
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Column(
        children: [
          for (final request in lists.transfersIn)
            ListTile(
              dense: true,
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.transferFrom(request.fromName ?? '')),
              subtitle: Text(
                [request.ticket.ticketNumber, request.ticket.customerName, if ((request.note ?? '').isNotEmpty) request.note]
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => cubit.select(request.ticket.id),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: () => cubit.respondTransfer(request, accept: false), child: Text(l10n.reject)),
                  FilledButton(onPressed: () => cubit.respondTransfer(request, accept: true), child: Text(l10n.accept)),
                ],
              ),
            ),
          for (final transfer in lists.transfersOut)
            ListTile(
              dense: true,
              leading: const Icon(Icons.hourglass_top, size: 20),
              title: Text(l10n.transferWaiting(transfer.toName ?? '')),
              onTap: () => cubit.select(transfer.ticketId),
              trailing: TextButton(onPressed: () => cubit.cancelTransfer(transfer), child: Text(l10n.cancel)),
            ),
        ],
      ),
    );
  }
}
