class Paged<T> {
  const Paged(this.items, {this.nextCursor});

  const Paged.empty() : items = const [], nextCursor = null;

  final List<T> items;

  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
