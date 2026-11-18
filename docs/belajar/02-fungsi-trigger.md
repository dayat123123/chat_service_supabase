# Modul 2: Fungsi dan Trigger

**Tujuan:** bisa membaca dan menulis fungsi seperti `send_message` dan trigger seperti `messages_26_slow_mode`. Di sistem kita, **fungsi adalah endpoint API** (modul 4), dan **trigger adalah aturan bisnis yang tidak bisa dilewati**.

Semua latihan dibuat di schema sementara `pg_temp` (hilang saat sesi ditutup) dan dibungkus `begin … rollback`.

---

## 2.1 Anatomi fungsi

```sql
create or replace function public.get_dm_policy()   -- schema.nama(parameter)
returns jsonb                                        -- tipe hasil
language plpgsql                                     -- bahasa: sql atau plpgsql
stable                                               -- volatility (2.4)
security definer                                     -- hak siapa yang dipakai (2.5)
set search_path = ''                                 -- keamanan (2.5)
as $$
begin
  ...
end;
$$;
```

`$$ … $$` adalah tanda kutip khusus untuk badan fungsi, supaya kita tidak perlu meng-escape `'` di dalamnya.

### `language sql` vs `language plpgsql`

| | `sql` | `plpgsql` |
|---|---|---|
| Isi | Satu (atau beberapa) query | Program: variabel, `if`, loop, error |
| Kapan dipakai | Fungsi kecil, helper | Logika dengan langkah dan pemeriksaan |
| Contoh kita | `private.make_cursor`, `private.comments_all_off` | `send_message`, `react_to_message` |

```sql
begin;
create function pg_temp.salam(p_nama text default 'teman')
returns text language sql immutable as $$ select 'Halo, ' || p_nama || '!' $$;

select pg_temp.salam(), pg_temp.salam('Budi'), pg_temp.salam(p_nama := 'Sari');
rollback;
```

`p_nama := 'Sari'` adalah **pemanggilan dengan nama parameter**. Cara inilah yang dipakai PostgREST saat menerima body JSON `{"p_nama": "Sari"}`. Itu sebabnya semua parameter kita diberi awalan `p_`: supaya tidak bentrok dengan nama kolom di dalam query.

## 2.2 PL/pgSQL dasar

```sql
begin;
create function pg_temp.jumlah_pesan(p_username text)
returns integer
language plpgsql
stable
as $$
declare
  v_id uuid;
  v_n  integer;
begin
  select p.id into v_id from public.profiles p where p.username = p_username;
  if not found then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  select count(*) into v_n from public.messages m where m.sender_id = v_id and m.deleted_at is null;
  return v_n;
end;
$$;

select pg_temp.jumlah_pesan('budi_santoso');
rollback;
```

| Konstruksi | Arti |
|---|---|
| `declare v_x tipe := nilai;` | Variabel lokal (konvensi kita: awalan `v_`) |
| `select … into v_x` | Simpan hasil query ke variabel |
| `found` | `true` bila pernyataan terakhir menyentuh minimal satu baris |
| `perform f(...)` | Panggil fungsi dan buang hasilnya (`select` tanpa tujuan tidak boleh di plpgsql) |
| `if … then … elsif … else … end if;` | Percabangan |
| `for v_row in select … loop … end loop;` | Ulangi per baris hasil query |
| `foreach v_id in array v_ids loop … end loop;` | Ulangi per elemen array |
| `continue;` / `exit;` | Lanjut ke putaran berikut / keluar loop |
| `get diagnostics v_n = row_count;` | Jumlah baris yang disentuh pernyataan terakhir |
| `return x;` | Kembalikan nilai |
| `return query select …;` | Kembalikan banyak baris (untuk `returns table` / `setof`) |

## 2.3 Jenis hasil

| `returns …` | Hasil di PostgREST | Contoh kita |
|---|---|---|
| `integer`, `uuid`, `boolean`, `text` | Nilai tunggal JSON (`42`, `"…"`, `true`) | `get_unread_chat_count`, `create_group_room` |
| `jsonb` | Objek/array JSON apa adanya | `get_dm_policy`, `react_to_message` |
| `setof public.chat_message` | Array baris dengan kolom tipe komposit | `get_messages`, `send_message` |
| `table (kolom tipe, …)` | Array baris | `get_room_members`, `get_unread_counts` |
| `void` | `204 No Content` | `mark_room_read`, `hide_room` |

```sql
begin;
create function pg_temp.room_saya(p_username text)
returns table (room_id uuid, tipe text, nama text)
language plpgsql stable as $$
begin
  return query
  select r.id, r.type, coalesce(r.name, r.stock_code, '(DM)')
  from public.chat_members cm
  join public.chat_rooms r on r.id = cm.room_id
  join public.profiles p on p.id = cm.user_id
  where p.username = p_username
  order by r.type;
end;
$$;
select * from pg_temp.room_saya('budi_santoso') limit 5;
rollback;
```

