begin;
select plan(17);

update cs.cs_settings set value = '100000' where key = 'integration.broadcast_batch_size';

select tests.create_user('lt_budi') as budi \gset
select tests.create_agent('Pandu Panjang', '{product}', '{}') as pandu \gset
select tests.create_agent('Sinta Panjang', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Maya Panjang', '{community}', '{}') as maya \gset
select repeat('a', 120) as t120, repeat('a', 121) as t121 \gset
select repeat('b', 300) as b300, repeat('b', 301) as b301, repeat('c', 5000) as b5000, repeat('c', 5001) as b5001 \gset
select repeat('Jadwal pemeliharaan server. ', 80) as long_body \gset
select rpad('Pengumuman dividen', 119, ' dan info') || 'k' as ct120, rpad('Pengumuman dividen', 120, ' dan info') || 'k' as ct121,
       rpad('Info dividen BBCA', 499, ' dan lainnya') || 'k' as cb500, rpad('Info dividen BBCA', 500, ' dan lainnya') || 'k' as cb501 \gset

select tests.authenticate_agent(:'pandu');
select lives_ok(format($$select cs_api.admin_save_banner(null, %L)$$, :'t120'), 'Judul banner sampai 120 karakter');
select throws_ok(format($$select cs_api.admin_save_banner(null, %L)$$, :'t121'), 'PT400', 'invalid_title',
  'Judul banner lebih dari 120 karakter ditolak');
select lives_ok(format($$select cs_api.admin_save_banner(null, 'Strip', %L)$$, :'b300'), 'Isi strip sampai 300 karakter');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Strip', %L)$$, :'b301'), 'PT400', 'invalid_body',
  'Isi strip lebih dari 300 karakter ditolak');
select cs_api.admin_save_banner(null, 'Popup panjang', :'b5000', p_display => 'popup') as popup_view \gset
select :'popup_view'::jsonb ->> 'id' as popup \gset
select is(char_length(:'popup_view'::jsonb ->> 'body'), 5000, 'Isi popup sampai 5000 karakter tersimpan');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Popup', %L, p_display => 'popup')$$, :'b5001'),
  'PT400', 'invalid_body', 'Isi popup lebih dari 5000 karakter ditolak');
select throws_ok(format($$select cs_api.admin_save_banner(%L, 'Popup panjang', %L)$$, :'popup', :'b5000'),
  'PT400', 'invalid_body', 'Popup berisi panjang tidak bisa diubah menjadi strip');

select cs_api.admin_save_banner(null, 'Pemeliharaan panjang', :'long_body', p_display => 'popup', p_notify => true)
  -> 'notice' ->> 'id' as long_notice \gset
select cs_api.admin_save_banner(null, 'Pemeliharaan singkat', 'Pukul 22.00 WIB', p_notify => true)
  -> 'notice' ->> 'id' as short_notice \gset
reset role;

select private.app_notice_tick();
select ok((select char_length(payload ->> 'body') <= 280 and payload ->> 'body' like '%…'
                  and payload -> 'body_truncated' = 'true'::jsonb
           from public.notifications where user_id = :'budi' and payload ->> 'notice_id' = :'long_notice'),
  'Notifikasi nasabah hanya membawa cuplikan isi panjang');
select ok((select not (payload ? 'body_truncated') and payload ->> 'body' = 'Pukul 22.00 WIB'
           from public.notifications where user_id = :'budi' and payload ->> 'notice_id' = :'short_notice'),
  'Isi pendek dikirim utuh tanpa tanda terpotong');
select ok(not exists (select 1 from private.push_queue where user_id = :'budi' and char_length(body) > 1000),
  'Push tetap di bawah batas 1000 karakter');

select tests.authenticate_as(:'budi');
select is(public.get_app_notice(:'long_notice'::uuid) ->> 'body', rtrim(:'long_body'),
  'Halaman info memuat isi lengkap dari server');
select ok(not (public.get_app_notice(:'long_notice'::uuid) ? 'body_truncated'), 'Isi lengkap tidak ditandai terpotong');
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.admin_set_community_permissions(:'sinta', '{community.accounts}') as sinta_perms \gset
select cs_api.community_save_account(null, 'lt_resmi', 'OLT Resmi', 'Akun resmi') ->> 'id' as account \gset
select cs_api.admin_set_community_permissions(:'maya', '{community.post}') as perms \gset
reset role;
select tests.authenticate_agent(:'maya');
select lives_ok(format($$select cs_api.community_save_campaign(null, %L, %L, %L)$$, :'account', :'ct120', :'cb500'),
  'Notifikasi Komunitas: judul 120 dan isi 500 karakter');
select throws_ok(format($$select cs_api.community_save_campaign(null, %L, %L, 'Isi singkat')$$, :'account', :'ct121'),
  'PT400', 'invalid_title', 'Judul notifikasi Komunitas lebih dari 120 karakter ditolak');
select throws_ok(format($$select cs_api.community_save_campaign(null, %L, 'Judul', %L)$$, :'account', :'cb501'),
  'PT400', 'invalid_body', 'Isi notifikasi Komunitas lebih dari 500 karakter ditolak');
reset role;

select throws_ok(format($$insert into private.app_banners (title, body, display) values ('Strip', %L, 'strip')$$, :'b301'),
  '23514', null, 'Tabel banner menolak strip berisi lebih dari 300 karakter');
select is(private.notice_preview(repeat('x', 280)), repeat('x', 280), 'Isi 280 karakter tidak dipotong');

select * from finish();
rollback;
