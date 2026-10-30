# Pertanyaan untuk Tim Kepatuhan & Legal: Customer Care OLT

> **Untuk:** tim kepatuhan (compliance) dan legal sekuritas.
> **Dari:** tim pengembang OLT.
> **Dasar:** [PROMPT-CUSTOMER-CARE.md](../PROMPT-CUSTOMER-CARE.md) (Addendum 3), bagian 1, 4, dan 10.

Kami sedang membangun layanan pelanggan di dalam aplikasi OLT. Isinya:
- pusat bantuan, live chat, dan tiket;
- **pengaduan resmi**;
- panel kerja untuk agen CS, supervisor, dan tim kepatuhan.

Sistem akan menghitung tenggat pengaduan, membuat bukti terima dan surat resmi, dan menyiapkan laporan secara otomatis. Agar perilakunya sesuai ketentuan, kami butuh konfirmasi atas hal-hal di bawah.

## Cara menjawab

- Setiap pertanyaan memuat **usulan kami**. Cukup jawab "setuju", atau tuliskan aturan yang benar, sebaiknya dengan rujukan pasalnya.
- Semua nilai (tenggat, format nomor, teks surat, retensi) dibuat **dapat diubah tanpa mengubah program**, sehingga jawaban yang datang belakangan tidak menghambat pembangunan.
- Layanan **tidak akan dibuka untuk nasabah** sebelum semua pertanyaan terjawab.
- Label waktu menunjukkan kapan jawaban dibutuhkan:
  - **Sebelum C1**: fondasi (mesin tenggat, klasifikasi, penomoran, bukti terima, retensi). Paling mendesak.
  - **Sebelum C2**: aplikasi nasabah (kontak resmi, tombol darurat).
  - **Sebelum C3**: live chat dan panel CS (verifikasi identitas, masking, transkrip).
  - **Sebelum C4**: surat resmi lanjutan, laporan, dan publikasi.
  - **Sebelum peluncuran**: wajib terjawab sebelum layanan dibuka.

Ringkasan yang paling mendesak (**Sebelum C1**): A1–A5, B1–B4, C1–C7, D1–D3, E1 (bukti terima), G1, G2, H2.

---

## A. Dasar regulasi dan klasifikasi

**A1. Regulasi yang berlaku.** Spesifikasi kami merujuk ke regulasi berikut:
- POJK 22 Tahun 2023;
- POJK 18/POJK.07/2018;
- SEOJK 20/SEOJK.08/2025 (berlaku 1 Januari 2027);
- UU PDP;
- ketentuan SRO (BEI, KSEI, KPEI).

Mohon konfirmasi daftar dan versi yang berlaku. Apakah ada ketentuan POJK 18/POJK.07/2018 yang sudah dicabut atau digantikan? Apakah ada SOP pengaduan internal yang harus diikuti sistem?

*Usulan:* daftar di atas; SOP internal yang ada menjadi acuan alur.

*Waktu:* Sebelum C1.

**A2. Kriteria pembeda pengaduan.** Kami memakai definisi pengaduan sebagai ungkapan ketidakpuasan yang disebabkan adanya kerugian dan/atau potensi kerugian. Mohon kriteria praktis, sebaiknya dengan contoh kasus, agar agen konsisten membedakan:
- pengaduan;
- pertanyaan;
- permintaan layanan;
- laporan masalah teknis;
- laporan penipuan;
- saran.

*Usulan:* kami menyiapkan daftar contoh kasus per jenis untuk dikoreksi.

*Waktu:* Sebelum C1.

**A3. Menurunkan klasifikasi pengaduan.** Pengaduan hanya bisa diubah menjadi jenis lain dengan persetujuan, wajib disertai alasan, dan tercatat. Apakah persetujuan supervisor CS cukup, atau harus oleh fungsi kepatuhan? Apakah nasabah wajib diberi tahu?

*Usulan:* disetujui supervisor, kepatuhan otomatis diberi tahu, dan nasabah melihat perubahannya di riwayat tiket.

*Waktu:* Sebelum C1.

**A4. Pengaduan atas pilihan nasabah.** Nasabah bisa menekan "Ajukan sebagai pengaduan resmi" kapan saja. Apakah ada kondisi yang membolehkan sekuritas menolak atau mengubah pilihan itu?

*Usulan:* tidak bisa ditolak. Perubahan hanya lewat A3.

*Waktu:* Sebelum C1.

