begin;
select plan(59);

update private.rate_limits set max_count = 1000 where action in ('message', 'cs_message');
update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;
delete from cs.ticket_labels;

select tests.create_user('tl_budi') as budi \gset
select tests.create_user('tl_citra') as citra \gset
select tests.create_agent('Rani Label', '{cs_agent}', '{"general": 2, "account": 2}') as rani \gset
select tests.create_agent('Sari Label', '{cs_agent}', '{"general": 2, "account": 2}') as sari \gset
select tests.create_agent('Ayu Label', '{cs_super_admin}') as ayu \gset
select tests.create_agent('Kirana Label', '{compliance}') as kirana \gset

select ok((select bool_and(relrowsecurity) from pg_class where oid in ('cs.ticket_labels'::regclass, 'cs.ticket_label_links'::regclass)),
  'RLS aktif di tabel label');
select ok(not has_table_privilege('authenticated', 'cs.ticket_label_links', 'select')
          and not has_table_privilege('authenticated', 'cs.ticket_labels', 'select'),
  'Tabel label tidak bisa dibaca langsung lewat API');
select ok((select bool_and(p.prosecdef and p.proconfig @> array['search_path=""'])
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'cs_api' and p.proname in ('ticket_labels', 'admin_ticket_labels', 'admin_save_ticket_label',
             'admin_reorder_ticket_labels', 'add_ticket_label', 'remove_ticket_label', 'report_ticket_labels')),
  'RPC label SECURITY DEFINER dengan search_path kosong');
select ok(not has_function_privilege('anon', 'cs_api.add_ticket_label(uuid, uuid)', 'execute'),
  'anon tidak bisa memanggil add_ticket_label');
select ok(not has_function_privilege('authenticated', 'cs.ticket_for_label_change(uuid)', 'execute'),
  'Helper izin label tidak bisa dipanggil langsung');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select throws_ok($$select cs_api.ticket_labels()$$, 'PT403', 'agent_required', 'Nasabah tidak bisa membaca daftar label');
select throws_ok($$select cs_api.admin_ticket_labels()$$, 'PT403', 'agent_required', 'Nasabah tidak bisa mengelola label');
select throws_ok(format($$select cs_api.add_ticket_label(%L, gen_random_uuid())$$, :'ticket'), 'PT403', 'agent_required',
  'Nasabah tidak bisa memberi label');
select throws_ok($$select * from cs.ticket_label_links$$, '42501', null, 'Nasabah tidak bisa membaca tautan label');
reset role;
select tests.authenticate_as(:'citra');
select cs_api.open_ticket('account') ->> 'id' as other_ticket \gset
reset role;

select tests.authenticate_agent(:'rani');
select throws_ok($$select cs_api.admin_save_ticket_label(null, 'Refund', 'warning', true)$$, 'PT403', 'role_forbidden',
  'CS biasa tidak bisa mengelola daftar label');
