alter table private.research_config add column notify_watchers boolean not null default true;

alter table private.research_reports
  add column notify_campaign_id uuid references cs.community_campaigns (id),
  add column notify_skipped text
    check (notify_skipped in ('disabled', 'older_period', 'stale', 'revision', 'replaced', 'failed'));
create index research_reports_notify_campaign_idx on private.research_reports (notify_campaign_id)
  where notify_campaign_id is not null;
create index research_reports_community_post_idx on private.research_reports (community_post_id)
  where community_post_id is not null;

create or replace function private.research_notify_skip(r private.research_reports)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not coalesce((select c.notify_watchers from private.research_config c where c.singleton), false)
      then 'disabled'
    when r.superseded_at is not null
         or exists (select 1 from private.research_reports n
                    where n.kind = r.kind and n.entity_code = r.entity_code and n.superseded_at is null
                      and n.period_end > r.period_end)
      then 'older_period'
    when r.period_end < current_date - private.setting_num('research.notify_max_age_days', 183)::integer
      then 'stale'
    when exists (select 1 from private.research_reports o
                 join cs.community_campaigns m on m.id = o.notify_campaign_id
                 where o.id <> r.id and o.kind = r.kind and o.entity_code = r.entity_code
                   and o.period_start = r.period_start and o.period_end = r.period_end
                   and m.status in ('sending', 'sent'))
      then 'revision'
  end;
$$;

create or replace function private.research_notify(p_post uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r      private.research_reports;
  c      cs.community_posts;
  v_skip text;
  v_camp uuid;
  o      record;
begin
  select * into r from private.research_reports where community_post_id = p_post for update;
  if not found or r.notify_campaign_id is not null or r.notify_skipped is not null then
    return null;
  end if;
  select * into c from cs.community_posts where id = p_post;
  v_skip := private.research_notify_skip(r);
  if v_skip is not null then
    update private.research_reports set notify_skipped = v_skip where id = r.id;
    return null;
  end if;

  for o in
    select x.id, m.id as campaign_id
    from private.research_reports x
    join cs.community_campaigns m on m.id = x.notify_campaign_id
    where x.id <> r.id and x.kind = r.kind and x.entity_code = r.entity_code and x.period_end <= r.period_end
      and m.status = 'scheduled'
    for update of m
  loop
    update cs.community_campaigns set status = 'cancelled', updated_at = now(), version = version + 1
     where id = o.campaign_id;
    update private.research_reports set notify_skipped = 'replaced' where id = o.id;
  end loop;

  insert into cs.community_campaigns (account_id, title, body, link_post_id, audience, audience_stock, status, send_at,
                                      created_by, submitted_at, reviewed_by, reviewed_at)
  values (c.account_id,
          left('$' || r.entity_code || ' · ' || coalesce(nullif(btrim(r.document ->> 'title'), ''), 'Riset baru'), 120),
          left(coalesce(nullif(btrim(r.document ->> 'headline'), ''), r.entity_name), 500),
          c.id, 'stock', r.entity_code, 'scheduled',
          now() + make_interval(secs => private.setting_num('research.notify_delay_seconds', 120)),
          c.created_by, c.submitted_at, c.reviewed_by, c.reviewed_at)
  returning id into v_camp;
  update private.research_reports set notify_campaign_id = v_camp where id = r.id;
  perform cs.audit('research.notify', null, null,
                   jsonb_build_object('report', r.id, 'campaign', v_camp, 'stock', r.entity_code));
  return v_camp;
end;
$$;

create or replace function private.research_post_published()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform private.research_notify(new.id);
  exception when others then
    raise warning 'research notify failed for community post %: %', new.id, sqlerrm;
    update private.research_reports set notify_skipped = 'failed'
     where community_post_id = new.id and notify_campaign_id is null and notify_skipped is null;
  end;
  return null;
end;
$$;

create trigger community_posts_research_notify
  after update of status on cs.community_posts
  for each row when (new.status = 'published' and old.status is distinct from 'published')
  execute function private.research_post_published();

create or replace function private.research_notification_view(r private.research_reports)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'skipped', r.notify_skipped,
    'campaign', (select jsonb_build_object('id', m.id, 'status', m.status, 'send_at', m.send_at,
                                           'finished_at', m.finished_at, 'recipients', m.recipients,
                                           'stock', m.audience_stock)
                 from cs.community_campaigns m where m.id = r.notify_campaign_id));
