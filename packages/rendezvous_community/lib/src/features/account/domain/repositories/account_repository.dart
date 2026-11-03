import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';

abstract interface class AccountRepository {
  Future<CommunityDataExport> exportMyData();

  Future<void> deleteMyAccount();
}