select throws_ok($$select cs_api.report_ticket_labels(current_date, current_date)$$, 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka laporan label');
reset role;

select tests.authenticate_agent(:'ayu');
select is(jsonb_array_length(cs_api.admin_save_ticket_label(null, '  Refund  ', 'warning', true)), 1, 'Super Admin membuat label');
select cs_api.admin_save_ticket_label(null, 'Akun', 'info', true) as list \gset
select is((select x ->> 'name' from jsonb_array_elements(:'list'::jsonb) x where (x ->> 'sort_order')::integer = 0),
  'Refund', 'Label baru ditaruh di urutan akhir');
select (select x ->> 'id' from jsonb_array_elements(:'list'::jsonb) x where x ->> 'name' = 'Refund') as refund \gset
select (select x ->> 'id' from jsonb_array_elements(:'list'::jsonb) x where x ->> 'name' = 'Akun') as akun \gset
select throws_ok(format($$select cs_api.admin_save_ticket_label(null, %L, 'info', true)$$, repeat('a', 31)),
  'PT400', 'invalid_label_name', 'Nama label lebih dari 30 karakter ditolak');
select throws_ok($$select cs_api.admin_save_ticket_label(null, '   ', 'info', true)$$,
  'PT400', 'invalid_label_name', 'Nama label kosong ditolak');
select throws_ok($$select cs_api.admin_save_ticket_label(null, 'Merah muda', 'pink', true)$$,
  'PT400', 'invalid_label_color', 'Warna di luar palet ditolak');
select throws_ok($$select cs_api.admin_save_ticket_label(null, 'REFUND', 'danger', true)$$,
  'PT409', 'duplicate_label', 'Nama label ganda (beda huruf besar) ditolak');
select throws_ok($$select cs_api.admin_save_ticket_label(gen_random_uuid(), 'Baru', 'info', true)$$,
  'PT404', 'label_not_found', 'Label yang tidak ada tidak bisa diubah');
select lives_ok(format($$select cs_api.admin_save_ticket_label(%L, 'Refund dana', 'danger', true)$$, :'refund'),
  'Super Admin mengubah label');
select is((select count(*)::integer from cs.cs_audit_log where action = 'ticket_label.save' and actor_id = :'ayu'), 3,
  'Setiap simpan label tercatat di audit');
select is((select details #>> '{before,name}' || ' -> ' || (details #>> '{after,name}') from cs.cs_audit_log
           where action = 'ticket_label.save' and details ->> 'label_id' = :'refund' and details ? 'before'),
  'Refund -> Refund dana', 'Audit perubahan label memuat sebelum dan sesudah');
select is((select x ->> 'name' from jsonb_array_elements(
             cs_api.admin_reorder_ticket_labels(array[:'akun', :'refund']::uuid[])) x where (x ->> 'sort_order')::integer = 0),
  'Akun', 'Super Admin mengatur urutan label');
select throws_ok(format($$select cs_api.admin_reorder_ticket_labels(array[%L]::uuid[])$$, :'akun'),
  'PT400', 'invalid_label_order', 'Urutan yang tidak memuat semua label ditolak');
select is((select count(*)::integer from cs.cs_audit_log where action = 'ticket_label.reorder'), 1, 'Perubahan urutan tercatat di audit');
reset role;

insert into cs.ticket_labels (name, color, active, sort_order)
select 'Label ' || i, 'neutral', true, 10 + i from generate_series(1, 48) i;
insert into cs.ticket_labels (name, color, active, sort_order) values ('Lama', 'neutral', false, 99);
select id as old_label from cs.ticket_labels where name = 'Lama' \gset

select tests.authenticate_agent(:'ayu');
select throws_ok($$select cs_api.admin_save_ticket_label(null, 'Ke-51', 'info', true)$$,
  'PT409', 'label_limit', 'Label aktif ke-51 ditolak');
select throws_ok(format($$select cs_api.admin_save_ticket_label(%L, 'Lama', 'neutral', true)$$, :'old_label'),
  'PT409', 'label_limit', 'Mengaktifkan label saat sudah 50 aktif ditolak');
select lives_ok($$select cs_api.admin_save_ticket_label(null, 'Arsip', 'neutral', false)$$,
  'Label nonaktif tetap bisa dibuat saat batas aktif tercapai');
select lives_ok(format($$select cs_api.admin_save_ticket_label(%L, 'Refund dana', 'warning', true)$$, :'refund'),
  'Label aktif tetap bisa diubah saat batas tercapai');
reset role;

select tests.authenticate_agent(:'rani');
select is(jsonb_array_length(cs_api.ticket_labels()), 50, 'CS melihat hanya label aktif');
select is((cs_api.ticket_labels() -> 0) ->> 'name', 'Akun', 'Daftar label mengikuti urutan Super Admin');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'ticket', :'refund'), 'PT403', 'not_ticket_owner',
  'Tiket antrean belum bisa diberi label oleh CS yang belum memegangnya');
reset role;

select string_agg(id::text, ',' order by name) as more_labels from cs.ticket_labels where name in ('Label 1', 'Label 2', 'Label 3') \gset
select tests.agent_online(:'rani');
select tests.authenticate_agent(:'rani');
select cs_api.claim_ticket(:'ticket') ->> 'id' as claimed \gset
select is(jsonb_array_length(cs_api.add_ticket_label(:'ticket', :'refund')), 1, 'CS pemegang tiket menambah label');
select is(jsonb_array_length(cs_api.add_ticket_label(:'ticket', :'refund')), 1, 'Menambah label yang sama tidak menggandakan');
select is((cs_api.ticket_detail(:'ticket') -> 'labels' -> 0) ->> 'name', 'Refund dana', 'Label terlihat di detail tiket');
select is((cs_api.ticket_detail(:'ticket') -> 'labels' -> 0) ->> 'color', 'warning', 'Detail tiket memuat warna label');
select ok((select bool_or(x -> 'labels' @> '[{"name": "Refund dana"}]')
           from jsonb_array_elements(cs_api.ticket_lists() -> 'mine') x), 'Label terlihat di daftar tiket');
select lives_ok(format($$select cs_api.add_ticket_label(%L, x::uuid) from unnest(string_to_array(%L || ',' || %L, ',')) x$$,
                       :'ticket', :'more_labels', :'akun'),
  'CS menambah label sampai lima');
