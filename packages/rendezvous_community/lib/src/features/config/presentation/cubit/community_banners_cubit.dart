import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/domain/services/banner_dismissals.dart';
import 'package:rendezvous_community/src/features/config/domain/services/client_config_service.dart';

List<CommunityBanner> visibleBanners(
  List<CommunityBanner> banners, {
  required Set<String> dismissed,
  required DateTime now,
  int max = 3,
}) {
  final active = [
    for (final banner in banners)
      if (!(banner.dismissible && dismissed.contains(banner.id)) &&
          (banner.endsAt == null || banner.endsAt!.isAfter(now)) &&
          (banner.startsAt == null || !banner.startsAt!.isAfter(now)))
        banner,
  ];
  active.sort((a, b) {
    final priority = b.priority.compareTo(a.priority);
    if (priority != 0) return priority;
    return (b.startsAt ?? DateTime(0)).compareTo(a.startsAt ?? DateTime(0));
  });
  return active.take(max).toList();
}

class CommunityBannersCubit extends Cubit<List<CommunityBanner>> {
  CommunityBannersCubit(this._config, this._dismissals, {this.maxVisible = 3}) : super(const []) {
    _configSub = _config.changes.listen((_) => _update());
    _dismissSub = _dismissals?.changes.listen((_) => _update());
    _update();
    unawaited(_dismissals?.load().then((_) => _update()));
  }

  final ClientConfigService _config;
  final BannerDismissals? _dismissals;
  final int maxVisible;
  final _local = <String>{};
  late final StreamSubscription<ClientConfig> _configSub;
  StreamSubscription<Set<String>>? _dismissSub;

  Future<void> dismiss(CommunityBanner banner) async {
    if (!banner.dismissible) return;
    _local.add(banner.id);
    _update();
    await _dismissals?.dismiss(banner.id);
  }

  void _update() {
    if (isClosed) return;
    final config = _config.current;
    emit(
      visibleBanners(
        config.banners,
        dismissed: {..._local, ...?_dismissals?.ids},
        now: config.serverNow(),
        max: maxVisible,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _configSub.cancel();
    await _dismissSub?.cancel();
    return super.close();
  }
}
