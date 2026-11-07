# Menu Akun Nasabah di Web CS (gateway csAdmin)

Menu **Akun Nasabah** di web CS menampilkan dan mengelola data nasabah online dari csAdmin (server C++ lama + SQL Server) tanpa memindahkan datanya. Menu ini khusus akun yang berperan CS. Web CS memanggil `nasabah-gateway`, dan gateway meneruskan rute staf `/online/*` yang ada di daftar izin ke csAdmin.

```
Browser CS (web CS, satu login GoTrue)
   │  /api-nasabah/online/...  + token sesi console
   ▼
Traefik (satu origin dengan web CS, VPN di produksi)
   ▼
nasabah-gateway (services/nasabah-gateway, Go)
   1. verifikasi token sesi console (HS256, jwt_secret)
   2. baca izin Akun Nasabah akun CS (cs_api.nasabah_access, service_role, cache 30 dtk)
   3. tolak rute di luar daftar izin, aksi tanpa izin, dan filter query yang tidak lolos validasi
   4. isi kolom pelaku dengan kode CS console, jalankan guard
   5. bila belum punya token csAdmin: kirim assertion Ed25519 ke POST /integration/token
   6. teruskan request dengan token itu, catat aksi tulis ke cs_audit_log
   ▼
csAdmin (cdAdminEL) ──► SQL Server
```

Chat, tiket, dan Kepatuhan tidak bergantung pada gateway atau csAdmin. Kalau keduanya mati, hanya menu Akun Nasabah yang terganggu.

## Token integrasi

Gateway tidak memakai akun di TCSLogin. Identitasnya berupa pasangan kunci Ed25519:

- **Kunci privat** hanya ada di gateway: `docker/secrets/csadmin_signing_key`, dibuat otomatis oleh `make gen-secrets` (Windows: `.\make.ps1 gen-secrets`).
- **Kunci publik** diisi di config csAdmin. Kunci publik bukan rahasia, jadi aman walaupun config csAdmin terbaca orang lain.

Alurnya:
1. Gateway membuat *assertion*, yaitu JWT `EdDSA` berumur 60 detik dengan klaim `iss` dan `sub` = client id, `aud` = `csAdminEL`, `iat`, `exp`, dan `jti` acak.
2. Gateway mengirim `POST /integration/token` dengan body `{"Assertion": "..."}`.
3. csAdmin memeriksa:
   - tanda tangan dengan kunci publik di config;
   - client id dan audience;
   - umur assertion (maksimal 120 detik, toleransi jam 30 detik);
   - `jti` belum pernah dipakai (anti replay);
   - IP pemanggil, bila `allowed_ips` diisi.
4. csAdmin menerbitkan token biasa (HS256 `token_key`, `loginId` = client id) berumur `duration_token_minutes`. Semua endpoint lama menerimanya tanpa perubahan.
5. Gateway menyimpan token itu dan meminta yang baru satu menit sebelum habis, atau langsung bila csAdmin menjawab 401.

Respons csAdmin:

| Status | Arti |
|---|---|
| 200 | Token terbit |
| 401 | Assertion tidak sah (alasannya hanya ditulis di log csAdmin) |
| 403 | IP di luar `allowed_ips` |
| 404 | `public_key` kosong atau tidak valid, sehingga fitur mati |

### Config CS Admin service

Tambahkan blok baru dengan format yang sama seperti blok `server`, `database`, dan `zmq`. Blok lain tidak perlu diubah:

```
#INTEGRATION (web CS gateway)
integration {
        client_id       = web-cs
        public_key      = <satu baris dari gen-secrets atau log gateway>
        #DURATION IN MINUTES (1-60)
        duration_token_minutes = 15
}
```

- **`public_key`**: base64 SubjectPublicKeyInfo Ed25519, satu baris, tanpa `=`. Cara termudah: salin blok siap tempel dari web CS, **Pengaturan → Integrasi API Nasabah**. Bisa juga dari output `gen-secrets`, dari log start gateway (`public_key` di baris "Customer admin integration configured"), atau dari perintah ini:
  ```bash
  openssl pkey -in docker/secrets/csadmin_signing_key -pubout -outform DER | openssl base64 -A | tr -d '='
  ```
