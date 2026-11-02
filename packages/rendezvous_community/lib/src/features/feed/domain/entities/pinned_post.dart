import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';

part 'pinned_post.freezed.dart';

@freezed
abstract class PinnedPost with _$PinnedPost {
  const factory PinnedPost({
    required Post post,
    @Default(false) bool announcement,
    String? title,
    DateTime? pinnedUntil,
  }) = _PinnedPost;
}
