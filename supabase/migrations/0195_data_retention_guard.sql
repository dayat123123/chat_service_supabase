create index posts_created_brin on public.posts using brin (created_at);
create index comments_created_brin on public.comments using brin (created_at);
create index messages_created_brin on public.messages using brin (created_at);

insert into private.settings (key, value, description) values
  ('retention.purge_enabled', '1',
   'Penjaga retensi menghapus konten aktif yang melewati batas umur (1 = aktif, 0 = berhenti)'),
  ('retention.max_rows_per_run', '20000',
   'Batas baris yang dihapus per jenis data dalam satu kali jalan penjaga retensi'),
  ('retention.posts_years', '5',
   'Post beserta komentar, reaksi, dan lampirannya dihapus sekian tahun setelah dibuat (0 = tidak pernah)'),
  ('retention.comments_years', '5',
   'Komentar dihapus sekian tahun setelah dibuat walau post-nya masih ada (0 = tidak pernah)'),
  ('retention.direct_chat_years', '5',
   'Pesan DM dan grup dihapus sekian tahun setelah dikirim (0 = tidak pernah)'),
  ('retention.stock_chat_years', '5',
   'Pesan room saham dihapus sekian tahun setelah dikirim (0 = tidak pernah)')
on conflict (key) do nothing;

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
         ('retention.rate_limit_events_days', 'days', 'log', 2, 1, 30, false, 'settings', 43);
$$;

