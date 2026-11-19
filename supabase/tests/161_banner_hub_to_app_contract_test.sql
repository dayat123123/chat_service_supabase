begin;
select plan(18);

delete from private.app_banners;

select tests.create_user('kb_baru') as baru \gset
select tests.create_user('kb_lama') as lama \gset
update public.profiles set created_at = now() - interval '30 days' where id = :'lama';
select tests.create_agent('Sinta Kontrak', '{cs_super_admin}', '{}') as sinta \gset
select gen_random_uuid() || '.jpg' as img \gset
select 'https://api.olt.example/storage/v1/object/public/app-banners/' as base \gset

select tests.authenticate_agent(:'sinta');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                       :'img', :'sinta'),
  'Gambar popup terunggah');

select cs_api.admin_save_banner(null, 'Promo kotak', p_display => 'popup', p_image_url => :'base' || :'img',
                                p_image_ratio => 'square') as popup \gset
select is(:'popup'::jsonb ->> 'image_ratio', 'square', 'Hub menyimpan rasio gambar 1:1');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_image_url => %L,
                                                          p_image_ratio => 'wide')$$, :'base' || :'img'),
  'PT400', 'invalid_image_ratio', 'Rasio selain 4:5 dan 1:1 ditolak');
select is(cs_api.admin_save_banner((:'popup'::jsonb ->> 'id')::uuid, 'Promo kotak', p_display => 'popup',
                                   p_image_url => :'base' || :'img') ->> 'image_ratio', 'square',
  'Hub lama yang tidak mengirim rasio tidak menghapus rasio gambar yang sama');
select is(cs_api.admin_save_banner((:'popup'::jsonb ->> 'id')::uuid, 'Promo kotak', p_display => 'popup',
                                   p_image_url => :'base' || :'img', p_image_ratio => 'portrait') ->> 'image_ratio',
  'portrait', 'Rasio bisa diganti bersama gambarnya');
select ok(not (cs_api.admin_save_banner(null, 'Strip', p_image_ratio => 'square') ? 'image_ratio'),
  'Strip tanpa gambar tidak menyimpan rasio');
select ok(not (cs_api.admin_save_banner((:'popup'::jsonb ->> 'id')::uuid, 'Promo kotak', p_display => 'popup',
                                        p_image_ratio => 'square') ? 'image_ratio'),
  'Melepas gambar ikut melepas rasionya');
select cs_api.admin_save_banner((:'popup'::jsonb ->> 'id')::uuid, 'Promo kotak', p_display => 'popup',
                                p_image_url => :'base' || :'img', p_image_ratio => 'square') as popup \gset

select cs_api.admin_save_banner(
  null, 'Kontrak lengkap',
  p_body => 'Isi kontrak', p_link_url => 'https://olt.example/info', p_level => 'warning',
  p_ends_at => now() + interval '3 days', p_platforms => '{windows,web}',
  p_min_app_version => '0.1.0', p_max_app_version => '0.2.0', p_dismissible => false, p_priority => 7,
  p_cta_label => 'Baca', p_frequency => 'daily', p_audience => 'new_users', p_audience_days => 7) as strip \gset
reset role;

create temp table kb_seen (who text, item jsonb);
grant all on kb_seen to authenticated, anon;

select tests.authenticate_as(:'baru');
insert into kb_seen select 'windows', e from jsonb_array_elements(public.get_client_config('windows', '0.1.53+54') -> 'banners') e;
insert into kb_seen select 'android', e from jsonb_array_elements(public.get_client_config('android', '0.1.53+54') -> 'banners') e;
insert into kb_seen select 'newer', e from jsonb_array_elements(public.get_client_config('web', '0.3.0') -> 'banners') e;
insert into kb_seen select 'unversioned', e from jsonb_array_elements(public.get_client_config('windows') -> 'banners') e;
select throws_ok($$select public.get_client_config('windows', 'versi baru')$$, 'PT400', 'invalid_version',
  'Versi aplikasi yang bukan angka ditolak');
reset role;

select tests.authenticate_as(:'lama');
insert into kb_seen select 'lama', e from jsonb_array_elements(public.get_client_config('windows', '0.1.53+54') -> 'banners') e;
reset role;

select tests.authenticate_anon();
insert into kb_seen select 'anon', e from jsonb_array_elements(public.get_client_config('windows', '0.1.53+54') -> 'banners') e;
reset role;

select is((select item - 'starts_at' - 'ends_at' from kb_seen where who = 'windows' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  jsonb_build_object('id', :'strip'::jsonb ->> 'id', 'title', 'Kontrak lengkap', 'body', 'Isi kontrak',
                     'link_url', 'https://olt.example/info', 'cta_label', 'Baca', 'level', 'warning',
                     'dismissible', false, 'priority', 7, 'display', 'strip', 'image_url', null, 'frequency', 'daily'),
  'Semua isian Hub sampai ke aplikasi apa adanya');
select ok((select (item ->> 'ends_at')::timestamptz > now() + interval '2 days'
                  and (item ->> 'starts_at')::timestamptz <= now()
           from kb_seen where who = 'windows' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Jadwal mulai dan selesai ikut terkirim');
select is((select item ->> 'image_ratio' from kb_seen where who = 'windows' and item ->> 'id' = :'popup'::jsonb ->> 'id'),
  'square', 'Rasio gambar popup sampai ke aplikasi');
select is((select item ->> 'image_url' from kb_seen where who = 'windows' and item ->> 'id' = :'popup'::jsonb ->> 'id'),
  :'base' || :'img', 'Gambar popup sampai ke aplikasi');
select ok(exists (select 1 from kb_seen where who = 'windows' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Versi dengan nomor build (0.1.53+54) dibandingkan sebagai 0.1.53');
select ok(not exists (select 1 from kb_seen where who = 'android' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Platform di luar pilihan Hub tidak menerima banner');
select ok(not exists (select 1 from kb_seen where who = 'newer' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Versi di atas batas maksimum tidak menerima banner');
select ok(not exists (select 1 from kb_seen where who = 'unversioned' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Aplikasi yang tidak mengirim versi tidak menerima banner berbatas versi');
select ok(not exists (select 1 from kb_seen where who = 'lama' and item ->> 'id' = :'strip'::jsonb ->> 'id')
          and exists (select 1 from kb_seen where who = 'lama' and item ->> 'id' = :'popup'::jsonb ->> 'id'),
  'Banner pengguna baru tidak tampil untuk akun lebih lama dari batas hari');
select ok(not exists (select 1 from kb_seen where who = 'anon' and item ->> 'id' = :'strip'::jsonb ->> 'id'),
  'Tamu tidak menerima banner khusus pengguna baru');

select * from finish();
rollback;
