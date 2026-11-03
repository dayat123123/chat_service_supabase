import 'package:rendezvous_community/src/core/storage/local_values.dart';
import 'package:rendezvous_community/src/features/config/domain/repositories/banner_dismissal_repository.dart';

class BannerDismissalRepositoryImpl implements BannerDismissalRepository {
  BannerDismissalRepositoryImpl(this._values, {this.maxIds = 100});

  static const _key = 'dismissed_banners';

  final LocalValues _values;
  final int maxIds;

  @override
  Future<Set<String>> load() async {
    final ids = (await _values.read(_key))?['ids'];
    return {
      if (ids is List)
        for (final id in ids)
          if (id is String) id,
    };
  }

  @override
  Future<void> save(Set<String> ids) {
    final list = ids.toList();
    return _values.write(_key, {'ids': list.length > maxIds ? list.sublist(list.length - maxIds) : list});
  }
}
