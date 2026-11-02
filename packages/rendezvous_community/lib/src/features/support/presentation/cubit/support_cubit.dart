import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/support/domain/entities/support_ticket.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'support_cubit.freezed.dart';

enum SupportNoticeKind { closed, complaintFiled, fakeReported, rated }

@freezed
abstract class SupportState with _$SupportState {
  const factory SupportState({
    @Default(LoadStatus.initial) LoadStatus status,
    SupportHome? home,
    @Default(<SupportTopic>[]) List<SupportTopic> topics,
    @Default(false) bool picking,
    @Default(false) bool history,
    @Default(false) bool busy,
    @Default(SensitiveCheck()) SensitiveCheck sensitive,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
    SupportNoticeKind? notice,
    @Default(0) int noticeId,
  }) = _SupportState;

  const SupportState._();

  SupportTicket? get ticket => home?.ticket;

  bool showsConversation(DateTime now) =>
      (history && home?.roomId != null) || (!picking && (home?.showsConversation(now) ?? false));

  bool canRate(String ticketId) => ticket?.id == ticketId && (ticket?.canRate ?? false);
}

class SupportCubit extends Cubit<SupportState> {
  SupportCubit({required this._support, this.topic, this.screen, this.language = 'id'}) : super(const SupportState());

  final SupportRepository _support;
  final String? topic;
  final String? screen;
  final String language;
  StreamSubscription<void>? _ticketEvents;
  String? _watchedRoom;
  Timer? _sensitiveDebounce;
  int _sensitiveRequest = 0;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final results = await Future.wait([_support.home(), _support.topics(language: language)]);
      if (isClosed) return;
      final home = results[0] as SupportHome;
      emit(state.copyWith(status: LoadStatus.ready, home: home, topics: results[1] as List<SupportTopic>));
      _watch(home.roomId);
      final initialTopic = topic;
      if (!home.active && initialTopic != null) await start(initialTopic);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  void _watch(String? roomId) {
    if (roomId == null || roomId == _watchedRoom) return;
    _watchedRoom = roomId;
    unawaited(_ticketEvents?.cancel());
    _ticketEvents = _support.watchTicket(roomId).listen((_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final home = await _support.home();
      if (isClosed) return;
      emit(state.copyWith(home: home));
      _watch(home.roomId);
    } catch (_) {}
  }

  void pickTopic() => emit(state.copyWith(picking: true, history: false));

  void showHistory() => emit(state.copyWith(picking: false, history: true));

  Future<void> start(String topic) => _act(() async {
    await _support.openTicket(topic: topic, language: language, screen: screen);
    await refresh();
    if (!isClosed) emit(state.copyWith(picking: false, history: false));
  });

  Future<void> closeTicket() => _act(() async {
    final ticket = state.ticket;
    if (ticket == null || !ticket.isActive) return;
    await _support.closeTicket(ticket.id);
    await refresh();
  }, notice: SupportNoticeKind.closed);

  Future<void> fileComplaint() => _act(() async {
    await _support.requestComplaint();
    await refresh();
  }, notice: SupportNoticeKind.complaintFiled);

  Future<void> reportFakeCs(String description) => _act(() async {
    await _support.reportFakeCs(description);
    await refresh();
    if (!isClosed) emit(state.copyWith(picking: false));
  }, notice: SupportNoticeKind.fakeReported);

  Future<void> rate(String ticketId, int rating, {String? comment}) => _act(() async {
    await _support.rateTicket(ticketId, rating, comment: comment);
    await refresh();
  }, notice: SupportNoticeKind.rated);

  void checkText(String text) {
    _sensitiveDebounce?.cancel();
    final value = text.trim();
    if (value.length < 4) {
      if (state.sensitive.masked) emit(state.copyWith(sensitive: const SensitiveCheck()));
      return;
    }
    _sensitiveDebounce = Timer(const Duration(milliseconds: 600), () async {
      final request = ++_sensitiveRequest;
      try {
        final check = await _support.checkSensitive(value);
        if (!isClosed && request == _sensitiveRequest) emit(state.copyWith(sensitive: check));
      } catch (_) {}
    });
  }

  Future<void> _act(Future<void> Function() action, {SupportNoticeKind? notice}) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            notice: notice ?? state.notice,
            noticeId: notice == null ? state.noticeId : state.noticeId + 1,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) emit(state.copyWith(busy: false, actionError: e, actionErrorId: state.actionErrorId + 1));
    }
  }

  @override
  Future<void> close() async {
    _sensitiveDebounce?.cancel();
    await _ticketEvents?.cancel();
    return super.close();
  }
}
