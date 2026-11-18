# Modul 11: Proyek Akhir

Dua bagian:
- **Bagian A:** menelusuri satu fitur nyata dari ujung ke ujung.
- **Bagian B:** membangun fitur kecil sendiri di dalam `begin … rollback`, lengkap dengan tes.

---

## Bagian A: menelusuri "Kontrol komentar"

Fitur ini (migrasi 0169–0170, library 1.31–1.33) memakai hampir semua konsep modul 1–10. Jawab pertanyaan di bawah sambil membaca file-nya.

| Langkah | File | Pertanyaan |
|---|---|---|
| 1. Data | [0169_comment_controls.sql](../../supabase/migrations/0169_comment_controls.sql) | Tipe apa yang dipakai untuk pilihan audiens? Di mana pengaturan akun disimpan, dan kenapa di schema `private`? |
| 2. Aturan | 0169: fungsi trigger `comments_25_comment_audience` | Kenapa aturannya di trigger, bukan di `create_comment`? Kenapa angkanya 25? |
| 3. Keamanan baca | 0169: policy `comments_hidden_when_off` | Kenapa policy ini `restrictive`? Apa yang terjadi bila dibuat `permissive`? |
| 4. Hak kolom | 0169: `grant insert (comment_audience)` | Error apa yang muncul tanpa baris ini? |
| 5. Proyeksi | 0170: `private.feed_posts` | Ada tiga `lateral` (`ao`, `ea`, `cr`). Apa isi masing-masing? Kenapa `comments_off_by_account` hanya dikirim ke pemilik post? |
| 6. API | 0170: `set_all_comments_off`, `get_comment_settings` | `security definer` atau tidak? Bagaimana fungsi memastikan pengguna hanya mengubah pengaturannya sendiri? |
| 7. Tes | [146](../../supabase/tests/146_comment_controls_test.sql), [147](../../supabase/tests/147_comment_controls_account_off_test.sql) | Temukan tes yang membuktikan insert langsung lewat REST tetap ditolak. Temukan tes "setelah saklar dimatikan, post kembali ke pengaturannya sendiri" |
| 8. Kontrak | [docs/social](../social/README.md), bagian "Kontrol komentar (`0169`)" | Field apa saja yang ditambahkan ke post, dan field mana yang hanya untuk pemilik? |
| 9. Klien | Library: `comment_controls.dart`, `feed_cubit.dart` | Bagaimana library tahu server mendukung saklar akun (`allOffAvailable`)? Apa yang terjadi di app lama yang tidak mengenal field baru? |
| 10. Rilis | [docs/panduan/catatan-rilis.md](../panduan/catatan-rilis.md) | Kenapa server harus dipasang sebelum aplikasi? |

Setelah selesai, coba tiru pengguna (modul 3.4) dan buktikan sendiri di DB yang sudah memasang 0169: komentar orang lain di post yang komentarnya dimatikan tidak terlihat, tetapi pemilik post tetap bisa melihat komentar lamanya.

---

## Bagian B: membangun `get_my_chat_stats`

**Kebutuhan:** halaman profil ingin menampilkan statistik chat pribadi:

```json
{"rooms": {"direct": 3, "group": 4, "stock": 2}, "messages_sent": 259, "unread_rooms": 2, "last_sent_at": "2026-11-16T…"}
```

Aturannya:
- Hanya untuk pengguna yang login. Bila tidak login → `401 not_authenticated`.
- Hanya data milik pemanggil.
- Pesan yang dihapus tidak dihitung.
- Pengguna yang baru dibuat (tanpa pesan) → semua angka `0`, `last_sent_at` `null`.

### Langkah

1. **Rancang.** Tulis di kertas:
   - Fungsi ini `security definer` atau `invoker`? (Petunjuk: semua tabel yang dibaca sudah dilindungi RLS untuk pemiliknya.)
   - `stable` atau `volatile`?
   - Tipe hasil apa?
2. **Tulis tesnya dulu** (modul 9): minimal enam tes, yaitu tidak login, hasil Budi cocok dengan query manual, pengguna baru berisi nol, pesan yang dihapus tidak dihitung, tidak bisa melihat data orang lain, dan `anon` tidak boleh memanggil.
3. **Tulis fungsinya** (modul 1 + 2), lalu `grant`/`revoke` (modul 3).
4. **Jalankan** semuanya dalam satu `begin … rollback`.
5. **Tinjau:** apakah ada query yang membaca seluruh tabel (`explain`, modul 5.4)? Index apa yang dipakai?

Fungsi dibuat di schema `public` di dalam transaksi supaya bisa diuji sebagai `authenticated`. Semuanya hilang saat `rollback`.