- **`allowed_ips`** (opsional): daftar IP dipisah koma, sebagaimana terlihat oleh csAdmin, mis. `allowed_ips = 192.168.4.20`. Tanpa baris ini, IP tidak dibatasi; tanda tangan tetap wajib.
- **`duration_token_minutes`**: 1–60; nilai lain kembali ke 15.
- **Syarat build:** OpenSSL ≥ 1.1.1 (Ed25519). Kodenya sudah dicek kompilasinya dengan jwt-cpp 0.4.0–0.7.2.
- Bila log csAdmin menulis "Integration token enabled for client web-cs", fitur aktif.

**Ganti kunci:** buat kunci baru (hapus `docker/secrets/csadmin_signing_key`, jalankan `gen-secrets`), ganti `public_key` di csAdmin, restart csAdmin, lalu restart gateway. `gen-secrets --force` juga membuat kunci baru.

## Endpoint csAdmin `GET /online/get-online-user`

Ditambahkan di `cdAdminEL.cc` untuk panel tiket: `?loginId=<LoginId>` (1–50 karakter, wajib token valid).
- Pencarian **persis** (bukan `LIKE`) dengan query berparameter, tidak peka huruf besar/kecil (`COLLATE SQL_Latin1_General_CP1_CI_AS`) di `dbo.V_LoginInfo`.
- Respons `data` berisi kolom yang sama dengan `get-list-online-user`, ditambah `Accounts`: daftar `TAccountLinked` yang di-join ke `V_Account` (`AccountId`, `AccountName`, `Branch`, `RDNAccount`, `RDNBank`, `InvestorNo`, `KSEIId`, `Created`, `CreatedBy`).
- `404 {"message":"Online user not found."}` bila LoginId tidak ada.

## Mencocokkan nasabah tiket dengan LoginId csAdmin

Nasabah tiket adalah profil aplikasi sosial yang dibuat dari token OLT. Username profil disanitasi (karakter selain `A-Za-z0-9_` menjadi `_`), jadi tidak selalu sama dengan LoginId. Karena itu:
- `public.upsert_olt_profile` (migrasi `0048`) menyimpan `preferred_username` asli dari token OLT ke `private.user_private.olt_username` setiap kali nasabah login.
- RPC `cs_api.ticket_customer_login(p_ticket_id)` hanya untuk akun CS yang boleh membaca tiket itu (aturan sama dengan `ticket_detail`). Hasilnya `{login_id, source}`:
  - `source = olt`: dari username login asli;
  - `source = profile`: jatuh ke username profil bila nasabah belum login ulang sejak migrasi ini.
- **Asumsi:** username login OLT sama dengan LoginId online user di csAdmin.

## Konfigurasi gateway

Super Admin mengatur sambungan ke CS Admin service dari web CS, di **Pengaturan → Integrasi API Nasabah**. Server cukup menjalankan `make up`; tidak ada alamat atau client id bawaan.

- **Aktif hanya setelah tes berhasil.** **Simpan & aktifkan** mengirim alamat dan client id ke gateway. Gateway meminta token ke CS Admin service dengan nilai itu, dan hanya bila berhasil menyimpannya lewat `cs_api.nasabah_save_integration` (service_role, migrasi `0055`). Penyimpanan langsung lewat `admin_set_setting` ditolak (`setting_locked`).
- **Menu Akun Nasabah** (menu atas, panel tiket, palet perintah) hanya tampil bila integrasi aktif: `agent_me` mengosongkan `nasabah_permissions` dan memberi `settings.nasabah_ready = false` selama belum aktif. Web CS memeriksa ulang setiap 60 detik, jadi tidak perlu login ulang.
- **Badge "Belum diatur"** tampil di menu samping Pengaturan dan di judul halaman sampai integrasi aktif. **Putuskan** menonaktifkan integrasi dan langsung menyembunyikan menu.
- **Gateway membaca nilainya** lewat `cs_api.nasabah_integration()` paling lama setiap 15 detik, dan langsung setelah simpan atau putus. Bila database sedang tidak terbaca, gateway tetap memakai nilai terakhir.
- **Audit:** `setting.nasabah_integration` dan `setting.nasabah_integration_cleared` atas nama Super Admin.

