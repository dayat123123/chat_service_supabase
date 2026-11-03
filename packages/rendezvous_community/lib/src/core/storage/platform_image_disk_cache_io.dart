import 'package:path_provider/path_provider.dart';
import 'package:rendezvous_community/src/core/storage/file_image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';

ImageDiskCache platformImageDiskCache({
  required Future<String?> Function() owner,
  required CommunityImageCacheConfig config,
}) => FileImageDiskCache(root: getApplicationSupportDirectory, owner: owner, config: config);
