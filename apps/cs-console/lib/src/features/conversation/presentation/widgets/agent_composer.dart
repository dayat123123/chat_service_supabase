import 'dart:async';

import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/conversation/presentation/widgets/action_dialogs.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/olt_social.dart' hide SupportTopic;

enum ComposerMode { reply, note }

const _noteColor = Color(0xFFFFF4C2);

class AgentComposer extends StatefulWidget {
  const AgentComposer({
    super.key,
    required this.ticket,
    required this.me,
    required this.topics,
    required this.agents,
  });

  final Ticket ticket;
  final AgentProfile me;
  final List<SupportTopic> topics;
  final AgentRepository agents;

  @override
  State<AgentComposer> createState() => _AgentComposerState();
}

class _AgentComposerState extends State<AgentComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  ComposerMode _mode = ComposerMode.reply;
  List<QuickReply> _suggestions = const [];
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _focus.onKeyEvent = _onKey;
    _text.addListener(_onChanged);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_mode == ComposerMode.reply) context.read<ChatRoomCubit>().onTextChanged(_text.text);
    final value = _text.text;
    final next = _mode == ComposerMode.reply && value.startsWith('/') && !value.contains('\n')
        ? _match(value.substring(1).toLowerCase())
        : const <QuickReply>[];
    if (next.length != _suggestions.length || !_sameIds(next, _suggestions)) {
      setState(() {
        _suggestions = next;
        _highlight = 0;
      });
    }
  }

  List<QuickReply> _match(String query) {
    final replies = context.read<ConversationCubit>().state.quickReplies;
    return [
      for (final r in replies)
        if (query.isEmpty || r.shortcut.toLowerCase().contains(query) || r.title.toLowerCase().contains(query)) r,
    ].take(8).toList();
  }

  bool _sameIds(List<QuickReply> a, List<QuickReply> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_suggestions.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _highlight = (_highlight + 1) % _suggestions.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _highlight = (_highlight - 1 + _suggestions.length) % _suggestions.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _suggestions = const []);
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) && !shift) {
        _apply(_suggestions[_highlight]);
        return KeyEventResult.handled;
      }
    }
    final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (enter && !shift && event is KeyDownEvent) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _apply(QuickReply reply) {
    final text = reply.fill(
      customer: widget.ticket.customerName,
      ticketNumber: widget.ticket.ticketNumber,
      agent: widget.me.displayName,
    );
    _text.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    setState(() => _suggestions = const []);
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (_mode == ComposerMode.reply) {
      _text.clear();
      _focus.requestFocus();
      await context.read<ChatRoomCubit>().send(text);
      return;
    }
    final saved = await context.read<ConversationCubit>().addNote(text);
    if (!mounted || !saved) return;
    _text.clear();
    showNotice(context, context.l10n.noteSaved);
  }

  Future<void> _attach() async {
    const group = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await context.read<ChatRoomCubit>().sendImage(bytes, _mime(file.name, file.mimeType));
  }

  String _mime(String name, String? reported) {
    if (reported != null && reported.startsWith('image/')) return reported;
    return switch (name.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _helpLink() async {
    final topic = await pickHelpTopic(context, widget.topics);
    if (topic == null || !mounted) return;
    await context.read<ConversationCubit>().sendHelpLink(title: topic.name, url: topic.helpUrl!);
  }

  void _setMode(ComposerMode mode) {
    if (_mode == ComposerMode.reply) unawaited(context.read<ChatRoomCubit>().stopTyping());
    setState(() {
      _mode = mode;
      _suggestions = const [];
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final note = _mode == ComposerMode.note;
    final uploading = context.select((ChatRoomCubit c) => c.state.uploading);
    final isOwner = widget.ticket.owner?.id == widget.me.id;
    return Container(
      color: note ? _noteColor.withValues(alpha: 0.45) : theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SegmentedButton<ComposerMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: ComposerMode.reply, label: Text(l10n.tabReply), icon: const Icon(Icons.reply, size: 16)),
                  ButtonSegment(
                    value: ComposerMode.note,
                    label: Text(l10n.tabNote),
                    icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
              const SizedBox(width: 10),
              if (note)
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _noteColor,
                  avatar: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: Text(l10n.noteInvisible),
                )
              else
                Text('/ ${l10n.quickReplies}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          if (_suggestions.isNotEmpty || (_mode == ComposerMode.reply && _text.text.startsWith('/') && !_text.text.contains('\n')))
            _QuickReplyList(
              replies: _suggestions,
              highlight: _highlight,
              onSelect: _apply,
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!note) ...[
                IconButton(
                  tooltip: l10n.attachImage,
                  onPressed: uploading ? null : _attach,
                  icon: uploading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                if (widget.topics.any((t) => t.helpUrl != null))
                  IconButton(tooltip: l10n.sendHelpLink, onPressed: _helpLink, icon: const Icon(Icons.menu_book_outlined)),
              ],
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    hintText: note ? l10n.noteHint : l10n.replyHint,
                    counterText: '',
                    isDense: true,
                    filled: note,
                    fillColor: _noteColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(note ? Icons.save_outlined : Icons.send, size: 18),
                label: Text(note ? l10n.saveNote : l10n.send),
              ),
            ],
          ),
          if (isOwner) ...[
            const SizedBox(height: 8),
            _OwnerActions(ticket: widget.ticket, me: widget.me, agents: widget.agents),
          ],
        ],
      ),
    );
  }
}

