// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'community_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class CommunityLocalizationsId extends CommunityLocalizations {
  CommunityLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get disclaimer => 'Konten ini opini pengguna, bukan rekomendasi investasi.';

  @override
  String get retry => 'Coba lagi';

  @override
  String get cancel => 'Batal';

  @override
  String get delete => 'Hapus';

  @override
  String get save => 'Simpan';

  @override
  String get close => 'Tutup';

  @override
  String get you => 'Anda';

  @override
  String get edited => '(diedit)';

  @override
  String get justNow => 'baru saja';

  @override
  String minutesAgo(int count) {
    return '$count mnt';
  }

  @override
  String hoursAgo(int count) {
    return '$count j';
  }

  @override
  String daysAgo(int count) {
    return '$count h';
  }

  @override
  String get errorNetwork => 'Tidak ada koneksi. Periksa jaringan Anda.';

  @override
  String get errorUnauthenticated => 'Sesi berakhir. Silakan login ulang di OLT.';

  @override
  String get errorRateLimited => 'Terlalu cepat. Coba lagi sebentar lagi.';

  @override
  String get errorContentBlocked => 'Konten mengandung kata atau frasa yang tidak diizinkan.';

  @override
  String get errorInvalidInput => 'Data tidak valid.';

  @override
  String get errorForbidden => 'Anda tidak memiliki akses untuk aksi ini.';

  @override
  String get errorNotFound => 'Konten tidak ditemukan atau sudah dihapus.';

  @override
  String get errorUnavailable => 'Layanan sedang tidak tersedia. Coba lagi nanti.';

  @override
  String get errorUnknown => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get feedLatest => 'Terbaru';

  @override
  String get feedFollowing => 'Mengikuti';

  @override
  String get feedEmpty => 'Belum ada post. Jadilah yang pertama!';

  @override
  String get feedFollowingEmpty => 'Belum ada post dari user yang Anda ikuti.';

  @override
  String stockFeedEmpty(String code) {
    return 'Belum ada diskusi tentang \$$code.';
  }

  @override
  String get userFeedEmpty => 'Belum ada post.';

  @override
  String newPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count post baru', one: '1 post baru');
    return '$_temp0';
  }

  @override
  String get composePrompt => 'Apa pendapat Anda tentang pasar hari ini?';

  @override
  String get composeTitle => 'Buat post';

  @override
  String get composeHint =>
      'Tulis analisis Anda. Gunakan \$KODE untuk menandai saham dan @username untuk menyebut user.';

  @override
  String get composeSubmit => 'Kirim';

  @override
  String composeCharsLeft(int count) {
    return '$count karakter tersisa';
  }

  @override
  String get composeAddImage => 'Tambah gambar';

  @override
  String get composeAddImageOrPdf => 'Lampirkan gambar atau PDF';

  @override
  String get documentTooLarge => 'PDF maksimal 10 MB.';

  @override
  String get documentOpenFailed => 'Dokumen tidak bisa dibuka. Coba lagi.';

  @override
  String get documentFallbackName => 'Dokumen.pdf';

  @override
  String openDocument(String name) {
    return 'Buka $name';
  }

  @override
  String get errorAttachmentNotAllowed =>
      'Lampiran ini tidak didukung. Chat CS menerima gambar dan PDF; chat lain hanya gambar.';

  @override
  String get composeRemoveImage => 'Hapus gambar';

  @override
  String get composeTooManyImages => 'Maksimal 4 gambar';

  @override
  String get composeImageTooLarge => 'Ukuran gambar maksimal 5 MB';

  @override
  String get composePosted => 'Post terkirim';

  @override
  String get sentimentLabel => 'Sentimen';

  @override
  String get sentimentBullish => 'Bullish';

  @override
  String get sentimentBearish => 'Bearish';

  @override
  String get sentimentNeutral => 'Netral';

  @override
  String get sentimentNone => 'Tanpa';

  @override
  String get like => 'Suka';

  @override
  String get unlike => 'Batal suka';

  @override
  String get comment => 'Komentar';

  @override
  String get reply => 'Balas';

  @override
  String get postDetail => 'Post';

  @override
  String get postNotFound => 'Post tidak ditemukan atau sudah dihapus.';

  @override
  String get postDeleted => 'Post dihapus';

  @override
  String get deletePostConfirm => 'Hapus post ini?';

  @override
  String get deleteCommentConfirm => 'Hapus komentar ini?';

  @override
  String get comments => 'Komentar';

  @override
  String get noComments => 'Belum ada komentar. Mulai diskusi!';

  @override
  String get writeComment => 'Tulis komentar…';

  @override
  String replyingTo(String name) {
    return 'Membalas $name';
  }

  @override
  String get commentDeleted => '[komentar dihapus]';

  @override
  String viewMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lihat $count balasan lainnya',
      one: 'Lihat 1 balasan lainnya',
    );
    return '$_temp0';
  }

  @override
  String get loadMoreComments => 'Muat komentar lainnya';

  @override
  String get continueThread => 'Lanjutkan thread';

  @override
  String get threadContext => 'Melanjutkan thread';

  @override
  String get collapse => 'Ciutkan';

  @override
  String get expand => 'Bentangkan';

  @override
  String hiddenReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count balasan disembunyikan',
      one: '1 balasan disembunyikan',
    );
    return '$_temp0';
  }

  @override
  String get newCommentsAvailable => 'Ada komentar baru';

  @override
  String get report => 'Laporkan';

  @override
  String get reportTitle => 'Laporkan konten';

  @override
  String get reportDetailsHint => 'Keterangan tambahan (opsional)';

  @override
  String get reportSent => 'Laporan terkirim. Terima kasih.';

  @override
  String get reasonSpam => 'Spam';

  @override
  String get reasonAbuse => 'Pelecehan / kasar';

  @override
  String get reasonScam => 'Penipuan';

  @override
  String get reasonPumpAndDump => 'Ajakan goreng saham';

  @override
  String get reasonMisinformation => 'Informasi menyesatkan';

  @override
  String get reasonOther => 'Lainnya';

  @override
  String get block => 'Blokir';

  @override
  String get unblock => 'Buka blokir';

  @override
  String blockConfirm(String name) {
    return 'Blokir $name? Anda tidak akan saling melihat post, komentar, dan pesan.';
  }

  @override
  String blocked(String name) {
    return '$name diblokir';
  }

  @override
  String get follow => 'Ikuti';

  @override
  String get followingLabel => 'Mengikuti';

  @override
  String followers(int count) {
    return '$count pengikut';
  }

  @override
  String followingCount(int count) {
    return '$count mengikuti';
  }

  @override
  String postsCount(int count) {
    return '$count post';
  }

  @override
  String get followsYou => 'Mengikuti Anda';

  @override
  String get sendMessage => 'Kirim pesan';

  @override
  String get editProfile => 'Ubah profil';

  @override
  String get displayName => 'Nama tampilan';

  @override
  String get bio => 'Bio';

  @override
  String get changeAvatar => 'Ganti foto';

  @override
  String get profileNotFound => 'User tidak ditemukan.';

  @override
  String get watch => 'Pantau';

  @override
  String get watching => 'Dipantau';

  @override
  String watchers(int count) {
    return '$count pemantau';
  }

  @override
  String get stockDiscussion => 'Diskusi';

  @override
  String get stockNotFound => 'Kode saham tidak valid.';

  @override
  String get chats => 'Chat';

  @override
  String get noChats => 'Belum ada percakapan.';

  @override
  String get selectChat => 'Pilih percakapan untuk mulai chat.';

  @override
  String get newGroup => 'Grup baru';

  @override
  String get groupName => 'Nama grup';

  @override
  String get addMembers => 'Tambah anggota';

  @override
  String get create => 'Buat';

  @override
  String get searchUsers => 'Cari user…';

  @override
  String members(int count) {
    return '$count anggota';
  }

  @override
  String get online => 'Online';

  @override
  String typing(String name) {
    return '$name sedang mengetik…';
  }

  @override
  String get typingMany => 'Beberapa orang sedang mengetik…';

  @override
  String get messageHint => 'Tulis pesan…';

  @override
  String get messageDeleted => '[pesan dihapus]';

  @override
  String get messageFailed => 'Gagal terkirim. Ketuk untuk kirim ulang.';

  @override
  String get messageRead => 'Dibaca';

  @override
  String get messageSent => 'Terkirim';

  @override
  String get messageSending => 'Mengirim…';

  @override
  String get reconnecting => 'Menyambungkan ulang…';

  @override
  String get attachment => '[lampiran]';

  @override
  String get replyToMessage => 'Balas pesan';

  @override
  String get deleteMessageConfirm => 'Hapus pesan ini untuk semua orang?';

  @override
  String get leaveRoom => 'Keluar';

  @override
  String get mute => 'Bisukan';

  @override
  String get unmute => 'Aktifkan suara';

  @override
  String get sendShortcutHint => 'Enter untuk kirim, Shift+Enter untuk baris baru';

  @override
  String get notifications => 'Notifikasi';

  @override
  String get noNotifications => 'Belum ada notifikasi.';

  @override
  String get markAllRead => 'Tandai semua dibaca';

  @override
  String notifReply(String name) {
    return '$name membalas Anda';
  }

  @override
  String notifMention(String name) {
    return '$name menyebut Anda';
  }

  @override
  String notifLike(String name, int count, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name dan $others lainnya menyukai konten Anda',
      one: '$name menyukai konten Anda',
    );
    return '$_temp0';
  }

  @override
  String notifFollow(String name) {
    return '$name mulai mengikuti Anda';
  }

  @override
  String notifMessage(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pesan baru dari $name',
      one: 'Pesan baru dari $name',
    );
    return '$_temp0';
  }

  @override
  String get someone => 'Seseorang';

  @override
  String get typingShort => 'mengetik…';

  @override
  String get messageDelivered => 'Diterima';

  @override
  String get pollAddTooltip => 'Tambah polling';

  @override
  String get pollRemove => 'Hapus polling';

  @override
  String pollOptionHint(int index) {
    return 'Pilihan $index';
  }

  @override
  String get pollAddOption => 'Tambah pilihan';

  @override
  String get pollDuration => 'Durasi';

  @override
  String get pollDuration1h => '1 jam';

  @override
  String get pollDuration6h => '6 jam';

  @override
  String get pollDuration1d => '1 hari';

  @override
  String get pollDuration3d => '3 hari';

  @override
  String get pollDuration7d => '7 hari';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count suara', zero: 'Belum ada suara');
    return '$_temp0';
  }

  @override
  String pollEndsIn(String time) {
    return 'Sisa $time';
  }

  @override
  String get pollEnded => 'Polling selesai';

  @override
  String get pollYourVote => 'Pilihan Anda';

  @override
  String get pollInvalidDraft => 'Isi 2–4 pilihan berbeda, masing-masing maksimal 40 karakter.';

  @override
  String pollTimeMinutes(int count) {
    return '$count menit';
  }

  @override
  String pollTimeHours(int count) {
    return '$count jam';
  }

  @override
  String pollTimeDays(int count) {
    return '$count hari';
  }

  @override
  String get errorPollClosed => 'Polling sudah berakhir.';

  @override
  String get errorAlreadyVoted => 'Anda sudah memilih di polling ini.';

  @override
  String get errorOwnPoll => 'Anda tidak bisa memilih di polling sendiri.';

  @override
  String get errorInvalidPoll => 'Polling tidak valid. Periksa pilihan dan durasinya.';

  @override
  String get errorDuplicateContent => 'Konten yang sama sudah dikirim berulang kali. Coba lagi beberapa menit lagi.';

  @override
  String get errorUserMuted => 'Akun Anda sedang dibatasi dan belum bisa mengirim konten.';

  @override
  String get today => 'Hari ini';

  @override
  String get yesterday => 'Kemarin';

  @override
  String get supportOfficialBadge => 'CS Resmi';

  @override
  String get supportOfficialChannel => 'Layanan resmi';

  @override
  String get supportOpenLink => 'Buka panduan';

  @override
  String get supportRatePrompt => 'Beri nilai layanan ini';

  @override
  String get supportRated => 'Terima kasih atas penilaian Anda';

  @override
  String get errorSecretRequestBlocked =>
      'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.';

  @override
  String get supportTitle => 'Bantuan / Chat CS';

  @override
  String get supportPickTopic => 'Apa yang bisa kami bantu?';

  @override
  String get supportPickTopicHint => 'Pilih topik agar CS yang tepat langsung membantu Anda.';

  @override
  String get supportHistory => 'Lihat riwayat chat';

  @override
  String supportOutOfHours(String time) {
    return 'CS sedang di luar jam layanan. Pesan Anda dibalas mulai $time.';
  }

  @override
  String get supportStatusWaiting => 'Menunggu CS';

  @override
  String supportQueueAhead(int count) {
    return '$count tiket di depan Anda';
  }

  @override
  String supportStatusHandled(String name) {
    return 'Ditangani oleh $name – CS Resmi';
  }

  @override
  String get supportStatusWaitingYou => 'Menunggu balasan Anda';

  @override
  String get supportStatusResolved => 'Selesai';

  @override
  String get supportStatusClosed => 'Ditutup';

  @override
  String get supportMenu => 'Menu bantuan';

  @override
  String get supportEndChat => 'Akhiri chat';

  @override
  String get supportEndConfirm => 'Akhiri chat dan tandai tiket ini selesai?';

  @override
  String get supportComplaint => 'Ajukan pengaduan';

  @override
  String get supportComplaintConfirm =>
      'Tiket ini akan dicatat sebagai pengaduan resmi dengan tenggat penyelesaian. Lanjutkan?';

  @override
  String get supportReportFake => 'Laporkan CS palsu';

  @override
  String get supportReportFakeHint => 'Ceritakan kejadiannya: siapa yang menghubungi, lewat apa, dan apa yang diminta.';

  @override
  String get supportSend => 'Kirim';

  @override
  String get supportMyTickets => 'Tiket saya';

  @override
  String get supportNoTickets => 'Belum ada tiket.';

  @override
  String get supportNewTicket => 'Buat tiket baru';

  @override
  String get supportRateTitle => 'Nilai layanan CS';

  @override
  String get supportRateComment => 'Komentar (opsional)';

  @override
  String get supportRateSubmit => 'Kirim nilai';

  @override
  String supportSensitiveWarning(String kinds) {
    return 'Pesan ini berisi $kinds dan akan disamarkan. CS OLT tidak pernah meminta OTP, PIN, atau password.';
  }

  @override
  String get supportKindOtp => 'kode OTP';

  @override
  String get supportKindPassword => 'password/PIN';

  @override
  String get supportKindCard => 'nomor kartu';

  @override
  String get supportKindNik => 'NIK';

  @override
  String get supportKindAccount => 'nomor rekening';

  @override
  String get supportComplaintFiled => 'Pengaduan dicatat. Tenggat penyelesaian tampil di chat.';

  @override
  String get supportFakeReported => 'Laporan terkirim. Tim kami segera menindaklanjuti.';

  @override
  String get supportClosed => 'Chat diakhiri.';

  @override
  String get officialAccountBadge => 'Resmi';

  @override
  String get pinnedLabel => 'Disematkan';

  @override
  String get announcementLabel => 'Pengumuman';

  @override
  String notifAnnouncement(String name) {
    return '$name membuat pengumuman';
  }

  @override
  String supportTicketClosedNotice(String ticket) {
    return 'Tiket #$ticket sudah ditutup dan tidak bisa dibalas lagi.';
  }

  @override
  String supportTicketMeta(String date, String status) {
    return '$date · $status';
  }

  @override
  String supportRating(int rating) {
    return 'Nilai $rating/5';
  }

  @override
  String get supportUnavailable => 'Chat CS belum tersedia. Coba lagi sebentar lagi.';

  @override
  String get errorUnsupportedType =>
      'Jenis file tidak didukung. Gunakan gambar JPEG, PNG, WebP, atau GIF (foto profil tanpa GIF), atau PDF di chat CS.';

  @override
  String get errorFileTooLarge =>
      'File terlalu besar. Batasnya 5 MB untuk gambar, 2 MB untuk foto profil, dan 10 MB untuk PDF.';

  @override
  String get errorEmptyFile => 'File kosong. Pilih file lain.';

  @override
  String get errorInvalidImage => 'Gambar rusak atau tidak bisa dibaca. Coba gambar lain.';

  @override
  String get errorImageTooLarge => 'Resolusi gambar terlalu besar. Maksimal 10.000 piksel per sisi dan 40 megapiksel.';

  @override
  String get errorInvalidPdf => 'PDF rusak atau tidak bisa dibaca.';

  @override
  String get errorPdfEncrypted =>
      'PDF yang dikunci kata sandi tidak bisa dikirim. Buka kuncinya dulu, lalu kirim ulang.';

  @override
  String get errorPdfActiveContent =>
      'PDF berisi skrip, file tersemat, atau konten aktif lain. Simpan ulang sebagai PDF biasa (misalnya lewat Cetak ke PDF), lalu kirim ulang.';

  @override
  String get errorUploadForbidden => 'Anda tidak diizinkan mengunggah file ke sini.';

  @override
  String get errorTooManyUploads => 'Batas unggahan hari ini sudah tercapai. Coba lagi besok.';

  @override
  String get errorUploadBusy => 'Server unggahan sedang sibuk. Coba lagi sebentar lagi.';

  @override
  String get errorStorageUnavailable => 'Unggahan file sedang tidak tersedia. Coba lagi nanti.';

  @override
  String get errorConsentRequired => 'Setujui Syarat & Ketentuan dan Pedoman Komunitas terbaru untuk mengirim konten.';

  @override
  String get consentDeclined => 'Belum terkirim. Setujui dokumen terbaru untuk mengirim; tulisan Anda tetap tersimpan.';

  @override
  String get consentTitle => 'Persetujuan diperlukan';

  @override
  String get consentIntro => 'Sebelum ikut berdiskusi, baca dan setujui dokumen berikut.';

  @override
  String consentAgree(String documents) {
    return 'Saya telah membaca dan menyetujui $documents.';
  }

  @override
  String get consentAccept => 'Setuju';

  @override
  String get consentLater => 'Nanti';

  @override
  String get consentRead => 'Baca';

  @override
  String get consentReview => 'Tinjau';

  @override
  String get consentAccepted => 'Terima kasih. Persetujuan Anda sudah tersimpan.';

  @override
  String consentBannerUpdated(String documents) {
    return '$documents diperbarui — tinjau dan setujui.';
  }

  @override
  String consentBannerRequired(String documents) {
    return 'Tinjau dan setujui $documents untuk ikut berdiskusi.';
  }

  @override
  String legalVersion(int version, String date) {
    return 'Versi $version · berlaku $date';
  }

  @override
  String get legalChanges => 'Yang berubah';

  @override
  String get listAnd => 'dan';

  @override
  String get accountSettingsTitle => 'Privasi & akun';

  @override
  String get accountLegalSection => 'Dokumen hukum';

  @override
  String get accountDataSection => 'Data Anda';

  @override
  String get accountExport => 'Unduh data saya';

  @override
  String get accountExportHint => 'Salinan data komunitas Anda dalam format JSON. Bisa diunduh 3 kali sehari.';

  @override
  String get accountExportSaved => 'Data komunitas Anda sudah diunduh.';

  @override
  String get accountExportLimit => 'Unduh data dibatasi 3 kali sehari. Coba lagi besok.';

  @override
  String get accountDelete => 'Hapus akun komunitas';

  @override
  String get accountDeleteHint => 'Menghapus profil dan konten komunitas Anda. Akun trading tidak terpengaruh.';

  @override
  String get accountDeleteTitle => 'Hapus akun komunitas?';

  @override
  String get accountDeleteIntro => 'Yang terjadi bila akun komunitas dihapus:';

  @override
  String get accountDeleteContent => 'Postingan, komentar, dan pesan chat Anda dihapus dari tampilan semua orang.';

  @override
  String get accountDeleteArchive => 'Salinan konten tetap diarsipkan untuk regulator sesuai ketentuan hukum.';

  @override
  String get accountDeleteRelations => 'Pengikut, akun yang Anda ikuti, blokir, dan bisukan dihapus.';

  @override
  String get accountDeleteSupport =>
      'Tiket layanan CS tetap tercatat untuk keperluan kepatuhan, tetapi pesan dan lampiran chat CS ikut dihapus.';

  @override
  String get accountDeleteTrading => 'Akun trading OLT Anda tidak terpengaruh.';

  @override
  String get accountDeleteFresh => 'Saat membuka komunitas lagi, profil komunitas baru yang kosong akan dibuat.';

  @override
  String accountDeleteTypeToConfirm(String word) {
    return 'Ketik $word untuk konfirmasi';
  }

  @override
  String get accountDeleteWord => 'HAPUS';

  @override
  String get accountDeleteConfirm => 'Hapus akun';

  @override
  String get accountDeleteProgress => 'Menghapus akun komunitas…';

  @override
  String get accountDeleted => 'Akun komunitas Anda sudah dihapus.';
}
