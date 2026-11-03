import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';

part 'stock_room_state.freezed.dart';

@freezed
abstract class StockRoomState with _$StockRoomState {
  const factory StockRoomState({
    String? roomId,
    String? stockCode,
    @Default(0) int slowModeSeconds,
    DateTime? slowModeUntil,
    String? slowModeSource,
    @Default(0) int waitSeconds,
    ChatMessage? pinnedMessage,
    DateTime? pinnedAt,
  }) = _StockRoomState;

  const StockRoomState._();

  bool slowModeActive([DateTime? now]) {
    if (slowModeSeconds <= 0) return false;
    final until = slowModeUntil;
    return until == null || until.isAfter((now ?? DateTime.now()).toUtc());
  }
}
