import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/repositories/link_preview_repository.dart';

const linkPreviewBucket = 'link-previews';

class LinkPreviewRepositoryImpl implements LinkPreviewRepository {
  LinkPreviewRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<List<LinkPreview>> lookup(List<String> urls) async {
    if (urls.isEmpty) return const [];
    final rows = await _api.rpcRows('get_link_previews', {'p_urls': urls});
    return [for (final row in rows) _preview(row)];
  }

  LinkPreview _preview(Map<String, dynamic> row) {
    final imagePath = row['image_path'] as String?;
    return LinkPreview(
      url: row['url'] as String? ?? '',
      status: LinkPreviewStatus.values.asNameMap()[row['status']] ?? LinkPreviewStatus.none,
      title: row['title'] as String?,
      description: row['description'] as String?,
      siteName: row['site_name'] as String?,
      imageUrl: imagePath == null || imagePath.isEmpty ? null : _api.publicUrl(linkPreviewBucket, imagePath),
      imageWidth: (row['image_width'] as num?)?.toInt(),
      imageHeight: (row['image_height'] as num?)?.toInt(),
      finalUrl: row['final_url'] as String?,
      fetchedAt: DateTime.tryParse(row['fetched_at'] as String? ?? ''),
    );
  }
}
