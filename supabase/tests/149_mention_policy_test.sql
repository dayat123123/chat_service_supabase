begin;
select plan(26);

update private.rate_limits set max_count = 1000
 where action in ('message', 'post', 'comment', 'follow', 'stock_room_create', 'data_export');
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select tests.create_user('mp_ani') as ani \gset
select tests.create_user('mp_budi') as budi \gset
select tests.create_user('mp_cici') as cici \gset
select tests.create_agent('Mona Moderasi', '{community}', '{}') as mona \gset
insert into follows (follower_id, following_id) values (:'ani', :'budi');

create function pg_temp.set_policy(p_user uuid, p_policy text) returns jsonb language plpgsql as $$
declare
  v jsonb;
begin
  perform tests.authenticate_as(p_user);
  v := set_mention_policy(p_policy);
  reset role;
  return v;
end;
$$;

create function pg_temp.post_mentions(p_author uuid, p_body text) returns integer language plpgsql as $$
declare
  v_post uuid := gen_random_uuid();
begin
  insert into posts (id, author_id, body) values (v_post, p_author, p_body);
  return (select count(*)::integer from notifications n
          where n.type = 'mention' and n.payload ->> 'post_id' = v_post::text
            and n.user_id = (select id from profiles where username = 'mp_ani'));
end;
$$;

create function pg_temp.can_mention(p_viewer uuid, p_query text) returns boolean language plpgsql as $$
declare
  v boolean;
begin
  perform tests.authenticate_as(p_viewer);
  select s.can_mention into v from search_profiles(p_query) s where s.username = p_query;
  reset role;
  return v;
end;
$$;

select tests.authenticate_as(:'ani');
select is(get_mention_policy(), '{"policy": "everyone"}'::jsonb, 'Bawaan: semua orang boleh menyebut');
select is(set_mention_policy('following'), '{"policy": "following"}'::jsonb, 'Pengaturan bisa diubah ke following');
select is(get_mention_policy(), '{"policy": "following"}'::jsonb, 'Pengaturan tersimpan');
select throws_ok($$select set_mention_policy('followers')$$, 'PT400', 'invalid_policy', 'Nilai tidak dikenal ditolak');
select throws_ok($$select set_mention_policy(null)$$, 'PT400', 'invalid_policy', 'Nilai kosong ditolak');
reset role;

select set_config('role', 'authenticated', true), set_config('request.jwt.claims', '{}', true);
select throws_ok($$select get_mention_policy()$$, 'PT401', 'not_authenticated', 'Tanpa login ditolak');
reset role;
select tests.authenticate_anon();
select throws_ok($$select set_mention_policy('none')$$, '42501', null, 'anon tidak boleh memanggil');
reset role;

select is(pg_temp.post_mentions(:'cici', 'Halo @mp_ani'), 0, 'following: post dari orang yang tidak diikuti tidak memberi notifikasi');
select is(pg_temp.post_mentions(:'budi', 'Halo @mp_ani'), 1, 'following: post dari orang yang diikuti memberi notifikasi');
select ok(private.mention_allowed(:'mona', :'ani'), 'Staf dan akun resmi tetap boleh menyebut');

insert into posts (id, author_id, body) values ('a4900000-0000-4000-8000-000000000001', :'budi', 'Diskusi mention');
select tests.authenticate_as(:'cici');
select id as cmt from create_comment('a4900000-0000-4000-8000-000000000001', null, 'Setuju @mp_ani') \gset
reset role;
select is((select count(*)::integer from notifications where user_id = :'ani' and type = 'mention'
           and payload ->> 'comment_id' = :'cmt'), 0, 'following: mention di komentar dari orang lain tidak memberi notifikasi');

select tests.authenticate_as(:'cici');
select join_stock_room('MNTP') as room \gset
select id as msg1 from send_message(:'room', 'Cek @mp_ani dan @mp_budi') \gset
reset role;
select is((select string_agg(p.username::text, ',' order by p.username) from notifications n
           join profiles p on p.id = n.user_id
           where n.type = 'mention' and n.payload ->> 'message_id' = :'msg1'), 'mp_budi',
  'Room saham: hanya pengguna yang mengizinkan yang mendapat notifikasi');
select tests.authenticate_as(:'budi');
select join_stock_room('MNTP') as room2 \gset
select id as msg2 from send_message(:'room', 'Cek @mp_ani') \gset
reset role;
select is((select count(*)::integer from notifications where user_id = :'ani' and type = 'mention'
           and payload ->> 'message_id' = :'msg2'), 1, 'Room saham: orang yang diikuti tetap bisa menyebut');

select is(pg_temp.can_mention(:'cici', 'mp_ani'), false, 'Autocomplete: tidak bisa menyebut bila tidak diikuti');
select is(pg_temp.can_mention(:'budi', 'mp_ani'), true, 'Autocomplete: orang yang diikuti bisa menyebut');
select is(pg_temp.can_mention(:'ani', 'mp_ani'), true, 'Autocomplete: diri sendiri selalu true');
select is(pg_temp.can_mention(:'ani', 'mp_cici'), true, 'Pengaturan pengguna lain tetap bawaan');
select tests.authenticate_as(:'cici');
select is((select count(*)::integer from search_profiles('mp_ani') s where s.username = 'mp_ani'), 1,
  'Pengguna yang membatasi mention tetap muncul di pencarian');
reset role;

select is(pg_temp.set_policy(:'ani', 'none'), '{"policy": "none"}'::jsonb, 'Pengaturan bisa diubah ke none');
select is(pg_temp.post_mentions(:'budi', 'Lagi @mp_ani'), 0, 'none: orang yang diikuti pun tidak memberi notifikasi');
select is(pg_temp.can_mention(:'budi', 'mp_ani'), false, 'none: autocomplete menandai tidak bisa disebut');
select ok(private.mention_allowed(:'mona', :'ani'), 'none: staf tetap boleh menyebut');

select tests.authenticate_as(:'ani');
select is(export_my_data() ->> 'mention_policy', 'none', 'Ekspor data memuat pengaturan mention');
reset role;

select is(pg_temp.set_policy(:'ani', 'everyone'), '{"policy": "everyone"}'::jsonb, 'Kembali ke semua orang');
select is((select count(*)::integer from private.mention_preferences where user_id = :'ani'), 0,
  'Pilihan bawaan tidak menyimpan baris');
select is(pg_temp.post_mentions(:'cici', 'Akhirnya @mp_ani'), 1, 'everyone: semua orang bisa menyebut lagi');

select * from finish();
rollback;
