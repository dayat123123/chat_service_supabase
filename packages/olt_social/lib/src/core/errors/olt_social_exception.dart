/// Jenis error yang perlu dibedakan UI.
enum OltSocialErrorKind {
  /// Tidak ada koneksi / timeout.
  network,

  /// Sesi OLT tidak ada atau tidak valid (user perlu login ulang di OLT).
  unauthenticated,

  /// Terlalu banyak aksi dalam waktu singkat (rate limit server).
  rateLimited,

  /// Konten ditolak filter kata.
  contentBlocked,

  /// Input tidak valid (terlalu panjang, kosong, format salah).
  invalidInput,

  /// Tidak diizinkan (diblokir, bukan pemilik, bukan anggota room).
  forbidden,

  /// Data tidak ditemukan / sudah dihapus.
  notFound,

  /// Server sosial atau server OLT sedang tidak tersedia.
  unavailable,

  /// Error lain.
  unknown,
}

/// Error tunggal yang dilempar seluruh API publik olt_social.
class OltSocialException implements Exception {
  const OltSocialException(this.kind, {this.code, this.message, this.cause});

  const OltSocialException.unauthenticated([String? message])
    : this(OltSocialErrorKind.unauthenticated, message: message);

  final OltSocialErrorKind kind;

  /// Kode stabil dari server, mis. `rate_limited`, `content_blocked`, `blocked`.
  final String? code;

  /// Pesan teknis / detail dari server (bukan untuk ditampilkan apa adanya).
  final String? message;

  /// Error asli, untuk logging.
  final Object? cause;

  @override
  String toString() =>
      'OltSocialException(${kind.name}${code == null ? '' : ', $code'}'
      '${message == null ? '' : ', $message'})';
}
