begin;
select plan(11);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message');

select tests.create_user('ks_ani') as ani \gset
select tests.create_user('ks_budi') as budi \gset
insert into public.posts (id, author_id, body) values ('00000000-0000-4000-8000-00000000f891', :'budi', 'Post budi');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'ani') as dm \gset
reset role;
select room_id as support_room from cs.tickets where id = :'ticket' \gset

update private.kill_switch set social_enabled = false, reason = 'Uji status kill switch', changed_at = now() where singleton;

create function pg_temp.error_of(p_sql text) returns text language plpgsql as $$
declare
  v_state text;
  v_message text;
  v_detail text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_message = message_text, v_detail = pg_exception_detail;
  return v_state || ' | ' || v_message || ' | ' || v_detail;
end;
$$;
grant execute on function pg_temp.error_of(text) to authenticated;

select tests.authenticate_as(:'budi');
select throws_ok($$insert into public.posts (author_id, body) values (auth.uid(), 'Post saat mati')$$,
  'PT403', 'social_disabled', 'Post baru ditolak dengan PT403 social_disabled');
select throws_ok($$select * from public.create_comment('00000000-0000-4000-8000-00000000f891', null, 'Komentar')$$,
  'PT403', 'social_disabled', 'Komentar baru ditolak dengan PT403 social_disabled');
select throws_ok(format($$select public.send_message(%L, 'Halo')$$, :'dm'),
  'PT403', 'social_disabled', 'Chat non-CS ditolak dengan PT403 social_disabled');
select is(pg_temp.error_of($$insert into public.posts (author_id, body) values (auth.uid(), 'Post saat mati')$$),
  'PT403 | social_disabled | Fitur komunitas sedang dinonaktifkan sementara',
  'Kode stabil dan pesan detail tidak berubah');
select isnt(pg_temp.error_of(format($$select public.send_message(%L, 'Halo')$$, :'dm')) like 'PT503%', true,
  'Kill switch tidak lagi memakai status 503');
select lives_ok(format($$select public.send_message(%L, 'Tolong bantu akun saya')$$, :'support_room'),
  'Chat CS tetap berjalan saat kill switch aktif');
reset role;

select tests.authenticate_service();
select lives_ok(format($$insert into public.posts (author_id, body) values (%L, 'Post dari server')$$, :'budi'),
  'Tulisan dari sisi server (bukan pengguna aplikasi) tidak diblokir');
reset role;
select is((select count(*)::integer from public.posts where id = '00000000-0000-4000-8000-00000000f891'), 1,
  'Post yang sudah ada tetap tersedia');

select is((select count(*)::integer
           from pg_catalog.pg_proc p
           join pg_catalog.pg_namespace n on n.oid = p.pronamespace
           where n.nspname not in ('pg_catalog', 'information_schema')
             and p.prosrc ~ 'api_error\s*\(\s*503\M'), 0,
  'Tidak ada fungsi yang memanggil api_error dengan status 503');
select is((select count(*)::integer
           from pg_catalog.pg_proc p
           join pg_catalog.pg_namespace n on n.oid = p.pronamespace
           where n.nspname not in ('pg_catalog', 'information_schema')
             and p.prosrc ~* '''PT503''|"PT503"|''status''\s*,\s*503'), 0,
  'Tidak ada fungsi yang menaikkan PT503 atau status 503 langsung');

update private.kill_switch set social_enabled = true where singleton;
select tests.authenticate_as(:'budi');
select lives_ok($$insert into public.posts (author_id, body) values (auth.uid(), 'Post saat hidup')$$,
  'Post kembali diterima setelah kill switch dimatikan');
reset role;

select * from finish();
rollback;
