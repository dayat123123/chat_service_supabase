create or replace function private.retention_rules()
returns table (key text, unit text, category text, default_value integer, min_value integer, max_value integer,
               allow_off boolean, store text, sort_order integer)
language sql
immutable
set search_path = ''
as $$
  values ('retention.purge_enabled', 'switch', 'guard', 1, 0, 1, false, 'settings', 1),
         ('retention.max_rows_per_run', 'rows', 'guard', 20000, 1000, 200000, false, 'settings', 2),
         ('retention.posts_years', 'years', 'content', 5, 1, 30, true, 'settings', 10),
         ('retention.comments_years', 'years', 'content', 5, 1, 30, true, 'settings', 11),
         ('retention.direct_chat_years', 'years', 'chat', 5, 1, 30, true, 'settings', 20),
         ('retention.stock_chat_years', 'years', 'chat', 5, 1, 30, true, 'settings', 21),
         ('retention.chat_years', 'years', 'chat', 10, 5, 30, false, 'cs', 22),
         ('retention.archive_days', 'days', 'archive', 1825, 365, 3650, false, 'settings', 30),
         ('retention.evidence_days', 'days', 'archive', 730, 365, 3650, false, 'settings', 31),
         ('retention.deleted_messages_days', 'days', 'archive', 30, 7, 365, false, 'settings', 32),
         ('retention.notifications_days', 'days', 'log', 90, 30, 730, false, 'settings', 40),
         ('retention.audit_log_days', 'days', 'log', 1825, 365, 3650, false, 'settings', 41),
         ('retention.access_log_days', 'days', 'log', 730, 365, 3650, false, 'settings', 42),
         ('retention.rate_limit_events_days', 'days', 'log', 2, 1, 30, false, 'settings', 43),
         ('retention.cs_audit_days', 'days', 'log', 1825, 1095, 3650, false, 'settings', 44),
         ('retention.notification_events_days', 'days', 'log', 400, 90, 3650, false, 'settings', 45),
         ('retention.moderation_events_days', 'days', 'log', 730, 365, 3650, false, 'settings', 46),
         ('retention.cron_history_days', 'days', 'log', 7, 1, 90, false, 'settings', 47);
$$;

select set_config('olt.retention_source', 'migration', true);
insert into private.settings (key, value, description) values
  ('retention.cs_audit_days', '1825',
   'Jejak audit Hub dan riwayat sesi CS (partisi bulanan) dibuang setelah sekian hari'),
  ('retention.notification_events_days', '400',
   'Catatan buka/ketuk notifikasi diringkas ke total per kampanye lalu dihapus setelah sekian hari'),
  ('retention.moderation_events_days', '730',
   'Riwayat perubahan status moderasi konten dihapus setelah sekian hari'),
  ('retention.cron_history_days', '7',
   'Riwayat eksekusi job terjadwal (pg_cron) dihapus setelah sekian hari')
on conflict (key) do nothing;
select set_config('olt.retention_source', '', true);

insert into private.settings (key, value, description) values
  ('storage.orphan_min_age_days', '7',
   'Umur minimal file unggahan sebelum diperiksa apakah dipakai; yang tidak dipakai dihapus janitor'),
  ('storage.sweep_objects_per_run', '2000',
   'Jumlah file per bucket yang diperiksa penyapu file yatim dalam satu kali jalan')
on conflict (key) do nothing;

create index content_archive_author_idx on private.content_archive (author_id, target_type) where author_id is not null;

create or replace function private.attachments_mention(p_attachments jsonb, p_name text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1
    from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments else '[]' end) e(item)
    where jsonb_typeof(e.item) = 'object'
      and (e.item ->> 'path' = p_name or e.item ->> 'thumbnail' = p_name or e.item #>> '{file,path}' = p_name));
$$;

create or replace function private.attachment_files(p_attachments jsonb)
returns table (bucket text, path text)
language sql
immutable
set search_path = ''
as $$
  select distinct b.bucket, f.path
  from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments else '[]' end) e(item)
  cross join lateral (
    select e.item #>> '{file,bucket}' as bucket, e.item #>> '{file,path}' as path
    where jsonb_typeof(e.item -> 'file') = 'object'
    union all
    select coalesce(e.item ->> 'bucket', 'attachments'), e.item ->> 'path'
    union all
    select coalesce(e.item ->> 'bucket', 'attachments'), e.item ->> 'thumbnail'
    union all
    select 'attachments', e.item ->> 'thumbnail'
  ) f
  cross join lateral (select f.bucket) b
  where jsonb_typeof(e.item) = 'object'
    and b.bucket in ('attachments', 'cs-documents', 'cs-videos', 'post-files')
    and f.path ~ '^[^/]+(/[^/]+)*$'
    and char_length(f.path) < 1000;
