# Komunitas: postingan resmi, pengumuman, notifikasi, dan moderasi

Menu **Komunitas** di web CS (`/community`) dipakai staf perusahaan sekuritas untuk mengelola stream komunitas di aplikasi nasabah. Migrasi: `0057_cs_community`.

## Izin

Izin diberikan per akun staf oleh Super Admin di **Pengaturan → Akun CS → Ubah akun → Izin Komunitas**. Izin bisa diberikan ke peran apa pun, termasuk peran baru **Komunitas** untuk tim riset/marketing yang tidak menangani tiket CS.

| Izin | Kode | Untuk |
|---|---|---|
| Tulis postingan resmi | `community.post` | Membuat draf postingan, pengumuman, dan notifikasi atas nama akun resmi |
| Setujui & terbitkan | `community.publish` | Menyetujui, menerbitkan, menjadwalkan, menyematkan, dan menghapus postingan resmi; menyetujui notifikasi |
| Moderasi konten | `community.moderate` | Antrean laporan: sembunyikan, hapus, pulihkan, atau abaikan |
| Sanksi pengguna | `community.sanction` | Peringatan, bisukan, blokir, cabut sesi, cabut sanksi |
| Kelola akun resmi | `community.accounts` | Membuat/mengubah/menonaktifkan akun resmi dan memberi badge verifikasi |

Tab yang tampil mengikuti izin: Stream dan Notifikasi (`post`/`publish`), Moderasi (`moderate`/`sanction`), Akun resmi (`accounts`). Database menolak aksi tanpa izin (`403 community_forbidden`).

## Akun resmi

- Profil khusus (`olt_user_id = official:<id>`) yang **tidak bisa login** dari aplikasi. Selalu terverifikasi, tingkat kepercayaan 3, dan tercatat di `cs.official_accounts`.
- Aplikasi menampilkan badge **Resmi** (bukan centang verifikasi biasa) untuk akun ini, berdasarkan `public.get_official_accounts()`, sehingga tidak bisa ditiru lewat nama.
- **Nama tampilan, username, bio, dan foto** dikelola di **Komunitas → Akun resmi**. Dialognya punya pratinjau tampilan profil di aplikasi (badge Resmi, jumlah pengikut, dan postingan) serta penghitung karakter. Mengganti username diberi peringatan karena mention lama tidak lagi mengarah ke akun itu.
- **Foto** bisa dipilih sejak akun dibuat, lewat klik atau tarik-lepas. Pengaturannya:
  - dipotong bulat di browser (geser, zoom dengan slider/gulir/tombol +/−, atau tombol panah);
  - disimpan sebagai JPEG 512 × 512 di bucket `avatars/<id akun>/`, dan foto kecil diberi peringatan;
  - diunggah hanya saat Simpan, jadi membatalkan dialog tidak meninggalkan file;
  - foto lama dihapus setelah diganti atau dihapus (policy `olt_official_avatar_delete`);
  - URL disimpan dengan domain API publik (`PUBLIC_API_URL` di container web CS, diisi dari `SUPABASE_PUBLIC_URL`).
- Perubahan akun tercatat di audit `community.account_update` beserta nilai lama → baru (`changes`). Simpan tanpa perubahan tidak menambah audit.
- Akun nonaktif tidak bisa dipakai untuk postingan atau notifikasi baru; postingan lamanya tetap tampil.

## Postingan resmi dan pengumuman

Alur: **draf → diajukan → disetujui (terbit sekarang atau terjadwal) → terbit**. Penolakan wajib beralasan dan mengembalikan draf ke pembuatnya.

