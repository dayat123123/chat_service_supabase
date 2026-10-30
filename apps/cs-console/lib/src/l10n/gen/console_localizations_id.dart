// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'console_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class ConsoleLocalizationsId extends ConsoleLocalizations {
  ConsoleLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'CS Console';

  @override
  String get loginTitle => 'Masuk ke CS Console';

  @override
  String get loginSubtitle =>
      'Khusus CS dan supervisor OLT. Akses hanya lewat jaringan internal (VPN).';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Tampilkan password';

  @override
  String get hidePassword => 'Sembunyikan password';

  @override
  String get signIn => 'Masuk';

  @override
  String get signOut => 'Keluar';

  @override
  String get useOtherAccount => 'Pakai akun lain';

  @override
  String get totpTitle => 'Verifikasi dua langkah';

  @override
  String get totpHint =>
      'Masukkan 6 digit kode dari aplikasi authenticator Anda.';

  @override
  String get totpCode => 'Kode 6 digit';

  @override
  String get verify => 'Verifikasi';

  @override
  String get enrollTitle => 'Aktifkan verifikasi dua langkah';

  @override
  String get enrollHint =>
      'Akun CS wajib memakai aplikasi authenticator. Pindai kode QR ini atau masukkan kunci di bawah secara manual, lalu masukkan kode 6 digit yang muncul.';

  @override
  String get enrollKey => 'Kunci manual';

  @override
  String get enrollActivate => 'Aktifkan & masuk';

  @override
  String get copy => 'Salin';

  @override
  String signedOutIdle(int minutes) {
    return 'Anda keluar otomatis karena tidak aktif $minutes menit.';
  }

  @override
  String get signedOutExpired => 'Sesi berakhir. Silakan masuk lagi.';

  @override
  String get signedOutNotStaff => 'Akun ini bukan akun CS aktif.';

  @override
  String get errorInvalidLogin => 'Email atau password salah.';

  @override
  String get errorInvalidCode =>
      'Kode verifikasi salah atau kedaluwarsa. Coba kode terbaru.';

  @override
  String get errorTooManyAttempts =>
      'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';

  @override
  String get errorNetwork =>
      'Tidak bisa terhubung ke server. Periksa jaringan atau VPN.';

  @override
  String get errorUnavailable =>
      'Layanan sedang sibuk. Coba lagi sebentar lagi.';

  @override
  String get errorSecretRequestBlocked =>
      'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.';

  @override
  String get errorGeneric => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get idleTitle => 'Masih di sana?';

  @override
  String idleBody(int seconds) {
    return 'Anda akan keluar otomatis dalam $seconds detik karena tidak ada aktivitas.';
  }

  @override
  String get idleStay => 'Tetap masuk';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusBusy => 'Sibuk';

  @override
  String get statusBreak => 'Istirahat';

  @override
  String get statusOffline => 'Offline';

  @override
  String get changeStatus => 'Ubah status';

  @override
  String activeTickets(int count, int max) {
    return 'Tiket aktif $count/$max';
  }

  @override
  String get activeTicketsHint =>
      'Tiket yang sedang Anda tangani dibanding batas maksimal';

  @override
  String get alertsSettings => 'Notifikasi';

  @override
  String get alertsNewTickets => 'Notifikasi tiket baru';

  @override
  String get alertsAll => 'Semua tiket baru';

  @override
  String get alertsHighPriority => 'Prioritas tinggi saja (P1–P2)';

  @override
  String get alertsOff => 'Mati';

  @override
  String get alertsAllowBrowser => 'Izinkan notifikasi browser';

  @override
  String get alertsBlocked =>
      'Notifikasi browser diblokir (ubah di pengaturan browser)';

  @override
  String get alertsTestSound => 'Tes suara';

  @override
  String get alertNewTicket => 'Tiket baru';

  @override
  String get alertNewUrgentTicket => 'Tiket baru prioritas tinggi';

  @override
  String get alertCustomerMessage => 'Pesan baru dari nasabah';

  @override
  String get alertOpenTicket => 'Buka tiket untuk membalas';

  @override
  String alertTransferRequest(String name) {
    return 'Permintaan transfer dari $name';
  }

  @override
  String get alertFakeCs => 'Laporan CS palsu';

  @override
  String get alertSecretRequest => 'CS mencoba meminta OTP/PIN/password';

  @override
  String get account => 'Akun';

  @override
  String get roleAgent => 'CS';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleAdmin => 'Admin CS';

  @override
  String get roleCompliance => 'Kepatuhan';

  @override
  String get tabOpen => 'Terbuka';

  @override
  String get tabMine => 'Saya';

  @override
  String get tabResolvedToday => 'Selesai hari ini';

  @override
  String get tabAllActive => 'Semua aktif';

  @override
  String get searchHint => 'Cari nomor tiket, nama, kode nasabah, isi pesan';

  @override
  String get filterTopic => 'Topik';

  @override
  String get filterPriority => 'Prioritas';

  @override
  String get filterFlag => 'Tanda';

  @override
  String get filterAll => 'Semua';

  @override
  String get clearFilters => 'Hapus filter';

  @override
  String get flagComplaint => 'Pengaduan';

  @override
  String get flagFraud => 'Fraud';

  @override
  String get flagVip => 'VIP';

  @override
  String get claim => 'Ambil';

  @override
  String waiting(String duration) {
    return 'menunggu $duration';
  }

  @override
  String get emptyOpen =>
      'Tidak ada tiket terbuka. Tiket baru akan muncul di sini.';

  @override
  String get emptyMine => 'Belum ada tiket yang Anda tangani.';

  @override
  String get emptyResolved => 'Belum ada tiket selesai hari ini.';

  @override
  String get emptyAllActive => 'Tidak ada tiket yang sedang ditangani.';

  @override
  String get emptySearch => 'Tidak ada tiket yang cocok.';

  @override
  String handledBy(String name) {
    return 'Ditangani oleh $name';
  }

  @override
  String get you => 'Anda';

  @override
  String transferFrom(String name) {
    return 'Transfer dari $name';
  }

  @override
  String transferWaiting(String name) {
    return 'Menunggu $name menerima transfer';
  }

  @override
  String get accept => 'Terima';

  @override
  String get reject => 'Tolak';

  @override
  String get cancel => 'Batal';

  @override
  String get retry => 'Coba lagi';

  @override
  String get loadFailed => 'Gagal memuat data.';

  @override
  String get offlineHint =>
      'Anda Offline. Ubah status ke Online untuk mengambil tiket.';

  @override
  String get statusOpenLabel => 'Terbuka';

  @override
  String get statusClaimedLabel => 'Ditangani';

  @override
  String get statusWaitingLabel => 'Menunggu nasabah';

  @override
  String get statusResolvedLabel => 'Selesai';

  @override
  String get statusClosedLabel => 'Ditutup';

  @override
  String get selectTicket => 'Pilih tiket dari daftar di kiri.';

  @override
  String get previewBanner =>
      'Pratinjau hanya-baca. Ambil tiket ini untuk membalas.';

  @override
  String get closedBanner =>
      'Tiket sudah selesai. Pesan baru dari nasabah akan membuka tiket lagi.';

  @override
  String get join => 'Gabung';

  @override
  String get moveTo => 'Pindahkan ke…';

  @override
  String get tabReply => 'Balas';

  @override
  String get tabNote => 'Catatan internal';

  @override
  String get replyHint => 'Tulis balasan… ketik / untuk balasan cepat';

  @override
  String get noteHint => 'Tulis catatan untuk sesama CS…';

  @override
  String get noteInvisible => 'Tidak terlihat nasabah';

  @override
  String get send => 'Kirim';

  @override
  String get saveNote => 'Simpan catatan';

  @override
  String get noteSaved => 'Catatan disimpan.';

  @override
  String get quickReplies => 'Balasan cepat';

  @override
  String get quickRepliesEmpty => 'Tidak ada balasan cepat yang cocok.';

  @override
  String get attachImage => 'Lampirkan gambar';

  @override
  String get sendHelpLink => 'Kirim tautan bantuan';

  @override
  String get actionWait => 'Tunggu nasabah';

  @override
  String get actionRelease => 'Lepas';

  @override
  String get actionTransfer => 'Transfer';

  @override
  String get actionResolve => 'Selesaikan';

  @override
  String get releaseTitle => 'Lepas tiket ke antrean';

  @override
  String get releaseHint =>
      'Tiket kembali ke tab Terbuka dan bisa diambil CS lain.';

  @override
  String get reasonRequired => 'Alasan (wajib)';

  @override
  String get releaseConfirm => 'Lepas tiket';

  @override
  String get transferTitle => 'Transfer ke CS lain';

  @override
  String get transferHint =>
      'Tiket tetap milik Anda sampai CS tujuan menerima.';

  @override
  String get transferTo => 'CS tujuan';

  @override
  String get transferNote => 'Catatan serah terima';

  @override
  String get transferSend => 'Kirim permintaan';

  @override
  String get transferNoAgents =>
      'Tidak ada CS lain yang Online dan masih punya slot.';

  @override
  String slots(int count, int max) {
    return '$count/$max tiket';
  }

  @override
  String get resolveTitle => 'Selesaikan tiket';

  @override
  String get resolveOutcome => 'Hasil';

  @override
  String get resolveSummary => 'Ringkasan singkat (5–500 karakter)';

  @override
  String get resolveTags => 'Tag (opsional, pisahkan dengan koma)';

  @override
  String get resolveConfirm => 'Selesaikan';

  @override
  String get reassignTitle => 'Pindahkan tiket';

  @override
  String get reassignReason => 'Alasan (wajib, dicatat di audit log)';

  @override
  String get reassignConfirm => 'Pindahkan';

  @override
  String get priority => 'Prioritas';

  @override
  String createdAt(String time) {
    return 'Dibuat $time';
  }

  @override
  String get owner => 'Pemilik';

  @override
  String complaintDue(String date) {
    return 'Tenggat pengaduan $date';
  }

  @override
  String pendingTransfer(String name) {
    return 'Menunggu $name menerima transfer';
  }

  @override
  String get noticeClaimed => 'Tiket diambil. Anda sekarang pemiliknya.';

  @override
  String get noticeReleased => 'Tiket dikembalikan ke antrean.';

  @override
  String get noticeTransferRequested =>
      'Permintaan transfer dikirim. Tiket tetap milik Anda sampai diterima.';

  @override
  String get noticeResolved =>
      'Tiket diselesaikan. Nasabah diminta memberi nilai.';

  @override
  String get noticeWaiting => 'Status diubah: menunggu balasan nasabah.';

  @override
  String get noticeJoined => 'Anda bergabung ke percakapan.';

  @override
  String get noticeReassigned => 'Tiket dipindahkan.';

  @override
  String get noticeSent => 'Terkirim ke chat.';

  @override
  String get noticeStale => 'Tiket sudah berubah. Data terbaru dimuat ulang.';

  @override
  String transferRejected(String name, String ticket) {
    return '$name menolak transfer $ticket';
  }

  @override
  String transferExpired(String ticket) {
    return 'Permintaan transfer $ticket kedaluwarsa';
  }

  @override
  String get showInfo => 'Tampilkan info nasabah';

  @override
  String get hideInfo => 'Sembunyikan info nasabah';

  @override
  String get customerInfo => 'Info nasabah';

  @override
  String get dataAfterClaim =>
      'Data OLT nasabah tersedia setelah Anda mengambil tiket.';

  @override
  String get profile => 'Profil';

  @override
  String get fieldName => 'Nama';

  @override
  String get fieldClientCode => 'Kode nasabah';

  @override
  String get fieldSid => 'SID';

  @override
  String get fieldNik => 'NIK';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPhone => 'No. HP';

  @override
  String get fieldBirthDate => 'Tanggal lahir';

  @override
  String get fieldAddress => 'Alamat';

  @override
  String get fieldRdn => 'RDN';

  @override
  String get fieldBankAccount => 'Rek. penarikan';

  @override
  String get fieldAccountStatus => 'Status akun';

  @override
  String get fieldKycStatus => 'Status KYC';

  @override
  String get fieldSegment => 'Segmen';

  @override
  String get reveal => 'Tampilkan';

  @override
  String revealTitle(String field) {
    return 'Tampilkan $field';
  }

  @override
  String get revealReason => 'Alasan membuka data';

  @override
  String get revealNote =>
      'Data tampil 5 menit lalu disamarkan lagi. Akses ini tercatat di audit log.';

  @override
  String get orders => 'Order terakhir';

  @override
  String get cashTransactions => 'Transaksi dana terakhir';

  @override
  String get devices => 'Perangkat & login';

  @override
  String get security => 'Keamanan akun';

  @override
  String get history => 'Riwayat tiket';

  @override
  String get notes => 'Catatan internal';

  @override
  String get sendToChat => 'Kirim ke chat';

  @override
  String get noData => 'Tidak ada data.';

  @override
  String get oltUnavailable => 'Data OLT sedang tidak tersedia.';

  @override
  String get secureAccount => 'Amankan akun';

  @override
  String get secureConfirm =>
      'Kunci transaksi dan keluarkan semua perangkat nasabah di OLT? Nasabah akan diberi tahu di chat.';

  @override
  String get secureDone => 'Akun nasabah diamankan.';

  @override
  String get secureFailed => 'Sebagian aksi gagal. Hubungi tim OLT.';

  @override
  String get tradingLocked => 'Transaksi dikunci';

  @override
  String get accountLocked => 'Akun dikunci';

  @override
  String failedLogins(int count) {
    return 'Gagal login 24 jam: $count';
  }

  @override
  String get otpEnabled => 'OTP aktif';

  @override
  String get suspicious => 'Aktivitas mencurigakan';

  @override
  String lastPasswordChange(String date) {
    return 'Ganti password terakhir $date';
  }

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get sideBuy => 'Beli';

  @override
  String get sideSell => 'Jual';

  @override
  String lots(int count) {
    return '$count lot';
  }

  @override
  String get addNote => 'Tambah catatan';

  @override
  String get notesEmpty => 'Belum ada catatan.';

  @override
  String get noteHandover => 'Serah terima';

  @override
  String get orderDetail => 'Detail order';

  @override
  String get close => 'Tutup';

  @override
  String get lastSessions => 'Sesi aktif';

  @override
  String get lastLogins => 'Login terakhir';

  @override
  String get cashDetail => 'Detail transaksi dana';

  @override
  String get cashKind => 'Jenis';

  @override
  String get cashAmount => 'Nominal';

  @override
  String get cashBank => 'Bank';

  @override
  String get cashBankRef => 'Ref. bank';

  @override
  String get cashTime => 'Waktu';

  @override
  String get orderStock => 'Saham';

  @override
  String get orderSide => 'Sisi';

  @override
  String get orderPrice => 'Harga';

  @override
  String get orderLot => 'Lot';

  @override
  String orderFilled(String lot, String filled) {
    return '$lot (terisi $filled)';
  }

  @override
  String get orderStatus => 'Status';

  @override
  String get orderReason => 'Alasan';

  @override
  String get orderChannel => 'Kanal';

  @override
  String get refresh => 'Muat ulang';

  @override
  String get save => 'Simpan';

  @override
  String get edit => 'Ubah';

  @override
  String get delete => 'Hapus';

  @override
  String get done => 'Selesai';

  @override
  String get copied => 'Disalin';

  @override
  String get active => 'Aktif';

  @override
  String get inactive => 'Nonaktif';

  @override
  String get saved => 'Tersimpan';

  @override
  String since(String time) {
    return 'Sejak $time';
  }

  @override
  String updatedAt(String time) {
    return 'Diperbarui $time';
  }

  @override
  String get navTickets => 'Tiket';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navReports => 'Laporan';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String navAttention(int count) {
    return '$count tiket perlu perhatian';
  }

  @override
  String get dashboardTitle => 'Dashboard supervisor';

  @override
  String get dashboardStale => 'Gagal memperbarui, data mungkin belum terbaru';

  @override
  String get statOpen => 'Tiket terbuka';

  @override
  String get statLongestWait => 'Tunggu terlama';

  @override
  String get statNoQueue => 'Antrean kosong';

  @override
  String get statActive => 'Sedang ditangani';

  @override
  String get statResolvedToday => 'Selesai hari ini';

  @override
  String get statAgentsOnline => 'CS online';

  @override
  String get needsAttention => 'Perlu perhatian';

  @override
  String overdueTitle(int minutes, int p1) {
    return 'Belum diambil > $minutes menit (P1 > $p1 menit)';
  }

  @override
  String get overdueEmpty => 'Semua tiket terbuka masih dalam batas waktu.';

  @override
  String get flaggedTitle => 'Fraud / pengaduan belum diambil';

  @override
  String get flaggedEmpty =>
      'Tidak ada tiket fraud atau pengaduan yang menunggu.';

  @override
  String get offlineOwnedTitle => 'Milik CS yang offline';

  @override
  String get offlineOwnedEmpty =>
      'Tidak ada tiket milik CS yang sedang offline.';

  @override
  String moreTickets(int count) {
    return '+$count tiket lainnya';
  }

  @override
  String ownerOffline(String name) {
    return '$name offline';
  }

  @override
  String get agentsToday => 'Status CS hari ini';

  @override
  String get noAgents => 'Belum ada akun CS.';

  @override
  String get colAgent => 'CS';

  @override
  String get colStatus => 'Status';

  @override
  String get colActiveTickets => 'Tiket aktif';

  @override
  String get colResolvedToday => 'Selesai hari ini';

  @override
  String get colStatusSince => 'Status sejak';

  @override
  String get connectionLostHint =>
      'Web CS tidak mengirim heartbeat, kemungkinan koneksi terputus';

  @override
  String get reportsTitle => 'Laporan';

  @override
  String get rangeToday => 'Hari ini';

  @override
  String get rangeWeek => '7 hari';

  @override
  String get rangeMonth => '30 hari';

  @override
  String get rangeCustom => 'Pilih tanggal';

  @override
  String get rangePickerTitle => 'Pilih rentang laporan';

  @override
  String rangeTooLong(int days) {
    return 'Rentang laporan maksimal $days hari';
  }

  @override
  String get exportCsv => 'Ekspor CSV';

  @override
  String get exportDaily => 'Tiket per hari';

  @override
  String get exportAgents => 'Per CS';

  @override
  String get exportTopics => 'Topik';

  @override
  String get reportCreated => 'Tiket masuk';

  @override
  String get reportResolved => 'Selesai';

  @override
  String percentOfTickets(int percent) {
    return '$percent% dari tiket masuk';
  }

  @override
  String get reportClaimTime => 'Rata-rata sampai diambil';

  @override
  String get reportFirstResponse => 'Respons pertama';

  @override
  String get reportDuration => 'Durasi sampai selesai';

  @override
  String get reportAvgRating => 'Rating rata-rata';

  @override
  String ratingCount(int count) {
    return '$count penilaian';
  }

  @override
  String get reportPerDay => 'Tiket per hari';

  @override
  String get reportDate => 'Tanggal';

  @override
  String get reportEmpty => 'Belum ada data pada rentang ini.';

  @override
  String get reportPerAgent => 'Per CS';

  @override
  String get reportAgent => 'CS';

  @override
  String get reportAgentCode => 'Kode CS';

  @override
  String get reportHandled => 'Ditangani';

  @override
  String get reportTopTopics => 'Topik terbanyak';

  @override
  String get reportTopic => 'Topik';

  @override
  String get reportTopicCode => 'Kode topik';

  @override
  String get reportCount => 'Jumlah';

  @override
  String get reportShare => 'Porsi';

  @override
  String get reportClaimMinutes => 'Rata-rata menit sampai diambil';

  @override
  String get reportFirstResponseMinutes => 'Rata-rata menit respons pertama';

  @override
  String get reportResolutionMinutes => 'Rata-rata menit sampai selesai';

  @override
  String get reportRatings => 'Jumlah penilaian';

  @override
  String get reportTotal => 'Total';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get menuAccounts => 'Akun CS';

  @override
  String get menuTopics => 'Topik';

  @override
  String get menuQuickReplies => 'Quick reply';

  @override
  String get menuHours => 'Jam layanan & libur';

  @override
  String get menuMessages => 'Pesan otomatis';

  @override
  String get menuAssignment => 'Penugasan & alert';

  @override
  String get accountsTitle => 'Akun CS';

  @override
  String get accountsDescription =>
      'Tambah akun, atur peran dan batas tiket aktif, atau nonaktifkan akun. Akun yang dinonaktifkan langsung tidak bisa login, dan tiket aktifnya kembali ke antrean dengan tanda.';

  @override
  String get addAccount => 'Tambah akun';

  @override
  String get colRoles => 'Peran';

  @override
  String get colTeam => 'Tim';

  @override
  String get colTicketLimit => 'Batas tiket';

  @override
  String get colTwoFactor => '2FA';

  @override
  String get twoFactorOn => 'TOTP aktif';

  @override
  String get twoFactorPending => 'Belum daftar';

  @override
  String disabledSince(String time) {
    return 'Dinonaktifkan $time';
  }

  @override
  String get accountDisabled => 'Nonaktif';

  @override
  String get addAccountTitle => 'Tambah akun CS';

  @override
  String editAccountTitle(String name) {
    return 'Ubah akun $name';
  }

  @override
  String get displayName => 'Nama tampilan';

  @override
  String get displayNameHint => 'Terlihat oleh nasabah, 2–40 karakter';

  @override
  String get staffEmailHint => 'Email kerja untuk login web CS';

  @override
  String get rolesLabel => 'Peran';

  @override
  String get teamLabel => 'Tim';

  @override
  String get ticketLimitLabel => 'Batas tiket aktif (1–20)';

  @override
  String get accountActive => 'Akun aktif';

  @override
  String disableWarning(int count) {
    return 'Akun ini langsung tidak bisa login. $count tiket aktifnya kembali ke antrean dengan tanda \"Akun CS dinonaktifkan\".';
  }

  @override
  String get selfLocked =>
      'Anda tidak bisa menonaktifkan atau melepas peran admin akun sendiri.';

  @override
  String get createAccount => 'Buat akun';

  @override
  String get rolesRequired => 'Pilih minimal satu peran';

  @override
  String get invalidEmail => 'Format email tidak valid';

  @override
  String get invalidName => 'Nama 2–40 karakter';

  @override
  String numberRange(int min, int max) {
    return 'Isi angka $min–$max';
  }

  @override
  String get accountCreatedTitle => 'Akun dibuat';

  @override
  String accountCreatedBody(String name) {
    return 'Akun $name siap dipakai. Password sementara hanya ditampilkan sekali ini.';
  }

  @override
  String get temporaryPassword => 'Password sementara';

  @override
  String get accountCreatedSteps =>
      'Serahkan email dan password ini lewat jalur aman. Saat login pertama, CS wajib mengganti password lalu mendaftarkan 2FA (TOTP).';

  @override
  String get topicsTitle => 'Topik bantuan';

  @override
  String get topicsDescription =>
      'Topik yang dipilih nasabah saat membuat tiket, beserta prioritas default dan skill CS yang dibutuhkan.';

  @override
  String get addTopic => 'Tambah topik';

  @override
  String get colOrder => 'Urutan';

  @override
  String get colCode => 'Kode';

  @override
  String get colName => 'Nama';

  @override
  String get colSkill => 'Skill';

  @override
  String get colDefaultPriority => 'Prioritas default';

  @override
  String get colHelpLink => 'Tautan bantuan';

  @override
  String editTopicTitle(String name) {
    return 'Ubah topik $name';
  }

  @override
  String get topicCode => 'Kode';

  @override
  String get topicCodeHint =>
      'Huruf kecil, angka, atau garis bawah. Tidak bisa diubah.';

  @override
  String get invalidTopicCode => 'Kode 2–32 karakter, diawali huruf kecil';

  @override
  String get topicNameId => 'Nama (Indonesia)';

  @override
  String get topicNameEn => 'Nama (Inggris)';

  @override
  String get topicSkill => 'Skill CS';

  @override
  String get defaultPriority => 'Prioritas default';

  @override
  String get helpUrl => 'Tautan bantuan (opsional)';

  @override
  String get helpUrlHint => 'https:// ke situs bantuan resmi';

  @override
  String get sortOrder => 'Urutan tampil (0–999)';

  @override
  String get topicActive => 'Tampilkan ke nasabah';

  @override
  String get quickRepliesTitle => 'Quick reply global';

  @override
  String get quickRepliesDescription =>
      'Balasan siap pakai untuk semua CS. Ketik / di kolom balas untuk memakainya.';

  @override
  String get addQuickReply => 'Tambah quick reply';

  @override
  String get colShortcut => 'Pintasan';

  @override
  String get colTitle => 'Judul';

  @override
  String get colLanguage => 'Bahasa';

  @override
  String get colUpdated => 'Diubah';

  @override
  String get editQuickReplyTitle => 'Ubah quick reply';

  @override
  String get shortcut => 'Pintasan';

  @override
  String get shortcutHint => 'Huruf kecil, angka, - atau _ (2–32)';

  @override
  String get invalidShortcut =>
      'Pintasan 2–32 karakter: huruf kecil, angka, - atau _';

  @override
  String get replyTitle => 'Judul';

  @override
  String get replyBody => 'Isi balasan';

  @override
  String get variables => 'Variabel';

  @override
  String get languageId => 'Indonesia';

  @override
  String get languageEn => 'Inggris';

  @override
  String get languageLabel => 'Bahasa';

  @override
  String get requiredField => 'Wajib diisi';

  @override
  String get hoursTitle => 'Jam layanan & hari libur';

  @override
  String get hoursDescription =>
      'Jam layanan CS dalam WIB. Di luar jam layanan, nasabah menerima pesan otomatis dan CS membalas mulai jam buka berikutnya.';

  @override
  String get serviceHours => 'Jam layanan (WIB)';

  @override
  String get dayOpen => 'Buka';

  @override
  String get dayClosed => 'Tutup';

  @override
  String get opensAt => 'Jam buka';

  @override
  String get closesAt => 'Jam tutup';

  @override
  String get hoursInvalid =>
      'Format HH:MM, jam buka sebelum jam tutup (tutup boleh 24:00)';

  @override
  String get saveHours => 'Simpan jam layanan';

  @override
  String holidaysTitle(String year) {
    return 'Hari libur $year';
  }

  @override
  String get holidaysHint =>
      'Libur nasional dan cuti bersama: layanan CS tutup. Libur bursa: pasar tutup, layanan CS tetap buka.';

  @override
  String get addHoliday => 'Tambah hari libur';

  @override
  String get holidayNational => 'Libur nasional';

  @override
  String get holidayCollective => 'Cuti bersama';

  @override
  String get holidayExchange => 'Libur bursa';

  @override
  String get holidayName => 'Nama hari libur';

  @override
  String get holidayDate => 'Tanggal';

  @override
  String get holidayKind => 'Jenis';

  @override
  String get deleteHolidayTitle => 'Hapus hari libur?';

  @override
  String deleteHolidayBody(String name, String date) {
    return '$name ($date) dihapus dari kalender layanan.';
  }

  @override
  String get noHolidays => 'Belum ada hari libur di tahun ini.';

  @override
  String get previousYear => 'Tahun sebelumnya';

  @override
  String get nextYear => 'Tahun berikutnya';

  @override
  String get messagesTitle => 'Pesan otomatis';

  @override
  String get messagesDescription =>
      'Pesan sistem yang dikirim ke nasabah. Variabel dalam kurung kurawal diisi otomatis; hanya variabel yang sudah ada yang boleh dipakai.';

  @override
  String get messageId => 'Bahasa Indonesia';

  @override
  String get messageEn => 'Bahasa Inggris';

  @override
  String get noVariables => 'Tanpa variabel';

  @override
  String lastChangedBy(String time, String name) {
    return 'Terakhir diubah $time oleh $name';
  }

  @override
  String lastChanged(String time) {
    return 'Terakhir diubah $time';
  }

  @override
  String get assignmentTitle => 'Penugasan & alert';

  @override
  String get assignmentDescription =>
      'Atur cara tiket dibagikan ke CS dan kapan supervisor mendapat peringatan.';

  @override
  String get assignmentMode => 'Mode penugasan';

  @override
  String get modeClaim => 'Ambil tiket (default)';

  @override
  String get modeClaimHint =>
      'CS memilih dan mengambil sendiri tiket dari daftar Terbuka.';

  @override
  String get modeAuto => 'Penugasan otomatis';

  @override
  String get modeAutoHint =>
      'Sistem menugaskan tiket terbuka ke CS online yang sesuai skill dan masih punya slot.';

  @override
  String get autoRelease => 'Lepas otomatis bila pemilik offline';

  @override
  String get autoReleaseHint =>
      'Default mati. Bila aktif, tiket milik CS yang offline lebih lama dari batas ini kembali ke antrean.';

  @override
  String get autoReleaseMinutes => 'Batas offline (menit, 1–1440)';

  @override
  String get supervisorAlerts => 'Alert supervisor';

  @override
  String get alertUnclaimed => 'Tiket belum diambil lebih dari (menit)';

  @override
  String get alertP1 => 'Tiket P1 belum diambil lebih dari (menit)';

  @override
  String alertOverdueTitle(String priority, int minutes) {
    return 'Tiket $priority belum diambil $minutes menit';
  }

  @override
  String transferCancelled(String ticket, String reason) {
    return 'Transfer tiket $ticket dibatalkan: $reason';
  }

  @override
  String get changePasswordTitle => 'Ganti password';

  @override
  String get changePasswordSubtitle =>
      'Akun Anda masih memakai password sementara. Buat password baru sebelum mulai bekerja.';

  @override
  String get newPassword => 'Password baru';

  @override
  String get confirmPassword => 'Ulangi password baru';

  @override
  String get passwordRules =>
      'Minimal 12 karakter. Jangan pakai ulang password akun lain.';

  @override
  String get passwordTooShort => 'Password minimal 12 karakter';

  @override
  String get passwordMismatch => 'Password tidak sama';

  @override
  String get savePassword => 'Simpan password';

  @override
  String get errorSamePassword =>
      'Password baru harus berbeda dari password sementara';

  @override
  String get errorWeakPassword =>
      'Password terlalu lemah, pakai kombinasi yang lebih panjang';

  @override
  String get noConsoleAccess =>
      'Peran akun ini belum punya menu di web CS. Hubungi admin CS.';

  @override
  String returnedTicket(String reason) {
    return 'Dikembalikan ke antrean: $reason';
  }
}
