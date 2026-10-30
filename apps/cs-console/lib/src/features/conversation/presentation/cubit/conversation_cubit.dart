import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/data/ticket_repository.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart';

part 'conversation_cubit.freezed.dart';

enum ConversationNotice { claimed, released, transferRequested, resolved, waiting, joined, reassigned, sent, stale }

@freezed
abstract class ConversationState with _$ConversationState {
  const factory ConversationState({
    @Default(LoadStatus.initial) LoadStatus status,
    Ticket? ticket,
    @Default(false) bool joined,
    @Default(false) bool busy,
    @Default(<QuickReply>[]) List<QuickReply> quickReplies,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
    ConversationNotice? notice,
    @Default(0) int noticeId,
    @Default(0) int notesVersion,
  }) = _ConversationState;

  const ConversationState._();

  bool canReply(String agentId) {
    final t = ticket;
    return t != null && t.isActive && (t.owner?.id == agentId || joined);
  }

  bool isOwner(String agentId) => ticket?.owner?.id == agentId && (ticket?.isActive ?? false);
}

class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit({
    required this._tickets,
    required this._staff,
    required this._agent,
    required Stream<QueueEvent> events,
    required this.ticketId,
  }) : super(const ConversationState()) {
    _events = events.listen(_onEvent);
  }

  final TicketRepository _tickets;
  final OltSupportStaff _staff;
  final AgentProfile Function() _agent;
  final String ticketId;
  late final StreamSubscription<QueueEvent> _events;
  Timer? _debounce;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      await _reload();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready));
      unawaited(_loadQuickReplies());
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> _reload() async {
    final ticket = await _tickets.detail(ticketId);
    final joined = await _joined(ticket);
    if (isClosed) return;
    _bind(ticket, joined);
    emit(state.copyWith(ticket: ticket, joined: joined));
  }

  Future<void> _loadQuickReplies() async {
    try {
      final replies = await _tickets.quickReplies(state.ticket?.language ?? 'id');
      if (!isClosed) emit(state.copyWith(quickReplies: replies));
    } catch (_) {}
  }

  Future<bool> _joined(Ticket ticket) async {
    final me = _agent();
    if (!me.isSupervisor || !ticket.isActive || ticket.owner?.id == me.id) return false;
    try {
      return (await _tickets.members(ticket.roomId)).contains(me.id);
    } catch (_) {
      return false;
    }
  }

  void _bind(Ticket ticket, bool joined) {
    final me = _agent();
    final now = DateTime.now().toUtc();
    final canReply = ticket.isActive && (ticket.owner?.id == me.id || joined);
    _staff.showTicket(
      ChatRoom(
        id: ticket.roomId,
        type: RoomType.support,
        name: ticket.customerName,
        createdAt: ticket.createdAt ?? now,
        lastReadAt: now,
      ),
      replyTicketId: canReply ? ticket.id : null,
    );
  }

  void _onEvent(QueueEvent event) {
    final relevant = switch (event) {
      TicketChanged(:final ticketId) || CustomerMessaged(:final ticketId) || TransferChanged(:final ticketId) =>
        ticketId == this.ticketId,
      QueueReconnected() => true,
      _ => false,
    };
    if (!relevant || state.status != LoadStatus.ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _reload();
      } catch (_) {}
    });
  }

  Future<void> claim() => _act((t) => _tickets.claim(t.id), notice: ConversationNotice.claimed);

  Future<void> waitCustomer() => _act(_tickets.waitCustomer, notice: ConversationNotice.waiting);

  Future<void> release(String reason) => _act((t) => _tickets.release(t, reason), notice: ConversationNotice.released);

  Future<void> transfer({required String toAgentId, required String note}) => _act((t) async {
    await _tickets.requestTransfer(t, toAgentId: toAgentId, note: note);
    return t;
  }, notice: ConversationNotice.transferRequested);

  Future<void> resolve({required String outcome, required String summary, List<String> tags = const []}) => _act(
    (t) => _tickets.resolve(t, outcome: outcome, summary: summary, tags: tags),
    notice: ConversationNotice.resolved,
  );

  Future<void> setPriority(String priority) => _act((t) => _tickets.setPriority(t, priority));

  Future<void> join() => _act((t) => _tickets.join(t.id), notice: ConversationNotice.joined);

  Future<void> reassign({required String toAgentId, required String reason}) =>
      _act((t) => _tickets.reassign(t.id, toAgentId: toAgentId, reason: reason), notice: ConversationNotice.reassigned);

  Future<void> sendCard(String card, String ref) => _act((t) async {
    await _tickets.sendSpecial(t, kind: 'card', payload: {'card': card, 'ref': ref});
    return t;
  }, notice: ConversationNotice.sent);

  Future<void> sendHelpLink({required String title, required String url}) => _act((t) async {
    await _tickets.sendSpecial(t, kind: 'help_link', body: title, payload: {'url': url});
    return t;
  }, notice: ConversationNotice.sent);

  Future<bool> addNote(String body) async {
    try {
      await _tickets.addNote(ticketId, body);
      if (!isClosed) emit(state.copyWith(notesVersion: state.notesVersion + 1));
      return true;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
      return false;
    }
  }

  Future<void> _act(Future<Ticket> Function(Ticket ticket) action, {ConversationNotice? notice}) async {
    final ticket = state.ticket;
    if (ticket == null || state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action(ticket);
      await _reload();
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          notice: notice ?? state.notice,
          noticeId: notice == null ? state.noticeId : state.noticeId + 1,
        ));
      }
    } catch (e) {
      final error = ConsoleError.from(e);
      if (error.isStale) {
        try {
          await _reload();
        } catch (_) {}
        if (!isClosed) {
          emit(state.copyWith(busy: false, notice: ConversationNotice.stale, noticeId: state.noticeId + 1));
        }
        return;
      }
      if (!isClosed) emit(state.copyWith(busy: false, actionError: error, actionErrorId: state.actionErrorId + 1));
    }
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _events.cancel();
    return super.close();
  }
}
