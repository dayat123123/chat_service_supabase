import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';

abstract interface class CommunitySupportDependencies {
  SupportRepository get support;

  ChatRepository get supportChat;
}

class CommunitySupportScope extends InheritedWidget {
  const CommunitySupportScope({super.key, required this.dependencies, required super.child});

  final CommunitySupportDependencies dependencies;

  static CommunitySupportDependencies of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunitySupportScope>()?.dependencies ?? RendezvousCommunity.instance;

  @override
  bool updateShouldNotify(CommunitySupportScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}
