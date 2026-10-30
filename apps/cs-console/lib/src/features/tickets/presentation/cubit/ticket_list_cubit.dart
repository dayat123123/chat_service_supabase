import 'dart:async';

import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/data/ticket_repository.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

part 'ticket_list_cubit.freezed.dart';

enum TicketTab { open, mine, resolvedToday, allActive }

@freezed
abstract class TicketFilter with _$TicketFilter {
  const factory TicketFilter({String? topic, String? priority, String? flag}) = _TicketFilter;

  const TicketFilter._();

  bool get isEmpty => topic == null && priority == null && flag == null;

  bool matches(Ticket t) =>
      (topic == null || t.topic == topic) &&
      (priority == null || t.priority == priority) &&
      (flag == null || t.flags.contains(flag));
}

@freezed
abstract class TicketListState with _$TicketListState {
  const factory TicketListState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(TicketLists()) TicketLists lists,
    @Default(<SupportTopic>[]) List<SupportTopic> topics,
    @Default(TicketTab.open) TicketTab tab,
    @Default(TicketFilter()) TicketFilter filter,
    @Default('') String query,
    List<Ticket>? results,
    @Default(false) bool searching,
    @Default(<String>{}) Set<String> claiming,
    String? selectedId,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _TicketListState;

  const TicketListState._();

  List<Ticket> get tabTickets => switch (tab) {
    TicketTab.open => lists.open,
    TicketTab.mine => lists.mine,
    TicketTab.resolvedToday => lists.resolvedToday,
    TicketTab.allActive => lists.allActive,
  };

  List<Ticket> get visible {
    final source = results ?? tabTickets;
    final filtered = [for (final t in source) if (filter.matches(t)) t];
    if (results != null || tab == TicketTab.resolvedToday) return filtered;
    return filtered..sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : a.sortTime.compareTo(b.sortTime);
    });
  }

  Ticket? find(String id) {
    for (final list in [lists.mine, lists.open, lists.allActive, lists.resolvedToday, results ?? const <Ticket>[]]) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    for (final r in lists.transfersIn) {
      if (r.ticket.id == id) return r.ticket;
    }
    return null;
  }

  String topicName(String code) => topics.where((t) => t.code == code).firstOrNull?.name ?? code;
}

class TicketListCubit extends Cubit<TicketListState> {
  TicketListCubit({required this._tickets, required this._events, this.pollEvery = const Duration(seconds: 30)})
    : super(const TicketListState());

  final TicketRepository _tickets;
  final Stream<QueueEvent> _events;
  final Duration pollEvery;
  StreamSubscription<QueueEvent>? _subscription;
  Timer? _debounce;
  Timer? _poll;
  Timer? _searchDebounce;

  Future<void> start() async {
    emit(state.copyWith(status: LoadStatus.loading));
    _subscription = _events.listen(_onEvent);
    _poll = Timer.periodic(pollEvery, (_) => refresh());
    try {
      final topics = await _tickets.topics();
      if (!isClosed) emit(state.copyWith(topics: topics));
    } catch (_) {}
    await refresh();
  }

  void _onEvent(QueueEvent event) {
    if (event is ColleagueStatusChanged) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> refresh() async {
    try {
      final lists = await _tickets.lists();
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.ready, lists: lists, error: null));
      if (state.query.length >= 2) unawaited(_runSearch(state.query));
    } catch (e) {
      if (isClosed) return;
      emit(state.status == LoadStatus.ready ? state : state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  void selectTab(TicketTab tab) => emit(state.copyWith(tab: tab));

  void setFilter(TicketFilter filter) => emit(state.copyWith(filter: filter));

  void select(String? ticketId) => emit(state.copyWith(selectedId: ticketId));

  void search(String query) {
    final q = query.trim();
    _searchDebounce?.cancel();
    if (q.length < 2) {
      emit(state.copyWith(query: q, results: null, searching: false));
      return;
    }
    emit(state.copyWith(query: q, searching: true));
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await _tickets.search(query);
      if (!isClosed && state.query == query) emit(state.copyWith(results: results, searching: false));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(searching: false));
    }
  }

  Future<Ticket?> claim(Ticket ticket) async {
    if (state.claiming.contains(ticket.id)) return null;
    emit(state.copyWith(claiming: {...state.claiming, ticket.id}));
    try {
      final claimed = await _tickets.claim(ticket.id);
      if (isClosed) return claimed;
      emit(state.copyWith(
        claiming: {...state.claiming}..remove(ticket.id),
        selectedId: claimed.id,
        tab: TicketTab.mine,
      ));
      await refresh();
      return claimed;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          claiming: {...state.claiming}..remove(ticket.id),
          actionError: e,
          actionErrorId: state.actionErrorId + 1,
        ));
      }
      await refresh();
      return null;
    }
  }

  Future<void> respondTransfer(TransferRequest request, {required bool accept, String? reason}) async {
    try {
      final ticket = await _tickets.respondTransfer(request.id, accept: accept, reason: reason);
      if (!isClosed && accept) emit(state.copyWith(selectedId: ticket.id, tab: TicketTab.mine));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
    }
    await refresh();
  }

  Future<void> cancelTransfer(OutgoingTransfer transfer) async {
    try {
      await _tickets.cancelTransfer(transfer.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
    }
    await refresh();
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _poll?.cancel();
    _searchDebounce?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