<details>
<summary>Contoh solusi (buka setelah mencoba sendiri)</summary>

```sql
begin;

create function public.get_my_chat_stats()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return jsonb_build_object(
    'rooms', (select jsonb_build_object(
                       'direct', count(*) filter (where r.type = 'direct'),
                       'group',  count(*) filter (where r.type = 'group'),
                       'stock',  count(*) filter (where r.type = 'stock'))
              from public.chat_members m
              join public.chat_rooms r on r.id = m.room_id
              where m.user_id = v_uid),
    'messages_sent', (select count(*) from public.messages x
                      where x.sender_id = v_uid and x.deleted_at is null),
    'unread_rooms', public.get_unread_chat_count(),
    'last_sent_at', (select max(x.created_at) from public.messages x
                     where x.sender_id = v_uid and x.deleted_at is null));
end;
$$;
revoke execute on function public.get_my_chat_stats() from public, anon;
grant execute on function public.get_my_chat_stats() to authenticated;

select plan(6);

select set_config('role', 'authenticated', true), set_config('request.jwt.claims', '{}', true);
select throws_ok($$select public.get_my_chat_stats()$$, 'PT401', 'not_authenticated', 'Tanpa login ditolak');

select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.profiles where username = 'budi_santoso'))::text, true);
select is((public.get_my_chat_stats() ->> 'messages_sent')::bigint,
          (select count(*) from public.messages where sender_id = auth.uid() and deleted_at is null),
          'Jumlah pesan Budi cocok');
select ok((public.get_my_chat_stats() -> 'rooms') ?& array['direct', 'group', 'stock'], 'Ada tiga jenis room');

reset role;
insert into public.profiles (id, olt_user_id, username) values (gen_random_uuid(), 'latihan-baru', 'latihan_baru');
select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims',
                  json_build_object('sub', (select id from public.profiles where username = 'latihan_baru'))::text, true);
select is(public.get_my_chat_stats(),
          '{"rooms": {"direct": 0, "group": 0, "stock": 0}, "messages_sent": 0, "unread_rooms": 0, "last_sent_at": null}'::jsonb,
          'Pengguna baru: semua nol');
select is((public.get_my_chat_stats() ->> 'messages_sent')::int, 0, 'Tidak melihat pesan orang lain');

reset role;
set local role anon;
select throws_ok($$select public.get_my_chat_stats()$$, '42501', null, 'anon tidak boleh memanggil');

select * from finish();
rollback;
```

Catatan:
- Fungsi ini memakai `security invoker` (bawaan), jadi RLS ikut menyaring. Filter `where m.user_id = v_uid` tetap ditulis supaya jelas maksudnya dan supaya index terpakai.
- `set search_path = ''` dan nama lengkap (`public.messages`) tetap dipakai walau bukan `security definer`, demi kebiasaan yang aman.
- Profil baru di-insert langsung sebagai `postgres` hanya untuk latihan ini. Di tes resmi kita memakai `tests.create_user`.
- Solusi ini sudah dijalankan di DB dev dan keenam tesnya lulus.
</details>

### Bila ingin dijadikan fitur sungguhan

Urutan yang dipakai tim:
1. Migrasi baru `supabase/migrations/NNNN_….sql`, dengan NNNN satu angka setelah migrasi terakhir (file `.sql` wajib LF, tanpa komentar).
2. Tes `supabase/tests/NNN_…_test.sql`, juga satu angka setelah tes terakhir.
3. Jalankan semua tes di DB sekali pakai (modul 9.4), bukan di DB dev.
4. Perbarui dokumentasi: [docs/social](../social/README.md), [docs/api/openapi.yaml](../api/openapi.yaml), [catatan rilis](../panduan/catatan-rilis.md).
5. Library: method repository + model + tes, lalu naikkan versi.
6. Pindai gitleaks, commit ke branch, merge ke `main`.

---

## Selesai

Setelah 11 modul ini, Anda seharusnya bisa:
- membaca migrasi mana pun dan menjelaskan aturan bisnisnya;
- membuktikan sendiri, dengan meniru pengguna, bahwa sebuah data aman;
- menelusuri pesan dari tombol Kirim sampai HP penerima;
- menulis fungsi baru beserta tes pgTAP-nya;
- membaca dashboard Kesehatan sistem dan memahami artinya.

Langkah berikutnya: pilih satu fitur di [docs/panduan/daftar-fitur.md](../panduan/daftar-fitur.md) yang belum Anda pahami, lalu telusuri dengan tabel di Bagian A.
