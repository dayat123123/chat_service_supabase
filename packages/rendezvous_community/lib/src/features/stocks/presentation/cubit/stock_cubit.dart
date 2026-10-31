import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock.dart';
import 'package:rendezvous_community/src/features/stocks/domain/repositories/stock_repository.dart';

part 'stock_cubit.freezed.dart';

@freezed
abstract class StockState with _$StockState {
  const factory StockState({
    Stock? stock,
    @Default(false) bool loaded,
    @Default(false) bool watching,
    @Default(false) bool joining,
    Object? error,
    @Default(0) int errorId,
  }) = _StockState;
}

class StockCubit extends Cubit<StockState> {
  StockCubit({required this._stocks, required this._chat, required this.code}) : super(const StockState());

  final StockRepository _stocks;
  final ChatRepository _chat;
  final String code;

  Future<void> load() async {
    try {
      final stock = await _stocks.getStock(code);
      if (!isClosed) emit(state.copyWith(stock: stock, watching: stock?.watching ?? false, loaded: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loaded: true, error: e, errorId: state.errorId + 1));
    }
  }

  Future<void> toggleWatch() async {
    final watching = !state.watching;
    final stock = state.stock;
    emit(
      state.copyWith(
        watching: watching,
        stock: stock?.copyWith(watcherCount: stock.watcherCount + (watching ? 1 : -1), watching: watching),
      ),
    );
    try {
      watching ? await _stocks.watch(code) : await _stocks.unwatch(code);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(watching: !watching, stock: stock, error: e, errorId: state.errorId + 1));
    }
  }

  Future<String?> joinDiscussion() async {
    emit(state.copyWith(joining: true));
    try {
      return await _chat.joinStockRoom(code);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: e, errorId: state.errorId + 1));
      return null;
    } finally {
      if (!isClosed) emit(state.copyWith(joining: false));
    }
  }
}
