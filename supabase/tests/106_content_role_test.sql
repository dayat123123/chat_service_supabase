begin;
select plan(9);

select tests.create_agent('Laras', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina', '{cs_agent}') as rina \gset

select is((select roles from cs.agents where user_id = :'laras'), '{cs_content}'::text[],
  'Akun bisa diberi peran Konten Layanan');
select lives_ok($$select cs.check_agent_input('Laras', '{cs_content,cs_agent}', null, 3)$$,
  'Form akun CS menerima peran Konten Layanan');

select tests.authenticate_agent(:'laras');
select ok(jsonb_array_length(cs_api.admin_topics()) > 0, 'Konten Layanan membaca daftar topik');
select ok(cs_api.admin_options() ? 'skills', 'Konten Layanan membaca pilihan skill untuk form topik');
select ok(cs_api.admin_save_topic('promo_saham', 'Promo Saham', 'Stock Promo', 'general', 'P3', null, 900, true)
            @> '[{"code": "promo_saham"}]',
  'Konten Layanan menyimpan topik');
select throws_ok($$select cs_api.admin_agents()$$, 'PT403', 'role_forbidden',
  'Konten Layanan tidak membuka daftar akun CS');
select throws_ok($$select cs_api.ticket_lists()$$, 'PT403', 'role_forbidden',
  'Konten Layanan tidak menangani tiket');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_topics()$$, 'PT403', 'role_forbidden', 'CS biasa tidak mengelola topik');

reset role;
select is((select count(*) from cs.cs_audit_log where action = 'topic.save' and actor_id = :'laras')::integer, 1,
  'Perubahan topik oleh Konten Layanan tercatat di audit');

select * from finish();
rollback;
