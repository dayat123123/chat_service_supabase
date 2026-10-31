import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';
import 'package:rendezvous_community/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'profile_cubit.freezed.dart';

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(LoadStatus.initial) LoadStatus status,
    UserProfile? profile,
    @Default(false) bool busy,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _ProfileState;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this._profiles, required this._chat, this.userId, this.username})
    : super(const ProfileState());

  final ProfileRepository _profiles;
  final ChatRepository _chat;
  final String? userId;
  final String? username;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final profile = await _profiles.getProfile(userId: userId, username: userId == null ? username : null);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, profile: profile));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> toggleFollow() async {
    final before = state.profile;
    if (before == null) return;
    final follow = !before.isFollowing;
    emit(
      state.copyWith(
        profile: before.copyWith(isFollowing: follow, followerCount: before.followerCount + (follow ? 1 : -1)),
      ),
    );
    try {
      follow ? await _profiles.follow(before.user.id) : await _profiles.unfollow(before.user.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(profile: before));
      _fail(e);
    }
  }

  Future<void> unblock() async {
    final p = state.profile;
    if (p == null) return;
    try {
      await _profiles.unblock(p.user.id);
      await load();
    } catch (e) {
      _fail(e);
    }
  }

  Future<String?> openDirectRoom() async {
    final p = state.profile;
    if (p == null) return null;
    try {
      return await _chat.getOrCreateDirectRoom(p.user.id);
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> saveProfile({required String displayName, required String bio}) async {
    emit(state.copyWith(busy: true));
    try {
      await _profiles.updateMyProfile(displayName: displayName, bio: bio);
      await load();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  Future<void> changeAvatar(List<int> bytes, String mimeType) async {
    emit(state.copyWith(busy: true));
    try {
      await _profiles.uploadAvatar(Uint8List.fromList(bytes), mimeType: mimeType);
      await load();
    } catch (e) {
      _fail(e);
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  void _fail(Object e) {
    if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
  }
}