$$;

create or replace function private.storage_queue_file(p_bucket text, p_path text, p_reason text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_path is null or p_path !~ '^[^/]+(/[^/]+)*$' or char_length(p_path) >= 1000 then
    return false;
  end if;
  if exists (select 1 from private.storage_cleanup_queue q
             where q.bucket_id = p_bucket and q.prefix = p_path || '/' and q.done_at is null) then
    return false;
  end if;
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values (p_bucket, p_path || '/', p_reason);
  return true;
end;
$$;

create or replace function private.content_archive_release_files()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  f record;
begin
  if old.attachments is null or old.target_type not in ('post', 'message') then
    return old;
  end if;
  if old.target_type = 'post'
     and exists (select 1 from public.posts p where p.id = old.target_id and p.deleted_at is null) then
    return old;
  end if;
  if old.target_type = 'message'
     and exists (select 1 from public.messages m where m.id = old.target_id and m.deleted_at is null) then
    return old;
  end if;
  if exists (select 1 from private.content_archive a
             where a.target_type = old.target_type and a.target_id = old.target_id and a.id <> old.id) then
    return old;
  end if;
  for f in select * from private.attachment_files(old.attachments) loop
    perform private.storage_queue_file(f.bucket, f.path, 'archive_expired');
  end loop;
  return old;
end;
$$;

create trigger content_archive_95_release_files
  before delete on private.content_archive
  for each row execute function private.content_archive_release_files();

create or replace function private.avatar_object(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select substring(p_url from '/storage/v1/object/public/avatars/([^?#]+)$');
$$;

create or replace function private.profile_avatar_replaced()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_path text := private.avatar_object(old.avatar_url);
begin
  if v_path ~ ('^' || old.id::text || '/avatar-[0-9]+\.(jpg|jpeg|png|webp)$')
     and v_path is distinct from private.avatar_object(new.avatar_url) then
    perform private.storage_queue_file('avatars', v_path, 'avatar_replaced');
  end if;
  return null;
end;
$$;

create trigger profiles_95_avatar_replaced
  after update of avatar_url on public.profiles
  for each row when (old.avatar_url is distinct from new.avatar_url and old.avatar_url is not null)
  execute function private.profile_avatar_replaced();

create or replace function private.room_avatar_replaced()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_path text := private.avatar_object(old.avatar_url);
begin
  if v_path ~ ('^[0-9a-f-]{36}/group-' || old.id::text || '-[0-9]+\.(jpg|jpeg|png|webp)$')
     and v_path is distinct from private.avatar_object(new.avatar_url) then
    perform private.storage_queue_file('avatars', v_path, 'avatar_replaced');
  end if;
  return null;
end;
$$;

create trigger chat_rooms_95_avatar_replaced
  after update of avatar_url on public.chat_rooms
  for each row when (old.avatar_url is distinct from new.avatar_url and old.avatar_url is not null)
  execute function private.room_avatar_replaced();

create table private.storage_sweep_cursors (
  bucket_id    text primary key,
  last_created timestamptz not null default '-infinity',
  last_name    text not null default '',
  updated_at   timestamptz not null default now()
);
alter table private.storage_sweep_cursors enable row level security;

create or replace function private.storage_object_in_use(p_bucket text, p_name text, p_created timestamptz)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_uuid  text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_owner uuid;
  v_room  uuid;
begin
  if p_bucket = 'avatars' then
    if cardinality(v_parts) <> 2 or v_parts[1] !~ v_uuid then
      return true;
    end if;
    if v_parts[2] ~ '^avatar-[0-9]+\.(jpg|jpeg|png|webp)$' then
      return exists (select 1 from public.profiles p
                     where p.id = v_parts[1]::uuid and private.avatar_object(p.avatar_url) = p_name);
    end if;
    if v_parts[2] ~ '^group-[0-9a-f-]{36}-[0-9]+\.(jpg|jpeg|png|webp)$'
       and substring(v_parts[2] from 7 for 36) ~ v_uuid then
      return exists (select 1 from public.chat_rooms r
                     where r.id = substring(v_parts[2] from 7 for 36)::uuid
                       and private.avatar_object(r.avatar_url) = p_name);
    end if;
    return true;
  end if;

  if v_parts[1] = 'posts' and cardinality(v_parts) >= 3 and v_parts[2] ~ v_uuid then
    v_owner := v_parts[2]::uuid;
    return exists (select 1 from public.posts p
                   where p.author_id = v_owner and private.attachments_mention(p.attachments, p_name))
        or exists (select 1 from public.post_drafts d
                   where d.user_id = v_owner and private.attachments_mention(d.attachments, p_name))
        or exists (select 1 from cs.community_posts c
                   where c.account_id = v_owner and private.attachments_mention(c.attachments, p_name))
        or exists (select 1 from private.content_archive a
                   where a.author_id = v_owner and a.target_type = 'post'
                     and private.attachments_mention(a.attachments, p_name));
  end if;

  if v_parts[1] = 'rooms' and cardinality(v_parts) >= 4 and v_parts[2] ~ v_uuid and v_parts[3] ~ v_uuid then
    v_room := v_parts[2]::uuid;
    v_owner := v_parts[3]::uuid;
    return exists (select 1 from public.messages m
                   where m.sender_id = v_owner and m.created_at >= p_created - interval '1 hour'
                     and m.room_id = v_room and private.attachments_mention(m.attachments, p_name))
        or exists (select 1 from private.content_archive a
                   where a.author_id = v_owner and a.target_type = 'message'
                     and private.attachments_mention(a.attachments, p_name));
  end if;

  return true;
end;
$$;

create or replace function private.storage_orphan_sweep(p_bucket text, p_limit integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit   integer := greatest(coalesce(p_limit,
                                         private.setting_num('storage.sweep_objects_per_run', 2000)::integer), 1);
  v_before  timestamptz := now() - make_interval(days => private.setting_num('storage.orphan_min_age_days', 7)::integer);
  c         private.storage_sweep_cursors;
  o         record;
  v_checked integer := 0;
  v_queued  integer := 0;
begin
  if p_bucket not in ('attachments', 'cs-documents', 'cs-videos', 'avatars') then
    perform private.api_error(400, 'invalid_bucket', 'Bucket tidak disapu otomatis');
  end if;
  insert into private.storage_sweep_cursors (bucket_id) values (p_bucket) on conflict (bucket_id) do nothing;
  select * into c from private.storage_sweep_cursors where bucket_id = p_bucket for update;
  for o in
    select s.name, s.created_at
    from storage.objects s
    where s.bucket_id = p_bucket and s.created_at < v_before
      and (s.created_at, s.name collate "C") > (c.last_created, c.last_name collate "C")
    order by s.created_at, s.name collate "C"
    limit v_limit
  loop
    v_checked := v_checked + 1;
    if not private.storage_object_in_use(p_bucket, o.name, o.created_at)
       and private.storage_queue_file(p_bucket, o.name, 'orphan_upload') then
      v_queued := v_queued + 1;
    end if;
    c.last_created := o.created_at;
    c.last_name := o.name;
  end loop;
  update private.storage_sweep_cursors
     set last_created = c.last_created, last_name = c.last_name, updated_at = now()
   where bucket_id = p_bucket;
  return jsonb_build_object('checked', v_checked, 'queued', v_queued);
end;
$$;

create or replace function private.faq_files_sweep(p_limit integer default 500)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_queued integer := 0;
  o        record;
begin
  for o in
    with refs as materialized (
      select coalesce(a.answer_id, '') || ' ' || coalesce(a.answer_en, '') || ' ' || coalesce(a.attachments::text, '') as t
      from cs.faq_articles a
      union all
      select v.content::text from cs.faq_article_versions v
    )
    select s.bucket_id, s.name
    from storage.objects s
    where s.bucket_id in ('faq-files', 'faq-images') and s.created_at < now() - interval '1 day'
      and not exists (select 1 from refs r where strpos(r.t, s.name) > 0)
    order by s.created_at
    limit greatest(coalesce(p_limit, 500), 1)
  loop
    if private.storage_queue_file(o.bucket_id, o.name, 'faq_unused') then
      v_queued := v_queued + 1;
    end if;
  end loop;
  return v_queued;
end;
$$;

create or replace function private.post_files_maintenance()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name  text;
  v_count integer := 0;
begin
  for v_name in
    select o.name
    from storage.objects o
    where o.bucket_id = 'post-files' and o.created_at < now() - interval '1 day'
      and not exists (
        select 1 from cs.community_posts c
        where c.attachments @> jsonb_build_array(jsonb_build_object('type', 'file',
                                                   'file', jsonb_build_object('path', o.name)))
          and (c.status in ('draft', 'pending', 'scheduled')
               or (c.status in ('rejected', 'cancelled', 'failed') and c.updated_at > now() - interval '90 days')
               or (c.status = 'published'
                   and exists (select 1 from public.posts p where p.id = c.post_id and p.deleted_at is null))))
      and not exists (
        select 1 from private.content_archive a
        where a.target_type = 'post'
          and a.author_id in (select f.profile_id from cs.official_accounts f)
          and a.attachments @> jsonb_build_array(jsonb_build_object('type', 'file',
                                                   'file', jsonb_build_object('path', o.name))))
      and not exists (select 1 from private.research_documents d
                      where d.object_name = o.name and d.status <> 'rejected')
      and not exists (select 1 from private.storage_cleanup_queue q
                      where q.bucket_id = 'post-files' and q.done_at is null
                        and q.prefix = regexp_replace(o.name, '[^/]+$', ''))
    order by o.created_at
    limit 500
  loop
    if private.storage_queue_file('post-files', regexp_replace(v_name, '/[^/]+$', ''), 'post_file_unused') then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create table private.notification_event_totals (
  source_type text not null,
  source_id   uuid not null,
  opened      integer not null default 0,
  tapped      integer not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (source_type, source_id)
);
alter table private.notification_event_totals enable row level security;

create or replace function private.notification_event_stats(p_type text, p_id uuid, p_recipients integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'opened', s.opened,
    'tapped', s.tapped,
    'open_rate', case when coalesce(p_recipients, 0) > 0 then round(100.0 * s.opened / p_recipients, 1) end,
    'tap_rate', case when coalesce(p_recipients, 0) > 0 then round(100.0 * s.tapped / p_recipients, 1) end)
  from (select l.opened + coalesce(t.opened, 0) as opened, l.tapped + coalesce(t.tapped, 0) as tapped
        from (select count(*) filter (where e.event = 'opened')::integer as opened,
                     count(*) filter (where e.event = 'tapped')::integer as tapped
              from private.notification_events e
              where e.source_type = p_type and e.source_id = p_id) l
        left join private.notification_event_totals t on t.source_type = p_type and t.source_id = p_id) s;
$$;

create or replace function private.notification_events_purge(p_before timestamptz, p_cap integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done integer := 0;
  v_rows integer;
begin
  loop
    exit when v_done >= p_cap;
    with gone as (
      delete from private.notification_events e
       where e.id in (select x.id from private.notification_events x
                      where x.created_at < p_before order by x.id limit least(20000, p_cap - v_done))
      returning e.source_type, e.source_id, e.event
    ), sums as (
      select g.source_type, g.source_id,
             count(*) filter (where g.event = 'opened')::integer as opened,
             count(*) filter (where g.event = 'tapped')::integer as tapped,
             count(*)::integer as total
      from gone g group by g.source_type, g.source_id
    ), saved as (
      insert into private.notification_event_totals as t (source_type, source_id, opened, tapped)
      select s.source_type, s.source_id, s.opened, s.tapped from sums s where s.source_type <> 'notification'
      on conflict (source_type, source_id) do update
        set opened = t.opened + excluded.opened, tapped = t.tapped + excluded.tapped, updated_at = now()
    )
    select coalesce(sum(s.total), 0)::integer into v_rows from sums s;
    v_done := v_done + v_rows;
    exit when v_rows = 0;
  end loop;
  return v_done;
end;
$$;

create or replace function private.cs_partitions_drop(p_before timestamptz)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  p         record;
  v_dropped integer := 0;
begin
  for p in
    select c.relname
    from pg_catalog.pg_inherits i
    join pg_catalog.pg_class c on c.oid = i.inhrelid
    join pg_catalog.pg_class t on t.oid = i.inhparent
    join pg_catalog.pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'cs' and t.relname in ('session_events', 'cs_audit_log')
      and case when c.relname ~ ('^' || t.relname || '_p[0-9]{6}$')
               then (to_date(right(c.relname, 6), 'YYYYMM') + interval '1 month') at time zone 'UTC' <= p_before
               else false end
    order by c.relname
  loop
    execute format('drop table cs.%I', p.relname);
    v_dropped := v_dropped + 1;
  end loop;
  return v_dropped;
end;
$$;

create or replace function private.cron_history_purge(p_before timestamptz, p_cap integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done integer := 0;
  v_rows integer;
begin
  loop
    exit when v_done >= p_cap;
    delete from cron.job_run_details d
     where d.runid in (select x.runid from cron.job_run_details x
                       where x.end_time < p_before or (x.end_time is null and x.start_time < p_before)
                       order by x.runid limit least(50000, p_cap - v_done));
    get diagnostics v_rows = row_count;
    v_done := v_done + v_rows;
    exit when v_rows = 0;
  end loop;
  return v_done;
end;
$$;

create table private.housekeeping_runs (
  id          bigint generated always as identity primary key,
  started_at  timestamptz not null,
  finished_at timestamptz not null default now(),
  result      jsonb not null default '{}',
  errors      jsonb not null default '{}'
);
create index housekeeping_runs_finished_idx on private.housekeeping_runs (finished_at);
alter table private.housekeeping_runs enable row level security;

create or replace function private.housekeeping_run(p_faq boolean default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_started timestamptz := clock_timestamp();
  v_result  jsonb := '{}';
  v_errors  jsonb := '{}';
  v_step    text;
  v_bucket  text;
begin
  if not pg_try_advisory_xact_lock(hashtext('private.housekeeping_run')) then
    return jsonb_build_object('skipped', 'already_running');
  end if;

  foreach v_step in array array['cron_history', 'cs_audit', 'notification_events', 'moderation_events',
                                'post_files', 'attachments', 'cs-documents', 'cs-videos', 'avatars', 'faq'] loop
    begin
      case v_step
        when 'cron_history' then
          v_result := v_result || jsonb_build_object(v_step, private.cron_history_purge(
            now() - make_interval(days => private.retention_value('retention.cron_history_days')), 500000));
        when 'cs_audit' then
          set local lock_timeout = '5s';
          v_result := v_result || jsonb_build_object(v_step, private.cs_partitions_drop(
            now() - make_interval(days => private.retention_value('retention.cs_audit_days'))));
          set local lock_timeout = 0;
        when 'notification_events' then
          v_result := v_result || jsonb_build_object(v_step, private.notification_events_purge(
            now() - make_interval(days => private.retention_value('retention.notification_events_days')), 200000));
        when 'moderation_events' then
          with gone as (
            delete from private.moderation_events e
             where e.id in (select x.id from private.moderation_events x
                            where x.created_at < now() - make_interval(
                                    days => private.retention_value('retention.moderation_events_days'))
                            order by x.id limit 200000)
            returning 1)
          select jsonb_build_object(v_step, count(*)) || v_result into v_result from gone;
        when 'post_files' then
          v_result := v_result || jsonb_build_object(v_step, private.post_files_maintenance());
        when 'faq' then
          if coalesce(p_faq, extract(hour from now() at time zone 'UTC') = 19) then
            v_result := v_result || jsonb_build_object(v_step, private.faq_files_sweep(500));
          end if;
        else
          v_bucket := v_step;
          v_result := v_result || jsonb_build_object(v_step, private.storage_orphan_sweep(v_bucket));
      end case;
    exception when others then
      v_errors := v_errors || jsonb_build_object(v_step, left(sqlerrm, 300));
      raise warning 'housekeeping: % failed: %', v_step, sqlerrm;
    end;
  end loop;

  delete from private.housekeeping_runs r where r.finished_at < now() - interval '90 days';
  insert into private.housekeeping_runs (started_at, result, errors) values (v_started, v_result, v_errors);
  return jsonb_build_object('result', v_result, 'errors', v_errors);
end;
$$;

select cron.unschedule('post-files-maintenance');
select cron.schedule('housekeeping', '51 * * * *', 'select private.housekeeping_run()');

revoke execute on function private.attachments_mention(jsonb, text) from public;
revoke execute on function private.attachment_files(jsonb) from public;
revoke execute on function private.storage_queue_file(text, text, text) from public;
revoke execute on function private.content_archive_release_files() from public;
revoke execute on function private.avatar_object(text) from public;
revoke execute on function private.profile_avatar_replaced() from public;
revoke execute on function private.room_avatar_replaced() from public;
revoke execute on function private.storage_object_in_use(text, text, timestamptz) from public;
revoke execute on function private.storage_orphan_sweep(text, integer) from public;
revoke execute on function private.faq_files_sweep(integer) from public;
revoke execute on function private.notification_events_purge(timestamptz, integer) from public;
revoke execute on function private.cs_partitions_drop(timestamptz) from public;
revoke execute on function private.cron_history_purge(timestamptz, integer) from public;
revoke execute on function private.housekeeping_run(boolean) from public;