create or replace function private.retention_value_ok(p_key text, p_value jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1 from private.retention_rules() r
    where r.key = p_key
      and jsonb_typeof(p_value) = 'number'
      and (p_value #>> '{}') ~ '^[0-9]{1,9}$'
      and (((p_value #>> '{}')::integer = 0 and r.allow_off)
           or (p_value #>> '{}')::integer between r.min_value and r.max_value));
$$;

create or replace function private.retention_range_text(p_key text)
returns text
language sql
immutable
set search_path = ''
as $$
  select format('%s–%s %s%s', r.min_value, r.max_value,
                case r.unit when 'years' then 'tahun' when 'days' then 'hari' when 'rows' then 'baris' else '' end,
                case when r.allow_off then ', atau 0 untuk tidak pernah dihapus' else '' end)
  from private.retention_rules() r
  where r.key = p_key;
$$;

create or replace function private.retention_value(p_key text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (v.value #>> '{}')::numeric::integer
     from (select s.value from private.settings s where s.key = r.key and r.store = 'settings'
           union all
           select c.value from cs.cs_settings c where c.key = r.key and r.store = 'cs') v
     where (v.value #>> '{}') ~ '^[0-9]+(\.[0-9]+)?$'
     limit 1),
    r.default_value)
  from private.retention_rules() r
  where r.key = p_key;
$$;

create or replace function private.retention_keep_score(p_key text, p_value integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
           when r.unit in ('switch', 'rows') then -p_value
           when p_value = 0 and r.allow_off then 1e12
           else p_value
         end
  from private.retention_rules() r
  where r.key = p_key;
$$;

create table private.retention_changes (
  id            bigint generated always as identity primary key,
  key           text not null,
  old_value     integer not null,
  new_value     integer not null,
  direction     text not null check (direction in ('keep_longer', 'delete_sooner')),
  reason        text not null check (char_length(btrim(reason)) between 10 and 500),
  status        text not null default 'pending'
                check (status in ('pending', 'approved', 'applied', 'rejected', 'withdrawn', 'expired', 'superseded')),
  requested_by  uuid not null,
  requested_at  timestamptz not null default now(),
  decided_by    uuid,
  decided_at    timestamptz,
  decision_note text check (char_length(decision_note) <= 500),
  effective_at  timestamptz,
  applied_at    timestamptz,
  cancelled_by  uuid,
  cancelled_at  timestamptz,
  cancel_note   text check (char_length(cancel_note) <= 500),
  constraint retention_changes_four_eyes check (decided_by is null or decided_by <> requested_by),
  constraint retention_changes_decided check (status not in ('approved', 'applied', 'rejected') or decided_at is not null),
  constraint retention_changes_effective check (status not in ('approved', 'applied') or effective_at is not null),
  constraint retention_changes_applied check ((status = 'applied') = (applied_at is not null)),
  constraint retention_changes_cancelled check (status not in ('withdrawn', 'expired', 'superseded') or cancelled_at is not null)
);
create unique index retention_changes_one_open on private.retention_changes (key) where status in ('pending', 'approved');
create index retention_changes_recent_idx on private.retention_changes (id desc);
alter table private.retention_changes enable row level security;

create table private.retention_history (
  id         bigint generated always as identity primary key,
  key        text not null,
  old_value  integer,
  new_value  integer not null,
  source     text not null check (source in ('baseline', 'migration', 'approved_change', 'insert', 'manual')),
  change_id  bigint references private.retention_changes (id),
  changed_by uuid,
  db_user    text not null default session_user,
  changed_at timestamptz not null default clock_timestamp()
);
create index retention_history_key_idx on private.retention_history (key, id desc);
alter table private.retention_history enable row level security;
create trigger retention_history_append_only
  before update or delete on private.retention_history
  for each row execute function cs.reject_change();
create trigger retention_history_no_truncate
  before truncate on private.retention_history
  for each statement execute function cs.reject_change();

create table private.retention_holds (
  id           uuid primary key default gen_random_uuid(),
  target_type  text not null check (target_type in ('user', 'room', 'post', 'comment', 'message')),
  target_id    uuid not null,
  reason       text not null check (char_length(btrim(reason)) between 10 and 500),
  reference    text check (char_length(reference) <= 100),
  created_by   uuid not null,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz,
  released_by  uuid,
  released_at  timestamptz,
  release_note text check (char_length(release_note) <= 500),
  constraint retention_holds_four_eyes check (released_by is null or released_by <> created_by),
  constraint retention_holds_released check ((released_at is null) = (released_by is null))
);
create unique index retention_holds_active_idx on private.retention_holds (target_type, target_id) where released_at is null;
alter table private.retention_holds enable row level security;

create table private.retention_runs (
  id           bigint generated always as identity primary key,
  source       text not null check (source in ('cron', 'manual')),
  actor_id     uuid,
  started_at   timestamptz not null,
  finished_at  timestamptz not null default clock_timestamp(),
  enabled      boolean not null,
  rules        jsonb not null default '{}',
  deleted      jsonb not null default '{}',
  capped       text[] not null default '{}',
  files_queued integer not null default 0,
  applied      integer not null default 0,
  errors       jsonb not null default '{}'
);
create index retention_runs_recent_idx on private.retention_runs (finished_at desc);
alter table private.retention_runs enable row level security;

create or replace function private.retention_setting_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key   text;
  v_rule  record;
  v_apply boolean := coalesce(current_setting('olt.retention_apply', true), '') = 'on';
  v_changed boolean;
begin
  if tg_op = 'DELETE' then
    v_key := old.key;
  else
    v_key := new.key;
  end if;
  select * into v_rule from private.retention_rules() r where r.key = v_key;
  if not found then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if not v_apply then
      perform private.api_error(409, 'retention_locked',
        'Pengaturan retensi data tidak bisa dihapus. Ubah lewat Kepatuhan → Retensi data');
    end if;
    return old;
  end if;
  if not private.retention_value_ok(v_key, new.value) then
    perform private.api_error(400, 'invalid_retention',
      format('Nilai %s harus %s', v_key, private.retention_range_text(v_key)));
  end if;
  if not v_apply then
    if tg_op = 'INSERT' then
      v_changed := new.value is distinct from to_jsonb(v_rule.default_value);
    else
      v_changed := new.value is distinct from old.value;
    end if;
    if v_changed then
      perform private.api_error(409, 'retention_locked',
        'Batas retensi data hanya bisa diubah dari Kepatuhan → Retensi data dan wajib disetujui staf lain');
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.retention_setting_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old integer;
begin
  if not exists (select 1 from private.retention_rules() r where r.key = new.key) then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    if new.value is not distinct from old.value then
      return null;
    end if;
    if (old.value #>> '{}') ~ '^[0-9]+(\.[0-9]+)?$' then
      v_old := (old.value #>> '{}')::numeric::integer;
    end if;
  end if;
  insert into private.retention_history (key, old_value, new_value, source, change_id, changed_by)
  values (new.key, v_old, (new.value #>> '{}')::integer,
          coalesce(nullif(current_setting('olt.retention_source', true), ''),
                   case when tg_op = 'INSERT' then 'insert' else 'manual' end),
          nullif(current_setting('olt.retention_change', true), '')::bigint,
          nullif(current_setting('olt.retention_actor', true), '')::uuid);
  return null;
end;
$$;

create trigger settings_05_retention_guard
  before insert or update of value or delete on private.settings
  for each row execute function private.retention_setting_guard();
create trigger settings_95_retention_history
  after insert or update of value on private.settings
  for each row execute function private.retention_setting_history();
create trigger cs_settings_05_retention_guard
  before insert or update of value or delete on cs.cs_settings
  for each row execute function private.retention_setting_guard();
create trigger cs_settings_95_retention_history
  after insert or update of value on cs.cs_settings
  for each row execute function private.retention_setting_history();

insert into private.retention_history (key, old_value, new_value, source)
select r.key, null, private.retention_value(r.key), 'baseline'
from private.retention_rules() r
order by r.sort_order;

create or replace function private.retention_apply(p_key text, p_value integer, p_change bigint, p_actor uuid,
                                                   p_source text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store text := (select r.store from private.retention_rules() r where r.key = p_key);
begin
  if v_store is null then
    perform private.api_error(404, 'retention_rule_not_found', 'Aturan retensi tidak dikenal');
  end if;
  perform set_config('olt.retention_apply', 'on', true);
  perform set_config('olt.retention_source', p_source, true);
  perform set_config('olt.retention_change', coalesce(p_change::text, ''), true);
  perform set_config('olt.retention_actor', coalesce(p_actor::text, ''), true);
  if v_store = 'cs' then
    perform cs.set_setting(p_key, to_jsonb(p_value), p_actor);
  else
    update private.settings set value = to_jsonb(p_value), updated_at = now() where key = p_key;
    if not found then
      insert into private.settings (key, value, description) values (p_key, to_jsonb(p_value), p_key);
    end if;
  end if;
  perform set_config('olt.retention_apply', '', true);
  perform set_config('olt.retention_source', '', true);
  perform set_config('olt.retention_change', '', true);
  perform set_config('olt.retention_actor', '', true);
end;
$$;

select private.retention_apply('retention.audit_log_days', 1825, null, null, 'migration')
where private.retention_value('retention.audit_log_days') = 365;

create or replace function private.retention_apply_due()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c         private.retention_changes;
  v_applied integer := 0;
begin
  update private.retention_changes x
     set status = 'expired', cancelled_at = now(), cancel_note = 'Tidak diputuskan dalam 14 hari'
   where x.status = 'pending' and x.requested_at < now() - interval '14 days';

  for c in
    select * from private.retention_changes x
    where x.status = 'approved' and x.effective_at <= now()
    order by x.id
    for update skip locked
  loop
    if private.retention_value(c.key) <> c.old_value then
      update private.retention_changes x
         set status = 'superseded', cancelled_at = now(), cancel_note = 'Nilai sudah berubah sebelum berlaku'
       where x.id = c.id;
      continue;
    end if;
    perform private.retention_apply(c.key, c.new_value, c.id, c.decided_by, 'approved_change');
    update private.retention_changes x set status = 'applied', applied_at = now() where x.id = c.id;
    perform cs.audit('retention.change_applied', null, null,
      jsonb_build_object('change', c.id, 'key', c.key, 'from', c.old_value, 'to', c.new_value));
    v_applied := v_applied + 1;
  end loop;
  return v_applied;
end;
$$;

create or replace function private.retention_hold_active(p_type text, p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_id is not null and exists (
    select 1 from private.retention_holds h
    where h.target_type = p_type and h.target_id = p_id
      and h.released_at is null and (h.expires_at is null or h.expires_at > now()));
$$;

create or replace function private.retention_content_held(p_type text, p_id uuid, p_author uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.retention_hold_active(p_type, p_id)
      or private.retention_hold_active('user', p_author)
      or exists (select 1 from public.reports r
                 where r.target_type = p_type and r.target_id = p_id and r.status in ('open', 'reviewing'))
      or exists (select 1 from public.appeals a
                 where a.target_type = p_type and a.target_id = p_id and a.status = 'pending')
      or exists (select 1 from private.evidence e
                 where e.target_type = p_type and e.target_id = p_id::text and e.legal_hold);
$$;

create or replace function private.retention_post_candidates(p_before timestamptz, p_limit integer)
returns table (id uuid, attachments jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.attachments
  from public.posts p
  where p.created_at < p_before
    and not private.retention_content_held('post', p.id, p.author_id)
    and not exists (select 1 from cs.community_posts c where c.post_id = p.id)
    and not exists (select 1 from public.comments c
                    where c.post_id = p.id and private.retention_content_held('comment', c.id, c.author_id))
  limit p_limit;
$$;

create or replace function private.retention_comment_candidates(p_before timestamptz, p_limit integer)
returns table (id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id
  from public.comments c
  join public.posts p on p.id = c.post_id
  where c.created_at < p_before
    and not exists (select 1 from public.comments r where r.parent_id = c.id)
    and not private.retention_content_held('comment', c.id, c.author_id)
    and not private.retention_content_held('post', p.id, p.author_id)
  limit p_limit;
$$;

create or replace function private.retention_message_candidates(p_category text, p_before timestamptz, p_limit integer)
returns table (id uuid, room_id uuid, attachments jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.room_id, m.attachments
  from public.messages m
  join public.chat_rooms r on r.id = m.room_id
  where m.created_at < p_before
    and r.type = any(case p_category when 'direct_chat' then array['direct', 'group']
                                     when 'stock_chat' then array['stock'] else array['support'] end)
    and not private.retention_hold_active('room', r.id)
    and not private.retention_content_held('message', m.id, m.sender_id)
    and (p_category <> 'support_chat'
         or (coalesce(r.last_message_at, r.created_at) < p_before
             and not private.retention_hold_active('user', r.customer_id)
             and not exists (select 1 from cs.tickets t
                             where t.room_id = r.id
                               and (t.status in ('open', 'claimed', 'waiting_customer')
                                    or coalesce(t.closed_at, t.resolved_at, t.created_at) >= p_before))))
  limit p_limit;
$$;

create or replace function private.retention_queue_files(p_attachments jsonb, p_buckets text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select distinct b.bucket, f.path || '/', 'retention'
  from jsonb_array_elements(coalesce(p_attachments, '[]')) a(list)
  cross join lateral jsonb_array_elements(case when jsonb_typeof(a.list) = 'array' then a.list else '[]' end) e(item)
  cross join lateral (values (e.item ->> 'path'), (e.item ->> 'thumbnail')) f(path)
  cross join unnest(p_buckets) b(bucket)
  where jsonb_typeof(e.item) = 'object'
    and f.path ~ '^[^/]+(/[^/]+)*$'
    and char_length(f.path) < 1000;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.retention_purge(p_category text, p_before timestamptz, p_cap integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done    integer := 0;
  v_files   integer := 0;
  v_batch   integer;
  v_rows    integer;
  v_ids     uuid[];
  v_atts    jsonb;
  v_rooms   uuid[];
  v_found   integer;
begin
  loop
    v_batch := least(1000, p_cap - v_done);
    exit when v_batch <= 0;
    v_ids := null;
    if p_category = 'posts' then
      select array_agg(c.id), jsonb_agg(c.attachments) into v_ids, v_atts
      from private.retention_post_candidates(p_before, v_batch) c;
      exit when v_ids is null;
      v_files := v_files + private.retention_queue_files(v_atts, array['attachments']);
      delete from public.posts p where p.id = any(v_ids);
      get diagnostics v_rows = row_count;
    elsif p_category = 'comments' then
      select array_agg(c.id) into v_ids from private.retention_comment_candidates(p_before, v_batch) c;
      exit when v_ids is null;
      delete from public.comments c where c.id = any(v_ids);
      get diagnostics v_rows = row_count;
    else
      select array_agg(c.id), jsonb_agg(c.attachments), array_agg(distinct c.room_id) into v_ids, v_atts, v_rooms
      from private.retention_message_candidates(p_category, p_before, v_batch) c;
      exit when v_ids is null;
      v_files := v_files + private.retention_queue_files(v_atts,
        case when p_category = 'support_chat' then array['attachments', 'cs-documents', 'cs-videos']
             else array['attachments'] end);
      delete from public.messages m where m.id = any(v_ids);
      get diagnostics v_rows = row_count;
      update public.chat_rooms r
         set last_message_preview = null, last_message_sender_id = null
       where r.id = any(v_rooms)
         and (r.last_message_preview is not null or r.last_message_sender_id is not null)
         and not exists (select 1 from public.messages m where m.room_id = r.id and m.created_at >= r.last_message_at);
    end if;
    v_found := cardinality(v_ids);
    v_done := v_done + v_rows;
    exit when v_rows = 0 or v_found < v_batch;
  end loop;
  return jsonb_build_object('deleted', v_done, 'files', v_files, 'capped', v_done >= p_cap);
end;
$$;

create or replace function private.retention_categories()
returns table (category text, key text)
language sql
immutable
set search_path = ''
as $$
  values ('posts', 'retention.posts_years'), ('comments', 'retention.comments_years'),
         ('direct_chat', 'retention.direct_chat_years'), ('stock_chat', 'retention.stock_chat_years'),
         ('support_chat', 'retention.chat_years');
$$;

create or replace function private.retention_guard_run(p_source text default 'cron', p_actor uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_started timestamptz := clock_timestamp();
  v_applied integer;
  v_enabled boolean;
  v_cap     integer;
  v_years   integer;
  v_rules   jsonb := '{}';
  v_deleted jsonb := '{}';
  v_capped  text[] := '{}';
  v_errors  jsonb := '{}';
  v_files   integer := 0;
  v_out     jsonb;
  v_id      bigint;
  c         record;
begin
  if p_source not in ('cron', 'manual') then
    perform private.api_error(400, 'invalid_source', 'Sumber run tidak dikenal');
  end if;
  if not pg_try_advisory_xact_lock(hashtext('private.retention_guard_run')) then
    return jsonb_build_object('skipped', 'already_running');
  end if;
  v_applied := private.retention_apply_due();
  v_enabled := private.retention_value('retention.purge_enabled') = 1;
  v_cap := private.retention_value('retention.max_rows_per_run');

  for c in select * from private.retention_categories() loop
    v_years := private.retention_value(c.key);
    v_rules := v_rules || jsonb_build_object(c.category, v_years);
    continue when not v_enabled or v_years = 0;
    begin
      v_out := private.retention_purge(c.category, now() - make_interval(years => v_years), v_cap);
      v_deleted := v_deleted || jsonb_build_object(c.category, (v_out ->> 'deleted')::integer);
      v_files := v_files + (v_out ->> 'files')::integer;
      if (v_out ->> 'capped')::boolean then
        v_capped := v_capped || c.category;
      end if;
    exception when others then
      v_errors := v_errors || jsonb_build_object(c.category, left(sqlerrm, 300));
      raise warning 'retention guard: % failed: %', c.category, sqlerrm;
    end;
  end loop;

  delete from private.retention_runs r where r.finished_at < now() - interval '3 years';
  insert into private.retention_runs (source, actor_id, started_at, enabled, rules, deleted, capped, files_queued,
                                      applied, errors)
  values (p_source, p_actor, v_started, v_enabled, v_rules || jsonb_build_object('max_rows_per_run', v_cap),
          v_deleted, v_capped, v_files, v_applied, v_errors)
  returning id into v_id;
  raise log 'retention guard run % enabled=% deleted=% capped=% files=% errors=%',
    v_id, v_enabled, v_deleted, v_capped, v_files, v_errors;
  return jsonb_build_object('run_id', v_id, 'enabled', v_enabled, 'deleted', v_deleted, 'capped', to_jsonb(v_capped),
                            'files_queued', v_files, 'applied', v_applied, 'errors', v_errors);
end;
$$;

create or replace function private.health_checks_retention()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'job:retention_guard', 'warning', 'Pembersihan data terjadwal tidak berjalan',
         case when x.last is null then 'Belum ada catatan run sejak dipasang '
                                       || private.health_fmt_time(x.installed)
              else 'Run terakhir ' || private.health_fmt_time(x.last) end
           || '. Periksa job pg_cron retention-guard (setiap hari 02.41 WIB)'
  from (select (select max(r.finished_at) from private.retention_runs r) as last,
               (select min(h.changed_at) from private.retention_history h where h.source = 'baseline') as installed) x
  where private.retention_value('retention.purge_enabled') = 1
    and coalesce(x.last, x.installed) < now() - interval '26 hours'
  union all
  select 'job:retention_errors', 'warning', 'Pembersihan data terjadwal gagal sebagian',
         'Run ' || private.health_fmt_time(r.finished_at) || ' gagal untuk: '
           || (select string_agg(e.key, ', ' order by e.key) from jsonb_each_text(r.errors) e)
  from (select * from private.retention_runs order by finished_at desc limit 1) r
  where r.errors <> '{}';
$$;

create or replace function private.health_current()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (c.key) c.key, c.severity, left(c.title, 200), left(c.detail, 500)
  from (
    select * from private.health_checks_services()
    union all select * from private.health_checks_probes()
    union all select * from private.health_checks_disks()
    union all select * from private.health_checks_database()
    union all select * from private.health_checks_queues()
    union all select * from private.health_checks_backup()
    union all select * from private.health_checks_secrets()
    union all select * from private.health_checks_metrics()
    union all select * from private.health_checks_room_preview()
    union all select * from private.health_checks_healer()
    union all select * from private.health_checks_trade_relay()
    union all select * from private.health_checks_retention()
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
$$;

create or replace function cs.retention_change_view(p_change private.retention_changes)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_change.id, 'key', p_change.key, 'old_value', p_change.old_value, 'new_value', p_change.new_value,
    'direction', p_change.direction, 'reason', p_change.reason, 'status', p_change.status,
    'requested_by', cs.staff_ref(p_change.requested_by), 'requested_at', p_change.requested_at,
    'decided_by', cs.staff_ref(p_change.decided_by), 'decided_at', p_change.decided_at,
    'decision_note', p_change.decision_note, 'effective_at', p_change.effective_at, 'applied_at', p_change.applied_at,
    'cancelled_by', cs.staff_ref(p_change.cancelled_by), 'cancelled_at', p_change.cancelled_at,
    'cancel_note', p_change.cancel_note,
    'expires_at', case when p_change.status = 'pending' then p_change.requested_at + interval '14 days' end,
    'mine', p_change.requested_by is not distinct from cs.current_agent_id(),
    'can_decide', p_change.status = 'pending' and p_change.requested_by is distinct from cs.current_agent_id(),
    'can_cancel', p_change.status in ('pending', 'approved'));
$$;

create or replace function cs.retention_hold_view(p_hold private.retention_holds)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_hold.id, 'target_type', p_hold.target_type, 'target_id', p_hold.target_id,
    'target_label', case p_hold.target_type
      when 'user' then (select '@' || p.username::text from public.profiles p where p.id = p_hold.target_id)
      when 'room' then (select coalesce(r.name, r.stock_code, r.type) from public.chat_rooms r where r.id = p_hold.target_id)
      when 'post' then (select private.snippet(p.body, 80) from public.posts p where p.id = p_hold.target_id)
      when 'comment' then (select private.snippet(c.body, 80) from public.comments c where c.id = p_hold.target_id)
      else (select private.snippet(m.body, 80) from public.messages m where m.id = p_hold.target_id) end,
    'reason', p_hold.reason, 'reference', p_hold.reference,
    'created_by', cs.staff_ref(p_hold.created_by), 'created_at', p_hold.created_at, 'expires_at', p_hold.expires_at,
    'released_by', cs.staff_ref(p_hold.released_by), 'released_at', p_hold.released_at,
    'release_note', p_hold.release_note,
    'active', p_hold.released_at is null and (p_hold.expires_at is null or p_hold.expires_at > now()),
    'can_release', p_hold.released_at is null and p_hold.created_by is distinct from cs.current_agent_id());
$$;

create or replace function cs.retention_require_mfa()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    perform private.api_error(403, 'retention_mfa_required',
      'Persetujuan retensi data wajib memakai sesi dengan 2FA. Aktifkan 2FA di profil lalu masuk lagi');
  end if;
end;
$$;

create or replace function cs_api.retention_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance,cs_super_admin}');
begin
  return jsonb_build_object(
    'enabled', private.retention_value('retention.purge_enabled') = 1,
    'schedule', jsonb_build_object('cron', '41 19 * * *', 'time_wib', '02.41'),
    'delay_days', 7,
    'request_days', 14,
    'can_run', cs.has_role('{cs_super_admin}'),
    'rules', (
      select jsonb_agg(jsonb_build_object(
               'key', r.key, 'unit', r.unit, 'category', r.category, 'value', private.retention_value(r.key),
               'default', r.default_value, 'min', r.min_value, 'max', r.max_value, 'allow_off', r.allow_off,
               'pending', (select cs.retention_change_view(c) from private.retention_changes c
                           where c.key = r.key and c.status in ('pending', 'approved')))
             order by r.sort_order)
      from private.retention_rules() r),
    'changes', coalesce((
      select jsonb_agg(cs.retention_change_view(c) order by c.id desc)
      from (select * from private.retention_changes order by id desc limit 50) c), '[]'),
    'holds', coalesce((
      select jsonb_agg(cs.retention_hold_view(h) order by h.created_at desc)
      from private.retention_holds h
      where h.released_at is null or h.released_at > now() - interval '90 days'), '[]'),
    'runs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', r.id, 'source', r.source, 'actor', cs.staff_ref(r.actor_id), 'started_at', r.started_at,
               'finished_at', r.finished_at, 'enabled', r.enabled, 'deleted', r.deleted, 'capped', to_jsonb(r.capped),
               'files_queued', r.files_queued, 'applied', r.applied, 'errors', r.errors)
             order by r.finished_at desc)
      from (select * from private.retention_runs order by finished_at desc limit 30) r), '[]'));
end;
$$;

create or replace function cs_api.retention_preview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_limit  integer := 10000;
  v_out    jsonb := '{}';
  v_years  integer;
  v_before timestamptz;
  v_count  integer;
  c        record;
begin
  for c in select * from private.retention_categories() loop
    v_years := private.retention_value(c.key);
    v_count := null;
    if v_years > 0 then
      v_before := now() - make_interval(years => v_years);
      v_count := case c.category
        when 'posts' then (select count(*) from private.retention_post_candidates(v_before, v_limit + 1))
        when 'comments' then (select count(*) from private.retention_comment_candidates(v_before, v_limit + 1))
        else (select count(*) from private.retention_message_candidates(c.category, v_before, v_limit + 1)) end;
    end if;
    v_out := v_out || jsonb_build_object(c.category, jsonb_build_object(
      'years', v_years, 'before', v_before, 'count', least(v_count, v_limit), 'more', coalesce(v_count > v_limit, false)));
    v_before := null;
  end loop;
  return jsonb_build_object('enabled', private.retention_value('retention.purge_enabled') = 1, 'limit', v_limit,
                            'categories', v_out, 'computed_at', now());
end;
$$;

create or replace function cs_api.retention_request_change(p_key text, p_value integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_old    integer;
  v_change private.retention_changes;
begin
  if not exists (select 1 from private.retention_rules() r where r.key = p_key) then
    perform private.api_error(404, 'retention_rule_not_found', 'Aturan retensi tidak dikenal');
  end if;
  if p_value is null or not private.retention_value_ok(p_key, to_jsonb(p_value)) then
    perform private.api_error(400, 'invalid_retention', 'Nilai harus ' || private.retention_range_text(p_key));
  end if;
  if char_length(coalesce(v_reason, '')) not between 10 and 500 then
    perform private.api_error(400, 'invalid_reason', 'Alasan perubahan 10–500 karakter');
  end if;
  v_old := private.retention_value(p_key);
  if v_old = p_value then
    perform private.api_error(409, 'retention_no_change', 'Nilai ini sudah berlaku');
  end if;
  if exists (select 1 from private.retention_changes c where c.key = p_key and c.status in ('pending', 'approved')) then
    perform private.api_error(409, 'retention_change_open',
      'Aturan ini masih punya permintaan perubahan yang belum selesai');
  end if;
  insert into private.retention_changes (key, old_value, new_value, direction, reason, requested_by)
  values (p_key, v_old, p_value,
          case when private.retention_keep_score(p_key, p_value) < private.retention_keep_score(p_key, v_old)
               then 'delete_sooner' else 'keep_longer' end,
          v_reason, v_me)
  returning * into v_change;
  perform cs.audit('retention.change_request', null, null,
    jsonb_build_object('change', v_change.id, 'key', p_key, 'from', v_old, 'to', p_value,
                       'direction', v_change.direction, 'reason', v_reason));
  return cs.retention_change_view(v_change);
end;
$$;

create or replace function cs_api.retention_decide_change(p_id bigint, p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_note   text := nullif(btrim(coalesce(p_note, '')), '');
  v_change private.retention_changes;
begin
  perform cs.retention_require_mfa();
  if p_approve is null then
    perform private.api_error(400, 'invalid_decision', 'Pilih setujui atau tolak');
  end if;
  if char_length(coalesce(v_note, '')) > 500 or (not p_approve and char_length(coalesce(v_note, '')) < 5) then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 500 karakter dan wajib 5 karakter bila menolak');
  end if;
  select * into v_change from private.retention_changes c where c.id = p_id for update;
  if not found then
    perform private.api_error(404, 'retention_change_not_found', 'Permintaan perubahan tidak ditemukan');
  end if;
  if v_change.status <> 'pending' then
    perform private.api_error(409, 'retention_change_closed', 'Permintaan ini sudah diputuskan atau dibatalkan');
  end if;
  if v_change.requested_at < now() - interval '14 days' then
    perform private.api_error(409, 'retention_change_expired', 'Permintaan ini sudah kedaluwarsa. Ajukan ulang');
  end if;
  if v_change.requested_by = v_me then
    perform private.api_error(403, 'four_eyes_required', 'Perubahan retensi harus disetujui staf lain, bukan pengajunya');
  end if;

  if not p_approve then
    update private.retention_changes c
       set status = 'rejected', decided_by = v_me, decided_at = now(), decision_note = v_note
     where c.id = p_id
    returning * into v_change;
    perform cs.audit('retention.change_reject', null, null,
      jsonb_build_object('change', p_id, 'key', v_change.key, 'note', v_note));
    return cs.retention_change_view(v_change);
  end if;

  if private.retention_value(v_change.key) <> v_change.old_value then
    perform private.api_error(409, 'retention_stale', 'Nilai aturan sudah berubah sejak diajukan. Ajukan ulang');
  end if;
  if v_change.direction = 'keep_longer' then
    perform private.retention_apply(v_change.key, v_change.new_value, p_id, v_me, 'approved_change');
    update private.retention_changes c
       set status = 'applied', decided_by = v_me, decided_at = now(), decision_note = v_note,
           effective_at = now(), applied_at = now()
     where c.id = p_id
    returning * into v_change;
  else
    update private.retention_changes c
       set status = 'approved', decided_by = v_me, decided_at = now(), decision_note = v_note,
           effective_at = now() + interval '7 days'
     where c.id = p_id
    returning * into v_change;
  end if;
  perform cs.audit('retention.change_approve', null, null,
    jsonb_build_object('change', p_id, 'key', v_change.key, 'from', v_change.old_value, 'to', v_change.new_value,
                       'effective_at', v_change.effective_at, 'note', v_note));
  return cs.retention_change_view(v_change);
end;
$$;

create or replace function cs_api.retention_cancel_change(p_id bigint, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_note   text := nullif(btrim(coalesce(p_note, '')), '');
  v_change private.retention_changes;
begin
  if char_length(coalesce(v_note, '')) not between 5 and 500 then
    perform private.api_error(400, 'invalid_note', 'Alasan pembatalan 5–500 karakter');
  end if;
  select * into v_change from private.retention_changes c where c.id = p_id for update;
  if not found then
    perform private.api_error(404, 'retention_change_not_found', 'Permintaan perubahan tidak ditemukan');
  end if;
  if v_change.status not in ('pending', 'approved') then
    perform private.api_error(409, 'retention_change_closed', 'Permintaan ini sudah berlaku atau ditutup');
  end if;
  update private.retention_changes c
     set status = 'withdrawn', cancelled_by = v_me, cancelled_at = now(), cancel_note = v_note
   where c.id = p_id
  returning * into v_change;
  perform cs.audit('retention.change_cancel', null, null,
    jsonb_build_object('change', p_id, 'key', v_change.key, 'note', v_note));
  return cs.retention_change_view(v_change);
end;
$$;

create or replace function cs_api.retention_add_hold(p_target_type text, p_target text, p_reason text,
                                                     p_reference text default null, p_expires_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_target text := btrim(coalesce(p_target, ''));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_ref    text := nullif(btrim(coalesce(p_reference, '')), '');
  v_id     uuid;
  v_hold   private.retention_holds;
begin
  if coalesce(p_target_type, '') not in ('user', 'room', 'post', 'comment', 'message') then
    perform private.api_error(400, 'invalid_target_type', 'Jenis target harus user, room, post, comment, atau message');
  end if;
  if v_target ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_id := v_target::uuid;
  elsif p_target_type = 'user' then
    select p.id into v_id from public.profiles p where p.username = ltrim(v_target, '@')::extensions.citext;
  end if;
  if v_id is null
     or (p_target_type = 'user' and not exists (select 1 from public.profiles p where p.id = v_id))
     or (p_target_type = 'room' and not exists (select 1 from public.chat_rooms r where r.id = v_id))
     or (p_target_type = 'post' and not exists (select 1 from public.posts p where p.id = v_id))
     or (p_target_type = 'comment' and not exists (select 1 from public.comments c where c.id = v_id))
     or (p_target_type = 'message' and not exists (select 1 from public.messages m where m.id = v_id)) then
    perform private.api_error(404, 'hold_target_not_found', 'Target penahanan tidak ditemukan');
  end if;
  if char_length(coalesce(v_reason, '')) not between 10 and 500 then
    perform private.api_error(400, 'invalid_reason', 'Alasan penahanan 10–500 karakter');
  end if;
  if char_length(coalesce(v_ref, '')) > 100 then
    perform private.api_error(400, 'invalid_reference', 'Nomor referensi maksimal 100 karakter');
  end if;
  if p_expires_at is not null and (p_expires_at < now() + interval '1 day' or p_expires_at > now() + interval '30 years') then
    perform private.api_error(400, 'invalid_expiry', 'Masa penahanan minimal 1 hari dan maksimal 30 tahun');
  end if;
  if exists (select 1 from private.retention_holds h
             where h.target_type = p_target_type and h.target_id = v_id and h.released_at is null) then
    perform private.api_error(409, 'hold_exists', 'Target ini sudah ditahan');
  end if;
  insert into private.retention_holds (target_type, target_id, reason, reference, created_by, expires_at)
  values (p_target_type, v_id, v_reason, v_ref, v_me, p_expires_at)
  returning * into v_hold;
  perform cs.audit('retention.hold_add', null, case when p_target_type = 'user' then v_id end,
    jsonb_build_object('hold', v_hold.id, 'target_type', p_target_type, 'target_id', v_id, 'reason', v_reason,
                       'reference', v_ref, 'expires_at', p_expires_at));
  return cs.retention_hold_view(v_hold);
end;
$$;

create or replace function cs_api.retention_release_hold(p_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_hold private.retention_holds;
begin
  perform cs.retention_require_mfa();
  if char_length(coalesce(v_note, '')) not between 5 and 500 then
    perform private.api_error(400, 'invalid_note', 'Alasan pelepasan 5–500 karakter');
  end if;
  select * into v_hold from private.retention_holds h where h.id = p_id for update;
  if not found then
    perform private.api_error(404, 'hold_not_found', 'Penahanan tidak ditemukan');
  end if;
  if v_hold.released_at is not null then
    perform private.api_error(409, 'hold_released', 'Penahanan ini sudah dilepas');
  end if;
  if v_hold.created_by = v_me then
    perform private.api_error(403, 'four_eyes_required', 'Penahanan harus dilepas staf lain, bukan pembuatnya');
  end if;
  update private.retention_holds h
     set released_by = v_me, released_at = now(), release_note = v_note
   where h.id = p_id
  returning * into v_hold;
  perform cs.audit('retention.hold_release', null, case when v_hold.target_type = 'user' then v_hold.target_id end,
    jsonb_build_object('hold', p_id, 'target_type', v_hold.target_type, 'target_id', v_hold.target_id, 'note', v_note));
  return cs.retention_hold_view(v_hold);
end;
$$;

create or replace function cs_api.retention_run_now()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_out jsonb;
begin
  perform cs.retention_require_mfa();
  if exists (select 1 from private.retention_runs r
             where r.source = 'manual' and r.finished_at > clock_timestamp() - interval '10 minutes') then
    perform private.api_error(429, 'retention_run_recent', 'Run manual terakhir kurang dari 10 menit yang lalu');
  end if;
  v_out := private.retention_guard_run('manual', v_me);
  perform cs.audit('retention.run_manual', null, null, v_out);
  return v_out;
end;
$$;

create or replace function cs.policy_rules()
returns table (key text, min_value integer, max_value integer, unit text, sort_order integer)
language sql
immutable
set search_path = ''
as $$
  values ('complaint.days', 1, 20, 'business_days', 1),
         ('complaint.extension_days', 0, 20, 'business_days', 2);
$$;

create or replace function cs_api.compliance_confirm_policy(p_key text, p_value jsonb, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_note    text := nullif(btrim(coalesce(p_note, '')), '');
  v_rule    record;
  v_old     jsonb;
  v_version integer;
begin
  select * into v_rule from cs.policy_rules() r where r.key = p_key;
  if not found then
    perform private.api_error(403, 'policy_locked',
      case when p_key like 'retention.%'
           then 'Retensi data diatur di Kepatuhan → Retensi data dan wajib disetujui staf lain'
           else 'Kepatuhan hanya mengatur tenggat pengaduan dan perpanjangan tenggat di sini' end);
  end if;
  if p_value is null or jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
     or (p_value #>> '{}')::integer not between v_rule.min_value and v_rule.max_value then
    perform private.api_error(400, 'invalid_policy',
      format('Nilai harus %s–%s %s', v_rule.min_value, v_rule.max_value,
             case v_rule.unit when 'years' then 'tahun' else 'hari kerja' end));
  end if;
  if char_length(v_note) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan konfirmasi maksimal 500 karakter');
  end if;
  select s.value into v_old from cs.cs_settings s where s.key = p_key for update;
  v_version := cs.set_setting(p_key, p_value, v_me);
  insert into cs.policy_confirmations (key, version, value, note, confirmed_by)
  values (p_key, v_version, p_value, v_note, v_me)
  on conflict (key, version) do nothing;
  perform cs.audit('compliance.policy_confirm', null, null,
                   jsonb_build_object('key', p_key, 'value', p_value, 'version', v_version,
                                      'changed', v_old is distinct from p_value));
  return cs.compliance_policy_view(p_key);
end;
$$;

select cron.schedule('retention-guard', '41 19 * * *', $$select private.retention_guard_run('cron')$$);
select cron.schedule('retention-apply-due', '7 * * * *', 'select private.retention_apply_due()');

revoke execute on function private.retention_rules() from public;
revoke execute on function private.retention_value_ok(text, jsonb) from public;
revoke execute on function private.retention_range_text(text) from public;
revoke execute on function private.retention_value(text) from public;
revoke execute on function private.retention_keep_score(text, integer) from public;
revoke execute on function private.retention_setting_guard() from public;
revoke execute on function private.retention_setting_history() from public;
revoke execute on function private.retention_apply(text, integer, bigint, uuid, text) from public;
revoke execute on function private.retention_apply_due() from public;
revoke execute on function private.retention_hold_active(text, uuid) from public;
revoke execute on function private.retention_content_held(text, uuid, uuid) from public;
revoke execute on function private.retention_post_candidates(timestamptz, integer) from public;
revoke execute on function private.retention_comment_candidates(timestamptz, integer) from public;
revoke execute on function private.retention_message_candidates(text, timestamptz, integer) from public;
revoke execute on function private.retention_queue_files(jsonb, text[]) from public;
revoke execute on function private.retention_purge(text, timestamptz, integer) from public;
revoke execute on function private.retention_categories() from public;
revoke execute on function private.retention_guard_run(text, uuid) from public;
revoke execute on function private.health_checks_retention() from public;
revoke execute on function private.health_current() from public;
revoke execute on function cs.retention_change_view(private.retention_changes) from public;
revoke execute on function cs.retention_hold_view(private.retention_holds) from public;
revoke execute on function cs.retention_require_mfa() from public;
revoke execute on function cs_api.retention_overview() from public;
revoke execute on function cs_api.retention_preview() from public;
revoke execute on function cs_api.retention_request_change(text, integer, text) from public;
revoke execute on function cs_api.retention_decide_change(bigint, boolean, text) from public;
revoke execute on function cs_api.retention_cancel_change(bigint, text) from public;
revoke execute on function cs_api.retention_add_hold(text, text, text, text, timestamptz) from public;
revoke execute on function cs_api.retention_release_hold(uuid, text) from public;
revoke execute on function cs_api.retention_run_now() from public;

grant execute on function cs_api.retention_overview() to authenticated;
grant execute on function cs_api.retention_preview() to authenticated;
grant execute on function cs_api.retention_request_change(text, integer, text) to authenticated;
grant execute on function cs_api.retention_decide_change(bigint, boolean, text) to authenticated;
grant execute on function cs_api.retention_cancel_change(bigint, text) to authenticated;
grant execute on function cs_api.retention_add_hold(text, text, text, text, timestamptz) to authenticated;
grant execute on function cs_api.retention_release_hold(uuid, text) to authenticated;
grant execute on function cs_api.retention_run_now() to authenticated;
