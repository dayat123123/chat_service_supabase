import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeGateway {
  RealtimeGateway(this._client);

  final SupabaseClient _client;
  int _seq = 0;

  Stream<PostgresChangePayload> tableChanges({
    required String table,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    PostgresChangeFilter? filter,
    void Function(RealtimeStatus status)? onStatus,
  }) {
    RealtimeChannel? channel;
    late final StreamController<PostgresChangePayload> controller;
    controller = StreamController<PostgresChangePayload>(
      onListen: () {
        onStatus?.call(RealtimeStatus.connecting);
        final topic = 'olt-$table-${_seq++}';
        channel = _client
            .channel(topic)
            .onPostgresChanges(
              event: event,
              schema: 'public',
              table: table,
              filter: filter,
              callback: (payload) {
                if (!controller.isClosed) controller.add(payload);
              },
            )
            .subscribe((status, error) {
              _logChannelStatus(topic, status, error);
              onStatus?.call(mapSubscribeStatus(status));
            });
      },
      onCancel: () async {
        final ch = channel;
        channel = null;
        if (ch != null) await _client.removeChannel(ch);
        await controller.close();
      },
    );
    return controller.stream;
  }

  RealtimeChannel privateChannel(String topic, {String? presenceKey}) =>
      _client.channel(topic, opts: RealtimeChannelConfig(private: true, key: presenceKey ?? ''));

  Future<void> remove(RealtimeChannel channel) => _client.removeChannel(channel);
}

void _logChannelStatus(String channel, RealtimeSubscribeStatus status, Object? error) {
  final (level, message) = switch (status) {
    RealtimeSubscribeStatus.subscribed => (Level.FINE, 'Realtime channel subscribed'),
    RealtimeSubscribeStatus.closed => (Level.FINE, 'Realtime channel closed'),
    RealtimeSubscribeStatus.channelError ||
    RealtimeSubscribeStatus.timedOut => (Level.WARNING, 'Realtime channel interrupted, retrying'),
  };
  CommunityLoggers.realtime.event(level, message, fields: {'channel': channel, 'status': status}, error: error);
}

RealtimeStatus mapSubscribeStatus(RealtimeSubscribeStatus status) => switch (status) {
  RealtimeSubscribeStatus.subscribed => RealtimeStatus.connected,
  RealtimeSubscribeStatus.channelError ||
  RealtimeSubscribeStatus.timedOut ||
  RealtimeSubscribeStatus.closed => RealtimeStatus.reconnecting,
};
