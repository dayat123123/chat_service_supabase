import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:rendezvous_community/src/features/compose/presentation/widgets/poll_editor.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_flow.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_composer_field.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_disclaimer.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/moderation_notice.dart';

class CommunityComposerImage {
  const CommunityComposerImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<Post?> showCommunityComposer(
  BuildContext context, {
  String? initialStock,
  CommunityComposerImage? initialImage,
  PostDraft? draft,
}) {
  final deps = CommunityScope.of(context);
  final features = context.getInheritedWidgetOfExactType<CommunityFeatureScope>()?.dependencies;
  final l10n = context.communityL10n;
  Widget scoped(Widget child) {
    final page = CommunityScope(dependencies: deps, child: child);
    return features == null ? page : CommunityFeatureScope(dependencies: features, child: page);
  }

  if (CommunityBreakpoints.isWide(context)) {
    return showDialog<Post>(
      context: context,
      builder: (dialogContext) => scoped(
        Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CommunityComposePost(
              initialStock: initialStock,
              initialImage: initialImage,
              draft: draft,
              autofocus: true,
              onPosted: (post) => Navigator.pop(dialogContext, post),
            ),
          ),
        ),
      ),
    );
  }
  return Navigator.of(context).push<Post>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (pageContext) => scoped(
        Scaffold(
          appBar: AppBar(title: Text(l10n.composeTitle)),
          body: SafeArea(
            child: CommunityComposePost(
              initialStock: initialStock,
              initialImage: initialImage,
              draft: draft,
              autofocus: true,
              onPosted: (post) => Navigator.pop(pageContext, post),
            ),
          ),
        ),
      ),
    ),
  );
}

class CommunityComposePost extends StatelessWidget {
  const CommunityComposePost({
    super.key,
    this.initialStock,
    this.initialImage,
    this.onPosted,
    this.autofocus = false,
    this.draft,
  });

  final String? initialStock;
  final CommunityComposerImage? initialImage;
  final ValueChanged<Post>? onPosted;
  final bool autofocus;
  final PostDraft? draft;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return CommunitySocialGate(
      child: BlocProvider(
        create: (_) => ComposeCubit(
          feed: deps.feed,
          media: deps.media,
          consent: communityConsentGate(context),
          drafts: context.communityFeatures?.drafts,
          draft: draft,
        ),
        child: _ComposeView(
          initialStock: initialStock,
          initialImage: initialImage,
          onPosted: onPosted,
          autofocus: autofocus,
          draft: draft,
        ),
      ),
    );
  }
}

class _ComposeView extends StatefulWidget {
  const _ComposeView({this.initialStock, this.initialImage, this.onPosted, required this.autofocus, this.draft});

  final String? initialStock;
  final CommunityComposerImage? initialImage;
  final ValueChanged<Post>? onPosted;
  final bool autofocus;
  final PostDraft? draft;

