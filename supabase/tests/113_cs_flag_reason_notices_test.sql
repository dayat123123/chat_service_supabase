begin;
select plan(15);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('flag_budi') as budi \gset
select tests.create_user('flag_sari') as sari \gset
select tests.create_agent('Rina Tanda', '{cs_agent}', '{"general": 2, "account": 2, "complaint": 2, "fraud": 2}') as rina \gset
select tests.create_agent('Dimas Tanda', '{cs_agent}', '{"general": 2, "account": 2}') as dimas \gset
select tests.create_agent('Kirana Tanda', '{compliance}', '{}') as kirana \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
reset role;
select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'t1') is not null as claimed \gset
reset role;

select tests.authenticate_agent(:'kirana');
select is((cs_api.compliance_notices_seen() ->> 'unseen')::integer, 0, 'Kepatuhan mulai tanpa notifikasi baru');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.flag_ticket(%L, 'complaint', 'abc')$$, :'t1'), 'PT400', 'reason_required',
  'Alasan terlalu pendek ditolak');
select ok(cs_api.flag_ticket(:'t1', 'complaint', '  Nasabah keberatan atas biaya admin  ') -> 'flags' ? 'complaint',
  'CS pemilik menandai tiket sebagai pengaduan dengan alasan');
select throws_ok(format($$select cs_api.flag_ticket(%L, 'complaint', 'Tandai ulang tiket')$$, :'t1'), 'PT409',
  'already_flagged', 'Tanda yang sama tidak bisa dipasang dua kali');
reset role;

select tests.authenticate_agent(:'dimas');
select throws_ok(format($$select cs_api.flag_ticket(%L, 'fraud', 'Indikasi penipuan')$$, :'t1'), 'PT403',
  'not_ticket_owner', 'CS lain tidak bisa menandai tiket yang bukan miliknya');
select throws_ok($$select cs_api.compliance_notices()$$, 'PT403', null, 'CS biasa tidak membaca notifikasi Kepatuhan');
reset role;

select is((select data ->> 'reason' from cs.session_events where session_id = :'t1' and type = 'flagged'),
  'Nasabah keberatan atas biaya admin', 'Alasan tersimpan di riwayat tiket');
select is((select details ->> 'reason' from cs.cs_audit_log where action = 'ticket.flag' and session_id = :'t1'),
  'Nasabah keberatan atas biaya admin', 'Alasan tercatat di jejak audit');

select tests.authenticate_agent(:'kirana');
select is((cs_api.compliance_notices() ->> 'unseen')::integer, 1, 'Kepatuhan menerima notifikasi kasus baru');
select ok(cs_api.compliance_notices() -> 'items' -> 0 @> jsonb_build_object('flag', 'complaint', 'source', 'agent',
            'actor_name', 'Rina Tanda', 'reason', 'Nasabah keberatan atas biaya admin', 'seen', false),
  'Notifikasi memuat tanda, alasan, dan nama CS');
select is((cs_api.compliance_notices_seen() ->> 'unseen')::integer, 0, 'Notifikasi ditandai sudah dibaca');
reset role;
select ok(cs.can_access_topic('cs:compliance'), 'Kepatuhan boleh mendengar kanal realtime kasus');

select tests.authenticate_agent(:'dimas');
reset role;
select ok(not cs.can_access_topic('cs:compliance'), 'CS biasa tidak boleh mendengar kanal kasus');

select tests.authenticate_as(:'sari');
select cs_api.report_fake_cs('Ada yang mengaku CS dan meminta kode OTP saya') is not null as reported \gset
reset role;

select tests.authenticate_agent(:'kirana');
select is((cs_api.compliance_notices() ->> 'unseen')::integer, 1, 'Laporan penipuan dari nasabah juga masuk notifikasi');
select is(cs_api.compliance_notices() -> 'items' -> 0 ->> 'source', 'customer', 'Sumber notifikasi dari nasabah');
reset role;

select * from finish();
rollback;
