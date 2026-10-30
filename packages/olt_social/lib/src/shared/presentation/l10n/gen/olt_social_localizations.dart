import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'olt_social_localizations_en.dart';
import 'olt_social_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of OltSocialLocalizations
/// returned by `OltSocialLocalizations.of(context)`.
///
/// Applications need to include `OltSocialLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/olt_social_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
///   supportedLocales: OltSocialLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the OltSocialLocalizations.supportedLocales
/// property.
abstract class OltSocialLocalizations {
  OltSocialLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static OltSocialLocalizations? of(BuildContext context) {
    return Localizations.of<OltSocialLocalizations>(
      context,
      OltSocialLocalizations,
    );
  }

  static const LocalizationsDelegate<OltSocialLocalizations> delegate =
      _OltSocialLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('id'),
    Locale('en'),
  ];

  /// No description provided for @disclaimer.
  ///
  /// In id, this message translates to:
  /// **'Konten ini opini pengguna, bukan rekomendasi investasi.'**
  String get disclaimer;

  /// No description provided for @retry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get save;

  /// No description provided for @close.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get close;

  /// No description provided for @you.
  ///
  /// In id, this message translates to:
  /// **'Anda'**
  String get you;

  /// No description provided for @edited.
  ///
  /// In id, this message translates to:
  /// **'(diedit)'**
  String get edited;

  /// No description provided for @justNow.
  ///
  /// In id, this message translates to:
  /// **'baru saja'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} mnt'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} j'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} h'**
  String daysAgo(int count);

  /// No description provided for @errorNetwork.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada koneksi. Periksa jaringan Anda.'**
  String get errorNetwork;

  /// No description provided for @errorUnauthenticated.
  ///
  /// In id, this message translates to:
  /// **'Sesi berakhir. Silakan login ulang di OLT.'**
  String get errorUnauthenticated;

  /// No description provided for @errorRateLimited.
  ///
  /// In id, this message translates to:
  /// **'Terlalu cepat. Coba lagi sebentar lagi.'**
  String get errorRateLimited;

  /// No description provided for @errorContentBlocked.
  ///
  /// In id, this message translates to:
  /// **'Konten mengandung kata atau frasa yang tidak diizinkan.'**
  String get errorContentBlocked;

  /// No description provided for @errorInvalidInput.
  ///
  /// In id, this message translates to:
  /// **'Data tidak valid.'**
  String get errorInvalidInput;

  /// No description provided for @errorForbidden.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak memiliki akses untuk aksi ini.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In id, this message translates to:
  /// **'Konten tidak ditemukan atau sudah dihapus.'**
  String get errorNotFound;

  /// No description provided for @errorUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Layanan sedang tidak tersedia. Coba lagi nanti.'**
  String get errorUnavailable;

  /// No description provided for @errorUnknown.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan. Coba lagi.'**
  String get errorUnknown;

  /// No description provided for @feedLatest.
  ///
  /// In id, this message translates to:
  /// **'Terbaru'**
  String get feedLatest;

  /// No description provided for @feedFollowing.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti'**
  String get feedFollowing;

  /// No description provided for @feedEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada post. Jadilah yang pertama!'**
  String get feedEmpty;

  /// No description provided for @feedFollowingEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada post dari user yang Anda ikuti.'**
  String get feedFollowingEmpty;

  /// No description provided for @stockFeedEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada diskusi tentang \${code}.'**
  String stockFeedEmpty(String code);

  /// No description provided for @userFeedEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada post.'**
  String get userFeedEmpty;

  /// No description provided for @newPosts.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{1 post baru} other{{count} post baru}}'**
  String newPosts(int count);

  /// No description provided for @composePrompt.
  ///
  /// In id, this message translates to:
  /// **'Apa pendapat Anda tentang pasar hari ini?'**
  String get composePrompt;

  /// No description provided for @composeTitle.
  ///
  /// In id, this message translates to:
  /// **'Buat post'**
  String get composeTitle;

  /// No description provided for @composeHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis analisis Anda. Gunakan \$KODE untuk menandai saham dan @username untuk menyebut user.'**
  String get composeHint;

  /// No description provided for @composeSubmit.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get composeSubmit;

  /// No description provided for @composeCharsLeft.
  ///
  /// In id, this message translates to:
  /// **'{count} karakter tersisa'**
  String composeCharsLeft(int count);

  /// No description provided for @composeAddImage.
  ///
  /// In id, this message translates to:
  /// **'Tambah gambar'**
  String get composeAddImage;

  /// No description provided for @composeRemoveImage.
  ///
  /// In id, this message translates to:
  /// **'Hapus gambar'**
  String get composeRemoveImage;

  /// No description provided for @composeTooManyImages.
  ///
  /// In id, this message translates to:
  /// **'Maksimal 4 gambar'**
  String get composeTooManyImages;

  /// No description provided for @composeImageTooLarge.
  ///
  /// In id, this message translates to:
  /// **'Ukuran gambar maksimal 5 MB'**
  String get composeImageTooLarge;

  /// No description provided for @composePosted.
  ///
  /// In id, this message translates to:
  /// **'Post terkirim'**
  String get composePosted;

  /// No description provided for @sentimentLabel.
  ///
  /// In id, this message translates to:
  /// **'Sentimen'**
  String get sentimentLabel;

  /// No description provided for @sentimentBullish.
  ///
  /// In id, this message translates to:
  /// **'Bullish'**
  String get sentimentBullish;

  /// No description provided for @sentimentBearish.
  ///
  /// In id, this message translates to:
  /// **'Bearish'**
  String get sentimentBearish;

  /// No description provided for @sentimentNeutral.
  ///
  /// In id, this message translates to:
  /// **'Netral'**
  String get sentimentNeutral;

  /// No description provided for @sentimentNone.
  ///
  /// In id, this message translates to:
  /// **'Tanpa'**
  String get sentimentNone;

  /// No description provided for @like.
  ///
  /// In id, this message translates to:
  /// **'Suka'**
  String get like;

  /// No description provided for @unlike.
  ///
  /// In id, this message translates to:
  /// **'Batal suka'**
  String get unlike;

  /// No description provided for @comment.
  ///
  /// In id, this message translates to:
  /// **'Komentar'**
  String get comment;

  /// No description provided for @reply.
  ///
  /// In id, this message translates to:
  /// **'Balas'**
  String get reply;

  /// No description provided for @postDetail.
  ///
  /// In id, this message translates to:
  /// **'Post'**
  String get postDetail;

  /// No description provided for @postNotFound.
  ///
  /// In id, this message translates to:
  /// **'Post tidak ditemukan atau sudah dihapus.'**
  String get postNotFound;

  /// No description provided for @postDeleted.
  ///
  /// In id, this message translates to:
  /// **'Post dihapus'**
  String get postDeleted;

  /// No description provided for @deletePostConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus post ini?'**
  String get deletePostConfirm;

  /// No description provided for @deleteCommentConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus komentar ini?'**
  String get deleteCommentConfirm;

  /// No description provided for @comments.
  ///
  /// In id, this message translates to:
  /// **'Komentar'**
  String get comments;

  /// No description provided for @noComments.
  ///
  /// In id, this message translates to:
  /// **'Belum ada komentar. Mulai diskusi!'**
  String get noComments;

  /// No description provided for @writeComment.
  ///
  /// In id, this message translates to:
  /// **'Tulis komentar…'**
  String get writeComment;

  /// No description provided for @replyingTo.
  ///
  /// In id, this message translates to:
  /// **'Membalas {name}'**
  String replyingTo(String name);

  /// No description provided for @commentDeleted.
  ///
  /// In id, this message translates to:
  /// **'[komentar dihapus]'**
  String get commentDeleted;

  /// No description provided for @viewMoreReplies.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{Lihat 1 balasan lainnya} other{Lihat {count} balasan lainnya}}'**
  String viewMoreReplies(int count);

  /// No description provided for @loadMoreComments.
  ///
  /// In id, this message translates to:
  /// **'Muat komentar lainnya'**
  String get loadMoreComments;

  /// No description provided for @continueThread.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan thread'**
  String get continueThread;

  /// No description provided for @threadContext.
  ///
  /// In id, this message translates to:
  /// **'Melanjutkan thread'**
  String get threadContext;

  /// No description provided for @collapse.
  ///
  /// In id, this message translates to:
  /// **'Ciutkan'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In id, this message translates to:
  /// **'Bentangkan'**
  String get expand;

  /// No description provided for @hiddenReplies.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{1 balasan disembunyikan} other{{count} balasan disembunyikan}}'**
  String hiddenReplies(int count);

  /// No description provided for @newCommentsAvailable.
  ///
  /// In id, this message translates to:
  /// **'Ada komentar baru'**
  String get newCommentsAvailable;

  /// No description provided for @report.
  ///
  /// In id, this message translates to:
  /// **'Laporkan'**
  String get report;

  /// No description provided for @reportTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporkan konten'**
  String get reportTitle;

  /// No description provided for @reportDetailsHint.
  ///
  /// In id, this message translates to:
  /// **'Keterangan tambahan (opsional)'**
  String get reportDetailsHint;

  /// No description provided for @reportSent.
  ///
  /// In id, this message translates to:
  /// **'Laporan terkirim. Terima kasih.'**
  String get reportSent;

  /// No description provided for @reasonSpam.
  ///
  /// In id, this message translates to:
  /// **'Spam'**
  String get reasonSpam;

  /// No description provided for @reasonAbuse.
  ///
  /// In id, this message translates to:
  /// **'Pelecehan / kasar'**
  String get reasonAbuse;

  /// No description provided for @reasonScam.
  ///
  /// In id, this message translates to:
  /// **'Penipuan'**
  String get reasonScam;

  /// No description provided for @reasonPumpAndDump.
  ///
  /// In id, this message translates to:
  /// **'Ajakan goreng saham'**
  String get reasonPumpAndDump;

  /// No description provided for @reasonMisinformation.
  ///
  /// In id, this message translates to:
  /// **'Informasi menyesatkan'**
  String get reasonMisinformation;

  /// No description provided for @reasonOther.
  ///
  /// In id, this message translates to:
  /// **'Lainnya'**
  String get reasonOther;

  /// No description provided for @block.
  ///
  /// In id, this message translates to:
  /// **'Blokir'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In id, this message translates to:
  /// **'Buka blokir'**
  String get unblock;

  /// No description provided for @blockConfirm.
  ///
  /// In id, this message translates to:
  /// **'Blokir {name}? Anda tidak akan saling melihat post, komentar, dan pesan.'**
  String blockConfirm(String name);

  /// No description provided for @blocked.
  ///
  /// In id, this message translates to:
  /// **'{name} diblokir'**
  String blocked(String name);

  /// No description provided for @follow.
  ///
  /// In id, this message translates to:
  /// **'Ikuti'**
  String get follow;

  /// No description provided for @followingLabel.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti'**
  String get followingLabel;

  /// No description provided for @followers.
  ///
  /// In id, this message translates to:
  /// **'{count} pengikut'**
  String followers(int count);

  /// No description provided for @followingCount.
  ///
  /// In id, this message translates to:
  /// **'{count} mengikuti'**
  String followingCount(int count);

  /// No description provided for @postsCount.
  ///
  /// In id, this message translates to:
  /// **'{count} post'**
  String postsCount(int count);

  /// No description provided for @followsYou.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti Anda'**
  String get followsYou;

  /// No description provided for @sendMessage.
  ///
  /// In id, this message translates to:
  /// **'Kirim pesan'**
  String get sendMessage;

  /// No description provided for @editProfile.
  ///
  /// In id, this message translates to:
  /// **'Ubah profil'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In id, this message translates to:
  /// **'Nama tampilan'**
  String get displayName;

  /// No description provided for @bio.
  ///
  /// In id, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @changeAvatar.
  ///
  /// In id, this message translates to:
  /// **'Ganti foto'**
  String get changeAvatar;

  /// No description provided for @profileNotFound.
  ///
  /// In id, this message translates to:
  /// **'User tidak ditemukan.'**
  String get profileNotFound;

  /// No description provided for @watch.
  ///
  /// In id, this message translates to:
  /// **'Pantau'**
  String get watch;

  /// No description provided for @watching.
  ///
  /// In id, this message translates to:
  /// **'Dipantau'**
  String get watching;

  /// No description provided for @watchers.
  ///
  /// In id, this message translates to:
  /// **'{count} pemantau'**
  String watchers(int count);

  /// No description provided for @stockDiscussion.
  ///
  /// In id, this message translates to:
  /// **'Diskusi'**
  String get stockDiscussion;

  /// No description provided for @stockNotFound.
  ///
  /// In id, this message translates to:
  /// **'Kode saham tidak dikenal.'**
  String get stockNotFound;

  /// No description provided for @chats.
  ///
  /// In id, this message translates to:
  /// **'Chat'**
  String get chats;

  /// No description provided for @noChats.
  ///
  /// In id, this message translates to:
  /// **'Belum ada percakapan.'**
  String get noChats;

  /// No description provided for @selectChat.
  ///
  /// In id, this message translates to:
  /// **'Pilih percakapan untuk mulai chat.'**
  String get selectChat;

  /// No description provided for @newGroup.
  ///
  /// In id, this message translates to:
  /// **'Grup baru'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In id, this message translates to:
  /// **'Nama grup'**
  String get groupName;

  /// No description provided for @addMembers.
  ///
  /// In id, this message translates to:
  /// **'Tambah anggota'**
  String get addMembers;

  /// No description provided for @create.
  ///
  /// In id, this message translates to:
  /// **'Buat'**
  String get create;

  /// No description provided for @searchUsers.
  ///
  /// In id, this message translates to:
  /// **'Cari user…'**
  String get searchUsers;

  /// No description provided for @members.
  ///
  /// In id, this message translates to:
  /// **'{count} anggota'**
  String members(int count);

  /// No description provided for @online.
  ///
  /// In id, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @typing.
  ///
  /// In id, this message translates to:
  /// **'{name} sedang mengetik…'**
  String typing(String name);

  /// No description provided for @typingMany.
  ///
  /// In id, this message translates to:
  /// **'Beberapa orang sedang mengetik…'**
  String get typingMany;

  /// No description provided for @messageHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis pesan…'**
  String get messageHint;

  /// No description provided for @messageDeleted.
  ///
  /// In id, this message translates to:
  /// **'[pesan dihapus]'**
  String get messageDeleted;

  /// No description provided for @messageFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal terkirim. Ketuk untuk kirim ulang.'**
  String get messageFailed;

  /// No description provided for @messageRead.
  ///
  /// In id, this message translates to:
  /// **'Dibaca'**
  String get messageRead;

  /// No description provided for @messageSent.
  ///
  /// In id, this message translates to:
  /// **'Terkirim'**
  String get messageSent;

  /// No description provided for @messageSending.
  ///
  /// In id, this message translates to:
  /// **'Mengirim…'**
  String get messageSending;

  /// No description provided for @reconnecting.
  ///
  /// In id, this message translates to:
  /// **'Menyambungkan ulang…'**
  String get reconnecting;

  /// No description provided for @attachment.
  ///
  /// In id, this message translates to:
  /// **'[lampiran]'**
  String get attachment;

  /// No description provided for @replyToMessage.
  ///
  /// In id, this message translates to:
  /// **'Balas pesan'**
  String get replyToMessage;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus pesan ini untuk semua orang?'**
  String get deleteMessageConfirm;

  /// No description provided for @leaveRoom.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get leaveRoom;

  /// No description provided for @mute.
  ///
  /// In id, this message translates to:
  /// **'Bisukan'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan suara'**
  String get unmute;

  /// No description provided for @sendShortcutHint.
  ///
  /// In id, this message translates to:
  /// **'Enter untuk kirim, Shift+Enter untuk baris baru'**
  String get sendShortcutHint;

  /// No description provided for @notifications.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In id, this message translates to:
  /// **'Belum ada notifikasi.'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In id, this message translates to:
  /// **'Tandai semua dibaca'**
  String get markAllRead;

  /// No description provided for @notifReply.
  ///
  /// In id, this message translates to:
  /// **'{name} membalas Anda'**
  String notifReply(String name);

  /// No description provided for @notifMention.
  ///
  /// In id, this message translates to:
  /// **'{name} menyebut Anda'**
  String notifMention(String name);

  /// No description provided for @notifLike.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{{name} menyukai konten Anda} other{{name} dan {others} lainnya menyukai konten Anda}}'**
  String notifLike(String name, int count, int others);

  /// No description provided for @notifFollow.
  ///
  /// In id, this message translates to:
  /// **'{name} mulai mengikuti Anda'**
  String notifFollow(String name);

  /// No description provided for @notifMessage.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{Pesan baru dari {name}} other{{count} pesan baru dari {name}}}'**
  String notifMessage(String name, int count);

  /// No description provided for @someone.
  ///
  /// In id, this message translates to:
  /// **'Seseorang'**
  String get someone;

  /// No description provided for @typingShort.
  ///
  /// In id, this message translates to:
  /// **'mengetik…'**
  String get typingShort;

  /// No description provided for @messageDelivered.
  ///
  /// In id, this message translates to:
  /// **'Diterima'**
  String get messageDelivered;

  /// No description provided for @pollAddTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tambah polling'**
  String get pollAddTooltip;

  /// No description provided for @pollRemove.
  ///
  /// In id, this message translates to:
  /// **'Hapus polling'**
  String get pollRemove;

  /// No description provided for @pollOptionHint.
  ///
  /// In id, this message translates to:
  /// **'Pilihan {index}'**
  String pollOptionHint(int index);

  /// No description provided for @pollAddOption.
  ///
  /// In id, this message translates to:
  /// **'Tambah pilihan'**
  String get pollAddOption;

  /// No description provided for @pollDuration.
  ///
  /// In id, this message translates to:
  /// **'Durasi'**
  String get pollDuration;

  /// No description provided for @pollDuration1h.
  ///
  /// In id, this message translates to:
  /// **'1 jam'**
  String get pollDuration1h;

  /// No description provided for @pollDuration6h.
  ///
  /// In id, this message translates to:
  /// **'6 jam'**
  String get pollDuration6h;

  /// No description provided for @pollDuration1d.
  ///
  /// In id, this message translates to:
  /// **'1 hari'**
  String get pollDuration1d;

  /// No description provided for @pollDuration3d.
  ///
  /// In id, this message translates to:
  /// **'3 hari'**
  String get pollDuration3d;

  /// No description provided for @pollDuration7d.
  ///
  /// In id, this message translates to:
  /// **'7 hari'**
  String get pollDuration7d;

  /// No description provided for @pollVotes.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =0{Belum ada suara} other{{count} suara}}'**
  String pollVotes(int count);

  /// No description provided for @pollEndsIn.
  ///
  /// In id, this message translates to:
  /// **'Sisa {time}'**
  String pollEndsIn(String time);

  /// No description provided for @pollEnded.
  ///
  /// In id, this message translates to:
  /// **'Polling selesai'**
  String get pollEnded;

  /// No description provided for @pollYourVote.
  ///
  /// In id, this message translates to:
  /// **'Pilihan Anda'**
  String get pollYourVote;

  /// No description provided for @pollInvalidDraft.
  ///
  /// In id, this message translates to:
  /// **'Isi 2–4 pilihan berbeda, masing-masing maksimal 40 karakter.'**
  String get pollInvalidDraft;

  /// No description provided for @pollTimeMinutes.
  ///
  /// In id, this message translates to:
  /// **'{count} menit'**
  String pollTimeMinutes(int count);

  /// No description provided for @pollTimeHours.
  ///
  /// In id, this message translates to:
  /// **'{count} jam'**
  String pollTimeHours(int count);

  /// No description provided for @pollTimeDays.
  ///
  /// In id, this message translates to:
  /// **'{count} hari'**
  String pollTimeDays(int count);

  /// No description provided for @errorPollClosed.
  ///
  /// In id, this message translates to:
  /// **'Polling sudah berakhir.'**
  String get errorPollClosed;

  /// No description provided for @errorAlreadyVoted.
  ///
  /// In id, this message translates to:
  /// **'Anda sudah memilih di polling ini.'**
  String get errorAlreadyVoted;

  /// No description provided for @errorOwnPoll.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak bisa memilih di polling sendiri.'**
  String get errorOwnPoll;

  /// No description provided for @errorInvalidPoll.
  ///
  /// In id, this message translates to:
  /// **'Polling tidak valid. Periksa pilihan dan durasinya.'**
  String get errorInvalidPoll;

  /// No description provided for @errorDuplicateContent.
  ///
  /// In id, this message translates to:
  /// **'Konten yang sama sudah dikirim berulang kali. Coba lagi beberapa menit lagi.'**
  String get errorDuplicateContent;

  /// No description provided for @errorUserMuted.
  ///
  /// In id, this message translates to:
  /// **'Akun Anda sedang dibatasi dan belum bisa mengirim konten.'**
  String get errorUserMuted;

  /// No description provided for @today.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In id, this message translates to:
  /// **'Kemarin'**
  String get yesterday;

  /// No description provided for @supportOfficialBadge.
  ///
  /// In id, this message translates to:
  /// **'CS Resmi'**
  String get supportOfficialBadge;

  /// No description provided for @supportOfficialChannel.
  ///
  /// In id, this message translates to:
  /// **'Layanan resmi'**
  String get supportOfficialChannel;

  /// No description provided for @supportOpenLink.
  ///
  /// In id, this message translates to:
  /// **'Buka panduan'**
  String get supportOpenLink;

  /// No description provided for @supportViewCard.
  ///
  /// In id, this message translates to:
  /// **'Lihat detail'**
  String get supportViewCard;

  /// No description provided for @supportRatePrompt.
  ///
  /// In id, this message translates to:
  /// **'Beri nilai layanan ini'**
  String get supportRatePrompt;

  /// No description provided for @supportRated.
  ///
  /// In id, this message translates to:
  /// **'Terima kasih atas penilaian Anda'**
  String get supportRated;

  /// No description provided for @errorSecretRequestBlocked.
  ///
  /// In id, this message translates to:
  /// **'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.'**
  String get errorSecretRequestBlocked;

  /// No description provided for @supportTitle.
  ///
  /// In id, this message translates to:
  /// **'Bantuan / Chat CS'**
  String get supportTitle;

  /// No description provided for @supportPickTopic.
  ///
  /// In id, this message translates to:
  /// **'Apa yang bisa kami bantu?'**
  String get supportPickTopic;

  /// No description provided for @supportPickTopicHint.
  ///
  /// In id, this message translates to:
  /// **'Pilih topik agar CS yang tepat langsung membantu Anda.'**
  String get supportPickTopicHint;

  /// No description provided for @supportAttachOrder.
  ///
  /// In id, this message translates to:
  /// **'Lampirkan order'**
  String get supportAttachOrder;

  /// No description provided for @supportAttached.
  ///
  /// In id, this message translates to:
  /// **'Order {ref} ikut dilampirkan'**
  String supportAttached(String ref);

  /// No description provided for @supportHistory.
  ///
  /// In id, this message translates to:
  /// **'Lihat riwayat chat'**
  String get supportHistory;

  /// No description provided for @supportOutOfHours.
  ///
  /// In id, this message translates to:
  /// **'CS sedang di luar jam layanan. Pesan Anda dibalas mulai {time}.'**
  String supportOutOfHours(String time);

  /// No description provided for @supportStatusWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu CS'**
  String get supportStatusWaiting;

  /// No description provided for @supportQueueAhead.
  ///
  /// In id, this message translates to:
  /// **'{count} tiket di depan Anda'**
  String supportQueueAhead(int count);

  /// No description provided for @supportStatusHandled.
  ///
  /// In id, this message translates to:
  /// **'Ditangani oleh {name} – CS Resmi'**
  String supportStatusHandled(String name);

  /// No description provided for @supportStatusWaitingYou.
  ///
  /// In id, this message translates to:
  /// **'Menunggu balasan Anda'**
  String get supportStatusWaitingYou;

  /// No description provided for @supportStatusResolved.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In id, this message translates to:
  /// **'Ditutup'**
  String get supportStatusClosed;

  /// No description provided for @supportMenu.
  ///
  /// In id, this message translates to:
  /// **'Menu bantuan'**
  String get supportMenu;

  /// No description provided for @supportEndChat.
  ///
  /// In id, this message translates to:
  /// **'Akhiri chat'**
  String get supportEndChat;

  /// No description provided for @supportEndConfirm.
  ///
  /// In id, this message translates to:
  /// **'Akhiri chat dan tandai tiket ini selesai?'**
  String get supportEndConfirm;

  /// No description provided for @supportComplaint.
  ///
  /// In id, this message translates to:
  /// **'Ajukan pengaduan'**
  String get supportComplaint;

  /// No description provided for @supportComplaintConfirm.
  ///
  /// In id, this message translates to:
  /// **'Tiket ini akan dicatat sebagai pengaduan resmi dengan tenggat penyelesaian. Lanjutkan?'**
  String get supportComplaintConfirm;

  /// No description provided for @supportReportFake.
  ///
  /// In id, this message translates to:
  /// **'Laporkan CS palsu'**
  String get supportReportFake;

  /// No description provided for @supportReportFakeHint.
  ///
  /// In id, this message translates to:
  /// **'Ceritakan kejadiannya: siapa yang menghubungi, lewat apa, dan apa yang diminta.'**
  String get supportReportFakeHint;

  /// No description provided for @supportSend.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get supportSend;

  /// No description provided for @supportMyTickets.
  ///
  /// In id, this message translates to:
  /// **'Tiket saya'**
  String get supportMyTickets;

  /// No description provided for @supportNoTickets.
  ///
  /// In id, this message translates to:
  /// **'Belum ada tiket.'**
  String get supportNoTickets;

  /// No description provided for @supportNewTicket.
  ///
  /// In id, this message translates to:
  /// **'Buat tiket baru'**
  String get supportNewTicket;

  /// No description provided for @supportRateTitle.
  ///
  /// In id, this message translates to:
  /// **'Nilai layanan CS'**
  String get supportRateTitle;

  /// No description provided for @supportRateComment.
  ///
  /// In id, this message translates to:
  /// **'Komentar (opsional)'**
  String get supportRateComment;

  /// No description provided for @supportRateSubmit.
  ///
  /// In id, this message translates to:
  /// **'Kirim nilai'**
  String get supportRateSubmit;

  /// No description provided for @supportSensitiveWarning.
  ///
  /// In id, this message translates to:
  /// **'Pesan ini berisi {kinds} dan akan disamarkan. CS OLT tidak pernah meminta OTP, PIN, atau password.'**
  String supportSensitiveWarning(String kinds);

  /// No description provided for @supportKindOtp.
  ///
  /// In id, this message translates to:
  /// **'kode OTP'**
  String get supportKindOtp;

  /// No description provided for @supportKindPassword.
  ///
  /// In id, this message translates to:
  /// **'password/PIN'**
  String get supportKindPassword;

  /// No description provided for @supportKindCard.
  ///
  /// In id, this message translates to:
  /// **'nomor kartu'**
  String get supportKindCard;

  /// No description provided for @supportKindNik.
  ///
  /// In id, this message translates to:
  /// **'NIK'**
  String get supportKindNik;

  /// No description provided for @supportKindAccount.
  ///
  /// In id, this message translates to:
  /// **'nomor rekening'**
  String get supportKindAccount;

  /// No description provided for @supportComplaintFiled.
  ///
  /// In id, this message translates to:
  /// **'Pengaduan dicatat. Tenggat penyelesaian tampil di chat.'**
  String get supportComplaintFiled;

  /// No description provided for @supportFakeReported.
  ///
  /// In id, this message translates to:
  /// **'Laporan terkirim. Tim kami segera menindaklanjuti.'**
  String get supportFakeReported;

  /// No description provided for @supportClosed.
  ///
  /// In id, this message translates to:
  /// **'Chat diakhiri.'**
  String get supportClosed;

  /// No description provided for @supportCardSent.
  ///
  /// In id, this message translates to:
  /// **'Order dilampirkan ke chat.'**
  String get supportCardSent;

  /// No description provided for @supportNoOrders.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada order terbaru.'**
  String get supportNoOrders;

  /// No description provided for @supportTicketMeta.
  ///
  /// In id, this message translates to:
  /// **'{date} · {status}'**
  String supportTicketMeta(String date, String status);

  /// No description provided for @supportRating.
  ///
  /// In id, this message translates to:
  /// **'Nilai {rating}/5'**
  String supportRating(int rating);

  /// No description provided for @supportUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Chat CS belum tersedia. Coba lagi sebentar lagi.'**
  String get supportUnavailable;
}

class _OltSocialLocalizationsDelegate
    extends LocalizationsDelegate<OltSocialLocalizations> {
  const _OltSocialLocalizationsDelegate();

  @override
  Future<OltSocialLocalizations> load(Locale locale) {
    return SynchronousFuture<OltSocialLocalizations>(
      lookupOltSocialLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_OltSocialLocalizationsDelegate old) => false;
}

OltSocialLocalizations lookupOltSocialLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return OltSocialLocalizationsEn();
    case 'id':
      return OltSocialLocalizationsId();
  }

  throw FlutterError(
    'OltSocialLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
