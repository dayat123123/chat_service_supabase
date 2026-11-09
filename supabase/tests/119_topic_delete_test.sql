begin;
select plan(8);

select tests.create_agent('Laras Hapus', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Sinta Hapus', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Hapus', '{cs_agent}', '{"general": 1}') as rina \gset
select (select id from cs.faq_categories where code = 'account') as account \gset

insert into cs.support_topics (code, name_id, name_en, skill, default_priority, sort_order)
values ('uji_hapus', 'Uji hapus', 'Delete test', 'general', 'P3', 900),
       ('uji_tanda', 'Uji tanda', 'Flag test', 'general', 'P3', 910);
update cs.support_topics set flags = '{complaint}' where code = 'uji_tanda';

select tests.authenticate_agent(:'laras');
select cs_api.admin_faq_save_article(null, :'account', 'Artikel untuk topik uji', 'Article for the test topic',
  'Jawaban', 'Answer', '{}', 'uji_hapus', 0) ->> 'id' as article \gset
select ok((select (x ->> 'ticket_count')::integer from jsonb_array_elements(cs_api.admin_topics()) x where x ->> 'code' = 'account') > 0,
  'Daftar topik admin memuat jumlah tiket per topik');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_delete_topic('uji_hapus')$$, 'PT403', null, 'CS biasa tidak bisa menghapus topik');
reset role;

select tests.authenticate_agent(:'laras');
select throws_ok($$select cs_api.admin_delete_topic('account')$$, 'PT409', 'topic_in_use',
  'Topik yang sudah dipakai tiket tidak bisa dihapus');
select throws_ok($$select cs_api.admin_delete_topic('uji_tanda')$$, 'PT403', 'flags_forbidden',
  'Topik bertanda hanya bisa dihapus Super Admin');
select ok(not (cs_api.admin_delete_topic('uji_hapus') @> '[{"code": "uji_hapus"}]'), 'Konten Layanan menghapus topik yang belum dipakai');
reset role;

select is((select topic_code from cs.faq_articles where id = :'article'), null, 'Artikel FAQ terkait dilepas dari topik yang dihapus');
select ok(exists (select 1 from cs.cs_audit_log where actor_id = :'laras' and action = 'topic.delete' and details ->> 'code' = 'uji_hapus'),
  'Penghapusan topik tercatat di jejak audit');

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_delete_topic('uji_tanda')$$, 'Super Admin menghapus topik bertanda yang belum dipakai');
reset role;

select * from finish();
rollback;
