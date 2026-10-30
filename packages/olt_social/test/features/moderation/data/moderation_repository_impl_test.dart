import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/src/features/moderation/data/repositories/moderation_repository_impl.dart';
import 'package:olt_social/src/features/moderation/domain/entities/report.dart';

import '../../../support/mock_api.dart';

void main() {
  test('report memakai nama alasan sesuai constraint DB', () async {
    final api = mockApi();
    when(() => api.insert('reports', any())).thenAnswer((_) async {});

    await ModerationRepositoryImpl(api).report(
      target: ReportTarget.post,
      targetId: 'p-1',
      reason: ReportReason.pumpAndDump,
    );

    final values = verify(() => api.insert('reports', captureAny())).captured.single as Map<String, Object?>;
    expect(values['reason'], 'pump_and_dump');
    expect(values['target_type'], 'post');
  });
}
