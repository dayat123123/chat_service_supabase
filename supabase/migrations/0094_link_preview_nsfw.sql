create table private.link_preview_image_scores (
  sha256        text primary key check (sha256 ~ '^[0-9a-f]{64}$'),
  model         text not null check (char_length(model) between 1 and 200),
  scores        jsonb not null check (jsonb_typeof(scores) = 'object' and pg_column_size(scores) <= 2048),
  classified_at timestamptz not null default now(),
  last_used_at  timestamptz not null default now()
);
create index link_preview_image_scores_used_idx on private.link_preview_image_scores (last_used_at);
alter table private.link_preview_image_scores enable row level security;

update public.link_previews
   set image_path = null, image_width = null, image_height = null, expires_at = least(expires_at, now())
 where image_path is not null;

alter table public.link_previews
  add column image_sha256 text check (image_sha256 ~ '^[0-9a-f]{64}$'),
  add column image_verdict text check (image_verdict in ('allow', 'hold', 'block', 'unreadable', 'unavailable')),
  add column image_category text check (image_category ~ '^[a-z][a-z0-9_]{0,31}$'),
  add column image_score numeric(5, 4) check (image_score between 0 and 1),
  add column image_thresholds_revision bigint,
  add constraint link_previews_image_checked
    check (image_path is null or (image_verdict = 'allow' and image_sha256 is not null));
create index link_previews_image_verdict_idx on public.link_previews (image_verdict)
  where image_verdict in ('hold', 'block', 'unavailable');

