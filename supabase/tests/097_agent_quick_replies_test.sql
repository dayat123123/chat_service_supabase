begin;
select plan(33);

select tests.create_user('aqr_budi') as budi \gset
select tests.create_agent('Rani Pribadi', '{cs_agent}') as rani \gset
select tests.create_agent('Sari Pribadi', '{cs_agent}') as sari \gset
select tests.create_agent('Ayu Admin', '{cs_super_admin}') as ayu \gset

insert into cs.quick_replies (scope, shortcut, title, body, language)
values ('global', 'aqr-bersama', 'Bersama ID', 'Halo dari tim', 'id'),
       ('global', 'aqr-shared', 'Shared EN', 'Hello from the team', 'en');

select ok((select bool_and(p.prosecdef and p.proconfig @> array['search_path=""'])
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'cs_api' and p.proname in ('my_quick_replies', 'save_my_quick_reply', 'delete_my_quick_reply')),
  'RPC balasan pribadi SECURITY DEFINER dengan search_path kosong');
select ok(not has_function_privilege('anon', 'cs_api.save_my_quick_reply(uuid, text, text, text)', 'execute'),
  'anon tidak bisa memanggil save_my_quick_reply');
select ok(not has_function_privilege('authenticated', 'cs.personal_quick_reply_shortcut(uuid, text, uuid)', 'execute'),
  'Helper pintasan tidak bisa dipanggil langsung');

select tests.authenticate_as(:'budi');
select throws_ok($$select cs_api.my_quick_replies()$$, 'PT403', 'agent_required', 'Nasabah tidak bisa membaca balasan pribadi');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Judul', 'Isi')$$, 'PT403', 'agent_required',
  'Nasabah tidak bisa membuat balasan pribadi');
select throws_ok($$select cs_api.quick_replies('id')$$, 'PT403', 'agent_required', 'Nasabah tidak bisa membaca balasan cepat');
reset role;

select tests.authenticate_agent(:'rani');
select cs_api.save_my_quick_reply(null, 'Salam Pagi!', 'Selamat pagi {nama}, saya {nama_cs}.') as r1 \gset
select is(:'r1'::jsonb ->> 'scope', 'personal', 'Balasan tersimpan sebagai pribadi');
select is(:'r1'::jsonb ->> 'shortcut', 'salam-pagi', 'Pintasan dibuat otomatis dari judul');
select cs_api.save_my_quick_reply(null, 'Salam pagi', 'Pagi {nama}') ->> 'shortcut' as s2 \gset
select is(:'s2'::text, 'salam-pagi-2', 'Pintasan otomatis tidak bentrok dengan milik sendiri');
select is(cs_api.save_my_quick_reply(null, 'Cek dana', 'Dana sedang dicek', 'aqr-bersama') ->> 'shortcut', 'aqr-bersama',
  'Pintasan pribadi boleh sama dengan pintasan bersama');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Lain', 'Isi', 'aqr-bersama')$$, 'PT409', 'duplicate_shortcut',
  'Pintasan pribadi ganda ditolak');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Lain', 'Isi', 'Bukan Valid')$$, 'PT400', 'invalid_shortcut',
  'Pintasan tidak valid ditolak');
select throws_ok(format($$select cs_api.save_my_quick_reply(null, %L, 'Isi')$$, repeat('a', 81)), 'PT400', 'invalid_title',
  'Judul lebih dari 80 karakter ditolak');
select throws_ok(format($$select cs_api.save_my_quick_reply(null, 'Judul', %L)$$, repeat('a', 2001)), 'PT400', 'invalid_body',
  'Isi lebih dari 2000 karakter ditolak');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Verifikasi', 'Mohon kirim kode OTP Anda ke chat ini')$$,
  'PT400', 'secret_request_blocked', 'Balasan pribadi yang meminta OTP ditolak');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Berikan PIN Anda', 'Isi aman')$$,
  'PT400', 'secret_request_blocked', 'Judul yang meminta PIN juga ditolak');
