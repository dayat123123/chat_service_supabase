create function private.stock_code_format(p_code text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select char_length(p_code) between 2 and 24 and p_code ~ '^[A-Z][A-Z0-9]{0,19}(-[A-Z0-9]{1,19})*$';
$$;

create table private.market_instruments (
  code         text primary key check (private.stock_code_format(code)),
  kind         text not null default 'index' check (kind in ('index')),
  name         text not null check (char_length(btrim(name)) between 1 and 80),
  description  text check (char_length(description) <= 300),
  position     integer not null default 0,
  enabled      boolean not null default true,
  room_enabled boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid
);
alter table private.market_instruments enable row level security;

create table private.market_instrument_aliases (
  alias text primary key check (private.stock_code_format(alias)),
  code  text not null references private.market_instruments(code) on delete cascade on update cascade
);
create index market_instrument_aliases_code_idx on private.market_instrument_aliases (code);
alter table private.market_instrument_aliases enable row level security;

create function private.stock_code(p_code text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select a.code from private.market_instrument_aliases a where a.alias = s.v),
    case when s.v ~ '^[A-Z][A-Z0-9]{1,11}$'
           or exists (select 1 from private.market_instruments i where i.code = s.v) then s.v end)
  from (select upper(ltrim(btrim(coalesce(p_code, '')), '$')) as v) s;
$$;

create function private.resolve_cashtag(p_token text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_token text := upper(coalesce(p_token, ''));
  v_code  text;
begin
  loop
    v_code := private.stock_code(v_token);
    if v_code is not null then
      return v_code;
    end if;
    if strpos(v_token, '-') = 0 then
      return null;
    end if;
    v_token := regexp_replace(v_token, '-[^-]*$', '');
  end loop;
end;
$$;

create or replace function private.extract_cashtags(p_text text)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(s.code order by s.first_pos), '{}')
  from (
    select r.code, min(t.ord) as first_pos
    from regexp_matches(coalesce(p_text, ''),
                        '(?<![A-Za-z0-9_$])\$([A-Za-z][A-Za-z0-9]{0,19}(?:-[A-Za-z0-9]{1,19})*)(?![A-Za-z0-9_])', 'g')
         with ordinality as t(m, ord)
    cross join lateral (select private.resolve_cashtag(t.m[1]) as code) r
    where r.code is not null
    group by r.code
  ) s;
$$;

