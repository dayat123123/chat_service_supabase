import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'message_requests_cubit.freezed.dart';

@freezed
abstract class MessageRequestsState with _$MessageRequestsState {
  const factory MessageRequestsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<MessageRequest>[]) List<MessageRequest> requests,
    @Default(0) int count,
    @Default(false) bool loadingMore,
    @Default(true) bool hasMore,
    String? respondingRoomId,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _MessageRequestsState;
}

class MessageRequestsCubit extends Cubit<MessageRequestsState> {
  MessageRequestsCubit(this._requests, {this.pageSize = 30}) : super(const MessageRequestsState());

  final MessageRequestRepository _requests;
  final int pageSize;

  Future<void> loadCount() async {
    try {
      final count = await _requests.requestCount();
      if (!isClosed) emit(state.copyWith(count: count));
    } catch (_) {}
  }

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final requests = await _requests.getRequests(limit: pageSize);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          requests: requests,
          hasMore: requests.length >= pageSize,
          count: requests.length >= pageSize ? state.count : requests.length,
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> loadMore() async {
    final last = state.requests.lastOrNull;
    if (!state.hasMore || state.loadingMore || last == null) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final more = await _requests.getRequests(limit: pageSize, before: last.createdAt);
      if (isClosed) return;
      final known = {for (final r in state.requests) r.roomId};
      emit(
        state.copyWith(
          loadingMore: false,
          hasMore: more.length >= pageSize,
          requests: [...state.requests, ...more.where((r) => !known.contains(r.roomId))],
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loadingMore: false, actionError: e, actionErrorId: state.actionErrorId + 1));
    }
  }

  Future<bool> respond(String roomId, MessageRequestAction action) async {
    if (state.respondingRoomId != null) return false;
    emit(state.copyWith(respondingRoomId: roomId));
    try {
      await _requests.respond(roomId, action);
      if (isClosed) return true;
      emit(
        state.copyWith(
          respondingRoomId: null,
          requests: [
            for (final r in state.requests)
              if (r.roomId != roomId) r,
          ],
          count: state.count > 0 ? state.count - 1 : 0,
        ),
      );
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(respondingRoomId: null, actionError: e, actionErrorId: state.actionErrorId + 1));
      }
      return false;
    }
  }

  void removeRequest(String roomId) => emit(
    state.copyWith(
      requests: [
        for (final r in state.requests)
          if (r.roomId != roomId) r,
      ],
      count: state.count > 0 ? state.count - 1 : 0,
    ),
  );
}
