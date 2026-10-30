import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'console_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ConsoleLocalizations
/// returned by `ConsoleLocalizations.of(context)`.
///
/// Applications need to include `ConsoleLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/console_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ConsoleLocalizations.localizationsDelegates,
///   supportedLocales: ConsoleLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ConsoleLocalizations.supportedLocales
/// property.
abstract class ConsoleLocalizations {
  ConsoleLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ConsoleLocalizations of(BuildContext context) {
    return Localizations.of<ConsoleLocalizations>(
      context,
      ConsoleLocalizations,
    )!;
  }

  static const LocalizationsDelegate<ConsoleLocalizations> delegate =
      _ConsoleLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('id')];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'CS Console'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk ke CS Console'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Khusus CS dan supervisor OLT. Akses hanya lewat jaringan internal (VPN).'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In id, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan password'**
  String get hidePassword;

  /// No description provided for @signIn.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get signOut;

  /// No description provided for @useOtherAccount.
  ///
  /// In id, this message translates to:
  /// **'Pakai akun lain'**
  String get useOtherAccount;

  /// No description provided for @totpTitle.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi dua langkah'**
  String get totpTitle;

  /// No description provided for @totpHint.
  ///
  /// In id, this message translates to:
  /// **'Masukkan 6 digit kode dari aplikasi authenticator Anda.'**
  String get totpHint;

  /// No description provided for @totpCode.
  ///
  /// In id, this message translates to:
  /// **'Kode 6 digit'**
  String get totpCode;

  /// No description provided for @verify.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi'**
  String get verify;

  /// No description provided for @enrollTitle.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan verifikasi dua langkah'**
  String get enrollTitle;

  /// No description provided for @enrollHint.
  ///
  /// In id, this message translates to:
  /// **'Akun CS wajib memakai aplikasi authenticator. Pindai kode QR ini atau masukkan kunci di bawah secara manual, lalu masukkan kode 6 digit yang muncul.'**
  String get enrollHint;

  /// No description provided for @enrollKey.
  ///
  /// In id, this message translates to:
  /// **'Kunci manual'**
  String get enrollKey;

  /// No description provided for @enrollActivate.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan & masuk'**
  String get enrollActivate;

  /// No description provided for @copy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get copy;

  /// No description provided for @signedOutIdle.
  ///
  /// In id, this message translates to:
  /// **'Anda keluar otomatis karena tidak aktif {minutes} menit.'**
  String signedOutIdle(int minutes);

  /// No description provided for @signedOutExpired.
  ///
  /// In id, this message translates to:
  /// **'Sesi berakhir. Silakan masuk lagi.'**
  String get signedOutExpired;

  /// No description provided for @signedOutNotStaff.
  ///
  /// In id, this message translates to:
  /// **'Akun ini bukan akun CS aktif.'**
  String get signedOutNotStaff;

  /// No description provided for @errorInvalidLogin.
  ///
  /// In id, this message translates to:
  /// **'Email atau password salah.'**
  String get errorInvalidLogin;

  /// No description provided for @errorInvalidCode.
  ///
  /// In id, this message translates to:
  /// **'Kode verifikasi salah atau kedaluwarsa. Coba kode terbaru.'**
  String get errorInvalidCode;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In id, this message translates to:
  /// **'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNetwork.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa terhubung ke server. Periksa jaringan atau VPN.'**
  String get errorNetwork;

  /// No description provided for @errorUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Layanan sedang sibuk. Coba lagi sebentar lagi.'**
  String get errorUnavailable;

  /// No description provided for @errorSecretRequestBlocked.
  ///
  /// In id, this message translates to:
  /// **'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.'**
  String get errorSecretRequestBlocked;

  /// No description provided for @errorGeneric.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan. Coba lagi.'**
  String get errorGeneric;

  /// No description provided for @idleTitle.
  ///
  /// In id, this message translates to:
  /// **'Masih di sana?'**
  String get idleTitle;

  /// No description provided for @idleBody.
  ///
  /// In id, this message translates to:
  /// **'Anda akan keluar otomatis dalam {seconds} detik karena tidak ada aktivitas.'**
  String idleBody(int seconds);

  /// No description provided for @idleStay.
  ///
  /// In id, this message translates to:
  /// **'Tetap masuk'**
  String get idleStay;

  /// No description provided for @statusOnline.
  ///
  /// In id, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusBusy.
  ///
  /// In id, this message translates to:
  /// **'Sibuk'**
  String get statusBusy;

  /// No description provided for @statusBreak.
  ///
  /// In id, this message translates to:
  /// **'Istirahat'**
  String get statusBreak;

  /// No description provided for @statusOffline.
  ///
  /// In id, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @changeStatus.
  ///
  /// In id, this message translates to:
  /// **'Ubah status'**
  String get changeStatus;

  /// No description provided for @activeTickets.
  ///
  /// In id, this message translates to:
  /// **'Tiket aktif {count}/{max}'**
  String activeTickets(int count, int max);

  /// No description provided for @activeTicketsHint.
  ///
  /// In id, this message translates to:
  /// **'Tiket yang sedang Anda tangani dibanding batas maksimal'**
  String get activeTicketsHint;

  /// No description provided for @alertsSettings.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get alertsSettings;

  /// No description provided for @alertsNewTickets.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi tiket baru'**
  String get alertsNewTickets;

  /// No description provided for @alertsAll.
  ///
  /// In id, this message translates to:
  /// **'Semua tiket baru'**
  String get alertsAll;

  /// No description provided for @alertsHighPriority.
  ///
  /// In id, this message translates to:
  /// **'Prioritas tinggi saja (P1–P2)'**
  String get alertsHighPriority;

  /// No description provided for @alertsOff.
  ///
  /// In id, this message translates to:
  /// **'Mati'**
  String get alertsOff;

  /// No description provided for @alertsAllowBrowser.
  ///
  /// In id, this message translates to:
  /// **'Izinkan notifikasi browser'**
  String get alertsAllowBrowser;

  /// No description provided for @alertsBlocked.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi browser diblokir (ubah di pengaturan browser)'**
  String get alertsBlocked;

  /// No description provided for @alertsTestSound.
  ///
  /// In id, this message translates to:
  /// **'Tes suara'**
  String get alertsTestSound;

  /// No description provided for @alertNewTicket.
  ///
  /// In id, this message translates to:
  /// **'Tiket baru'**
  String get alertNewTicket;

  /// No description provided for @alertNewUrgentTicket.
  ///
  /// In id, this message translates to:
  /// **'Tiket baru prioritas tinggi'**
  String get alertNewUrgentTicket;

  /// No description provided for @alertCustomerMessage.
  ///
  /// In id, this message translates to:
  /// **'Pesan baru dari nasabah'**
  String get alertCustomerMessage;

  /// No description provided for @alertOpenTicket.
  ///
  /// In id, this message translates to:
  /// **'Buka tiket untuk membalas'**
  String get alertOpenTicket;

  /// No description provided for @alertTransferRequest.
  ///
  /// In id, this message translates to:
  /// **'Permintaan transfer dari {name}'**
  String alertTransferRequest(String name);

  /// No description provided for @alertFakeCs.
  ///
  /// In id, this message translates to:
  /// **'Laporan CS palsu'**
  String get alertFakeCs;

  /// No description provided for @alertSecretRequest.
  ///
  /// In id, this message translates to:
  /// **'CS mencoba meminta OTP/PIN/password'**
  String get alertSecretRequest;

  /// No description provided for @account.
  ///
  /// In id, this message translates to:
  /// **'Akun'**
  String get account;

  /// No description provided for @roleAgent.
  ///
  /// In id, this message translates to:
  /// **'CS'**
  String get roleAgent;

  /// No description provided for @roleSupervisor.
  ///
  /// In id, this message translates to:
  /// **'Supervisor'**
  String get roleSupervisor;

  /// No description provided for @roleAdmin.
  ///
  /// In id, this message translates to:
  /// **'Admin CS'**
  String get roleAdmin;

  /// No description provided for @roleCompliance.
  ///
  /// In id, this message translates to:
  /// **'Kepatuhan'**
  String get roleCompliance;

  /// No description provided for @tabOpen.
  ///
  /// In id, this message translates to:
  /// **'Terbuka'**
  String get tabOpen;

  /// No description provided for @tabMine.
  ///
  /// In id, this message translates to:
  /// **'Saya'**
  String get tabMine;

  /// No description provided for @tabResolvedToday.
  ///
  /// In id, this message translates to:
  /// **'Selesai hari ini'**
  String get tabResolvedToday;

  /// No description provided for @tabAllActive.
  ///
  /// In id, this message translates to:
  /// **'Semua aktif'**
  String get tabAllActive;

  /// No description provided for @searchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari nomor tiket, nama, kode nasabah, isi pesan'**
  String get searchHint;

  /// No description provided for @filterTopic.
  ///
  /// In id, this message translates to:
  /// **'Topik'**
  String get filterTopic;

  /// No description provided for @filterPriority.
  ///
  /// In id, this message translates to:
  /// **'Prioritas'**
  String get filterPriority;

  /// No description provided for @filterFlag.
  ///
  /// In id, this message translates to:
  /// **'Tanda'**
  String get filterFlag;

  /// No description provided for @filterAll.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get filterAll;

  /// No description provided for @clearFilters.
  ///
  /// In id, this message translates to:
  /// **'Hapus filter'**
  String get clearFilters;

  /// No description provided for @flagComplaint.
  ///
  /// In id, this message translates to:
  /// **'Pengaduan'**
  String get flagComplaint;

  /// No description provided for @flagFraud.
  ///
  /// In id, this message translates to:
  /// **'Fraud'**
  String get flagFraud;

  /// No description provided for @flagVip.
  ///
  /// In id, this message translates to:
  /// **'VIP'**
  String get flagVip;

  /// No description provided for @claim.
  ///
  /// In id, this message translates to:
  /// **'Ambil'**
  String get claim;

  /// No description provided for @waiting.
  ///
  /// In id, this message translates to:
  /// **'menunggu {duration}'**
  String waiting(String duration);

  /// No description provided for @emptyOpen.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tiket terbuka. Tiket baru akan muncul di sini.'**
  String get emptyOpen;

  /// No description provided for @emptyMine.
  ///
  /// In id, this message translates to:
  /// **'Belum ada tiket yang Anda tangani.'**
  String get emptyMine;

  /// No description provided for @emptyResolved.
  ///
  /// In id, this message translates to:
  /// **'Belum ada tiket selesai hari ini.'**
  String get emptyResolved;

  /// No description provided for @emptyAllActive.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tiket yang sedang ditangani.'**
  String get emptyAllActive;

  /// No description provided for @emptySearch.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tiket yang cocok.'**
  String get emptySearch;

  /// No description provided for @handledBy.
  ///
  /// In id, this message translates to:
  /// **'Ditangani oleh {name}'**
  String handledBy(String name);

  /// No description provided for @you.
  ///
  /// In id, this message translates to:
  /// **'Anda'**
  String get you;

  /// No description provided for @transferFrom.
  ///
  /// In id, this message translates to:
  /// **'Transfer dari {name}'**
  String transferFrom(String name);

  /// No description provided for @transferWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu {name} menerima transfer'**
  String transferWaiting(String name);

  /// No description provided for @accept.
  ///
  /// In id, this message translates to:
  /// **'Terima'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In id, this message translates to:
  /// **'Tolak'**
  String get reject;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get retry;

  /// No description provided for @loadFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat data.'**
  String get loadFailed;

  /// No description provided for @offlineHint.
  ///
  /// In id, this message translates to:
  /// **'Anda Offline. Ubah status ke Online untuk mengambil tiket.'**
  String get offlineHint;

  /// No description provided for @statusOpenLabel.
  ///
  /// In id, this message translates to:
  /// **'Terbuka'**
  String get statusOpenLabel;

  /// No description provided for @statusClaimedLabel.
  ///
  /// In id, this message translates to:
  /// **'Ditangani'**
  String get statusClaimedLabel;

  /// No description provided for @statusWaitingLabel.
  ///
  /// In id, this message translates to:
  /// **'Menunggu nasabah'**
  String get statusWaitingLabel;

  /// No description provided for @statusResolvedLabel.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get statusResolvedLabel;

  /// No description provided for @statusClosedLabel.
  ///
  /// In id, this message translates to:
  /// **'Ditutup'**
  String get statusClosedLabel;

  /// No description provided for @selectTicket.
  ///
  /// In id, this message translates to:
  /// **'Pilih tiket dari daftar di kiri.'**
  String get selectTicket;

  /// No description provided for @previewBanner.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau hanya-baca. Ambil tiket ini untuk membalas.'**
  String get previewBanner;

  /// No description provided for @closedBanner.
  ///
  /// In id, this message translates to:
  /// **'Tiket sudah selesai. Pesan baru dari nasabah akan membuka tiket lagi.'**
  String get closedBanner;

  /// No description provided for @join.
  ///
  /// In id, this message translates to:
  /// **'Gabung'**
  String get join;

  /// No description provided for @moveTo.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan ke…'**
  String get moveTo;

  /// No description provided for @tabReply.
  ///
  /// In id, this message translates to:
  /// **'Balas'**
  String get tabReply;

  /// No description provided for @tabNote.
  ///
  /// In id, this message translates to:
  /// **'Catatan internal'**
  String get tabNote;

  /// No description provided for @replyHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis balasan… ketik / untuk balasan cepat'**
  String get replyHint;

  /// No description provided for @noteHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis catatan untuk sesama CS…'**
  String get noteHint;

  /// No description provided for @noteInvisible.
  ///
  /// In id, this message translates to:
  /// **'Tidak terlihat nasabah'**
  String get noteInvisible;

  /// No description provided for @send.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get send;

  /// No description provided for @saveNote.
  ///
  /// In id, this message translates to:
  /// **'Simpan catatan'**
  String get saveNote;

  /// No description provided for @noteSaved.
  ///
  /// In id, this message translates to:
  /// **'Catatan disimpan.'**
  String get noteSaved;

  /// No description provided for @quickReplies.
  ///
  /// In id, this message translates to:
  /// **'Balasan cepat'**
  String get quickReplies;

  /// No description provided for @quickRepliesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada balasan cepat yang cocok.'**
  String get quickRepliesEmpty;

  /// No description provided for @attachImage.
  ///
  /// In id, this message translates to:
  /// **'Lampirkan gambar'**
  String get attachImage;

  /// No description provided for @sendHelpLink.
  ///
  /// In id, this message translates to:
  /// **'Kirim tautan bantuan'**
  String get sendHelpLink;

  /// No description provided for @actionWait.
  ///
  /// In id, this message translates to:
  /// **'Tunggu nasabah'**
  String get actionWait;

  /// No description provided for @actionRelease.
  ///
  /// In id, this message translates to:
  /// **'Lepas'**
  String get actionRelease;

  /// No description provided for @actionTransfer.
  ///
  /// In id, this message translates to:
  /// **'Transfer'**
  String get actionTransfer;

  /// No description provided for @actionResolve.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan'**
  String get actionResolve;

  /// No description provided for @releaseTitle.
  ///
  /// In id, this message translates to:
  /// **'Lepas tiket ke antrean'**
  String get releaseTitle;

  /// No description provided for @releaseHint.
  ///
  /// In id, this message translates to:
  /// **'Tiket kembali ke tab Terbuka dan bisa diambil CS lain.'**
  String get releaseHint;

  /// No description provided for @reasonRequired.
  ///
  /// In id, this message translates to:
  /// **'Alasan (wajib)'**
  String get reasonRequired;

  /// No description provided for @releaseConfirm.
  ///
  /// In id, this message translates to:
  /// **'Lepas tiket'**
  String get releaseConfirm;

  /// No description provided for @transferTitle.
  ///
  /// In id, this message translates to:
  /// **'Transfer ke CS lain'**
  String get transferTitle;

  /// No description provided for @transferHint.
  ///
  /// In id, this message translates to:
  /// **'Tiket tetap milik Anda sampai CS tujuan menerima.'**
  String get transferHint;

  /// No description provided for @transferTo.
  ///
  /// In id, this message translates to:
  /// **'CS tujuan'**
  String get transferTo;

  /// No description provided for @transferNote.
  ///
  /// In id, this message translates to:
  /// **'Catatan serah terima'**
  String get transferNote;

  /// No description provided for @transferSend.
  ///
  /// In id, this message translates to:
  /// **'Kirim permintaan'**
  String get transferSend;

  /// No description provided for @transferNoAgents.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada CS lain yang Online dan masih punya slot.'**
  String get transferNoAgents;

  /// No description provided for @slots.
  ///
  /// In id, this message translates to:
  /// **'{count}/{max} tiket'**
  String slots(int count, int max);

  /// No description provided for @resolveTitle.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan tiket'**
  String get resolveTitle;

  /// No description provided for @resolveOutcome.
  ///
  /// In id, this message translates to:
  /// **'Hasil'**
  String get resolveOutcome;

  /// No description provided for @resolveSummary.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan singkat (5–500 karakter)'**
  String get resolveSummary;

  /// No description provided for @resolveTags.
  ///
  /// In id, this message translates to:
  /// **'Tag (opsional, pisahkan dengan koma)'**
  String get resolveTags;

  /// No description provided for @resolveConfirm.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan'**
  String get resolveConfirm;

  /// No description provided for @reassignTitle.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan tiket'**
  String get reassignTitle;

  /// No description provided for @reassignReason.
  ///
  /// In id, this message translates to:
  /// **'Alasan (wajib, dicatat di audit log)'**
  String get reassignReason;

  /// No description provided for @reassignConfirm.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan'**
  String get reassignConfirm;

  /// No description provided for @priority.
  ///
  /// In id, this message translates to:
  /// **'Prioritas'**
  String get priority;

  /// No description provided for @createdAt.
  ///
  /// In id, this message translates to:
  /// **'Dibuat {time}'**
  String createdAt(String time);

  /// No description provided for @owner.
  ///
  /// In id, this message translates to:
  /// **'Pemilik'**
  String get owner;

  /// No description provided for @complaintDue.
  ///
  /// In id, this message translates to:
  /// **'Tenggat pengaduan {date}'**
  String complaintDue(String date);

  /// No description provided for @pendingTransfer.
  ///
  /// In id, this message translates to:
  /// **'Menunggu {name} menerima transfer'**
  String pendingTransfer(String name);

  /// No description provided for @noticeClaimed.
  ///
  /// In id, this message translates to:
  /// **'Tiket diambil. Anda sekarang pemiliknya.'**
  String get noticeClaimed;

  /// No description provided for @noticeReleased.
  ///
  /// In id, this message translates to:
  /// **'Tiket dikembalikan ke antrean.'**
  String get noticeReleased;

  /// No description provided for @noticeTransferRequested.
  ///
  /// In id, this message translates to:
  /// **'Permintaan transfer dikirim. Tiket tetap milik Anda sampai diterima.'**
  String get noticeTransferRequested;

  /// No description provided for @noticeResolved.
  ///
  /// In id, this message translates to:
  /// **'Tiket diselesaikan. Nasabah diminta memberi nilai.'**
  String get noticeResolved;

  /// No description provided for @noticeWaiting.
  ///
  /// In id, this message translates to:
  /// **'Status diubah: menunggu balasan nasabah.'**
  String get noticeWaiting;

  /// No description provided for @noticeJoined.
  ///
  /// In id, this message translates to:
  /// **'Anda bergabung ke percakapan.'**
  String get noticeJoined;

  /// No description provided for @noticeReassigned.
  ///
  /// In id, this message translates to:
  /// **'Tiket dipindahkan.'**
  String get noticeReassigned;

  /// No description provided for @noticeSent.
  ///
  /// In id, this message translates to:
  /// **'Terkirim ke chat.'**
  String get noticeSent;

  /// No description provided for @noticeStale.
  ///
  /// In id, this message translates to:
  /// **'Tiket sudah berubah. Data terbaru dimuat ulang.'**
  String get noticeStale;

  /// No description provided for @transferRejected.
  ///
  /// In id, this message translates to:
  /// **'{name} menolak transfer {ticket}'**
  String transferRejected(String name, String ticket);

  /// No description provided for @transferExpired.
  ///
  /// In id, this message translates to:
  /// **'Permintaan transfer {ticket} kedaluwarsa'**
  String transferExpired(String ticket);

  /// No description provided for @showInfo.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan info nasabah'**
  String get showInfo;

  /// No description provided for @hideInfo.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan info nasabah'**
  String get hideInfo;

  /// No description provided for @customerInfo.
  ///
  /// In id, this message translates to:
  /// **'Info nasabah'**
  String get customerInfo;

  /// No description provided for @dataAfterClaim.
  ///
  /// In id, this message translates to:
  /// **'Data OLT nasabah tersedia setelah Anda mengambil tiket.'**
  String get dataAfterClaim;

  /// No description provided for @profile.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @fieldName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get fieldName;

  /// No description provided for @fieldClientCode.
  ///
  /// In id, this message translates to:
  /// **'Kode nasabah'**
  String get fieldClientCode;

  /// No description provided for @fieldSid.
  ///
  /// In id, this message translates to:
  /// **'SID'**
  String get fieldSid;

  /// No description provided for @fieldNik.
  ///
  /// In id, this message translates to:
  /// **'NIK'**
  String get fieldNik;

  /// No description provided for @fieldEmail.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPhone.
  ///
  /// In id, this message translates to:
  /// **'No. HP'**
  String get fieldPhone;

  /// No description provided for @fieldBirthDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal lahir'**
  String get fieldBirthDate;

  /// No description provided for @fieldAddress.
  ///
  /// In id, this message translates to:
  /// **'Alamat'**
  String get fieldAddress;

  /// No description provided for @fieldRdn.
  ///
  /// In id, this message translates to:
  /// **'RDN'**
  String get fieldRdn;

  /// No description provided for @fieldBankAccount.
  ///
  /// In id, this message translates to:
  /// **'Rek. penarikan'**
  String get fieldBankAccount;

  /// No description provided for @fieldAccountStatus.
  ///
  /// In id, this message translates to:
  /// **'Status akun'**
  String get fieldAccountStatus;

  /// No description provided for @fieldKycStatus.
  ///
  /// In id, this message translates to:
  /// **'Status KYC'**
  String get fieldKycStatus;

  /// No description provided for @fieldSegment.
  ///
  /// In id, this message translates to:
  /// **'Segmen'**
  String get fieldSegment;

  /// No description provided for @reveal.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan'**
  String get reveal;

  /// No description provided for @revealTitle.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan {field}'**
  String revealTitle(String field);

  /// No description provided for @revealReason.
  ///
  /// In id, this message translates to:
  /// **'Alasan membuka data'**
  String get revealReason;

  /// No description provided for @revealNote.
  ///
  /// In id, this message translates to:
  /// **'Data tampil 5 menit lalu disamarkan lagi. Akses ini tercatat di audit log.'**
  String get revealNote;

  /// No description provided for @orders.
  ///
  /// In id, this message translates to:
  /// **'Order terakhir'**
  String get orders;

  /// No description provided for @cashTransactions.
  ///
  /// In id, this message translates to:
  /// **'Transaksi dana terakhir'**
  String get cashTransactions;

  /// No description provided for @devices.
  ///
  /// In id, this message translates to:
  /// **'Perangkat & login'**
  String get devices;

  /// No description provided for @security.
  ///
  /// In id, this message translates to:
  /// **'Keamanan akun'**
  String get security;

  /// No description provided for @history.
  ///
  /// In id, this message translates to:
  /// **'Riwayat tiket'**
  String get history;

  /// No description provided for @notes.
  ///
  /// In id, this message translates to:
  /// **'Catatan internal'**
  String get notes;

  /// No description provided for @sendToChat.
  ///
  /// In id, this message translates to:
  /// **'Kirim ke chat'**
  String get sendToChat;

  /// No description provided for @noData.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada data.'**
  String get noData;

  /// No description provided for @oltUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Data OLT sedang tidak tersedia.'**
  String get oltUnavailable;

  /// No description provided for @secureAccount.
  ///
  /// In id, this message translates to:
  /// **'Amankan akun'**
  String get secureAccount;

  /// No description provided for @secureConfirm.
  ///
  /// In id, this message translates to:
  /// **'Kunci transaksi dan keluarkan semua perangkat nasabah di OLT? Nasabah akan diberi tahu di chat.'**
  String get secureConfirm;

  /// No description provided for @secureDone.
  ///
  /// In id, this message translates to:
  /// **'Akun nasabah diamankan.'**
  String get secureDone;

  /// No description provided for @secureFailed.
  ///
  /// In id, this message translates to:
  /// **'Sebagian aksi gagal. Hubungi tim OLT.'**
  String get secureFailed;

  /// No description provided for @tradingLocked.
  ///
  /// In id, this message translates to:
  /// **'Transaksi dikunci'**
  String get tradingLocked;

  /// No description provided for @accountLocked.
  ///
  /// In id, this message translates to:
  /// **'Akun dikunci'**
  String get accountLocked;

  /// No description provided for @failedLogins.
  ///
  /// In id, this message translates to:
  /// **'Gagal login 24 jam: {count}'**
  String failedLogins(int count);

  /// No description provided for @otpEnabled.
  ///
  /// In id, this message translates to:
  /// **'OTP aktif'**
  String get otpEnabled;

  /// No description provided for @suspicious.
  ///
  /// In id, this message translates to:
  /// **'Aktivitas mencurigakan'**
  String get suspicious;

  /// No description provided for @lastPasswordChange.
  ///
  /// In id, this message translates to:
  /// **'Ganti password terakhir {date}'**
  String lastPasswordChange(String date);

  /// No description provided for @yes.
  ///
  /// In id, this message translates to:
  /// **'Ya'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In id, this message translates to:
  /// **'Tidak'**
  String get no;

  /// No description provided for @sideBuy.
  ///
  /// In id, this message translates to:
  /// **'Beli'**
  String get sideBuy;

  /// No description provided for @sideSell.
  ///
  /// In id, this message translates to:
  /// **'Jual'**
  String get sideSell;

  /// No description provided for @lots.
  ///
  /// In id, this message translates to:
  /// **'{count} lot'**
  String lots(int count);

  /// No description provided for @addNote.
  ///
  /// In id, this message translates to:
  /// **'Tambah catatan'**
  String get addNote;

  /// No description provided for @notesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan.'**
  String get notesEmpty;

  /// No description provided for @noteHandover.
  ///
  /// In id, this message translates to:
  /// **'Serah terima'**
  String get noteHandover;

  /// No description provided for @orderDetail.
  ///
  /// In id, this message translates to:
  /// **'Detail order'**
  String get orderDetail;

  /// No description provided for @close.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get close;

  /// No description provided for @lastSessions.
  ///
  /// In id, this message translates to:
  /// **'Sesi aktif'**
  String get lastSessions;

  /// No description provided for @lastLogins.
  ///
  /// In id, this message translates to:
  /// **'Login terakhir'**
  String get lastLogins;

  /// No description provided for @cashDetail.
  ///
  /// In id, this message translates to:
  /// **'Detail transaksi dana'**
  String get cashDetail;

  /// No description provided for @cashKind.
  ///
  /// In id, this message translates to:
  /// **'Jenis'**
  String get cashKind;

  /// No description provided for @cashAmount.
  ///
  /// In id, this message translates to:
  /// **'Nominal'**
  String get cashAmount;

  /// No description provided for @cashBank.
  ///
  /// In id, this message translates to:
  /// **'Bank'**
  String get cashBank;

  /// No description provided for @cashBankRef.
  ///
  /// In id, this message translates to:
  /// **'Ref. bank'**
  String get cashBankRef;

  /// No description provided for @cashTime.
  ///
  /// In id, this message translates to:
  /// **'Waktu'**
  String get cashTime;

  /// No description provided for @orderStock.
  ///
  /// In id, this message translates to:
  /// **'Saham'**
  String get orderStock;

  /// No description provided for @orderSide.
  ///
  /// In id, this message translates to:
  /// **'Sisi'**
  String get orderSide;

  /// No description provided for @orderPrice.
  ///
  /// In id, this message translates to:
  /// **'Harga'**
  String get orderPrice;

  /// No description provided for @orderLot.
  ///
  /// In id, this message translates to:
  /// **'Lot'**
  String get orderLot;

  /// No description provided for @orderFilled.
  ///
  /// In id, this message translates to:
  /// **'{lot} (terisi {filled})'**
  String orderFilled(String lot, String filled);

  /// No description provided for @orderStatus.
  ///
  /// In id, this message translates to:
  /// **'Status'**
  String get orderStatus;

  /// No description provided for @orderReason.
  ///
  /// In id, this message translates to:
  /// **'Alasan'**
  String get orderReason;

  /// No description provided for @orderChannel.
  ///
  /// In id, this message translates to:
  /// **'Kanal'**
  String get orderChannel;

  /// No description provided for @refresh.
  ///
  /// In id, this message translates to:
  /// **'Muat ulang'**
  String get refresh;

  /// No description provided for @save.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get done;

  /// No description provided for @copied.
  ///
  /// In id, this message translates to:
  /// **'Disalin'**
  String get copied;

  /// No description provided for @active.
  ///
  /// In id, this message translates to:
  /// **'Aktif'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In id, this message translates to:
  /// **'Nonaktif'**
  String get inactive;

  /// No description provided for @saved.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan'**
  String get saved;

  /// No description provided for @since.
  ///
  /// In id, this message translates to:
  /// **'Sejak {time}'**
  String since(String time);

  /// No description provided for @updatedAt.
  ///
  /// In id, this message translates to:
  /// **'Diperbarui {time}'**
  String updatedAt(String time);

  /// No description provided for @navTickets.
  ///
  /// In id, this message translates to:
  /// **'Tiket'**
  String get navTickets;

  /// No description provided for @navDashboard.
  ///
  /// In id, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navReports.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get navSettings;

  /// No description provided for @navAttention.
  ///
  /// In id, this message translates to:
  /// **'{count} tiket perlu perhatian'**
  String navAttention(int count);

  /// No description provided for @dashboardTitle.
  ///
  /// In id, this message translates to:
  /// **'Dashboard supervisor'**
  String get dashboardTitle;

  /// No description provided for @dashboardStale.
  ///
  /// In id, this message translates to:
  /// **'Gagal memperbarui, data mungkin belum terbaru'**
  String get dashboardStale;

  /// No description provided for @statOpen.
  ///
  /// In id, this message translates to:
  /// **'Tiket terbuka'**
  String get statOpen;

  /// No description provided for @statLongestWait.
  ///
  /// In id, this message translates to:
  /// **'Tunggu terlama'**
  String get statLongestWait;

  /// No description provided for @statNoQueue.
  ///
  /// In id, this message translates to:
  /// **'Antrean kosong'**
  String get statNoQueue;

  /// No description provided for @statActive.
  ///
  /// In id, this message translates to:
  /// **'Sedang ditangani'**
  String get statActive;

  /// No description provided for @statResolvedToday.
  ///
  /// In id, this message translates to:
  /// **'Selesai hari ini'**
  String get statResolvedToday;

  /// No description provided for @statAgentsOnline.
  ///
  /// In id, this message translates to:
  /// **'CS online'**
  String get statAgentsOnline;

  /// No description provided for @needsAttention.
  ///
  /// In id, this message translates to:
  /// **'Perlu perhatian'**
  String get needsAttention;

  /// No description provided for @overdueTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum diambil > {minutes} menit (P1 > {p1} menit)'**
  String overdueTitle(int minutes, int p1);

  /// No description provided for @overdueEmpty.
  ///
  /// In id, this message translates to:
  /// **'Semua tiket terbuka masih dalam batas waktu.'**
  String get overdueEmpty;

  /// No description provided for @flaggedTitle.
  ///
  /// In id, this message translates to:
  /// **'Fraud / pengaduan belum diambil'**
  String get flaggedTitle;

  /// No description provided for @flaggedEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tiket fraud atau pengaduan yang menunggu.'**
  String get flaggedEmpty;

  /// No description provided for @offlineOwnedTitle.
  ///
  /// In id, this message translates to:
  /// **'Milik CS yang offline'**
  String get offlineOwnedTitle;

  /// No description provided for @offlineOwnedEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tiket milik CS yang sedang offline.'**
  String get offlineOwnedEmpty;

  /// No description provided for @moreTickets.
  ///
  /// In id, this message translates to:
  /// **'+{count} tiket lainnya'**
  String moreTickets(int count);

  /// No description provided for @ownerOffline.
  ///
  /// In id, this message translates to:
  /// **'{name} offline'**
  String ownerOffline(String name);

  /// No description provided for @agentsToday.
  ///
  /// In id, this message translates to:
  /// **'Status CS hari ini'**
  String get agentsToday;

  /// No description provided for @noAgents.
  ///
  /// In id, this message translates to:
  /// **'Belum ada akun CS.'**
  String get noAgents;

  /// No description provided for @colAgent.
  ///
  /// In id, this message translates to:
  /// **'CS'**
  String get colAgent;

  /// No description provided for @colStatus.
  ///
  /// In id, this message translates to:
  /// **'Status'**
  String get colStatus;

  /// No description provided for @colActiveTickets.
  ///
  /// In id, this message translates to:
  /// **'Tiket aktif'**
  String get colActiveTickets;

  /// No description provided for @colResolvedToday.
  ///
  /// In id, this message translates to:
  /// **'Selesai hari ini'**
  String get colResolvedToday;

  /// No description provided for @colStatusSince.
  ///
  /// In id, this message translates to:
  /// **'Status sejak'**
  String get colStatusSince;

  /// No description provided for @connectionLostHint.
  ///
  /// In id, this message translates to:
  /// **'Web CS tidak mengirim heartbeat, kemungkinan koneksi terputus'**
  String get connectionLostHint;

  /// No description provided for @reportsTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get reportsTitle;

  /// No description provided for @rangeToday.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get rangeToday;

  /// No description provided for @rangeWeek.
  ///
  /// In id, this message translates to:
  /// **'7 hari'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In id, this message translates to:
  /// **'30 hari'**
  String get rangeMonth;

  /// No description provided for @rangeCustom.
  ///
  /// In id, this message translates to:
  /// **'Pilih tanggal'**
  String get rangeCustom;

  /// No description provided for @rangePickerTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih rentang laporan'**
  String get rangePickerTitle;

  /// No description provided for @rangeTooLong.
  ///
  /// In id, this message translates to:
  /// **'Rentang laporan maksimal {days} hari'**
  String rangeTooLong(int days);

  /// No description provided for @exportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor CSV'**
  String get exportCsv;

  /// No description provided for @exportDaily.
  ///
  /// In id, this message translates to:
  /// **'Tiket per hari'**
  String get exportDaily;

  /// No description provided for @exportAgents.
  ///
  /// In id, this message translates to:
  /// **'Per CS'**
  String get exportAgents;

  /// No description provided for @exportTopics.
  ///
  /// In id, this message translates to:
  /// **'Topik'**
  String get exportTopics;

  /// No description provided for @reportCreated.
  ///
  /// In id, this message translates to:
  /// **'Tiket masuk'**
  String get reportCreated;

  /// No description provided for @reportResolved.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get reportResolved;

  /// No description provided for @percentOfTickets.
  ///
  /// In id, this message translates to:
  /// **'{percent}% dari tiket masuk'**
  String percentOfTickets(int percent);

  /// No description provided for @reportClaimTime.
  ///
  /// In id, this message translates to:
  /// **'Rata-rata sampai diambil'**
  String get reportClaimTime;

  /// No description provided for @reportFirstResponse.
  ///
  /// In id, this message translates to:
  /// **'Respons pertama'**
  String get reportFirstResponse;

  /// No description provided for @reportDuration.
  ///
  /// In id, this message translates to:
  /// **'Durasi sampai selesai'**
  String get reportDuration;

  /// No description provided for @reportAvgRating.
  ///
  /// In id, this message translates to:
  /// **'Rating rata-rata'**
  String get reportAvgRating;

  /// No description provided for @ratingCount.
  ///
  /// In id, this message translates to:
  /// **'{count} penilaian'**
  String ratingCount(int count);

  /// No description provided for @reportPerDay.
  ///
  /// In id, this message translates to:
  /// **'Tiket per hari'**
  String get reportPerDay;

  /// No description provided for @reportDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get reportDate;

  /// No description provided for @reportEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data pada rentang ini.'**
  String get reportEmpty;

  /// No description provided for @reportPerAgent.
  ///
  /// In id, this message translates to:
  /// **'Per CS'**
  String get reportPerAgent;

  /// No description provided for @reportAgent.
  ///
  /// In id, this message translates to:
  /// **'CS'**
  String get reportAgent;

  /// No description provided for @reportAgentCode.
  ///
  /// In id, this message translates to:
  /// **'Kode CS'**
  String get reportAgentCode;

  /// No description provided for @reportHandled.
  ///
  /// In id, this message translates to:
  /// **'Ditangani'**
  String get reportHandled;

  /// No description provided for @reportTopTopics.
  ///
  /// In id, this message translates to:
  /// **'Topik terbanyak'**
  String get reportTopTopics;

  /// No description provided for @reportTopic.
  ///
  /// In id, this message translates to:
  /// **'Topik'**
  String get reportTopic;

  /// No description provided for @reportTopicCode.
  ///
  /// In id, this message translates to:
  /// **'Kode topik'**
  String get reportTopicCode;

  /// No description provided for @reportCount.
  ///
  /// In id, this message translates to:
  /// **'Jumlah'**
  String get reportCount;

  /// No description provided for @reportShare.
  ///
  /// In id, this message translates to:
  /// **'Porsi'**
  String get reportShare;

  /// No description provided for @reportClaimMinutes.
  ///
  /// In id, this message translates to:
  /// **'Rata-rata menit sampai diambil'**
  String get reportClaimMinutes;

  /// No description provided for @reportFirstResponseMinutes.
  ///
  /// In id, this message translates to:
  /// **'Rata-rata menit respons pertama'**
  String get reportFirstResponseMinutes;

  /// No description provided for @reportResolutionMinutes.
  ///
  /// In id, this message translates to:
  /// **'Rata-rata menit sampai selesai'**
  String get reportResolutionMinutes;

  /// No description provided for @reportRatings.
  ///
  /// In id, this message translates to:
  /// **'Jumlah penilaian'**
  String get reportRatings;

  /// No description provided for @reportTotal.
  ///
  /// In id, this message translates to:
  /// **'Total'**
  String get reportTotal;

  /// No description provided for @settingsTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTitle;

  /// No description provided for @menuAccounts.
  ///
  /// In id, this message translates to:
  /// **'Akun CS'**
  String get menuAccounts;

  /// No description provided for @menuTopics.
  ///
  /// In id, this message translates to:
  /// **'Topik'**
  String get menuTopics;

  /// No description provided for @menuQuickReplies.
  ///
  /// In id, this message translates to:
  /// **'Quick reply'**
  String get menuQuickReplies;

  /// No description provided for @menuHours.
  ///
  /// In id, this message translates to:
  /// **'Jam layanan & libur'**
  String get menuHours;

  /// No description provided for @menuMessages.
  ///
  /// In id, this message translates to:
  /// **'Pesan otomatis'**
  String get menuMessages;

  /// No description provided for @menuAssignment.
  ///
  /// In id, this message translates to:
  /// **'Penugasan & alert'**
  String get menuAssignment;

  /// No description provided for @accountsTitle.
  ///
  /// In id, this message translates to:
  /// **'Akun CS'**
  String get accountsTitle;

  /// No description provided for @accountsDescription.
  ///
  /// In id, this message translates to:
  /// **'Tambah akun, atur peran dan batas tiket aktif, atau nonaktifkan akun. Akun yang dinonaktifkan langsung tidak bisa login, dan tiket aktifnya kembali ke antrean dengan tanda.'**
  String get accountsDescription;

  /// No description provided for @addAccount.
  ///
  /// In id, this message translates to:
  /// **'Tambah akun'**
  String get addAccount;

  /// No description provided for @colRoles.
  ///
  /// In id, this message translates to:
  /// **'Peran'**
  String get colRoles;

  /// No description provided for @colTeam.
  ///
  /// In id, this message translates to:
  /// **'Tim'**
  String get colTeam;

  /// No description provided for @colTicketLimit.
  ///
  /// In id, this message translates to:
  /// **'Batas tiket'**
  String get colTicketLimit;

  /// No description provided for @colTwoFactor.
  ///
  /// In id, this message translates to:
  /// **'2FA'**
  String get colTwoFactor;

  /// No description provided for @twoFactorOn.
  ///
  /// In id, this message translates to:
  /// **'TOTP aktif'**
  String get twoFactorOn;

  /// No description provided for @twoFactorPending.
  ///
  /// In id, this message translates to:
  /// **'Belum daftar'**
  String get twoFactorPending;

  /// No description provided for @disabledSince.
  ///
  /// In id, this message translates to:
  /// **'Dinonaktifkan {time}'**
  String disabledSince(String time);

  /// No description provided for @accountDisabled.
  ///
  /// In id, this message translates to:
  /// **'Nonaktif'**
  String get accountDisabled;

  /// No description provided for @addAccountTitle.
  ///
  /// In id, this message translates to:
  /// **'Tambah akun CS'**
  String get addAccountTitle;

  /// No description provided for @editAccountTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah akun {name}'**
  String editAccountTitle(String name);

  /// No description provided for @displayName.
  ///
  /// In id, this message translates to:
  /// **'Nama tampilan'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In id, this message translates to:
  /// **'Terlihat oleh nasabah, 2–40 karakter'**
  String get displayNameHint;

  /// No description provided for @staffEmailHint.
  ///
  /// In id, this message translates to:
  /// **'Email kerja untuk login web CS'**
  String get staffEmailHint;

  /// No description provided for @rolesLabel.
  ///
  /// In id, this message translates to:
  /// **'Peran'**
  String get rolesLabel;

  /// No description provided for @teamLabel.
  ///
  /// In id, this message translates to:
  /// **'Tim'**
  String get teamLabel;

  /// No description provided for @ticketLimitLabel.
  ///
  /// In id, this message translates to:
  /// **'Batas tiket aktif (1–20)'**
  String get ticketLimitLabel;

  /// No description provided for @accountActive.
  ///
  /// In id, this message translates to:
  /// **'Akun aktif'**
  String get accountActive;

  /// No description provided for @disableWarning.
  ///
  /// In id, this message translates to:
  /// **'Akun ini langsung tidak bisa login. {count} tiket aktifnya kembali ke antrean dengan tanda \"Akun CS dinonaktifkan\".'**
  String disableWarning(int count);

  /// No description provided for @selfLocked.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak bisa menonaktifkan atau melepas peran admin akun sendiri.'**
  String get selfLocked;

  /// No description provided for @createAccount.
  ///
  /// In id, this message translates to:
  /// **'Buat akun'**
  String get createAccount;

  /// No description provided for @rolesRequired.
  ///
  /// In id, this message translates to:
  /// **'Pilih minimal satu peran'**
  String get rolesRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In id, this message translates to:
  /// **'Format email tidak valid'**
  String get invalidEmail;

  /// No description provided for @invalidName.
  ///
  /// In id, this message translates to:
  /// **'Nama 2–40 karakter'**
  String get invalidName;

  /// No description provided for @numberRange.
  ///
  /// In id, this message translates to:
  /// **'Isi angka {min}–{max}'**
  String numberRange(int min, int max);

  /// No description provided for @accountCreatedTitle.
  ///
  /// In id, this message translates to:
  /// **'Akun dibuat'**
  String get accountCreatedTitle;

  /// No description provided for @accountCreatedBody.
  ///
  /// In id, this message translates to:
  /// **'Akun {name} siap dipakai. Password sementara hanya ditampilkan sekali ini.'**
  String accountCreatedBody(String name);

  /// No description provided for @temporaryPassword.
  ///
  /// In id, this message translates to:
  /// **'Password sementara'**
  String get temporaryPassword;

  /// No description provided for @accountCreatedSteps.
  ///
  /// In id, this message translates to:
  /// **'Serahkan email dan password ini lewat jalur aman. Saat login pertama, CS wajib mengganti password lalu mendaftarkan 2FA (TOTP).'**
  String get accountCreatedSteps;

  /// No description provided for @topicsTitle.
  ///
  /// In id, this message translates to:
  /// **'Topik bantuan'**
  String get topicsTitle;

  /// No description provided for @topicsDescription.
  ///
  /// In id, this message translates to:
  /// **'Topik yang dipilih nasabah saat membuat tiket, beserta prioritas default dan skill CS yang dibutuhkan.'**
  String get topicsDescription;

  /// No description provided for @addTopic.
  ///
  /// In id, this message translates to:
  /// **'Tambah topik'**
  String get addTopic;

  /// No description provided for @colOrder.
  ///
  /// In id, this message translates to:
  /// **'Urutan'**
  String get colOrder;

  /// No description provided for @colCode.
  ///
  /// In id, this message translates to:
  /// **'Kode'**
  String get colCode;

  /// No description provided for @colName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get colName;

  /// No description provided for @colSkill.
  ///
  /// In id, this message translates to:
  /// **'Skill'**
  String get colSkill;

  /// No description provided for @colDefaultPriority.
  ///
  /// In id, this message translates to:
  /// **'Prioritas default'**
  String get colDefaultPriority;

  /// No description provided for @colHelpLink.
  ///
  /// In id, this message translates to:
  /// **'Tautan bantuan'**
  String get colHelpLink;

  /// No description provided for @editTopicTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah topik {name}'**
  String editTopicTitle(String name);

  /// No description provided for @topicCode.
  ///
  /// In id, this message translates to:
  /// **'Kode'**
  String get topicCode;

  /// No description provided for @topicCodeHint.
  ///
  /// In id, this message translates to:
  /// **'Huruf kecil, angka, atau garis bawah. Tidak bisa diubah.'**
  String get topicCodeHint;

  /// No description provided for @invalidTopicCode.
  ///
  /// In id, this message translates to:
  /// **'Kode 2–32 karakter, diawali huruf kecil'**
  String get invalidTopicCode;

  /// No description provided for @topicNameId.
  ///
  /// In id, this message translates to:
  /// **'Nama (Indonesia)'**
  String get topicNameId;

  /// No description provided for @topicNameEn.
  ///
  /// In id, this message translates to:
  /// **'Nama (Inggris)'**
  String get topicNameEn;

  /// No description provided for @topicSkill.
  ///
  /// In id, this message translates to:
  /// **'Skill CS'**
  String get topicSkill;

  /// No description provided for @defaultPriority.
  ///
  /// In id, this message translates to:
  /// **'Prioritas default'**
  String get defaultPriority;

  /// No description provided for @helpUrl.
  ///
  /// In id, this message translates to:
  /// **'Tautan bantuan (opsional)'**
  String get helpUrl;

  /// No description provided for @helpUrlHint.
  ///
  /// In id, this message translates to:
  /// **'https:// ke situs bantuan resmi'**
  String get helpUrlHint;

  /// No description provided for @sortOrder.
  ///
  /// In id, this message translates to:
  /// **'Urutan tampil (0–999)'**
  String get sortOrder;

  /// No description provided for @topicActive.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan ke nasabah'**
  String get topicActive;

  /// No description provided for @quickRepliesTitle.
  ///
  /// In id, this message translates to:
  /// **'Quick reply global'**
  String get quickRepliesTitle;

  /// No description provided for @quickRepliesDescription.
  ///
  /// In id, this message translates to:
  /// **'Balasan siap pakai untuk semua CS. Ketik / di kolom balas untuk memakainya.'**
  String get quickRepliesDescription;

  /// No description provided for @addQuickReply.
  ///
  /// In id, this message translates to:
  /// **'Tambah quick reply'**
  String get addQuickReply;

  /// No description provided for @colShortcut.
  ///
  /// In id, this message translates to:
  /// **'Pintasan'**
  String get colShortcut;

  /// No description provided for @colTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get colTitle;

  /// No description provided for @colLanguage.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get colLanguage;

  /// No description provided for @colUpdated.
  ///
  /// In id, this message translates to:
  /// **'Diubah'**
  String get colUpdated;

  /// No description provided for @editQuickReplyTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah quick reply'**
  String get editQuickReplyTitle;

  /// No description provided for @shortcut.
  ///
  /// In id, this message translates to:
  /// **'Pintasan'**
  String get shortcut;

  /// No description provided for @shortcutHint.
  ///
  /// In id, this message translates to:
  /// **'Huruf kecil, angka, - atau _ (2–32)'**
  String get shortcutHint;

  /// No description provided for @invalidShortcut.
  ///
  /// In id, this message translates to:
  /// **'Pintasan 2–32 karakter: huruf kecil, angka, - atau _'**
  String get invalidShortcut;

  /// No description provided for @replyTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get replyTitle;

  /// No description provided for @replyBody.
  ///
  /// In id, this message translates to:
  /// **'Isi balasan'**
  String get replyBody;

  /// No description provided for @variables.
  ///
  /// In id, this message translates to:
  /// **'Variabel'**
  String get variables;

  /// No description provided for @languageId.
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get languageId;

  /// No description provided for @languageEn.
  ///
  /// In id, this message translates to:
  /// **'Inggris'**
  String get languageEn;

  /// No description provided for @languageLabel.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get languageLabel;

  /// No description provided for @requiredField.
  ///
  /// In id, this message translates to:
  /// **'Wajib diisi'**
  String get requiredField;

  /// No description provided for @hoursTitle.
  ///
  /// In id, this message translates to:
  /// **'Jam layanan & hari libur'**
  String get hoursTitle;

  /// No description provided for @hoursDescription.
  ///
  /// In id, this message translates to:
  /// **'Jam layanan CS dalam WIB. Di luar jam layanan, nasabah menerima pesan otomatis dan CS membalas mulai jam buka berikutnya.'**
  String get hoursDescription;

  /// No description provided for @serviceHours.
  ///
  /// In id, this message translates to:
  /// **'Jam layanan (WIB)'**
  String get serviceHours;

  /// No description provided for @dayOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get dayOpen;

  /// No description provided for @dayClosed.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get dayClosed;

  /// No description provided for @opensAt.
  ///
  /// In id, this message translates to:
  /// **'Jam buka'**
  String get opensAt;

  /// No description provided for @closesAt.
  ///
  /// In id, this message translates to:
  /// **'Jam tutup'**
  String get closesAt;

  /// No description provided for @hoursInvalid.
  ///
  /// In id, this message translates to:
  /// **'Format HH:MM, jam buka sebelum jam tutup (tutup boleh 24:00)'**
  String get hoursInvalid;

  /// No description provided for @saveHours.
  ///
  /// In id, this message translates to:
  /// **'Simpan jam layanan'**
  String get saveHours;

  /// No description provided for @holidaysTitle.
  ///
  /// In id, this message translates to:
  /// **'Hari libur {year}'**
  String holidaysTitle(String year);

  /// No description provided for @holidaysHint.
  ///
  /// In id, this message translates to:
  /// **'Libur nasional dan cuti bersama: layanan CS tutup. Libur bursa: pasar tutup, layanan CS tetap buka.'**
  String get holidaysHint;

  /// No description provided for @addHoliday.
  ///
  /// In id, this message translates to:
  /// **'Tambah hari libur'**
  String get addHoliday;

  /// No description provided for @holidayNational.
  ///
  /// In id, this message translates to:
  /// **'Libur nasional'**
  String get holidayNational;

  /// No description provided for @holidayCollective.
  ///
  /// In id, this message translates to:
  /// **'Cuti bersama'**
  String get holidayCollective;

  /// No description provided for @holidayExchange.
  ///
  /// In id, this message translates to:
  /// **'Libur bursa'**
  String get holidayExchange;

  /// No description provided for @holidayName.
  ///
  /// In id, this message translates to:
  /// **'Nama hari libur'**
  String get holidayName;

  /// No description provided for @holidayDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get holidayDate;

  /// No description provided for @holidayKind.
  ///
  /// In id, this message translates to:
  /// **'Jenis'**
  String get holidayKind;

  /// No description provided for @deleteHolidayTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus hari libur?'**
  String get deleteHolidayTitle;

  /// No description provided for @deleteHolidayBody.
  ///
  /// In id, this message translates to:
  /// **'{name} ({date}) dihapus dari kalender layanan.'**
  String deleteHolidayBody(String name, String date);

  /// No description provided for @noHolidays.
  ///
  /// In id, this message translates to:
  /// **'Belum ada hari libur di tahun ini.'**
  String get noHolidays;

  /// No description provided for @previousYear.
  ///
  /// In id, this message translates to:
  /// **'Tahun sebelumnya'**
  String get previousYear;

  /// No description provided for @nextYear.
  ///
  /// In id, this message translates to:
  /// **'Tahun berikutnya'**
  String get nextYear;

  /// No description provided for @messagesTitle.
  ///
  /// In id, this message translates to:
  /// **'Pesan otomatis'**
  String get messagesTitle;

  /// No description provided for @messagesDescription.
  ///
  /// In id, this message translates to:
  /// **'Pesan sistem yang dikirim ke nasabah. Variabel dalam kurung kurawal diisi otomatis; hanya variabel yang sudah ada yang boleh dipakai.'**
  String get messagesDescription;

  /// No description provided for @messageId.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get messageId;

  /// No description provided for @messageEn.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Inggris'**
  String get messageEn;

  /// No description provided for @noVariables.
  ///
  /// In id, this message translates to:
  /// **'Tanpa variabel'**
  String get noVariables;

  /// No description provided for @lastChangedBy.
  ///
  /// In id, this message translates to:
  /// **'Terakhir diubah {time} oleh {name}'**
  String lastChangedBy(String time, String name);

  /// No description provided for @lastChanged.
  ///
  /// In id, this message translates to:
  /// **'Terakhir diubah {time}'**
  String lastChanged(String time);

  /// No description provided for @assignmentTitle.
  ///
  /// In id, this message translates to:
  /// **'Penugasan & alert'**
  String get assignmentTitle;

  /// No description provided for @assignmentDescription.
  ///
  /// In id, this message translates to:
  /// **'Atur cara tiket dibagikan ke CS dan kapan supervisor mendapat peringatan.'**
  String get assignmentDescription;

  /// No description provided for @assignmentMode.
  ///
  /// In id, this message translates to:
  /// **'Mode penugasan'**
  String get assignmentMode;

  /// No description provided for @modeClaim.
  ///
  /// In id, this message translates to:
  /// **'Ambil tiket (default)'**
  String get modeClaim;

  /// No description provided for @modeClaimHint.
  ///
  /// In id, this message translates to:
  /// **'CS memilih dan mengambil sendiri tiket dari daftar Terbuka.'**
  String get modeClaimHint;

  /// No description provided for @modeAuto.
  ///
  /// In id, this message translates to:
  /// **'Penugasan otomatis'**
  String get modeAuto;

  /// No description provided for @modeAutoHint.
  ///
  /// In id, this message translates to:
  /// **'Sistem menugaskan tiket terbuka ke CS online yang sesuai skill dan masih punya slot.'**
  String get modeAutoHint;

  /// No description provided for @autoRelease.
  ///
  /// In id, this message translates to:
  /// **'Lepas otomatis bila pemilik offline'**
  String get autoRelease;

  /// No description provided for @autoReleaseHint.
  ///
  /// In id, this message translates to:
  /// **'Default mati. Bila aktif, tiket milik CS yang offline lebih lama dari batas ini kembali ke antrean.'**
  String get autoReleaseHint;

  /// No description provided for @autoReleaseMinutes.
  ///
  /// In id, this message translates to:
  /// **'Batas offline (menit, 1–1440)'**
  String get autoReleaseMinutes;

  /// No description provided for @supervisorAlerts.
  ///
  /// In id, this message translates to:
  /// **'Alert supervisor'**
  String get supervisorAlerts;

  /// No description provided for @alertUnclaimed.
  ///
  /// In id, this message translates to:
  /// **'Tiket belum diambil lebih dari (menit)'**
  String get alertUnclaimed;

  /// No description provided for @alertP1.
  ///
  /// In id, this message translates to:
  /// **'Tiket P1 belum diambil lebih dari (menit)'**
  String get alertP1;

  /// No description provided for @alertOverdueTitle.
  ///
  /// In id, this message translates to:
  /// **'Tiket {priority} belum diambil {minutes} menit'**
  String alertOverdueTitle(String priority, int minutes);

  /// No description provided for @transferCancelled.
  ///
  /// In id, this message translates to:
  /// **'Transfer tiket {ticket} dibatalkan: {reason}'**
  String transferCancelled(String ticket, String reason);

  /// No description provided for @changePasswordTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Akun Anda masih memakai password sementara. Buat password baru sebelum mulai bekerja.'**
  String get changePasswordSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In id, this message translates to:
  /// **'Password baru'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In id, this message translates to:
  /// **'Ulangi password baru'**
  String get confirmPassword;

  /// No description provided for @passwordRules.
  ///
  /// In id, this message translates to:
  /// **'Minimal 12 karakter. Jangan pakai ulang password akun lain.'**
  String get passwordRules;

  /// No description provided for @passwordTooShort.
  ///
  /// In id, this message translates to:
  /// **'Password minimal 12 karakter'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In id, this message translates to:
  /// **'Password tidak sama'**
  String get passwordMismatch;

  /// No description provided for @savePassword.
  ///
  /// In id, this message translates to:
  /// **'Simpan password'**
  String get savePassword;

  /// No description provided for @errorSamePassword.
  ///
  /// In id, this message translates to:
  /// **'Password baru harus berbeda dari password sementara'**
  String get errorSamePassword;

  /// No description provided for @errorWeakPassword.
  ///
  /// In id, this message translates to:
  /// **'Password terlalu lemah, pakai kombinasi yang lebih panjang'**
  String get errorWeakPassword;

  /// No description provided for @noConsoleAccess.
  ///
  /// In id, this message translates to:
  /// **'Peran akun ini belum punya menu di web CS. Hubungi admin CS.'**
  String get noConsoleAccess;

  /// No description provided for @returnedTicket.
  ///
  /// In id, this message translates to:
  /// **'Dikembalikan ke antrean: {reason}'**
  String returnedTicket(String reason);
}

class _ConsoleLocalizationsDelegate
    extends LocalizationsDelegate<ConsoleLocalizations> {
  const _ConsoleLocalizationsDelegate();

  @override
  Future<ConsoleLocalizations> load(Locale locale) {
    return SynchronousFuture<ConsoleLocalizations>(
      lookupConsoleLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['id'].contains(locale.languageCode);

  @override
  bool shouldReload(_ConsoleLocalizationsDelegate old) => false;
}

ConsoleLocalizations lookupConsoleLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'id':
      return ConsoleLocalizationsId();
  }

  throw FlutterError(
    'ConsoleLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
