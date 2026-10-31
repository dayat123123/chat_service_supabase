import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/stocks/data/models/stock_model.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock.dart';
import 'package:rendezvous_community/src/features/stocks/domain/repositories/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Stock?> getStock(String code) async {
    final rows = await _api.rpcRows('get_stock', {'p_code': code});
    return rows.isEmpty ? null : StockModel.fromJson(rows.first).toEntity();
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