Tipe komposit seperti `public.chat_message` adalah "bentuk baris" yang dipakai bersama banyak fungsi. Lihat isinya dengan `\d public.chat_message`. Di 0170 kita menambah kolom ke tipe `public.feed_post` dengan `alter type … add attribute`, dan semua fungsi feed otomatis ikut.

## 2.4 Volatility: `immutable`, `stable`, `volatile`

Ini janji kepada Postgres tentang perilaku fungsi:

| Label | Janji | Akibat |
|---|---|---|
| `immutable` | Input sama → hasil sama selamanya, tidak membaca tabel | Boleh dipakai di index, hasil bisa dihitung sekali |
| `stable` | Tidak mengubah data; hasil sama dalam satu query | Boleh dipanggil **GET** di PostgREST (transaksi read-only) |
| `volatile` (bawaan) | Boleh mengubah data | Wajib POST |

Label yang salah adalah bug: fungsi `stable` yang ternyata menulis data akan gagal saat dipanggil lewat GET.

## 2.5 `SECURITY DEFINER` dan `search_path`

Bawaannya, fungsi berjalan dengan hak **pemanggil** (`security invoker`). Dengan `security definer`, fungsi berjalan dengan hak **pemilik fungsi**, yaitu `postgres`.

Kenapa dibutuhkan? Pengguna (`authenticated`) tidak punya akses ke schema `private`. Tapi `get_dm_policy` perlu membaca `private.dm_preferences`. Dengan `security definer`, fungsi itu bisa membacanya, dan **fungsi itu sendiri** yang membatasi apa yang dikembalikan (hanya kebijakan milik `auth.uid()`).

Ibaratnya petugas loket yang memegang kunci gudang: nasabah tidak bisa masuk gudang, tapi petugas mengambilkan barang yang memang hak nasabah.

**Bahayanya:** karena fungsi berhak penuh, setiap fungsi `security definer` wajib:

1. **Mengecek siapa pemanggilnya** (`auth.uid()`, keanggotaan room, dan seterusnya) sebelum menyentuh data.
2. **`set search_path = ''`**, lalu menulis semua nama lengkap dengan schema (`public.messages`, `private.api_error`). Tanpa ini, penyerang bisa membuat tabel atau fungsi tiruan bernama `messages` di schema lain yang lebih dulu dicari, sehingga fungsi berhak penuh itu tertipu memakai tiruannya.

Coba bandingkan:

```sql
\sf public.get_dm_policy
\sf public.get_messages
```

`get_messages` **tidak** memakai `security definer`. Ia berjalan sebagai pengguna, sehingga RLS (modul 3) ikut menyaring pesan yang boleh dilihat.

## 2.6 Error yang dipahami klien

```sql
\sf private.api_error
```

```sql
raise exception using errcode = 'PT' || p_status::text, message = p_code, detail = …;
```

- `raise exception` menghentikan fungsi dan **membatalkan seluruh transaksi**: semua yang sudah ditulis ikut batal.
- `errcode` adalah SQLSTATE lima karakter. PostgREST punya aturan khusus: SQLSTATE `PTxyz` menjadi status HTTP `xyz`.
- `message` berisi kode stabil (`not_member`), yang dibaca program klien. `detail` berisi teks untuk manusia.

Di psql, sebuah error membuat transaksi "rusak" sampai di-rollback. Pakai `savepoint` untuk mencoba error tanpa kehilangan latihan sebelumnya:

```sql
begin;
-- (buat pg_temp.jumlah_pesan dari 2.2 dulu)
savepoint s1;
select pg_temp.jumlah_pesan('tidak_ada');   -- ERROR: user_not_found
rollback to s1;                             -- kembali ke titik aman
select 1;                                   -- transaksi bisa dipakai lagi
rollback;
```

Menangkap error di dalam fungsi: `begin … exception when others then … end;`. Contohnya `private.room_broadcast` sengaja menelan error supaya kegagalan siaran tidak menggagalkan pengiriman pesan.

## 2.7 Trigger

Trigger adalah fungsi yang dijalankan otomatis oleh Postgres saat tabel berubah.

| Pilihan | Arti |
|---|---|
| `before` | Sebelum baris ditulis. Boleh mengubah `new` atau menolak dengan error |
| `after` | Setelah baris ditulis. Untuk efek samping: notifikasi, broadcast, hitungan |
| `for each row` | Dijalankan per baris (yang kita pakai) |
| `insert / update [of kolom] / delete` | Kejadian pemicunya |
| `new` / `old` | Baris baru / lama |
| `tg_op` | `'INSERT'`, `'UPDATE'`, `'DELETE'` |
| `return new;` | (before) lanjutkan dengan baris ini |
| `return null;` | (before) batalkan baris ini diam-diam; (after) hasil diabaikan |

