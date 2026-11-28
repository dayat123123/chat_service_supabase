begin;
select plan(9);

update private.rate_limits set max_count = 1000 where action in ('post', 'post_share_link');
update cs.cs_settings set value = '{"enabled": true, "base_url": "http://192.168.0.235:8000", "preview": true}' where key = 'share.links';

select is(cs.setting('banners.deep_link_schemes'), '["rendezvous-olt"]'::jsonb,
  'Skema aplikasi bawaan menjadi rendezvous-olt');
select ok(exists (select 1 from cs.cs_settings_history
                  where key = 'banners.deep_link_schemes' and old_value = '["olt"]'::jsonb
                    and new_value = '["rendezvous-olt"]'::jsonb and changed_by is null),
  'Penggantian olt ke rendezvous-olt tercatat di riwayat pengaturan');
select is(private.app_scheme(), 'rendezvous-olt', 'Skema utama tautan berbagi rendezvous-olt');

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_user('rs_ani') as ani \gset
insert into public.posts (author_id, body) values (:'ani', 'Post skema baru') returning id as post \gset

select tests.authenticate_as(:'ani');
select matches(public.post_share_link(:'post') ->> 'app_url', '^rendezvous-olt://p/[A-Za-z0-9]{10}$',
  'Tombol Buka di aplikasi memakai rendezvous-olt://p/<kode>');
reset role;

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_save_banner(null, 'Promo', p_link_url => 'rendezvous-olt://promo/akhir-tahun')$$,
  'Banner boleh memakai tautan rendezvous-olt://');
select throws_ok($$select cs_api.admin_save_banner(null, 'Lama', p_link_url => 'olt://promo/akhir-tahun')$$,
  'PT400', 'invalid_link', 'Skema olt:// tidak lagi diizinkan');
select is(cs_api.admin_set_banner_link_schemes('{" Rendezvous-OLT ",mitra}') -> 'deep_link_schemes',
  '["rendezvous-olt", "mitra"]'::jsonb, 'Skema bertanda hubung lolos validasi dan dinormalisasi huruf kecil');
reset role;

update cs.cs_settings set value = '{}' where key = 'banners.deep_link_schemes';
select is(private.banner_link_schemes(), '{rendezvous-olt}'::text[], 'Nilai rusak kembali ke skema bawaan rendezvous-olt');

select tests.authenticate_service();
select is(public.share_link_config() ->> 'app_scheme', 'rendezvous-olt', 'Layanan share-link menerima skema rendezvous-olt');
reset role;

select * from finish();
rollback;
