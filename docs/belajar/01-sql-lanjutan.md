# Modul 1: SQL Lanjutan

**Tujuan:** bisa membaca query di migrasi kita tanpa tersendat. Hampir semua fungsi server memakai enam teknik di bawah.

Buka psql (`.\make.ps1 psql`) dan coba setiap contoh. Semuanya hanya membaca, kecuali yang dibungkus `begin … rollback`.

---

## 1.1 JSONB: kolom berisi JSON

Postgres punya dua tipe JSON: `json` (teks apa adanya) dan `jsonb` (disimpan dalam bentuk biner, bisa di-index, urutan key tidak dijaga). Kita selalu memakai `jsonb`.

Contohnya kolom `messages.attachments`:

```sql
select id, attachments
from public.messages
where jsonb_array_length(attachments) > 0
limit 2;
```

### Operator yang wajib hafal

| Operator / fungsi | Hasil | Contoh |
|---|---|---|
| `->` | Ambil sebagai **jsonb** | `payload -> 'data'` → `{"stock": "BBCA"}` |
| `->>` | Ambil sebagai **teks** | `payload ->> 'kind'` → `olt.info` |
| `#>` / `#>>` | Ambil lewat path | `payload #>> '{data,stock}'` → `BBCA` |
| `?` | Punya key ini? | `target ? 'cust_id'` |
| `@>` | Mengandung (subset)? | `prefs @> '{"push": true}'` |
| `\|\|` | Gabung objek | `'{"a":1}'::jsonb \|\| '{"b":2}'` |
| `-` | Buang key | `payload - 'secret'` |
| `jsonb_build_object(k, v, …)` | Membuat objek | lihat di bawah |
| `jsonb_agg(x)` | Mengumpulkan baris jadi array | lihat 1.3 |
| `jsonb_array_elements(arr)` | Memecah array jadi baris | lihat 1.4 |
| `jsonb_typeof(x)` | `object`, `array`, `string`, `number`, `boolean`, `null` | validasi input |
| `jsonb_strip_nulls(x)` | Buang key bernilai null | merapikan respons |

```sql
select jsonb_build_object('id', p.id, 'username', p.username, 'jumlah_post', p.post_count)
from public.profiles p
where p.username = 'budi_santoso';
```

Hampir semua RPC kita yang mengembalikan `jsonb` dibangun dengan `jsonb_build_object`. Contohnya `get_dm_policy` (`\sf public.get_dm_policy`).

**Jebakan:** `->>` selalu menghasilkan teks. Untuk membandingkan angka harus di-cast dulu: `(m ->> 'ttl_seconds')::integer`. Lihat cara `private.integration_notify_error` memvalidasi tipe dulu dengan `jsonb_typeof` sebelum cast, di [0086_notify_targets.sql](../../supabase/migrations/0086_notify_targets.sql).

## 1.2 Array

Postgres punya tipe array asli: `uuid[]`, `text[]`.

| Sintaks | Arti |
|---|---|
| `array['a','b']` | Membuat array |
| `x = any(arr)` | `x` ada di array (pengganti `in (...)` untuk array) |
| `arr @> array['a']` | Array mengandung semua elemen kanan |
| `unnest(arr)` | Pecah array jadi baris |
| `array_agg(x order by y)` | Kumpulkan baris jadi array |
| `cardinality(arr)` | Jumlah elemen |

```sql
select r.type, count(*), array_agg(r.name order by r.name) filter (where r.name is not null)
from public.chat_rooms r
group by r.type;
```

Lihat `filter (where …)`: agregat hanya menghitung baris yang memenuhi syarat. Teknik ini sering dipakai untuk menghitung beberapa hal sekaligus dalam satu query.

## 1.3 CTE (`with`)

CTE adalah "tabel sementara bernama" dalam satu query, supaya query panjang bisa dibaca bertahap.

```sql
with aktif as (
  select sender_id, count(*) as n
  from public.messages
  where created_at > now() - interval '365 days'
  group by sender_id
)
select p.username, a.n
from aktif a
join public.profiles p on p.id = a.sender_id
order by a.n desc
limit 5;
```

CTE juga bisa berisi `insert/update/delete … returning`, sehingga beberapa perubahan bisa dirantai dalam satu pernyataan. Contohnya di `register_push_device`: `with cancelled as (update … returning q.id) select array_agg(id) …`.

## 1.4 `LATERAL`: subquery yang boleh melihat baris di kirinya

Subquery biasa di `from` tidak bisa memakai kolom tabel lain. `lateral` membolehkannya, sehingga untuk **setiap baris** kiri, subquery dijalankan dengan nilainya.

Contoh: pesan terakhir di setiap room.

```sql
select r.id, r.type, terakhir.body, terakhir.created_at
from public.chat_rooms r
cross join lateral (
  select m.body, m.created_at
  from public.messages m
  where m.room_id = r.id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) terakhir
limit 5;
```

Memecah array JSON juga memakai `lateral`:

```sql
select m.id, a.value ->> 'type' as tipe, a.value ->> 'code' as kode, a.value ->> 'path' as path
from public.messages m
cross join lateral jsonb_array_elements(m.attachments) a
where jsonb_array_length(m.attachments) > 0
limit 5;
```

Di [0170_comment_controls_account_off.sql](../../supabase/migrations/0170_comment_controls_account_off.sql), `private.feed_posts` memakai tiga `lateral` berurutan: `ao` (saklar akun), `ea` (audiens efektif), dan `cr` (pembatasan komentar). Setiap lateral memakai hasil lateral sebelumnya.

