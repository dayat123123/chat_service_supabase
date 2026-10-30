import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/stocks/data/models/stock_model.dart';
import 'package:olt_social/src/features/stocks/domain/entities/stock.dart';
import 'package:olt_social/src/features/stocks/domain/repositories/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Stock?> getStock(String code) async {
    final rows = await _api.select(
      'stocks',
      columns: 'code,name,type,sector,watcher_count',
      match: {'code': code.toUpperCase()},
      limit: 1,
    );
    return rows.isEmpty ? null : StockModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<List<Stock>> searchStocks(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _api.rpcRows('search_stocks', {'p_query': query, 'p_limit': limit});
    return [for (final row in rows) StockModel.fromJson(row).toEntity()];
  }

  @override
  Future<bool> isWatching(String code) async {
    final me = await _api.requireUserId();
    final rows = await _api.select(
      'stock_watchers',
      columns: 'stock_code',
      match: {'user_id': me, 'stock_code': code.toUpperCase()},
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> watch(String code) async {
    final me = await _api.requireUserId();
    await _api.insertIgnoringDuplicate('stock_watchers', {'user_id': me, 'stock_code': code.toUpperCase()});
  }

  @override
  Future<void> unwatch(String code) async {
    final me = await _api.requireUserId();
    await _api.delete('stock_watchers', {'user_id': me, 'stock_code': code.toUpperCase()});
  }
}
