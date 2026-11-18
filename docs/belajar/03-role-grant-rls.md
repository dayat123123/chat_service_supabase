# Modul 3: Role, GRANT, dan RLS

**Tujuan:** mengerti bagaimana database tahu "siapa kamu" dan "apa yang boleh kamu lihat". Inilah inti keamanan sistem kita: aturan akses tidak ditulis di server aplikasi, tapi di database.

Ada tiga lapis pemeriksaan, dari kasar ke halus:

```
1. ROLE   → kamu login sebagai siapa?                 (anon / authenticated / service_role)
2. GRANT  → role itu boleh menyentuh objek ini?       (tabel, fungsi, schema)
3. RLS    → dari baris-baris di tabel, mana yang boleh? (per baris, pakai auth.uid())
```

---

## 3.1 Role

```sql
select rolname, rolsuper, rolbypassrls, rolcanlogin
from pg_roles
where rolname in ('postgres', 'anon', 'authenticated', 'service_role', 'authenticator')
order by 1;
```

| Role | Siapa | Catatan |
|---|---|---|
| `authenticator` | Akun login PostgREST | Hanya untuk masuk, lalu **berganti** ke role di bawah sesuai token |
| `anon` | Request tanpa token pengguna | Hampir tidak boleh apa-apa |
| `authenticated` | Pengguna yang login (nasabah, staf) | Dibatasi GRANT dan RLS |
| `service_role` | Layanan internal Go (notifier, media, …) | `bypassrls`: melewati RLS. **Jangan pernah** sampai ke aplikasi |
| `postgres` | Admin, migrasi, psql Anda | Pemilik tabel, `bypassrls` |

Alurnya: PostgREST login sebagai `authenticator`. Untuk setiap request, ia membaca klaim `role` di JWT lalu menjalankan `set role authenticated` (atau `anon`/`service_role`) sebelum memanggil fungsi.

## 3.2 GRANT: izin per objek

```sql
grant usage on schema public to authenticated;                       -- boleh "masuk" schema
grant select on public.messages to authenticated;                    -- boleh select tabel
grant insert (comment_audience) on public.posts to authenticated;    -- hanya kolom tertentu
grant execute on function public.get_dm_policy() to authenticated;   -- boleh memanggil fungsi
revoke execute on function private.integration_target(jsonb) from public;
```

Beberapa hal penting:
- Di Postgres, `public` dalam `revoke … from public` berarti **semua role**, bukan schema `public`. Fungsi baru otomatis bisa dieksekusi semua role, karena itu migrasi kita me-`revoke` fungsi internal dari `public`.
- Schema `private` tidak di-`grant` ke `authenticated`, jadi pengguna tidak bisa menyentuh isinya langsung, hanya lewat fungsi `security definer` (modul 2.5).
- **Grant per kolom** dipakai untuk membatasi kolom yang boleh ditulis pengguna. Di 0169, `create_post` sempat gagal `permission denied for column comment_audience` sampai kita menambah `grant insert (comment_audience) on public.posts`.

Melihat izin: `\dp public.messages` (tabel), `\df+ public.get_dm_policy` (fungsi, kolom *Access privileges*).

## 3.3 RLS: aturan per baris

Tanpa RLS, `grant select on public.messages` berarti pengguna bisa membaca **semua** pesan semua orang. RLS menambahkan filter otomatis yang tidak bisa dilewati.

```sql
alter table public.messages enable row level security;

create policy messages_select_member on public.messages
  for select to authenticated
  using (room_id in (select private.my_room_ids()) and …);
```

Begitu RLS aktif, setiap `select * from public.messages` oleh `authenticated` diam-diam menjadi `select * from public.messages where <policy>`.

| Bagian policy | Arti |
|---|---|
| `for select / insert / update / delete / all` | Perintah yang diatur |
| `to authenticated` | Role yang terkena |
| `using (…)` | Baris **lama** mana yang boleh dilihat/disentuh (select, update, delete) |
| `with check (…)` | Baris **baru** seperti apa yang boleh ditulis (insert, update) |
| `as permissive` (bawaan) | Beberapa policy permissive digabung dengan **OR** |
| `as restrictive` | Digabung dengan **AND**: syarat tambahan yang wajib lolos |

**Aturan emas:** RLS aktif tanpa policy sama sekali = **tidak ada baris yang terlihat** (aman secara bawaan).

Lihat policy kita:

```sql
select tablename, policyname, permissive, cmd, roles, qual
from pg_policies
where schemaname = 'public' and tablename in ('messages', 'chat_rooms', 'chat_members')
order by 1, 2;
```

Contoh nyata:
- `chat_rooms_select`: `type = 'stock' or id in (room saya)`. Room saham terlihat semua orang, room lain hanya oleh anggotanya.
- `messages_select_member`: pesan di room saya, **dan** pengirimnya tidak saling blokir dengan saya.
- `messages_update_own`: hanya pengirim yang boleh mengubah, dan hanya pesan yang belum dihapus.
- `comments_hidden_when_off` (0169): policy **restrictive**. Walaupun policy lain mengizinkan, komentar di post yang komentarnya dimatikan tetap tersembunyi. Policy ini baru ada setelah migrasi 0169 terpasang.

## 3.4 `auth.uid()`: dari token ke SQL

```sql
\sf auth.uid
```

```sql
select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid
```

PostgREST menaruh isi JWT ke setting sesi `request.jwt.claims`, dan `auth.uid()` hanya membaca `sub` dari situ. Tidak ada sihir: kita bisa menirunya sendiri di psql.

### Latihan utama: meniru Budi

