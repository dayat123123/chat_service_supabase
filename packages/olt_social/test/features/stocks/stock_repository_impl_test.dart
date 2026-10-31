import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/stocks/data/repositories/stock_repository_impl.dart';

import '../../support/mock_api.dart';

void main() {
  late MockApi api;
  late StockRepositoryImpl repo;

  setUp(() {
    api = mockApi();
    repo = StockRepositoryImpl(api);
  });

  test('ringkasan saham diambil dari RPC get_stock tanpa daftar saham di server', () async {
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

  test('kode berformat salah tidak menghasilkan saham', () async {
    when(() => api.rpcRows('get_stock', any())).thenAnswer((_) async => const []);

    expect(await repo.getStock('1X'), isNull);
  });
}
