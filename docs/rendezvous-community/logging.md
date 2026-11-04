# Logging `rendezvous_community`

Library memakai satu logger terpusat berbasis [`package:logging`](https://pub.dev/packages/logging) (BSD-3). Library **tidak mencetak ke konsol** sendiri; host memasang handler.

## Pemasangan di host

```dart
await RendezvousCommunity.initialize(
  // ...
  logHandler: (record) {
    final event = record.object;                     // CommunityLogEvent: message + fields
    oltLog.write(
      level: record.level.name,
      source: record.loggerName,                     // RendezvousCommunity.Chat, dst.
      message: event is CommunityLogEvent ? event.message : record.message,
      fields: event is CommunityLogEvent ? event.fields : const {},
      error: record.error,                           // sudah disamarkan
    );
  },
  logLevel: Level.INFO,
);
```

- **Tanpa `logHandler`:** log dicetak dengan `debugPrint` **hanya di mode debug** (`debugConsoleLogHandler`).
- **Level default:** `INFO` di build release, `FINE` di debug. Ubah dengan `logLevel`.
- Record juga naik ke `Logger.root` milik `package:logging`. Bila host sudah mendengarkan `Logger.root`, jangan pasang handler yang sama dua kali.
- `initialize` menyalakan `hierarchicalLoggingEnabled` supaya level library tidak mengubah level logger host.

## Logger per komponen

| Logger | Isi |
|---|---|
| `RendezvousCommunity.Auth` | Penerbitan dan refresh sesi sosial |
| `RendezvousCommunity.Realtime` | Status channel realtime (`postgres_changes` dan topik broadcast privat) |
| `RendezvousCommunity.Chat` | Pengiriman pesan |
| `RendezvousCommunity.Feed` | Pemuatan feed |
| `RendezvousCommunity.Support` | Chat CS / tiket |
| `RendezvousCommunity.Push` | Pendaftaran token push |
| `RendezvousCommunity.Account` | Dokumen hukum, ekspor data, hapus akun |
| `RendezvousCommunity.Config` | Konfigurasi klien, kill switch, versi minimum |
| `RendezvousCommunity.Analytics` | Pengiriman batch analitik |
| `RendezvousCommunity.Offline` | Database lokal (hapus, ganti user, error penyimpanan) dan status koneksi |

Di kode: `CommunityLoggers.chat.event(Level.SEVERE, 'Failed to send message', fields: {...})`.

## Format pesan

- **Kalimat:** singkat, Bahasa Inggris, bentuk lampau atau keadaan, diawali huruf kapital, tanpa titik di akhir.
- **Data variabel:** masuk ke `fields` (map), tidak disisipkan ke kalimat. `record.message` berisi `Message {"field":"value"}`.
- **Level:**

  | Level | Dipakai untuk |
  |---|---|
  | `FINE` | Event sering atau debug, misalnya status channel realtime |
  | `INFO` | Kejadian penting yang normal |
  | `WARNING` | Gagal tapi bisa pulih |
  | `SEVERE` | Error yang membuat aksi user gagal |

| Level | Logger | Pesan | Field |
|---|---|---|---|
| INFO | Auth | `Social session issued` | `userId`, `expiresAt` |
| WARNING | Auth | `Social session exchange failed` | `kind`, `code` |
| FINE | Auth | `Scheduled session refresh failed, retrying` | `delayMs` |
| FINE | Realtime | `Realtime channel subscribed` / `Realtime channel closed` | `channel`, `status` |
| WARNING | Realtime | `Realtime channel interrupted, retrying` | `channel`, `status`, error |
| SEVERE | Chat | `Failed to send message` | `roomId`, `clientId`, `kind`, `code` |
| INFO | Support | `Support ticket opened` | `ticketId`, `topic`, `status` |
| WARNING | Feed | `Failed to load feed` | `scope`, `kind`, `code` |
| WARNING | Account | `Could not load legal documents` | `kind`, `code` |
| INFO | Account | `Personal data exported` | `userId`, `byteCount` (isi ekspor tidak pernah dicatat) |
| INFO | Account | `Community account deleted` | `userId` |
| WARNING | Config | `Client config refresh failed` | `kind`, `code` |
| INFO | Config | `Client config changed` | `socialEnabled`, `updateRequired` |
| FINE | Analytics | `Analytics batch dropped` | `eventCount`, `kind`, `code` (isi event tidak dicatat) |
| FINE | Analytics | `Analytics disabled by server` | — |
| FINE | Chat | `Message queued for retry` | `roomId`, `clientId`, `attemptCount`, `kind`, `code`, `delayMs` |
| WARNING | Chat | `Queued message failed` | `roomId`, `clientId`, `attemptCount`, `kind`, `code` |
| FINE | Chat | `Queued message sent` | `roomId`, `clientId`, `attemptCount` |
| FINE | Push | `Notification event queued` / `Notification event dropped` | `event`, `kind`, `code` |
| FINE | Feed | `Draft kept on this device` | `draftId`, `kind`, `code` (isi draf tidak dicatat) |
| INFO | Offline | `Offline cache wiped` | `storeCount` |
| INFO | Offline | `Offline cache of a previous user removed` | — |
| WARNING | Offline | `Offline cache operation failed` | `operation`, `errorType`, error |
| INFO | Offline | `Network reachability changed` | `online` |
| INFO | Offline | `Image cache wiped` | — |
| INFO | Offline | `Image cache of a previous user removed` | — |
| WARNING | Offline | `Image cache operation failed` | `operation` (`open`, `write`, `wipe`), `errorType`, error |

## Data sensitif

Token, JWT, password, OTP, isi pesan chat, isi post, nomor rekening, dan NIK **tidak boleh** masuk log. ID boleh. `CommunityLogEvent` dan `event(error: ...)` menyamarkan otomatis menjadi `[REDACTED]`:

- **Field yang key-nya sensitif.** Key dipecah per kata (`accessToken` → `access`, `token`). Kata sensitif: `token`, `jwt`, `password`, `passwd`, `secret`, `otp`, `pin`, `authorization`, `cookie`, `body`, `content`, `text`, `message`, `caption`, `comment`, `account`, `rekening`, `nik`, `card`, `cvv`, `apikey`. Key yang berakhiran `Id`, `Ids`, `Count`, `At`, `Status`, `Kind`, `Code`, atau `Type` tetap ditampilkan (`messageId`, `commentCount`).
- **Nilai teks di field mana pun dan pesan error:**
  - pola JWT `eyJ….….…`;
  - `Bearer <token>`;
  - token sesi OLT `olt_…`;
  - token mock `mock:<id>:<username>`;
  - `token=`/`password=`/`apikey=`/`otp=` di query;
  - deret angka ≥ 10 digit (NIK, nomor rekening). Nomor tiket `CS-YYYYMMDD-NNNN` tetap terbaca.

Tesnya ada di `test/core/logging/community_logger_test.dart`. CI juga menjalankan `tool/check_logging.dart`, yang menolak `print`/`debugPrint` di luar `lib/src/core/logging/`.