```sql
select count(*) as semua_pesan from public.messages;      -- sebagai postgres: semua

begin;
select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims',
                  json_build_object('sub', (select id from public.profiles where username = 'budi_santoso'),
                                    'role', 'authenticated')::text, true);

select auth.uid(), current_user;
select count(*) as pesan_terlihat_budi from public.messages;   -- jauh lebih sedikit
select r.type, count(*) from public.chat_rooms r group by 1;   -- semua room saham + room Budi saja
select count(*) from private.dm_preferences;                   -- ERROR: permission denied (tidak ada GRANT)
rollback;
```

Argumen `true` di `set_config` berarti "hanya untuk transaksi ini", jadi `rollback` mengembalikan Anda menjadi `postgres`. Cara ini persis sama dengan yang dipakai tes pgTAP kita (`tests.authenticate_as` di [supabase/tests/helpers](../../supabase/tests/helpers)).

Coba juga sebagai `anon`:

```sql
begin;
set local role anon;
select count(*) from public.messages;    -- ERROR: permission denied (anon tidak punya GRANT)
rollback;
```

## 3.5 Membuat tabel ber-RLS sendiri

```sql
begin;
create temp table catatan_pribadi (
  id serial primary key,
  pemilik uuid not null default auth.uid(),
  isi text
);
insert into catatan_pribadi (pemilik, isi)
select id, 'rahasia ' || username from public.profiles where username in ('budi_santoso', 'sari_invest');

alter table catatan_pribadi enable row level security;
create policy pemilik_baca  on catatan_pribadi for select to authenticated using (pemilik = (select auth.uid()));
create policy pemilik_tulis on catatan_pribadi for insert to authenticated with check (pemilik = (select auth.uid()));
grant select, insert on catatan_pribadi to authenticated;
grant usage on sequence catatan_pribadi_id_seq to authenticated;

select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims',
                  json_build_object('sub', (select id from public.profiles where username = 'budi_santoso'))::text, true);

select * from catatan_pribadi;                                       -- hanya milik Budi
insert into catatan_pribadi (isi) values ('catatan baru budi') returning *;
savepoint a;
insert into catatan_pribadi (pemilik, isi)
values ((select id from public.profiles where username = 'sari_invest'), 'menyamar');
                                    -- ERROR: new row violates row-level security policy
rollback to a;

reset role;
select count(*) as dilihat_postgres from catatan_pribadi;            -- postgres melihat semua
rollback;
```

Perhatikan bentuk `(select auth.uid())`, bukan `auth.uid()` langsung. Dengan dibungkus `select`, Postgres menghitungnya **sekali per query**, bukan sekali per baris. Bedanya besar di tabel dengan jutaan baris. Semua policy kita memakai bentuk ini.

## 3.6 RLS + fungsi: siapa yang memeriksa?

| Fungsi | Mode | Siapa yang menyaring data |
|---|---|---|
| `get_messages` | `security invoker` (bawaan) | **RLS**: fungsi berjalan sebagai pengguna |
| `get_dm_policy`, `react_to_message` | `security definer` | **Kode fungsi**: RLS dilewati, jadi fungsi wajib mengecek sendiri |

Fungsi `security definer` yang lupa mengecek hak adalah celah keamanan nomor satu di sistem seperti ini. Karena itu setiap fungsi baru punya tes pgTAP yang mencoba memanggilnya sebagai pengguna yang **tidak** berhak (lihat tes 146: matriks audiens × peran).

## 3.7 RLS juga menjaga Realtime dan Storage

- **Realtime:** tabel `realtime.messages` punya policy `olt_realtime_receive` yang memanggil `private.can_access_topic(realtime.topic())`. Saat aplikasi join `room:<id>`, Realtime menjalankan pemeriksaan ini dengan JWT pengguna. Bukan anggota = ditolak.
- **Storage:** `storage.objects` punya policy yang hanya mengizinkan anggota room membaca file di `rooms/<room_id>/…`, dan hanya upload yang membawa klaim `media_verified` (lewat layanan media) yang boleh menulis.

Jadi satu konsep yang sama menjaga tiga pintu: HTTP, WebSocket, dan file.

---

## Latihan

1. Tiru `sari_invest`, lalu hitung pesan yang terlihat. Bandingkan dengan Budi. Kenapa berbeda?
2. Sebagai Budi, coba `update public.messages set body = 'diubah' where sender_id <> auth.uid()`. Berapa baris yang berubah, dan kenapa tidak error?
3. Baca `\sf private.my_room_ids` dan `\sf private.can_access_topic`. Topik apa saja yang boleh di-join seorang pengguna?
4. Tambahkan ke latihan 3.5 sebuah policy `update` sehingga pengguna hanya bisa mengubah catatannya sendiri **dan** tidak boleh memindahkan `pemilik` ke orang lain. Petunjuk: `using` **dan** `with check`.
5. Buat policy restrictive di latihan 3.5 yang menyembunyikan catatan berisi kata "arsip", lalu buktikan bahwa policy permissive tidak bisa mengalahkannya.

<details>
<summary>Jawaban nomor 2</summary>

`0` baris. RLS `messages_update_own` (`using sender_id = auth.uid()`) membuat baris milik orang lain tidak "terlihat" oleh `update`, jadi tidak ada yang cocok dengan `where`. RLS tidak melempar error untuk baris yang tidak terlihat. Error hanya muncul untuk `with check` (baris baru yang melanggar).
</details>

## Cek pemahaman

- Apa beda `using` dan `with check`?
- Kenapa `service_role` tidak boleh ada di aplikasi?
- Policy A (permissive) mengizinkan, policy B (restrictive) menolak. Hasilnya?
- Kenapa `(select auth.uid())` lebih cepat daripada `auth.uid()` di policy?

**Bacaan:** PostgreSQL docs *Row Security Policies*, *GRANT*; Supabase docs *Row Level Security* dan *Realtime Authorization*.