```sql
begin;
create temp table catatan (id serial primary key, isi text not null, diubah_at timestamptz, versi int not null default 1);

create function pg_temp.catatan_sebelum_ubah() returns trigger language plpgsql as $$
begin
  new.isi := btrim(new.isi);
  if new.isi = '' then
    raise exception using errcode = 'PT400', message = 'empty_body';
  end if;
  if tg_op = 'UPDATE' then
    new.diubah_at := now();
    new.versi := old.versi + 1;
  end if;
  return new;
end;
$$;

create trigger catatan_10_rapikan
  before insert or update on catatan
  for each row execute function pg_temp.catatan_sebelum_ubah();

insert into catatan (isi) values ('   halo   ') returning *;
update catatan set isi = 'halo lagi' where id = 1 returning *;
savepoint s2;
insert into catatan (isi) values ('    ');   -- ERROR: empty_body
rollback to s2;
rollback;
```

### Urutan trigger = urutan nama

Postgres menjalankan trigger dengan jenis yang sama **berurutan menurut nama**. Kita memanfaatkannya dengan awalan angka:

```sql
select tgname from pg_trigger
where tgrelid = 'public.messages'::regclass and not tgisinternal
order by tgname;
```

`messages_05_support` → `08_room_mute` → `10_rate_limit` → `20_before_write` → … → `26_slow_mode` → `30_content_policy` → `60_broadcast`. Pemeriksaan yang murah dan paling sering menolak diletakkan di depan, sedangkan efek samping (broadcast) di belakang. Saat menambah aturan baru, pilih nomor yang menempatkannya di urutan yang benar. Contohnya 0169 memakai `comments_25_comment_audience`, sengaja sebelum `comments_25_integrity`.

### Kenapa aturan ditaruh di trigger, bukan di `send_message`?

Karena trigger **tidak bisa dilewati**. Pesan bisa masuk lewat `send_message`, `share_post_to_chat`, insert REST langsung, atau fungsi CS. Semua jalur itu tetap melewati trigger `messages_26_slow_mode`. Tes 147 kita membuktikannya: insert komentar langsung lewat REST tetap ditolak saat komentar dimatikan.

## 2.8 Mendefinisikan ulang fungsi di migrasi

`create or replace function` mengganti isi fungsi yang sudah ada. Karena itu **definisi yang berlaku adalah migrasi bernomor terbesar** yang menyentuh fungsi itu. Contohnya `integration_notify` didefinisikan di 0068, diganti di 0086, lalu diganti lagi di 0171.

Cara mencarinya: `\sf nama` di psql (paling akurat), atau cari di folder migrasi tanpa membedakan huruf besar/kecil. Beberapa migrasi menulis `CREATE OR REPLACE` dengan huruf kapital.

Aturan tim: migrasi yang sudah terpasang tidak pernah diedit. Perubahan selalu dibuat sebagai migrasi baru.

---

## Latihan

1. Buat `pg_temp.inisial(p_nama text) returns text` yang mengubah "budi santoso" menjadi "BS". Petunjuk: `string_to_array`, `left`, `upper`, `string_agg`.
2. Buat `pg_temp.statistik_room(p_room_id uuid) returns jsonb` yang mengembalikan `{"anggota": n, "pesan": n, "terakhir": timestamp}`. Error `room_not_found` (404) bila room tidak ada.
3. Buat temp table `saldo(user_id uuid primary key, nilai int)` dan trigger `before update` yang menolak (`PT409`, `insufficient_balance`) bila `nilai` menjadi negatif.
4. Baca `\sf public.react_to_message`, lalu jawab:
   - Di mana fungsi ini memeriksa apakah pemanggil adalah anggota room?
   - Kenapa reaksi di pesan yang `moderation_status`-nya bukan `visible` hanya boleh oleh pengirimnya?
   - Apa yang terjadi bila emoji yang dikirim sama dengan yang sudah ada?
5. Jalankan `\d public.messages` dan pilih tiga trigger. Buka fungsinya dengan `\sf` dan tulis satu kalimat tentang tugas masing-masing.

<details>
<summary>Contoh jawaban nomor 2</summary>

```sql
begin;
create function pg_temp.statistik_room(p_room_id uuid) returns jsonb
language plpgsql stable as $$
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id) then
    perform private.api_error(404, 'room_not_found');
  end if;
  return jsonb_build_object(
    'anggota',  (select count(*) from public.chat_members m where m.room_id = p_room_id),
    'pesan',    (select count(*) from public.messages m where m.room_id = p_room_id and m.deleted_at is null),
    'terakhir', (select max(m.created_at) from public.messages m where m.room_id = p_room_id));
end;
$$;
select pg_temp.statistik_room(id) from public.chat_rooms where type = 'group' limit 2;
rollback;
```
</details>

## Cek pemahaman

- Kenapa `get_messages` tidak perlu `security definer`, sedangkan `get_dm_policy` perlu?
- Apa yang terjadi pada pesan yang sudah di-insert bila trigger `after` sesudahnya memanggil `raise exception`?
- Kenapa nama trigger diberi angka?

**Bacaan:** PostgreSQL docs bab *PL/pgSQL*, *Trigger Functions*, *Function Volatility Categories*, *Writing SECURITY DEFINER Functions Safely*.
