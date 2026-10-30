import 'package:olt_social/src/features/moderation/domain/entities/report.dart';

abstract interface class ModerationRepository {
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  });
}