**A5. Laporan penipuan dan peretasan.** Apakah laporan transaksi tidak dikenal, peretasan akun, CS palsu, dan phishing otomatis menjadi pengaduan dengan tenggat regulasi? Apakah ada kewajiban meneruskannya ke pihak lain (misalnya OJK, Satgas PASTI, kepolisian, bank RDN), dan dalam berapa lama?

*Usulan:* transaksi tidak dikenal dan peretasan = pengaduan. CS palsu atau phishing tanpa kerugian = laporan penipuan (bukan pengaduan), tetapi tetap prioritas tertinggi. Kewajiban penerusan mengikuti jawaban Anda.

*Waktu:* Sebelum C1.

**A6. Keluhan di kanal tidak resmi.** Apakah keluhan yang diketahui CS dari kanal tidak resmi (post di fitur sosial OLT, media sosial publik) wajib dicatat sebagai pengaduan?

*Usulan:* tidak wajib. CS boleh membuat tiket atas nama nasabah dengan kanal sumber "media sosial".

*Waktu:* Sebelum peluncuran.

## B. Kanal dan jenis pengaduan (lisan atau tertulis)

**B1. Lisan atau tertulis per kanal.** Spesifikasi menganggap live chat sebagai pengaduan **lisan** (tenggat 5 hari kerja). Karena chat berbentuk teks dan tersimpan, mohon konfirmasi apakah live chat di aplikasi termasuk lisan atau tertulis. Mohon juga konfirmasi kanal lain: formulir tiket di aplikasi, email, telepon, surat fisik, dan datang langsung.

*Usulan:* telepon, datang langsung, dan live chat = lisan. Formulir di aplikasi, email, dan surat = tertulis.

*Waktu:* Sebelum C1.

**B2. Dokumen pendukung per kategori.** Pengaduan tertulis dihitung sejak dokumen pendukung diterima lengkap. Mohon daftar dokumen wajib per kategori, misalnya:
- masalah dana: bukti transfer dan mutasi rekening;
- transaksi: nomor order dan konfirmasi transaksi.

Siapa yang berwenang menyatakan dokumen "lengkap"?

*Usulan:* daftar disusun bersama per kategori. Agen menyatakan "lengkap" lewat tombol khusus yang tercatat.

*Waktu:* Sebelum C1.

**B3. Mengubah pengaduan lisan menjadi tertulis.** Bila pengaduan lisan membutuhkan dokumen, sistem memandu agen mengubahnya menjadi pengaduan tertulis. Apakah perubahan ini butuh persetujuan atau tanda tangan nasabah? Apakah nasabah wajib diberi tahu secara tertulis bahwa tenggatnya berubah?

*Usulan:* nasabah menyetujui di aplikasi (satu klik). Pemberitahuan tertulis dikirim otomatis lewat aplikasi dan email.

*Waktu:* Sebelum C1.

**B4. Bukti penerimaan untuk pengaduan lisan.** Apakah pengaduan lisan (telepon, chat) juga wajib diberi bukti penerimaan bernomor, dan dalam berapa lama?

*Usulan:* ya, seketika saat tiket menjadi pengaduan, lewat aplikasi, email, dan PDF.

*Waktu:* Sebelum C1.

**B5. Pengaduan oleh perwakilan.** Apakah sistem harus menerima pengaduan yang diajukan pihak lain atas nama nasabah (kuasa, ahli waris, lembaga)? Dokumen apa yang dibutuhkan?

*Usulan:* hanya lewat pencatatan manual oleh CS dengan lampiran surat kuasa.

*Waktu:* Sebelum C3.

## C. Tenggat dan hari kerja

**C1. Nilai tenggat.** Mohon konfirmasi:
- pengaduan lisan diselesaikan paling lama 5 hari kerja;
- pengaduan tertulis paling lama 10 hari kerja sejak dokumen lengkap;
- perpanjangan paling lama 10 hari kerja;
- nasabah diberi 10 hari kerja untuk melengkapi dokumen.

*Usulan:* nilai di atas.

*Waktu:* Sebelum C1.

**C2. Definisi hari kerja.** Mohon konfirmasi hal-hal berikut:
- Apakah hari kerja = Senin–Jumat, dikurangi libur nasional dan cuti bersama?
- Apakah hari libur bursa ikut dikecualikan bila berbeda dari libur nasional?
- Apakah Sabtu dihitung bila CS melayani di hari Sabtu?
- Siapa yang memelihara kalender resmi, dan dari sumber apa (SKB libur nasional dan cuti bersama, kalender BEI)?

