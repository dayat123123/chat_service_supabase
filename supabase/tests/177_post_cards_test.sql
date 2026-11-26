begin;
select plan(16);

select tests.create_agent('Rina Kartu', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Budi Kartu', '{cs_agent}', '{"general": 1}') as budi \gset
update cs.agents set community_permissions = '{community.post}' where user_id = :'rina';
update cs.agents set community_permissions = '{community.publish}' where user_id = :'budi';
select tests.create_user('kartu_resmi') as resmi \gset
select tests.create_user('kartu_pembaca') as pembaca \gset
insert into cs.official_accounts (profile_id) values (:'resmi');
insert into public.banned_words (word, action) values ('tipuankartu', 'block') on conflict do nothing;

create function pg_temp.card(p_headline text, p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('type', 'card', 'document', jsonb_build_object(
    'version', 1, 'badge', 'Info pasar', 'title', 'Jadwal Libur Bursa', 'headline', p_headline,
    'disclaimer', 'Informasi dari OLT Research.',
    'blocks', jsonb_build_array(
      jsonb_build_object('type', 'paragraph', 'text', 'Bursa libur pada hari berikut.'),
      jsonb_build_object('type', 'list', 'style', 'numbered', 'items', jsonb_build_array('25 Desember', '26 Desember')),
      jsonb_build_object('type', 'metrics', 'metrics', jsonb_build_array(
        jsonb_build_object('label', 'Hari libur', 'value', '2 hari', 'change', '+1 hari', 'trend', 'up'))),
      jsonb_build_object('type', 'callout', 'title', 'Catatan', 'text', 'Settlement bergeser.')))) || p_extra)
$$;

select tests.authenticate_agent(:'rina');
select cs_api.community_save_post(null, :'resmi', 'post', null, 'diabaikan',
  pg_temp.card('Bursa libur dua hari', '{"stock_code": "bbca", "research_id": "00000000-0000-0000-0000-000000000001", "source": "research"}')
) as saved \gset
select (:'saved'::jsonb ->> 'id') as post \gset
select is((:'saved'::jsonb #> '{attachments,0}') - 'document'::text,
  '{"type": "card", "source": "manual", "stock_code": "BBCA"}'::jsonb,
  'Kartu manual disimpan sebagai lampiran card dengan sumber manual dan kode saham yang dinormalkan');
select is(:'saved'::jsonb ->> 'body',
  E'$BBCA — Jadwal Libur Bursa\n\nBursa libur dua hari\n\nBursa libur pada hari berikut.\n\n1. 25 Desember\n2. 26 Desember\n\nHari libur: 2 hari (+1 hari)\n\nCatatan: Settlement bergeser.\n\nInformasi dari OLT Research.',
  'Isi teks dibuat otomatis dari kartu untuk aplikasi lama');
select is(:'saved'::jsonb #>> '{attachments,0,document,blocks,1,items,1}', '26 Desember', 'Blok kartu tersimpan utuh');
select is(jsonb_array_length(cs_api.community_save_post(null, :'resmi', 'post', null, '',
  pg_temp.card('Kartu dengan gambar') || jsonb_build_array(jsonb_build_object('path', 'posts/' || :'resmi' || '/grafik.png')))
  -> 'attachments'), 2, 'Kartu bisa digabung dengan gambar');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  pg_temp.card('')), 'PT400', 'invalid_card', 'Kartu tanpa kalimat utama ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  pg_temp.card('Satu') || pg_temp.card('Dua')), 'PT400', 'invalid_card', 'Satu postingan hanya boleh satu kartu');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(jsonb_build_object('type', 'card', 'document', jsonb_build_object('version', 1, 'title', 'T',
    'headline', 'H', 'disclaimer', 'D', 'blocks', jsonb_build_array(jsonb_build_object('type', 'video')))))),
  'PT400', 'invalid_card', 'Jenis blok yang tidak dikenal ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  pg_temp.card('Kode salah', '{"stock_code": "12"}')), 'PT400', 'invalid_stock', 'Kode saham kartu divalidasi');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  pg_temp.card('Ini tipuankartu')), 'PT422', 'content_blocked', 'Isi kartu ikut diperiksa kebijakan konten');
select is(cs_api.community_save_post(:'post', :'resmi', 'post', null, '', pg_temp.card('Bursa libur tiga hari', '{"stock_code": "BBCA"}'),
  null, null, null, false, null, (:'saved'::jsonb ->> 'version')::integer) #>> '{attachments,0,document,headline}',
  'Bursa libur tiga hari', 'Draf kartu bisa diubah');
select is(cs_api.community_save_post(null, :'resmi', 'post', null, 'Postingan teks biasa') -> 'attachments', '[]'::jsonb,
  'Postingan teks biasa tetap jalan tanpa kartu');
select is(cs_api.community_submit_post(:'post') ->> 'status', 'pending', 'Kartu diajukan untuk ditinjau');
reset role;

select tests.authenticate_agent(:'budi');
select is(cs_api.community_review_post(:'post', true) ->> 'status', 'published', 'Staf lain menyetujui dan kartu terbit');
reset role;
select ok((select p.attachments -> 0 ->> 'type' = 'card' and p.body like '$BBCA — Jadwal Libur Bursa%'
           from public.posts p join cs.community_posts c on c.post_id = p.id where c.id = :'post'),
  'Postingan di Stream membawa kartu dan teks pendampingnya');
select ok(exists (select 1 from public.post_stocks s join cs.community_posts c on c.post_id = s.post_id
                  where c.id = :'post' and s.stock_code = 'BBCA'),
  'Cashtag di teks pendamping menautkan kartu ke saham');

select tests.authenticate_as(:'pembaca');
select throws_ok(format($$insert into public.posts (author_id, body, attachments) values (%L, 'Palsu', %L)$$,
                        :'pembaca', pg_temp.card('Palsu')),
  'PT400', 'invalid_attachments', 'Pengguna biasa tidak bisa memposting kartu');
reset role;

select * from finish();
rollback;
