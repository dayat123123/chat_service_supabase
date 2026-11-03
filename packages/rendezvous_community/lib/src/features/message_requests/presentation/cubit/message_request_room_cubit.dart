import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'message_request_room_cubit.freezed.dart';

@freezed
abstract class MessageRequestRoomState with _$MessageRequestRoomState {
  const factory MessageRequestRoomState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<ChatMessage>[]) List<ChatMessage> messages,
    MessageRequestAction? responding,
    MessageRequestAction? completed,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _MessageRequestRoomState;
}

class MessageRequestRoomCubit extends Cubit<MessageRequestRoomState> {
  MessageRequestRoomCubit({required this._chat, required this._requests, required this.roomId, this.pageSize = 50})
    : super(const MessageRequestRoomState());

  final ChatRepository _chat;
  final MessageRequestRepository _requests;
  final String roomId;
  final int pageSize;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final page = await _chat.getMessages(roomId, limit: pageSize);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, messages: page.items));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<bool> respond(MessageRequestAction action) async {
    if (state.responding != null) return false;
    emit(state.copyWith(responding: action));
    try {
      await _requests.respond(roomId, action);
      if (!isClosed) emit(state.copyWith(responding: null, completed: action));
      return true;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(responding: null, actionError: e, actionErrorId: state.actionErrorId + 1));
      return false;
    }
  }
}
