import 'dart:async';

import 'package:cs_console/src/features/customer/data/customer_repository.dart';
import 'package:cs_console/src/features/customer/domain/customer_records.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

part 'customer_cubit.freezed.dart';

class Section<T> {
  const Section({this.status = LoadStatus.initial, this.data, this.error});

  final LoadStatus status;
  final T? data;
  final Object? error;

  Section<T> loading() => Section(status: LoadStatus.loading, data: data);
}

@freezed
abstract class CustomerState with _$CustomerState {
  const factory CustomerState({
    @Default(false) bool canViewData,
    @Default(Section<Map<String, dynamic>>()) Section<Map<String, dynamic>> profile,
    @Default(Section<List<Map<String, dynamic>>>()) Section<List<Map<String, dynamic>>> orders,
    @Default(Section<List<Map<String, dynamic>>>()) Section<List<Map<String, dynamic>>> cash,
    @Default(Section<Map<String, dynamic>>()) Section<Map<String, dynamic>> devices,
    @Default(Section<Map<String, dynamic>>()) Section<Map<String, dynamic>> security,
    @Default(Section<List<TicketHistoryItem>>()) Section<List<TicketHistoryItem>> history,
    @Default(Section<List<AgentNote>>()) Section<List<AgentNote>> notes,
    @Default(<String, RevealedField>{}) Map<String, RevealedField> revealed,
    @Default(false) bool securing,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _CustomerState;
}

class CustomerCubit extends Cubit<CustomerState> {
  CustomerCubit({required this._customers, required this.ticketId, required this.customerId})
    : super(const CustomerState());

  final CustomerRepository _customers;
  final String ticketId;
  final String customerId;
  Timer? _expiry;

  Future<void> load({required bool canViewData}) async {
    emit(state.copyWith(canViewData: canViewData));
    await Future.wait([
      _section(() => _customers.history(customerId), (s) => state.copyWith(history: s), state.history),
      _section(() => _customers.notes(customerId), (s) => state.copyWith(notes: s), state.notes),
      if (canViewData) ...[
        _section(() => _customers.profile(ticketId), (s) => state.copyWith(profile: s), state.profile),
        _section(() => _customers.orders(ticketId), (s) => state.copyWith(orders: s), state.orders),
        _section(() => _customers.cashTransactions(ticketId), (s) => state.copyWith(cash: s), state.cash),
        _section(() => _customers.devices(ticketId), (s) => state.copyWith(devices: s), state.devices),
        _section(() => _customers.security(ticketId), (s) => state.copyWith(security: s), state.security),
      ],
    ]);
  }

  Future<void> reloadNotes() =>
      _section(() => _customers.notes(customerId), (s) => state.copyWith(notes: s), state.notes);

  Future<void> _section<T>(
    Future<T> Function() fetch,
    CustomerState Function(Section<T> section) apply,
    Section<T> current,
  ) async {
    emit(apply(current.loading()));
    try {
      final data = await fetch();
      if (!isClosed) emit(apply(Section(status: LoadStatus.ready, data: data)));
    } catch (e) {
      if (!isClosed) emit(apply(Section(status: LoadStatus.failure, error: e)));
    }
  }

  Future<bool> reveal(String field, String reason) async {
    try {
      final revealed = await _customers.reveal(ticketId, field: field, reason: reason);
      if (isClosed) return true;
      emit(state.copyWith(revealed: {...state.revealed, field: revealed}));
      _scheduleExpiry();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final next = state.revealed.values.map((r) => r.until).reduce((a, b) => a.isBefore(b) ? a : b);
    _expiry = Timer(next.difference(DateTime.now()) + const Duration(milliseconds: 200), () {
      if (isClosed) return;
      final now = DateTime.now();
      emit(state.copyWith(revealed: {
        for (final entry in state.revealed.entries)
          if (entry.value.until.isAfter(now)) entry.key: entry.value,
      }));
      if (state.revealed.isNotEmpty) _scheduleExpiry();
    });
  }

  Future<Map<String, dynamic>?> order(String ref) async {
    try {
      return await _customers.order(ticketId, ref);
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> cashTransaction(String ref) async {
    try {
      return await _customers.cashTransaction(ticketId, ref);
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> addNote(String body) async {
    try {
      await _customers.addNote(body: body, customerId: customerId);
      await reloadNotes();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> secureAccount() async {
    emit(state.copyWith(securing: true));
    try {
      final result = await _customers.secureAccount(ticketId);
      if (!isClosed) emit(state.copyWith(securing: false));
      unawaited(_section(() => _customers.security(ticketId), (s) => state.copyWith(security: s), state.security));
      return result;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(securing: false));
      _fail(e);
      return null;
    }
  }

  void _fail(Object error) {
    if (!isClosed) emit(state.copyWith(actionError: error, actionErrorId: state.actionErrorId + 1));
  }

  @override
  Future<void> close() {
    _expiry?.cancel();
    return super.close();
  }
}
