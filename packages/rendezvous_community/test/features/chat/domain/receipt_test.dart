import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';

void main() {
  final sentAt = DateTime.utc(2026, 10, 29, 10);

  MemberReceipt member(String id, {required int deliveredMinutes, required int readMinutes}) => MemberReceipt(
    userId: id,
    lastDeliveredAt: sentAt.add(Duration(minutes: deliveredMinutes)),
    lastReadAt: sentAt.add(Duration(minutes: readMinutes)),
  );

  test('not received by any device: one tick', () {
    expect(receiptStatus(sentAt, [member('a', deliveredMinutes: -1, readMinutes: -1)]), ReceiptStatus.sent);
  });

  test('received but unread: two grey ticks', () {
    expect(receiptStatus(sentAt, [member('a', deliveredMinutes: 1, readMinutes: -1)]), ReceiptStatus.delivered);
  });

  test('read: two blue ticks', () {
    expect(receiptStatus(sentAt, [member('a', deliveredMinutes: 1, readMinutes: 0)]), ReceiptStatus.read);
  });

  test('group: status follows the member who is furthest behind', () {
    final group = [member('a', deliveredMinutes: 1, readMinutes: 1), member('b', deliveredMinutes: 1, readMinutes: -1)];
    expect(receiptStatus(sentAt, group), ReceiptStatus.delivered);
    expect(receiptStatus(sentAt, [...group, member('c', deliveredMinutes: -1, readMinutes: -1)]), ReceiptStatus.sent);
  });

  test('stays at one tick without recipients', () {
    expect(receiptStatus(sentAt, const []), ReceiptStatus.sent);
  });

  test('merge never moves a marker backwards', () {
    final current = member('a', deliveredMinutes: 5, readMinutes: 2);
    final merged = current.merge(member('a', deliveredMinutes: 1, readMinutes: 4));
    expect(merged.lastDeliveredAt, sentAt.add(const Duration(minutes: 5)));
    expect(merged.lastReadAt, sentAt.add(const Duration(minutes: 4)));
  });
}
