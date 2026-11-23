# Dokumentasi

## Panduan (mulai dari sini)

Baru mengenal sistem? Mulai dari [**panduan/pengetahuan-sistem.md**](panduan/pengetahuan-sistem.md): bagian-bagian sistem, fungsi setiap node, teknologi, dan susunan server.

[**panduan/**](panduan/README.md): pegangan untuk tim IT, Super Admin, dan staf. Isinya spesifikasi dan instalasi server, operasional harian, pembaruan dan rollback, catatan rilis, backup dan pemulihan, penanganan gangguan, checklist go-live, dan pelatihan Hub.

## Spesifikasi kebutuhan

[spesifikasi/](spesifikasi/README.md): BRD (kebutuhan bisnis) dan SRS (spesifikasi kebutuhan perangkat lunak) lengkap untuk seluruh sistem, dengan kode modul yang saling terlacak.

## Belajar

[belajar/](belajar/README.md): modul belajar 11 bagian, dari SQL lanjutan, fungsi dan trigger, RLS, PostgREST/JWT, transaksi dan PgBouncer, Realtime, sampai infrastruktur, pengujian, klien Flutter, dan proyek akhir. Latihannya bisa langsung dicoba di server dev.

## Kontrak integrasi

| Dokumen | Isi |
|---|---|
| [olt-integration.md](olt-integration.md) | Token sosial bertanda tangan untuk tim backend OLT |
| [api/](api/README.md) | Spesifikasi OpenAPI dan AsyncAPI chat untuk klien non-Flutter dan layanan lain |
| [integration/](integration/README.md) | API notifikasi transaksi dan bot resmi (`/integration/v1`) |
| [integration/kesehatan-sistem.md](integration/kesehatan-sistem.md) | API kesehatan sistem untuk aplikasi internal (dasbor monitoring) |
| [rendezvous-community/](rendezvous-community/README.md) | Library Flutter untuk aplikasi OLT |

## Desain per fitur

| Dokumen | Isi |
|---|---|
| [social/](social/README.md) | Feed, chat, realtime, pencarian, notifikasi |
| [cs-chat/](cs-chat/README.md) | Chat CS, tiket, `cs_api` |
| [community/](community/README.md) | Postingan resmi, pengumuman, kampanye notifikasi, moderasi |
| [content-safety.md](content-safety.md) | Kata terlarang, NSFW, DM, banding, integritas pasar |
| [evidence/](evidence/README.md) | Karantina bukti |
| [nasabah/](nasabah/README.md) | Menu Akun Nasabah (gateway csAdmin) |
| [push/](push/README.md) | Push notification ke HP |
| [backup/](backup/README.md) | Arsitektur backup dan pemulihan |
| [system-health/](system-health/README.md) | Kesehatan sistem, peta layanan, dan alert |
| [sdk-mobile/](sdk-mobile/rencana.md) | Rencana SDK native Android dan iOS untuk klien non-Flutter (masih diskusi) |
| [berbagi-trade/](berbagi-trade/operasional.md) | Berbagi Trade dan relay trade (dijeda): [rencana](berbagi-trade/rencana.md), [operasional](berbagi-trade/operasional.md), [draf dokumen hukum](berbagi-trade/draf-dokumen-hukum.md) |

## Pengujian

[testing/](testing/README.md): cara menjalankan uji keamanan, beban, dan chaos beserta laporannya.

## Arsip

[archive/](archive/): dokumen riwayat yang tidak lagi dipakai sehari-hari, yaitu prompt dan spesifikasi awal (`PROMPT*.md`), audit web CS, audit kesiapan produksi, dan daftar pekerjaan yang sudah selesai. Isinya bisa tidak sesuai dengan sistem saat ini.