create function private.retag_posts(p_tokens text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_patterns text[] := array(
    select '%$' || upper(btrim(t)) || '%'
    from unnest(coalesce(p_tokens, '{}')) t
    where btrim(coalesce(t, '')) <> '');
  v_codes    text[];
  v_n        integer := 0;
  r          record;
begin
  if cardinality(v_patterns) = 0 then
    return 0;
  end if;
  for r in
    select p.id, p.body, p.created_at
    from public.posts p
    where p.deleted_at is null and p.body ilike any (v_patterns)
  loop
    v_codes := (private.extract_cashtags(r.body))[1:10];
    delete from public.post_stocks where post_id = r.id and stock_code <> all (v_codes);
    insert into public.post_stocks (post_id, stock_code, post_created_at)
    select r.id, c.code, r.created_at from unnest(v_codes) as c(code)
    on conflict do nothing;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

create function private.merge_stock_code(p_from text, p_to text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_from is null or p_to is null or p_from = p_to then
    return;
  end if;
  insert into public.stock_watchers (user_id, stock_code, created_at)
  select w.user_id, p_to, w.created_at from public.stock_watchers w where w.stock_code = p_from
  on conflict do nothing;
  delete from public.stock_watchers where stock_code = p_from;
  insert into public.muted_stocks (user_id, stock_code, created_at)
  select m.user_id, p_to, m.created_at from public.muted_stocks m where m.stock_code = p_from
  on conflict do nothing;
  delete from public.muted_stocks where stock_code = p_from;
  if not exists (select 1 from public.chat_rooms r where r.type = 'stock' and r.stock_code = p_to) then
    update public.chat_rooms set stock_code = p_to, name = p_to where type = 'stock' and stock_code = p_from;
  end if;
end;
$$;

create function private.canonical_stock_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := private.stock_code(new.stock_code);
begin
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  new.stock_code := v_code;
  return new;
end;
$$;

alter table public.post_stocks drop constraint post_stocks_code_format;
alter table public.stock_watchers drop constraint stock_watchers_code_format;
alter table public.muted_stocks drop constraint muted_stocks_code_format;
alter table public.chat_rooms drop constraint chat_rooms_stock_code_format;
alter table private.stock_codes drop constraint stock_codes_code_check;
alter table cs.manipulation_alerts drop constraint manipulation_alerts_stock;
alter table cs.community_posts drop constraint community_posts_pin_stock_check;
alter table cs.community_campaigns drop constraint community_campaigns_audience_stock_check;

alter table public.post_stocks add constraint post_stocks_code_format check (private.stock_code_format(stock_code));
alter table public.stock_watchers add constraint stock_watchers_code_format check (private.stock_code_format(stock_code));
alter table public.muted_stocks add constraint muted_stocks_code_format check (private.stock_code_format(stock_code));
alter table public.chat_rooms add constraint chat_rooms_stock_code_format check (private.stock_code_format(stock_code));
alter table private.stock_codes add constraint stock_codes_code_check check (private.stock_code_format(code));
alter table cs.manipulation_alerts add constraint manipulation_alerts_stock check (private.stock_code_format(stock));
alter table cs.community_posts add constraint community_posts_pin_stock_check check (private.stock_code_format(pin_stock));
alter table cs.community_campaigns add constraint community_campaigns_audience_stock_check
  check (private.stock_code_format(audience_stock));

create trigger stock_watchers_05_canonical_code
  before insert or update of stock_code on public.stock_watchers
  for each row execute function private.canonical_stock_code();
create trigger muted_stocks_05_canonical_code
  before insert or update of stock_code on public.muted_stocks
  for each row execute function private.canonical_stock_code();

create or replace function private.stock_room_id(p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.id from public.chat_rooms r
  where r.type = 'stock'
    and r.stock_code = coalesce(private.stock_code(p_code), upper(btrim(coalesce(p_code, ''))));
$$;

create function private.stock_room_enabled(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select i.room_enabled from private.market_instruments i where i.code = p_code), true);
$$;

create or replace function private.feed_stock_codes(p_codes text[])
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array(
    select distinct coalesce(private.stock_code(c), upper(ltrim(btrim(c), '$')))
    from unnest(coalesce(p_codes, '{}')) c
    where btrim(coalesce(c, '')) <> '');
$$;

create or replace function cs.community_audience_check(p_audience text, p_stock text, p_days integer, p_platform text,
                                                       p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_aud      text := lower(btrim(coalesce(p_audience, 'all')));
  v_stock    text := private.stock_code(nullif(btrim(coalesce(p_stock, '')), ''));
  v_platform text := nullif(lower(btrim(coalesce(p_platform, ''))), '');
begin
  if v_aud not in ('all', 'stock', 'new_users', 'inactive', 'platform', 'followers') then
    perform private.api_error(400, 'invalid_audience',
      'Penerima: all, stock, new_users, inactive, platform, atau followers');
  end if;
  if v_aud = 'stock' and v_stock is null then
    perform private.api_error(400, 'invalid_audience', 'Penerima: semua pengguna atau pemantau saham/indeks dengan kode valid');
  end if;
  if v_aud in ('new_users', 'inactive') and coalesce(p_days, 0) not between 1 and 365 then
    perform private.api_error(400, 'invalid_audience', 'Jumlah hari penerima 1–365');
  end if;
  if v_aud = 'platform' and (v_platform is null or v_platform <> all (private.client_platforms())) then
    perform private.api_error(400, 'invalid_audience', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_aud = 'followers' and (p_account is null or not cs.official_active(p_account)) then
    perform private.api_error(400, 'invalid_audience', 'Pilih akun resmi aktif untuk penerima pengikut');
  end if;
  return jsonb_build_object(
    'audience', v_aud,
    'stock', case when v_aud = 'stock' then v_stock end,
    'days', case when v_aud in ('new_users', 'inactive') then p_days end,
    'platform', case when v_aud = 'platform' then v_platform end,
    'account', case when v_aud = 'followers' then p_account end);
end;
$$;

create or replace function cs.ensure_stock_room(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := private.stock_code(p_code);
  v_room uuid;
begin
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  v_room := private.stock_room_id(v_code);
  if v_room is null then
    insert into public.chat_rooms (type, name, stock_code) values ('stock', v_code, v_code)
    on conflict (stock_code) where type = 'stock' do nothing
    returning id into v_room;
    v_room := coalesce(v_room, private.stock_room_id(v_code));
  end if;
  return v_room;
end;
$$;

create or replace function cs_api.community_pin_post(p_id uuid, p_scope text, p_stock text default null,
                                                      p_until timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.publish}');
  v_scope text := nullif(btrim(coalesce(p_scope, '')), '');
  v_stock text := private.stock_code(nullif(btrim(coalesce(p_stock, '')), ''));
  c       cs.community_posts;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if not found or c.status <> 'published'
     or exists (select 1 from public.posts p where p.id = c.post_id and p.deleted_at is not null) then
    perform private.api_error(409, 'invalid_status', 'Hanya postingan yang sudah terbit yang bisa disematkan');
  end if;
  if v_scope is null then
    update cs.community_posts set unpinned_at = now(), updated_at = now(), version = version + 1 where id = c.id;
    perform cs.audit('community.post_unpin', null, null, jsonb_build_object('post', c.id));
    return cs.community_post_view(c.id);
  end if;
  if v_scope not in ('global', 'stock') or (v_scope = 'stock' and v_stock is null) then
    perform private.api_error(400, 'invalid_pin', 'Sematkan di stream umum atau stream saham/indeks dengan kode valid');
  end if;
  if p_until is not null and p_until <= now() then
    perform private.api_error(400, 'invalid_pin_until', 'Batas sematan harus di masa depan');
  end if;
  update cs.community_posts
     set pin_scope = v_scope, pin_stock = case when v_scope = 'stock' then v_stock end, pin_until = p_until,
         unpinned_at = null, updated_at = now(), version = version + 1
   where id = c.id;
  perform cs.audit('community.post_pin', null, null,
                   jsonb_build_object('post', c.id, 'scope', v_scope, 'stock', v_stock, 'until', p_until));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs_api.community_room_moderators(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_code text := private.stock_code(p_code);
begin
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  return cs.room_moderators_view(private.stock_room_id(v_code), v_code);
end;
$$;

create or replace function cs_api.community_save_post(
  p_id          uuid,
  p_account_id  uuid,
  p_kind        text,
  p_title       text,
  p_body        text,
  p_attachments jsonb default '[]',
  p_pin_scope   text default null,
  p_pin_stock   text default null,
  p_pin_until   timestamptz default null,
  p_notify      boolean default false,
  p_publish_at  timestamptz default null,
  p_version     integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.post}');
  v_kind   text := coalesce(p_kind, 'post');
  v_title  text := nullif(btrim(coalesce(p_title, '')), '');
  v_body   text := btrim(coalesce(p_body, ''));
  v_scope  text := nullif(btrim(coalesce(p_pin_scope, '')), '');
  v_stock  text := private.stock_code(nullif(btrim(coalesce(p_pin_stock, '')), ''));
  v_media  jsonb := coalesce(p_attachments, '[]');
  v_at     timestamptz := case when p_publish_at > now() then p_publish_at end;
  c        cs.community_posts;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if v_kind not in ('post', 'announcement') then
    perform private.api_error(400, 'invalid_kind', 'Jenis harus postingan atau pengumuman');
  end if;
  if v_kind = 'announcement' then
    if char_length(coalesce(v_title, '')) not between 3 and 80 then
      perform private.api_error(400, 'invalid_title', 'Judul pengumuman 3–80 karakter');
    end if;
    v_scope := coalesce(v_scope, 'global');
  else
    v_title := null;
  end if;
  if char_length(v_body) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Isi postingan 1–2000 karakter');
  end if;
  perform private.validate_text(v_body, 'post');
  perform private.apply_content_policy(v_body);
  perform private.validate_attachments(v_media, 'posts/' || p_account_id || '/');
  if v_scope is not null and v_scope not in ('global', 'stock') then
    perform private.api_error(400, 'invalid_pin', 'Sematkan di stream umum atau stream saham');
  end if;
  if v_scope = 'stock' and v_stock is null then
    perform private.api_error(400, 'invalid_stock', 'Kode saham atau indeks tidak valid');
  end if;
  if v_scope is distinct from 'stock' then
    v_stock := null;
  end if;
  if v_scope is null and p_pin_until is not null then
    perform private.api_error(400, 'invalid_pin', 'Batas sematan hanya untuk postingan yang disematkan');
  end if;
  if p_pin_until is not null and p_pin_until <= coalesce(v_at, now()) then
    perform private.api_error(400, 'invalid_pin_until', 'Batas sematan harus setelah waktu terbit');
  end if;

  if p_id is null then
    insert into cs.community_posts (account_id, kind, title, body, attachments, pin_scope, pin_stock, pin_until,
                                    notify, publish_at, created_by)
    values (p_account_id, v_kind, v_title, v_body, v_media, v_scope, v_stock, p_pin_until,
            coalesce(p_notify, false), v_at, v_me)
    returning * into c;
  else
    select * into c from cs.community_posts where id = p_id for update;
    if not found then
      perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
    end if;
    if c.created_by <> v_me then
      perform private.api_error(403, 'not_post_owner', 'Hanya pembuat yang bisa mengubah draf ini');
    end if;
    if c.status not in ('draft', 'rejected', 'failed') then
      perform private.api_error(409, 'invalid_status', 'Postingan ini tidak bisa diubah lagi');
    end if;
    perform cs.check_version(c.version, p_version);
    update cs.community_posts
       set account_id = p_account_id, kind = v_kind, title = v_title, body = v_body, attachments = v_media,
           pin_scope = v_scope, pin_stock = v_stock, pin_until = p_pin_until, notify = coalesce(p_notify, false),
           publish_at = v_at, status = 'draft', error = null, updated_at = now(), version = version + 1
     where id = c.id
    returning * into c;
  end if;
  perform cs.audit('community.post_save', null, null, jsonb_build_object('post', c.id, 'kind', c.kind));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function private.analytics_props(p_props jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e.key, case when e.key = 'stock_code' then to_jsonb(upper(e.value #>> '{}'))
                                               else e.value end), '{}')
  from jsonb_each(case when jsonb_typeof(p_props) = 'object' then p_props else '{}'::jsonb end) e
  where case
    when e.key = 'stock_code' then jsonb_typeof(e.value) = 'string'
                                   and private.stock_code_format(upper(e.value #>> '{}'))
    when e.key in ('post_id', 'room_id', 'target_id', 'notification_id') then
      jsonb_typeof(e.value) = 'string'
      and (e.value #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    when e.key = 'hashtag' then jsonb_typeof(e.value) = 'string' and (e.value #>> '{}') ~ '^[a-z0-9_]{2,50}$'
    when e.key = 'source' then (e.value #>> '{}') = any (array['feed', 'post', 'comment', 'chat', 'search', 'profile',
                                 'notification', 'stock', 'hashtag', 'trending', 'push', 'deep_link', 'share', 'other'])
                               and jsonb_typeof(e.value) = 'string'
    when e.key = 'scope' then (e.value #>> '{}') = any (array['global', 'following', 'stock', 'user', 'hashtag',
                                 'bookmarks', 'trending']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'type' then (e.value #>> '{}') = any (array['all', 'posts', 'users', 'stocks', 'hashtags', 'direct',
                                 'group', 'stock', 'support', 'text', 'image', 'post']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'side' then (e.value #>> '{}') = any (array['buy', 'sell']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'interval' then (e.value #>> '{}') = any (array['intraday', '1d', '1w', '1m', '3m', '6m', '1y', '5y',
                                 'all']) and jsonb_typeof(e.value) = 'string'
    when e.key in ('result_count', 'position', 'query_length', 'duration_ms') then
      jsonb_typeof(e.value) = 'number' and (e.value #>> '{}') ~ '^[0-9]{1,9}$'
    when e.key in ('has_attachment', 'has_poll', 'is_reply') then jsonb_typeof(e.value) = 'boolean'
    else false
  end;
$$;

create or replace function private.integration_target(p_target jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_keys  text[];
  v_cust  text;
  v_stock text;
begin
  if jsonb_typeof(p_target) is distinct from 'object' then
    return null;
  end if;
  select array_agg(k order by k) into v_keys from jsonb_object_keys(p_target) k;
  if v_keys = array['cust_id'] then
    v_cust := private.integration_cust_id(p_target -> 'cust_id');
    return case when v_cust is not null then jsonb_build_object('cust_id', v_cust) end;
  end if;
  if v_keys = array['olt_user_ids'] then
    if jsonb_typeof(p_target -> 'olt_user_ids') <> 'array'
       or jsonb_array_length(p_target -> 'olt_user_ids') not between 1 and 500
       or exists (select 1 from jsonb_array_elements(p_target -> 'olt_user_ids') e
                  where jsonb_typeof(e.value) not in ('string', 'number')
                     or btrim(e.value #>> '{}') !~ '^[A-Za-z0-9._-]{1,64}$') then
      return null;
    end if;
    return jsonb_build_object('olt_user_ids', (select jsonb_agg(distinct btrim(e.value #>> '{}'))
                                               from jsonb_array_elements(p_target -> 'olt_user_ids') e));
  end if;
  if v_keys = array['audience'] and p_target -> 'audience' = '"all"' then
    return jsonb_build_object('audience', 'all');
  end if;
  if v_keys = array['audience', 'stock'] and p_target -> 'audience' = '"stock_watchers"'
     and jsonb_typeof(p_target -> 'stock') = 'string' then
    v_stock := private.stock_code(p_target ->> 'stock');
    return case when v_stock is not null
                then jsonb_build_object('audience', 'stock_watchers', 'stock', v_stock) end;
  end if;
  return null;
end;
$$;

create or replace function private.validate_stock_cards(p_items jsonb, p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_codes text[];
begin
  if jsonb_array_length(coalesce(p_items, '[]')) = 0 then
    return '[]';
  end if;
  if exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(400, 'share_not_allowed', 'Kartu saham tidak bisa dikirim ke chat CS');
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) e
             where jsonb_typeof(e.value -> 'code') is distinct from 'string'
                or private.stock_code(e.value ->> 'code') is null) then
    perform private.api_error(400, 'invalid_attachments', 'Kode saham atau indeks tidak valid');
  end if;
  select array_agg(s.code order by s.ord) into v_codes
  from (select private.stock_code(e.value ->> 'code') as code, min(e.ordinality) as ord
        from jsonb_array_elements(p_items) with ordinality e
        group by private.stock_code(e.value ->> 'code')) s;
  if cardinality(v_codes) > 3 then
    perform private.api_error(400, 'invalid_attachments', 'Maksimal 3 kartu saham per pesan');
  end if;
  return (select jsonb_agg(jsonb_build_object('type', 'stock', 'code', u.code) order by u.ord)
          from unnest(v_codes) with ordinality as u(code, ord));
end;
$$;

create or replace function public.get_stock(p_code text)
returns table (code text, watcher_count integer, watching boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select c.code,
         (select count(*)::integer from public.stock_watchers w where w.stock_code = c.code),
         exists (select 1 from public.stock_watchers w where w.stock_code = c.code and w.user_id = auth.uid())
  from (select private.stock_code(p_code) as code) c
  where c.code is not null;
$$;

create or replace function public.get_stock_room_state(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code text := private.stock_code(p_code);
  v_room uuid;
  v_busy timestamptz;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  v_room := private.stock_room_id(v_code);
  if v_room is null then
    v_busy := private.busy_window_end(now());
    return jsonb_build_object(
      'stock_code', v_code, 'room_id', null, 'room_enabled', private.stock_room_enabled(v_code),
      'slow_mode', jsonb_build_object(
        'seconds', case when v_busy is null then 0 else private.setting_num('rooms.busy_slow_mode', 10)::integer end,
        'until', v_busy, 'source', case when v_busy is not null then 'schedule' end),
      'wait_seconds', 0, 'pinned_message', null, 'pinned_at', null,
      'moderators', '[]'::jsonb, 'is_moderator', false, 'muted_until', null);
  end if;
  return jsonb_build_object('stock_code', v_code, 'room_enabled', private.stock_room_enabled(v_code))
      || private.stock_room_state(v_room, auth.uid());
end;
$$;

create or replace function public.get_stock_sentiment(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code   text := private.stock_code(p_code);
  v_result jsonb := '{}';
  v_window text;
  r        record;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;

  foreach v_window in array array['24h', '7d'] loop
    select coalesce(sum(b.posts), 0)::integer as posts,
           coalesce(sum(b.bullish), 0)::integer as bullish,
           coalesce(sum(b.bearish), 0)::integer as bearish,
           coalesce(sum(b.neutral), 0)::integer as neutral,
           coalesce(sum(b.w_bullish), 0) as w_bullish,
           coalesce(sum(b.w_bearish), 0) as w_bearish,
           coalesce(sum(b.w_neutral), 0) as w_neutral
      into r
    from private.stock_mention_buckets b
    where b.stock_code = v_code
      and b.bucket >= now() - case v_window when '24h' then interval '24 hours' else interval '7 days' end;

    v_result := v_result || jsonb_build_object(v_window, jsonb_build_object(
      'posts', r.posts, 'bullish', r.bullish, 'bearish', r.bearish, 'neutral', r.neutral,
      'unlabeled', r.posts - r.bullish - r.bearish - r.neutral,
      'bullish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_bullish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
      'bearish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_bearish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
      'neutral_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_neutral / (r.w_bullish + r.w_bearish + r.w_neutral)) end));
  end loop;

  return jsonb_build_object('code', v_code)
      || v_result
      || jsonb_build_object('updated_at', (select s.refreshed_at from private.trending_state s where s.singleton));
end;
$$;

create or replace function public.get_stock_stats(p_codes text[])
returns table (code text, posts_today integer, bullish_pct integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_codes text[];
  v_today timestamptz := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_codes := array(
    select distinct private.stock_code(c)
    from unnest(coalesce(p_codes, '{}')) c
    where private.stock_code(c) is not null);
  if cardinality(v_codes) > private.setting_num('stock_stats.max_codes', 50) then
    perform private.api_error(400, 'too_many_stocks', 'Terlalu banyak kode saham');
  end if;

  return query
  select c.code,
         coalesce(sum(b.posts), 0)::integer,
         case when coalesce(sum(b.w_bullish + b.w_bearish + b.w_neutral), 0) > 0
              then round(100 * sum(b.w_bullish) / sum(b.w_bullish + b.w_bearish + b.w_neutral))::integer end
  from unnest(v_codes) as c(code)
  left join private.stock_mention_buckets b on b.stock_code = c.code and b.bucket >= v_today
  group by c.code
  order by c.code;
end;
$$;

create or replace function public.join_stock_room(p_stock_code text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_code text := private.stock_code(p_stock_code);
  v_room uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  if not private.stock_room_enabled(v_code) then
    perform private.api_error(403, 'room_disabled', 'Room diskusi untuk kode ini sedang ditutup');
  end if;

  select id into v_room from public.chat_rooms where type = 'stock' and stock_code = v_code;
  if v_room is null then
    perform private.consume_rate_limit(auth.uid(), 'stock_room_create');
    insert into public.chat_rooms (type, name, stock_code, created_by)
    values ('stock', v_code, v_code, auth.uid())
    on conflict (stock_code) where type = 'stock' do nothing
    returning id into v_room;
    if v_room is null then
      select id into v_room from public.chat_rooms where type = 'stock' and stock_code = v_code;
    end if;
  end if;

  insert into public.chat_members (room_id, user_id) values (v_room, auth.uid())
  on conflict do nothing;
  return v_room;
end;
$$;

create or replace function public.save_post_draft(p_client_draft_id uuid, p_body text default '',
                                                  p_sentiment text default null, p_stocks text[] default '{}',
                                                  p_attachments jsonb default '[]', p_poll jsonb default null,
                                                  p_base_updated_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_body   text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_att    jsonb := coalesce(p_attachments, '[]');
  v_poll   jsonb := case when jsonb_typeof(p_poll) = 'null' then null else p_poll end;
  v_stocks text[];
  v_old    public.post_drafts;
  v_new    public.post_drafts;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_client_draft_id is null then
    perform private.api_error(400, 'invalid_draft', 'client_draft_id wajib diisi');
  end if;
  perform private.consume_rate_limit(v_uid, 'post_draft');
  if char_length(v_body) > 2000 then
    perform private.api_error(400, 'body_too_long', 'Draf maksimal 2000 karakter');
  end if;
  if p_sentiment is not null and p_sentiment not in ('bullish', 'bearish', 'neutral') then
    perform private.api_error(400, 'invalid_sentiment', 'Sentimen: bullish, bearish, atau neutral');
  end if;
  if exists (select 1 from unnest(coalesce(p_stocks, '{}')) x
             where btrim(coalesce(x, '')) <> '' and private.stock_code(x) is null) then
    perform private.api_error(400, 'invalid_stocks', 'Maksimal 10 kode saham dengan format valid');
  end if;
  select coalesce(array_agg(s.code order by s.ord), '{}') into v_stocks
  from (select private.stock_code(x) as code, min(o) as ord
        from unnest(coalesce(p_stocks, '{}')) with ordinality as u(x, o)
        where btrim(coalesce(x, '')) <> ''
        group by private.stock_code(x)) s;
  if cardinality(v_stocks) > 10 then
    perform private.api_error(400, 'invalid_stocks', 'Maksimal 10 kode saham dengan format valid');
  end if;
  perform private.validate_attachments(v_att, 'posts/' || v_uid || '/');
  if v_poll is not null and (jsonb_typeof(v_poll) <> 'object' or octet_length(v_poll::text) > 4000) then
    perform private.api_error(400, 'invalid_poll', 'Polling draf harus berupa objek maksimal 4000 byte');
  end if;
  if v_body = '' and jsonb_array_length(v_att) = 0 and v_poll is null and cardinality(v_stocks) = 0 then
    perform private.api_error(400, 'empty_draft', 'Draf kosong tidak disimpan');
  end if;

  select * into v_old from public.post_drafts d
  where d.user_id = v_uid and d.client_draft_id = p_client_draft_id
  for update;
  if v_old.id is null then
    if (select count(*) from public.post_drafts d where d.user_id = v_uid)
       >= private.setting_num('drafts.max_per_user', 20) then
      perform private.api_error(409, 'draft_limit', 'Maksimal 20 draf. Hapus draf lama terlebih dahulu');
    end if;
    insert into public.post_drafts (user_id, client_draft_id, body, sentiment, stocks, attachments, poll)
    values (v_uid, p_client_draft_id, v_body, p_sentiment, v_stocks, v_att, v_poll)
    on conflict (user_id, client_draft_id) do update
      set body = excluded.body, sentiment = excluded.sentiment, stocks = excluded.stocks,
          attachments = excluded.attachments, poll = excluded.poll, updated_at = clock_timestamp()
    returning * into v_new;
  else
    if p_base_updated_at is not null and v_old.updated_at > p_base_updated_at then
      perform private.api_error(409, 'draft_conflict', 'Draf sudah diubah di perangkat lain. Muat ulang draf');
    end if;
    update public.post_drafts
       set body = v_body, sentiment = p_sentiment, stocks = v_stocks, attachments = v_att, poll = v_poll,
           updated_at = clock_timestamp()
     where id = v_old.id
    returning * into v_new;
  end if;
  return private.post_draft_view(v_new);
end;
$$;

create or replace function private.search_stocks(p_uid uuid, p_query text, p_offset integer, p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query  text := btrim(coalesce(p_query, ''));
  v_prefix text := upper(ltrim(btrim(coalesce(p_query, '')), '$'));
  v_code   boolean;
  v_name   boolean;
  v_rows   jsonb;
begin
  v_code := v_prefix ~ '^[A-Z][A-Z0-9-]{0,23}$';
  v_name := char_length(v_query) between 2 and 80;
  if not v_code and not v_name then
    return jsonb_build_object('items', '[]'::jsonb, 'next_cursor', null);
  end if;

  select coalesce(jsonb_agg(r.item order by r.n), '[]') into v_rows
  from (
    select jsonb_build_object('code', s.code, 'posts_7d', s.posts_7d, 'watcher_count', s.watchers,
                              'is_watching', s.watching, 'kind', i.kind, 'name', i.name) as item,
           row_number() over (order by (s.code = v_prefix) desc, (i.code is not null) desc, s.posts_7d desc,
                                       s.watchers desc, s.code) as n
    from (
      select c.code,
             (select count(*)::integer from public.post_stocks ps
              where ps.stock_code = c.code and ps.post_created_at > now() - interval '7 days') as posts_7d,
             (select count(*)::integer from public.stock_watchers w where w.stock_code = c.code) as watchers,
             exists (select 1 from public.stock_watchers w where w.stock_code = c.code and w.user_id = p_uid) as watching
      from (
        select sc.code::text as code from private.stock_codes sc
        where v_code and sc.code like v_prefix || '%'
          and not exists (select 1 from private.market_instruments d where d.code = sc.code::text and not d.enabled)
        union
        select mi.code from private.market_instruments mi
        where mi.enabled
          and ((v_code and mi.code like v_prefix || '%')
               or (v_name and mi.name ilike '%' || v_query || '%')
               or (v_code and exists (select 1 from private.market_instrument_aliases a
                                      where a.code = mi.code and a.alias like v_prefix || '%')))
      ) c
    ) s
    left join private.market_instruments i on i.code = s.code
    order by n
    offset p_offset
    limit p_limit + 1
  ) r;

  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(e.value order by e.ordinality)
                       from jsonb_array_elements(v_rows) with ordinality e
                       where e.ordinality <= p_limit), '[]'),
    'next_cursor', case when jsonb_array_length(v_rows) > p_limit then 'o:' || (p_offset + p_limit) end);
end;
$$;

create function public.get_market_instruments()
returns table (code text, kind text, name text, description text, aliases text[], "position" integer,
               room_enabled boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return query
  select i.code, i.kind, i.name, i.description,
         coalesce((select array_agg(a.alias order by a.alias) from private.market_instrument_aliases a
                   where a.code = i.code), '{}'),
         i.position, i.room_enabled
  from private.market_instruments i
  where i.enabled
  order by i.position, i.code;
end;
$$;

create function cs.instrument_usage(p_code text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'code', p_code,
    'posts', (select count(*)::integer from public.post_stocks ps where ps.stock_code = p_code),
    'posts_7d', (select count(*)::integer from public.post_stocks ps
                 where ps.stock_code = p_code and ps.post_created_at > now() - interval '7 days'),
    'watchers', (select count(*)::integer from public.stock_watchers w where w.stock_code = p_code),
    'room_id', private.stock_room_id(p_code),
    'room_members', (select count(*)::integer from public.chat_members m
                     where m.room_id = private.stock_room_id(p_code)));
$$;

create function cs.instrument_view(i private.market_instruments)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'code', i.code, 'kind', i.kind, 'name', i.name, 'description', i.description,
    'aliases', coalesce((select jsonb_agg(a.alias order by a.alias) from private.market_instrument_aliases a
                         where a.code = i.code), '[]'),
    'position', i.position, 'enabled', i.enabled, 'room_enabled', i.room_enabled,
    'created_at', i.created_at, 'updated_at', i.updated_at, 'updated_by', cs.staff_ref(i.updated_by),
    'usage', cs.instrument_usage(i.code));
$$;

create function cs_api.community_instruments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  return coalesce((select jsonb_agg(cs.instrument_view(i) order by i.position, i.code)
                   from private.market_instruments i), '[]');
end;
$$;

create function cs_api.community_instrument_check(p_code text, p_aliases text[] default '{}')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_code text := upper(ltrim(btrim(coalesce(p_code, '')), '$'));
begin
  return coalesce((
    select jsonb_agg(cs.instrument_usage(t.token) || jsonb_build_object(
             'role', t.role,
             'valid', private.stock_code_format(t.token),
             'instrument', (select i.code from private.market_instruments i where i.code = t.token),
             'alias_of', (select a.code from private.market_instrument_aliases a where a.alias = t.token),
             'stock_format', t.token ~ '^[A-Z][A-Z0-9]{1,11}$')
           order by t.ord)
    from (
      select v_code as token, 'code' as role, 0::bigint as ord
      union all
      select distinct on (upper(ltrim(btrim(a), '$'))) upper(ltrim(btrim(a), '$')), 'alias', o
      from unnest(coalesce(p_aliases, '{}')) with ordinality as u(a, o)
      where btrim(coalesce(a, '')) <> '' and upper(ltrim(btrim(a), '$')) <> v_code
    ) t), '[]');
end;
$$;

create function cs_api.community_save_instrument(
  p_code         text,
  p_name         text,
  p_aliases      text[] default '{}',
  p_description  text default null,
  p_position     integer default null,
  p_enabled      boolean default true,
  p_room_enabled boolean default true,
  p_kind         text default 'index'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_community('{community.moderate}');
  v_code    text := upper(ltrim(btrim(coalesce(p_code, '')), '$'));
  v_aliases text[] := array(
    select distinct upper(ltrim(btrim(a), '$')) from unnest(coalesce(p_aliases, '{}')) a
    where btrim(coalesce(a, '')) <> '' and upper(ltrim(btrim(a), '$')) <> upper(ltrim(btrim(coalesce(p_code, '')), '$')));
  v_old     private.market_instruments;
  v_new     private.market_instruments;
  v_before  text[];
  v_alias   text;
begin
  if not coalesce(private.stock_code_format(v_code), false) then
    perform private.api_error(400, 'invalid_instrument_code',
      'Kode 2–24 karakter: huruf/angka, boleh dipisah tanda strip, diawali huruf');
  end if;
  if exists (select 1 from private.market_instrument_aliases a where a.alias = v_code) then
    perform private.api_error(409, 'instrument_code_taken', 'Kode ini sudah dipakai sebagai alias instrumen lain');
  end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 80 then
    perform private.api_error(400, 'invalid_instrument_name', 'Nama wajib diisi, maksimal 80 karakter');
  end if;
  if char_length(coalesce(p_description, '')) > 300 then
    perform private.api_error(400, 'invalid_instrument_description', 'Deskripsi maksimal 300 karakter');
  end if;
  if coalesce(p_kind, 'index') not in ('index') then
    perform private.api_error(400, 'invalid_instrument_kind', 'Jenis instrumen harus index');
  end if;
  if cardinality(v_aliases) > 10 then
    perform private.api_error(400, 'invalid_instrument_alias', 'Maksimal 10 alias');
  end if;
  if exists (select 1 from unnest(v_aliases) a where not coalesce(private.stock_code_format(a), false)) then
    perform private.api_error(400, 'invalid_instrument_alias', 'Format alias sama dengan format kode');
  end if;
  if exists (select 1 from unnest(v_aliases) a
             where exists (select 1 from private.market_instruments i where i.code = a)
                or exists (select 1 from private.market_instrument_aliases x where x.alias = a and x.code <> v_code)) then
    perform private.api_error(409, 'instrument_alias_taken', 'Alias sudah dipakai sebagai kode atau alias instrumen lain');
  end if;

  select * into v_old from private.market_instruments where code = v_code for update;
  v_before := array(select a.alias from private.market_instrument_aliases a where a.code = v_code order by a.alias);

  insert into private.market_instruments as m (code, kind, name, description, position, enabled, room_enabled,
                                               updated_at, updated_by)
  values (v_code, coalesce(p_kind, 'index'), btrim(p_name), nullif(btrim(coalesce(p_description, '')), ''),
          coalesce(p_position, (select coalesce(max(x.position), -1) + 1 from private.market_instruments x)),
          coalesce(p_enabled, true), coalesce(p_room_enabled, true), now(), v_me)
  on conflict (code) do update
    set kind = excluded.kind, name = excluded.name, description = excluded.description,
        position = coalesce(p_position, m.position), enabled = excluded.enabled,
        room_enabled = excluded.room_enabled, updated_at = now(), updated_by = v_me
  returning * into v_new;

  delete from private.market_instrument_aliases where code = v_code and alias <> all (v_aliases);
  insert into private.market_instrument_aliases (alias, code)
  select a, v_code from unnest(v_aliases) a
  on conflict (alias) do nothing;

  foreach v_alias in array v_aliases loop
    perform private.merge_stock_code(v_alias, v_code);
  end loop;
  perform private.retag_posts(array[v_code] || v_aliases || v_before);

  perform cs.audit('community.instrument_save', null, null, jsonb_build_object(
    'code', v_code,
    'before', case when v_old.code is null then null
                   else jsonb_build_object('name', v_old.name, 'aliases', to_jsonb(v_before),
                                           'enabled', v_old.enabled, 'room_enabled', v_old.room_enabled,
                                           'position', v_old.position, 'description', v_old.description) end,
    'after', jsonb_build_object('name', v_new.name, 'aliases', to_jsonb(v_aliases),
                                'enabled', v_new.enabled, 'room_enabled', v_new.room_enabled,
                                'position', v_new.position, 'description', v_new.description)));
  return cs.instrument_view(v_new);
end;
$$;

create function cs_api.community_reorder_instruments(p_codes text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.moderate}');
  v_codes text[] := array(select upper(btrim(c)) from unnest(coalesce(p_codes, '{}')) c);
begin
  if cardinality(v_codes) <> (select count(*) from private.market_instruments)
     or cardinality(v_codes) <> (select count(distinct c) from unnest(v_codes) c)
     or exists (select 1 from unnest(v_codes) c
                where not exists (select 1 from private.market_instruments i where i.code = c)) then
    perform private.api_error(400, 'invalid_instrument_order', 'Urutan harus memuat setiap instrumen tepat satu kali');
  end if;
  update private.market_instruments i
     set position = o.ord - 1, updated_at = now(), updated_by = v_me
    from unnest(v_codes) with ordinality as o(code, ord)
   where i.code = o.code and i.position is distinct from o.ord - 1;
  perform cs.audit('community.instrument_reorder', null, null, jsonb_build_object('codes', to_jsonb(v_codes)));
  return cs_api.community_instruments();
end;
$$;

create function cs_api.community_delete_instrument(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_community('{community.moderate}');
  v_code    text := upper(ltrim(btrim(coalesce(p_code, '')), '$'));
  v_old     private.market_instruments;
  v_aliases text[];
begin
  v_aliases := array(select a.alias from private.market_instrument_aliases a where a.code = v_code order by a.alias);
  delete from private.market_instruments where code = v_code returning * into v_old;
  if v_old.code is null then
    perform private.api_error(404, 'instrument_not_found', 'Instrumen tidak ditemukan');
  end if;
  perform private.retag_posts(array[v_code] || v_aliases);
  perform cs.audit('community.instrument_delete', null, null, jsonb_build_object(
    'code', v_code, 'name', v_old.name, 'aliases', to_jsonb(v_aliases)));
  return cs_api.community_instruments();
end;
$$;

insert into private.market_instruments (code, name, position) values
  ('IHSG', 'Indeks Harga Saham Gabungan', 0),
  ('LQ45', 'Indeks LQ45', 1),
  ('IDX30', 'Indeks IDX30', 2),
  ('IDX80', 'Indeks IDX80', 3),
  ('KOMPAS100', 'Indeks Kompas100', 4),
  ('JII', 'Jakarta Islamic Index', 5),
  ('JII70', 'Jakarta Islamic Index 70', 6),
  ('ISSI', 'Indeks Saham Syariah Indonesia', 7),
  ('SRI-KEHATI', 'Indeks SRI-KEHATI', 8),
  ('IDXHIDIV20', 'IDX High Dividend 20', 9),
  ('IDXBUMN20', 'IDX BUMN20', 10),
  ('IDXV30', 'IDX Value30', 11),
  ('IDXG30', 'IDX Growth30', 12),
  ('IDXQ30', 'IDX Quality30', 13),
  ('IDXESGL', 'IDX ESG Leaders', 14),
  ('IDXSMC-LIQ', 'IDX SMC Liquid', 15),
  ('IDXSMC-COM', 'IDX SMC Composite', 16),
  ('PEFINDO25', 'Indeks PEFINDO25', 17),
  ('INFOBANK15', 'Indeks Infobank15', 18),
  ('BISNIS-27', 'Indeks Bisnis-27', 19),
  ('MNC36', 'Indeks MNC36', 20),
  ('SMINFRA18', 'Indeks SMinfra18', 21),
  ('IDXENERGY', 'IDX Sektor Energi', 22),
  ('IDXBASIC', 'IDX Sektor Barang Baku', 23),
  ('IDXINDUST', 'IDX Sektor Perindustrian', 24),
  ('IDXNONCYC', 'IDX Sektor Barang Konsumen Primer', 25),
  ('IDXCYCLIC', 'IDX Sektor Barang Konsumen Non-Primer', 26),
  ('IDXHEALTH', 'IDX Sektor Kesehatan', 27),
  ('IDXFINANCE', 'IDX Sektor Keuangan', 28),
  ('IDXPROPERT', 'IDX Sektor Properti & Real Estat', 29),
  ('IDXTECHNO', 'IDX Sektor Teknologi', 30),
  ('IDXINFRA', 'IDX Sektor Infrastruktur', 31),
  ('IDXTRANS', 'IDX Sektor Transportasi & Logistik', 32);

insert into private.market_instrument_aliases (alias, code) values
  ('COMPOSITE', 'IHSG'),
  ('JCI', 'IHSG'),
  ('SRIKEHATI', 'SRI-KEHATI'),
  ('IDXSMCLIQ', 'IDXSMC-LIQ'),
  ('IDXSMCCOM', 'IDXSMC-COM'),
  ('BISNIS27', 'BISNIS-27');

select private.merge_stock_code(a.alias, a.code) from private.market_instrument_aliases a;
select private.retag_posts(array(
  select i.code from private.market_instruments i where strpos(i.code, '-') > 0
  union all
  select a.alias from private.market_instrument_aliases a));

revoke all on private.market_instruments from public, anon, authenticated;
revoke all on private.market_instrument_aliases from public, anon, authenticated;
revoke execute on function private.stock_code(text) from public;
revoke execute on function private.resolve_cashtag(text) from public;
revoke execute on function private.retag_posts(text[]) from public;
revoke execute on function private.merge_stock_code(text, text) from public;
revoke execute on function private.canonical_stock_code() from public;
revoke execute on function private.stock_room_enabled(text) from public;
revoke execute on function public.get_market_instruments() from public, anon;
revoke execute on function cs.instrument_usage(text) from public;
revoke execute on function cs.instrument_view(private.market_instruments) from public;
revoke execute on function cs_api.community_instruments() from public;
revoke execute on function cs_api.community_instrument_check(text, text[]) from public;
revoke execute on function cs_api.community_save_instrument(text, text, text[], text, integer, boolean, boolean, text)
  from public;
revoke execute on function cs_api.community_reorder_instruments(text[]) from public;
revoke execute on function cs_api.community_delete_instrument(text) from public;
grant execute on function private.stock_code(text) to authenticated;
grant execute on function public.get_market_instruments() to authenticated;
grant execute on function cs_api.community_instruments() to authenticated;
grant execute on function cs_api.community_instrument_check(text, text[]) to authenticated;
grant execute on function cs_api.community_save_instrument(text, text, text[], text, integer, boolean, boolean, text)
  to authenticated;
grant execute on function cs_api.community_reorder_instruments(text[]) to authenticated;
grant execute on function cs_api.community_delete_instrument(text) to authenticated;
