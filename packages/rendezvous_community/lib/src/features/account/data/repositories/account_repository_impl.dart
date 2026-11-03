import 'dart:convert';
import 'dart:typed_data';

import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:rendezvous_community/src/features/account/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._api, {String? Function()? currentUsername, DateTime Function()? clock})
    : _currentUsername = currentUsername ?? (() => null),
      _clock = clock ?? DateTime.now;

  final SocialRemoteDataSource _api;
  final String? Function() _currentUsername;
  final DateTime Function() _clock;

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<CommunityDataExport> exportMyData() async {
    final data = await _api.rpcValue('export_my_data');
    final bytes = Uint8List.fromList(utf8.encode(_encoder.convert(data)));
    final owner = _username(data) ?? _currentUsername() ?? _api.currentUserId ?? '';
    return CommunityDataExport(bytes: bytes, fileName: CommunityDataExport.fileNameFor(owner, _clock()));
  }

  @override
  Future<void> deleteMyAccount() => _api.rpcValue('delete_my_account');

  static String? _username(Object? data) {
    if (data is! Map) return null;
    final profile = data['profile'];
    if (profile is! Map) return null;
    final username = profile['username'];
    return username is String && username.isNotEmpty ? username : null;
  }
}
