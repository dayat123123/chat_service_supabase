begin;
select plan(9);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

select tests.create_user('tr_budi') as budi \gset
select tests.create_agent('Rina Terjemah', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
update public.profiles set display_name = 'Budi Terjemah' where id = :'budi';

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account', 'id', 'help') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room, (:'j'::jsonb ->> 'ticket_number') as num \gset

select is((select m.payload -> 'texts' ->> 'id' from cs_api.get_messages(:'room'::uuid) m
            where m.payload ->> 'code' = 'ticket_opened'),
          (select m.body from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'ticket_opened'),
  'Teks bahasa tiket sama dengan isi pesan');
select ok((select m.payload -> 'texts' ->> 'en' like 'Ticket #' || :'num' || ' opened. Hi Budi Terjemah%'
             from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'ticket_opened'),
  'Salam pembukaan tiket juga tersedia dalam bahasa Inggris dengan nama nasabah');

select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'t1') as claimed \gset

select tests.authenticate_as(:'budi');
select is((select m.payload -> 'texts' ->> 'en' from cs_api.get_messages(:'room'::uuid) m
            where m.payload ->> 'code' = 'ticket_claimed'),
  'Your ticket is now handled by Rina Terjemah – Official CS.',
  'Pesan CS mengambil tiket tersedia dalam bahasa Inggris');
select is((select m.payload -> 'texts' ->> 'id' from cs_api.get_messages(:'room'::uuid) m
            where m.payload ->> 'code' = 'ticket_claimed'),
          (select m.body from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'ticket_claimed'),
  'Pesan CS mengambil tiket dalam bahasa Indonesia sama dengan isinya');

select cs_api.request_complaint() as complaint \gset
reset role;
select format_time_id, format_time_en from (
  select cs.format_time(t.complaint_due_at, 'id') as format_time_id, cs.format_time(t.complaint_due_at, 'en') as format_time_en
    from cs.tickets t where t.id = :'t1'
) x \gset
select tests.authenticate_as(:'budi');
select ok((select m.payload -> 'texts' ->> 'id' like '%' || :'format_time_id' || '%'
             from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'complaint'),
  'Pesan pengaduan Indonesia memuat tenggat dengan format tanggal Indonesia');
select ok((select m.payload -> 'texts' ->> 'en' like '%' || :'format_time_en' || '%'
                   and m.payload -> 'texts' ->> 'en' like 'We have recorded your complaint on %'
             from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'complaint'),
  'Pesan pengaduan Inggris memuat tenggat dengan format tanggal Inggris');
select ok((select m.payload -> 'texts' ->> 'en' not like '%pukul%'
             from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'complaint'),
  'Tanggal di teks Inggris tidak memakai format Indonesia');

reset role;
select is((select count(*)::int from public.messages m
            where m.session_id = :'t1' and m.sender_role = 'system' and not (m.payload ? 'texts')), 0,
  'Setiap pesan sistem tiket baru membawa terjemahan');
select ok(not has_function_privilege('authenticated', 'cs.localized_vars(cs.tickets, jsonb, text)', 'execute')
          and not has_function_privilege('authenticated', 'cs.message_text_in(cs.tickets, text, jsonb, text)', 'execute')
          and not has_function_privilege('authenticated', 'cs.ticket_opened_text(cs.tickets, uuid, text)', 'execute'),
  'Fungsi penerjemah pesan sistem tidak bisa dipanggil langsung');

select * from finish();
rollback;
