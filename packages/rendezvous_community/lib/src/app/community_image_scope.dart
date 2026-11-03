import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/shared/presentation/images/community_image_loader.dart';

class CommunityImageScope extends InheritedWidget {
  const CommunityImageScope({super.key, required this.loader, required super.child});

  final CommunityImageLoader loader;

  static CommunityImageLoader of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityImageScope>()?.loader ??
      (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance.images : CommunityImageLoader.fallback);

  @override
  bool updateShouldNotify(CommunityImageScope oldWidget) => !identical(loader, oldWidget.loader);
}

class CommunityImagePersistence extends InheritedWidget {
  const CommunityImagePersistence({super.key, required this.persist, required super.child});

  final bool persist;

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityImagePersistence>()?.persist ?? true;

  @override
  bool updateShouldNotify(CommunityImagePersistence oldWidget) => persist != oldWidget.persist;
}
