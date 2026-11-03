import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';

abstract interface class LinkPreviewRepository {
  Future<List<LinkPreview>> lookup(List<String> urls);
}
