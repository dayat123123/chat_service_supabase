# Menu Nasabah di Web CS (gateway csAdmin)

Menu **Nasabah** di web CS menampilkan dan mengelola data nasabah online dan akun CS csAdmin (server C++ lama + SQL Server) tanpa memindahkan datanya. Web CS memanggil `nasabah-gateway`. Gateway inilah yang login ke csAdmin, dan hanya rute dalam daftar izin yang diteruskan: rute staf `/online/*` dan pengelolaan akun CS `/cs/*`.

```
Browser staf (web CS, satu login GoTrue)
   │  /api-nasabah/online/... atau /api-nasabah/cs/...  + token sesi console
   ▼
Traefik (satu origin dengan web CS, VPN di produksi)
   ▼
nasabah-gateway (services/nasabah-gateway, Go)
   1. verifikasi token sesi console (HS256, jwt_secret)
   2. baca permission Nasabah akun console (cs_api.nasabah_access, service_role, cache 30 dtk)
   3. tolak rute di luar daftar izin, aksi tanpa permission, dan filter query yang tidak lolos validasi
   4. isi kolom pelaku dengan kode akun console, jalankan guard
   5. login ke csAdmin dengan akun teknis (token disimpan, login ulang bila 401)
   6. teruskan request, jalankan langkah lanjutan (mis. password sementara), catat aksi tulis ke cs_audit_log
   ▼
csAdmin (cdAdminEL) ──► SQL Server
```

Chat, tiket, dan Kepatuhan tidak bergantung pada gateway atau csAdmin. Kalau keduanya mati, hanya menu Nasabah yang terganggu.

## Konfigurasi

| Tempat | Kunci | Isi |
|---|---|---|
| `docker/.env` | `CSADMIN_URL` | Alamat csAdmin termasuk prefix path, mis. `http://192.168.10.10:8080` atau `http://host:9001/csAdmin` |
| `docker/.env` | `CSADMIN_USERNAME` | LoginId akun teknis csAdmin (baris di `TCSLogin`) |
| `docker/secrets/csadmin_password` | | Password akun teknis (file teks, tanpa baris baru) |
| `docker/.env` | `CSADMIN_ACTOR` | `agent` (default): kolom pelaku di csAdmin diisi kode akun console (mis. `CS-0045`). `service`: diisi LoginId akun teknis |
| `docker/.env` | `CSADMIN_TIMEOUT` | Batas waktu panggilan ke csAdmin (default `15s`) |

Kedua file di atas di-gitignore. Setelah mengubah, jalankan ulang gateway:

```bash
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml --profile cs up -d nasabah-gateway
```

Bila URL, username, atau password kosong, gateway tetap hidup dan menjawab `503 not_configured`; menu Nasabah menampilkan pesannya.

## Permission per akun console

Diatur Super Admin di **Pengaturan → Akun CS → Akses Nasabah** (`cs.agents.nasabah_permissions`, RPC `cs_api.admin_set_nasabah_permissions`, diaudit `agent.nasabah_permissions`). Menu Nasabah hanya tampil untuk akun yang punya minimal satu permission. Akun nonaktif langsung kehilangan akses.

| Permission | Padanan bit csAdmin | Boleh |
|---|---|---|
| `online_user.view` | – | Lihat daftar nasabah online dan rekening tertautnya |
| `online_user.manage` | bit 1 createOnlineUser | Ajukan buat/ubah/hapus Online ID, ubah rekening tertaut, reset password/PIN |
| `online_user.demo` | bit 3 createDemoAccount | Ajukan buat/ubah/hapus **akun demo saja**, tanpa tautan rekening |
| `online_user.approve` | bit 2 approveOnlineUser | Setujui/tolak pengajuan (bukan pengajuan sendiri) |
| `online_user.status` | – | Ubah status Online ID langsung (aktif, nonaktif, tangguh transaksi, tangguh login) dengan alasan wajib |
| `opening_account.send` | bit 5 approvalOpeningAccount | Lihat data pembukaan rekening dan kirim emailnya (satu per satu atau beberapa sekaligus) |
| `cs_user.manage` | bit 0 createCsLogin | Kelola akun CS csAdmin: buat, ubah flag dan status, atur password, hapus |
| `cs_log.view` | bit 4 viewCsLogs | Lihat log aktivitas CS csAdmin |

csAdmin sendiri tidak memeriksa permission di server (hanya aplikasi desktop yang memeriksa). Untuk web CS, gateway yang menegakkannya.

## Isi menu

