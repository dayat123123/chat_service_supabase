begin;
select plan(13);

select tests.create_agent('Sinta Hapus Key', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Hapus Key', '{cs_agent}', '{"general": 1}') as rina \gset

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('Notif lama', '{notify}', null, '{}', 600) ->> 'id' as old_key \gset
select cs_api.integration_key_create('Dasbor', '{health_read}', null, '{}', 600) ->> 'id' as health_key \gset
select cs_api.integration_key_create('Notif aktif', '{notify}', null, '{}', 600) ->> 'id' as live_key \gset

select throws_ok(format($$select cs_api.integration_key_delete(%L)$$, :'live_key'),
  'PT409', 'key_not_revoked', 'Key yang masih aktif tidak bisa dihapus');
select cs_api.integration_key_revoke(:'old_key', 'Sistem lama sudah dimatikan') is not null as revoked \gset
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.integration_key_delete(%L)$$, :'old_key'),
  'PT403', null, 'Agen biasa tidak bisa menghapus API key');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.integration_key_delete(:'old_key'), jsonb_build_object('id', :'old_key'::uuid, 'deleted', true),
  'Super Admin menghapus key yang sudah dicabut');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.integration_keys()) k where k ->> 'id' = :'old_key'),
  'Key yang dihapus hilang dari daftar');
select ok(exists (select 1 from jsonb_array_elements(cs_api.integration_keys()) k where k ->> 'id' = :'live_key'),
  'Key lain tetap ada di daftar');
select throws_ok(format($$select cs_api.integration_key_delete(%L)$$, :'old_key'),
  'PT404', 'key_not_found', 'Key yang sudah dihapus tidak bisa dihapus lagi');
select throws_ok(format($$select cs_api.integration_key_delete(%L)$$, gen_random_uuid()),
  'PT404', 'key_not_found', 'Key yang tidak ada ditolak');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.integration_stats(7) -> 'keys') k
                      where k ->> 'id' in (:'old_key', :'health_key')),
  'Statistik notifikasi tidak memuat key yang dihapus maupun key kesehatan sistem');
select ok(exists (select 1 from jsonb_array_elements(cs_api.integration_stats(7) -> 'keys') k
                  where k ->> 'id' = :'live_key' and k -> 'scopes' = '["notify"]'),
  'Statistik notifikasi memuat key notifikasi beserta izinnya');
reset role;

select ok((select deleted_at is not null and deleted_by = :'sinta' and revoked_at is not null
           from private.integration_keys where id = :'old_key'),
  'Key disembunyikan, bukan dibuang: data dan riwayatnya tetap tersimpan');
select ok(exists (select 1 from cs.cs_audit_log a where a.action = 'integration.key_delete'
                  and a.details ->> 'key_id' = :'old_key'),
  'Penghapusan tercatat di jejak audit');
select throws_ok(format($$update private.integration_keys set deleted_at = now() where id = %L$$, :'live_key'),
  '23514', null, 'Database menolak key aktif yang ditandai terhapus');
select is(public.integration_authenticate(
  (select key_hash from private.integration_keys where id = :'old_key'), '1.2.3.4'), null,
  'Key yang dihapus tetap tidak bisa dipakai');

select * from finish();
rollback;
