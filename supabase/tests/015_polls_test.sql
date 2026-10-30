begin;
select plan(26);

select tests.create_user('poll_author') as author \gset
select tests.create_user('poll_voter') as voter \gset
select tests.create_user('poll_late') as late \gset

select tests.authenticate_as(:'author');
select (create_post(
  'IHSG minggu depan ke mana?', null, '[]', null,
  '{"options": ["Naik", "Turun", "Sideways"], "duration_minutes": 60}'
)).id as poll_post \gset
select poll -> 'options' -> 0 ->> 'id' as opt_up,
       poll -> 'options' -> 1 ->> 'id' as opt_down
  from get_post(:'poll_post') \gset
select (create_post('Post biasa tanpa polling')).id as plain_post \gset

select is(
  (select jsonb_array_length(poll -> 'options') from get_post(:'poll_post')), 3,
  'Polling tersimpan dengan 3 pilihan');
select is(
  (select poll -> 'options' -> 2 ->> 'label' from get_post(:'poll_post')), 'Sideways',
  'Urutan pilihan sesuai input');
select ok(
  (select (poll ->> 'results_visible')::boolean from get_post(:'poll_post')),
  'Pembuat polling langsung melihat hasil');
select ok(
  (select poll is null from get_post(:'plain_post')),
  'Post biasa tidak punya data polling');
select throws_ok(
  format('select vote_poll(%L, %L)', :'poll_post', :'opt_up'),
  'PT403', 'own_poll', 'Pembuat tidak bisa memilih di polling sendiri');
select throws_ok(
  $$select create_post('Satu pilihan saja?', null, '[]', null, '{"options": ["Ya"]}')$$,
  'PT422', 'invalid_poll_options', 'Polling minimal 2 pilihan');
select throws_ok(
  $$select create_post('Terlalu banyak pilihan?', null, '[]', null, '{"options": ["A", "B", "C", "D", "E"]}')$$,
  'PT422', 'invalid_poll_options', 'Polling maksimal 4 pilihan');
select throws_ok(
  $$select create_post('Pilihan kembar?', null, '[]', null, '{"options": ["Naik", "naik "]}')$$,
  'PT422', 'duplicate_poll_option', 'Pilihan polling tidak boleh sama');
select throws_ok(
  $$select create_post('Durasi terlalu singkat?', null, '[]', null, '{"options": ["A", "B"], "duration_minutes": 1}')$$,
  'PT422', 'invalid_poll_duration', 'Durasi polling minimal 5 menit');
select throws_ok(
  $$select create_post('Label kepanjangan?', null, '[]', null,
    '{"options": ["A", "Pilihan yang panjangnya jauh melebihi empat puluh karakter"]}')$$,
  'PT422', 'invalid_poll_option', 'Label pilihan maksimal 40 karakter');
select throws_ok(
  $$select create_post('Polling bergambar?', null, '[{"path": "posts/x.jpg", "mime": "image/jpeg"}]', null,
    '{"options": ["A", "B"]}')$$,
  'PT422', 'poll_with_attachments', 'Polling tidak bisa digabung dengan lampiran');
select is(
  (select count(*)::int from posts where author_id = :'author'), 2,
  'Polling yang gagal validasi tidak membuat post');

select tests.authenticate_as(:'voter');
select ok(
  not (select (poll ->> 'results_visible')::boolean from get_post(:'poll_post')),
  'Hasil tersembunyi sebelum memilih');
select is(
  (select poll -> 'options' -> 0 -> 'votes' from get_post(:'poll_post')), 'null'::jsonb,
  'Jumlah suara per pilihan tidak dikirim sebelum memilih');
select is(
  vote_poll(:'poll_post', :'opt_down') ->> 'my_option_id', :'opt_down',
  'Suara tercatat');
select is(
  (select (poll -> 'options' -> 1 ->> 'votes')::int from get_post(:'poll_post')), 1,
  'Jumlah suara pilihan bertambah');
select is(
  (select (poll ->> 'total_votes')::int from get_post(:'poll_post')), 1,
  'Total pemilih bertambah');
select throws_ok(
  format('select vote_poll(%L, %L)', :'poll_post', :'opt_up'),
  'PT409', 'already_voted', 'Satu user hanya punya satu suara');
select throws_ok(
  'select * from post_poll_votes', '42501', null,
  'Isi suara tidak bisa dibaca langsung');
select throws_ok(
  'select * from post_poll_options', '42501', null,
  'Jumlah suara hanya tersedia lewat proyeksi feed');
select is(
  jsonb_array_length(export_my_data() -> 'poll_votes'), 1,
  'Ekspor data memuat suara polling');

select tests.authenticate_as(:'late');
select throws_ok(
  format('select vote_poll(%L, %L)', :'poll_post', gen_random_uuid()),
  'PT422', 'invalid_poll_option', 'Pilihan dari luar polling ditolak');
select throws_ok(
  format('insert into post_poll_votes (post_id, user_id, option_id) values (%L, %L, %L)',
    :'poll_post', :'voter', :'opt_up'),
  '42501', null, 'Tidak bisa memilih atas nama orang lain');

reset role;
update post_polls set ends_at = now() - interval '1 minute' where post_id = :'poll_post';

select tests.authenticate_as(:'late');
select ok(
  (select (poll ->> 'closed')::boolean and (poll ->> 'results_visible')::boolean from get_post(:'poll_post')),
  'Polling selesai: hasil terlihat oleh semua');
select throws_ok(
  format('select vote_poll(%L, %L)', :'poll_post', :'opt_up'),
  'PT422', 'poll_closed', 'Polling yang selesai tidak menerima suara');

reset role;
delete from post_poll_votes where user_id = :'voter';
select is(
  (select voters_count from post_polls where post_id = :'poll_post'), 0,
  'Suara yang dihapus ikut mengurangi jumlah pemilih');

select * from finish();
rollback;
