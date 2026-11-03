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
    @Default(<String>{}) Set<String> moderatorIds,
    @Default(<String, DateTime>{}) Map<String, DateTime> mutes,
    DateTime? viewerMutedUntil,
  }) = _StockRoomState;

  const StockRoomState._();

  bool slowModeActive([DateTime? now]) {
    if (slowModeSeconds <= 0) return false;
    final until = slowModeUntil;
    return until == null || until.isAfter((now ?? DateTime.now()).toUtc());
  }

  bool isModerator(String? userId) => userId != null && moderatorIds.contains(userId);

  DateTime? mutedUntil(String? userId, [DateTime? now]) => _active(userId == null ? null : mutes[userId], now);

  DateTime? viewerMute([DateTime? now]) => _active(viewerMutedUntil, now);
}

DateTime? _active(DateTime? until, DateTime? now) =>
    until != null && until.isAfter((now ?? DateTime.now()).toUtc()) ? until : null;
