import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/shared/domain/official_accounts.dart';

class CommunityOfficialScope extends InheritedWidget {
  const CommunityOfficialScope({super.key, required this.accounts, required super.child});

  final OfficialAccounts accounts;

  static OfficialAccounts? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityOfficialScope>()?.accounts ??
      (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance.officialAccounts : null);

  @override
  bool updateShouldNotify(CommunityOfficialScope oldWidget) => !identical(accounts, oldWidget.accounts);
}
