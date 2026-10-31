import 'dart:async';

import 'package:olt_social/src/core/network/realtime_status.dart';
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
        channel = _client
            .channel('olt-$table-${_seq++}')
            .onPostgresChanges(
              event: event,
              schema: 'public',
              table: table,
              filter: filter,
              callback: (payload) {
                if (!controller.isClosed) controller.add(payload);
              },
            )
            .subscribe((status, _) => onStatus?.call(mapSubscribeStatus(status)));
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

  RealtimeChannel privateChannel(String topic, {String? presenceKey}) => _client.channel(
    topic,
    opts: RealtimeChannelConfig(private: true, key: presenceKey ?? ''),
  );

  Future<void> remove(RealtimeChannel channel) => _client.removeChannel(channel);
}

RealtimeStatus mapSubscribeStatus(RealtimeSubscribeStatus status) => switch (status) {
  RealtimeSubscribeStatus.subscribed => RealtimeStatus.connected,
  RealtimeSubscribeStatus.channelError ||
  RealtimeSubscribeStatus.timedOut ||
  RealtimeSubscribeStatus.closed => RealtimeStatus.reconnecting,
};