$$;

create or replace function cs.research_config_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'official_account', case when c.official_account_id is not null
                             then cs.community_account_ref(c.official_account_id) end,
    'official_active', c.official_account_id is not null and cs.official_active(c.official_account_id),
    'auto_publish', c.auto_publish, 'notify_watchers', c.notify_watchers,
    'notify_delay_seconds', private.setting_num('research.notify_delay_seconds', 120)::integer,
    'notify_max_age_days', private.setting_num('research.notify_max_age_days', 183)::integer,
    'updated_by', cs.staff_ref(c.updated_by), 'updated_at', c.updated_at,
    'max_file_bytes', 8388608, 'max_document_bytes', 20971520, 'max_documents', 3)
  from private.research_config c
  where c.singleton;
$$;

drop function cs_api.research_save_config(uuid, boolean);

create or replace function cs_api.research_save_config(p_official_account uuid, p_auto_publish boolean,
                                                       p_notify_watchers boolean default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  c     private.research_config;
begin
  if p_official_account is not null and not cs.official_active(p_official_account) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  select * into c from private.research_config where singleton for update;
  update private.research_config
     set official_account_id = p_official_account, auto_publish = coalesce(p_auto_publish, false),
         notify_watchers = coalesce(p_notify_watchers, c.notify_watchers),
         updated_by = v_me, updated_at = now()
   where singleton;
  perform cs.audit('research.config', null, null, jsonb_build_object(
    'official_account', jsonb_build_object('from', c.official_account_id, 'to', p_official_account),
    'auto_publish', jsonb_build_object('from', c.auto_publish, 'to', coalesce(p_auto_publish, false)),
    'notify_watchers', jsonb_build_object('from', c.notify_watchers,
                                          'to', coalesce(p_notify_watchers, c.notify_watchers))));
  return cs.research_config_view();
end;
$$;

create or replace function cs_api.research_report(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
  r    private.research_reports;
begin
  select * into r from private.research_reports where id = p_id;
  if not found then
    perform private.api_error(404, 'report_not_found', 'Laporan tidak ditemukan');
  end if;
  return private.research_report_ref(r.id) || jsonb_build_object(
    'sector', r.sector, 'subsector', r.subsector, 'metrics', r.metrics, 'document', r.document,
    'summary', r.summary,
    'warnings', r.warnings, 'created_at', r.created_at, 'superseded_at', r.superseded_at,
    'supersedes', private.research_report_ref(r.supersedes),
    'superseded_by', (select private.research_report_ref(n.id) from private.research_reports n where n.supersedes = r.id),
    'post', case when r.community_post_id is not null then cs.community_post_view(r.community_post_id) end,
    'notification', private.research_notification_view(r),
    'can_create_post', r.superseded_at is null
      and (r.community_post_id is null
           or (select c.status in ('rejected', 'cancelled', 'failed') from cs.community_posts c
               where c.id = r.community_post_id)),
    'files', coalesce((select jsonb_agg(cs.research_file_view(f.id) order by f.created_at)
                       from private.research_files f where f.report_id = r.id), '[]'),
    'documents', coalesce((select jsonb_agg(private.research_document_view(d.id) order by d.created_at, d.id)
                           from private.research_documents d join private.research_files f on f.id = d.file_id
                           where f.report_id = r.id), '[]'),
    'history', coalesce((select jsonb_agg(private.research_report_ref(h.id) order by h.period_end desc)
                         from (select x.id, x.period_end from private.research_reports x
                               where x.entity_code = r.entity_code and x.superseded_at is null and x.id <> r.id
                               order by x.period_end desc limit 12) h), '[]'));
end;
$$;

revoke execute on function private.research_notify_skip(private.research_reports) from public;
revoke execute on function private.research_notify(uuid) from public;
revoke execute on function private.research_post_published() from public;
revoke execute on function private.research_notification_view(private.research_reports) from public;
revoke execute on function cs_api.research_save_config(uuid, boolean, boolean) from public;
grant execute on function cs_api.research_save_config(uuid, boolean, boolean) to authenticated;
