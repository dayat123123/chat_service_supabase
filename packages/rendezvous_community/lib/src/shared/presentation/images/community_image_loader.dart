import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';

class CommunityImageLoadException implements Exception {
  const CommunityImageLoadException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'CommunityImageLoadException($statusCode)';
}

class CommunityImageLoader {
  CommunityImageLoader({this._disk = const NoImageDiskCache(), http.Client? client})
    : _client = client,
      _ownsClient = client == null;

  static final CommunityImageLoader fallback = CommunityImageLoader();

  final ImageDiskCache _disk;
  http.Client? _client;
  final bool _ownsClient;
  final _memoryKeys = <Object>{};
  final _writes = <Future<void>>{};
  int _generation = 0;

  ImageDiskCache get disk => _disk;

  int get generation => _generation;

  void remember(Object key) => _memoryKeys.add(key);

  Future<Uint8List> load({
    required String cacheKey,
    required Future<AuthorizedImage> Function() resolve,
    bool persist = true,
  }) async {
    final generation = _generation;
    if (persist) {
      final cached = await _disk.read(cacheKey).catchError((Object _) => null);
      if (cached != null) return cached;
    }
    final target = await resolve();
    final client = _client ??= http.Client();
    final response = await client.get(Uri.parse(target.url), headers: target.headers);
    final bytes = response.bodyBytes;
    if (response.statusCode != 200 || bytes.isEmpty) throw CommunityImageLoadException(response.statusCode);
    if (persist && generation == _generation) {
      late final Future<void> write;
      write = _disk.write(cacheKey, bytes).catchError((Object _) {}).whenComplete(() => _writes.remove(write));
      _writes.add(write);
    }
    return bytes;
  }

  void evictMemory() {
    _generation++;
    if (_memoryKeys.isEmpty) return;
    final cache = PaintingBinding.instance.imageCache;
    for (final key in _memoryKeys) {
      cache.evict(key);
    }
    _memoryKeys.clear();
  }

  Future<void> settled() => Future.wait([..._writes]);

  Future<void> wipe() async {
    evictMemory();
    await settled();
    await _disk.wipe();
  }

  void dispose() {
    if (_ownsClient) _client?.close();
    _client = null;
  }
}
