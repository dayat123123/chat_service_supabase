import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';

abstract interface class AppealRepository {
  Future<Appeal> createAppeal(AppealTargetType targetType, String targetId, String reason);

  Future<List<Appeal>> myAppeals();

  Future<List<Sanction>> mySanctions();

  Future<List<ModeratedContent>> myModeratedContent({int limit = 50});
}
