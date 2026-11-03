insert into private.settings (key, value, description) values
  ('integration.account_link_days', '30',
   'Tautan rekening OLT tidak dipakai lagi bila pemiliknya tidak login fitur sosial selama sekian hari'),
  ('integration.receipt_days', '7', 'Id pesan notifikasi OLT diingat selama sekian hari agar kiriman ulang tidak dobel'),
  ('integration.bot_posts_per_hour', '30', 'Batas postingan bot per API key integrasi per jam')
on conflict (key) do nothing;

create table private.account_links (
  cust_id    text not null check (cust_id ~ '^[A-Z0-9._-]{1,32}$'),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  seen_at    timestamptz not null default now(),
  primary key (cust_id, profile_id)
);
create index account_links_profile_idx on private.account_links (profile_id);
create index account_links_seen_idx on private.account_links (seen_at);

create table private.integration_keys (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null check (char_length(btrim(name)) between 3 and 80),
  prefix                text not null unique check (prefix ~ '^[A-Za-z0-9_-]{8}$'),
  key_hash              text not null unique check (key_hash ~ '^[0-9a-f]{64}$'),
  scopes                text[] not null
                        check (cardinality(scopes) between 1 and 2 and scopes <@ array['notify', 'bot_post']),
  official_account_id   uuid references cs.official_accounts (profile_id),
  allowed_cidrs         cidr[] not null default '{}' check (cardinality(allowed_cidrs) <= 20),
  rate_limit_per_minute integer not null default 600 check (rate_limit_per_minute between 1 and 100000),
  created_by            uuid not null references cs.agents (user_id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  disabled_at           timestamptz,
  revoked_at            timestamptz,
  revoked_by            uuid references cs.agents (user_id),
  revoke_reason         text check (char_length(revoke_reason) <= 500),
  last_used_at          timestamptz,
  last_used_ip          inet,
  constraint integration_keys_bot check (('bot_post' = any (scopes)) = (official_account_id is not null))
);

create table private.integration_receipts (
  key_id     uuid not null references private.integration_keys (id) on delete cascade,
  message_id text not null check (message_id ~ '^[A-Za-z0-9._:-]{1,100}$'),
  status     text not null default 'queued' check (status in ('queued', 'no_recipient')),
  devices    integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (key_id, message_id)
);
create index integration_receipts_created_idx on private.integration_receipts (created_at);

create table private.integration_posts (
  key_id            uuid not null references private.integration_keys (id),
  message_id        text not null check (message_id ~ '^[A-Za-z0-9._:-]{1,100}$'),
  community_post_id uuid unique references cs.community_posts (id),
  post_id           uuid references public.posts (id) on delete set null,
  created_at        timestamptz not null default now(),
  primary key (key_id, message_id)
);
create index integration_posts_post_idx on private.integration_posts (post_id) where post_id is not null;
create index integration_posts_recent_idx on private.integration_posts (key_id, created_at);

create table private.integration_daily (
  key_id         uuid not null references private.integration_keys (id) on delete cascade,
  day            date not null,
  received       integer not null default 0,
  queued         integer not null default 0,
  devices        integer not null default 0,
  no_recipient   integer not null default 0,
  duplicate      integer not null default 0,
  invalid        integer not null default 0,
  posts          integer not null default 0,
  posts_rejected integer not null default 0,
  primary key (key_id, day)
);

alter table private.account_links enable row level security;
alter table private.integration_keys enable row level security;
alter table private.integration_receipts enable row level security;
alter table private.integration_posts enable row level security;
alter table private.integration_daily enable row level security;

do $do$
begin
  if to_regprocedure('private.push_allowed(uuid,text)') is null then
    execute $fn$
      create function private.push_allowed(p_profile uuid, p_kind text)
      returns boolean
      language sql
      stable
      security definer
      set search_path = ''
      as 'select true'
    $fn$;
    revoke execute on function private.push_allowed(uuid, text) from public;
  end if;
end;
$do$;

create or replace function private.integration_cust_id(p_value jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_value) = 'string' and btrim(p_value #>> '{}') ~ '^[A-Za-z0-9._-]{1,32}$'
              then upper(btrim(p_value #>> '{}')) end;
$$;

create or replace function private.integration_day()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Jakarta')::date;
$$;

create or replace function private.integration_ref(p_key uuid, p_day date)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'olt:' || p_key::text || ':' || to_char(p_day, 'YYYYMMDD');
$$;

create or replace function public.set_olt_account_links(p_profile_id uuid, p_accounts jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids     text[];
  v_total   integer;
begin
  if jsonb_typeof(p_accounts) is distinct from 'array' then
    perform private.api_error(400, 'invalid_accounts', 'accounts harus berupa array');
  end if;
  v_total := jsonb_array_length(p_accounts);
  if v_total > 1000 then
    perform private.api_error(400, 'invalid_accounts', 'accounts terlalu banyak');
  end if;
  if p_profile_id is null
     or not exists (select 1 from public.profiles p where p.id = p_profile_id and p.deleted_at is null) then
    perform private.api_error(404, 'profile_not_found', 'Profil tidak ditemukan');
  end if;

  select coalesce(array_agg(v.cust_id order by v.ord), '{}') into v_ids
  from (select x.cust_id, min(x.ord) as ord
        from (select private.integration_cust_id(e.value) as cust_id, e.ord
              from jsonb_array_elements(p_accounts) with ordinality as e(value, ord)) x
        where x.cust_id is not null
        group by x.cust_id
        order by min(x.ord)
        limit 50) v;

  delete from private.account_links l
   where l.profile_id = p_profile_id and l.cust_id <> all (v_ids);
  insert into private.account_links (cust_id, profile_id)
  select c, p_profile_id from unnest(v_ids) as c
  on conflict (cust_id, profile_id) do update set seen_at = now();

  return jsonb_build_object('linked', cardinality(v_ids), 'ignored', v_total - cardinality(v_ids));
end;
$$;

create or replace function private.account_links_forget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.account_links where profile_id = new.id;
  return null;
end;
$$;

create trigger profiles_70_account_links_forget
  after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function private.account_links_forget();

create or replace function private.account_links_export(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('cust_id', l.cust_id, 'linked_at', l.created_at, 'seen_at', l.seen_at)
                            order by l.cust_id), '[]')
  from private.account_links l
  where l.profile_id = p_profile;
$$;

create or replace function private.post_is_bot(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from private.integration_posts b where b.post_id = p_post_id);
$$;

create or replace function cs.integration_key_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', k.id, 'name', k.name, 'prefix', k.prefix, 'hint', 'oik_' || k.prefix || '…',
    'scopes', to_jsonb(k.scopes),
    'official_account', case when k.official_account_id is not null
                             then cs.community_account_ref(k.official_account_id) end,
    'allowed_cidrs', coalesce((select jsonb_agg(c::text order by c) from unnest(k.allowed_cidrs) c), '[]'),
    'rate_limit_per_minute', k.rate_limit_per_minute,
    'status', case when k.revoked_at is not null then 'revoked'
                   when k.disabled_at is not null then 'disabled' else 'active' end,
    'created_by', cs.staff_ref(k.created_by), 'created_at', k.created_at, 'updated_at', k.updated_at,
    'disabled_at', k.disabled_at, 'revoked_at', k.revoked_at, 'revoked_by', cs.staff_ref(k.revoked_by),
    'revoke_reason', k.revoke_reason, 'last_used_at', k.last_used_at, 'last_used_ip', host(k.last_used_ip))
  from private.integration_keys k
  where k.id = p_id;
$$;

create or replace function cs.integration_scopes(p_scopes text[])
returns text[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_scopes text[];
begin
  select coalesce(array_agg(distinct btrim(s) order by btrim(s)), '{}') into v_scopes
  from unnest(coalesce(p_scopes, '{}')) s
  where btrim(coalesce(s, '')) <> '';
  if cardinality(v_scopes) = 0 or not v_scopes <@ array['notify', 'bot_post'] then
    perform private.api_error(400, 'invalid_scopes', 'Pilih izin notify, bot_post, atau keduanya');
  end if;
  return v_scopes;
end;
$$;

create or replace function cs.integration_cidrs(p_cidrs text[])
returns cidr[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_item   text;
  v_result cidr[] := '{}';
begin
  foreach v_item in array coalesce(p_cidrs, '{}') loop
    continue when btrim(coalesce(v_item, '')) = '';
    begin
      v_result := v_result || network(btrim(v_item)::inet)::cidr;
    exception when invalid_text_representation then
      perform private.api_error(400, 'invalid_cidr', format('Alamat IP atau CIDR tidak valid: %s', left(v_item, 60)));
    end;
  end loop;
  select coalesce(array_agg(distinct c order by c), '{}') into v_result from unnest(v_result) c;
  if cardinality(v_result) > 20 then
    perform private.api_error(400, 'invalid_cidr', 'Maksimal 20 alamat IP atau CIDR');
  end if;
  return v_result;
end;
$$;

create or replace function cs.integration_check(p_name text, p_scopes text[], p_official uuid, p_rate integer,
                                                p_active boolean)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 80 then
    perform private.api_error(400, 'invalid_name', 'Nama key 3–80 karakter');
  end if;
  if coalesce(p_rate, 0) not between 1 and 100000 then
    perform private.api_error(400, 'invalid_rate_limit', 'Batas per menit 1–100000');
  end if;
  if 'bot_post' = any (p_scopes)
     and (p_official is null or not exists (select 1 from cs.official_accounts o where o.profile_id = p_official)
          or (p_active and not cs.official_active(p_official))) then
    perform private.api_error(400, 'official_required', 'Izin bot_post wajib memilih akun resmi yang aktif');
  end if;
end;
$$;

create or replace function cs_api.integration_keys()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((
    select jsonb_agg(cs.integration_key_view(k.id) order by k.revoked_at nulls first, k.created_at desc)
    from private.integration_keys k), '[]');
end;
$$;

create or replace function cs_api.integration_key_create(
  p_name                  text,
  p_scopes                text[],
  p_official_account_id   uuid default null,
  p_allowed_cidrs         text[] default '{}',
  p_rate_limit_per_minute integer default 600
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_scopes   text[] := cs.integration_scopes(p_scopes);
  v_cidrs    cidr[] := cs.integration_cidrs(p_allowed_cidrs);
  v_official uuid := case when 'bot_post' = any (v_scopes) then p_official_account_id end;
  v_rate     integer := coalesce(p_rate_limit_per_minute, 600);
  v_secret   text;
  v_key      text;
  v_id       uuid;
  v_attempt  integer := 0;
begin
  perform cs.integration_check(p_name, v_scopes, v_official, v_rate, true);
  loop
    v_secret := translate(encode(extensions.gen_random_bytes(32), 'base64'), E'+/=\n', '-_');
    v_key := 'oik_' || v_secret;
    begin
      insert into private.integration_keys (name, prefix, key_hash, scopes, official_account_id, allowed_cidrs,
                                            rate_limit_per_minute, created_by)
      values (btrim(p_name), left(v_secret, 8), encode(sha256(convert_to(v_key, 'UTF8')), 'hex'), v_scopes,
              v_official, v_cidrs, v_rate, v_me)
      returning id into v_id;
      exit;
    exception when unique_violation then
      v_attempt := v_attempt + 1;
      if v_attempt >= 3 then
        raise;
      end if;
    end;
  end loop;
  perform cs.audit('integration.key_create', null, null, jsonb_build_object(
    'key_id', v_id, 'name', btrim(p_name), 'prefix', left(v_secret, 8), 'scopes', to_jsonb(v_scopes),
    'official_account', v_official, 'allowed_cidrs', to_jsonb(v_cidrs::text[]), 'rate_limit_per_minute', v_rate));
  return cs.integration_key_view(v_id) || jsonb_build_object('key', v_key);
end;
$$;

create or replace function cs_api.integration_key_update(
  p_id                    uuid,
  p_name                  text,
  p_scopes                text[],
  p_official_account_id   uuid default null,
  p_allowed_cidrs         text[] default '{}',
  p_rate_limit_per_minute integer default 600,
  p_enabled               boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_scopes   text[] := cs.integration_scopes(p_scopes);
  v_cidrs    cidr[] := cs.integration_cidrs(p_allowed_cidrs);
  v_official uuid := case when 'bot_post' = any (v_scopes) then p_official_account_id end;
  v_rate     integer := coalesce(p_rate_limit_per_minute, 600);
  v_enabled  boolean := coalesce(p_enabled, true);
  v_changes  jsonb := '{}';
  k          private.integration_keys;
begin
  select * into k from private.integration_keys where id = p_id for update;
  if not found then
    perform private.api_error(404, 'key_not_found', 'API key tidak ditemukan');
  end if;
  if k.revoked_at is not null then
    perform private.api_error(409, 'key_revoked', 'API key yang sudah dicabut tidak bisa diubah');
  end if;
  perform cs.integration_check(p_name, v_scopes, v_official, v_rate, v_enabled);

  if k.name <> btrim(p_name) then
    v_changes := v_changes || jsonb_build_object('name', jsonb_build_object('from', k.name, 'to', btrim(p_name)));
  end if;
  if k.scopes <> v_scopes then
    v_changes := v_changes || jsonb_build_object('scopes', jsonb_build_object('from', k.scopes, 'to', v_scopes));
  end if;
  if k.official_account_id is distinct from v_official then
    v_changes := v_changes || jsonb_build_object('official_account',
                                                 jsonb_build_object('from', k.official_account_id, 'to', v_official));
  end if;
  if k.allowed_cidrs <> v_cidrs then
    v_changes := v_changes || jsonb_build_object('allowed_cidrs',
                                                 jsonb_build_object('from', k.allowed_cidrs::text[], 'to', v_cidrs::text[]));
  end if;
  if k.rate_limit_per_minute <> v_rate then
    v_changes := v_changes || jsonb_build_object('rate_limit_per_minute',
                                                 jsonb_build_object('from', k.rate_limit_per_minute, 'to', v_rate));
  end if;
  if (k.disabled_at is null) <> v_enabled then
    v_changes := v_changes || jsonb_build_object('enabled', jsonb_build_object('from', k.disabled_at is null, 'to', v_enabled));
  end if;

  if v_changes <> '{}' then
    update private.integration_keys
       set name = btrim(p_name), scopes = v_scopes, official_account_id = v_official, allowed_cidrs = v_cidrs,
           rate_limit_per_minute = v_rate,
           disabled_at = case when v_enabled then null else coalesce(disabled_at, now()) end,
           updated_at = now()
     where id = k.id;
    perform cs.audit('integration.key_update', null, null,
                     jsonb_build_object('key_id', k.id, 'prefix', k.prefix, 'changes', v_changes));
  end if;
  return cs.integration_key_view(k.id);
end;
$$;

create or replace function cs_api.integration_key_revoke(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := btrim(coalesce(p_reason, ''));
  k        private.integration_keys;
begin
  if char_length(v_reason) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan pencabutan 5–500 karakter');
  end if;
  select * into k from private.integration_keys where id = p_id for update;
  if not found then
    perform private.api_error(404, 'key_not_found', 'API key tidak ditemukan');
  end if;
  if k.revoked_at is not null then
    return cs.integration_key_view(k.id);
  end if;
  update private.integration_keys
     set revoked_at = now(), revoked_by = v_me, revoke_reason = v_reason, updated_at = now()
   where id = k.id;
  perform cs.audit('integration.key_revoke', null, null,
                   jsonb_build_object('key_id', k.id, 'name', k.name, 'prefix', k.prefix, 'reason', v_reason));
  return cs.integration_key_view(k.id);
end;
$$;

create or replace function public.integration_authenticate(p_key_hash text, p_ip text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  k    private.integration_keys;
  v_ip inet;
begin
  if coalesce(p_key_hash, '') !~ '^[0-9a-f]{64}$' then
    return null;
  end if;
  select * into k from private.integration_keys
   where key_hash = p_key_hash and revoked_at is null and disabled_at is null;
  if not found then
    return null;
  end if;
  begin
    v_ip := nullif(btrim(coalesce(p_ip, '')), '')::inet;
  exception when invalid_text_representation then
    v_ip := null;
  end;
  return jsonb_build_object(
    'id', k.id, 'name', k.name, 'prefix', k.prefix, 'scopes', to_jsonb(k.scopes),
    'official_account_id', k.official_account_id,
    'rate_limit_per_minute', k.rate_limit_per_minute,
    'ip_allowed', cardinality(k.allowed_cidrs) = 0 or coalesce(v_ip <<= any (k.allowed_cidrs), false));
end;
$$;

create or replace function private.integration_key_for(p_key_id uuid, p_scope text, p_ip text)
returns private.integration_keys
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  k    private.integration_keys;
  v_ip inet;
begin
  select * into k from private.integration_keys
   where id = p_key_id and revoked_at is null and disabled_at is null;
  if not found then
    perform private.api_error(401, 'invalid_key', 'API key tidak dikenal, nonaktif, atau sudah dicabut');
  end if;
  if not p_scope = any (k.scopes) then
    perform private.api_error(403, 'scope_forbidden', format('API key ini tidak punya izin %s', p_scope));
  end if;
  if cardinality(k.allowed_cidrs) > 0 then
    begin
      v_ip := nullif(btrim(coalesce(p_ip, '')), '')::inet;
    exception when invalid_text_representation then
      v_ip := null;
    end;
    if v_ip is null or not v_ip <<= any (k.allowed_cidrs) then
      perform private.api_error(403, 'ip_not_allowed', 'Alamat IP pengirim tidak diizinkan untuk API key ini');
    end if;
  end if;
  return k;
end;
$$;

create or replace function private.integration_touch(p_key_id uuid, p_ip text, p_counts jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ip inet;
begin
  begin
    v_ip := nullif(btrim(coalesce(p_ip, '')), '')::inet;
  exception when invalid_text_representation then
    v_ip := null;
  end;
  insert into private.integration_daily as d (key_id, day, received, queued, devices, no_recipient, duplicate, invalid,
                                              posts, posts_rejected)
  values (p_key_id, private.integration_day(),
          coalesce((p_counts ->> 'received')::integer, 0), coalesce((p_counts ->> 'queued')::integer, 0),
          coalesce((p_counts ->> 'devices')::integer, 0), coalesce((p_counts ->> 'no_recipient')::integer, 0),
          coalesce((p_counts ->> 'duplicate')::integer, 0), coalesce((p_counts ->> 'invalid')::integer, 0),
          coalesce((p_counts ->> 'posts')::integer, 0), coalesce((p_counts ->> 'posts_rejected')::integer, 0))
  on conflict (key_id, day) do update
     set received = d.received + excluded.received, queued = d.queued + excluded.queued,
         devices = d.devices + excluded.devices, no_recipient = d.no_recipient + excluded.no_recipient,
         duplicate = d.duplicate + excluded.duplicate, invalid = d.invalid + excluded.invalid,
         posts = d.posts + excluded.posts, posts_rejected = d.posts_rejected + excluded.posts_rejected;
  update private.integration_keys
     set last_used_at = now(), last_used_ip = coalesce(v_ip, last_used_ip)
   where id = p_key_id
     and (last_used_at is null or last_used_at < now() - interval '1 minute'
          or last_used_ip is distinct from coalesce(v_ip, last_used_ip));
end;
$$;

create or replace function private.integration_text(p_value jsonb, p_max integer)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case jsonb_typeof(p_value)
    when 'string' then case when char_length(btrim(p_value #>> '{}')) between 1 and p_max
                            then to_jsonb(btrim(p_value #>> '{}')) end
    when 'object' then (
      select case when count(*) > 0 and bool_and(char_length(e.value #>> '{}') <= p_max)
                  then jsonb_object_agg(e.key, btrim(e.value #>> '{}')) end
      from jsonb_each(p_value) e
      where e.key in ('id', 'en') and jsonb_typeof(e.value) = 'string' and btrim(e.value #>> '{}') <> '')
  end;
$$;

create or replace function private.integration_notify_error(m jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(m) is distinct from 'object' then 'invalid_message'
    when jsonb_typeof(m -> 'id') is distinct from 'string' or (m ->> 'id') !~ '^[A-Za-z0-9._:-]{1,100}$'
      then 'invalid_id'
    when private.integration_cust_id(m -> 'cust_id') is null then 'invalid_cust_id'
    when m ? 'kind' and jsonb_typeof(m -> 'kind') <> 'null' and (jsonb_typeof(m -> 'kind') <> 'string'
                         or (m ->> 'kind') !~ '^olt\.[a-z0-9_]+(\.[a-z0-9_]+)*$' or char_length(m ->> 'kind') > 40)
      then 'invalid_kind'
    when private.integration_text(m -> 'title', 200) is null then 'invalid_title'
    when m ? 'body' and jsonb_typeof(m -> 'body') <> 'null' and private.integration_text(m -> 'body', 1000) is null
         and not (jsonb_typeof(m -> 'body') = 'string' and btrim(m ->> 'body') = '')
      then 'invalid_body'
    when m ? 'data' and jsonb_typeof(m -> 'data') <> 'null'
         and (jsonb_typeof(m -> 'data') <> 'object' or octet_length((m -> 'data')::text) > 2048)
      then 'invalid_data'
    when m ? 'ttl_seconds' and jsonb_typeof(m -> 'ttl_seconds') <> 'null'
         and (jsonb_typeof(m -> 'ttl_seconds') <> 'number' or (m ->> 'ttl_seconds') !~ '^[0-9]{1,8}$'
              or (m ->> 'ttl_seconds')::integer not between 60 and 2419200)
      then 'invalid_ttl'
    when m ? 'collapse_key' and jsonb_typeof(m -> 'collapse_key') <> 'null'
         and (jsonb_typeof(m -> 'collapse_key') <> 'string' or char_length(m ->> 'collapse_key') not between 1 and 64)
      then 'invalid_collapse_key'
    when m ? 'priority' and jsonb_typeof(m -> 'priority') <> 'null' and (m ->> 'priority') not in ('high', 'normal')
      then 'invalid_priority'
  end;
$$;

create or replace function public.integration_notify(p_key_id uuid, p_messages jsonb, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k          private.integration_keys := private.integration_key_for(p_key_id, 'notify', p_ip);
  v_days     integer := private.setting_num('integration.account_link_days', 30)::integer;
  v_ref      text := private.integration_ref(p_key_id, private.integration_day());
  v_results  jsonb := '[]';
  v_counts   jsonb;
  v_queued   integer := 0;
  v_none     integer := 0;
  v_dup      integer := 0;
  v_invalid  integer := 0;
  v_devices  integer := 0;
  m          jsonb;
  v_index    bigint;
  v_error    text;
  v_id       text;
  v_cust     text;
  v_kind     text;
  v_data     jsonb;
  v_options  jsonb;
  v_count    integer;
  v_profile  uuid;
  v_inserted integer;
begin
  if jsonb_typeof(p_messages) is distinct from 'array' or jsonb_array_length(p_messages) not between 1 and 500 then
    perform private.api_error(400, 'invalid_batch', 'messages harus array berisi 1–500 pesan');
  end if;

  for m, v_index in select e.value, e.ord - 1 from jsonb_array_elements(p_messages) with ordinality as e(value, ord) loop
    v_error := private.integration_notify_error(m);
    v_id := case when jsonb_typeof(m) = 'object' and jsonb_typeof(m -> 'id') = 'string' then left(m ->> 'id', 100) end;
    if v_error is not null then
      v_invalid := v_invalid + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'invalid', 'error', v_error);
      continue;
    end if;

    insert into private.integration_receipts (key_id, message_id) values (k.id, v_id) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      v_dup := v_dup + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'duplicate');
      continue;
    end if;

    v_cust := private.integration_cust_id(m -> 'cust_id');
    v_kind := coalesce(m ->> 'kind', 'olt.trade');
    v_data := case when jsonb_typeof(m -> 'data') = 'object' then m -> 'data' else '{}' end
              || jsonb_build_object('source', 'olt', 'message_id', v_id, 'cust_id', v_cust);
    v_options := jsonb_strip_nulls(jsonb_build_object(
      'ref', v_ref,
      'ttl_seconds', case when jsonb_typeof(m -> 'ttl_seconds') = 'number' then (m ->> 'ttl_seconds')::integer end,
      'collapse_key', case when jsonb_typeof(m -> 'collapse_key') = 'string' then m ->> 'collapse_key' end,
      'priority', case when jsonb_typeof(m -> 'priority') = 'string' then m ->> 'priority' end));
    v_count := 0;
    for v_profile in
      select l.profile_id
      from private.account_links l
      join public.profiles p on p.id = l.profile_id and p.deleted_at is null
      where l.cust_id = v_cust and l.seen_at > now() - make_interval(days => v_days)
      order by l.profile_id
    loop
      if coalesce(private.push_allowed(v_profile, v_kind), false) then
        v_count := v_count + private.push_enqueue(v_profile, v_kind, private.integration_text(m -> 'title', 200),
                                                  coalesce(private.integration_text(m -> 'body', 1000), '""'),
                                                  v_data, v_options);
      end if;
    end loop;

    update private.integration_receipts
       set status = case when v_count > 0 then 'queued' else 'no_recipient' end, devices = v_count
     where key_id = k.id and message_id = v_id;
    if v_count > 0 then
      v_queued := v_queued + 1;
      v_devices := v_devices + v_count;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'queued', 'devices', v_count);
    else
      v_none := v_none + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'no_recipient');
    end if;
  end loop;

  v_counts := jsonb_build_object('received', jsonb_array_length(p_messages), 'queued', v_queued, 'devices', v_devices,
                                 'no_recipient', v_none, 'duplicate', v_dup, 'invalid', v_invalid);
  perform private.integration_touch(k.id, p_ip, v_counts);
  return jsonb_build_object('results', v_results) || (v_counts - 'received');
end;
$$;

create or replace function public.integration_bot_post(p_key_id uuid, p_posts jsonb, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k          private.integration_keys := private.integration_key_for(p_key_id, 'bot_post', p_ip);
  v_cap      integer := private.setting_num('integration.bot_posts_per_hour', 30)::integer;
  v_used     integer;
  v_results  jsonb := '[]';
  v_posted   integer := 0;
  v_rejected integer := 0;
  v_dup      integer := 0;
  v_invalid  integer := 0;
  v_limited  integer := 0;
  m          jsonb;
  v_index    bigint;
  v_id       text;
  v_body     text;
  v_inserted integer;
  v_cp       uuid;
  v_post     uuid;
  v_status   text;
  c          cs.community_posts;
  v_state    text;
  v_code     text;
  v_detail   text;
begin
  if jsonb_typeof(p_posts) is distinct from 'array' or jsonb_array_length(p_posts) not between 1 and 50 then
    perform private.api_error(400, 'invalid_batch', 'posts harus array berisi 1–50 postingan');
  end if;
  if not cs.official_active(k.official_account_id) then
    perform private.api_error(409, 'official_inactive', 'Akun resmi untuk bot ini nonaktif');
  end if;
  select count(*) into v_used from private.integration_posts b
   where b.key_id = k.id and b.created_at > now() - interval '1 hour';

  for m, v_index in select e.value, e.ord - 1 from jsonb_array_elements(p_posts) with ordinality as e(value, ord) loop
    v_id := case when jsonb_typeof(m) = 'object' and jsonb_typeof(m -> 'id') = 'string' then left(m ->> 'id', 100) end;
    v_body := case when jsonb_typeof(m -> 'body') = 'string' then btrim(m ->> 'body') end;
    if coalesce(v_id, '') !~ '^[A-Za-z0-9._:-]{1,100}$' then
      v_invalid := v_invalid + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'invalid', 'error', 'invalid_id');
      continue;
    end if;
    if char_length(coalesce(v_body, '')) not between 1 and 2000 then
      v_invalid := v_invalid + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'invalid', 'error', 'invalid_body');
      continue;
    end if;

    select b.post_id into v_post from private.integration_posts b where b.key_id = k.id and b.message_id = v_id;
    if found then
      v_dup := v_dup + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'duplicate', 'post_id', v_post);
      continue;
    end if;
    if v_used >= v_cap then
      v_limited := v_limited + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'rate_limited');
      continue;
    end if;

    begin
      insert into private.integration_posts (key_id, message_id) values (k.id, v_id) on conflict do nothing;
      get diagnostics v_inserted = row_count;
      if v_inserted = 0 then
        select b.post_id into v_post from private.integration_posts b where b.key_id = k.id and b.message_id = v_id;
        v_dup := v_dup + 1;
        v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'duplicate', 'post_id', v_post);
        continue;
      end if;
      perform private.validate_text(v_body, 'post');
      perform private.apply_content_policy(v_body);
      insert into cs.community_posts (account_id, kind, body, status, created_by, submitted_at)
      values (k.official_account_id, 'post', v_body, 'draft', k.created_by, now())
      returning id into v_cp;
      c := cs.community_publish(v_cp);
      if c.status <> 'published' or c.post_id is null then
        perform private.api_error(422, 'publish_failed', 'Postingan gagal diterbitkan');
      end if;
      update private.integration_posts set community_post_id = v_cp, post_id = c.post_id
       where key_id = k.id and message_id = v_id;
      select p.moderation_status into v_status from public.posts p where p.id = c.post_id;
      v_used := v_used + 1;
      v_posted := v_posted + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'published',
                                                   'post_id', c.post_id, 'moderation_status', v_status);
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_code = message_text, v_detail = pg_exception_detail;
      if v_state !~ '^PT4' then
        raise;
      end if;
      v_rejected := v_rejected + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'rejected',
                                                   'error', v_code, 'message', v_detail);
    end;
  end loop;

  perform private.integration_touch(k.id, p_ip, jsonb_build_object(
    'posts', v_posted, 'posts_rejected', v_rejected, 'duplicate', v_dup, 'invalid', v_invalid));
  return jsonb_build_object('results', v_results, 'published', v_posted, 'rejected', v_rejected,
                            'duplicate', v_dup, 'invalid', v_invalid, 'rate_limited', v_limited);
end;
$$;

create or replace function cs_api.integration_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_days  integer := greatest(1, least(coalesce(p_days, 7), 90));
  v_from  date := private.integration_day() - (v_days - 1);
  v_link  integer := private.setting_num('integration.account_link_days', 30)::integer;
begin
  return jsonb_build_object(
    'days', v_days,
    'from', v_from,
    'keys', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', k.id, 'name', k.name, 'prefix', k.prefix,
               'status', case when k.revoked_at is not null then 'revoked'
                              when k.disabled_at is not null then 'disabled' else 'active' end,
               'last_used_at', k.last_used_at,
               'received', coalesce(d.received, 0), 'queued', coalesce(d.queued, 0),
               'devices', coalesce(d.devices, 0), 'no_recipient', coalesce(d.no_recipient, 0),
               'duplicate', coalesce(d.duplicate, 0), 'invalid', coalesce(d.invalid, 0),
               'posts', coalesce(d.posts, 0), 'posts_rejected', coalesce(d.posts_rejected, 0),
               'push', jsonb_build_object(
                 'sent', coalesce(s.sent, 0), 'failed', coalesce(s.failed, 0), 'invalid', coalesce(s.invalid, 0),
                 'expired', coalesce(s.expired, 0) + coalesce(s.cancelled, 0),
                 'pending', (select count(*) from private.push_queue q
                             where q.status = 'queued' and q.expires_at > now()
                               and q.ref like 'olt:' || k.id::text || ':%')))
             order by k.revoked_at nulls first, k.created_at desc)
      from private.integration_keys k
      left join lateral (
        select sum(x.received) as received, sum(x.queued) as queued, sum(x.devices) as devices,
               sum(x.no_recipient) as no_recipient, sum(x.duplicate) as duplicate, sum(x.invalid) as invalid,
               sum(x.posts) as posts, sum(x.posts_rejected) as posts_rejected
        from private.integration_daily x where x.key_id = k.id and x.day >= v_from) d on true
      left join lateral (
        select sum(r.sent) as sent, sum(r.failed) as failed, sum(r.invalid) as invalid, sum(r.expired) as expired,
               sum(r.cancelled) as cancelled
        from private.push_ref_stats r
        where r.ref in (select private.integration_ref(k.id, v_from + i) from generate_series(0, v_days - 1) i)) s on true
      where k.revoked_at is null or k.revoked_at > v_from or d.received is not null or d.posts is not null), '[]'),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', x.day, 'received', x.received, 'queued', x.queued,
                                          'no_recipient', x.no_recipient, 'posts', x.posts) order by x.day)
      from (select y.day, sum(y.received) as received, sum(y.queued) as queued, sum(y.no_recipient) as no_recipient,
                   sum(y.posts) as posts
            from private.integration_daily y where y.day >= v_from group by y.day) x), '[]'),
    'linked', (
      select jsonb_build_object('accounts', count(distinct l.cust_id), 'profiles', count(distinct l.profile_id))
      from private.account_links l
      where l.seen_at > now() - make_interval(days => v_link)));
end;
$$;

create or replace function private.integration_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_receipts integer;
  v_links    integer;
begin
  delete from private.integration_receipts
   where created_at < now() - make_interval(days => private.setting_num('integration.receipt_days', 7)::integer);
  get diagnostics v_receipts = row_count;
  delete from private.account_links
   where seen_at < now() - make_interval(days => private.setting_num('integration.account_link_days', 30)::integer);
  get diagnostics v_links = row_count;
  delete from private.integration_daily where day < private.integration_day() - 400;
  return jsonb_build_object('receipts', v_receipts, 'links', v_links);
end;
$$;

select cron.schedule('integration-maintenance', '23 * * * *', 'select private.integration_maintenance()');

revoke execute on function private.integration_cust_id(jsonb) from public;
revoke execute on function private.integration_day() from public;
revoke execute on function private.integration_ref(uuid, date) from public;
revoke execute on function private.account_links_forget() from public;
revoke execute on function private.account_links_export(uuid) from public;
revoke execute on function private.post_is_bot(uuid) from public;
revoke execute on function private.integration_key_for(uuid, text, text) from public;
revoke execute on function private.integration_touch(uuid, text, jsonb) from public;
revoke execute on function private.integration_text(jsonb, integer) from public;
revoke execute on function private.integration_notify_error(jsonb) from public;
revoke execute on function private.integration_maintenance() from public;
revoke execute on function cs.integration_key_view(uuid) from public;
revoke execute on function cs.integration_scopes(text[]) from public;
revoke execute on function cs.integration_cidrs(text[]) from public;
revoke execute on function cs.integration_check(text, text[], uuid, integer, boolean) from public;

revoke execute on function public.set_olt_account_links(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.integration_authenticate(text, text) from public, anon, authenticated;
revoke execute on function public.integration_notify(uuid, jsonb, text) from public, anon, authenticated;
revoke execute on function public.integration_bot_post(uuid, jsonb, text) from public, anon, authenticated;
revoke execute on function cs_api.integration_keys() from public;
revoke execute on function cs_api.integration_key_create(text, text[], uuid, text[], integer) from public;
revoke execute on function cs_api.integration_key_update(uuid, text, text[], uuid, text[], integer, boolean) from public;
revoke execute on function cs_api.integration_key_revoke(uuid, text) from public;
revoke execute on function cs_api.integration_stats(integer) from public;

grant execute on function public.set_olt_account_links(uuid, jsonb) to service_role;
grant execute on function public.integration_authenticate(text, text) to service_role;
grant execute on function public.integration_notify(uuid, jsonb, text) to service_role;
grant execute on function public.integration_bot_post(uuid, jsonb, text) to service_role;
grant execute on function cs_api.integration_keys() to authenticated;
grant execute on function cs_api.integration_key_create(text, text[], uuid, text[], integer) to authenticated;
grant execute on function cs_api.integration_key_update(uuid, text, text[], uuid, text[], integer, boolean) to authenticated;
grant execute on function cs_api.integration_key_revoke(uuid, text) to authenticated;
grant execute on function cs_api.integration_stats(integer) to authenticated;