Endpoint gateway khusus Super Admin aktif (dicek lewat `cs_api.nasabah_is_super_admin`):

| Rute | Isi |
|---|---|
| `GET /api-nasabah/integration` | Alamat, client id, `configured`, `connected_at`, `connected_by`, dan kunci publik |
| `PUT /api-nasabah/integration` | Body `{url, client_id}` (wajib). Tes koneksi dulu; menjawab `{saved, check, status}`. `saved = false` berarti tes gagal dan tidak ada yang disimpan |
| `DELETE /api-nasabah/integration` | Putus integrasi; menu Akun Nasabah tersembunyi lagi |
| `POST /api-nasabah/integration/test` | Body `{url, client_id}` (wajib). Hanya tes, tidak menyimpan. Menjawab `result` (tabel di bawah) |

| `result` | Arti |
|---|---|
| `ok` | csAdmin menerbitkan token |
| `refused` | csAdmin menjawab 401: `public_key` atau `client_id` di config CS Admin service tidak cocok, atau jam server berbeda jauh |
| `ip_not_allowed` | csAdmin menjawab 403: IP server web CS tidak ada di `allowed_ips` |
| `disabled` | csAdmin menjawab 404: blok `integration` belum diisi, atau csAdmin masih versi lama |
| `unexpected` | Status HTTP lain, biasanya prefix path salah |
| `unreachable` | Alamat, port, atau firewall menghalangi |
| `not_configured` / `no_key` | Alamat atau client id kosong / kunci integrasi belum ada di server |

Yang tetap di server:

