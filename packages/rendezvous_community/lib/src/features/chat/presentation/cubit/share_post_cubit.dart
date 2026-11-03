import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:uuid/uuid.dart';

part 'share_post_cubit.freezed.dart';

const _uuid = Uuid();

@freezed
abstract class SharePostState with _$SharePostState {
  const factory SharePostState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<ChatRoom>[]) List<ChatRoom> rooms,
    String? sendingRoomId,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _SharePostState;
}

class SharePostCubit extends Cubit<SharePostState> {
  SharePostCubit({required this._chat, required this._extras, required this.postId}) : super(const SharePostState());

  final ChatRepository _chat;
  final ChatExtrasRepository _extras;
  final String postId;
  final _clientIds = <String, String>{};

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final page = await _chat.getRooms(limit: 50);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          rooms: [
            for (final room in page.items)
              if (room.type != RoomType.support) room,
          ],
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<bool> share(String roomId, {String? body}) async {
    if (state.sendingRoomId != null) return false;
    emit(state.copyWith(sendingRoomId: roomId));
    try {
      await _extras.sharePost(roomId, postId, body: body, clientId: _clientIds.putIfAbsent(roomId, _uuid.v4));
      if (!isClosed) emit(state.copyWith(sendingRoomId: null));
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(sendingRoomId: null, actionError: e, actionErrorId: state.actionErrorId + 1));
      }
      return false;
    }
  }
}
