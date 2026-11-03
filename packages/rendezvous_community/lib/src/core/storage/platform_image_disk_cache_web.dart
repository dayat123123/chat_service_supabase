import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';

ImageDiskCache platformImageDiskCache({
  required Future<String?> Function() owner,
  required CommunityImageCacheConfig config,
}) => const NoImageDiskCache();
