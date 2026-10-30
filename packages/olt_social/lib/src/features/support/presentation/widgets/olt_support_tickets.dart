import 'package:flutter/material.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/app/olt_support_scope.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/core/paging/paged.dart';
import 'package:olt_social/src/features/chat/data/realtime/room_connection.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/olt_chat_room.dart';
import 'package:olt_social/src/features/support/domain/entities/support_ticket.dart';
import 'package:olt_social/src/features/support/domain/repositories/support_repository.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_header.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_topic_picker.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltSupportTickets extends StatefulWidget {
  const OltSupportTickets({super.key});

  @override
  State<OltSupportTickets> createState() => _OltSupportTicketsState();
}

class _OltSupportTicketsState extends State<OltSupportTickets> {
  late Future<List<SupportTicket>> _tickets = OltSupportScope.of(context).support.myTickets();

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return FutureBuilder<List<SupportTicket>>(
      future: _tickets,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OltErrorView(
            error: snapshot.error!,
            onRetry: () => setState(() => _tickets = OltSupportScope.of(context).support.myTickets()),
          );
        }
        if (!snapshot.hasData) return const OltSkeleton(itemCount: 4);
        final tickets = snapshot.data!;
        if (tickets.isEmpty) return OltEmptyView(message: l10n.supportNoTickets, icon: Icons.inbox_outlined);
        return ListView.separated(
          itemCount: tickets.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final ticket = tickets[i];
            return ListTile(
              leading: Icon(supportTopicIcon(ticket.topic)),
              title: Text('${ticket.ticketNumber} · ${ticket.topicName ?? ticket.topic}'),
              subtitle: Text([
                l10n.supportTicketMeta(l10n.dayLabel(ticket.createdAt), supportStatusText(l10n, ticket)),
                if (ticket.rating != null) l10n.supportRating(ticket.rating!),
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTranscript(context, ticket),
            );
          },
        );
      },
    );
  }

  Future<void> _openTranscript(BuildContext context, SupportTicket ticket) {
    final deps = OltSocialScope.of(context);
    final support = OltSupportScope.of(context).support;
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OltSocialScope(
        dependencies: deps,
        child: Scaffold(
          appBar: AppBar(title: Text('${ticket.ticketNumber} · ${ticket.topicName ?? ticket.topic}')),
          body: OltChatRoom(
            roomId: ticket.roomId,
            repository: _TranscriptRepository(support, ticket),
            showHeader: false,
            composer: const SizedBox.shrink(),
          ),
        ),
      ),
    ));
  }
}

class _TranscriptRepository implements ChatRepository {
  _TranscriptRepository(this._support, this._ticket);

  final SupportRepository _support;
  final SupportTicket _ticket;

  static const _readOnly = OltSocialException(OltSocialErrorKind.forbidden, code: 'transcript_read_only');

  @override
  Future<List<ChatRoom>> getRooms() async => [
    ChatRoom(id: _ticket.roomId, type: RoomType.support, createdAt: _ticket.createdAt, lastReadAt: _ticket.createdAt),
  ];

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async {
    if (cursor != null) return const Paged([]);
    final messages = await _support.ticketMessages(_ticket.id);
    return Paged([...messages]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<List<ChatMessage>> getMessagesAfter(String roomId, String cursor) async => const [];

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
