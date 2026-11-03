import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/share_post_sheet.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/edit/presentation/widgets/edit_content_dialog.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

typedef PostEditSaver = Future<bool> Function(Post post, String body);

bool canEditPost(BuildContext context, Post post) {
  if (context.communityFeatures == null || post.poll != null) return false;
  if (CommunityScope.of(context).currentUser?.id != post.author.id) return false;
  return context.communityConfig.canEdit(post.createdAt);
}

VoidCallback? editPostAction(BuildContext context, Post post, PostEditSaver? save) {
  if (save == null || !canEditPost(context, post)) return null;
  return () => editPostWithDialog(context, post, save);
}

Future<void> editPostWithDialog(BuildContext context, Post post, PostEditSaver save) async {
  final l10n = context.communityL10n;
  final body = await showEditContentDialog(
    context,
    title: l10n.editPostTitle,
    initial: post.body,
    maxLength: maxPostLength,
  );
  if (body == null || !context.mounted) return;
  if (await save(post, body) && context.mounted) showCommunityMessage(context, l10n.editSaved);
}

VoidCallback? bookmarkPostAction(BuildContext context, VoidCallback? toggle) =>
    toggle != null && context.communityFeature(CommunityFlags.bookmarks) ? toggle : null;

VoidCallback? sharePostAction(BuildContext context, Post post) =>
    context.communityFeature(CommunityFlags.sharePostToChat) && !post.isHeld && !post.isHidden
    ? () => showSharePostToChat(context, post)
    : null;

VoidCallback? appealPostAction(BuildContext context, Post post) => post.isHidden && context.communityFeatures != null
    ? () => showCommunityAppealDialog(context, targetType: AppealTargetType.post, targetId: post.id)
    : null;
