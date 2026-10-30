enum ReceiptStatus { sent, delivered, read }

class MemberReceipt {
  const MemberReceipt({required this.userId, required this.lastDeliveredAt, required this.lastReadAt});

  final String userId;
  final DateTime lastDeliveredAt;
  final DateTime lastReadAt;

  MemberReceipt merge(MemberReceipt newer) => MemberReceipt(
    userId: userId,
    lastDeliveredAt: _latest(lastDeliveredAt, newer.lastDeliveredAt),
    lastReadAt: _latest(lastReadAt, newer.lastReadAt),
  );

  static DateTime _latest(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  @override
  bool operator ==(Object other) =>
      other is MemberReceipt &&
      other.userId == userId &&
      other.lastDeliveredAt == lastDeliveredAt &&
      other.lastReadAt == lastReadAt;

  @override
  int get hashCode => Object.hash(userId, lastDeliveredAt, lastReadAt);
}

ReceiptStatus receiptStatus(DateTime sentAt, Iterable<MemberReceipt> recipients) {
  final list = recipients.toList();
  if (list.isEmpty) return ReceiptStatus.sent;
  if (list.every((r) => !r.lastReadAt.isBefore(sentAt))) return ReceiptStatus.read;
  if (list.every((r) => !r.lastDeliveredAt.isBefore(sentAt))) return ReceiptStatus.delivered;
  return ReceiptStatus.sent;
}
