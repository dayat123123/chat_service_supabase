import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/community_consent.dart';

abstract interface class CommunityAccountDependencies {
  CommunityConsent get consent;

  Future<CommunityDataExport> exportMyData();

  Future<void> deleteMyAccount();
}

class CommunityAccountScope extends InheritedWidget {
  const CommunityAccountScope({super.key, required this.dependencies, required super.child});

  final CommunityAccountDependencies dependencies;

  static CommunityAccountDependencies of(BuildContext context) => maybeOf(context) ?? RendezvousCommunity.instance;

  static CommunityAccountDependencies? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityAccountScope>()?.dependencies ??
      (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance : null);

  @override
  bool updateShouldNotify(CommunityAccountScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}
