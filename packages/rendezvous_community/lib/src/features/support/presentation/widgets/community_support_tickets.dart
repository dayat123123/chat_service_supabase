import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_builders.dart';
import 'package:rendezvous_community/src/app/community_image_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/app/community_support_scope.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/chat/data/realtime/room_connection.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/community_chat_room.dart';
import 'package:rendezvous_community/src/features/support/domain/entities/support_ticket.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_header.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_topic_picker.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

class CommunitySupportTickets extends StatefulWidget {
  const CommunitySupportTickets({super.key});

  @override
  State<CommunitySupportTickets> createState() => _CommunitySupportTicketsState();
}

class _CommunitySupportTicketsState extends State<CommunitySupportTickets> {
  late Future<List<SupportTicket>> _tickets = CommunitySupportScope.of(context).support.myTickets();

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return FutureBuilder<List<SupportTicket>>(
      future: _tickets,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommunityErrorView(
            error: snapshot.error!,
            onRetry: () => setState(() => _tickets = CommunitySupportScope.of(context).support.myTickets()),
          );
        }
        if (!snapshot.hasData) return const CommunitySkeleton(itemCount: 4);
        final tickets = snapshot.data!;
        if (tickets.isEmpty) return CommunityEmptyView(message: l10n.supportNoTickets, icon: Icons.inbox_outlined);
        return ListView.separated(
          addAutomaticKeepAlives: false,
          itemCount: tickets.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final ticket = tickets[i];
            return ListTile(
              leading: Icon(supportTopicIcon(ticket.topic)),
              title: Text('${ticket.ticketNumber} · ${ticket.topicName ?? ticket.topic}'),
              subtitle: Text(
                [
                  l10n.supportTicketMeta(l10n.dayLabel(ticket.createdAt), supportStatusText(l10n, ticket)),
                  if (ticket.rating != null) l10n.supportRating(ticket.rating!),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTranscript(context, ticket),
            );
          },
        );
      },
    );
  }

  Future<void> _openTranscript(BuildContext context, SupportTicket ticket) {
    final deps = CommunityScope.of(context);
    final support = CommunitySupportScope.of(context).support;
    final carry = carryCommunityBuilders(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => carry(
          CommunityScope(
            dependencies: deps,
            child: Scaffold(
              appBar: AppBar(title: Text('${ticket.ticketNumber} · ${ticket.topicName ?? ticket.topic}')),
              body: CommunityImagePersistence(
                persist: false,
                child: CommunityChatRoom(
                  roomId: ticket.roomId,
                  repository: _TranscriptRepository(support, ticket),
                  showHeader: false,
                  composer: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptRepository implements ChatRepository {
  _TranscriptRepository(this._support, this._ticket);

  final SupportRepository _support;
  final SupportTicket _ticket;

  static const _readOnly = CommunityException(CommunityErrorKind.forbidden, code: 'transcript_read_only');

  ChatRoom get _room =>
      ChatRoom(id: _ticket.roomId, type: RoomType.support, createdAt: _ticket.createdAt, lastReadAt: _ticket.createdAt);

  @override
  Future<Paged<ChatRoom>> getRooms({String? cursor, int limit = 30}) async =>
      cursor == null ? Paged([_room]) : const Paged.empty();

  @override
  Future<ChatRoom?> getRoom(String roomId) async => roomId == _ticket.roomId ? _room : null;

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async {
    if (cursor != null) return const Paged([]);
    final messages = await _support.ticketMessages(_ticket.id);
    return Paged([...messages]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<Paged<ChatMessage>> getMessagesAfter(String roomId, String cursor, {int limit = 100}) async =>
      const Paged.empty();

  @override
  Future<List<RoomMember>> getMembers(String roomId) async => const [];

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) => NoopRoomConnection();

  @override
  Future<void> markRoomRead(String roomId) async {}

  @override
  Future<int> markDelivered({List<String>? roomIds}) async => 0;

  @override
  Future<Map<String, int>> unreadCounts() async => const {};

  @override
  Future<int> unreadChatCount() async => 0;

  @override
  Stream<void> watchUnreadChanges() => const Stream.empty();

  @override
  Stream<RoomActivity> watchRoomActivity() => const Stream.empty();

  @override
  Stream<RoomSignal> watchRoomSignals(Set<String> roomIds, {required UserSummary me}) => const Stream.empty();

  @override
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  }) => Future.error(_readOnly);

  @override
  Future<void> deleteMessage(String messageId) => Future.error(_readOnly);

  @override
  Future<String> getOrCreateDirectRoom(String otherUserId) => Future.error(_readOnly);

  @override
  Future<String> createGroupRoom(String name, List<String> memberIds) => Future.error(_readOnly);

  @override
  Future<String> joinStockRoom(String stockCode) => Future.error(_readOnly);

  @override
  Future<void> leaveRoom(String roomId) => Future.error(_readOnly);

  @override
  Future<void> setMuted(String roomId, {required bool muted}) => Future.error(_readOnly);
}
