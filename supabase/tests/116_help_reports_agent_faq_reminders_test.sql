begin;
select plan(15);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('rep_budi') as budi \gset
select tests.create_agent('Sinta Laporan', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Laporan', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Laras Laporan', '{cs_content}', '{}') as laras \gset
select (select id from cs.faq_categories where code = 'account') as account \gset

select tests.authenticate_agent(:'laras');
select cs_api.admin_faq_save_article(null, :'account', 'Bagaimana cara ganti PIN?', 'How to change PIN?',
  'Buka Profil lalu Ganti PIN.', 'Open Profile then Change PIN.', '{pin}', 'account', 0) ->> 'id' as pin \gset
select cs_api.admin_faq_set_status(:'pin', 'published') is not null as published \gset
reset role;

select tests.authenticate_as(:'budi');
select cs_api.faq_article(:'pin', 'id') is not null as read \gset
select cs_api.faq_feedback(:'pin', true) is not null as voted \gset
select throws_ok(format($$select cs_api.ticket_transcript(%L)$$, gen_random_uuid()), 'PT404', 'ticket_not_found',
  'Transkrip tiket orang lain atau yang tidak ada ditolak');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select throws_ok(format($$select cs_api.ticket_transcript(%L)$$, :'ticket'), 'PT409', 'ticket_active',
  'Transkrip baru tersedia setelah tiket selesai');
reset role;

select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'ticket') is not null as claimed \gset
select is(jsonb_array_length(cs_api.agent_faq_search('ganti pin', 'id')), 1, 'CS mencari artikel FAQ untuk disisipkan ke chat');
select is(cs_api.agent_faq_search('ganti pin', 'id') -> 0 ->> 'answer', 'Buka Profil lalu Ganti PIN.', 'Hasil memuat jawaban artikel');
select throws_ok(format($$select cs_api.agent_flag_faq(%L, 'ok')$$, :'pin'), 'PT400', 'reason_required',
  'Catatan penandaan artikel wajib diisi');
select ok(cs_api.agent_flag_faq(:'pin', 'Menu Ganti PIN sudah pindah ke Keamanan') ? 'id', 'CS menandai artikel perlu diperbarui');
reset role;

select tests.authenticate_agent(:'laras');
select is((select (x ->> 'open_flags')::integer from jsonb_array_elements(cs_api.admin_faq() -> 'articles') x where x ->> 'id' = :'pin'), 1,
  'Konten Layanan melihat jumlah tanda yang belum selesai');
select is(cs_api.admin_faq_flags(:'pin') -> 0 ->> 'agent_name', 'Rina Laporan', 'Tanda memuat nama CS');
select is(cs_api.admin_faq_resolve_flags(:'pin') -> 0 ->> 'resolved_by_name', 'Laras Laporan', 'Tanda ditandai selesai');
reset role;

update cs.tickets set status = 'waiting_customer', last_agent_message_at = now() - interval '30 hours',
                      last_customer_message_at = now() - interval '31 hours'
 where id = :'ticket';
select is(cs.remind_waiting_customers(), 1, 'Pengingat dikirim untuk tiket yang menunggu nasabah terlalu lama');
select is(cs.remind_waiting_customers(), 0, 'Pengingat tidak dikirim dua kali untuk balasan CS yang sama');
select ok(exists (select 1 from public.messages m where m.session_id = :'ticket' and m.payload -> 'texts' ->> 'id' like 'Apakah masih ada%'),
  'Pesan pengingat masuk ke chat tiket');
update cs.cs_settings set value = '0' where key = 'ticket.reminder_hours';
update cs.tickets set reminded_at = null where id = :'ticket';
select is(cs.remind_waiting_customers(), 0, 'Pengingat bisa dimatikan');

select tests.authenticate_agent(:'rina');
select cs_api.resolve_ticket(:'ticket', 'answered', 'PIN berhasil diganti') is not null as resolved \gset
reset role;

select tests.authenticate_as(:'budi');
select ok(jsonb_array_length(cs_api.ticket_transcript(:'ticket') -> 'messages') >= 2, 'Nasabah mengunduh transkrip tiket yang selesai');
reset role;

select tests.authenticate_agent(:'sinta');
select ok((select (x ->> 'tickets')::integer from jsonb_array_elements(cs_api.admin_help_report(current_date - 1, current_date) -> 'topics') x where x ->> 'topic' = 'account') >= 1
          and cs_api.admin_help_report(current_date - 1, current_date) -> 'articles' @> jsonb_build_array(jsonb_build_object('id', :'pin', 'readers', 1, 'helpful', 1, 'tickets_after', 1, 'prevented', 0)),
  'Laporan bantuan memuat topik, artikel, dan tiket setelah membaca');
reset role;

select * from finish();
rollback;