| Tempat | Kunci | Isi |
|---|---|---|
| `docker/secrets/csadmin_signing_key` | | Kunci privat Ed25519 (PEM PKCS#8), dibuat `gen-secrets`. Kosong = menu belum aktif |
| `docker/.env` | `CSADMIN_TIMEOUT` | Batas waktu panggilan ke csAdmin (default `15s`) |

Perubahan `CSADMIN_TIMEOUT` atau kunci baru baru dipakai setelah gateway dijalankan ulang:

```bash
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml --profile cs up -d nasabah-gateway
```

**Keamanan alamat.** Siapa pun yang bisa mengubah alamat bisa mengarahkan assertion gateway (berumur 60 detik) ke server lain. Karena itu:
- hanya Super Admin aktif yang bisa mengubah alamat dan menjalankan tes;
- alamat divalidasi di database dan di gateway: hanya `http(s)://host[:port][/path]`, tanpa login, query, atau fragment;
- setiap perubahan tercatat di audit log;
- isi `allowed_ips` di csAdmin dengan IP server web CS, supaya assertion yang tertangkap tidak bisa dipakai dari mesin lain.

Bila alamat atau kunci kosong, gateway tetap hidup dan menjawab `503 not_configured`. Bila csAdmin menolak kuncinya, gateway menjawab `503 integration_refused`, dan menu menampilkan pesan untuk memeriksa `public_key`.

## Izin per akun CS

Diatur Super Admin di **Pengaturan → Akun CS → Akses Akun Nasabah** (`cs.agents.nasabah_permissions`, RPC `cs_api.admin_set_nasabah_permissions`, diaudit `agent.nasabah_permissions`).

- Kotak centang ini hanya tampil untuk akun yang berperan **CS**. Database menolak memberi izin ke akun lain (`not_cs_agent`).
- Bila peran CS dicabut, izinnya ikut kosong (trigger `agents_nasabah_scope`).
- Akun nonaktif langsung kehilangan akses.

| Izin | Boleh |
|---|---|
| `online_user.view` | Lihat daftar nasabah online dan rekening tertautnya |
| `online_user.manage` | Ajukan buat/ubah/hapus Online ID, ubah rekening tertaut, reset password/PIN |
| `online_user.demo` | Ajukan buat/ubah/hapus **akun demo saja**, tanpa tautan rekening |
| `online_user.approve` | Setujui/tolak pengajuan **CS lain** |
| `online_user.approve_own` | Setujui/tolak pengajuan **sendiri**, tanpa menunggu CS lain |
| `online_user.status` | Ubah status Online ID langsung (aktif, nonaktif, tangguh transaksi, tangguh login) dengan alasan wajib |
| `opening_account.send` | Lihat data pembukaan rekening dan kirim emailnya (satu per satu atau beberapa sekaligus) |

Web CS memuat ulang izin akun saat menu dibuka, saat tab kembali aktif, dan setiap 60 detik, jadi perubahan izin berlaku tanpa login ulang. Pengajuan sendiri hanya bisa diputuskan dengan `online_user.approve_own`. Pengajuan CS lain hanya dengan `online_user.approve`. Akun yang punya keduanya boleh memutuskan semua pengajuan. csAdmin sendiri tidak memeriksa izin di server, jadi gateway yang menegakkannya.

## Isi menu

Menu ada di bar atas sebelum **Pengaturan**.

- **Ringkasan** di atas tab: jumlah Online ID terdaftar dan pengajuan yang menunggu approval, sesuai izin akun.
- **Online ID**:
  - daftar dan pencarian, serta detail dengan rekening tertaut. Kotak cari mencocokkan LoginId **atau** email yang mengandung teks itu (di bagian mana pun), sekaligus (dua permintaan ke csAdmin, hasil digabung tanpa duplikat, lalu dipaginasi di web). Baris yang terbawa karena bug filter email csAdmin (lihat catatan keamanan no. 6) disaring. Paling banyak 5 halaman × 100 baris per jenis pencarian dibaca; bila lebih, web meminta kata kunci yang lebih lengkap;
  - **data duplikat**: Online ID yang email atau nomor HP-nya juga dipakai Online ID lain diberi penanda merah, dan panel detail menyebut Online ID pasangannya. Sakelar **Hanya data duplikat** menampilkan semuanya dari seluruh data, bukan hanya halaman yang tampil, dan bisa disaring dengan kotak cari. Email dibandingkan tanpa beda huruf besar/kecil; nomor HP hanya angkanya, dengan `62`/`+62`/`8…` disamakan menjadi `0…` dan nomor kurang dari 8 digit diabaikan. Gateway membaca seluruh daftar csAdmin (100 baris per halaman, 4 permintaan paralel, paling banyak 300 halaman) dan menyimpan hasilnya 5 menit;
  - pengajuan buat/ubah/hapus, reset password/PIN, dan **ubah status** cepat;
  - form pengajuan buat/ubah mengikuti aturan form Online ID di aplikasi csAdmin lama (`legacy/user-management-flutter/csAdmin_New`, `add_edit_online_id_dialog.dart`):
    - **Rekening tertaut langsung di form** untuk tipe Nasabah (akun dengan izin manage), jadi buat Online ID dan tautkan rekening cukup satu pengajuan. csAdmin menerimanya lewat `ArrayAccountLink`/`ArrayAccountUnLink` di `create-approval-login`, dan rekening ditautkan saat pengajuan disetujui.
    - Email wajib dengan format valid (tanpa kolom ketik ulang).
    - Di layar lebar form dua kolom: data akun di kiri, rekening tertaut di kanan.
    - Nomor HP wajib, 7–20 digit (boleh diawali `+`). Tanggal lahir wajib, paling jauh 80 tahun lalu dan tidak di masa depan. Nilai lama yang tidak diubah tetap diterima, kecuali tanggal lahir placeholder `1900-01-01`.
    - Sales memilih **kode sales** (StaffId) dan Cabang/CS cabang memilih **kode cabang** dari data rekening (`get-list-link-account`). Kode yang tidak ada ditolak.
    - Hanya akun Demo yang punya masa berlaku: tanggal dari hari ini sampai 1 Januari tiga tahun lagi, atau centang **Tidak pernah kedaluwarsa**. Tanggal baru dikirim sebagai `yyyy-MM-dd 00:00:00`; tanggal lama yang tidak diubah dikirim apa adanya.
    - Ganti tipe akun mengosongkan kode sales/cabang dan masa berlaku, serta membatalkan perubahan tautan rekening. Mengubah Nasabah ke tipe lain tidak melepas rekening yang sudah tertaut (sama seperti app lama).
    - Status akun tidak ada di form: Online ID baru selalu Aktif, dan perubahan status lewat **Ubah status** (wajib alasan, izin `online_user.status`).
    - Sebelum terkirim ada konfirmasi berisi jumlah rekening yang akan ditautkan/dilepas.
    - Daftar kode rekening yang ditautkan dan yang dilepas masing-masing maksimal 255 karakter setelah digabung koma, karena parameter `@ArrayAccountLink`/`@ArrayAccountUnLink` di csAdmin berupa VARCHAR(255). Lebih dari itu ditolak dengan pesan untuk membagi pengajuan.
  - kelola rekening tertaut, dengan dialog terbagi: **Sudah tertaut** (hapus centang untuk melepas), **Akan ditautkan**, dan **Tambah rekening** (pencarian katalog), plus ringkasan jumlah setelah disetujui;
  - baris yang email, nomor HP, atau tanggal lahirnya kosong diberi penanda. Sakelar **Hanya data belum lengkap** menyaring halaman yang sedang tampil, dan tombol **Lengkapi data** membuka form pengajuan perubahan.
- **Panel info nasabah di tiket**: bagian **Akun Nasabah** paling atas, untuk akun yang punya izin baca (view/manage/demo/approve/approve_own/status). Isinya:
  - LoginId, tipe, dan status;
  - email dan HP dengan tanda terverifikasi, tanggal lahir, tanggal terdaftar, salah password/PIN, dan fitur tambahan;
  - rekening tertaut dengan nama, cabang, RDN, bank, dan SID (4 pertama, lalu **Tampilkan semua**);
  - tautan **Buka di Akun Nasabah** (`/nasabah?q=<LoginId>`).

  Bila LoginId nasabah tidak ada di csAdmin, bagian ini tidak ditampilkan sama sekali.
- **Approval**: daftar pengajuan dengan filter, detail perubahan rekening, setujui/tolak.
- **Pembukaan rekening**: dikelompokkan per LoginId, satu baris per LoginId berisi email, jumlah rekening, dan contoh kode rekening. Pengelompokan dilakukan di klien dari baris yang sudah dimuat; klik baris untuk membuka rekeningnya tanpa request tambahan ke csAdmin. Karena csAdmin memaginasi per baris rekening (urut LoginId), LoginId pertama/terakhir di halaman bisa berlanjut ke halaman sebelah, dan detailnya diberi catatan. Email bisa dikirim satu per satu, atau centang beberapa rekening (boleh lintas LoginId; ada centang semua per LoginId) lalu **Kirim email (n)**. Halaman daftar berisi 100 baris rekening csAdmin.

## Rute yang dibuka

Semua rute membatasi parameter query ke daftar yang dikenal dan memvalidasi isinya:
- `page` 1–999999 dan `size` 1–100;
- LoginId/kode `[A-Za-z0-9._@-]` maksimal 50 karakter;
- email `[A-Za-z0-9._@+-]` maksimal 100 karakter;
- angka kecil untuk status/jenis.

Parameter lain dibuang, dan nilai yang tidak lolos dijawab `400 invalid_query` tanpa menyentuh csAdmin.

| Rute csAdmin | Aksi audit | Izin | Guard di gateway |
|---|---|---|---|
| `GET /online/get-list-online-user` | – | view/manage/demo/approve/approve_own/status | – |
| `GET /online/duplicates` | – | view/manage/demo/approve/approve_own/status | Dihitung di gateway, tidak diteruskan ke csAdmin: membaca seluruh `get-list-online-user`, lalu mengembalikan kelompok email/HP yang dipakai lebih dari satu Online ID beserta barisnya. Cache 5 menit untuk semua staf |
| `GET /online/get-online-user` | `nasabah.online_user.profile` | view/manage/demo/approve/approve_own/status | Endpoint baru csAdmin; `loginId` divalidasi; satu user persis + rekening tertaut |
| `GET /online/get-linked-account-online-user` | `nasabah.online_user.linked_accounts` | idem | – |
| `GET /online/get-list-link-account` | – | manage | – |
| `POST /online/create-approval-login` | `nasabah.approval.create` | manage, demo | LoginId baru `^[A-Za-z0-9._@-]{1,50}$` (`invalid_login_id`). `ArrayAccountLink`/`ArrayAccountUnLink` berupa array kode unik yang dirapikan, masing-masing maksimal 255 karakter setelah digabung (`invalid_account_link`, `too_many_accounts`). Tautan baru hanya untuk tipe Nasabah, kecuali hapus (`links_client_only`). Demo-only: tipe akun 0, tanpa tautan rekening, dan Online ID yang diubah/dihapus memang akun demo |
| `POST /online/change-password-and-pin-online-user` | `nasabah.online_user.reset_credential` | manage | Email penerima diambil dari data nasabah di csAdmin; ditolak bila nasabah belum punya email |
| `PUT /online/update-status-online-user` | `nasabah.online_user.status` | status | Status 0–3; alasan 10–200 karakter wajib dan ikut tercatat di audit; Online ID harus ada |
| `GET /online/get-list-approval-online-user` | – | approve/approve_own/manage/demo | – |
| `GET /online/get-approval-linked-account-online-user` | – | approve/approve_own/manage/demo | – |
| `POST /online/approve-approval-login` | `nasabah.approval.decide` | approve, approve_own | Pengajuan harus masih pending; LoginId, jenis, dan email diambil dari pengajuan asli; pengajuan sendiri butuh approve_own, pengajuan CS lain butuh approve |
| `GET /online/get-list-opening-rekening-online-user` | – | opening | – |
| `POST /online/send-email-opening-account-with-rekening` | `nasabah.opening_account.send_email` | opening | Pasangan LoginId–rekening harus ada |

Bila csAdmin menjawab 404 tanpa JSON (rute belum ada karena server csAdmin belum diperbarui), gateway menjawab `502 upstream_outdated`. Dengan begitu web CS tidak salah menampilkan "tidak ditemukan".

Kolom pelaku (`CreatedBy`, `ApprovedBy`, `ModifiedBy`, `CSLoginId`) selalu ditimpa gateway dengan kode CS console (mis. `CS-0045`); nilai dari browser diabaikan. Audit mencatat:
- CS yang sebenarnya;
- rute;
- nama field yang dikirim, tanpa nilainya;
- subjek (LoginId/ApprovalId/CustId/Status/alasan).

Semua tampil di menu **Jejak Audit** Kepatuhan.

**Sengaja tidak dibuka:**
- semua `/cs/*` (akun staf csAdmin), `/auto-update/*`, `/otp/*`, dan `/integration/token` (hanya dipakai gateway sendiri);
- rute publik aplikasi nasabah (registrasi, OTP, verifikasi email, lupa password/PIN);
- `send-email-opening-account` dan `send-email-forget-password-and-pin-online-user`, karena keduanya mengirim kredensial tanpa login.

Gateway menjawab `404 route_not_found` tanpa menyentuh csAdmin.

## Catatan keamanan csAdmin (di luar gateway)

Ditemukan saat membaca `legacy/user-management/cdAdminEL.cc`; gateway tidak bisa menambal hal-hal ini di sisi csAdmin:

1. `GET /auto-update/get-binary-file?fileName=` bisa dipanggil tanpa login dan rentan path traversal, sehingga config (berisi `token_key` dan password SQL Server) bisa dibaca. Kunci publik integrasi aman walau terbaca, tetapi `token_key` tidak. **Jangan buka port csAdmin ke internet**, ganti `token_key` dan password DB bila pernah terbuka, dan batasi `fileName` ke daftar hash.
2. Filter daftar ditempel langsung ke SQL (`LIKE '<nilai>%'`). Lewat web CS, gateway hanya meneruskan nilai yang lolos pola karakter aman; klien lain tetap rentan sampai csAdmin memakai parameterized query.
3. Server tidak memeriksa izin dan mengambil pelaku dari body. Untuk web CS ini ditangani gateway, tetapi pemegang token mana pun bisa melakukan apa saja.
4. Lalu lintas ke csAdmin memakai HTTP biasa, sehingga token yang diterbitkan bisa terbaca di jaringan. Batasi csAdmin ke jaringan internal/VPN, dan pertimbangkan TLS.
5. `cdAdminEL.cc` berisi nilai default kredensial di kode. Jangan dibagikan ke luar tim.
6. Filter email di `get-list-online-user` tanpa kurung: `AND Email LIKE '<nilai>%' OR Email IS NULL`, sehingga semua Online ID tanpa email ikut terbawa dan hasil yang benar bisa terdorong ke halaman lain. Web CS menyaring baris ini; perbaikan di csAdmin cukup menghapus `OR Email IS NULL` (atau memberi kurung).

## Pengujian

- **Go:** `make test-nasabah-gateway` (Windows: `.\make.ps1 test-nasabah-gateway`). Mencakup:
  - verifikasi token console, cache izin;
  - assertion Ed25519 dan pertukaran token (sekali pakai, refresh, ditolak);
  - kunci PKCS#8;
  - daftar rute dan validasi query, guard (demo, email, approval termasuk approve_own, status);
  - timpa pelaku dan audit.
- **pgTAP:** `supabase/tests/032_cs_nasabah_access_test.sql` (izin khusus akun CS, approve_own, pencabutan peran, RPC khusus gateway, audit).
- **Web CS:**
  - `src/features/nasabah/*.test.ts`: logika form, keputusan approval, status, data belum lengkap, klien API;
  - `accounts-section.test.tsx`: kotak centang hanya untuk akun CS.
- **Endpoint csAdmin:** fungsi barunya diekstrak dan dikompilasi (g++ 12, `-Wall -Wextra`) dalam server uji, lalu diuji dari gateway Go dengan kunci sungguhan. Kasus yang diuji:
  - token terbit dan diterima endpoint lama;
  - replay, kunci lain, issuer/audience salah, umur terlalu panjang, kedaluwarsa, waktu masa depan, tanpa `jti`, HS256 palsu, dan token rusak ditolak 401;
  - IP di luar allowlist ditolak 403;
  - fitur mati menjawab 404.
- **Uji ke csAdmin sungguhan:** dijalankan setelah csAdmin baru dipasang di server. Aksi tulis ke data csAdmin sungguhan belum pernah dijalankan.

## Keputusan

1. **UI disatukan, data tidak.** SQL Server tetap sumber kebenaran; Supabase tidak menyimpan data nasabah csAdmin.
2. **Token integrasi, bukan akun.** Gateway tidak memakai akun CS di TCSLogin. csAdmin hanya menyimpan kunci publik, sehingga kebocoran config tidak memberi kemampuan meminta token.
3. **Akun Nasabah khusus akun CS.** Izin diatur per akun CS di console; Super Admin dan Kepatuhan yang bukan CS tidak mendapat menu ini.
4. **Approve sendiri lewat izin.** Maker-checker tetap jadi bawaan, tetapi akun dengan `online_user.approve_own` boleh memutuskan pengajuannya sendiri. Semua keputusan tetap tercatat dengan kode CS.
5. **Ubah status cepat dengan rem.** Izin terpisah (`online_user.status`), alasan wajib, dan audit.
6. **Kirim ulang kredensial tanpa login tidak dibuka.** Reset password/PIN (kredensial baru ke email terdaftar) menggantikannya.
7. **Kelola akun CS csAdmin tidak dibuka.** Menu ini fokus pada akun nasabah; akun staf csAdmin tetap diurus di aplikasi lama.
