import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

class SupportNotifications {
  SupportNotifications({required this.isSupportVisible, required this.onOpen});

  final bool Function() isSupportVisible;
  final VoidCallback onOpen;
  final _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<SupportNotice>? _subscription;

  Future<void> start(Stream<SupportNotice> notices) async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          windows: WindowsInitializationSettings(
            appName: 'OLT Social Example',
            appUserModelId: 'Rendezvous.Olt.SocialExample',
            guid: '6f1c2a9e-4f4b-4d1d-9a3e-0c8b5f2d7e41',
          ),
          web: WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => onOpen(),
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (_) {
      return;
    }
    _subscription = notices.listen(_show);
  }

  Future<void> _show(SupportNotice notice) async {
    if (isSupportVisible()) return;
    try {
      await _plugin.show(
        id: notice.id.hashCode & 0x7fffffff,
        title: notice.title,
        body: notice.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'cs_chat',
            'Chat CS',
            channelDescription: 'Balasan dan status tiket dari CS OLT',
            importance: Importance.high,
            priority: Priority.high,
          ),
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