- **Ringkasan** di atas tab: jumlah Online ID terdaftar, pengajuan yang menunggu approval, dan jumlah akun CS csAdmin. Angka hanya muncul untuk bagian yang boleh dilihat akun tersebut.
- **Online ID**: daftar dan pencarian, detail dengan rekening tertaut, pengajuan buat/ubah/hapus, kelola rekening tertaut, reset password/PIN, dan **ubah status** cepat. Baris yang emailnya, nomor HP-nya, atau tanggal lahirnya kosong diberi penanda. Ada juga sakelar **Hanya data belum lengkap** (berlaku untuk halaman yang sedang tampil). Di detail nasabah, tombol **Lengkapi data** membuka form pengajuan perubahan.
- **Approval**: daftar pengajuan dengan filter, detail perubahan rekening, setujui/tolak.
- **Pembukaan rekening**: daftar per LoginId–rekening, kirim email satu per satu, atau centang beberapa baris di halaman lalu **Kirim email (n)**. Email dikirim berurutan dan hasilnya diringkas (berhasil/gagal).
- **Akun CS csAdmin**: daftar dan pencarian (LoginId, ID karyawan), detail dengan 9 flag aplikasi, tambah akun, ubah akun (ID karyawan, email, status, flag), atur password (dengan tombol **Buat acak**), dan hapus akun.
- **Log CS**: log aktivitas csAdmin dengan filter jenis aktivitas (23 jenis), LoginId CS, dan LoginId nasabah.

## Rute yang dibuka

Semua rute baca membatasi parameter query ke daftar yang dikenal dan memvalidasi isinya. `page` 1–999999, `size` 1–100, LoginId/kode `[A-Za-z0-9._@-]` maksimal 50 karakter, email `[A-Za-z0-9._@+-]` maksimal 100 karakter, dan angka kecil untuk status/jenis. Parameter lain dibuang, dan nilai yang tidak lolos validasi dijawab `400 invalid_query` tanpa menyentuh csAdmin.

| Rute csAdmin | Aksi audit | Permission | Guard di gateway |
|---|---|---|---|
| `GET /online/get-list-online-user` | – | view/manage/demo/approve/status | – |
| `GET /online/get-linked-account-online-user` | `nasabah.online_user.linked_accounts` | view/manage/demo/approve/status | – |
| `GET /online/get-list-link-account` | – | manage | – |
| `POST /online/create-approval-login` | `nasabah.approval.create` | manage, demo | Demo-only: tipe akun 0, tanpa tautan rekening, dan Online ID yang diubah/dihapus memang akun demo |
| `POST /online/change-password-and-pin-online-user` | `nasabah.online_user.reset_credential` | manage | Email penerima diambil dari data nasabah di csAdmin, bukan dari browser; ditolak bila nasabah belum punya email |
| `PUT /online/update-status-online-user` | `nasabah.online_user.status` | status | Status 0–3; alasan 10–200 karakter wajib dan ikut tercatat di audit; Online ID harus ada |
| `GET /online/get-list-approval-online-user` | – | approve/manage/demo | – |
| `GET /online/get-approval-linked-account-online-user` | – | approve/manage/demo | – |
| `POST /online/approve-approval-login` | `nasabah.approval.decide` | approve | Pengajuan harus masih pending; LoginId, jenis, dan email diambil dari pengajuan asli; pengaju tidak boleh memutuskan pengajuannya sendiri |
| `GET /online/get-list-opening-rekening-online-user` | – | opening | – |
| `POST /online/send-email-opening-account-with-rekening` | `nasabah.opening_account.send_email` | opening | Pasangan LoginId–rekening harus ada |
| `GET /cs/get-list-customer-service` | – | cs_user.manage | – |
| `POST /cs/create-customer-service-account` | `nasabah.cs_user.create` | cs_user.manage | LoginId `[A-Za-z0-9._]` 3–50, ID karyawan wajib, email valid, flag 0–511; password dan status dari browser dibuang. Setelah sukses, gateway memasang password sementara acak (lihat di bawah) |
| `PUT /cs/update-customer-service-account` | `nasabah.cs_user.update` | cs_user.manage | Validasi yang sama dan status 0–3 |
| `PUT /cs/change-password-customer-service-account` | `nasabah.cs_user.password` | cs_user.manage | Password 6–20 karakter, ada huruf besar dan huruf kecil, tanpa spasi |
| `DELETE /cs/delete-customer-service-account` | `nasabah.cs_user.delete` | cs_user.manage | `modifiedBy` di query diisi gateway |
| `GET /cs/get-customer-service-logs` | – | cs_log.view | – |

Kolom pelaku (`CreatedBy`, `ApprovedBy`, `ModifiedBy`, `CSLoginId`, dan `modifiedBy` di query) selalu ditimpa gateway; nilai dari browser diabaikan. Audit mencatat CS console yang sebenarnya, rute, nama field yang dikirim (tanpa nilai seperti password), dan subjek (LoginId/ApprovalId/CustId/Status/alasan). Semua tampil di menu **Jejak Audit** Kepatuhan.

**Sengaja tidak dibuka:** `/cs/login`, `/cs/logout`, `/cs/reset-password` (mengirim password lama yang didekripsi lewat email), `/cs/*-suggestion`, `/cs/get-campaigns`, `/auto-update/*`, `/otp/*`, rute publik aplikasi nasabah (registrasi, OTP, verifikasi email, lupa password/PIN), `send-email-opening-account` dan `send-email-forget-password-and-pin-online-user` (mengirim kredensial tanpa login). Gateway menjawab `404 route_not_found` tanpa menyentuh csAdmin.

