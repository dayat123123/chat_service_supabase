import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_image_scope.dart';
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';
import 'package:rendezvous_community/src/shared/presentation/images/community_image_provider.dart';

CommunityImageProvider communityImageProvider(
  BuildContext context, {
  required String cacheKey,
  required Future<AuthorizedImage> Function() source,
  double? width,
  double? height,
  bool persist = true,
}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  return CommunityImageProvider(
    cacheKey: cacheKey,
    source: source,
    loader: CommunityImageScope.of(context),
    persist: persist && CommunityImagePersistence.of(context),
    targetWidth: communityDecodeDimension(width, dpr),
    targetHeight: communityDecodeDimension(height, dpr),
  );
}

CommunityImageProvider communityUrlImageProvider(BuildContext context, String url, {double? width, double? height}) =>
    communityImageProvider(
      context,
      cacheKey: imageCacheKeyForUrl(url),
      source: () async => AuthorizedImage(url, const {}),
      width: width,
      height: height,
    );

class CommunityNetworkImage extends StatelessWidget {
  const CommunityNetworkImage({
    super.key,
    required this.cacheKey,
    required this.source,
    this.persist = true,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
  });

  CommunityNetworkImage.url(String url, {Key? key, BoxFit fit = BoxFit.cover, Widget? placeholder, Widget? error})
    : this(
        key: key,
        cacheKey: imageCacheKeyForUrl(url),
        source: () async => AuthorizedImage(url, const {}),
        fit: fit,
        placeholder: placeholder,
        error: error,
      );

  final String cacheKey;
  final Future<AuthorizedImage> Function() source;
  final bool persist;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final provider = communityImageProvider(
        context,
        cacheKey: cacheKey,
        source: source,
        width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
        height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
        persist: persist,
      );
      final placeholder = this.placeholder ?? const SizedBox.expand();
      return Image(
        image: provider,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, synchronous) => frame == null && !synchronous ? placeholder : child,
        errorBuilder: (context, _, _) => error ?? placeholder,
      );
    },
  );
}