*Usulan:* Senin–Jumat, kecuali libur nasional, cuti bersama, dan hari libur bursa. Sabtu tidak dihitung walaupun CS buka. Kalender dikelola tim kepatuhan di panel.

*Waktu:* Sebelum C1.

**C3. Hari pertama dan batas jam.** Mohon konfirmasi cara menghitung hari pertama:
- Pengaduan masuk Jumat pukul 23.00, hari Sabtu, atau hari libur: mulai dihitung kapan?
- Apakah hari penerimaan dihitung sebagai hari ke-0 atau hari ke-1?
- Apakah ada batas jam (misalnya setelah 16.00 dianggap diterima hari kerja berikutnya)?
- Apakah semua dihitung dalam WIB, termasuk nasabah di WITA/WIT?

*Usulan:*
- hari penerimaan = hari ke-0;
- pengaduan di luar hari kerja dianggap diterima hari kerja berikutnya;
- tenggat jatuh pukul 23.59 WIB pada hari kerja ke-N;
- tanpa batas jam;
- semua dalam WIB.

*Waktu:* Sebelum C1.

**C4. Menunggu dokumen dari nasabah.** Selama menunggu dokumen, apakah tenggat dijeda lalu dilanjutkan, atau dihitung dari awal sejak dokumen lengkap? Bila dokumen tidak dilengkapi dalam 10 hari kerja, apa yang terjadi, dan apakah wajib ada pemberitahuan tertulis?

*Usulan:* tenggat 10 hari kerja pengaduan tertulis baru mulai berjalan saat dokumen lengkap. Bila 10 hari kerja lewat tanpa dokumen, pengaduan ditutup dengan surat pemberitahuan, dan nasabah bisa mengajukan ulang.

*Waktu:* Sebelum C1.

**C5. Kondisi perpanjangan.** Mohon daftar "kondisi tertentu" yang membolehkan perpanjangan. Daftar ini menjadi pilihan wajib saat agen memperpanjang. Berapa kali perpanjangan boleh dilakukan? Apakah pemberitahuan tertulis cukup lewat aplikasi dan email (PDF), atau perlu surat fisik?

*Usulan:* maksimal 1 kali, sebelum tenggat awal lewat, diberitahukan lewat aplikasi, email, dan PDF.

*Waktu:* Sebelum C1.

**C6. Keberatan dan membuka kembali.** Mohon konfirmasi aturan keberatan:
- Berapa lama nasabah boleh menyatakan keberatan setelah tanggapan akhir?
- Bila keberatan disertai dokumen baru, berapa tenggat barunya?
- Bila tanpa dokumen baru, apakah tetap dibuka kembali?

*Usulan:*
- keberatan dalam 7 hari kerja;
- dengan dokumen baru: tenggat baru sesuai jenisnya (tertulis: 10 hari kerja);
- tanpa dokumen baru: ditinjau supervisor dan dijawab paling lama 5 hari kerja.

*Waktu:* Sebelum C1.

**C7. Penutupan otomatis.** Tiket biasa yang 7 hari kerja menunggu jawaban nasabah akan diselesaikan otomatis. Apakah pengaduan boleh ditutup otomatis bila nasabah tidak merespons?

*Usulan:* pengaduan tidak pernah ditutup otomatis. Agen wajib mengirim tanggapan akhir.

*Waktu:* Sebelum C1.

**C8. Tenggat terlewat.** Bila tenggat terlewat, apakah ada kewajiban pelaporan atau pemberitahuan khusus ke nasabah atau ke OJK?

*Usulan:* peringatan internal ke kepatuhan dan manajemen, dan tercatat di laporan.

*Waktu:* Sebelum C4.

## D. Penomoran dan bukti

**D1. Format nomor pengaduan.** Nomor tiket kami berformat `CC-2026-10-000123`. Pengaduan mendapat nomor tersendiri. Mohon format yang dibutuhkan untuk pelaporan:
- awalan dan kode perusahaan;
- tahun/bulan;
- panjang nomor urut;
- apakah wajib urut tanpa celah, dan apakah direset tiap tahun.

Apakah nomor harus didaftarkan atau diperoleh dari sistem OJK?

*Usulan:* `PGD-2026-000123`, urut per tahun tanpa celah, direset setiap 1 Januari.

*Waktu:* Sebelum C1.

**D2. Isi bukti penerimaan pengaduan.** Usulan isi:
- nomor pengaduan dan nomor tiket;
- tanggal dan jam diterima (WIB);
- kanal dan jenis (lisan/tertulis);
- ringkasan pengaduan;
- dokumen yang sudah dan belum diterima;
- perkiraan tenggat;
- kontak unit pengaduan;
- peringatan anti-penipuan.