create or replace function private.link_preview_scores_valid(p_model text, p_scores jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select char_length(coalesce(p_model, '')) between 1 and 200
     and jsonb_typeof(p_scores) = 'object'
     and pg_column_size(p_scores) <= 2048
     and exists (select 1 from jsonb_each(p_scores))
     and not exists (
       select 1 from jsonb_each(p_scores) e
       where e.key !~ '^[a-z][a-z0-9_]{0,31}$'
          or jsonb_typeof(e.value) <> 'number'
          or (e.value #>> '{}')::numeric not between 0 and 1);
$$;

drop function private.link_preview_store(text, text, text, text, text, text, text, text, integer, integer, text);

create function private.link_preview_store(p_hash text, p_url text, p_status text, p_final_url text,
                                           p_title text, p_description text, p_site_name text,
                                           p_image_path text, p_image_width integer, p_image_height integer,
                                           p_error text, p_check jsonb default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status   text := p_status;
  v_ttl      interval;
  v_verdict  text;
  v_sha      text;
  v_category text;
  v_score    numeric;
  v_revision bigint;
  v_image    text;
begin
  if v_status in ('ok', 'empty') and jsonb_typeof(p_check) = 'object' then
    v_verdict := case when p_check ->> 'image_verdict' in ('allow', 'hold', 'block', 'unreadable', 'unavailable')
                      then p_check ->> 'image_verdict' end;
    v_sha := case when p_check ->> 'image_sha256' ~ '^[0-9a-f]{64}$' then p_check ->> 'image_sha256' end;
    v_category := case when p_check ->> 'image_category' ~ '^[a-z][a-z0-9_]{0,31}$' then p_check ->> 'image_category' end;
    v_score := case when jsonb_typeof(p_check -> 'image_score') = 'number'
                         and (p_check ->> 'image_score')::numeric between 0 and 1
                    then round((p_check ->> 'image_score')::numeric, 4) end;
    v_revision := case when jsonb_typeof(p_check -> 'thresholds_revision') = 'number'
                            and (p_check ->> 'thresholds_revision')::numeric between 1 and 9223372036854775807
                       then (p_check ->> 'thresholds_revision')::numeric::bigint end;
  end if;
  v_image := case when v_verdict = 'allow' and v_sha is not null then p_image_path end;
  if v_status = 'ok' and p_title is null and p_description is null and v_image is null then
    v_status := 'empty';
  end if;
  v_ttl := case when v_status = 'failed' or v_verdict = 'unavailable'
                then make_interval(hours => private.setting_num('link_preview.failed_cache_hours', 24)::integer)
                else make_interval(days => private.setting_num('link_preview.cache_days', 7)::integer) end;
  insert into public.link_previews as p (url_hash, url, final_url, status, title, description, site_name,
                                         image_path, image_width, image_height, error, fetched_at, expires_at,
                                         image_sha256, image_verdict, image_category, image_score,
                                         image_thresholds_revision)
  values (p_hash, p_url, p_final_url, v_status,
          case when v_status = 'ok' then p_title end,
          case when v_status = 'ok' then p_description end,
          case when v_status = 'ok' then p_site_name end,
          case when v_status = 'ok' then v_image end,
          case when v_status = 'ok' and v_image is not null then p_image_width end,
          case when v_status = 'ok' and v_image is not null then p_image_height end,
          left(p_error, 300), now(), now() + v_ttl,
          v_sha, v_verdict, v_category, v_score, v_revision)
  on conflict (url_hash) do update
     set url = excluded.url, final_url = excluded.final_url, status = excluded.status, title = excluded.title,
         description = excluded.description, site_name = excluded.site_name, image_path = excluded.image_path,
         image_width = excluded.image_width, image_height = excluded.image_height, error = excluded.error,
         fetched_at = excluded.fetched_at, expires_at = excluded.expires_at, image_sha256 = excluded.image_sha256,
         image_verdict = excluded.image_verdict, image_category = excluded.image_category,
         image_score = excluded.image_score, image_thresholds_revision = excluded.image_thresholds_revision;
  delete from private.link_preview_queue where url_hash = p_hash;
  return v_status;
end;
$$;

create or replace function public.link_preview_image_scores(p_sha256 text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('model', s.model, 'scores', s.scores)
  from private.link_preview_image_scores s
  where s.sha256 = p_sha256;
$$;

create or replace function public.link_preview_report(p_instance text, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r         record;
  q         record;
  v_max     integer := greatest(private.setting_num('link_preview.max_attempts', 3)::integer, 1);
  v_status  text;
  v_final   text;
  v_image   text;
  v_blocked text[];
  v_check   jsonb;
  v_updated integer := 0;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_results', 'Hasil link preview harus berupa array');
  end if;
  for r in
    select x.url_hash, x.status, x.final_url, x.title, x.description, x.site_name, x.image_path,
           x.image_width, x.image_height, nullif(btrim(coalesce(x.error, '')), '') as error,
           x.image_sha256, x.image_verdict, x.image_category, x.image_score, x.image_model, x.image_scores,
           x.thresholds_revision
    from jsonb_to_recordset(p_results) as x(url_hash text, status text, final_url text, title text, description text,
                                             site_name text, image_path text, image_width integer, image_height integer,
                                             error text, image_sha256 text, image_verdict text, image_category text,
                                             image_score jsonb, image_model text, image_scores jsonb,
                                             thresholds_revision jsonb)
  loop
    select l.url_hash, l.url, l.attempts, l.source, l.queued_at into q
    from private.link_preview_queue l
    where l.url_hash = r.url_hash and l.locked_by = p_instance
    for update;
    continue when not found;
    v_status := r.status;
    if v_status is null or v_status not in ('ok', 'empty', 'blocked', 'failed', 'retry', 'release') then
      v_status := 'retry';
      r.error := coalesce(r.error, 'invalid_status');
    end if;
    if v_status = 'release' then
      update private.link_preview_queue l
         set locked_until = null, locked_by = null, attempts = greatest(l.attempts - 1, 0)
       where l.url_hash = q.url_hash;
      v_updated := v_updated + 1;
      continue;
    end if;
    if r.image_sha256 ~ '^[0-9a-f]{64}$' then
      if private.link_preview_scores_valid(r.image_model, r.image_scores) then
        insert into private.link_preview_image_scores as s (sha256, model, scores)
        values (r.image_sha256, r.image_model, r.image_scores)
        on conflict (sha256) do update
           set model = excluded.model, scores = excluded.scores, classified_at = now(), last_used_at = now();
      elsif r.image_verdict in ('allow', 'hold', 'block') then
        update private.link_preview_image_scores s set last_used_at = now() where s.sha256 = r.image_sha256;
      end if;
    end if;
    if v_status = 'retry' and q.attempts < v_max then
      update private.link_preview_queue l
         set locked_until = null, locked_by = null, error = left(coalesce(r.error, 'retry'), 300),
             available_at = now() + least(interval '1 hour', interval '1 minute' * power(2, greatest(q.attempts - 1, 0)))
                                  * (0.8 + random() * 0.4)
       where l.url_hash = q.url_hash;
      v_updated := v_updated + 1;
      continue;
    end if;
    if v_status = 'retry' then
      v_status := 'failed';
    end if;
    v_final := case when char_length(r.final_url) <= 2048 and r.final_url ~* '^https?://[^[:space:][:cntrl:]]+$'
                    then r.final_url end;
    v_image := case when r.image_path ~ ('^' || q.url_hash || '/[0-9a-f]{16}/preview\.(jpg|png|webp|gif)$')
                         and r.image_width between 1 and 10000 and r.image_height between 1 and 10000
                    then r.image_path end;
    if v_status in ('ok', 'empty') then
      v_blocked := private.link_preview_blocked_hosts(array[private.link_preview_host(q.url), private.link_preview_host(v_final)]);
      if cardinality(v_blocked) > 0 then
        v_status := 'blocked';
        r.error := 'blocked_domain';
      end if;
    end if;
    v_check := jsonb_strip_nulls(jsonb_build_object(
      'image_sha256', r.image_sha256, 'image_verdict', r.image_verdict, 'image_category', r.image_category,
      'image_score', r.image_score, 'thresholds_revision', r.thresholds_revision));
    perform private.link_preview_store(q.url_hash, q.url, v_status, v_final,
                                       private.link_preview_text(r.title, 300),
                                       private.link_preview_text(r.description, 1000),
                                       private.link_preview_text(r.site_name, 100),
                                       v_image, r.image_width, r.image_height,
                                       case when v_status <> 'ok' then r.error end,
                                       v_check);
    if v_status in ('ok', 'empty') and r.image_verdict = 'unavailable' and q.attempts < v_max then
      insert into private.link_preview_queue (url_hash, url, source, queued_at, available_at, attempts, error)
      values (q.url_hash, q.url, q.source, q.queued_at,
              now() + least(interval '1 hour', interval '1 minute' * power(2, greatest(q.attempts - 1, 0)))
                    * (0.8 + random() * 0.4),
              q.attempts, 'classifier_unavailable')
      on conflict (url_hash) do nothing;
    end if;
    v_updated := v_updated + 1;
  end loop;
  return v_updated;
end;
$$;

create or replace function private.link_preview_purge()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days    integer := greatest(private.setting_num('link_preview.retention_days', 30)::integer, 1);
  v_deleted integer;
begin
  delete from public.link_previews p
   where p.expires_at < now() - make_interval(days => v_days)
     and not exists (select 1 from private.link_preview_queue q where q.url_hash = p.url_hash);
  get diagnostics v_deleted = row_count;
  delete from private.link_preview_queue q where q.queued_at < now() - interval '7 days';
  delete from private.link_preview_image_scores s where s.last_used_at < now() - make_interval(days => v_days);
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select distinct 'link-previews', o.folder, 'link_preview'
  from (
    select regexp_replace(o.name, '[^/]+$', '') as folder, o.name
    from storage.objects o
    where o.bucket_id = 'link-previews'
      and o.created_at < now() - interval '1 day'
  ) o
  where o.folder ~ '^[^/]+(/[^/]+)*/$'
    and not exists (select 1 from public.link_previews p where p.image_path = o.name)
    and not exists (select 1 from private.storage_cleanup_queue s
                    where s.bucket_id = 'link-previews' and s.prefix = o.folder and s.done_at is null);
  return v_deleted;
end;
$$;

revoke execute on function private.link_preview_scores_valid(text, jsonb) from public;
revoke execute on function private.link_preview_store(text, text, text, text, text, text, text, text, integer, integer, text, jsonb)
  from public;
revoke execute on function public.link_preview_image_scores(text) from public, anon, authenticated;
grant execute on function public.link_preview_image_scores(text) to service_role;
