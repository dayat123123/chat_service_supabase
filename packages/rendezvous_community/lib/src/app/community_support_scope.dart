import 'package:flutter/widgets.dart';
import 'package:olt_social/src/app/olt_social.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/features/support/domain/repositories/support_repository.dart';

abstract interface class OltSupportDependencies {
  SupportRepository get support;

  ChatRepository get supportChat;
}

class OltSupportScope extends InheritedWidget {
  const OltSupportScope({super.key, required this.dependencies, required super.child});

  final OltSupportDependencies dependencies;

  static OltSupportDependencies of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OltSupportScope>()?.dependencies ?? OltSocial.instance;

  @override
  bool updateShouldNotify(OltSupportScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}
