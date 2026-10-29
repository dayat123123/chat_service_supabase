import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/repositories.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../widgets/common.dart';
import 'feed_list.dart';

part 'olt_stock_feed.freezed.dart';

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
  StockCubit({required this._stocks, required this._chat, required this.code})
    : super(const StockState());

  final StockRepository _stocks;
  final ChatRepository _chat;
  final String code;

  Future<void> load() async {
    try {
      final results = await Future.wait([_stocks.getStock(code), _stocks.isWatching(code)]);
      if (!isClosed) emit(state.copyWith(stock: results[0] as Stock?, watching: results[1]! as bool, loaded: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loaded: true, error: e, errorId: state.errorId + 1));
    }
  }

  /// Pantau/berhenti memantau (optimistic).
  Future<void> toggleWatch() async {
    final watching = !state.watching;
    final stock = state.stock;
    emit(state.copyWith(
      watching: watching,
      stock: stock?.copyWith(watcherCount: stock.watcherCount + (watching ? 1 : -1)),
    ));
    try {
      watching ? await _stocks.watch(code) : await _stocks.unwatch(code);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(watching: !watching, stock: stock, error: e, errorId: state.errorId + 1));
    }
  }

  /// Masuk room diskusi saham; mengembalikan id room.
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

/// Feed sebuah saham, untuk ditempel di halaman saham OLT.
class OltStockFeed extends StatelessWidget {
  const OltStockFeed({super.key, required this.stockCode, this.showHeader = true});

  final String stockCode;

  /// Sembunyikan header bila halaman saham OLT sudah menampilkan info saham.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    final code = stockCode.toUpperCase();
    return BlocProvider(
      create: (_) => StockCubit(stocks: deps.stocks, chat: deps.chat, code: code)..load(),
      child: BlocListener<StockCubit, StockState>(
        listenWhen: (a, b) => a.errorId != b.errorId,
        listener: (context, state) => showOltError(context, state.error!),
        child: OltFeedList(
          scope: FeedScope.stock(code),
          emptyMessage: context.oltL10n.stockFeedEmpty(code),
          header: Column(
            children: [
              if (showHeader) const _StockHeader(),
              ComposePromptCard(initialStock: code),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockHeader extends StatelessWidget {
  const _StockHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocBuilder<StockCubit, StockState>(
      builder: (context, state) {
        final cubit = context.read<StockCubit>();
        final stock = state.stock;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.show_chart),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${cubit.code}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (stock != null)
                      Text(
                        '${stock.name} · ${l10n.watchers(stock.watcherCount)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (state.loaded)
                      Text(l10n.stockNotFound, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (stock != null) ...[
                state.watching
                    ? FilledButton.tonalIcon(
                        onPressed: cubit.toggleWatch,
                        icon: const Icon(Icons.star),
                        label: Text(l10n.watching),
                      )
                    : OutlinedButton.icon(
                        onPressed: cubit.toggleWatch,
                        icon: const Icon(Icons.star_border),
                        label: Text(l10n.watch),
                      ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: l10n.stockDiscussion,
                  onPressed: state.joining
                      ? null
                      : () async {
                          final roomId = await cubit.joinDiscussion();
                          if (roomId != null && context.mounted) OltNavigator.openRoom(context, roomId);
                        },
                  icon: const Icon(Icons.forum_outlined),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
