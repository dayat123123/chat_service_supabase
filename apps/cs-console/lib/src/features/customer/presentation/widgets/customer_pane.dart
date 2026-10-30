import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/action_dialogs.dart';
import 'package:cs_console/src/features/customer/data/customer_repository.dart';
import 'package:cs_console/src/features/customer/domain/customer_records.dart';
import 'package:cs_console/src/features/customer/presentation/cubit/customer_cubit.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:cs_console/src/features/tickets/presentation/widgets/ticket_badges.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

bool canViewCustomerData(Ticket ticket, AgentProfile me) =>
    (ticket.isActive && ticket.owner?.id == me.id) ||
    me.isSupervisor ||
    (me.roles.contains('compliance') && (ticket.isComplaint || ticket.isFraud));

class CustomerScope extends StatelessWidget {
  const CustomerScope({super.key, required this.ticket, required this.me, required this.repository, required this.child});

  final Ticket ticket;
  final AgentProfile me;
  final CustomerRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final customer = ticket.customer;
    if (customer == null) return child;
    final canView = canViewCustomerData(ticket, me);
    return BlocProvider(
      key: ValueKey('${ticket.id}-$canView'),
      create: (_) => CustomerCubit(customers: repository, ticketId: ticket.id, customerId: customer.id)
        ..load(canViewData: canView),
      child: BlocListener<ConversationCubit, ConversationState>(
        listenWhen: (a, b) => a.notesVersion != b.notesVersion,
        listener: (context, _) => context.read<CustomerCubit>().reloadNotes(),
        child: child,
      ),
    );
  }
}

class CustomerPane extends StatelessWidget {
  const CustomerPane({super.key, required this.ticket, required this.me});

  final Ticket ticket;
  final AgentProfile me;

  @override
  Widget build(BuildContext context) {
    if (ticket.customer == null) return const SizedBox.shrink();
    return _CustomerView(ticket: ticket, me: me);
  }
}

class _CustomerView extends StatelessWidget {
  const _CustomerView({required this.ticket, required this.me});

  final Ticket ticket;
  final AgentProfile me;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocConsumer<CustomerCubit, CustomerState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showError(context, state.actionError!),
      builder: (context, state) {
        final customer = ticket.customer!;
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(l10n.customerInfo, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 6),
              Text(customer.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (customer.username != null)
                Text('@${customer.username}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 12),
              if (!state.canViewData)
                _Hint(l10n.dataAfterClaim)
              else ...[
                _ProfileSection(section: state.profile, revealed: state.revealed, me: me),
                _SecureAccount(ticket: ticket, me: me, busy: state.securing),
                _OrdersSection(section: state.orders, ticket: ticket, me: me),
                _CashSection(section: state.cash),
                _DevicesSection(section: state.devices),
                _SecuritySection(section: state.security),
              ],
              _HistorySection(section: state.history, currentId: ticket.id),
              _NotesSection(section: state.notes),
            ],
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _Block<T> extends StatelessWidget {
  const _Block({required this.title, required this.section, required this.builder, this.icon});

  final String title;
  final IconData? icon;
  final Section<T> section;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final data = section.data;
    final Widget body;
    if (section.status == LoadStatus.failure) {
      final error = section.error;
      body = Text(
        error != null && errorText(context, error) != l10n.errorGeneric ? errorText(context, error) : l10n.loadFailed,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      );
    } else if (data == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    } else {
      body = builder(context, data);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 6)],
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          body,
          const SizedBox(height: 4),
          Divider(height: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value.isEmpty ? '–' : value, style: theme.textTheme.bodySmall)),
          ?trailing,
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.section, required this.revealed, required this.me});

  final Section<Map<String, dynamic>> section;
  final Map<String, RevealedField> revealed;
  final AgentProfile me;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String text(Map<String, dynamic> p, String key) => '${p[key] ?? ''}';
    String nested(Map<String, dynamic> p, String key) {
      final account = p[key];
      return account is Map ? '${account['bank'] ?? ''} ${account['number'] ?? ''}'.trim() : '';
    }

    Widget? revealButton(String field, String label) {
      if (revealed.containsKey(field)) return const Icon(Icons.visibility_outlined, size: 16);
      return TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: Theme.of(context).textTheme.labelSmall,
        ),
        onPressed: () async {
          final reason = await pickRevealReason(context, field: label, reasons: me.settings.revealReasons);
          if (reason != null && context.mounted) await context.read<CustomerCubit>().reveal(field, reason);
        },
        child: Text(l10n.reveal),
      );
    }

    String value(String field, String masked) => revealed[field]?.value ?? masked;

    return _Block<Map<String, dynamic>>(
      title: l10n.profile,
      icon: Icons.badge_outlined,
      section: section,
      builder: (context, p) => Column(
        children: [
          _Row(l10n.fieldName, text(p, 'name')),
          _Row(l10n.fieldClientCode, value('client_code', text(p, 'client_code')),
              trailing: revealButton('client_code', l10n.fieldClientCode)),
          _Row(l10n.fieldSid, value('sid', text(p, 'sid')), trailing: revealButton('sid', l10n.fieldSid)),
          _Row(l10n.fieldNik, value('nik', text(p, 'nik')), trailing: revealButton('nik', l10n.fieldNik)),
          _Row(l10n.fieldPhone, value('phone', text(p, 'phone')), trailing: revealButton('phone', l10n.fieldPhone)),
          _Row(l10n.fieldEmail, value('email', text(p, 'email')), trailing: revealButton('email', l10n.fieldEmail)),
          _Row(l10n.fieldBirthDate, value('birth_date', text(p, 'birth_date')),
              trailing: revealButton('birth_date', l10n.fieldBirthDate)),
          _Row(l10n.fieldAddress, value('address', text(p, 'address')), trailing: revealButton('address', l10n.fieldAddress)),
          _Row(l10n.fieldRdn, value('rdn_number', nested(p, 'rdn')), trailing: revealButton('rdn_number', l10n.fieldRdn)),
          _Row(l10n.fieldBankAccount, value('bank_account', nested(p, 'withdrawal_account')),
              trailing: revealButton('bank_account', l10n.fieldBankAccount)),
          _Row(l10n.fieldAccountStatus, text(p, 'account_status')),
          _Row(l10n.fieldKycStatus, text(p, 'kyc_status')),
          _Row(l10n.fieldSegment, text(p, 'segment')),
        ],
      ),
    );
  }
}

