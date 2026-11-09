begin;
select plan(17);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('inc_budi') as budi \gset
select tests.create_agent('Sinta Gangguan', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Gangguan', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_save_incident(null, 'Gangguan', 'Outage', 'Login lambat', 'Slow login', 'warning')$$,
  'PT403', null, 'CS biasa tidak bisa memasang pengumuman gangguan');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_save_incident(null, 'Gangguan', 'Outage', 'Login lambat', 'Slow login', 'panic')$$,
  'PT400', 'invalid_incident', 'Tingkat gangguan di luar daftar ditolak');
select throws_ok($$select cs_api.admin_save_incident(null, 'Gangguan', 'Outage', 'Login lambat', 'Slow login', 'info', now(), now() - interval '1 hour')$$,
  'PT400', 'invalid_incident', 'Waktu selesai sebelum mulai ditolak');
select cs_api.admin_save_incident(null, 'Login lambat', 'Slow login', 'Kami sedang memperbaiki login.', 'We are fixing login.',
  'critical', now() - interval '10 minutes') ->> 'id' as incident \gset
select cs_api.admin_save_incident(null, 'Pemeliharaan nanti', 'Maintenance later', 'Pemeliharaan malam ini.', 'Maintenance tonight.',
  'info', now() + interval '1 day') ->> 'id' as later \gset
reset role;

select tests.authenticate_as(:'budi');
select is(jsonb_array_length(cs_api.support_home() -> 'incidents'), 1, 'Hanya gangguan yang sedang berlangsung tampil');
select ok(cs_api.service_status('en') -> 'incidents' @> '[{"title": "Slow login", "level": "critical"}]',
  'Status layanan mengikuti bahasa');
select ok(cs_api.support_home() -> 'survey' -> 'en' @> '{"scale": 5, "low_max": 2}', 'Pengaturan survei dikirim ke aplikasi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
reset role;

select tests.authenticate_agent(:'sinta');
select is((select (x ->> 'tickets')::integer from jsonb_array_elements(cs_api.admin_incidents()) x where x ->> 'id' = :'incident'), 1,
  'Jumlah tiket selama gangguan dihitung');
select is(cs_api.admin_end_incident(:'incident') ->> 'active', 'false', 'Super Admin mengakhiri gangguan');
select throws_ok($$select cs_api.admin_set_survey_config('{"question": {"id": "Bagaimana layanan kami?", "en": "How was it?"}, "scale": 4, "low_max": 2, "reasons": []}')$$,
  'PT400', 'invalid_survey', 'Skala selain 3 atau 5 ditolak');
select ok(cs_api.admin_set_survey_config('{"question": {"id": "Seberapa puas Anda?", "en": "How satisfied are you?"}, "scale": 3, "low_max": 1,
  "reasons": [{"code": "slow", "id": "Lama", "en": "Slow"}, {"code": "rude", "id": "Kurang ramah", "en": "Unfriendly"}]}')
  -> 'config' @> '{"scale": 3, "low_max": 1}', 'Super Admin mengubah survei');
reset role;

select ok((select count(*) from cs.cs_audit_log where actor_id = :'sinta' and action in ('incident.save', 'incident.end', 'survey.config')) >= 4,
  'Perubahan gangguan dan survei tercatat di jejak audit');

select tests.authenticate_as(:'budi');
select is(jsonb_array_length(cs_api.support_home() -> 'incidents'), 0, 'Gangguan yang diakhiri hilang dari aplikasi');
reset role;

select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'ticket') is not null as claimed \gset
select cs_api.resolve_ticket(:'ticket', 'answered', 'Login sudah normal') is not null as resolved \gset
reset role;

select tests.authenticate_as(:'budi');
select throws_ok(format($$select cs_api.rate_ticket(%L, 2)$$, :'ticket'), 'PT400', 'invalid_rating',
  'Nilai di luar skala 3 ditolak');
select throws_ok(format($$select cs_api.rate_ticket(%L, 5, null, '{slow}')$$, :'ticket'), 'PT400', 'invalid_reasons',
  'Alasan hanya untuk nilai rendah');
select throws_ok(format($$select cs_api.rate_ticket(%L, 1, null, '{lainnya}')$$, :'ticket'), 'PT400', 'invalid_reasons',
  'Alasan di luar daftar ditolak');
select is(cs_api.rate_ticket(:'ticket', 1, 'Lama sekali', '{slow,rude,slow}') ->> 'rating', '1', 'Nasabah memberi nilai rendah dengan alasan');
reset role;

select tests.authenticate_agent(:'sinta');
select ok(cs_api.admin_rating_reasons(current_date - 1, current_date) -> 'by_agent'
          @> jsonb_build_array(jsonb_build_object('agent_name', 'Rina Gangguan', 'reason', 'slow', 'count', 1)),
  'Laporan alasan nilai rendah per CS');
reset role;

select * from finish();
rollback;
