begin;
select plan(21);

select tests.create_agent('Sinta Notif', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Notif', '{cs_agent}', '{"general": 1}') as rina \gset
update cs.agents set community_permissions = '{community.post,community.publish}' where user_id = :'rina';
select tests.create_user('rn_resmi') as resmi \gset
insert into cs.official_accounts (profile_id) values (:'resmi');
select tests.create_user('rn_fan_a') as fan_a \gset
select tests.create_user('rn_fan_b') as fan_b \gset
insert into public.stock_watchers (user_id, stock_code) values (:'fan_a', 'NTFA'), (:'fan_b', 'NTFB');

create function pg_temp.qend(p_back integer) returns date language sql as $$
  select (date_trunc('quarter', current_date) - make_interval(months => 3 * p_back) - interval '1 day')::date
$$;
create function pg_temp.payload(p_code text, p_sha text, p_back integer) returns jsonb language sql as $$
  select jsonb_build_object(
    'sha256', p_sha, 'kind', 'financial_report',
    'document', jsonb_build_object('version', 1, 'title', 'Laporan Keuangan ' || to_char(pg_temp.qend(p_back), 'YYYY-MM'),
                                   'headline', 'Laba naik di ' || p_code,
                                   'blocks', jsonb_build_array(jsonb_build_object('type', 'paragraph', 'text', 'Isi'))),
    'entity_code', p_code, 'entity_name', 'PT Contoh ' || p_code || ' Tbk',
    'period', case extract(month from pg_temp.qend(p_back)) when 3 then 'Q1' when 6 then 'Q2' when 9 then 'Q3' else 'FY' end,
    'period_start', date_trunc('year', pg_temp.qend(p_back))::date, 'period_end', pg_temp.qend(p_back),
    'audit', 'unaudited', 'currency', 'IDR', 'template', 'general',
    'facts', jsonb_build_object('current', jsonb_build_object('SalesAndRevenue', 10)),
    'metrics', jsonb_build_object('version', 1), 'summary', '$' || p_code || ' — Laporan Keuangan',
    'warnings', '[]'::jsonb)
$$;
create function pg_temp.report(p_key uuid, p_code text, p_sha text, p_back integer) returns jsonb language plpgsql as $$
declare
  v_job jsonb;
begin
  perform public.research_submit(p_key, p_sha, 90000, null);
  v_job := public.research_claim('w1', 120);
  return public.research_complete((v_job ->> 'id')::uuid, 'w1', pg_temp.payload(p_code, p_sha, p_back)) -> 'report';
end;
$$;
create function pg_temp.notify_state(p_report uuid) returns text language sql as $$
  select coalesce(r.notify_skipped, m.status)
  from private.research_reports r left join cs.community_campaigns m on m.id = r.notify_campaign_id
  where r.id = p_report
$$;
create function pg_temp.deliver() returns void language plpgsql as $$
begin
  update cs.community_campaigns set send_at = now() - interval '1 second' where status = 'scheduled';
  perform cs.community_tick();
end;
$$;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('Riset notif', '{research}', null, '{}', 600) ->> 'id' as key_id \gset
select is((cs_api.research_save_config(:'resmi', true) -> 'notify_watchers')::boolean, true,
  'Notifikasi ke pemantau saham menyala secara bawaan');
reset role;

select tests.authenticate_service();
select pg_temp.report(:'key_id', 'NTFA', repeat('a', 64), 0) ->> 'id' as rep_a \gset
reset role;
select is((select c.status from cs.community_posts c join private.research_reports r on r.community_post_id = c.id
           where r.id = :'rep_a'), 'published', 'Riset periode terbaru langsung terbit');
select is(pg_temp.notify_state(:'rep_a'), 'scheduled', 'Kampanye notifikasi dijadwalkan saat postingan terbit');
select ok((select m.audience = 'stock' and m.audience_stock = 'NTFA' and m.title like '$NTFA · Laporan Keuangan %'
                  and m.body = 'Laba naik di NTFA' and m.account_id = :'resmi'
                  and m.send_at between now() + interval '119 seconds' and now() + interval '121 seconds'
                  and m.link_post_id = r.community_post_id
           from private.research_reports r join cs.community_campaigns m on m.id = r.notify_campaign_id
           where r.id = :'rep_a'),
  'Kampanye untuk pemantau saham itu, tertaut ke postingan, ditunda 2 menit');
select is((select count(*)::integer from public.notifications where user_id in (:'fan_a', :'fan_b')), 0,
  'Belum ada notifikasi selama masa tunda');

select pg_temp.deliver();
select is(pg_temp.notify_state(:'rep_a'), 'sent', 'Kampanye terkirim setelah masa tunda');
select ok((select n.type = 'announcement' and n.actor_id = :'resmi' and n.payload ->> 'title' like '$NTFA · %'
                  and (n.payload ->> 'post_id')::uuid = c.post_id
           from public.notifications n, private.research_reports r
           join cs.community_posts c on c.id = r.community_post_id
           where n.user_id = :'fan_a' and r.id = :'rep_a'),
  'Pemantau saham menerima notifikasi yang membuka postingan riset');
select is((select count(*)::integer from public.notifications where user_id = :'fan_b'), 0,
  'Nasabah yang tidak memantau saham itu tidak menerima notifikasi');

select tests.authenticate_service();
select pg_temp.report(:'key_id', 'NTFA', repeat('b', 64), 1) ->> 'id' as rep_old \gset
select pg_temp.report(:'key_id', 'NTFC', repeat('c', 64), 4) ->> 'id' as rep_stale \gset
select pg_temp.report(:'key_id', 'NTFA', repeat('d', 64), 0) ->> 'id' as rep_rev \gset
reset role;
select r.community_post_id as rev_post from private.research_reports r where r.id = :'rep_rev' \gset
select tests.authenticate_agent(:'rina');
select cs_api.community_review_post(:'rev_post', true) is not null as rev_approved \gset
reset role;
select is(pg_temp.notify_state(:'rep_old'), 'older_period', 'Laporan periode lama tidak dikirim bila yang lebih baru ada');
select is(pg_temp.notify_state(:'rep_stale'), 'stale', 'Laporan yang periodenya sudah lewat setengah tahun tidak dikirim');
select is(pg_temp.notify_state(:'rep_rev'), 'revision', 'Revisi periode yang sudah dikabarkan tidak dikirim lagi setelah disetujui');

select tests.authenticate_service();
select pg_temp.report(:'key_id', 'NTFB', repeat('e', 64), 1) ->> 'id' as rep_b_prev \gset
select pg_temp.report(:'key_id', 'NTFB', repeat('f', 64), 0) ->> 'id' as rep_b \gset
reset role;
select is(pg_temp.notify_state(:'rep_b_prev'), 'replaced',
  'Kampanye periode lama yang belum terkirim dibatalkan saat periode baru terbit');
select is(pg_temp.notify_state(:'rep_b'), 'scheduled', 'Hanya periode terbaru yang dikabarkan');
select pg_temp.deliver();
select is((select array_agg(n.payload ->> 'body') from public.notifications n where n.user_id = :'fan_b'),
  array['Laba naik di NTFB'], 'Pemantau menerima satu notifikasi untuk unggahan beberapa periode sekaligus');

select tests.authenticate_agent(:'sinta');
select cs_api.research_save_config(:'resmi', false) as manual_cfg \gset
reset role;
select is((:'manual_cfg'::jsonb ->> 'notify_watchers')::boolean, true,
  'Menyimpan pengaturan tanpa saklar notifikasi tidak mengubahnya');
select tests.authenticate_service();
select pg_temp.report(:'key_id', 'NTFD', repeat('1', 64), 0) ->> 'id' as rep_manual \gset
reset role;
select is(pg_temp.notify_state(:'rep_manual'), null, 'Postingan yang menunggu persetujuan belum memicu notifikasi');
select r.community_post_id as manual_post from private.research_reports r where r.id = :'rep_manual' \gset
select tests.authenticate_agent(:'rina');
select cs_api.community_review_post(:'manual_post', true) is not null as approved \gset
select is(cs_api.research_report(:'rep_manual') #>> '{notification,campaign,status}', 'scheduled',
  'Postingan yang disetujui staf memicu notifikasi dan statusnya tampil di detail laporan');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.research_save_config(%L, true, false)$$, :'resmi'),
  'PT403', null, 'Hanya Super Admin yang mengubah saklar notifikasi');
reset role;
select tests.authenticate_agent(:'sinta');
select cs_api.research_save_config(:'resmi', true, false) is not null as disabled \gset
reset role;
select tests.authenticate_service();
select pg_temp.report(:'key_id', 'NTFE', repeat('2', 64), 0) ->> 'id' as rep_off \gset
reset role;
select is(pg_temp.notify_state(:'rep_off'), 'disabled', 'Saklar mati: riset terbit tanpa notifikasi');
select ok(exists (select 1 from cs.cs_audit_log where action = 'research.config'
                  and details #>> '{notify_watchers,to}' = 'false'),
  'Perubahan saklar notifikasi tercatat di jejak audit');

select ok(exists (select 1 from cs.cs_audit_log where action = 'research.notify' and details ->> 'report' = :'rep_a'),
  'Notifikasi riset tercatat di jejak audit');

select * from finish();
rollback;