reset role;
select is((select count(*)::integer from cs.ticket_label_links where ticket_id = :'ticket'), 5, 'Tiket memiliki lima label');
select id as label_4 from cs.ticket_labels where name = 'Label 4' \gset

select tests.authenticate_agent(:'rani');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'ticket', :'label_4'), 'PT409', 'ticket_label_limit',
  'Label keenam ditolak');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'ticket', :'old_label'), 'PT409', 'label_inactive',
  'Label nonaktif tidak bisa ditambahkan');
select throws_ok(format($$select cs_api.add_ticket_label(%L, gen_random_uuid())$$, :'ticket'), 'PT404', 'label_not_found',
  'Label yang tidak ada ditolak');
select is(jsonb_array_length(cs_api.remove_ticket_label(:'ticket', :'akun')), 4, 'CS pemegang tiket menghapus label');
reset role;

select tests.authenticate_agent(:'sari');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'ticket', :'akun'), 'PT404', 'ticket_not_found',
  'CS lain tidak bisa memberi label pada tiket yang dipegang orang lain');
select throws_ok(format($$select cs_api.remove_ticket_label(%L, %L)$$, :'ticket', :'refund'), 'PT404', 'ticket_not_found',
  'CS lain tidak bisa menghapus label tiket orang lain');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'other_ticket', :'akun'), 'PT403', 'not_ticket_owner',
  'CS yang hanya melihat antrean tidak bisa memberi label');
reset role;

select tests.authenticate_agent(:'kirana');
select throws_ok(format($$select cs_api.add_ticket_label(%L, %L)$$, :'ticket', :'akun'), 'PT403', 'role_forbidden',
  'Kepatuhan tidak bisa mengubah label');
reset role;

select tests.authenticate_agent(:'ayu');
select is(jsonb_array_length(cs_api.remove_ticket_label(:'ticket', :'refund')), 3, 'Super Admin pemantau bisa menghapus label');
select is(jsonb_array_length(cs_api.add_ticket_label(:'other_ticket', :'refund')), 1, 'Super Admin bisa memberi label tiket antrean');
select is((select count(*)::integer from jsonb_array_elements(cs_api.ticket_detail(:'ticket') -> 'events') e
           where e ->> 'type' in ('label_added', 'label_removed')), 7, 'Perubahan label tercatat di riwayat tiket');
select is((select e ->> 'actor_name' from jsonb_array_elements(cs_api.ticket_detail(:'ticket') -> 'events') e
           where e ->> 'type' = 'label_removed' and e #>> '{data,label}' = 'Refund dana'), 'Ayu Label',
  'Riwayat label mencatat pelaku dan nama label');
select cs_api.report_ticket_labels(current_date - 1, current_date) as report \gset
select is((select (x ->> 'count')::integer from jsonb_array_elements(:'report'::jsonb -> 'labels') x where x ->> 'name' = 'Refund dana'),
  1, 'Laporan menghitung tiket per label pada periode');
select ok((:'report'::jsonb ->> 'total')::integer >= 2 and (:'report'::jsonb ->> 'unlabeled')::integer >= 0,
  'Laporan memuat total dan tiket tanpa label');
select ok(not exists (select 1 from jsonb_array_elements(:'report'::jsonb -> 'labels') x where x ->> 'name' = 'Arsip'),
  'Label nonaktif tanpa tiket tidak masuk laporan');
select throws_ok($$select cs_api.report_ticket_labels(current_date, current_date - 1)$$, 'PT400', 'invalid_range',
  'Rentang laporan label divalidasi');
reset role;

select is((select count(*)::integer from cs.cs_audit_log where action in ('ticket.label_add', 'ticket.label_remove')), 8,
  'Perubahan label tiket tercatat di audit');
select ok(exists (select 1 from realtime.messages where topic = 'cs:queue' and event = 'ticket'
                  and payload ->> 'event' = 'ticket_labels' and payload ->> 'ticket_id' = :'ticket'),
  'Perubahan label disiarkan lewat kanal tiket yang sudah ada');
select ok(exists (select 1 from realtime.messages where topic = 'cs:room:' || (select room_id::text from cs.tickets where id = :'ticket')
                  and event = 'ticket' and payload ->> 'event' = 'ticket_labels'),
  'Staf yang membuka tiket menerima penyegaran label');

select tests.authenticate_as(:'budi');
select ok(not (cs_api.support_home() -> 'ticket') ? 'labels', 'Nasabah tidak menerima label di beranda bantuan');
select throws_ok(format($$select cs_api.ticket_detail(%L)$$, :'ticket'), 'PT403', 'agent_required',
  'Nasabah tidak bisa membuka detail tiket staf');
reset role;

select * from finish();
rollback;