  @override
  State<_ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<_ComposeView> {
  late final _controller = TextEditingController(
    text: widget.draft?.body ?? (widget.initialStock == null ? '' : '\$${widget.initialStock!.toUpperCase()} '),
  );

  String? _chartPath;
  int _draftNotice = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => context.read<ComposeCubit>().bodyChanged(_controller.text));
    final image = widget.initialImage;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final cubit = context.read<ComposeCubit>();
        await cubit.addImage(image.bytes, image.mimeType);
        if (mounted && cubit.state.attachments.isNotEmpty) _chartPath = cubit.state.attachments.first.path;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<ComposeCubit>();
    final hasPoll = cubit.state.poll != null;
    final hasChart = _chartPath != null && cubit.state.attachments.any((a) => a.path == _chartPath);
    final post = await cubit.submit(_controller.text);
    if (post == null || !mounted) return;
    final stock = post.stockCodes.firstOrNull ?? widget.initialStock;
    context.trackCommunityEvent(CommunityAnalyticsEvent.postCreate, {
      'post_id': post.id,
      'has_attachment': post.attachments.isNotEmpty,
      'has_poll': hasPoll,
      'stock_code': stock,
      'source': hasChart ? 'share' : 'feed',
    });
    if (hasChart) {
      context.trackCommunityEvent(CommunityAnalyticsEvent.shareChart, {'post_id': post.id, 'stock_code': stock});
    }
    _chartPath = null;
    _controller.clear();
    showCommunityMessage(context, context.communityL10n.composePosted);
    widget.onPosted?.call(post);
  }

  Future<void> _pickImage() async {
    const group = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
      uniformTypeIdentifiers: ['public.image'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await context.read<ComposeCubit>().addImage(bytes, mimeFromName(file.name, file.mimeType));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    return BlocConsumer<ComposeCubit, ComposeState>(
      listenWhen: (a, b) => a.errorId != b.errorId || a.draftNoticeId != b.draftNoticeId,
      listener: (context, state) {
        if (state.draftNoticeId != _draftNotice) {
          _draftNotice = state.draftNoticeId;
          if (state.draftStatus == DraftSyncStatus.replaced && state.restoredBody != null) {
            _controller.text = state.restoredBody!;
            return showCommunityMessage(context, l10n.draftReplaced);
          }
          return showCommunityMessage(context, l10n.draftLimit(maxPostDrafts));
        }
        final error = state.error;
        if (error == null) return;
        final code = error is CommunityException ? error.code : null;
        showCommunityMessage(context, switch (code) {
          'too_many_images' => l10n.composeTooManyImages,
          'file_too_large' => l10n.composeImageTooLarge,
          'invalid_poll_draft' => l10n.pollInvalidDraft,
          _ => l10n.errorMessage(error),
        });
      },
      builder: (context, state) {
        final cubit = context.read<ComposeCubit>();
        final poll = state.poll;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CommunityComposerField(
                controller: _controller,
                hintText: l10n.composeHint,
                maxLength: maxPostLength,
                minLines: poll == null ? 4 : 2,
                maxLines: 12,
                autofocus: widget.autofocus,
                enabled: !state.submitting,
                onSubmit: _submit,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              if (poll != null) ...[const SizedBox(height: 12), PollEditor(poll: poll, enabled: !state.submitting)],
              const SizedBox(height: 12),
              Text(l10n.sentimentLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<Sentiment?>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: Sentiment.bullish,
                    label: Text(l10n.sentimentBullish),
                    icon: const Icon(Icons.trending_up),
                  ),
                  ButtonSegment(
                    value: Sentiment.bearish,
                    label: Text(l10n.sentimentBearish),
                    icon: const Icon(Icons.trending_down),
                  ),
                  ButtonSegment(
                    value: Sentiment.neutral,
                    label: Text(l10n.sentimentNeutral),
                    icon: const Icon(Icons.trending_flat),
                  ),
                  ButtonSegment(value: null, label: Text(l10n.sentimentNone)),
                ],
                selected: {state.sentiment},
                onSelectionChanged: (s) => cubit.setSentiment(s.first),
              ),
              if (state.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in state.attachments)
                      InputChip(
                        avatar: const Icon(Icons.image_outlined),
                        label: a.held
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(child: Text(a.path.split('/').last, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 6),
                                  const HeldAttachmentLabel(),
                                ],
                              )
                            : Text(a.path.split('/').last, overflow: TextOverflow.ellipsis),
                        deleteButtonTooltipMessage: l10n.composeRemoveImage,
                        onDeleted: state.busy ? null : () => cubit.removeImage(a),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.composeAddImage,
                    onPressed: state.busy || !state.canAddImage ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.pollAddTooltip,
                    onPressed: state.busy || !state.canAddPoll ? null : cubit.addPoll,
                    icon: const Icon(Icons.poll_outlined),
                  ),
                  if (state.uploading)
                    const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: state.busy ? null : _submit,
                    icon: state.submitting
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(l10n.composeSubmit),
                  ),
                ],
              ),
              if (isDesktopPlatform(context))
                Text(
                  l10n.sendShortcutHint,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              if (state.draftStatus != null)
                Text(
                  state.draftStatus == DraftSyncStatus.synced ? l10n.draftSaved : l10n.draftSavedLocally,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              const CommunityDisclaimer(padding: EdgeInsets.only(top: 12)),
            ],
          ),
        );
      },
    );
  }
}