class _QuickReplyList extends StatelessWidget {
  const _QuickReplyList({required this.replies, required this.highlight, required this.onSelect});

  final List<QuickReply> replies;
  final int highlight;
  final ValueChanged<QuickReply> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: replies.isEmpty
          ? Padding(padding: const EdgeInsets.all(12), child: Text(context.l10n.quickRepliesEmpty))
          : ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < replies.length; i++)
                  ListTile(
                    dense: true,
                    selected: i == highlight,
                    onTap: () => onSelect(replies[i]),
                    leading: Text('/${replies[i].shortcut}', style: theme.textTheme.labelLarge),
                    title: Text(replies[i].title),
                    subtitle: Text(replies[i].body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({required this.ticket, required this.me, required this.agents});

  final Ticket ticket;
  final AgentProfile me;
  final AgentRepository agents;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = context.select((ConversationCubit c) => c.state.busy);
    final cubit = context.read<ConversationCubit>();
    final pending = ticket.transfer;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (ticket.status == TicketStatus.claimed)
          OutlinedButton.icon(
            onPressed: busy ? null : cubit.waitCustomer,
            icon: const Icon(Icons.hourglass_empty, size: 18),
            label: Text(l10n.actionWait),
          ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final reason = await askReason(
                    context,
                    title: l10n.releaseTitle,
                    hint: l10n.releaseHint,
                    confirm: l10n.releaseConfirm,
                  );
                  if (reason != null) await cubit.release(reason);
                  if (context.mounted) await context.read<AgentCubit>().beat();
                },
          icon: const Icon(Icons.undo, size: 18),
          label: Text(l10n.actionRelease),
        ),
        OutlinedButton.icon(
          onPressed: busy || pending != null
              ? null
              : () async {
                  final choice = await pickAgent(
                    context,
                    agents: agents,
                    title: l10n.transferTitle,
                    hint: l10n.transferHint,
                    noteLabel: l10n.transferNote,
                    confirm: l10n.transferSend,
                  );
                  if (choice != null) await cubit.transfer(toAgentId: choice.agent.id, note: choice.note);
                },
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(l10n.actionTransfer),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final resolution = await askResolution(context, me.settings.outcomes);
                  if (resolution == null) return;
                  await cubit.resolve(outcome: resolution.outcome, summary: resolution.summary, tags: resolution.tags);
                  if (context.mounted) await context.read<AgentCubit>().beat();
                },
          icon: const Icon(Icons.task_alt, size: 18),
          label: Text(l10n.actionResolve),
        ),
        if (pending != null)
          Text(
            l10n.pendingTransfer(pending.toName ?? ''),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}
