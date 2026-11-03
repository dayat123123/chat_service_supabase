import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/drafts/domain/services/community_drafts.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'post_drafts_cubit.freezed.dart';

@freezed
abstract class PostDraftsState with _$PostDraftsState {
  const factory PostDraftsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<PostDraft>[]) List<PostDraft> drafts,
    Object? error,
  }) = _PostDraftsState;
}

class PostDraftsCubit extends Cubit<PostDraftsState> {
  PostDraftsCubit(this._drafts) : super(const PostDraftsState());

  final CommunityDrafts _drafts;

  Future<void> load() async {
    if (state.status != LoadStatus.ready) emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final drafts = await _drafts.list();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, drafts: drafts));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> delete(PostDraft draft) async {
    emit(
      state.copyWith(
        drafts: [
          for (final d in state.drafts)
            if (d.clientDraftId != draft.clientDraftId) d,
        ],
      ),
    );
    await _drafts.delete(draft.clientDraftId);
  }
}