- **Aturan empat mata** (`community.four_eyes`, default aktif, diatur di **Pengaturan → Komunitas**): pembuat tidak bisa menyetujui postingannya sendiri. Bila dimatikan, staf yang juga punya izin terbit bisa langsung menerbitkan buatannya sendiri.
- **Pengumuman** wajib berjudul dan selalu disematkan. **Sematkan** di stream umum atau stream saham (`$KODE`), opsional sampai tanggal tertentu. Aplikasi menampilkan maksimal 3 sematan di atas stream (pengumuman lebih dulu), lewat `public.get_pinned_posts(scope, stock_code)`, dan tidak mengulanginya di daftar biasa.
- **Jadwal**: job pg_cron `cs-community` (tiap 15 detik) menerbitkan postingan yang jatuh tempo. Bila gagal (misalnya akun dinonaktifkan atau teks terkena kata terlarang baru), statusnya menjadi "Gagal terbit" dengan alasannya, dan pembuat bisa memperbaikinya.
- Gambar maksimal 4 (bucket `attachments`, folder `posts/<id akun>/`), teks 1–2.000 karakter, kata terlarang dicek sejak draf.
- Postingan yang dihapus dari web hilang dari stream dan diarsipkan di `private.content_archive`.
- Opsi **Kirim notifikasi saat terbit** membuat kampanye notifikasi otomatis ke semua pengguna, atau ke pemantau saham bila disematkan di stream saham.

## Notifikasi

Kampanye notifikasi (`cs.community_campaigns`) punya alur persetujuan yang sama, dengan:
- judul (3–80) dan isi (3–240), pratinjau di web;
- tujuan saat diketuk: kotak notifikasi, postingan resmi yang sudah terbit, atau tautan `https://`;
- penerima: semua pengguna atau pemantau saham tertentu (`public.stock_watchers`), dengan perkiraan jumlah penerima;
- kirim segera setelah disetujui atau dijadwalkan.

Pengiriman membuat notifikasi tipe `announcement` di kotak notifikasi aplikasi, bertahap 5.000 penerima per putaran job. Akun staf dan akun resmi tidak ikut menerima.

**Push ke layar HP** dikirim otomatis oleh layanan notifier untuk setiap notifikasi pengumuman, begitu file Firebase dipasang ([docs/push](../push/README.md)). Status kanal tampil di tab Notifikasi dan, lengkap, di **Pengaturan → Push notification**. Detail kampanye menampilkan jumlah push terkirim, menunggu, dan gagal (`cs_api.community_campaign_push`).

## Moderasi

- **Antrean laporan** (`cs_api.community_reports`) diurutkan menurut prioritas: jumlah laporan, tingkat kepercayaan pelapor, dan jenis laporan (penipuan dan pom-pom saham lebih berat).
- Tindakan **sembunyikan / hapus / pulihkan / abaikan** wajib beralasan dan memakai logika yang sama dengan `admin_api.resolve_target` (`private.resolve_report`).
- **Detail pengguna**: jumlah konten, laporan, konten terbaru, dan riwayat sanksi.
- **Sanksi**: otomatis mengikuti tangga sanksi (`moderation.sanction_ladder`), atau pilih peringatan / bisukan 24 jam / bisukan 7 hari / blokir 7 hari / blokir permanen. Blokir mencabut sesi. Akun staf dan akun resmi tidak bisa diberi sanksi.

## Audit

Semua aksi tercatat di `cs_audit_log` dan tampil di **Kepatuhan → Jejak Audit**, termasuk:
- izin: `agent.community_permissions`;
- akun resmi: `community.account_*`, `community.verify_user`;
- postingan: `community.post_*`;
- notifikasi: `community.campaign_*`;
- moderasi: `community.report_resolve`, `community.sanction`, `community.sanction_revoke`, `community.sessions_revoke`.

Tindakan terhadap pengguna dicatat dengan `customer_id` pengguna tersebut.

## Aplikasi nasabah (`rendezvous_community`)

- `FeedRepository.getPinned(scope)` dan kartu **Pengumuman / Disematkan** di atas `CommunityFeedList` (stream umum dan stream saham).
- Badge **Resmi** di semua nama pengguna, dari `OfficialAccounts`. Dimuat sekali per sesi, bisa diganti lewat `CommunityOfficialScope` untuk tes atau aplikasi host.
- Notifikasi tipe `announcement`: judul dan isi dari kampanye. Saat diketuk membuka postingan, atau tautan `https` di browser.
