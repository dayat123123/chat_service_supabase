import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/errors/olt_social_exception.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/repositories.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';
import '../widgets/common.dart';
import '../widgets/composer_field.dart';

part 'olt_compose_post.freezed.dart';

const maxPostLength = 2000;
const maxPostImages = 4;
const maxImageBytes = 5 * 1024 * 1024;

@freezed
abstract class ComposeState with _$ComposeState {
  const factory ComposeState({
    Sentiment? sentiment,
    @Default(<Attachment>[]) List<Attachment> attachments,
    @Default(false) bool uploading,
    @Default(false) bool submitting,
    Object? error,
    @Default(0) int errorId,
  }) = _ComposeState;
}

class ComposeCubit extends Cubit<ComposeState> {
  ComposeCubit({required this._feed, required this._media})
    : super(const ComposeState());

  final FeedRepository _feed;
  final MediaRepository _media;

  void setSentiment(Sentiment? sentiment) => emit(state.copyWith(sentiment: sentiment));

  Future<void> addImage(Uint8List bytes, String mimeType) async {
    if (state.attachments.length >= maxPostImages) {
      return _fail(const OltSocialException(OltSocialErrorKind.invalidInput, code: 'too_many_images'));
    }
    if (bytes.length > maxImageBytes) {
      return _fail(const OltSocialException(OltSocialErrorKind.invalidInput, code: 'image_too_large'));
    }
    emit(state.copyWith(uploading: true));
    try {
      final attachment = await _media.uploadPostImage(bytes, mimeType: mimeType);
      if (!isClosed) emit(state.copyWith(uploading: false, attachments: [...state.attachments, attachment]));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(uploading: false));
      _fail(e);
    }
  }

  void removeImage(Attachment attachment) =>
      emit(state.copyWith(attachments: [for (final a in state.attachments) if (a != attachment) a]));

  /// Mengirim post; mengembalikan post baru atau null bila gagal.
  Future<Post?> submit(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.submitting || state.uploading) return null;
    emit(state.copyWith(submitting: true));
    try {
      final post = await _feed.createPost(body: text, sentiment: state.sentiment, attachments: state.attachments);
      if (!isClosed) emit(const ComposeState());
      return post;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(submitting: false));
      _fail(e);
      return null;
    }
  }

  void _fail(Object error) {
    if (!isClosed) emit(state.copyWith(error: error, errorId: state.errorId + 1));
  }
}

/// Menampilkan composer: dialog di layar lebar, halaman penuh di mobile.
/// Mengembalikan post yang berhasil dibuat.
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

/// Form membuat post: teks dengan autocomplete $KODE/@user, sentimen,
/// lampiran gambar, dan disclaimer.
class OltComposePost extends StatelessWidget {
  const OltComposePost({super.key, this.initialStock, this.onPosted, this.autofocus = false});

  /// Kode saham yang langsung ditulis di awal post (mis. dari halaman saham).
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
    return BlocConsumer<ComposeCubit, ComposeState>(
      listenWhen: (a, b) => a.errorId != b.errorId,
      listener: (context, state) {
        final error = state.error;
        final code = error is OltSocialException ? error.code : null;
        showOltMessage(context, switch (code) {
          'too_many_images' => l10n.composeTooManyImages,
          'image_too_large' => l10n.composeImageTooLarge,
          _ => l10n.errorMessage(error!),
        });
      },
      builder: (context, state) {
        final cubit = context.read<ComposeCubit>();
        final busy = state.submitting || state.uploading;
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
                minLines: 4,
                maxLines: 12,
                autofocus: widget.autofocus,
                enabled: !state.submitting,
                onSubmit: _submit,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text(l10n.sentimentLabel, style: Theme.of(context).textTheme.labelLarge),
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
                        onDeleted: busy ? null : () => cubit.removeImage(a),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.composeAddImage,
                    onPressed: busy || state.attachments.length >= maxPostImages ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  if (state.uploading) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: busy ? null : _submit,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              const OltDisclaimer(padding: EdgeInsets.only(top: 12)),
            ],
          ),
        );
      },
    );
  }
}

/// MIME dari nama file (file_selector tidak selalu mengisi mimeType di Windows).
String mimeFromName(String name, [String? reported]) {
  if (reported != null && reported.startsWith('image/')) return reported;
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
