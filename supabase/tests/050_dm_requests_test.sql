begin;
select plan(46);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'follow', 'report');
create function pg_temp.pending(p_room uuid, p_user uuid) returns boolean language sql security definer as $$ select private.dm_request_pending(p_room, p_user) $$;
select tests.create_user('dm_alya') as alya \gset
select tests.create_user('dm_bima') as bima \gset
select tests.create_user('dm_cita') as cita \gset
select tests.create_user('dm_dewa') as dewa \gset
select tests.create_user('dm_eka') as eka \gset
select tests.create_user('dm_fajar') as fajar \gset
select tests.create_user('dm_gita') as gita \gset
select tests.create_user('dm_hadi') as hadi \gset
select tests.create_user('dm_resmi') as resmi \gset
select tests.create_agent('Rani', '{cs_agent}', '{"general": 1}') as rani \gset
insert into cs.official_accounts (profile_id) values (:'resmi');
update public.profiles set trust_level = 0 where id = :'dewa';
insert into public.follows (follower_id, following_id) values (:'bima', :'cita'), (:'eka', :'dewa');

select tests.authenticate_as(:'alya');
select get_or_create_direct_room(:'bima') as dm_ab \gset
select ok(pg_temp.pending(:'dm_ab', :'bima'), 'DM dari orang yang tidak diikuti menjadi permintaan untuk penerima');
select ok(not pg_temp.pending(:'dm_ab', :'alya'), 'Bagi pengirim, room DM tetap tampil normal');
select lives_ok(format($$select send_message(%L, 'Halo Bima', 'd5000000-0000-4000-8000-000000000001')$$, :'dm_ab'), 'Pesan pertama terkirim');
select lives_ok(format($$select send_message(%L, 'Mau tanya soal BBCA')$$, :'dm_ab'), 'Pesan kedua terkirim');
select lives_ok(format($$select send_message(%L, 'Terima kasih')$$, :'dm_ab'), 'Pesan ketiga terkirim');
select throws_ok(format($$select send_message(%L, 'Halo lagi?')$$, :'dm_ab'), 'PT403', 'dm_request_limit',
  'Pengirim dibatasi 3 pesan sebelum diterima');
select lives_ok(format($$select send_message(%L, 'Halo Bima', 'd5000000-0000-4000-8000-000000000001')$$, :'dm_ab'),
  'Kirim ulang dengan client_id sama tetap idempoten');
reset role;
update chat_members set last_read_at = now() - interval '1 minute' where room_id = :'dm_ab' and user_id = :'bima';

select tests.authenticate_as(:'bima');
select results_eq(
  'select sender_id, message_count, last_message_preview is not null, has_image from get_message_requests()',
  format($$values (%L::uuid, 3, true, false)$$, :'alya'),
  'Penerima melihat permintaan pesan beserta jumlah dan cuplikannya');
select is((select count(*)::int from get_my_rooms() where id = :'dm_ab'), 0, 'Permintaan tidak muncul di daftar chat biasa');
select is(get_message_request_count(), 1, 'Jumlah permintaan pesan tersedia untuk lencana');
select is((select count(*)::int from get_unread_counts() where room_id = :'dm_ab'), 0, 'Permintaan tidak ikut jumlah belum dibaca per room');
select is(get_unread_chat_count(), 0, 'Permintaan tidak ikut lencana chat belum dibaca');
select is((respond_message_request(:'dm_ab', 'accept')) ->> 'status', 'accepted', 'Penerima menerima permintaan');
select ok(not pg_temp.pending(:'dm_ab', :'bima'), 'Setelah diterima, DM tidak lagi berstatus permintaan');
select is((select count(*)::int from get_my_rooms() where id = :'dm_ab'), 1, 'DM yang diterima tampil di daftar chat');
select is(get_unread_chat_count(), 1, 'Setelah diterima, DM ikut lencana belum dibaca');
select throws_ok(format($$select respond_message_request(%L, 'accept')$$, :'dm_ab'), 'PT404', 'request_not_found',
  'Permintaan yang sudah diterima tidak bisa direspons lagi');

select tests.authenticate_as(:'alya');
select lives_ok(format($$select send_message(%L, 'Pesan keempat setelah diterima')$$, :'dm_ab'), 'Setelah diterima, batas pesan hilang');
select throws_ok(format($$select respond_message_request(%L, 'accept')$$, :'dm_ab'), 'PT404', 'request_not_found',
  'Pengirim tidak bisa menerima permintaannya sendiri');

select tests.authenticate_as(:'cita');
select get_or_create_direct_room(:'bima') as dm_cb \gset
select ok(not pg_temp.pending(:'dm_cb', :'bima'), 'DM dari orang yang diikuti penerima langsung diterima');

