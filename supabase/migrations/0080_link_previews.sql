insert into private.settings (key, value, description) values
  ('link_preview.enabled', 'true', 'Buat pratinjau link untuk postingan, komentar, dan chat (false = berhenti mengantre link baru)'),
  ('link_preview.cache_days', '7', 'Umur pratinjau sebelum link diambil ulang saat muncul lagi di konten (hari)'),
  ('link_preview.failed_cache_hours', '24', 'Lama link yang gagal diambil tidak dicoba lagi (jam)'),
  ('link_preview.max_attempts', '3', 'Percobaan maksimal per link sebelum dianggap gagal'),
  ('link_preview.retention_days', '30', 'Pratinjau yang kedaluwarsa lebih lama dari ini dihapus beserta gambarnya (hari)')
on conflict (key) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('link-previews', 'link-previews', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.link_previews (
  url_hash     text primary key check (url_hash ~ '^[0-9a-f]{64}$'),
  url          text not null check (char_length(url) <= 2048 and url ~ '^https?://'),
  final_url    text check (char_length(final_url) <= 2048 and final_url ~* '^https?://'),
  status       text not null check (status in ('ok', 'empty', 'blocked', 'failed')),
  title        text check (char_length(title) <= 300),
  description  text check (char_length(description) <= 1000),
  site_name    text check (char_length(site_name) <= 100),
  image_path   text check (image_path ~ '^[0-9a-f]{64}/[0-9a-f]{16}/preview\.(jpg|png|webp|gif)$'),
  image_width  integer check (image_width between 1 and 10000),
  image_height integer check (image_height between 1 and 10000),
  error        text check (char_length(error) <= 300),
  fetched_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  constraint link_previews_image check ((image_path is null) = (image_width is null) and (image_path is null) = (image_height is null)),
  constraint link_previews_image_owner check (image_path is null or starts_with(image_path, url_hash || '/'))
);
create index link_previews_expires_idx on public.link_previews (expires_at);
create index link_previews_image_idx on public.link_previews (image_path) where image_path is not null;
alter table public.link_previews enable row level security;
revoke all on public.link_previews from public, anon, authenticated;

create table private.link_preview_queue (
  url_hash     text primary key check (url_hash ~ '^[0-9a-f]{64}$'),
  url          text not null check (char_length(url) <= 2048 and url ~ '^https?://'),
  source       text not null check (source in ('post', 'comment', 'message')),
  queued_at    timestamptz not null default now(),
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text check (char_length(locked_by) <= 100),
  attempts     integer not null default 0 check (attempts >= 0),
  error        text check (char_length(error) <= 300)
);
create index link_preview_queue_ready_idx on private.link_preview_queue (available_at, queued_at);
alter table private.link_preview_queue enable row level security;

create or replace function private.link_preview_normalize(p_url text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_url  text := btrim(coalesce(p_url, ''));
  v_last text;
  v_m    text[];
  v_auth text[];
  v_host text;
  v_port text;
  v_rest text;
begin
  if char_length(v_url) > 4096 then
    return null;
  end if;
  loop
    v_last := right(v_url, 1);
    exit when v_last = '';
    if v_last in ('.', ',', ';', ':', '!', '?', '''', '"', '*', '<', '>')
       or (v_last = ')' and char_length(replace(v_url, '(', '')) > char_length(replace(v_url, ')', '')))
       or (v_last = ']' and char_length(replace(v_url, '[', '')) > char_length(replace(v_url, ']', '')))
       or (v_last = '}' and char_length(replace(v_url, '{', '')) > char_length(replace(v_url, '}', ''))) then
      v_url := left(v_url, -1);
    else
      exit;
    end if;
  end loop;
  v_url := split_part(v_url, '#', 1);
  if v_url ~ '[[:space:][:cntrl:]]' then
    return null;
  end if;
  v_m := regexp_match(v_url, '^(https?)://([^/?#]*)(.*)$', 'i');
  if v_m is null or v_m[2] ~ '[@%\\]' then
    return null;
  end if;
  v_auth := regexp_match(v_m[2], '^(\[[0-9A-Fa-f:.]+\]|[^:\[\]]+)(:[0-9]{1,5})?$');
  if v_auth is null then
    return null;
  end if;
  v_host := rtrim(lower(v_auth[1]), '.');
  v_port := nullif(ltrim(v_auth[2], ':'), '');
  if v_host = '' then
    return null;
  end if;
  if (lower(v_m[1]) = 'http' and v_port = '80') or (lower(v_m[1]) = 'https' and v_port = '443') then
    v_port := null;
  end if;
  v_rest := v_m[3];
  if v_rest = '' or left(v_rest, 1) = '?' then
    v_rest := '/' || v_rest;
  end if;
  v_url := lower(v_m[1]) || '://' || v_host || coalesce(':' || v_port, '') || v_rest;
  if char_length(v_url) > 2048 then
    return null;
  end if;
  return v_url;
end;
$$;

create or replace function private.link_preview_urls(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce((array_agg(u order by first_pos))[1:3], '{}')
  from (
    select u, min(ord) as first_pos
    from (
      select private.link_preview_normalize(m[1]) as u, ord
      from regexp_matches(coalesce(p_text, ''), '(https?://[^\s<>"''`]+)', 'gi') with ordinality as t(m, ord)
    ) x
    where u is not null
    group by u
  ) y;
$$;

create or replace function private.link_preview_hash(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(sha256(convert_to(p_url, 'UTF8')), 'hex');
$$;

create or replace function private.link_preview_host(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select rtrim(lower((regexp_match(p_url, '^https?://(\[[^\]/]*\]|[^:/?#@]+)', 'i'))[1]), '.');
$$;

create or replace function private.link_preview_domains(p_host text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(array_to_string(s.parts[i:], '.') order by i), '{}')
  from (select string_to_array(p_host, '.') as parts) s
  cross join lateral generate_subscripts(s.parts, 1) as i
  where p_host is not null and p_host !~ '^\[';
$$;

create or replace function private.link_preview_blocked_hosts(p_hosts text[])
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_hosts   text[];
  v_blocked text[] := '{}';
  v_allowed text[] := '{}';
begin
  select coalesce(array_agg(distinct h), '{}') into v_hosts from unnest(p_hosts) h where h is not null;
  if cardinality(v_hosts) = 0 or to_regclass('cs.blocked_domains') is null then
    return '{}';
  end if;
  begin
    select coalesce(array_agg(distinct h.host), '{}') into v_blocked
    from unnest(v_hosts) h(host)
    cross join lateral unnest(private.link_preview_domains(h.host)) d(domain)
    join (
      select lower(btrim(to_jsonb(b) ->> 'domain')) as domain
      from cs.blocked_domains b
      where coalesce(lower(to_jsonb(b) ->> 'action'), 'block') <> 'allow'
    ) bd on bd.domain = d.domain;
    if cardinality(v_blocked) > 0 and to_regclass('cs.allowed_domains') is not null then
      select coalesce(array_agg(distinct h.host), '{}') into v_allowed
      from unnest(v_blocked) h(host)
      cross join lateral unnest(private.link_preview_domains(h.host)) d(domain)
      join (select lower(btrim(to_jsonb(a) ->> 'domain')) as domain from cs.allowed_domains a) ad
        on ad.domain = d.domain;
    end if;
  exception when others then
    return v_hosts;
  end;
  return array(select h from unnest(v_blocked) h where h <> all (v_allowed) order by h);
end;
$$;

create or replace function private.link_preview_store(p_hash text, p_url text, p_status text, p_final_url text,
                                                      p_title text, p_description text, p_site_name text,
                                                      p_image_path text, p_image_width integer, p_image_height integer,
                                                      p_error text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := p_status;
  v_ttl    interval;
begin
  if v_status = 'ok' and p_title is null and p_description is null and p_image_path is null then
    v_status := 'empty';
  end if;
  v_ttl := case when v_status = 'failed'
                then make_interval(hours => private.setting_num('link_preview.failed_cache_hours', 24)::integer)
                else make_interval(days => private.setting_num('link_preview.cache_days', 7)::integer) end;
  insert into public.link_previews as p (url_hash, url, final_url, status, title, description, site_name,
                                         image_path, image_width, image_height, error, fetched_at, expires_at)
  values (p_hash, p_url, p_final_url, v_status,
          case when v_status = 'ok' then p_title end,
          case when v_status = 'ok' then p_description end,
          case when v_status = 'ok' then p_site_name end,
          case when v_status = 'ok' then p_image_path end,
          case when v_status = 'ok' and p_image_path is not null then p_image_width end,
          case when v_status = 'ok' and p_image_path is not null then p_image_height end,
          left(p_error, 300), now(), now() + v_ttl)
  on conflict (url_hash) do update
     set url = excluded.url, final_url = excluded.final_url, status = excluded.status, title = excluded.title,
         description = excluded.description, site_name = excluded.site_name, image_path = excluded.image_path,
         image_width = excluded.image_width, image_height = excluded.image_height, error = excluded.error,
         fetched_at = excluded.fetched_at, expires_at = excluded.expires_at;
  delete from private.link_preview_queue where url_hash = p_hash;
  return v_status;
end;
$$;

create or replace function private.link_preview_enqueue(p_urls text[], p_source text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_urls    text[];
  v_blocked text[];
  v_count   integer := 0;
  v_rows    integer;
  r         record;
begin
  if coalesce(cardinality(p_urls), 0) = 0
     or not coalesce((private.setting_json('link_preview.enabled', 'true') #>> '{}')::boolean, true) then
    return 0;
  end if;
  select coalesce(array_agg(u), '{}') into v_urls
  from (
    select distinct u
    from unnest(p_urls) u
    where u is not null
      and not exists (select 1 from public.link_previews p
                      where p.url_hash = private.link_preview_hash(u) and p.expires_at > now())
      and not exists (select 1 from private.link_preview_queue q where q.url_hash = private.link_preview_hash(u))
  ) x;
  if cardinality(v_urls) = 0 then
    return 0;
  end if;
  v_blocked := private.link_preview_blocked_hosts(array(select private.link_preview_host(u) from unnest(v_urls) u));
  for r in select u as url, private.link_preview_hash(u) as hash, private.link_preview_host(u) as host
           from unnest(v_urls) u
  loop
    if r.host = any (v_blocked) then
      perform private.link_preview_store(r.hash, r.url, 'blocked', null, null, null, null, null, null, null, 'blocked_domain');
    else
      insert into private.link_preview_queue (url_hash, url, source) values (r.hash, r.url, p_source)
      on conflict (url_hash) do nothing;
      get diagnostics v_rows = row_count;
      v_count := v_count + v_rows;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function private.link_preview_content()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null or new.moderation_status <> 'visible' then
    return null;
  end if;
  if tg_op = 'UPDATE' and new.body is not distinct from old.body
     and old.moderation_status = 'visible' and old.deleted_at is null then
    return null;
  end if;
  if tg_table_name = 'messages' then
    if new.kind <> 'text' or exists (select 1 from public.chat_rooms r where r.id = new.room_id and r.type = 'support') then
      return null;
    end if;
  end if;
  perform private.link_preview_enqueue(private.link_preview_urls(new.body), tg_argv[0]);
  return null;
end;
$$;

create trigger posts_50_link_preview
  after insert or update of body, moderation_status on public.posts
  for each row when (new.body ~* 'https?://')
  execute function private.link_preview_content('post');

create trigger comments_50_link_preview
  after insert or update of body, moderation_status on public.comments
  for each row when (new.body ~* 'https?://')
  execute function private.link_preview_content('comment');

create trigger messages_50_link_preview
  after insert or update of body, moderation_status on public.messages
  for each row when (new.body ~* 'https?://')
  execute function private.link_preview_content('message');

create or replace function public.link_preview_claim(p_instance text, p_limit integer default 10,
                                                     p_lease_seconds integer default 120)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max     integer := greatest(private.setting_num('link_preview.max_attempts', 3)::integer, 1);
  v_claim   jsonb;
  v_picked  jsonb := '[]';
  v_blocked text[];
  r         record;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance link preview tidak valid');
  end if;
  if coalesce(p_limit, 0) not between 1 and 100 or coalesce(p_lease_seconds, 0) not between 30 and 3600 then
    perform private.api_error(400, 'invalid_claim', 'Batas claim di luar rentang');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('url_hash', s.url_hash, 'url', s.url, 'attempts', s.attempts,
                                               'error', s.error) order by s.available_at, s.queued_at), '[]')
    into v_claim
  from (
    select q.url_hash, q.url, q.attempts, q.error, q.available_at, q.queued_at
    from private.link_preview_queue q
    where q.available_at <= now()
      and (q.locked_until is null or q.locked_until < now())
    order by q.available_at, q.queued_at
    limit p_limit
    for update skip locked
  ) s;
  v_blocked := private.link_preview_blocked_hosts(array(
    select private.link_preview_host(x.url) from jsonb_to_recordset(v_claim) as x(url text)));
  for r in select x.url_hash, x.url, x.attempts, x.error
           from jsonb_to_recordset(v_claim) as x(url_hash text, url text, attempts integer, error text)
  loop
    if private.link_preview_host(r.url) = any (v_blocked) then
      perform private.link_preview_store(r.url_hash, r.url, 'blocked', null, null, null, null, null, null, null,
                                         'blocked_domain');
    elsif r.attempts >= v_max then
      perform private.link_preview_store(r.url_hash, r.url, 'failed', null, null, null, null, null, null, null,
                                         coalesce(r.error, 'too_many_attempts'));
    else
      update private.link_preview_queue q
         set locked_until = now() + make_interval(secs => p_lease_seconds), locked_by = p_instance,
             attempts = q.attempts + 1
       where q.url_hash = r.url_hash;
      v_picked := v_picked || jsonb_build_array(jsonb_build_object(
        'url_hash', r.url_hash, 'url', r.url, 'attempt', r.attempts + 1));
    end if;
  end loop;
  return v_picked;
end;
$$;

create or replace function private.link_preview_text(p_text text, p_max integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(nullif(btrim(regexp_replace(coalesce(p_text, ''), '[[:space:][:cntrl:]]+', ' ', 'g')), ''), p_max);
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
  v_updated integer := 0;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_results', 'Hasil link preview harus berupa array');
  end if;
  for r in
    select x.url_hash, x.status, x.final_url, x.title, x.description, x.site_name, x.image_path,
           x.image_width, x.image_height, nullif(btrim(coalesce(x.error, '')), '') as error
    from jsonb_to_recordset(p_results) as x(url_hash text, status text, final_url text, title text, description text,
                                             site_name text, image_path text, image_width integer, image_height integer,
                                             error text)
  loop
    select l.url_hash, l.url, l.attempts into q
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
    perform private.link_preview_store(q.url_hash, q.url, v_status, v_final,
                                       private.link_preview_text(r.title, 300),
                                       private.link_preview_text(r.description, 1000),
                                       private.link_preview_text(r.site_name, 100),
                                       v_image, r.image_width, r.image_height,
                                       case when v_status <> 'ok' then r.error end);
    v_updated := v_updated + 1;
  end loop;
  return v_updated;
end;
$$;

create or replace function public.get_link_previews(p_urls text[])
returns table (url text, status text, title text, description text, site_name text, image_path text,
               image_width integer, image_height integer, final_url text, fetched_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_blocked text[];
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if coalesce(cardinality(p_urls), 0) > 20 then
    perform private.api_error(400, 'too_many_urls', 'Maksimal 20 link per permintaan');
  end if;
  if coalesce(cardinality(p_urls), 0) = 0 then
    return;
  end if;
  v_blocked := private.link_preview_blocked_hosts(array(
    select private.link_preview_host(p.final_url)
    from unnest(p_urls) u
    join public.link_previews p on p.url_hash = private.link_preview_hash(private.link_preview_normalize(u))
    where p.status = 'ok'
    union
    select private.link_preview_host(private.link_preview_normalize(u)) from unnest(p_urls) u));
  return query
  select u.url,
         case when p.status = 'ok' and not (coalesce(private.link_preview_host(n.norm) = any (v_blocked), false)
                                            or coalesce(private.link_preview_host(p.final_url) = any (v_blocked), false))
              then 'ok'
              when q.url_hash is not null then 'pending'
              else 'none' end,
         ok.title, ok.description, ok.site_name, ok.image_path, ok.image_width, ok.image_height, ok.final_url,
         ok.fetched_at
  from unnest(p_urls) with ordinality as u(url, ord)
  cross join lateral (select private.link_preview_normalize(u.url) as norm) n
  cross join lateral (select private.link_preview_hash(n.norm) as hash) h
  left join public.link_previews p on n.norm is not null and p.url_hash = h.hash
  left join private.link_preview_queue q on n.norm is not null and q.url_hash = h.hash
  left join lateral (
    select p.title, p.description, p.site_name, p.image_path, p.image_width, p.image_height, p.final_url, p.fetched_at
    where p.status = 'ok'
      and not (coalesce(private.link_preview_host(n.norm) = any (v_blocked), false)
               or coalesce(private.link_preview_host(p.final_url) = any (v_blocked), false))
  ) ok on true
  order by u.ord;
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

select cron.schedule('link-preview-purge', '37 3 * * *', 'select private.link_preview_purge()');

revoke execute on function private.link_preview_normalize(text) from public;
revoke execute on function private.link_preview_urls(text) from public;
revoke execute on function private.link_preview_hash(text) from public;
revoke execute on function private.link_preview_host(text) from public;
revoke execute on function private.link_preview_domains(text) from public;
revoke execute on function private.link_preview_blocked_hosts(text[]) from public;
revoke execute on function private.link_preview_store(text, text, text, text, text, text, text, text, integer, integer, text)
  from public;
revoke execute on function private.link_preview_enqueue(text[], text) from public;
revoke execute on function private.link_preview_content() from public;
revoke execute on function private.link_preview_text(text, integer) from public;
revoke execute on function private.link_preview_purge() from public;
revoke execute on function public.link_preview_claim(text, integer, integer) from public, anon, authenticated;
revoke execute on function public.link_preview_report(text, jsonb) from public, anon, authenticated;
revoke execute on function public.get_link_previews(text[]) from public, anon;

grant execute on function public.link_preview_claim(text, integer, integer) to service_role;
grant execute on function public.link_preview_report(text, jsonb) to service_role;
grant execute on function public.get_link_previews(text[]) to authenticated;
