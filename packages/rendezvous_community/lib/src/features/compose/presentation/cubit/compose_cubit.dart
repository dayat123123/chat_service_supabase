import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/consent_gate.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:uuid/uuid.dart';

part 'compose_cubit.freezed.dart';

const maxPostLength = 2000;
const maxPostImages = 4;
const maxImageBytes = 5 * 1024 * 1024;

const _uuid = Uuid();

@freezed
abstract class ComposeState with _$ComposeState {
  const factory ComposeState({
    Sentiment? sentiment,
    @Default(<Attachment>[]) List<Attachment> attachments,
    PollDraft? poll,
    @Default(false) bool uploading,
    @Default(false) bool submitting,
    Object? error,
    @Default(0) int errorId,
  }) = _ComposeState;

  const ComposeState._();

  bool get busy => submitting || uploading;

  bool get canAddImage => poll == null && attachments.length < maxPostImages;

  bool get canAddPoll => poll == null && attachments.isEmpty;
}

class ComposeCubit extends Cubit<ComposeState> {
  ComposeCubit({required this._feed, required this._media, this._consent}) : super(const ComposeState());

  final FeedRepository _feed;
  final MediaRepository _media;
  final ConsentGate? _consent;
  String _clientId = _uuid.v4();

  void setSentiment(Sentiment? sentiment) => emit(state.copyWith(sentiment: sentiment));

  Future<void> addImage(Uint8List bytes, String mimeType) async {
    if (!state.canAddImage) {
      return _fail(const CommunityException(CommunityErrorKind.invalidInput, code: 'too_many_images'));
    }
    if (bytes.length > maxImageBytes) {
      return _fail(const CommunityException(CommunityErrorKind.invalidInput, code: 'file_too_large'));
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

  void removeImage(Attachment attachment) => emit(
    state.copyWith(
      attachments: [
        for (final a in state.attachments)
          if (a != attachment) a,
      ],
    ),
  );

  void addPoll() {
    if (state.canAddPoll) emit(state.copyWith(poll: const PollDraft()));
  }

  void removePoll() => emit(state.copyWith(poll: null));

  void setPollOption(int index, String value) {
    final poll = state.poll;
    if (poll == null || index >= poll.options.length) return;
    emit(state.copyWith(poll: poll.copyWith(options: [...poll.options]..[index] = value)));
  }

  void addPollOption() {
    final poll = state.poll;
    if (poll == null || poll.options.length >= PollDraft.maxOptions) return;
    emit(state.copyWith(poll: poll.copyWith(options: [...poll.options, ''])));
  }

  void removePollOption(int index) {
    final poll = state.poll;
    if (poll == null || poll.options.length <= PollDraft.minOptions) return;
    emit(state.copyWith(poll: poll.copyWith(options: [...poll.options]..removeAt(index))));
  }

  void setPollDuration(PollDuration duration) {
    final poll = state.poll;
    if (poll != null) emit(state.copyWith(poll: poll.copyWith(duration: duration)));
  }

  Future<Post?> submit(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.busy) return null;
    final poll = state.poll;
    if (poll != null && !poll.isValid) {
      _fail(const CommunityException(CommunityErrorKind.invalidInput, code: 'invalid_poll_draft'));
      return null;
    }
    emit(state.copyWith(submitting: true));
    try {
      final post = await _consent.guard(
        () => _feed.createPost(
          body: text,
          sentiment: state.sentiment,
          attachments: state.attachments,
          poll: poll,
          clientId: _clientId,
        ),
      );
      _clientId = _uuid.v4();
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