select tests.authenticate_as(:'bima');
select is(set_dm_policy('following') ->> 'policy', 'following', 'Pengguna mengatur kebijakan DM');
select throws_ok($$select set_dm_policy('teman')$$, 'PT400', 'invalid_policy', 'Kebijakan DM divalidasi');
select tests.authenticate_as(:'fajar');
select throws_ok(format('select get_or_create_direct_room(%L)', :'bima'), 'PT403', 'dm_not_allowed',
  'Kebijakan "following": orang yang tidak diikuti ditolak');
select tests.authenticate_as(:'cita');
select lives_ok(format($$select send_message(%L, 'Masih boleh karena diikuti')$$, :'dm_cb'), 'Orang yang diikuti tetap boleh');
select tests.authenticate_as(:'bima');
select is(set_dm_policy('none') ->> 'policy', 'none', 'Kebijakan "none" diterapkan');
select tests.authenticate_as(:'hadi');
select throws_ok(format('select get_or_create_direct_room(%L)', :'bima'), 'PT403', 'dm_not_allowed',
  'Kebijakan "none": DM baru ditolak');
select tests.authenticate_as(:'resmi');
select get_or_create_direct_room(:'bima') as dm_resmi \gset
select ok(not pg_temp.pending(:'dm_resmi', :'bima'), 'Akun resmi tidak terkena kebijakan DM');
reset role;
select is(private.dm_evaluate(:'rani', :'bima'), 'accepted', 'Staf CS tidak terkena kebijakan DM');
select tests.authenticate_as(:'bima');
select is(get_dm_policy(), '{"policy": "none", "request_max_messages": 3}'::jsonb, 'Pengguna membaca kebijakan DM-nya');

select tests.authenticate_as(:'dewa');
select get_or_create_direct_room(:'eka') as dm_de \gset
select ok(pg_temp.pending(:'dm_de', :'eka'), 'Akun baru ke non-mutual lewat permintaan walau penerima mengikutinya');
reset role;
insert into public.follows (follower_id, following_id) values (:'dewa', :'eka');
select tests.authenticate_as(:'dewa');
select lives_ok(format($$select send_message(%L, 'Halo Eka')$$, :'dm_de'), 'Setelah saling mengikuti, pesan terkirim');
select ok(not pg_temp.pending(:'dm_de', :'eka'), 'Saling mengikuti membuat permintaan otomatis diterima');

select tests.authenticate_as(:'fajar');
select get_or_create_direct_room(:'gita') as dm_fg \gset
select lives_ok(format($$select send_message(%L, 'Salam kenal Gita')$$, :'dm_fg'), 'Fajar mengirim permintaan');
select tests.authenticate_as(:'gita');
select lives_ok(format($$select send_message(%L, 'Salam kenal juga')$$, :'dm_fg'), 'Penerima membalas');
select ok(not pg_temp.pending(:'dm_fg', :'gita'), 'Membalas berarti menerima permintaan');

select tests.authenticate_as(:'hadi');
select get_or_create_direct_room(:'gita') as dm_hg \gset
select lives_ok(format($$select send_message(%L, 'Promo terbatas')$$, :'dm_hg'), 'Hadi mengirim permintaan');
select tests.authenticate_as(:'gita');
select is((respond_message_request(:'dm_hg', 'decline')) ->> 'status', 'declined', 'Penerima menolak permintaan');
select ok(pg_temp.pending(:'dm_hg', :'gita'), 'Permintaan yang ditolak tetap tersembunyi dari daftar chat');
select is((select count(*)::int from get_message_requests() where room_id = :'dm_hg'), 0,
  'Permintaan yang ditolak hilang dari daftar permintaan');
select tests.authenticate_as(:'hadi');
select lives_ok(format($$select send_message(%L, 'Masih ada?')$$, :'dm_hg'),
  'Pengirim tidak diberi tahu penolakan (masih dalam batas 3 pesan)');

select tests.authenticate_as(:'alya');
select get_or_create_direct_room(:'gita') as dm_ag \gset
select lives_ok(format($$select send_message(%L, 'Join sinyal saya')$$, :'dm_ag'), 'Alya mengirim permintaan');
select tests.authenticate_as(:'gita');
select is(respond_message_request(:'dm_ag', 'block'), format('{"room_id": "%s", "status": "declined", "blocked": true}', :'dm_ag')::jsonb,
  'Penerima memblokir dan melaporkan pengirim');
select throws_ok(format($$select respond_message_request(%L, 'hapus')$$, :'dm_ag'), 'PT400', 'invalid_action', 'Aksi respons divalidasi');
reset role;
select ok(exists (select 1 from public.blocks where blocker_id = :'gita' and blocked_id = :'alya'), 'Blokir tersimpan');
select ok(exists (select 1 from public.reports where reporter_id = :'gita' and target_type = 'user' and target_id = :'alya'
                  and reason = 'spam'), 'Laporan spam tersimpan untuk moderator');
select tests.authenticate_as(:'alya');
select throws_ok(format($$select send_message(%L, 'Halo?')$$, :'dm_ag'), 'PT403', 'cannot_send', 'Pengirim yang diblokir tidak bisa mengirim');

select * from finish();
rollback;
