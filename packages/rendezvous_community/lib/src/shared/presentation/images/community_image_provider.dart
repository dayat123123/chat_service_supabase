import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/shared/presentation/images/community_image_loader.dart';

const communityMaxDecodeDimension = 2048;

const _bucket = 64;

int? communityDecodeDimension(double? logical, double devicePixelRatio) {
  if (logical == null || !logical.isFinite || logical <= 0) return null;
  final physical = (logical * devicePixelRatio / _bucket).ceil() * _bucket;
  return math.min(physical, communityMaxDecodeDimension);
}

ui.TargetImageSize coverTargetSize(int width, int height, {int? targetWidth, int? targetHeight}) {
  if (width <= 0 || height <= 0) return const ui.TargetImageSize();
  final scaleX = targetWidth == null ? 0.0 : targetWidth / width;
  final scaleY = targetHeight == null ? 0.0 : targetHeight / height;
  var scale = targetWidth == null && targetHeight == null ? 1.0 : math.max(scaleX, scaleY);
  scale = math.min(scale, communityMaxDecodeDimension / math.max(width, height));
  if (scale >= 1) return const ui.TargetImageSize();
  return ui.TargetImageSize(width: math.max(1, (width * scale).round()), height: math.max(1, (height * scale).round()));
}

@immutable
class CommunityImageProvider extends ImageProvider<CommunityImageProvider> {
  const CommunityImageProvider({
    required this.cacheKey,
    required this.source,
    required this.loader,
    this.persist = true,
    this.targetWidth,
    this.targetHeight,
  });

  final String cacheKey;
  final Future<AuthorizedImage> Function() source;
  final CommunityImageLoader loader;
  final bool persist;
  final int? targetWidth;
  final int? targetHeight;

  @override
  Future<CommunityImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CommunityImageProvider key, ImageDecoderCallback decode) {
    loader.remember(key);
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: cacheKey,
      informationCollector: () => [DiagnosticsProperty<ImageProvider>('Image provider', this)],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await loader.load(cacheKey: cacheKey, resolve: source, persist: persist);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(
      buffer,
      getTargetSize: (width, height) =>
          coverTargetSize(width, height, targetWidth: targetWidth, targetHeight: targetHeight),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CommunityImageProvider &&
      other.cacheKey == cacheKey &&
      other.targetWidth == targetWidth &&
      other.targetHeight == targetHeight;

  @override
  int get hashCode => Object.hash(cacheKey, targetWidth, targetHeight);

  @override
  String toString() => 'CommunityImageProvider($cacheKey, ${targetWidth}x$targetHeight)';
}