class _SecureAccount extends StatelessWidget {
  const _SecureAccount({required this.ticket, required this.me, required this.busy});

  final Ticket ticket;
  final AgentProfile me;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ticket.isActive) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
        onPressed: busy
            ? null
            : () async {
                if (!await confirmAction(context, message: l10n.secureConfirm, confirm: l10n.secureAccount)) return;
                if (!context.mounted) return;
                final result = await context.read<CustomerCubit>().secureAccount();
                if (result != null && context.mounted) {
                  showNotice(context, result['ok'] == true ? l10n.secureDone : l10n.secureFailed);
                }
              },
        icon: busy
            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.shield_outlined, size: 18),
        label: Text(l10n.secureAccount),
      ),
    );
  }
}

class _OrdersSection extends StatelessWidget {
  const _OrdersSection({required this.section, required this.ticket, required this.me});

  final Section<List<Map<String, dynamic>>> section;
  final Ticket ticket;
  final AgentProfile me;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canSend = ticket.isActive && ticket.owner?.id == me.id;
    return _Block<List<Map<String, dynamic>>>(
      title: l10n.orders,
      icon: Icons.receipt_long_outlined,
      section: section,
      builder: (context, orders) => orders.isEmpty
          ? Text(l10n.noData, style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (final o in orders)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () => showCardDetail(context, 'order', '${o['order_id']}'),
                    title: Text(
                      '${o['code'] ?? ''} · ${o['side'] == 'sell' ? l10n.sideSell : l10n.sideBuy} '
                      '${l10n.lots((o['lot'] as num?)?.toInt() ?? 0)} @ ${number((o['price'] as num?) ?? 0)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${o['status'] ?? ''} · ${_time(o['time'])}${o['reject_reason'] == null ? '' : ' · ${o['reject_reason']}'}',
                      style: theme.textTheme.labelSmall,
                    ),
                    trailing: canSend
                        ? IconButton(
                            tooltip: l10n.sendToChat,
                            icon: const Icon(Icons.send_to_mobile_outlined, size: 18),
                            onPressed: () => context.read<ConversationCubit>().sendCard('order', '${o['order_id']}'),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

String _time(Object? value) {
  final time = DateTime.tryParse('${value ?? ''}');
  return time == null ? '' : stamp(time);
}

Future<void> showCardDetail(BuildContext context, String card, String ref) async {
  final cubit = context.read<CustomerCubit>();
  final l10n = context.l10n;
  final order = card == 'order';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${order ? l10n.orderDetail : l10n.cashDetail} $ref'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: order ? cubit.order(ref) : cubit.cashTransaction(ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final o = snapshot.data;
            if (o == null) return Text(l10n.loadFailed);
            if (!order) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Row(l10n.cashKind, '${o['kind'] ?? ''}'),
                  _Row(l10n.cashAmount, rupiah((o['amount'] as num?) ?? 0)),
                  _Row(l10n.cashBank, '${o['bank'] ?? ''}'),
                  _Row(l10n.orderStatus, '${o['status'] ?? ''}'),
                  _Row(l10n.cashBankRef, '${o['bank_ref'] ?? ''}'),
                  _Row(l10n.cashTime, _time(o['time'])),
                  if (o['failure_reason'] != null) _Row(l10n.orderReason, '${o['failure_reason']}'),
                ],
              );
            }
            final history = (o['history'] as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
            final executions = (o['executions'] as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(l10n.orderStock, '${o['code'] ?? ''}'),
                _Row(l10n.orderSide, o['side'] == 'sell' ? l10n.sideSell : l10n.sideBuy),
                _Row(l10n.orderPrice, number((o['price'] as num?) ?? 0)),
                _Row(l10n.orderLot, l10n.orderFilled('${o['lot'] ?? ''}', '${o['filled_lot'] ?? 0}')),
                _Row(l10n.orderStatus, '${o['status'] ?? ''}'),
                if (o['reject_reason'] != null) _Row(l10n.orderReason, '${o['reject_code'] ?? ''} ${o['reject_reason']}'),
                _Row(l10n.orderChannel, '${o['channel'] ?? ''} · ${o['session'] ?? ''}'),
                const SizedBox(height: 8),
                for (final h in history) _Row(_time(h['time']), '${h['status'] ?? ''} ${h['note'] ?? ''}'.trim()),
                for (final e in executions) _Row(_time(e['time']), '${e['lot']} lot @ ${number((e['price'] as num?) ?? 0)}'),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
    ),
  );
}

class _CashSection extends StatelessWidget {
  const _CashSection({required this.section});

