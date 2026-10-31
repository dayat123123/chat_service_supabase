import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/support/domain/entities/support_ticket.dart';

abstract interface class SupportRepository {
  Future<SupportHome> home();

  Future<List<SupportTopic>> topics({String language = 'id'});

  Future<SupportTicket> openTicket({
    required String topic,
    String language = 'id',
    String? screen,
    bool complaint = false,
  });

  Future<List<SupportTicket>> myTickets();

  Future<List<ChatMessage>> ticketMessages(String ticketId);

  Future<SupportTicket> closeTicket(String ticketId);

  Future<SupportTicket> rateTicket(String ticketId, int rating, {String? comment});

  Future<SupportTicket> requestComplaint();

  Future<SupportTicket> reportFakeCs(String description);

  Future<SensitiveCheck> checkSensitive(String text);

  Stream<void> watchTicket(String roomId);

  Stream<SupportNotice> notices();
}