Mohon redaksi resmi dan elemen wajib lain yang belum ada.

*Waktu:* Sebelum C1.

**D3. Kop dan tanda tangan.** Apakah bukti terima, surat perpanjangan, dan tanggapan akhir wajib berkop resmi dan bertanda tangan? Bila ya, bentuk tanda tangan yang mana:
- tanda tangan elektronik tersertifikasi (penyelenggara sertifikasi elektronik terdaftar);
- tanda tangan hasil pindai;
- cukup nomor dokumen dan kode verifikasi yang bisa dicek keasliannya.

Siapa penandatangannya (nama/jabatan)?

*Usulan:* semua surat berkop, dengan nomor dokumen dan kode verifikasi. Tanda tangan elektronik tersertifikasi hanya untuk tanggapan akhir.

*Waktu:* Sebelum C1 (bukti terima); Sebelum C4 (surat lainnya).

**D4. Bahasa dokumen.** Apakah dokumen resmi wajib berbahasa Indonesia, dengan versi Inggris opsional?

*Usulan:* Bahasa Indonesia wajib. Terjemahan Inggris dilampirkan bila nasabah memilih bahasa Inggris.

*Waktu:* Sebelum C4.

## E. Template surat resmi

**E1. Redaksi template.** Mohon teks resmi (Indonesia, dan Inggris bila perlu) untuk:
- bukti penerimaan;
- permintaan dokumen;
- pemberitahuan perpanjangan;
- tanggapan akhir;
- tanggapan atas keberatan;
- pemberitahuan penutupan karena dokumen tidak lengkap.

*Usulan:* kami menyiapkan draf dengan isian otomatis (nomor pengaduan, tanggal, tenggat, dan sebagainya) untuk dikoreksi.

*Waktu:* bukti penerimaan Sebelum C1; lainnya Sebelum C4.

**E2. Hak nasabah untuk melanjutkan.** Mohon redaksi informasi hak nasabah bila tidak puas, yaitu penyelesaian melalui LAPS SJK dan/atau layanan pengaduan OJK. Sertakan kontak resmi dan batas waktu yang perlu dicantumkan.

*Waktu:* Sebelum C4.

**E3. Persetujuan perubahan template.** Siapa yang mengubah dan siapa yang menyetujui perubahan template? Apakah versi lama harus tersimpan, dan harus dapat ditelusuri surat mana memakai versi mana?

*Usulan:* diubah oleh staf kepatuhan dan disetujui pejabat kepatuhan lain. Semua versi disimpan permanen dan tertaut ke setiap surat.

*Waktu:* Sebelum C4.

## F. Pelaporan dan publikasi

**F1. Laporan ke OJK.** Mohon informasi berikut:
- laporan apa saja yang wajib (jenis, periode, batas waktu penyampaian);
- lewat sistem atau portal apa;
- format dan kolomnya;
- apakah ada daftar kategori pengaduan baku yang harus dipetakan dari kategori kami.

*Usulan:* ekspor CSV/XLSX/PDF dengan kolom yang bisa diatur. Pemetaan kategori dikelola tim kepatuhan.

*Waktu:* Sebelum C4.

**F2. Publikasi (SEOJK 20/SEOJK.08/2025).** Apa yang wajib dipublikasikan, di mana (situs, aplikasi), seberapa sering, dan dalam format apa?

*Waktu:* Sebelum C4 (ketentuan berlaku 1 Januari 2027).

**F3. Cakupan laporan.** Apakah laporan harus memuat pengaduan dari semua kanal (aplikasi, telepon, email, surat, datang langsung), termasuk yang dicatat manual oleh CS?

*Usulan:* ya, semua kanal dalam satu laporan, dengan kolom kanal.

*Waktu:* Sebelum C4.

## G. Retensi, arsip, dan pelindungan data pribadi

**G1. Masa retensi.** Berapa lama data berikut disimpan, dan dihitung sejak kapan? Apakah berbeda untuk pengaduan dan non-pengaduan?
- tiket;
- percakapan;
- lampiran;
- surat resmi;
- catatan audit.

*Usulan:*
- pengaduan, surat resmi, dan catatan audit: 10 tahun;
- tiket non-pengaduan: 5 tahun;
- dihitung sejak tiket ditutup.

*Waktu:* Sebelum C1.

