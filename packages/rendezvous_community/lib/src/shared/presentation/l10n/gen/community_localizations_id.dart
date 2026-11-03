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
  String get messagePending => 'Menunggu dikirim';

  @override
  String get offlineBanner => 'Anda sedang offline. Menampilkan data tersimpan.';

  @override
  String get offlineChatBanner => 'Anda sedang offline. Pesan teks dikirim otomatis saat tersambung kembali.';

  @override
  String get errorAttachmentOffline => 'Gambar dan dokumen hanya bisa dikirim saat online.';

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

  @override
  String get errorNewAccountImage => 'Akun baru belum bisa melampirkan gambar. Coba lagi beberapa hari lagi.';

  @override
  String get errorNewAccountLink => 'Akun baru belum bisa membagikan tautan. Coba lagi beberapa hari lagi.';

  @override
  String get errorLinkBlocked => 'Tautan ini tidak diizinkan.';

  @override
  String get errorContactBlocked => 'Konten ini tidak bisa dikirim karena melanggar Pedoman Komunitas.';

  @override
  String errorSlowMode(int seconds) {
    return 'Slow mode aktif. Tunggu $seconds detik sebelum mengirim lagi.';
  }

  @override
  String get errorSlowModeShort => 'Slow mode aktif. Tunggu sebentar sebelum mengirim lagi.';

  @override
  String get errorDmNotAllowed => 'Pengguna ini tidak menerima pesan langsung dari Anda.';

  @override
  String get errorDmRequestLimit =>
      'Tunggu sampai penerima menerima permintaan pesan Anda sebelum mengirim pesan lagi.';

  @override
  String get errorSocialDisabled => 'Fitur komunitas sementara tidak tersedia. Chat CS tetap bisa dipakai.';

  @override
  String get errorEditWindowExpired => 'Batas waktu edit sudah lewat.';

  @override
  String get errorPollNotEditable => 'Post dengan polling tidak bisa diedit.';

  @override
  String get errorImageBlocked => 'Gambar ini tidak bisa diunggah karena melanggar Pedoman Komunitas.';

  @override
  String get errorImageCheckUnavailable => 'Pemeriksaan gambar sedang tidak tersedia. Coba lagi sebentar lagi.';

  @override
  String get errorAppealExists => 'Banding untuk ini sudah pernah diajukan.';

  @override
  String get errorAppealWindowClosed => 'Batas waktu pengajuan banding sudah lewat.';

  @override
  String get errorAppealNotAllowed => 'Keputusan ini tidak bisa diajukan banding.';

  @override
  String get errorAppealReason => 'Alasan banding 10–1000 karakter.';

  @override
  String get errorQueryTooShort => 'Kata kunci terlalu pendek.';

  @override
  String get errorQueryTooLong => 'Kata kunci terlalu panjang.';

  @override
  String get errorShareNotAllowed => 'Post tidak bisa dibagikan ke chat ini.';

  @override
  String get errorRequestNotFound => 'Permintaan pesan sudah tidak ada.';

  @override
  String get errorInvalidQuietHours => 'Jam tenang tidak valid.';

  @override
  String get socialUnavailableTitle => 'Komunitas sedang tidak tersedia';

  @override
  String get socialUnavailableBody => 'Fitur komunitas sedang dalam pemeliharaan. Chat CS tetap bisa dipakai.';

  @override
  String get featureUnavailable => 'Fitur ini sedang tidak tersedia.';

  @override
  String get updateRequiredTitle => 'Perbarui aplikasi';

  @override
  String get updateRequiredBody =>
      'Versi aplikasi ini tidak lagi didukung fitur komunitas. Perbarui aplikasi untuk melanjutkan.';

  @override
  String get moderationHeld => 'Menunggu tinjauan';

  @override
  String get moderationHeldHint => 'Hanya Anda yang bisa melihatnya sampai ditinjau moderator.';

  @override
  String get moderationHidden => 'Disembunyikan moderator';

  @override
  String get moderationHiddenHint => 'Konten ini tidak terlihat oleh orang lain.';

  @override
  String get messageRequests => 'Permintaan pesan';

  @override
  String get messageRequestsEmpty => 'Tidak ada permintaan pesan.';

  @override
  String messageRequestMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count pesan', one: '1 pesan');
    return '$_temp0';
  }

  @override
  String messageRequestIntro(String name) {
    return '$name belum Anda ikuti. Terima untuk membalas, atau tolak untuk menyembunyikan permintaan ini.';
  }

  @override
  String get messageRequestAccept => 'Terima';

  @override
  String get messageRequestDecline => 'Tolak';

  @override
  String get messageRequestBlock => 'Blokir & laporkan';

  @override
  String messageRequestBlockConfirm(String name) {
    return 'Blokir $name dan laporkan permintaan ini sebagai spam?';
  }

  @override
  String get messageRequestAccepted => 'Permintaan diterima.';

  @override
  String get messageRequestDeclined => 'Permintaan ditolak.';

  @override
  String get messageRequestImageHidden => 'Gambar diburamkan sampai Anda menerima permintaan.';

  @override
  String dmRequestSenderNotice(String name, int max) {
    return 'Bila $name belum mengikuti Anda, pesan Anda masuk sebagai permintaan pesan. Anda bisa mengirim hingga $max pesan sampai permintaan diterima.';
  }

  @override
  String dmRequestLimitNotice(String name, int max) {
    return 'Anda sudah mengirim $max pesan. Tunggu $name menerima permintaan pesan Anda.';
  }

  @override
  String get accountMessagesSection => 'Pesan langsung';

  @override
  String get dmPolicyTitle => 'Siapa yang bisa mengirim pesan langsung';

  @override
  String get dmPolicyEveryone => 'Semua orang';

  @override
  String get dmPolicyEveryoneHint => 'Orang yang tidak Anda ikuti masuk ke Permintaan pesan.';

  @override
  String get dmPolicyFollowing => 'Hanya yang saya ikuti';

  @override
  String get dmPolicyNone => 'Tidak ada';

  @override
  String get dmPolicyNoneHint => 'Percakapan yang sudah ada tetap berjalan.';

  @override
  String get dmPolicySaved => 'Pengaturan pesan disimpan.';

  @override
  String get appealAction => 'Ajukan banding';

  @override
  String get appealTitle => 'Ajukan banding';

  @override
  String get appealHint => 'Jelaskan mengapa menurut Anda keputusan ini keliru (10–1000 karakter).';

  @override
  String get appealSubmit => 'Kirim banding';

  @override
  String get appealSent => 'Banding terkirim. Kami akan memberi tahu hasilnya.';

  @override
  String get myAppeals => 'Banding saya';

  @override
  String get myAppealsEmpty => 'Belum ada banding.';

  @override
  String get appealStatusPending => 'Sedang ditinjau';

  @override
  String get appealStatusAccepted => 'Diterima';

  @override
  String get appealStatusRejected => 'Ditolak';

  @override
  String get appealTargetSanction => 'Sanksi akun';

  @override
  String get appealTargetPost => 'Post';

  @override
  String get appealTargetComment => 'Komentar';

  @override
  String get appealTargetMessage => 'Pesan';

  @override
  String appealDecisionNote(String note) {
    return 'Catatan: $note';
  }

  @override
  String get activeSanctions => 'Sanksi aktif';

  @override
  String get noActiveSanctions => 'Tidak ada sanksi aktif.';

  @override
  String get sanctionWarning => 'Peringatan';

  @override
  String get sanctionMute => 'Dibatasi mengirim konten';

  @override
  String get sanctionBan => 'Akun diblokir';

  @override
  String sanctionUntil(String date) {
    return 'Sampai $date';
  }

  @override
  String get sanctionPermanent => 'Tanpa batas waktu';

  @override
  String get accountAppealsSection => 'Banding & sanksi';

  @override
  String get accountAppealsHint => 'Lihat sanksi aktif dan status banding Anda.';

  @override
  String get notifAppealAccepted => 'Banding Anda diterima';

  @override
  String get notifAppealRejected => 'Banding Anda ditolak';

  @override
  String get notificationSettings => 'Notifikasi';

  @override
  String get notificationSettingsHint => 'Atur notifikasi di aplikasi dan push per jenis, serta jam tenang.';

  @override
  String get notifTypeReply => 'Balasan';

  @override
  String get notifTypeMention => 'Mention';

  @override
  String get notifTypeLike => 'Suka';

  @override
  String get notifTypeFollow => 'Pengikut baru';

  @override
  String get notifTypeMessage => 'Pesan chat';

  @override
  String get notifTypeAnnouncement => 'Pengumuman';

  @override
  String get notifTypeAppeal => 'Banding';

  @override
  String get notifTypeTrade => 'Transaksi';

  @override
  String get notifTypeTradeHint => 'Order dan transaksi saham';

  @override
  String get notifTypeFunds => 'Dana';

  @override
  String get notifTypeFundsHint => 'Setoran, penarikan, dan RDN';

  @override
  String get notifTypeMarket => 'Pasar';

  @override
  String get notifTypeMarketHint => 'Alert harga, IPO, dan aksi korporasi';

  @override
  String get notifTypeOltInfo => 'Info';

  @override
  String get notifTypeOltInfoHint => 'Informasi lain dari OLT';

  @override
  String get notifTypePromo => 'Promo';

  @override
  String get notifTypePromoHint => 'Promo dan penawaran';

  @override
  String get notifSectionOlt => 'Notifikasi OLT';

  @override
  String get notifOltImportantHint => 'Pesan penting dari OLT selalu dikirim, termasuk saat jam tenang.';

  @override
  String get notifInApp => 'Di aplikasi';

  @override
  String get notifPush => 'Push';

  @override
  String get notifSupportAlwaysOn => 'Pesan dari CS resmi selalu dikirim.';

  @override
  String get quietHours => 'Jam tenang';

  @override
  String get quietHoursHint => 'Push ditunda selama jam tenang (WIB). Notifikasi di aplikasi tetap masuk.';

  @override
  String get quietHoursStart => 'Mulai';

  @override
  String get quietHoursEnd => 'Selesai';

  @override
  String quietHoursRange(String start, String end) {
    return '$start–$end WIB';
  }

  @override
  String notifFollowMany(String name, int others) {
    return '$name dan $others lainnya mulai mengikuti Anda';
  }

  @override
  String get searchTitle => 'Cari';

  @override
  String get searchHint => 'Cari post, pengguna, \$KODE, #hashtag';

  @override
  String get searchTabAll => 'Semua';

  @override
  String get searchTabPosts => 'Post';

  @override
  String get searchTabUsers => 'Pengguna';

  @override
  String get searchTabStocks => 'Saham';

  @override
  String get searchTabHashtags => 'Hashtag';

  @override
  String searchMinLength(int min) {
    return 'Ketik minimal $min karakter.';
  }

  @override
  String searchNoResults(String query) {
    return 'Tidak ada hasil untuk \"$query\".';
  }

  @override
  String get searchSeeAll => 'Lihat semua';

  @override
  String postsLast7Days(int count) {
    return '$count post (7 hari)';
  }

  @override
  String get trendingHashtags => 'Hashtag trending';

  @override
  String hashtagFeedEmpty(String tag) {
    return 'Belum ada post dengan #$tag.';
  }

  @override
  String get trendingTitle => 'Trending';

  @override
  String get trendingStocks => 'Saham';

  @override
  String get trendingRising => 'Naik daun';

  @override
  String get trendingPosts => 'Populer';

  @override
  String get trendingWindowDay => '24 jam';

  @override
  String get trendingWindowWeek => '7 hari';

  @override
  String get trendingEmpty => 'Belum ada data trending.';

  @override
  String trendingPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count post', one: '1 post');
    return '$_temp0';
  }

  @override
  String trendingGrowth(String percent) {
    return '+$percent%';
  }

  @override
  String get sentimentTitle => 'Sentimen komunitas';

  @override
  String get sentimentNoData => 'Belum ada post berlabel sentimen.';

  @override
  String sentimentBasedOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Dari $count post', one: 'Dari 1 post');
    return '$_temp0';
  }

  @override
  String get editAction => 'Edit';

  @override
  String get editPostTitle => 'Edit post';

  @override
  String get editCommentTitle => 'Edit komentar';

  @override
  String get editSaved => 'Perubahan disimpan.';

  @override
  String get bookmarkAdd => 'Simpan';

  @override
  String get bookmarkRemove => 'Hapus dari simpanan';

  @override
  String get bookmarksTitle => 'Disimpan';

  @override
  String get bookmarksEmpty => 'Belum ada post yang disimpan.';

  @override
  String get bookmarkAdded => 'Post disimpan.';

  @override
  String get bookmarkRemoved => 'Dihapus dari simpanan.';

  @override
  String get reactionAdd => 'Beri reaksi';

  @override
  String get shareToChat => 'Kirim ke chat';

  @override
  String get sharePickRoom => 'Kirim ke…';

  @override
  String get shareMessageHint => 'Tambahkan pesan (opsional)';

  @override
  String get shareSent => 'Post dikirim ke chat.';

  @override
  String get shareNoRooms => 'Belum ada chat. Mulai percakapan dulu.';

  @override
  String get sharedPostUnavailable => 'Post tidak tersedia';

  @override
  String get sharedPostLabel => 'Post';

  @override
  String get linkOpenTitle => 'Buka tautan?';

  @override
  String linkOpenBody(String domain) {
    return 'Anda akan membuka $domain di luar aplikasi. Pastikan Anda mempercayai situs ini.';
  }

  @override
  String get linkOpenAction => 'Buka';

  @override
  String get linkOpenFailed => 'Tautan tidak bisa dibuka.';

  @override
  String get botLabel => 'Bot';

  @override
  String slowModeBanner(int seconds) {
    return 'Slow mode: 1 pesan tiap $seconds detik';
  }

  @override
  String slowModeWait(int seconds) {
    return 'Tunggu $seconds dtk';
  }

  @override
  String get pinnedMessageLabel => 'Pesan disematkan';

  @override
  String dmRequestPendingSender(String name, int sent, int max) {
    return 'Pesan Anda masih berupa permintaan ($sent/$max). $name perlu menerimanya sebelum Anda bisa mengirim lebih banyak.';
  }

  @override
  String dmRequestPendingRecipient(String name) {
    return '$name mengirim permintaan pesan. Terima untuk membalas.';
  }

  @override
  String get moderatedContent => 'Konten yang dimoderasi';

  @override
  String get moderatedContentEmpty => 'Tidak ada konten Anda yang dimoderasi dalam 90 hari terakhir.';

  @override
  String get moderationRemoved => 'Dihapus moderator';

  @override
  String get stockCardSend => 'Kirim kartu saham';

  @override
  String get stockCardHint => 'Kode saham, mis. BBCA, TLKM';

  @override
  String get stockCardAdd => 'Tambah';

  @override
  String get stockCardInvalid => 'Kode saham tidak valid';

  @override
  String stockCardLimit(int count) {
    return 'Maksimal $count saham per pesan';
  }

  @override
  String get bannerOpen => 'Selengkapnya';

  @override
  String get bannerDismiss => 'Tutup';

  @override
  String get draftsTitle => 'Draf postingan';

  @override
  String get draftsEmpty => 'Belum ada draf.';

  @override
  String get draftNoText => '(tanpa teks)';

  @override
  String get draftSaved => 'Draf tersimpan';

  @override
  String get draftSavedLocally => 'Draf tersimpan di perangkat ini';

  @override
  String get draftReplaced => 'Draf ini diperbarui di perangkat lain; versi terbaru dimuat.';

  @override
  String draftLimit(int count) {
    return 'Batas $count draf tercapai. Draf ini hanya tersimpan di perangkat ini.';
  }

  @override
  String notifMentionRoom(String name, String room) {
    return '$name menyebut Anda di $room';
  }

  @override
  String notifFollowedPost(String name) {
    return '$name membuat postingan baru';
  }

  @override
  String notifFollowedPostMany(String name, int count) {
    return '$name membuat $count postingan baru';
  }

  @override
  String get notifWatchlistDigest => 'Ringkasan saham pantauan';

  @override
  String notifWatchlistDigestBody(int count, String stocks, int others) {
    String _temp0 = intl.Intl.pluralLogic(others, locale: localeName, other: ', dan $others saham lainnya', zero: '');
    return '$count postingan baru tentang $stocks$_temp0';
  }

  @override
  String get notifTargetPost => 'Postingan';

  @override
  String get notifTargetComment => 'Komentar';

  @override
  String get notifTargetMessage => 'Pesan';

  @override
  String notifModerationHidden(String target) {
    return '$target Anda disembunyikan moderator';
  }

  @override
  String notifModerationRemoved(String target) {
    return '$target Anda dihapus moderator';
  }

  @override
  String get notifModerationAppealable => 'Ketuk untuk melihat detail dan mengajukan banding';

  @override
  String get notifModerationAppealed => 'Banding untuk konten ini sudah diajukan';

  @override
  String notifRoomMuted(String room) {
    return 'Anda dibisukan moderator di $room';
  }

  @override
  String notifRoomUnmuted(String room) {
    return 'Bisu Anda di $room dicabut';
  }

  @override
  String notifRoomMutedUntil(String time) {
    return 'Anda bisa mengirim pesan lagi setelah $time';
  }

  @override
  String get notifRoomUnmutedBody => 'Anda bisa mengirim pesan lagi di room ini';

  @override
  String get notifTypeFollowedPost => 'Postingan akun yang diikuti';

  @override
  String get notifTypeFollowedPostHint => 'Push bawaan mati';

  @override
  String get notifTypeWatchlistDigest => 'Ringkasan saham pantauan';

  @override
  String get notifTypeWatchlistDigestHint => 'Setiap hari pukul 17.05 WIB';

  @override
  String get notifTypeModeration => 'Moderasi';

  @override
  String get notifTypeModerationHint => 'Selalu tampil di aplikasi';

  @override
  String get roomModeratorBadge => 'Moderator';

  @override
  String get roomModeratorNotice => 'Anda moderator room ini. Tekan lama pesan anggota untuk aksi moderasi.';

  @override
  String get roomModHide => 'Sembunyikan pesan';

  @override
  String get roomModMute => 'Bisukan anggota';

  @override
  String get roomModEscalate => 'Eskalasi ke staf';

  @override
  String get roomModHideTitle => 'Sembunyikan pesan ini?';

  @override
  String get roomModHideBody =>
      'Pesan disembunyikan dari anggota lain. Staf meninjau setiap aksi moderator dan pengirim bisa mengajukan banding.';

  @override
  String roomModMuteTitle(String name) {
    return 'Bisukan $name di room ini';
  }

  @override
  String get roomModMuteBody =>
      'Anggota tetap bisa membaca room, tetapi tidak bisa mengirim pesan sampai waktu bisu berakhir.';

  @override
  String get roomModEscalateTitle => 'Eskalasi pesan ke staf';

  @override
  String get roomModEscalateBody =>
      'Pesan dikirim ke antrean laporan staf untuk ditinjau. Pesan tetap tampil sampai staf memutuskan.';

  @override
  String get roomModReason => 'Alasan';

  @override
  String get roomModDuration => 'Lama bisu';

  @override
  String get roomModNoteHint => 'Catatan untuk staf (opsional)';

  @override
  String roomModMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String roomModHours(int hours) {
    return '$hours jam';
  }

  @override
  String get roomModHidden => 'Pesan disembunyikan';

  @override
  String roomModMuted(String name, String time) {
    return '$name dibisukan sampai $time';
  }

  @override
  String get roomModEscalated => 'Pesan dieskalasi ke staf';

  @override
  String roomModMemberMuted(String time) {
    return 'Dibisukan sampai $time';
  }

  @override
  String roomMutedBanner(String time) {
    return 'Moderator membisukan Anda di room ini sampai $time. Anda tetap bisa membaca pesan.';
  }

  @override
  String get roomMutedComposer => 'Anda sedang dibisukan di room ini';

  @override
  String get errorRoomMuted => 'Anda sedang dibisukan moderator di room ini.';

  @override
  String get errorNotRoomModerator => 'Anda bukan lagi moderator room ini.';

  @override
  String get errorRoomModeratorSuspended => 'Hak moderator Anda sedang ditangguhkan.';

  @override
  String get errorRoomModTarget => 'Akun resmi, moderator lain, dan pesan Anda sendiri tidak bisa dimoderasi.';

  @override
  String get errorAlreadyModerated => 'Aksi ini sudah dilakukan sebelumnya.';
}
