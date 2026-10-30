import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/widgets/top_bar.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';

Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? hint,
  required String confirm,
  int minLength = 3,
  int maxLength = 300,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ReasonDialog(title: title, hint: hint, confirm: confirm, minLength: minLength, maxLength: maxLength),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirm,
    required this.minLength,
    required this.maxLength,
  });

  final String title;
  final String? hint;
  final String confirm;
  final int minLength;
  final int maxLength;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = _reason.text.trim().length >= widget.minLength;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hint != null) ...[Text(widget.hint!), const SizedBox(height: 12)],
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              maxLength: widget.maxLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.reasonRequired, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _reason.text.trim()) : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class AgentChoice {
  const AgentChoice(this.agent, this.note);

  final OnlineAgent agent;
  final String note;
}

Future<AgentChoice?> pickAgent(
  BuildContext context, {
  required AgentRepository agents,
  required String title,
  String? hint,
  required String noteLabel,
  required String confirm,
  bool onlyAvailable = true,
}) => showDialog<AgentChoice>(
  context: context,
  builder: (context) => _AgentDialog(
    agents: agents,
    title: title,
    hint: hint,
    noteLabel: noteLabel,
    confirm: confirm,
    onlyAvailable: onlyAvailable,
  ),
);

class _AgentDialog extends StatefulWidget {
  const _AgentDialog({
    required this.agents,
    required this.title,
    required this.hint,
    required this.noteLabel,
    required this.confirm,
    required this.onlyAvailable,
  });

  final AgentRepository agents;
  final String title;
  final String? hint;
  final String noteLabel;
  final String confirm;
  final bool onlyAvailable;

  @override
  State<_AgentDialog> createState() => _AgentDialogState();
}

class _AgentDialogState extends State<_AgentDialog> {
  final _note = TextEditingController();
  late final Future<List<OnlineAgent>> _colleagues = widget.agents.colleagues();
  OnlineAgent? _selected;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final valid = _selected != null && _note.text.trim().length >= 3;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<OnlineAgent>>(
          future: _colleagues,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? Text(l10n.loadFailed)
                  : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            final agents = [for (final a in snapshot.data!) if (!widget.onlyAvailable || a.canTake) a];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.hint != null) ...[Text(widget.hint!), const SizedBox(height: 12)],
                Text(l10n.transferTo, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                if (agents.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l10n.transferNoAgents))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final agent in agents)
                          ListTile(
                            dense: true,
                            selected: _selected?.id == agent.id,
                            onTap: () => setState(() => _selected = agent),
                            leading: Icon(
                              _selected?.id == agent.id ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: _selected?.id == agent.id ? scheme.primary : null,
                            ),
                            title: Text('${agent.displayName} (${agent.agentCode ?? ''})'),
                            subtitle: Text('${statusLabel(context, agent.status)} · ${l10n.slots(agent.activeTickets, agent.maxActiveTickets)}'),
                            trailing: Icon(Icons.circle, size: 10, color: statusColor(agent.status, scheme)),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: widget.noteLabel, border: const OutlineInputBorder()),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, AgentChoice(_selected!, _note.text.trim())) : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class Resolution {
  const Resolution({required this.outcome, required this.summary, required this.tags});

  final String outcome;
  final String summary;
  final List<String> tags;
}

Future<Resolution?> askResolution(BuildContext context, Map<String, Map<String, String>> outcomes) =>
    showDialog<Resolution>(context: context, builder: (context) => _ResolveDialog(outcomes: outcomes));

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.outcomes});

  final Map<String, Map<String, String>> outcomes;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _summary = TextEditingController();
  final _tags = TextEditingController();
  late String? _outcome = widget.outcomes.containsKey('answered') ? 'answered' : widget.outcomes.keys.firstOrNull;

  @override
  void dispose() {
    _summary.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = _summary.text.trim();
    final valid = _outcome != null && summary.length >= 5 && summary.length <= 500;
    return AlertDialog(
      title: Text(l10n.resolveTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.resolveOutcome, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in widget.outcomes.entries)
                  ChoiceChip(
                    label: Text(entry.value['id'] ?? entry.key),
                    selected: _outcome == entry.key,
                    onSelected: (_) => setState(() => _outcome = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _summary,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.resolveSummary, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tags,
              decoration: InputDecoration(labelText: l10n.resolveTags, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  Resolution(
                    outcome: _outcome!,
                    summary: summary,
                    tags: [
                      for (final t in _tags.text.split(','))
                        if (t.trim().isNotEmpty) t.trim().toLowerCase(),
                    ],
                  ),
                )
              : null,
          child: Text(l10n.resolveConfirm),
        ),
      ],
    );
  }
}

Future<SupportTopic?> pickHelpTopic(BuildContext context, List<SupportTopic> topics) => showDialog<SupportTopic>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(context.l10n.sendHelpLink),
    children: [
      for (final topic in topics.where((t) => t.helpUrl != null))
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, topic),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(topic.name),
            subtitle: Text(topic.helpUrl!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
    ],
  ),
);

Future<String?> pickRevealReason(BuildContext context, {required String field, required Map<String, Map<String, String>> reasons}) =>
    showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return SimpleDialog(
          title: Text(l10n.revealTitle(field)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.revealNote, style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final entry in reasons.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, entry.key),
                child: Text(entry.value['id'] ?? entry.key),
              ),
          ],
        );
      },
    );

Future<bool> confirmAction(BuildContext context, {required String message, required String confirm}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}
