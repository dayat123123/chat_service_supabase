import 'package:freezed_annotation/freezed_annotation.dart';

part 'link_preview.freezed.dart';

enum LinkPreviewStatus { ok, pending, none }

@freezed
abstract class LinkPreview with _$LinkPreview {
  const factory LinkPreview({
    required String url,
    @Default(LinkPreviewStatus.none) LinkPreviewStatus status,
    String? title,
    String? description,
    String? siteName,
    String? imageUrl,
    int? imageWidth,
    int? imageHeight,
    String? finalUrl,
    DateTime? fetchedAt,
  }) = _LinkPreview;

  const LinkPreview._();

  bool get hasCard =>
      status == LinkPreviewStatus.ok &&
      ((title?.trim().isNotEmpty ?? false) ||
          (description?.trim().isNotEmpty ?? false) ||
          (imageUrl?.isNotEmpty ?? false));

  String get domain {
    final uri = Uri.tryParse(finalUrl ?? url) ?? Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}