  final Section<List<Map<String, dynamic>>> section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _Block<List<Map<String, dynamic>>>(
      title: l10n.cashTransactions,
      icon: Icons.account_balance_wallet_outlined,
      section: section,
      builder: (context, items) => items.isEmpty
          ? Text(l10n.noData, style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (final t in items)
                  _Row(
                    '${t['kind'] ?? ''}',
                    '${rupiah((t['amount'] as num?) ?? 0)} · ${t['status'] ?? ''} · ${_time(t['time'])}'
                    '${t['failure_reason'] == null ? '' : ' · ${t['failure_reason']}'}',
                  ),
              ],
            ),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({required this.section});

  final Section<Map<String, dynamic>> section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _Block<Map<String, dynamic>>(
      title: l10n.devices,
      icon: Icons.devices_outlined,
      section: section,
      builder: (context, data) {
        final sessions = (data['sessions'] as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
        final logins = (data['logins'] as List<Object?>? ?? const []).cast<Map<String, dynamic>>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.lastSessions, style: theme.textTheme.labelSmall),
            for (final s in sessions)
              _Row('${s['device'] ?? ''}', '${s['platform'] ?? ''} ${s['app_version'] ?? ''} · ${s['ip'] ?? ''} · ${_time(s['last_active'])}'),
            const SizedBox(height: 6),
            Text(l10n.lastLogins, style: theme.textTheme.labelSmall),
            for (final login in logins.take(5))
              _Row(_time(login['time']), '${login['device'] ?? ''} · ${login['ip'] ?? ''} · ${login['result'] ?? ''}'),
          ],
        );
      },
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.section});

  final Section<Map<String, dynamic>> section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String yesNo(Object? v) => v == true ? l10n.yes : l10n.no;
    return _Block<Map<String, dynamic>>(
      title: l10n.security,
      icon: Icons.security_outlined,
      section: section,
      builder: (context, s) => Column(
        children: [
          _Row(l10n.tradingLocked, yesNo(s['trading_locked'])),
          _Row(l10n.accountLocked, '${yesNo(s['account_locked'])}${s['lock_reason'] == null ? '' : ' · ${s['lock_reason']}'}'),
          _Row(l10n.otpEnabled, yesNo(s['otp_enabled'])),
          _Row(l10n.suspicious, yesNo(s['suspicious'])),
          _Row('', l10n.failedLogins((s['failed_logins_24h'] as num?)?.toInt() ?? 0)),
          if (s['last_password_change'] != null) _Row('', l10n.lastPasswordChange(_time(s['last_password_change']))),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.section, required this.currentId});

  final Section<List<TicketHistoryItem>> section;
  final String currentId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final topics = context.select((TicketListCubit c) => c.state);
    return _Block<List<TicketHistoryItem>>(
      title: l10n.history,
      icon: Icons.history,
      section: section,
      builder: (context, items) {
        final previous = [for (final i in items) if (i.id != currentId) i];
        if (previous.isEmpty) return Text(l10n.noData, style: theme.textTheme.bodySmall);
        return Column(
          children: [
            for (final item in previous.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => context.read<TicketListCubit>().select(item.id),
                title: Text(
                  '${item.ticketNumber ?? ''} · ${topics.topicName(item.topic)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    shortDate(item.createdAt),
                    item.status,
                    if (item.agent != null) item.agent!,
                    if (item.rating != null) '★ ${item.rating}',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
                trailing: Wrap(spacing: 4, children: [for (final f in item.flags) FlagChip(f)]),
              ),
          ],
        );
      },
    );
  }
}

class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.section});

  final Section<List<AgentNote>> section;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _note.text.trim();
    if (body.isEmpty) return;
    if (await context.read<CustomerCubit>().addNote(body)) _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _Block<List<AgentNote>>(
      title: l10n.notes,
      icon: Icons.sticky_note_2_outlined,
      section: widget.section,
      builder: (context, notes) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notes.isEmpty) Text(l10n.notesEmpty, style: theme.textTheme.bodySmall),
          for (final note in notes.take(20))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF4C2), borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.body, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (note.kind == 'handover') l10n.noteHandover,
                      note.author?.displayName ?? '',
                      stamp(note.createdAt),
                    ].where((p) => p.isNotEmpty).join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.addNote,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.add, size: 18), onPressed: _add),
            ),
          ),
        ],
      ),
    );
  }
}