**G2. Penghapusan akun.** Bila nasabah menghapus akun, data pengaduan yang wajib disimpan dipisahkan dan aksesnya diperketat. Mohon konfirmasi:
- data apa yang boleh tetap disimpan;
- siapa yang boleh mengaksesnya;
- apa yang terjadi setelah masa retensi habis: dihapus permanen atau dianonimkan.

*Usulan:* hanya tim kepatuhan yang bisa membuka. Setelah masa retensi, data dihapus permanen.

*Waktu:* Sebelum C1.

**G3. Dasar pemrosesan dan pemberitahuan privasi.** Apa dasar pemrosesan data di layanan pelanggan: kewajiban hukum, perjanjian, atau persetujuan? Apakah kebijakan privasi perlu diperbarui? Apakah aplikasi perlu menampilkan pemberitahuan privasi saat nasabah membuat tiket atau mengunggah lampiran?

*Waktu:* Sebelum peluncuran.

**G4. Penilaian dampak (DPIA).** Apakah diperlukan penilaian dampak pelindungan data pribadi sebelum layanan dibuka?

*Waktu:* Sebelum peluncuran.

**G5. Lokasi data dan pihak ketiga.** Apakah data, termasuk backup, wajib disimpan di Indonesia? Pihak ketiga yang direncanakan:
- penyedia email (SMTP);
- notifikasi push Android (Firebase Cloud Messaging, servernya di luar negeri);
- penyedia tanda tangan elektronik;
- WhatsApp Business (opsional, fase lanjut).

Persyaratan apa yang berlaku? Bolehkah notifikasi push memuat nomor tiket atau potongan pesan?

*Usulan:* semua data di Indonesia. Notifikasi push hanya berisi teks umum ("Ada balasan baru di tiket Anda") tanpa data pribadi.

*Waktu:* Sebelum peluncuran.

**G6. Hak subjek data.** Bagaimana menangani permintaan nasabah untuk mengakses, mengoreksi, atau menghapus data tiket dan pengaduan miliknya?

*Waktu:* Sebelum peluncuran.

## H. Akses data nasabah dan isi percakapan

**H1. Data yang disamarkan (masking).** Data apa saja yang wajib disamarkan di panel CS? Role mana yang boleh membuka data apa, dan alasan apa yang diterima?

*Usulan:*
- Disamarkan secara default: NIK, nomor rekening, email, nomor HP, SID, alamat, dan tanggal lahir.
- Membuka data hanya untuk satu kolom, berlaku 5 menit, dan wajib beralasan. Semuanya tercatat.
- Yang boleh membuka: agen yang menangani tiket, supervisor, dan kepatuhan.

*Waktu:* Sebelum C3.

**H2. Penyamaran isi percakapan.** OTP, PIN, password, nomor kartu, dan nomor rekening lengkap yang terketik di chat akan disamarkan **sebelum disimpan**, sehingga nilai aslinya tidak pernah tersimpan. Apakah ini dapat diterima sebagai catatan bukti, atau ada kewajiban menyimpan pesan asli tanpa perubahan?

*Usulan:* hanya versi yang sudah disamarkan yang disimpan, disertai catatan bahwa penyamaran terjadi.

*Waktu:* Sebelum C1.

**H3. Transkrip sebagai bukti.** Apakah transkrip chat dan riwayat tiket, yang tidak bisa diubah dan bercap waktu, sah sebagai catatan pengaduan? Apakah perlu bukti integritas tambahan?

*Usulan:* arsip yang hanya bisa ditambah, dilengkapi sidik digital (hash) harian.

*Waktu:* Sebelum C3.

**H4. Rekaman telepon.** Bila pengaduan masuk lewat call center, apakah rekaman telepon wajib ditautkan ke tiket? Integrasi telepon belum ada di rencana tahap awal.

*Waktu:* Sebelum peluncuran.

**H5. Ekspor data.** Siapa yang boleh mengekspor data dalam jumlah besar (laporan, daftar tiket)? Apakah perlu persetujuan kedua?

*Usulan:* hanya kepatuhan dan supervisor, dengan alasan. Ekspor yang memuat data pribadi butuh persetujuan pejabat kepatuhan.

*Waktu:* Sebelum C4.

## I. Verifikasi identitas dan tindakan darurat

**I1. Permintaan berisiko tinggi.** Mohon konfirmasi daftar permintaan yang wajib verifikasi identitas tambahan, atau tambahkan yang belum ada:
- perubahan data pribadi;
- perubahan rekening bank;
- reset akses;
- membuka blokir akun;
- informasi detail transaksi lewat kanal di luar aplikasi.

