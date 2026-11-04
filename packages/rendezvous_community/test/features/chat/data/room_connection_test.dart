import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:rendezvous_community/src/features/chat/data/realtime/room_connection.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockChannel extends Mock implements RealtimeChannel {}

class _Gateway extends RealtimeGateway {
  _Gateway(this.channel) : super(_MockClient());

  final _MockChannel channel;
  final topics = <String>[];

  @override
  RealtimeChannel privateChannel(String topic, {String? presenceKey}) {
    topics.add(topic);
    return channel;
  }

  @override
  Future<void> remove(RealtimeChannel channel) async {}
}

const _me = UserSummary(id: 'u-me', username: 'saya');

Map<String, dynamic> _row(String id, {String roomId = 'r', String createdAt = '2026-11-03T09:00:00.123456+00:00'}) => {
  'id': id,
  'room_id': roomId,
  'sender_id': 'u-ani',
  'sender_username': 'ani',
  'body': 'Halo $id',
  'is_deleted': false,
  'attachments': <Object?>[],
  'client_id': 'c-$id',
  'created_at': createdAt,
  'cursor': '2026-11-03T09:00:00.123456Z|$id',
  'kind': 'text',
};

Map<String, dynamic> _broadcast(String event, Map<String, dynamic> payload) => {
  'type': 'broadcast',
  'event': event,
  'payload': payload,
};

void main() {
  late _MockChannel channel;
  late _Gateway gateway;
  late Map<String, void Function(Map<String, dynamic>)> handlers;
  late void Function(RealtimeSubscribeStatus, Object?) onStatus;
  late List<({String roomId, bool isTyping})> typed;
  late List<String> fetched;
  late List<ChatMessage> server;

  setUp(() {
    channel = _MockChannel();
    gateway = _Gateway(channel);
    handlers = {};
    typed = [];
    fetched = [];
    server = [];
    when(
      () => channel.onBroadcast(
        event: any(named: 'event'),
        callback: any(named: 'callback'),
      ),
    ).thenAnswer((call) {
      handlers[call.namedArguments[#event] as String] =
          call.namedArguments[#callback] as void Function(Map<String, dynamic>);
      return channel;
    });
    when(() => channel.onPresenceSync(any())).thenReturn(channel);
    when(() => channel.subscribe(any())).thenAnswer((call) {
      onStatus = call.positionalArguments.first as void Function(RealtimeSubscribeStatus, Object?);
      return channel;
    });
    when(() => channel.track(any())).thenAnswer((_) async => ChannelResponse.ok);
    when(() => channel.presenceState()).thenReturn(const []);
  });

  SupabaseRoomConnection connect() {
    final hub = RoomChannelHub(
      gateway,
      typing: (roomId, {required isTyping}) async => typed.add((roomId: roomId, isTyping: isTyping)),
    );
    final connection = SupabaseRoomConnection(
      hub,
      'r',
      _me,
      fetchAfter: (cursor) async {
        fetched.add(cursor);
        return Paged(server);
      },
      referenceDelay: Duration.zero,
    );
    addTearDown(connection.close);
    return connection;
  }

  Future<List<ChatRoomEvent>> collect(SupabaseRoomConnection connection, void Function() act) async {
    final events = <ChatRoomEvent>[];
    final sub = connection.events.listen(events.add);
    await pumpEventQueue();
    act();
    await pumpEventQueue();
    await sub.cancel();
    return events;
  }

  test('the room joins one private topic and new messages arrive as server broadcasts', () async {
    final connection = connect();
    final events = await collect(connection, () => handlers['message']!(_broadcast('message', _row('m-1'))));

    expect(gateway.topics, ['room:r']);
    final upserted = events.whereType<MessageUpserted>().single.message;
    expect(upserted.id, 'm-1');
    expect(upserted.body, 'Halo m-1');
    expect(upserted.sender?.username, 'ani');
    expect(upserted.clientId, 'c-m-1');
  });

  test('payloads for another room or without the required fields are ignored', () async {
    final connection = connect();
    final events = await collect(connection, () {
      handlers['message']!(_broadcast('message', _row('m-x', roomId: 'other')));
      handlers['message']!(_broadcast('message', {'room_id': 'r'}));
      handlers['message']!(_broadcast('message', {..._row('m-y'), 'created_at': 'bukan tanggal'}));
      handlers['message_hidden']!(_broadcast('message_hidden', {'room_id': 'other', 'message_id': 'm-1'}));
      handlers['room_state']!(_broadcast('room_state', {'room_id': 'other'}));
      handlers['typing']!(_broadcast('typing', {'room_id': 'other', 'user_id': 'u-ani', 'typing': true}));
    });

    expect(events, isEmpty);
  });

  test('typing goes through the server RPC and the client never broadcasts', () async {
    final connection = connect();
    await collect(connection, () {});
    await connection.sendTyping(isTyping: true);
    await connection.sendTyping(isTyping: false);

    expect(typed, [(roomId: 'r', isTyping: true), (roomId: 'r', isTyping: false)]);
    verifyNever(
      () => channel.sendBroadcastMessage(
        event: any(named: 'event'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('typing about myself is ignored while typing from others is shown with the server identity', () async {
    final connection = connect();
    final events = await collect(connection, () {
      handlers['typing']!(_broadcast('typing', {'user_id': 'u-me', 'username': 'saya', 'typing': true}));
      handlers['typing']!(_broadcast('typing', {'user_id': 'u-ani', 'username': 'ani', 'typing': true}));
    });

    final typing = events.whereType<TypingChanged>().single;
    expect(typing.user.id, 'u-ani');
    expect(typing.isTyping, isTrue);
  });

  test('a message reference is fetched after its cursor and only the referenced message is shown', () async {
    server = [
      ChatMessageModel.fromJson(_row('m-other')).toEntity(),
      ChatMessageModel.fromJson(_row('m-ref')).toEntity(),
    ];
    final connection = connect();
    final events = <ChatRoomEvent>[];
    final sub = connection.events.listen(events.add);
    await pumpEventQueue();
    handlers['message']!(
      _broadcast('message', {
        'id': 'm-ref',
        'room_id': 'r',
        'created_at': '2026-11-03T09:00:00.123456+00:00',
        'ref': true,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(fetched, ['2026-11-03T09:00:00.123456Z|00000000-0000-0000-0000-000000000000']);
    expect(events.whereType<MessageUpserted>().map((e) => e.message.id), ['m-ref']);
  });

  test('one channel status drives both the message and the signal connection state', () async {
    final connection = connect();
    final events = await collect(connection, () => onStatus(RealtimeSubscribeStatus.subscribed, null));

    expect(events.whereType<ConnectionChanged>().single.status, RealtimeStatus.connected);
    expect(events.whereType<SignalsConnectionChanged>().single.status, RealtimeStatus.connected);
  });

  test('room activity from the user topic is parsed and malformed activity is dropped', () {
    final activity = parseRoomActivity({
      'room_id': 'r',
      'sender_id': 'u-ani',
      'preview': 'Halo',
      'created_at': '2026-11-03T09:00:00+00:00',
    });
    expect(activity?.roomId, 'r');
    expect(activity?.senderId, 'u-ani');
    expect(activity?.preview, 'Halo');
    expect(parseRoomActivity({'sender_id': 'u-ani'}), isNull);
  });
}
