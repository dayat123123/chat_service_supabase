begin;
select plan(5);

select tests.create_agent('Laras Urut', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina Urut', '{cs_agent}', '{"general": 1}') as rina \gset
select array_agg(code order by sort_order desc, code desc) as reversed from cs.support_topics \gset

select tests.authenticate_agent(:'rina');
select throws_ok(format('select cs_api.admin_reorder_topics(%L)', :'reversed'), 'PT403', null,
  'CS biasa tidak bisa mengubah urutan topik');
reset role;

select tests.authenticate_agent(:'laras');
select throws_ok($$select cs_api.admin_reorder_topics('{account}')$$, 'PT400', 'invalid_topic_order',
  'Urutan yang tidak memuat semua topik ditolak');
select throws_ok(format('select cs_api.admin_reorder_topics(%L)', (:'reversed'::text[]) || 'account'::text),
  'PT400', 'invalid_topic_order', 'Topik ganda ditolak');
select is((select array_agg(x ->> 'code') from jsonb_array_elements(cs_api.admin_reorder_topics(:'reversed')) x),
  :'reversed'::text[], 'Konten Layanan mengurutkan ulang topik');
reset role;

select ok(exists (select 1 from cs.cs_audit_log where actor_id = :'laras' and action = 'topic.reorder'),
  'Perubahan urutan topik tercatat di jejak audit');

select * from finish();
rollback;
