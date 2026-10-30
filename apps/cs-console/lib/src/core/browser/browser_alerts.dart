import 'dart:js_interop';

import 'package:web/web.dart' as web;

enum AlertSound { ticket, message }

class BrowserAlerts {
  BrowserAlerts({this.assetBase = 'assets/assets/sounds'});

  final String assetBase;
  final _players = <AlertSound, web.HTMLAudioElement>{};

  bool get pageInBackground => web.document.hidden || !web.document.hasFocus();

  String get permission => web.Notification.permission;

  Future<String> requestPermission() async => (await web.Notification.requestPermission().toDart).toDart;

  void play(AlertSound sound) {
    final player = _players.putIfAbsent(sound, () => web.HTMLAudioElement()..src = '$assetBase/${sound.name}.wav');
    player.currentTime = 0;
    player.play().toDart.ignore();
  }

  void notify({required String title, required String body, String? tag, void Function()? onClick}) {
    if (permission != 'granted') return;
    final notification = web.Notification(title, web.NotificationOptions(body: body, tag: tag ?? ''));
    notification.onclick = ((web.Event _) {
      web.window.focus();
      notification.close();
      onClick?.call();
    }).toJS;
  }
}
