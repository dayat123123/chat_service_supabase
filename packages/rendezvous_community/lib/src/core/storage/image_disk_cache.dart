import 'dart:typed_data';

class CommunityImageCacheConfig {
  const CommunityImageCacheConfig({
    this.enabled = true,
    this.maxBytes = 200 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
  });

  const CommunityImageCacheConfig.disabled() : this(enabled: false);

  final bool enabled;
  final int maxBytes;
  final Duration maxAge;

  bool get persists => enabled && maxBytes > 0 && maxAge > Duration.zero;
}

abstract interface class ImageDiskCache {
  Future<Uint8List?> read(String key);

  Future<void> write(String key, Uint8List bytes);

  Future<void> wipe();
}

class NoImageDiskCache implements ImageDiskCache {
  const NoImageDiskCache();

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, Uint8List bytes) async {}

  @override
  Future<void> wipe() async {}
}

const _signatureParams = {
  'token',
  'signature',
  'sig',
  'expires',
  'expiry',
  'exp',
  'policy',
  'key-pair-id',
  'se',
  'sp',
  'sr',
  'st',
  'sv',
  'skoid',
  'sktid',
  'skt',
  'ske',
  'sks',
  'skv',
};

final _storageObject = RegExp(r'/storage/v1/(?:object|render/image)/(?:public|sign|authenticated)/(.+)$');

String imageCacheKeyForUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final storage = _storageObject.firstMatch(uri.path);
  if (storage != null) return 'storage:${Uri.decodeComponent(storage.group(1)!)}';
  final kept = <String, List<String>>{
    for (final entry in uri.queryParametersAll.entries)
      if (!_isSignatureParam(entry.key)) entry.key: [...entry.value]..sort(),
  };
  final names = kept.keys.toList()..sort();
  final query = [
    for (final name in names)
      for (final value in kept[name]!) '${Uri.encodeQueryComponent(name)}=${Uri.encodeQueryComponent(value)}',
  ].join('&');
  final base = '${uri.scheme}://${uri.authority}${uri.path}';
  return query.isEmpty ? base : '$base?$query';
}

bool _isSignatureParam(String name) {
  final lower = name.toLowerCase();
  return _signatureParams.contains(lower) || lower.startsWith('x-amz-') || lower.startsWith('x-goog-');
}

String imageCacheKeyForObject(String bucket, String path) => 'storage:$bucket/$path';
