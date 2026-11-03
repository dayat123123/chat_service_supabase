abstract interface class BannerDismissalRepository {
  Future<Set<String>> load();

  Future<void> save(Set<String> ids);
}
