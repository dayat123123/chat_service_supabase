import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';

import '../../../support/fakes.dart';
import '../../../support/feature_fakes.dart';

Widget _hostStockCard(BuildContext context, CommunityStockCardDetails d, Widget fallback) => Text('host ${d.code}');

Widget _nestedMessage(BuildContext context, CommunityMessageDetails d, Widget fallback) => fallback;

void main() {
  test('merge keeps the host stock card builder when the nested set leaves it empty', () {
    const host = CommunityChatBuilders(stockCard: _hostStockCard);
    final merged = host.merge(const CommunityChatBuilders(message: _nestedMessage));
    expect(merged.stockCard, same(_hostStockCard));
    expect(merged.message, same(_nestedMessage));
  });

  testWidgets('a nested chat builders scope still renders the host stock card builder', (tester) async {
    await pumpFeatureApp(
      tester,
      CommunityChatBuildersScope(
        builders: const CommunityChatBuilders(stockCard: _hostStockCard),
        child: Builder(
          builder: (context) => withChatBuilders(
            context,
            const CommunityChatBuilders(message: _nestedMessage),
            const StockCards(codes: ['BBCA'], isMine: false),
          ),
        ),
      ),
      dependencies: FakeDependencies(),
    );

    expect(find.text('host BBCA'), findsOneWidget);
  });
}
