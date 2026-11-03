import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:rendezvous_community/src/features/edit/domain/repositories/content_edit_repository.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/consent_gate.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';
import 'package:rendezvous_community/src/features/post/domain/repositories/comment_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'comment_thread_cubit.freezed.dart';

const topLevelKey = '';

@freezed
abstract class ThreadState with _$ThreadState {
  const factory ThreadState({
    @Default(LoadStatus.initial) LoadStatus status,
    Post? post,
    ThreadComment? root,
    @Default(<String, ThreadComment>{}) Map<String, ThreadComment> comments,
    @Default(<String, List<String>>{}) Map<String, List<String>> children,
    String? topCursor,
    @Default(false) bool hasMoreTop,
    @Default(<String>{}) Set<String> collapsed,
    @Default(<String>{}) Set<String> loadingBranches,
    ThreadComment? replyTo,
    @Default(false) bool sending,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _ThreadState;

  const ThreadState._();

  String get rootKey => root?.id ?? topLevelKey;

  int get baseDepth => root == null ? 0 : root!.depth + 1;

  int levelOf(ThreadComment c) => c.depth - baseDepth;
}

class CommentThreadCubit extends Cubit<ThreadState> {
  CommentThreadCubit({
    required this._feed,
    required this._comments,
    required this.postId,
    this.rootCommentId,
    this.maxLevels = 4,
    this.pageSize = 20,
    this.repliesPerBranch = 3,
    this._consent,
    this._bookmarks,
    this._edits,
  }) : super(const ThreadState());

  final FeedRepository _feed;
  final CommentRepository _comments;
  final ConsentGate? _consent;
  final BookmarkRepository? _bookmarks;
  final ContentEditRepository? _edits;

  bool get canBookmark => _bookmarks != null;

  bool get canEdit => _edits != null;
  final String postId;
  final String? rootCommentId;

  final int maxLevels;
  final int pageSize;
  final int repliesPerBranch;

  StreamSubscription<String>? _commentEvents;
  StreamSubscription<PostChange>? _postEvents;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final results = await Future.wait([
        _feed.getPost(postId),
        _comments.getThread(
          postId,
          rootCommentId: rootCommentId,
          maxDepth: maxLevels - 1,
          limit: pageSize,
          repliesLimit: repliesPerBranch,
          includeRoot: rootCommentId != null,
        ),
      ]);
      if (isClosed) return;
      final post = results[0] as Post?;
      final list = results[1]! as List<ThreadComment>;
      final root = rootCommentId == null ? null : list.where((c) => c.id == rootCommentId).firstOrNull;
      var next = ThreadState(status: LoadStatus.ready, post: post, root: root);
      next = _merge(next, list);
      final top = _topLevelOf(next, list);
      emit(next.copyWith(topCursor: top.lastOrNull?.cursor, hasMoreTop: top.length >= pageSize));
      _listen();
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> loadMoreTop() async {
    if (!state.hasMoreTop || state.loadingBranches.contains(topLevelKey)) return;
    _setLoading(topLevelKey, true);
    try {
      final list = await _comments.getThread(
        postId,
        rootCommentId: state.root?.id,
        cursor: state.topCursor,
        maxDepth: maxLevels - 1,
        limit: pageSize,
        repliesLimit: repliesPerBranch,
      );
      if (isClosed) return;
      final next = _merge(state, list);
      final top = _topLevelOf(next, list);
      emit(next.copyWith(topCursor: top.lastOrNull?.cursor ?? state.topCursor, hasMoreTop: top.length >= pageSize));
    } catch (e) {
      _fail(e);
    } finally {
      _setLoading(topLevelKey, false);
    }
  }

  Future<void> loadMoreReplies(String parentId) async {
    final parent = state.comments[parentId];
    if (parent == null || state.loadingBranches.contains(parentId)) return;
    final loaded = state.children[parentId] ?? const [];
    final cursor = loaded.isEmpty ? null : state.comments[loaded.last]?.cursor;
    final depthBelow = math.max(0, (maxLevels - 1) - (state.levelOf(parent) + 1));
    _setLoading(parentId, true);
    try {
      final list = await _comments.getThread(
        postId,
        rootCommentId: parentId,
        cursor: cursor,
        maxDepth: depthBelow,
        limit: 10,
        repliesLimit: repliesPerBranch,
      );
      if (!isClosed) emit(_merge(state, list));
    } catch (e) {
      _fail(e);
    } finally {
      _setLoading(parentId, false);
    }
  }

  void toggleCollapse(String commentId) {
    final collapsed = {...state.collapsed};
    if (!collapsed.remove(commentId)) collapsed.add(commentId);
    emit(state.copyWith(collapsed: collapsed));
  }

  void setReplyTo(ThreadComment? comment) => emit(state.copyWith(replyTo: comment));

  Future<bool> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.sending) return false;
    final parentId = state.replyTo?.id ?? state.root?.id;
    emit(state.copyWith(sending: true));
    try {
      final created = await _consent.guard(
        () => _comments.createComment(postId: postId, parentId: parentId, body: text),
      );
      if (isClosed) return true;
      var next = _merge(state, [created]);
      next = _bumpReplyCount(next, parentId, 1);
      final post = next.post;
      final collapsed = {...next.collapsed}..remove(parentId);
      emit(
        next.copyWith(
          sending: false,
          replyTo: null,
          collapsed: collapsed,
          post: post?.copyWith(commentCount: post.commentCount + 1),
        ),
      );
      return true;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(sending: false));
      _fail(e);
      return false;
    }
  }

  Future<void> toggleLike(ThreadComment comment) async {
    final current = state.comments[comment.id] ?? comment;
    final liked = !current.likedByMe;
    _replace(current.copyWith(likedByMe: liked, likeCount: current.likeCount + (liked ? 1 : -1)));
    try {
      liked ? await _comments.likeComment(comment.id) : await _comments.unlikeComment(comment.id);
    } catch (e) {
      _replace(current);
      _fail(e);
    }
  }

  Future<void> deleteComment(ThreadComment comment) async {
    final before = state.comments[comment.id] ?? comment;
    _replace(before.copyWith(isDeleted: true, body: null, author: null));
    final post = state.post;
    if (post != null) emit(state.copyWith(post: post.copyWith(commentCount: math.max(0, post.commentCount - 1))));
    try {
      await _comments.deleteComment(comment.id);
    } catch (e) {
      _replace(before);
      if (post != null && !isClosed) emit(state.copyWith(post: post));
      _fail(e);
    }
  }

  Future<void> togglePostLike() async {
    final post = state.post;
    if (post == null) return;
    final liked = !post.likedByMe;
    emit(
      state.copyWith(
        post: post.copyWith(likedByMe: liked, likeCount: post.likeCount + (liked ? 1 : -1)),
      ),
    );
    try {
      liked ? await _feed.likePost(post.id) : await _feed.unlikePost(post.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(post: post));
      _fail(e);
    }
  }

  Future<void> togglePostBookmark() async {
    final post = state.post;
    final bookmarks = _bookmarks;
    if (post == null || bookmarks == null) return;
    final next = !post.isBookmarked;
    emit(state.copyWith(post: post.copyWith(isBookmarked: next)));
    try {
      final saved = await bookmarks.setBookmarked(post.id, bookmarked: next);
      final current = state.post;
      if (saved != next && current != null && !isClosed) {
        emit(state.copyWith(post: current.copyWith(isBookmarked: saved)));
      }
    } catch (e) {
      final current = state.post;
      if (current != null && !isClosed) emit(state.copyWith(post: current.copyWith(isBookmarked: post.isBookmarked)));
      _fail(e);
    }
  }

  Future<bool> editPost(Post post, String body) async {
    final edits = _edits;
    final text = body.trim();
    if (edits == null || text.isEmpty) return false;
    try {
      final updated = await edits.editPost(post.id, text);
      if (!isClosed) emit(state.copyWith(post: updated));
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> editComment(ThreadComment comment, String body) async {
    final edits = _edits;
    final text = body.trim();
    if (edits == null || text.isEmpty) return false;
    try {
      final updated = await edits.editComment(comment.id, text);
      final known = state.comments[comment.id] ?? comment;
      _replace(
        known.copyWith(
          body: updated.body,
          editedAt: updated.editedAt ?? DateTime.now().toUtc(),
          moderationStatus: updated.moderationStatus,
        ),
      );
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> deletePost() async {
    try {
      await _feed.deletePost(postId);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void _listen() {
    _commentEvents ??= _comments.watchComments(postId).listen(_onCommentEvent, onError: (Object _) {});
    _postEvents ??= _feed.watchPosts(postId: postId).listen((change) {
      final post = state.post;
      if (isClosed || post == null || change is! PostUpdated) return;
      emit(
        state.copyWith(
          post: post.copyWith(likeCount: change.likeCount, commentCount: change.commentCount),
        ),
      );
    }, onError: (Object _) {});
  }

  Future<void> _onCommentEvent(String commentId) async {
    try {
      final rows = await _comments.getThread(
        postId,
        rootCommentId: commentId,
        maxDepth: 0,
        limit: 1,
        repliesLimit: 0,
        includeRoot: true,
      );
      final comment = rows.where((c) => c.id == commentId).firstOrNull;
      if (comment == null || isClosed) return;

      final known = state.comments[commentId];
      if (known != null) {
        _replace(comment.copyWith(likedByMe: known.likedByMe));
        return;
      }

      final parentKey = comment.parentId ?? topLevelKey;
      if (parentKey == topLevelKey || parentKey == state.rootKey) {
        if (state.root != null && parentKey != state.rootKey) return;
        if (!state.hasMoreTop) emit(_merge(state, [comment]));
        return;
      }
      final parent = state.comments[parentKey];
      if (parent == null) return;
      final loadedAll = (state.children[parentKey]?.length ?? 0) >= parent.replyCount;
      final withCount = _bumpReplyCount(state, parentKey, 1);
      emit(loadedAll && state.levelOf(comment) < maxLevels ? _merge(withCount, [comment]) : withCount);
    } catch (_) {}
  }

  ThreadState _merge(ThreadState base, List<ThreadComment> list) {
    final comments = {...base.comments};
    final children = {
      for (final e in base.children.entries) e.key: [...e.value],
    };
    final rootId = base.root?.id;
    for (final c in list) {
      comments[c.id] = c;
      if (c.id == rootId) continue;
      final key = c.parentId ?? topLevelKey;
      final siblings = children.putIfAbsent(key, () => []);
      if (!siblings.contains(c.id)) siblings.add(c.id);
    }
    for (final siblings in children.values) {
      siblings.sort((a, b) => comments[a]!.path.compareTo(comments[b]!.path));
    }
    return base.copyWith(comments: comments, children: children);
  }

  List<ThreadComment> _topLevelOf(ThreadState s, List<ThreadComment> list) => [
    for (final c in list)
      if ((c.parentId ?? topLevelKey) == s.rootKey && c.id != s.root?.id) c,
  ];

  ThreadState _bumpReplyCount(ThreadState s, String? parentId, int delta) {
    if (parentId == null) return s;
    final parent = s.comments[parentId];
    if (parent == null) return s;
    final updated = parent.copyWith(replyCount: math.max(0, parent.replyCount + delta));
    return s.copyWith(comments: {...s.comments, parentId: updated}, root: s.root?.id == parentId ? updated : s.root);
  }

  void _replace(ThreadComment c) {
    if (isClosed) return;
    emit(state.copyWith(comments: {...state.comments, c.id: c}, root: state.root?.id == c.id ? c : state.root));
  }

  void _setLoading(String key, bool loading) {
    if (isClosed) return;
    final set = {...state.loadingBranches};
    loading ? set.add(key) : set.remove(key);
    emit(state.copyWith(loadingBranches: set));
  }

  void _fail(Object error) {
    if (!isClosed) emit(state.copyWith(actionError: error, actionErrorId: state.actionErrorId + 1));
  }

  @override
  Future<void> close() async {
    await _commentEvents?.cancel();
    await _postEvents?.cancel();
    return super.close();
  }
}

sealed class ThreadRow {
  const ThreadRow(this.level);

  final int level;
}

class CommentRow extends ThreadRow {
  const CommentRow(this.comment, super.level, {required this.collapsed});
  final ThreadComment comment;
  final bool collapsed;
}

class MoreRepliesRow extends ThreadRow {
  const MoreRepliesRow(this.parentId, super.level, {required this.remaining, required this.loading});
  final String parentId;
  final int remaining;
  final bool loading;
}

class ContinueThreadRow extends ThreadRow {
  const ContinueThreadRow(this.comment, super.level);
  final ThreadComment comment;
}

class MoreTopLevelRow extends ThreadRow {
  const MoreTopLevelRow({required this.loading}) : super(0);
  final bool loading;
}

List<ThreadRow> buildThreadRows(ThreadState state, {required int maxLevels}) {
  final rows = <ThreadRow>[];

  void visit(String id, int level) {
    final c = state.comments[id];
    if (c == null) return;
    final collapsed = state.collapsed.contains(id);
    rows.add(CommentRow(c, level, collapsed: collapsed));
    if (collapsed) return;

    final kids = state.children[id] ?? const [];
    if (level + 1 >= maxLevels) {
      if (c.replyCount > 0) rows.add(ContinueThreadRow(c, level + 1));
      return;
    }
    for (final k in kids) {
      visit(k, level + 1);
    }
    final remaining = c.replyCount - kids.length;
    if (remaining > 0) {
      rows.add(MoreRepliesRow(id, level + 1, remaining: remaining, loading: state.loadingBranches.contains(id)));
    }
  }

  for (final id in state.children[state.rootKey] ?? const <String>[]) {
    visit(id, 0);
  }
  if (state.hasMoreTop) rows.add(MoreTopLevelRow(loading: state.loadingBranches.contains(topLevelKey)));
  return rows;
}