Pakai `left join lateral (…) x on true` bila baris kiri harus tetap muncul walaupun subquery kosong.

## 1.5 Upsert: `insert … on conflict`

"Masukkan, atau perbarui kalau sudah ada" dalam satu pernyataan, aman dari balapan dua request bersamaan.

```sql
begin;
create temp table latihan_skor (user_id uuid primary key, skor int not null default 0);
insert into latihan_skor (user_id, skor) select id, 1 from public.profiles limit 3;

insert into latihan_skor as s (user_id, skor)
select id, 1 from public.profiles limit 5
on conflict (user_id) do update set skor = s.skor + excluded.skor
returning user_id, skor;
rollback;
```

- `excluded` = baris yang **gagal** dimasukkan (nilai baru).
- `on conflict do nothing` = abaikan kalau sudah ada. Dipakai untuk idempotensi, misalnya `integration_receipts` di [0171](../../supabase/migrations/0171_notify_olt_user_target.sql): kalau `row_count = 0`, berarti id pesan pernah diterima, jadi jawabannya `duplicate`.
- `returning` mengembalikan baris hasil insert/update tanpa perlu `select` lagi.

## 1.6 Cursor pagination

`limit 20 offset 1000` lambat (Postgres tetap membaca 1.000 baris yang dibuang) dan rusak saat ada data baru masuk (baris bergeser, muncul ganda). Kita memakai **keyset pagination**: "beri saya 20 baris setelah baris terakhir yang saya lihat".

Kuncinya adalah **row comparison** dengan dua kolom supaya urutannya pasti walaupun `created_at` kembar:

```sql
select m.id, m.created_at, private.make_cursor(m.created_at, m.id)
from public.messages m
order by m.created_at desc, m.id desc
limit 3;

select m.id, m.created_at
from public.messages m
where (m.created_at, m.id) < (select created_at, id from public.messages
                              order by created_at desc, id desc offset 2 limit 1)
order by m.created_at desc, m.id desc
limit 3;
```

`private.make_cursor` hanya menggabungkan waktu dan id menjadi teks `2026-11-17T06:22:58.431728Z|98921ec4-…`, dan `private.parse_cursor` membaliknya. Klien diberi tahu cursor itu *opaque* supaya kita bebas mengubah formatnya. Baca `\sf public.get_messages` untuk melihat versi lengkapnya.

## 1.7 Bonus yang sering muncul

```sql
select distinct on (m.room_id) m.room_id, m.body, m.created_at
from public.messages m
order by m.room_id, m.created_at desc
limit 3;

select username, row_number() over (order by follower_count desc) as peringkat, follower_count
from public.profiles
where deleted_at is null
limit 5;

select coalesce(nullif(btrim('   '), ''), 'kosong');

select g, now() - make_interval(days => g) from generate_series(1, 3) g;
```

| Teknik | Kegunaan |
|---|---|
| `distinct on (kolom)` | Ambil satu baris per grup (yang pertama menurut `order by`) |
| Window function (`over (...)`) | Peringkat, total berjalan, tanpa menggabungkan baris |
| `coalesce` / `nullif` | Nilai pengganti untuk null / ubah nilai tertentu jadi null |
| `generate_series` | Membuat deret angka atau tanggal, sering dipakai di tes |
| `make_interval(days => n)` | Durasi dari angka |
| `exists (select 1 …)` | Cek ada/tidak, berhenti di baris pertama (lebih cepat dari `count(*) > 0`) |

---

## Latihan

1. Tampilkan 10 pesan terakhir di room grup "Diskusi Perbankan" beserta username pengirimnya.
2. Untuk setiap pengguna, hitung jumlah room yang ia ikuti per jenis (`direct`, `group`, `stock`) dalam **satu baris per pengguna**. Petunjuk: `count(*) filter (where …)`.
3. Tampilkan semua kartu saham (`attachments` dengan `type = 'stock'`) yang pernah dikirim di chat, beserta kode dan jumlah kemunculannya.
4. Buat query halaman 2 room saya (anggap saya `budi_santoso`), 5 room per halaman, urut `coalesce(last_message_at, created_at) desc, id desc`, dengan cursor dari baris terakhir halaman 1.
5. Bangun satu objek JSON per room grup: `{"id", "name", "anggota": [username…]}` memakai `jsonb_build_object` + `jsonb_agg`.

<details>
<summary>Contoh jawaban nomor 2 dan 5</summary>

```sql
select p.username,
       count(*) filter (where r.type = 'direct') as dm,
       count(*) filter (where r.type = 'group')  as grup,
       count(*) filter (where r.type = 'stock')  as saham
from public.chat_members cm
join public.chat_rooms r on r.id = cm.room_id
join public.profiles p on p.id = cm.user_id
group by p.username
order by p.username;

select jsonb_build_object(
         'id', r.id, 'name', r.name,
         'anggota', (select jsonb_agg(p.username order by p.username)
                     from public.chat_members cm join public.profiles p on p.id = cm.user_id
                     where cm.room_id = r.id))
from public.chat_rooms r
where r.type = 'group';
```
</details>

## Cek pemahaman

- Apa beda `payload -> 'kind'` dan `payload ->> 'kind'`?
- Kenapa cursor memakai dua kolom (`created_at`, `id`), bukan `created_at` saja?
- Kapan `left join lateral … on true` dipakai, bukan `cross join lateral`?

**Bacaan:** PostgreSQL docs bab *JSON Functions and Operators*, *Array Functions*, *WITH Queries*, *LATERAL Subqueries*, *INSERT … ON CONFLICT*.
