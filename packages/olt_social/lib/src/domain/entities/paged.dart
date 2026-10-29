/// Satu halaman data dengan cursor keyset untuk halaman berikutnya.
class Paged<T> {
  const Paged(this.items, {this.nextCursor});

  const Paged.empty() : items = const [], nextCursor = null;

  final List<T> items;

  /// null jika tidak ada halaman berikutnya.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Alasan laporan (harus sama dengan constraint reports_reason di DB).
enum ReportReason {
  spam('spam'),
  abuse('abuse'),
  scam('scam'),
  pumpAndDump('pump_and_dump'),
  misinformation('misinformation'),
  other('other');

  const ReportReason(this.wireName);
  final String wireName;
}

enum ReportTarget { post, comment, message, user }
