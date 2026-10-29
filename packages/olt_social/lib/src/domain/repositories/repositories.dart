import 'dart:typed_data';

import '../entities/chat.dart';
import '../entities/comment.dart';
import '../entities/notification.dart';
import '../entities/paged.dart';
import '../entities/post.dart';
import '../entities/stock.dart';
import '../entities/user.dart';

// Kontrak repository. Semua method melempar OltSocialException bila gagal.

abstract interface class FeedRepository {
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20});

  /// null jika post tidak ada, dihapus, atau tidak terlihat (blokir).
  Future<Post?> getPost(String postId);

  Future<Post> createPost({
    required String body,
    Sentiment? sentiment,
    List<Attachment> attachments = const [],
  });

  Future<void> deletePost(String postId);

  Future<void> likePost(String postId);

  Future<void> unlikePost(String postId);

  /// Post baru & perubahan counter. [postId] membatasi ke satu post.
  Stream<PostChange> watchPosts({String? postId});
}

abstract interface class CommentRepository {
  /// Lihat dokumentasi RPC get_comment_thread di 0007_feed_rpc.sql.
  Future<List<ThreadComment>> getThread(
    String postId, {
    String? rootCommentId,
    int maxDepth = 3,
    String? cursor,
    int limit = 20,
    int repliesLimit = 3,
    bool includeRoot = false,
  });

  Future<ThreadComment> createComment({required String postId, String? parentId, required String body});

  Future<void> deleteComment(String commentId);

  Future<void> likeComment(String commentId);

  Future<void> unlikeComment(String commentId);

  /// id komentar baru/berubah di sebuah post.
  Stream<String> watchComments(String postId);
}

abstract interface class ProfileRepository {
  Future<UserProfile?> getProfile({String? userId, String? username});

  Future<void> updateMyProfile({String? displayName, String? bio, String? avatarUrl});

  /// Unggah avatar ke bucket publik `avatars`; mengembalikan URL publiknya.
  Future<String> uploadAvatar(Uint8List bytes, {required String mimeType});

  Future<void> follow(String userId);

  Future<void> unfollow(String userId);

  Future<void> block(String userId);

  Future<void> unblock(String userId);

  Future<List<UserSummary>> searchUsers(String query, {int limit = 8});
}

abstract interface class StockRepository {
  Future<Stock?> getStock(String code);

  Future<List<Stock>> searchStocks(String query, {int limit = 8});

  Future<bool> isWatching(String code);

  Future<void> watch(String code);

  Future<void> unwatch(String code);
}

abstract interface class ChatRepository {
  Future<List<ChatRoom>> getRooms();

  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30});

  /// Pesan yang lebih baru dari [cursor] (isi celah setelah reconnect).
  Future<List<ChatMessage>> getMessagesAfter(String roomId, String cursor);

  /// Idempoten per [clientId]: kirim ulang tidak menduplikasi pesan.
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  });

  Future<void> deleteMessage(String messageId);

  Future<void> markRoomRead(String roomId);

  /// roomId -> jumlah pesan belum dibaca (maks 100).
  Future<Map<String, int>> unreadCounts();

  Future<String> getOrCreateDirectRoom(String otherUserId);

  Future<String> createGroupRoom(String name, List<String> memberIds);

  Future<String> joinStockRoom(String stockCode);

  Future<void> leaveRoom(String roomId);

  Future<void> setMuted(String roomId, {required bool muted});

  Future<List<RoomMember>> getMembers(String roomId);

  /// Koneksi realtime satu room: pesan, mengetik, read receipt, status koneksi.
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me});

  /// Aktivitas pesan di semua room milik user (untuk daftar chat & badge).
  Stream<RoomActivity> watchRoomActivity();

  /// Id user yang sedang online (presence).
  Stream<Set<String>> watchOnlineUsers({required UserSummary me});
}

abstract interface class ChatRoomConnection {
  Stream<ChatRoomEvent> get events;

  Future<void> sendTyping({required bool isTyping});

  Future<void> sendReadReceipt(DateTime lastReadAt);

  Future<void> close();
}

abstract interface class NotificationRepository {
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30});

  Future<int> unreadCount();

  /// [ids] null = semua.
  Future<void> markRead({List<String>? ids});

  /// Memancar setiap ada notifikasi baru/berubah untuk user ini.
  Stream<void> watchNotifications();
}

abstract interface class ModerationRepository {
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  });
}

/// Akses gambar di bucket privat `attachments`.
class AuthorizedImage {
  const AuthorizedImage(this.url, this.headers);
  final String url;
  final Map<String, String> headers;
}

abstract interface class MediaRepository {
  /// Unggah gambar post ke `attachments/posts/<user_id>/...`.
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType});

  /// Unggah gambar chat ke `attachments/rooms/<room_id>/<user_id>/...`.
  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType});

  /// URL + header otorisasi untuk menampilkan lampiran.
  Future<AuthorizedImage> attachmentImage(Attachment attachment);
}
