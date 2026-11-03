begin;
select plan(21);

select tests.create_agent('Sinta Banner', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Banner', '{cs_agent}', '{"general": 1}') as rina \gset

select ok((select relrowsecurity from pg_class where oid = 'private.app_banners'::regclass), 'RLS aktif di tabel banner');

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.admin_banners()', 'PT403', 'role_forbidden', 'Hanya Super Admin yang mengelola banner');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_save_banner(null, '  ')$$, 'PT400', 'invalid_title', 'Judul wajib');
select throws_ok($$select cs_api.admin_save_banner(null, 'Info', p_link_url => 'ftp://olt.example')$$, 'PT400', 'invalid_link',
  'Tautan harus http(s)');
select throws_ok($$select cs_api.admin_save_banner(null, 'Info', p_level => 'danger')$$, 'PT400', 'invalid_level',
  'Level harus info, warning, atau critical');
select throws_ok($$select cs_api.admin_save_banner(null, 'Info', p_platforms => '{android,symbian}')$$, 'PT400', 'invalid_platform',
  'Platform harus dikenal');
select throws_ok($$select cs_api.admin_save_banner(null, 'Info', p_min_app_version => '3.0.0', p_max_app_version => '2.0.0')$$,
  'PT400', 'invalid_version', 'Versi minimum tidak boleh melebihi maksimum');
select throws_ok($$select cs_api.admin_save_banner(null, 'Info', p_starts_at => now() + interval '2 hours',
                                                   p_ends_at => now() + interval '1 hour')$$,
  'PT400', 'invalid_schedule', 'Waktu selesai harus setelah waktu mulai');

select cs_api.admin_save_banner(null, 'Pemeliharaan sistem', 'Layanan chat akan dipelihara pukul 22.00 WIB',
  'https://olt.example/status', 'warning', now() - interval '1 hour', now() + interval '1 day', '{}', null, null, true, 10) as b1 \gset
select cs_api.admin_save_banner(null, 'Versi baru Android', 'Perbarui aplikasi', null, 'info', null, null,
  '{android}', '2.5.0', '2.9.9', false, 5) as b2 \gset
select cs_api.admin_save_banner(null, 'Besok', p_starts_at => now() + interval '1 day') as b3 \gset
select cs_api.admin_save_banner(null, 'Sudah lewat', p_starts_at => now() - interval '2 days',
                                p_ends_at => now() - interval '1 day') as b4 \gset
select is(:'b1'::jsonb ->> 'status', 'active', 'Banner aktif');
select is(:'b3'::jsonb ->> 'status', 'scheduled', 'Banner terjadwal');
select is(:'b4'::jsonb ->> 'status', 'ended', 'Banner berakhir');
select is((select jsonb_agg(b ->> 'title') from jsonb_array_elements(cs_api.admin_banners()) b
           where b ->> 'id' in (:'b1'::jsonb ->> 'id', :'b2'::jsonb ->> 'id', :'b4'::jsonb ->> 'id')),
  '["Pemeliharaan sistem", "Versi baru Android", "Sudah lewat"]'::jsonb, 'Daftar banner: aktif per prioritas, yang berakhir di akhir');
reset role;

select is((select jsonb_agg(b ->> 'title') from jsonb_array_elements(public.get_client_config('android', '2.5.1') -> 'banners') b),
  '["Pemeliharaan sistem", "Versi baru Android"]'::jsonb, 'Konfigurasi klien memuat banner aktif sesuai platform dan versi');
select is((public.get_client_config('android', '2.5.1') -> 'banners' -> 0),
  jsonb_build_object('id', :'b1'::jsonb -> 'id', 'title', 'Pemeliharaan sistem',
                     'body', 'Layanan chat akan dipelihara pukul 22.00 WIB', 'link_url', 'https://olt.example/status',
                     'level', 'warning', 'dismissible', true, 'priority', 10,
                     'starts_at', :'b1'::jsonb -> 'starts_at', 'ends_at', :'b1'::jsonb -> 'ends_at'),
  'Bentuk banner untuk klien');
select is((select jsonb_agg(b ->> 'title') from jsonb_array_elements(public.get_client_config('android', '2.4.0') -> 'banners') b)
          || (select jsonb_agg(b ->> 'title') from jsonb_array_elements(public.get_client_config('ios', '2.6.0') -> 'banners') b)
          || (select jsonb_agg(b ->> 'title') from jsonb_array_elements(public.get_client_config() -> 'banners') b),
  '["Pemeliharaan sistem", "Pemeliharaan sistem", "Pemeliharaan sistem"]'::jsonb,
  'Banner berbatas platform/versi tidak tampil untuk versi lama, platform lain, atau tanpa versi');
select tests.authenticate_anon();
select is(jsonb_array_length(public.get_client_config('web') -> 'banners'), 1, 'Banner tersedia sebelum login');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_save_banner((:'b1'::jsonb ->> 'id')::uuid, 'Pemeliharaan diundur', p_level => 'critical') ->> 'level',
  'critical', 'Banner bisa diubah');
select is(cs_api.admin_delete_banner((:'b3'::jsonb ->> 'id')::uuid) ->> 'deleted', 'true', 'Banner bisa dihapus');
select throws_ok(format($$select cs_api.admin_delete_banner(%L)$$, :'b3'::jsonb ->> 'id'), 'PT404', 'banner_not_found',
  'Banner yang sudah dihapus tidak ditemukan');
reset role;
select is((select string_agg(action, ',' order by action) from cs.cs_audit_log
           where action like 'banner.%' and details ->> 'id' in (:'b1'::jsonb ->> 'id', :'b3'::jsonb ->> 'id')),
  'banner.delete,banner.save,banner.save,banner.save', 'Perubahan banner tercatat di audit');
select is((select details #>> '{before,title}' || ' -> ' || (details #>> '{after,title}') from cs.cs_audit_log
           where action = 'banner.save' and details ->> 'id' = :'b1'::jsonb ->> 'id' and details -> 'before' <> 'null'::jsonb),
  'Pemeliharaan sistem -> Pemeliharaan diundur', 'Audit menyimpan isi sebelum dan sesudah');

select * from finish();
rollback;