## Akun teknis gateway

- Akun teknis (`CSADMIN_USERNAME`) tampil di tab Akun CS dengan label **Akun teknis gateway**. Tombol ubah, atur password, dan hapus dinonaktifkan. Gateway juga menolak ketiga aksi itu untuk akun tersebut (`403 service_account_locked`), apa pun huruf besar/kecilnya. Password dan flag-nya diatur lewat konfigurasi server, bukan dari web CS.
- Detail akun lain mencantumkan nama yang dipakai sebagai pelaku di csAdmin (`GET /api-nasabah/gateway/info`).

## Password akun CS baru

csAdmin membuat akun CS dengan password default yang sama untuk semua akun. Karena itu, setelah create sukses gateway langsung memanggil `change-password-customer-service-account` dengan password acak 14 karakter (huruf besar, huruf kecil, dan angka, tanpa karakter mirip seperti `0 O 1 l I`). Password itu dikembalikan sekali ke web CS sebagai `TemporaryPassword` dan ditampilkan sekali dengan tombol salin. Password tidak pernah ditulis ke log atau audit. Bila langkah lanjutan ini gagal, respons berisi `TemporaryPasswordError`, lalu web CS meminta staf mengatur password saat itu juga.

## Catatan keamanan csAdmin (di luar gateway)

Ditemukan saat membaca `legacy/user-management/cdAdminEL.cc`; gateway tidak bisa menambal hal-hal ini di sisi csAdmin:

1. `GET /auto-update/get-binary-file?fileName=` bisa dipanggil tanpa login dan rentan path traversal, sehingga file config (berisi `token_key` dan password SQL Server) bisa dibaca. **Jangan buka port csAdmin ke internet**, ganti `token_key` dan password DB bila pernah terbuka, dan batasi `fileName` ke daftar hash.
2. Filter daftar (`loginId`, `email`, `custId`, `createdBy`, `csLoginId`, `employeeId`) ditempel langsung ke SQL (`LIKE '<nilai>%'`), sehingga rentan SQL injection. Lewat web CS, gateway hanya meneruskan nilai yang lolos pola karakter aman. Klien lain (aplikasi desktop) tetap rentan sampai csAdmin memakai parameterized query.
3. Server tidak memeriksa permission dan mengambil identitas pelaku dari body. Untuk web CS ini ditangani gateway, tapi klien lain tetap bisa melakukan apa saja dengan token apa pun.
4. `update-status-online-user` mengubah status langsung tanpa approval dan tanpa log di csAdmin. Lewat web CS, aksi ini dibatasi permission tersendiri, wajib beralasan, dan tercatat di audit console.
5. Akun teknis gateway sebaiknya memakai password kuat dan khusus untuk gateway.

## Pengujian

- Go: `make test-nasabah-gateway` (Windows: `.\make.ps1 test-nasabah-gateway`). Mencakup verifikasi token, cache akses, sesi csAdmin (login, refresh, login ulang), daftar rute dan validasi query, guard (demo, email, approval, status, akun CS, password, akun teknis), password sementara, timpa pelaku, dan audit.
- pgTAP: `supabase/tests/032_cs_nasabah_access_test.sql` (permission, RPC khusus gateway, audit).
- Web CS: `src/features/nasabah/*.test.ts` (logika form, payload, kebijakan password, data belum lengkap, klien API) dan `components/cs-users-tab.test.tsx` (penguncian akun teknis, password sementara sekali tampil).
- Uji nyata ke csAdmin hanya untuk permintaan baca dan penolakan validasi yang berhenti di gateway. Aksi tulis (pengajuan, approval, reset, ubah status, kirim email, buat/ubah/hapus akun CS, atur password) diuji lewat tes unit dan belum dijalankan ke data csAdmin sungguhan.

## Keputusan

1. **UI disatukan, data tidak.** SQL Server tetap sumber kebenaran; Supabase tidak menyimpan data nasabah csAdmin.
2. **Akun teknis, bukan token key.** Gateway login ke csAdmin seperti aplikasi desktop, jadi `token_key` csAdmin tidak perlu dibagikan ke stack ini.
3. **Permission di console.** Super Admin mengatur akses per akun console; tautan ke akun csAdmin per staf tidak diperlukan.
4. **Maker-checker dijaga gateway.** Kode akun console dipakai sebagai pelaku agar pengaju dan penyetuju terbaca di data csAdmin, dan self-approval ditolak.
5. **Ubah status cepat dibuka dengan rem.** Kebutuhan operasional (mis. menangguhkan login karena laporan nasabah) tidak bisa menunggu approval. Karena itu aksi ini memakai permission terpisah (`online_user.status`), alasan wajib, dan audit.
6. **Kirim ulang kredensial tanpa login tidak dibuka.** Reset password/PIN (kredensial baru ke email terdaftar) menggantikan pengiriman ulang kredensial lama.