*Waktu:* Sebelum C3.

**I2. Verifikasi di aplikasi.** Nasabah menyetujui permintaan verifikasi di aplikasi OLT memakai PIN atau biometrik. Prosesnya ditangani OLT, sehingga PIN tidak pernah terlihat oleh CS. Apakah cara ini cukup, dan berapa lama permintaan berlaku?

*Usulan:* cukup. Permintaan berlaku 10 menit, dan hasilnya (berhasil/gagal/waktu) tercatat di tiket.

*Waktu:* Sebelum C3.

**I3. Kanal email dan telepon.** Nasabah yang menghubungi lewat email atau telepon belum terverifikasi. Prosedur apa yang berlaku? Misalnya: wajib verifikasi lewat aplikasi, atau panggilan balik ke nomor terdaftar.

*Usulan:* wajib verifikasi lewat aplikasi. Tanpa itu, informasi akun tidak diberikan.

*Waktu:* Sebelum C3.

**I4. Maker–checker perubahan data.** Siapa pembuat (maker) dan pemeriksa (checker) untuk perubahan data nasabah, misalnya rekening bank? Apakah SOP-nya sudah ada?

*Waktu:* Sebelum C3.

**I5. "Amankan akun saya".** Mohon konfirmasi aturan tombol darurat:
- tindakan apa yang boleh atau wajib dilakukan otomatis: keluarkan semua perangkat, kunci transaksi, atau kunci akun;
- siapa yang boleh membuka kunci, dan dengan verifikasi apa;
- apakah nasabah wajib diberi pemberitahuan tertulis.

*Waktu:* Sebelum C2.

## J. Anti-penipuan dan kanal resmi

**J1. Daftar kontak resmi.** Mohon daftar kanal resmi yang akan ditampilkan di aplikasi:
- email;
- call center;
- WhatsApp resmi (bila ada);
- akun media sosial resmi;
- situs;
- alamat kantor.

*Waktu:* Sebelum C2.

**J2. Teks edukasi.** Mohon persetujuan teks peringatan: *"CS kami tidak pernah meminta PIN, password, OTP, atau meminta transfer dana ke rekening pribadi."*

*Waktu:* Sebelum C2.

**J3. Identitas agen.** Setiap agen menampilkan ID dan kode verifikasi yang bisa dicek nasabah di aplikasi. Apakah nama asli agen boleh ditampilkan, atau wajib nama panggilan?

*Usulan:* nama panggilan dan ID agen.

*Waktu:* Sebelum C3.

## K. Kompensasi, jam layanan, dan aksesibilitas

**K1. Kompensasi.** Mohon kebijakan kompensasi: siapa yang menyetujui, batas nilai per level jabatan, dan pencatatan yang wajib.

*Waktu:* Sebelum C3.

**K2. Jam layanan.** Mohon konfirmasi jam layanan CS, dan bahwa penerimaan pengaduan tetap 24 jam.

*Usulan:* Senin–Jumat 08.00–22.00 WIB, Sabtu–Minggu 09.00–18.00 WIB. Cara menghitung pengaduan di luar jam layanan mengikuti C3.

*Waktu:* Sebelum C2.

**K3. Nasabah penyandang disabilitas dan lanjut usia.** Apakah ada kewajiban layanan khusus di kanal digital, selain dukungan pembaca layar, teks besar, kontras tinggi, dan permintaan panggilan balik?

*Waktu:* Sebelum peluncuran.

## L. Persetujuan legal untuk komponen tertentu

**L1. Pemindai malware berlisensi GPL (ClamAV).** Apakah legal menyetujui ClamAV dipakai sebagai layanan terpisah, tanpa modifikasi, untuk memindai lampiran? Bila tidak, kami mengandalkan:
- pembatasan jenis file;
- penulisan ulang gambar;
- pemeriksaan struktur PDF.

*Waktu:* Sebelum C3.

**L2. Chatbot (fase lanjut).** Bila nanti memakai AI generatif, persyaratan apa yang berlaku? Misalnya penanda bot, larangan memberi rekomendasi investasi, dan persetujuan nasabah.

*Waktu:* Sebelum C6.

**L3. WhatsApp Business (opsional).** Bila nanti dipakai, apakah dibutuhkan persetujuan khusus? Bagaimana memverifikasi nasabah di kanal itu?

*Waktu:* sebelum kanal itu dibangun.