select is(cs_api.save_my_quick_reply(null, 'Rekening', 'Transfer ke rekening 1234567890123 ya') ->> 'body',
  'Transfer ke rekening *********0123 ya', 'Data sensitif disamarkan sebelum disimpan');
select is((select count(*)::integer from jsonb_array_elements(cs_api.quick_replies('en')) x
           where x ->> 'scope' = 'personal'), 4, 'Balasan pribadi tampil di semua bahasa');
select ok((select bool_or(x ->> 'shortcut' = 'aqr-shared') and not bool_or(x ->> 'shortcut' = 'aqr-bersama' and x ->> 'scope' = 'global')
           from jsonb_array_elements(cs_api.quick_replies('en')) x),
  'Balasan bersama tetap disaring per bahasa');
select is((cs_api.quick_replies('id') -> 0) ->> 'scope', 'personal', 'Balasan pribadi diurutkan lebih dulu');
select cs_api.save_my_quick_reply((:'r1'::jsonb ->> 'id')::uuid, 'Salam pagi baru', 'Pagi, {nama}', 'pagi') as r1b \gset
select is(:'r1b'::jsonb ->> 'shortcut', 'pagi', 'Balasan pribadi bisa diubah pemiliknya');
reset role;

select tests.authenticate_agent(:'sari');
select is(jsonb_array_length(cs_api.my_quick_replies()), 0, 'Staf lain tidak melihat balasan pribadi Rani');
select is((select count(*)::integer from jsonb_array_elements(cs_api.quick_replies('id')) x
           where x ->> 'scope' = 'personal'), 0, 'Pemilih balasan staf lain tidak memuat balasan pribadi Rani');
select is((select count(*)::integer from cs.quick_replies where scope = 'personal'), 0,
  'RLS menyembunyikan balasan pribadi staf lain dari pembacaan langsung');
select throws_ok(format($$select cs_api.save_my_quick_reply(%L, 'Ambil alih', 'Isi')$$, :'r1'::jsonb ->> 'id'),
  'PT404', 'quick_reply_not_found', 'Staf lain tidak bisa mengubah balasan pribadi Rani');
select throws_ok(format($$select cs_api.delete_my_quick_reply(%L)$$, :'r1'::jsonb ->> 'id'),
  'PT404', 'quick_reply_not_found', 'Staf lain tidak bisa menghapus balasan pribadi Rani');
reset role;

select tests.authenticate_agent(:'ayu');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Admin', 'Isi')$$, 'PT403', 'role_forbidden',
  'Super Admin tanpa peran CS tidak membuat balasan pribadi');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.admin_quick_replies()) x where x ->> 'shortcut' = 'pagi'),
  'Daftar balasan bersama Super Admin tidak memuat balasan pribadi');
reset role;

insert into cs.quick_replies (scope, owner_id, shortcut, title, body, created_by)
select 'personal', :'rani', 'isi-' || i, 'Isi ' || i, 'Isi balasan ' || i, :'rani' from generate_series(1, 46) i;

select tests.authenticate_agent(:'rani');
select is(jsonb_array_length(cs_api.my_quick_replies()), 50, 'Rani punya 50 balasan pribadi');
select throws_ok($$select cs_api.save_my_quick_reply(null, 'Ke-51', 'Isi')$$, 'PT409', 'quick_reply_limit',
  'Balasan pribadi ke-51 ditolak');
select lives_ok(format($$select cs_api.save_my_quick_reply(%L, 'Tetap bisa diubah', 'Isi baru')$$, :'r1'::jsonb ->> 'id'),
  'Balasan yang ada tetap bisa diubah saat batas tercapai');
select is(cs_api.delete_my_quick_reply((:'r1'::jsonb ->> 'id')::uuid) ->> 'deleted', 'true', 'Pemilik bisa menghapus balasan pribadi');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.my_quick_replies()) x where x ->> 'id' = :'r1'::jsonb ->> 'id'),
  'Balasan yang dihapus hilang dari daftar');
reset role;

select * from finish();
rollback;
