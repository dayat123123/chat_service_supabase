import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/features/moderation/data/repositories/moderation_repository_impl.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';

import '../../../support/mock_api.dart';

void main() {
  test('report uses reason names that match the DB constraint', () async {
    final api = mockApi();
    when(() => api.insert('reports', any())).thenAnswer((_) async {});

    await ModerationRepositoryImpl(
      api,
    ).report(target: ReportTarget.post, targetId: 'p-1', reason: ReportReason.pumpAndDump);

    final values = verify(() => api.insert('reports', captureAny())).captured.single as Map<String, Object?>;
    expect(values['reason'], 'pump_and_dump');
    expect(values['target_type'], 'post');
  });
}
