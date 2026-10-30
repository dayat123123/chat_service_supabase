import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/core/media/image_mime.dart';
import 'package:olt_social/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:olt_social/src/features/compose/presentation/widgets/poll_editor.dart';
import 'package:olt_social/src/features/feed/domain/entities/post.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_composer_field.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_disclaimer.dart';

Future<Post?> showOltComposer(BuildContext context, {String? initialStock}) {
  final deps = OltSocialScope.of(context);
  final l10n = context.oltL10n;
  if (OltBreakpoints.isWide(context)) {
    return showDialog<Post>(
      context: context,
      builder: (dialogContext) => OltSocialScope(
        dependencies: deps,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: OltComposePost(
              initialStock: initialStock,
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
      builder: (pageContext) => OltSocialScope(
        dependencies: deps,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.composeTitle)),
          body: SafeArea(
            child: OltComposePost(
              initialStock: initialStock,
              autofocus: true,
              onPosted: (post) => Navigator.pop(pageContext, post),
            ),
          ),
        ),
      ),
    ),
  );
}

class OltComposePost extends StatelessWidget {
  const OltComposePost({super.key, this.initialStock, this.onPosted, this.autofocus = false});

  final String? initialStock;
  final ValueChanged<Post>? onPosted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ComposeCubit(feed: deps.feed, media: deps.media),
      child: _ComposeView(initialStock: initialStock, onPosted: onPosted, autofocus: autofocus),
    );
  }
}

class _ComposeView extends StatefulWidget {
  const _ComposeView({this.initialStock, this.onPosted, required this.autofocus});

  final String? initialStock;
  final ValueChanged<Post>? onPosted;
  final bool autofocus;

  @override
  State<_ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<_ComposeView> {
  late final _controller = TextEditingController(
    text: widget.initialStock == null ? '' : '\$${widget.initialStock!.toUpperCase()} ',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final post = await context.read<ComposeCubit>().submit(_controller.text);
    if (post == null || !mounted) return;
    _controller.clear();
    showOltMessage(context, context.oltL10n.composePosted);
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
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocConsumer<ComposeCubit, ComposeState>(
      listenWhen: (a, b) => a.errorId != b.errorId,
      listener: (context, state) {
        final error = state.error;
        final code = error is OltSocialException ? error.code : null;
        showOltMessage(context, switch (code) {
          'too_many_images' => l10n.composeTooManyImages,
          'image_too_large' => l10n.composeImageTooLarge,
          'invalid_poll_draft' => l10n.pollInvalidDraft,
          _ => l10n.errorMessage(error!),
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
              OltComposerField(
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
              if (poll != null) ...[
                const SizedBox(height: 12),
                PollEditor(poll: poll, enabled: !state.submitting),
              ],
              const SizedBox(height: 12),
              Text(l10n.sentimentLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<Sentiment?>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: Sentiment.bullish, label: Text(l10n.sentimentBullish), icon: const Icon(Icons.trending_up)),
                  ButtonSegment(value: Sentiment.bearish, label: Text(l10n.sentimentBearish), icon: const Icon(Icons.trending_down)),
                  ButtonSegment(value: Sentiment.neutral, label: Text(l10n.sentimentNeutral), icon: const Icon(Icons.trending_flat)),
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
                        label: Text(a.path.split('/').last, overflow: TextOverflow.ellipsis),
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
                  if (state.uploading) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
              const OltDisclaimer(padding: EdgeInsets.only(top: 12)),
            ],
          ),
        );
      },
    );
  }
}
