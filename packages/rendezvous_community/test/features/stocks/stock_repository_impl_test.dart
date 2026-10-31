import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/stocks/data/repositories/stock_repository_impl.dart';

import '../../support/mock_api.dart';

void main() {
  late MockApi api;
  late StockRepositoryImpl repo;

  setUp(() {
    api = mockApi();
    repo = StockRepositoryImpl(api);
  });

  test('the stock summary comes from the get_stock RPC without a server-side stock list', () async {
    when(() => api.rpcRows('get_stock', any())).thenAnswer(
      (_) async => [
        {'code': 'NEWCO', 'watcher_count': 3, 'watching': true},
      ],
    );

    final stock = await repo.getStock('newco');

    expect(stock, const Stock(code: 'NEWCO', watcherCount: 3, watching: true));
    final params = verify(() => api.rpcRows('get_stock', captureAny())).captured.single as Map<String, Object?>;
    expect(params, {'p_code': 'newco'});
  });

  test('malformed codes yield no stock', () async {
    when(() => api.rpcRows('get_stock', any())).thenAnswer((_) async => const []);

    expect(await repo.getStock('1X'), isNull);
  });
}
