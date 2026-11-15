insert into cs.cs_settings (key, value, description) values
  ('trade_share.enabled', 'false', 'Tombol darurat fitur Berbagi Trade. Mati = UI tersembunyi dan tidak ada data trade yang diproses'),
  ('trade_share.pilot_only', 'true', 'Pengajuan trader hanya untuk profil undangan pilot'),
  ('trade_share.min_account_age_days', '30', 'Umur minimal profil sosial (hari) untuk mengajukan sebagai trader'),
  ('trade_share.reapply_cooldown_days', '30', 'Masa tunggu (hari) sebelum boleh mengajukan lagi setelah ditolak atau dicabut'),
  ('trade_share.min_delay_minutes', '15', 'Jeda minimum (menit) antara trade dan notifikasi ke pelanggan'),
  ('trade_share.max_delay_minutes', '240', 'Jeda maksimum (menit) yang boleh dipilih trader'),
  ('trade_share.force_hide_price', 'false', 'Paksa harga tersembunyi untuk semua trader'),
  ('trade_share.force_hide_lot', 'false', 'Paksa lot tersembunyi untuk semua trader'),
  ('trade_share.four_eyes', 'false', 'Persetujuan trader butuh dua staf berbeda'),
  ('trade_share.max_subscriptions', '20', 'Jumlah maksimum trader yang boleh dilanggan satu pelanggan'),
  ('trade_share.request_expiry_days', '14', 'Permintaan langganan yang tidak dijawab kedaluwarsa setelah sekian hari'),
  ('trade_share.review_subscriber_threshold', '1000', 'Trader dengan pelanggan aktif sebanyak ini masuk daftar tinjauan'),
  ('trade_share.lot_size', '100', 'Jumlah lembar per lot'),
  ('trade_share.boards', '["RG"]', 'Board yang dibagikan')
on conflict (key) do nothing;

alter table cs.agents add column trade_permissions text[] not null default '{}';

create or replace function cs.trade_permission_codes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['trade_relay.operate', 'trade_share.manage', 'trade_share.review'];
$$;

alter table cs.agents add constraint agents_trade_permissions_check
  check (trade_permissions <@ array['trade_relay.operate', 'trade_share.manage', 'trade_share.review']);

create or replace function cs.has_trade(p_permissions text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.current_agent_id() is not null
     and (cs.has_role('{cs_super_admin}')
          or exists (select 1 from cs.agents a
                      where a.user_id = cs.current_agent_id() and a.trade_permissions && p_permissions));
$$;

create or replace function cs.require_trade(p_permissions text[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  if not cs.has_trade(p_permissions) then
    perform private.api_error(403, 'trade_forbidden', 'Tidak punya izin Berbagi Trade');
  end if;
  return v_me;
end;
$$;

create or replace function cs_api.admin_set_trade_permissions(p_agent_id uuid, p_permissions text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_perms text[] := coalesce((select array_agg(distinct p order by p) from unnest(coalesce(p_permissions, '{}')) p), '{}');
begin
  if not (v_perms <@ cs.trade_permission_codes()) then
    perform private.api_error(400, 'invalid_permission', 'Izin Berbagi Trade tidak dikenal');
  end if;
  if not exists (select 1 from cs.agents where user_id = p_agent_id) then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  update cs.agents set trade_permissions = v_perms where user_id = p_agent_id;
  perform cs.audit('agent.trade_permissions', null, null,
                   jsonb_build_object('agent', p_agent_id, 'permissions', to_jsonb(v_perms)));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

create or replace function cs.agent_admin_view(p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.user_id,
    'agent_code', a.agent_code,
    'display_name', a.display_name,
    'email', u.email,
    'roles', to_jsonb(a.roles),
    'team', tm.code,
    'max_active_tickets', a.max_active_tickets,
    'disabled_at', a.disabled_at,
    'status', coalesce(st.status, 'offline'),
    'active_tickets', cs.active_ticket_count(a.user_id),
    'totp', exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'),
    'nasabah_permissions', to_jsonb(a.nasabah_permissions),
    'community_permissions', to_jsonb(a.community_permissions),
    'trade_permissions', to_jsonb(a.trade_permissions),
    'created_at', a.created_at)
  from cs.agents a
  left join cs.agent_status st on st.agent_id = a.user_id
  left join cs.teams tm on tm.id = a.team_id
  left join auth.users u on u.id = a.user_id
  where a.user_id = p_agent;
$$;

alter table public.legal_documents drop constraint legal_documents_kind;
alter table public.legal_documents add constraint legal_documents_kind
  check (kind in ('terms', 'community_guidelines', 'privacy', 'trade_share_terms', 'trade_share_risk'));

alter table cs.legal_drafts drop constraint legal_drafts_kind_check;
alter table cs.legal_drafts add constraint legal_drafts_kind_check
  check (kind in ('terms', 'community_guidelines', 'privacy', 'trade_share_terms', 'trade_share_risk'));

create or replace function cs.legal_kinds()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['terms', 'community_guidelines', 'privacy', 'trade_share_terms', 'trade_share_risk'];
$$;

create table private.trade_sharers (
  profile_id        uuid primary key references public.profiles (id) on delete cascade,
  status            text not null
                    check (status in ('pending', 'active', 'paused', 'suspended', 'rejected', 'revoked', 'withdrawn')),
  pause_source      text check (pause_source in ('user', 'system')),
  show_price        boolean not null default true,
  show_lot          boolean not null default true,
  delay_minutes     integer not null check (delay_minutes between 1 and 1440),
  subscribe_mode    text not null default 'auto' check (subscribe_mode in ('auto', 'approval')),
  terms_document_id uuid references public.legal_documents (id),
  applied_at        timestamptz not null default now(),
  proposed_by       uuid,
  proposed_at       timestamptz,
  decided_by        uuid,
  decided_at        timestamptz,
  decision_reason   text check (char_length(decision_reason) <= 500),
  suspended_until   timestamptz,
  cooldown_until    timestamptz,
  updated_at        timestamptz not null default now(),
  constraint trade_sharers_pause check ((status = 'paused') = (pause_source is not null))
);
create index trade_sharers_status_idx on private.trade_sharers (status, applied_at desc);

create table private.trade_sharer_accounts (
  profile_id uuid not null references private.trade_sharers (profile_id) on delete cascade,
  cust_id    text not null check (cust_id ~ '^[A-Z0-9._-]{1,32}$'),
  state      text not null default 'active' check (state in ('active', 'unlinked', 'expired', 'shared_link', 'excluded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, cust_id)
);
create index trade_sharer_accounts_cust_idx on private.trade_sharer_accounts (cust_id);

create table private.trade_share_events (
  id          bigint generated always as identity primary key,
  profile_id  uuid not null references private.trade_sharers (profile_id) on delete cascade,
  action      text not null check (char_length(action) between 3 and 60),
  actor_kind  text not null check (actor_kind in ('user', 'staff', 'system')),
  actor_id    uuid,
  from_status text,
  to_status   text,
  reason      text check (char_length(reason) <= 500),
  details     jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index trade_share_events_profile_idx on private.trade_share_events (profile_id, id desc);

create table private.trade_share_excluded_accounts (
  cust_id    text primary key check (cust_id ~ '^[A-Z0-9._-]{1,32}$'),
  reason     text not null check (char_length(btrim(reason)) between 3 and 500),
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table private.trade_share_pilot_invites (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

alter table private.trade_sharers enable row level security;
alter table private.trade_sharer_accounts enable row level security;
alter table private.trade_share_events enable row level security;
alter table private.trade_share_excluded_accounts enable row level security;
alter table private.trade_share_pilot_invites enable row level security;
revoke all on private.trade_sharers, private.trade_sharer_accounts, private.trade_share_events,
              private.trade_share_excluded_accounts, private.trade_share_pilot_invites
  from public, anon, authenticated;

create or replace function private.trade_share_bool(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((cs.setting(p_key) #>> '{}')::boolean, false);
$$;

create or replace function private.trade_share_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(cs.setting_int(p_key), p_default);
$$;

create or replace function private.trade_share_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.trade_share_bool('trade_share.enabled');
$$;

create or replace function private.trade_share_reason(p_reason text, p_required boolean)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if p_required and (v is null or char_length(v) < 3) then
    perform private.api_error(400, 'reason_required', 'Alasan wajib diisi (minimal 3 karakter)');
  end if;
  if char_length(v) > 500 then
    perform private.api_error(400, 'reason_too_long', 'Alasan maksimal 500 karakter');
  end if;
  return v;
end;
$$;

create or replace function private.trade_share_log(p_profile uuid, p_action text, p_actor_kind text, p_actor uuid,
                                                   p_from text, p_to text, p_reason text default null,
                                                   p_details jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.trade_share_events (profile_id, action, actor_kind, actor_id, from_status, to_status, reason, details)
  values (p_profile, p_action, p_actor_kind, p_actor, p_from, p_to, p_reason, coalesce(p_details, '{}'));
$$;

create or replace function private.trade_share_latest_document(p_kind text)
returns public.legal_documents
language sql
stable
security definer
set search_path = ''
as $$
  select d.* from public.legal_documents d
   where d.kind = p_kind and d.effective_at <= now()
   order by d.version desc
   limit 1;
$$;

create or replace function private.trade_share_account_state(p_profile uuid, p_cust text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with v as (select private.setting_num('integration.account_link_days', 30)::integer as days)
  select case
    when not exists (select 1 from private.account_links l where l.cust_id = p_cust and l.profile_id = p_profile)
      then 'unlinked'
    when exists (select 1 from private.trade_share_excluded_accounts x where x.cust_id = p_cust)
      then 'excluded'
    when exists (select 1 from private.account_links l
                   join public.profiles p on p.id = l.profile_id and p.deleted_at is null
                  where l.cust_id = p_cust and l.profile_id <> p_profile
                    and l.seen_at > now() - make_interval(days => (select days from v)))
      then 'shared_link'
    when exists (select 1 from private.account_links l
                  where l.cust_id = p_cust and l.profile_id = p_profile
                    and l.seen_at <= now() - make_interval(days => (select days from v)))
      then 'expired'
    else 'active'
  end;
$$;

create or replace function private.trade_share_candidate_accounts(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('cust_id', l.cust_id,
                                               'state', private.trade_share_account_state(p_profile, l.cust_id))
                            order by l.created_at, l.cust_id), '[]')
  from private.account_links l
  where l.profile_id = p_profile;
$$;

create or replace function private.trade_share_eligibility(p_profile uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p          public.profiles;
  s          private.trade_sharers;
  v_accounts jsonb := private.trade_share_candidate_accounts(p_profile);
  v_terms    public.legal_documents := private.trade_share_latest_document('trade_share_terms');
  v_checks   jsonb;
begin
  select * into p from public.profiles where id = p_profile;
  select * into s from private.trade_sharers where profile_id = p_profile;
  v_checks := jsonb_build_array(
    jsonb_build_object('code', 'feature_enabled', 'ok', coalesce(private.trade_share_enabled(), false)),
    jsonb_build_object('code', 'pilot_invited',
                       'ok', coalesce(not private.trade_share_bool('trade_share.pilot_only')
                                      or exists (select 1 from private.trade_share_pilot_invites i
                                                  where i.profile_id = p_profile), false)),
    jsonb_build_object('code', 'regular_profile',
                       'ok', coalesce(p.id is not null and p.deleted_at is null and not p.is_guest
                                      and not private.is_official_account(p.id) and not cs.is_staff(p.id), false)),
    jsonb_build_object('code', 'not_sanctioned',
                       'ok', coalesce(not private.has_active_sanction(p_profile, '{mute,ban}'), false)),
    jsonb_build_object('code', 'account_age',
                       'ok', coalesce(p.created_at <= now() - make_interval(
                                        days => private.trade_share_int('trade_share.min_account_age_days', 30)), false)),
    jsonb_build_object('code', 'cooldown', 'ok', s.cooldown_until is null or s.cooldown_until <= now()),
    jsonb_build_object('code', 'linked_account',
                       'ok', exists (select 1 from jsonb_array_elements(v_accounts) a where a ->> 'state' = 'active')),
    jsonb_build_object('code', 'terms_available', 'ok', v_terms.id is not null));
  return jsonb_build_object(
    'eligible', not exists (select 1 from jsonb_array_elements(v_checks) c where not (c ->> 'ok')::boolean),
    'checks', v_checks,
    'accounts', v_accounts,
    'cooldown_until', s.cooldown_until,
    'terms_document', case when v_terms.id is not null then jsonb_build_object(
      'id', v_terms.id, 'version', v_terms.version, 'title', v_terms.title, 'body', v_terms.body,
      'effective_at', v_terms.effective_at) end);
end;
$$;

create or replace function private.trade_share_subscriber_counts(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('active', 0, 'pending', 0);
$$;

create or replace function private.trade_share_status_view(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'enabled', private.trade_share_enabled(),
    'status', s.status,
    'pause_source', s.pause_source,
    'show_price', s.show_price,
    'show_lot', s.show_lot,
    'delay_minutes', s.delay_minutes,
    'subscribe_mode', s.subscribe_mode,
    'applied_at', s.applied_at,
    'decided_at', s.decided_at,
    'decision_reason', case when s.status in ('rejected', 'revoked', 'suspended') then s.decision_reason end,
    'suspended_until', s.suspended_until,
    'cooldown_until', s.cooldown_until,
    'accounts', coalesce((select jsonb_agg(jsonb_build_object('cust_id', a.cust_id, 'state', a.state) order by a.cust_id)
                            from private.trade_sharer_accounts a where a.profile_id = s.profile_id), '[]'),
    'subscribers', case when s.profile_id is not null then private.trade_share_subscriber_counts(s.profile_id) end,
    'limits', jsonb_build_object(
      'min_delay_minutes', private.trade_share_int('trade_share.min_delay_minutes', 15),
      'max_delay_minutes', private.trade_share_int('trade_share.max_delay_minutes', 240),
      'force_hide_price', private.trade_share_bool('trade_share.force_hide_price'),
      'force_hide_lot', private.trade_share_bool('trade_share.force_hide_lot')),
    'eligibility', private.trade_share_eligibility(p_profile))
  from (select p_profile as id) x
  left join private.trade_sharers s on s.profile_id = x.id;
$$;

create or replace function private.trade_share_refresh(p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s       private.trade_sharers;
  a       record;
  v_state text;
  v_any   boolean;
begin
  select * into s from private.trade_sharers where profile_id = p_profile for update;
  if not found then
    return;
  end if;
  for a in select * from private.trade_sharer_accounts where profile_id = p_profile for update loop
    v_state := private.trade_share_account_state(p_profile, a.cust_id);
    if v_state <> a.state then
      update private.trade_sharer_accounts set state = v_state, updated_at = now()
       where profile_id = p_profile and cust_id = a.cust_id;
      perform private.trade_share_log(p_profile, 'account_state', 'system', null, s.status, s.status, null,
                                      jsonb_build_object('cust_id', a.cust_id, 'from', a.state, 'to', v_state));
    end if;
  end loop;
  v_any := exists (select 1 from private.trade_sharer_accounts where profile_id = p_profile and state = 'active');
  if s.status = 'active' and not v_any then
    update private.trade_sharers set status = 'paused', pause_source = 'system', updated_at = now()
     where profile_id = p_profile;
    perform private.trade_share_log(p_profile, 'auto_paused', 'system', null, 'active', 'paused', 'no_active_accounts');
  elsif s.status = 'paused' and s.pause_source = 'system' and v_any then
    update private.trade_sharers set status = 'active', pause_source = null, updated_at = now()
     where profile_id = p_profile;
    perform private.trade_share_log(p_profile, 'auto_resumed', 'system', null, 'paused', 'active');
  end if;
end;
$$;

create or replace function private.trade_share_refresh_cust(p_cust text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile uuid;
begin
  for v_profile in select distinct a.profile_id from private.trade_sharer_accounts a where a.cust_id = p_cust loop
    perform private.trade_share_refresh(v_profile);
  end loop;
end;
$$;

create or replace function private.trade_share_links_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cust text := coalesce(new.cust_id, old.cust_id);
begin
  if tg_op = 'UPDATE' and new.seen_at is not distinct from old.seen_at then
    return null;
  end if;
  if exists (select 1 from private.trade_sharer_accounts a where a.cust_id = v_cust) then
    perform private.trade_share_refresh_cust(v_cust);
  end if;
  return null;
end;
$$;

create trigger account_links_trade_share
  after insert or delete or update of seen_at on private.account_links
  for each row execute function private.trade_share_links_changed();

create or replace function private.trade_share_excluded_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.trade_share_refresh_cust(coalesce(new.cust_id, old.cust_id));
  return null;
end;
$$;

create trigger trade_share_excluded_refresh
  after insert or delete on private.trade_share_excluded_accounts
  for each row execute function private.trade_share_excluded_changed();

create or replace function private.trade_share_forget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    delete from private.trade_sharers where profile_id = new.id;
    delete from private.trade_share_pilot_invites where profile_id = new.id;
  end if;
  return null;
end;
$$;

create trigger profiles_71_trade_share_forget
  after update of deleted_at on public.profiles
  for each row execute function private.trade_share_forget();

create or replace function private.trade_share_clean_accounts(p_accounts text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct c order by c), '{}')
  from (select private.integration_cust_id(to_jsonb(x)) as c from unnest(coalesce(p_accounts, '{}')) x) y
  where c is not null;
$$;

create or replace function private.trade_share_check_accounts(p_profile uuid, p_accounts text[], p_required text[])
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bad text[];
begin
  if cardinality(p_accounts) = 0 then
    perform private.api_error(400, 'accounts_required', 'Pilih minimal satu rekening');
  end if;
  if cardinality(p_accounts) > 50 then
    perform private.api_error(400, 'too_many_accounts', 'Rekening terlalu banyak');
  end if;
  select array_agg(c order by c) into v_bad
  from unnest(p_required) c
  where private.trade_share_account_state(p_profile, c) <> 'active';
  if v_bad is not null then
    perform private.api_error(400, 'account_not_eligible', array_to_string(v_bad, ','));
  end if;
end;
$$;

create or replace function private.trade_share_check_values(p_delay integer, p_mode text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_min integer := private.trade_share_int('trade_share.min_delay_minutes', 15);
  v_max integer := private.trade_share_int('trade_share.max_delay_minutes', 240);
begin
  if p_delay is null or p_delay < v_min or p_delay > v_max then
    perform private.api_error(400, 'invalid_delay', format('Jeda harus %s–%s menit', v_min, v_max));
  end if;
  if p_mode is null or p_mode not in ('auto', 'approval') then
    perform private.api_error(400, 'invalid_subscribe_mode', 'Mode langganan tidak dikenal');
  end if;
end;
$$;

create or replace function private.trade_share_set_accounts(p_profile uuid, p_accounts text[])
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.trade_sharer_accounts where profile_id = p_profile and cust_id <> all (p_accounts);
  insert into private.trade_sharer_accounts (profile_id, cust_id, state)
  select p_profile, c, 'active' from unnest(p_accounts) c
  on conflict (profile_id, cust_id) do update set state = 'active', updated_at = now();
$$;

create or replace function public.get_trade_share_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function public.submit_trade_share_application(p_accounts text[], p_show_price boolean,
                                                                 p_show_lot boolean, p_delay_minutes integer,
                                                                 p_subscribe_mode text, p_terms_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  s          private.trade_sharers;
  v_elig     jsonb;
  v_terms    public.legal_documents;
  v_accounts text[] := private.trade_share_clean_accounts(p_accounts);
  v_delay    integer := coalesce(p_delay_minutes, private.trade_share_int('trade_share.min_delay_minutes', 15));
  v_mode     text := coalesce(p_subscribe_mode, 'auto');
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_sharers where profile_id = v_uid for update;
  if found and s.status in ('pending', 'active', 'paused', 'suspended') then
    perform private.api_error(409, 'already_applied', 'Pengajuan atau keikutsertaan masih berjalan');
  end if;
  v_elig := private.trade_share_eligibility(v_uid);
  if not (v_elig ->> 'eligible')::boolean then
    perform private.api_error(403, 'not_eligible',
                              (select string_agg(c ->> 'code', ',') from jsonb_array_elements(v_elig -> 'checks') c
                                where not (c ->> 'ok')::boolean));
  end if;
  v_terms := private.trade_share_latest_document('trade_share_terms');
  if p_terms_document_id is distinct from v_terms.id then
    perform private.api_error(409, 'terms_outdated', 'Syarat & Ketentuan sudah berubah, baca ulang');
  end if;
  perform private.trade_share_check_accounts(v_uid, v_accounts, v_accounts);
  perform private.trade_share_check_values(v_delay, v_mode);
  insert into public.user_consents (user_id, document_id) values (v_uid, v_terms.id) on conflict do nothing;
  insert into private.trade_sharers as t (profile_id, status, show_price, show_lot, delay_minutes, subscribe_mode,
                                          terms_document_id, applied_at)
  values (v_uid, 'pending', coalesce(p_show_price, true), coalesce(p_show_lot, true), v_delay, v_mode,
          v_terms.id, now())
  on conflict (profile_id) do update
     set status = 'pending', pause_source = null, show_price = excluded.show_price, show_lot = excluded.show_lot,
         delay_minutes = excluded.delay_minutes, subscribe_mode = excluded.subscribe_mode,
         terms_document_id = excluded.terms_document_id, applied_at = now(), proposed_by = null,
         proposed_at = null, decided_by = null, decided_at = null, decision_reason = null,
         suspended_until = null, cooldown_until = null, updated_at = now();
  perform private.trade_share_set_accounts(v_uid, v_accounts);
  perform private.trade_share_log(v_uid, 'applied', 'user', v_uid, s.status, 'pending', null,
                                  jsonb_build_object('accounts', to_jsonb(v_accounts), 'show_price', coalesce(p_show_price, true),
                                                     'show_lot', coalesce(p_show_lot, true), 'delay_minutes', v_delay,
                                                     'subscribe_mode', v_mode, 'terms_version', v_terms.version));
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function public.update_trade_share_settings(p_accounts text[], p_show_price boolean,
                                                              p_show_lot boolean, p_delay_minutes integer,
                                                              p_subscribe_mode text, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  s          private.trade_sharers;
  v_accounts text[] := private.trade_share_clean_accounts(p_accounts);
  v_old      text[];
  v_scope    boolean;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_sharers where profile_id = v_uid for update;
  if not found or s.status not in ('pending', 'active', 'paused') then
    perform private.api_error(409, 'not_sharing', 'Belum terdaftar sebagai trader');
  end if;
  select coalesce(array_agg(cust_id order by cust_id), '{}') into v_old
  from private.trade_sharer_accounts where profile_id = v_uid;
  perform private.trade_share_check_accounts(v_uid, v_accounts,
                                             (select coalesce(array_agg(c), '{}') from unnest(v_accounts) c
                                               where c <> all (v_old)));
  perform private.trade_share_check_values(p_delay_minutes, p_subscribe_mode);
  v_scope := coalesce(p_show_price, s.show_price) is distinct from s.show_price
          or coalesce(p_show_lot, s.show_lot) is distinct from s.show_lot
          or v_accounts is distinct from v_old;
  if v_scope and not coalesce(p_confirm, false) then
    perform private.api_error(409, 'confirmation_required', 'Perubahan cakupan data perlu dikonfirmasi');
  end if;
  update private.trade_sharers
     set show_price = coalesce(p_show_price, show_price), show_lot = coalesce(p_show_lot, show_lot),
         delay_minutes = p_delay_minutes, subscribe_mode = p_subscribe_mode, updated_at = now()
   where profile_id = v_uid;
  perform private.trade_share_set_accounts(v_uid, v_accounts);
  perform private.trade_share_log(v_uid, 'settings_changed', 'user', v_uid, s.status, s.status, null,
                                  jsonb_build_object(
                                    'accounts', jsonb_build_object('from', to_jsonb(v_old), 'to', to_jsonb(v_accounts)),
                                    'show_price', jsonb_build_object('from', s.show_price, 'to', coalesce(p_show_price, s.show_price)),
                                    'show_lot', jsonb_build_object('from', s.show_lot, 'to', coalesce(p_show_lot, s.show_lot)),
                                    'delay_minutes', jsonb_build_object('from', s.delay_minutes, 'to', p_delay_minutes),
                                    'subscribe_mode', jsonb_build_object('from', s.subscribe_mode, 'to', p_subscribe_mode)));
  perform private.trade_share_refresh(v_uid);
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function public.pause_trade_share()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  s     private.trade_sharers;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_sharers where profile_id = v_uid for update;
  if not found or s.status <> 'active' then
    perform private.api_error(409, 'not_active', 'Berbagi trade tidak sedang aktif');
  end if;
  update private.trade_sharers set status = 'paused', pause_source = 'user', updated_at = now() where profile_id = v_uid;
  perform private.trade_share_log(v_uid, 'paused', 'user', v_uid, 'active', 'paused');
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function public.resume_trade_share()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  s     private.trade_sharers;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_sharers where profile_id = v_uid for update;
  if not found or s.status <> 'paused' then
    perform private.api_error(409, 'not_paused', 'Berbagi trade tidak sedang dijeda');
  end if;
  if not exists (select 1 from private.trade_sharer_accounts a where a.profile_id = v_uid and a.state = 'active') then
    perform private.api_error(409, 'no_active_accounts', 'Tidak ada rekening aktif yang bisa dibagikan');
  end if;
  update private.trade_sharers set status = 'active', pause_source = null, updated_at = now() where profile_id = v_uid;
  perform private.trade_share_log(v_uid, 'resumed', 'user', v_uid, 'paused', 'active');
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function public.withdraw_trade_share()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  s     private.trade_sharers;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_sharers where profile_id = v_uid for update;
  if not found or s.status not in ('pending', 'active', 'paused', 'suspended') then
    perform private.api_error(409, 'not_sharing', 'Belum terdaftar sebagai trader');
  end if;
  update private.trade_sharers set status = 'withdrawn', pause_source = null, updated_at = now() where profile_id = v_uid;
  perform private.trade_share_log(v_uid, 'withdrawn', 'user', v_uid, s.status, 'withdrawn');
  return private.trade_share_status_view(v_uid);
end;
$$;

create or replace function cs.trade_share_profile_ref(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name,
                            'avatar_url', p.avatar_url, 'is_verified', p.is_verified,
                            'follower_count', p.follower_count, 'created_at', p.created_at)
  from public.profiles p where p.id = p_profile;
$$;

create or replace function cs.trade_share_account_review(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'cust_id', a.cust_id,
    'state', a.state,
    'current_state', private.trade_share_account_state(p_profile, a.cust_id),
    'excluded_reason', (select x.reason from private.trade_share_excluded_accounts x where x.cust_id = a.cust_id),
    'other_profiles', (select count(*) from private.account_links l
                         join public.profiles p on p.id = l.profile_id and p.deleted_at is null
                        where l.cust_id = a.cust_id and l.profile_id <> p_profile)) order by a.cust_id), '[]')
  from private.trade_sharer_accounts a where a.profile_id = p_profile;
$$;

create or replace function cs.trade_share_item(s private.trade_sharers)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', cs.trade_share_profile_ref(s.profile_id),
    'status', s.status,
    'pause_source', s.pause_source,
    'show_price', s.show_price,
    'show_lot', s.show_lot,
    'delay_minutes', s.delay_minutes,
    'subscribe_mode', s.subscribe_mode,
    'applied_at', s.applied_at,
    'proposed_by', s.proposed_by,
    'proposed_at', s.proposed_at,
    'decided_by', s.decided_by,
    'decided_at', s.decided_at,
    'decision_reason', s.decision_reason,
    'suspended_until', s.suspended_until,
    'cooldown_until', s.cooldown_until,
    'accounts', (select count(*) from private.trade_sharer_accounts a where a.profile_id = s.profile_id),
    'warnings', (select count(*) from private.trade_sharer_accounts a
                  where a.profile_id = s.profile_id and a.state <> 'active'),
    'subscribers', private.trade_share_subscriber_counts(s.profile_id));
$$;

create or replace function cs_api.trade_share_list(p_status text default 'pending', p_before timestamptz default null,
                                                   p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if p_status is not null
     and p_status not in ('pending', 'active', 'paused', 'suspended', 'rejected', 'revoked', 'withdrawn') then
    perform private.api_error(400, 'invalid_status', 'Status tidak dikenal');
  end if;
  return coalesce((
    select jsonb_agg(cs.trade_share_item(s) order by s.applied_at desc)
    from (select * from private.trade_sharers t
           where (p_status is null or t.status = p_status)
             and (p_before is null or t.applied_at < p_before)
           order by t.applied_at desc
           limit v_limit) s), '[]');
end;
$$;

create or replace function cs.trade_share_detail_view(p_profile uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s private.trade_sharers;
begin
  select * into s from private.trade_sharers where profile_id = p_profile;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  return cs.trade_share_item(s) || jsonb_build_object(
    'account_review', cs.trade_share_account_review(p_profile),
    'eligibility', private.trade_share_eligibility(p_profile),
    'sanctions', jsonb_build_object(
      'active', private.has_active_sanction(p_profile, '{warning,mute,ban}'),
      'last_365_days', (select count(*) from private.user_sanctions us
                         where us.user_id = p_profile and us.created_at > now() - interval '365 days')),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', e.id, 'action', e.action, 'actor_kind', e.actor_kind, 'actor_id', e.actor_id,
                          'from_status', e.from_status, 'to_status', e.to_status, 'reason', e.reason,
                          'details', e.details, 'created_at', e.created_at) order by e.id desc)
                        from (select * from private.trade_share_events ev where ev.profile_id = p_profile
                               order by ev.id desc limit 100) e), '[]'));
end;
$$;

create or replace function cs_api.trade_share_detail(p_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_view jsonb := cs.trade_share_detail_view(p_profile);
begin
  perform cs.audit('trade_share.view', null, p_profile, '{}');
  return v_view;
end;
$$;

create or replace function cs_api.trade_share_decide(p_profile uuid, p_decision text, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.review}');
  s        private.trade_sharers;
  v_reason text := private.trade_share_reason(p_reason, p_decision = 'reject');
begin
  if p_decision is null or p_decision not in ('approve', 'reject') then
    perform private.api_error(400, 'invalid_decision', 'Keputusan tidak dikenal');
  end if;
  select * into s from private.trade_sharers where profile_id = p_profile for update;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  if s.status <> 'pending' then
    perform private.api_error(409, 'not_pending', 'Pengajuan tidak sedang menunggu peninjauan');
  end if;
  if p_decision = 'reject' then
    update private.trade_sharers
       set status = 'rejected', decided_by = v_me, decided_at = now(), decision_reason = v_reason,
           cooldown_until = now() + make_interval(days => private.trade_share_int('trade_share.reapply_cooldown_days', 30)),
           updated_at = now()
     where profile_id = p_profile;
    perform private.trade_share_log(p_profile, 'rejected', 'staff', v_me, 'pending', 'rejected', v_reason);
    perform cs.audit('trade_share.reject', null, p_profile, jsonb_build_object('reason', v_reason));
    return cs.trade_share_detail_view(p_profile);
  end if;
  if not exists (select 1 from private.trade_sharer_accounts a
                  where a.profile_id = p_profile
                    and private.trade_share_account_state(p_profile, a.cust_id) = 'active') then
    perform private.api_error(409, 'no_active_accounts', 'Tidak ada rekening yang memenuhi syarat');
  end if;
  if private.trade_share_bool('trade_share.four_eyes') then
    if s.proposed_by is null then
      update private.trade_sharers set proposed_by = v_me, proposed_at = now(), updated_at = now()
       where profile_id = p_profile;
      perform private.trade_share_log(p_profile, 'approval_proposed', 'staff', v_me, 'pending', 'pending', v_reason);
      perform cs.audit('trade_share.propose', null, p_profile, jsonb_build_object('reason', v_reason));
      return cs.trade_share_detail_view(p_profile);
    end if;
    if s.proposed_by = v_me then
      perform private.api_error(409, 'four_eyes_same_agent', 'Persetujuan kedua harus dari staf lain');
    end if;
  end if;
  update private.trade_sharers
     set status = 'active', pause_source = null, decided_by = v_me, decided_at = now(), decision_reason = v_reason,
         updated_at = now()
   where profile_id = p_profile;
  perform private.trade_share_log(p_profile, 'approved', 'staff', v_me, 'pending', 'active', v_reason,
                                  jsonb_build_object('proposed_by', s.proposed_by));
  perform cs.audit('trade_share.approve', null, p_profile, jsonb_build_object('reason', v_reason,
                                                                              'proposed_by', s.proposed_by));
  perform private.trade_share_refresh(p_profile);
  return cs.trade_share_detail_view(p_profile);
end;
$$;

create or replace function cs_api.trade_share_suspend(p_profile uuid, p_reason text, p_until timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.review}');
  s        private.trade_sharers;
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  if p_until is not null and p_until <= now() then
    perform private.api_error(400, 'invalid_until', 'Batas waktu harus di masa depan');
  end if;
  select * into s from private.trade_sharers where profile_id = p_profile for update;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  if s.status not in ('active', 'paused') then
    perform private.api_error(409, 'not_active', 'Trader tidak sedang aktif');
  end if;
  update private.trade_sharers
     set status = 'suspended', pause_source = null, suspended_until = p_until, decision_reason = v_reason,
         decided_by = v_me, decided_at = now(), updated_at = now()
   where profile_id = p_profile;
  perform private.trade_share_log(p_profile, 'suspended', 'staff', v_me, s.status, 'suspended', v_reason,
                                  jsonb_build_object('until', p_until));
  perform cs.audit('trade_share.suspend', null, p_profile, jsonb_build_object('reason', v_reason, 'until', p_until));
  return cs.trade_share_detail_view(p_profile);
end;
$$;

create or replace function cs_api.trade_share_reinstate(p_profile uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.review}');
  s        private.trade_sharers;
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  select * into s from private.trade_sharers where profile_id = p_profile for update;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  if s.status <> 'suspended' then
    perform private.api_error(409, 'not_suspended', 'Trader tidak sedang ditangguhkan');
  end if;
  update private.trade_sharers
     set status = 'active', suspended_until = null, decision_reason = v_reason, decided_by = v_me,
         decided_at = now(), updated_at = now()
   where profile_id = p_profile;
  perform private.trade_share_log(p_profile, 'reinstated', 'staff', v_me, 'suspended', 'active', v_reason);
  perform cs.audit('trade_share.reinstate', null, p_profile, jsonb_build_object('reason', v_reason));
  perform private.trade_share_refresh(p_profile);
  return cs.trade_share_detail_view(p_profile);
end;
$$;

create or replace function cs_api.trade_share_revoke(p_profile uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.review}');
  s        private.trade_sharers;
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  select * into s from private.trade_sharers where profile_id = p_profile for update;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  if s.status not in ('pending', 'active', 'paused', 'suspended') then
    perform private.api_error(409, 'not_sharing', 'Trader tidak sedang terdaftar');
  end if;
  update private.trade_sharers
     set status = 'revoked', pause_source = null, suspended_until = null, decision_reason = v_reason,
         decided_by = v_me, decided_at = now(),
         cooldown_until = now() + make_interval(days => private.trade_share_int('trade_share.reapply_cooldown_days', 30)),
         updated_at = now()
   where profile_id = p_profile;
  perform private.trade_share_log(p_profile, 'revoked', 'staff', v_me, s.status, 'revoked', v_reason);
  perform cs.audit('trade_share.revoke', null, p_profile, jsonb_build_object('reason', v_reason));
  return cs.trade_share_detail_view(p_profile);
end;
$$;

create or replace function private.trade_share_end_suspensions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile uuid;
  v_count   integer := 0;
begin
  for v_profile in select profile_id from private.trade_sharers
                    where status = 'suspended' and suspended_until is not null and suspended_until <= now()
                    for update skip locked loop
    update private.trade_sharers set status = 'active', suspended_until = null, updated_at = now()
     where profile_id = v_profile;
    perform private.trade_share_log(v_profile, 'suspension_ended', 'system', null, 'suspended', 'active');
    perform private.trade_share_refresh(v_profile);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs_api.trade_share_excluded_accounts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('cust_id', x.cust_id, 'reason', x.reason,
                                                       'created_by', x.created_by, 'created_at', x.created_at)
                                    order by x.cust_id)
                   from private.trade_share_excluded_accounts x), '[]');
end;
$$;

create or replace function cs_api.trade_share_exclude_account(p_cust_id text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.manage}');
  v_cust   text := private.integration_cust_id(to_jsonb(p_cust_id));
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  if v_cust is null then
    perform private.api_error(400, 'invalid_cust_id', 'Nomor rekening tidak valid');
  end if;
  insert into private.trade_share_excluded_accounts (cust_id, reason, created_by)
  values (v_cust, v_reason, v_me)
  on conflict (cust_id) do update set reason = excluded.reason;
  perform cs.audit('trade_share.exclude_account', null, null, jsonb_build_object('cust_id', v_cust, 'reason', v_reason));
  perform private.trade_share_refresh_cust(v_cust);
  return cs_api.trade_share_excluded_accounts();
end;
$$;

create or replace function cs_api.trade_share_unexclude_account(p_cust_id text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.manage}');
  v_cust   text := private.integration_cust_id(to_jsonb(p_cust_id));
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  delete from private.trade_share_excluded_accounts where cust_id = v_cust;
  if not found then
    perform private.api_error(404, 'not_excluded', 'Rekening tidak ada di daftar dikecualikan');
  end if;
  perform cs.audit('trade_share.unexclude_account', null, null, jsonb_build_object('cust_id', v_cust, 'reason', v_reason));
  return cs_api.trade_share_excluded_accounts();
end;
$$;

create or replace function cs_api.trade_share_pilot_invites()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('profile', cs.trade_share_profile_ref(i.profile_id),
                                                       'created_by', i.created_by, 'created_at', i.created_at)
                                    order by i.created_at desc)
                   from private.trade_share_pilot_invites i), '[]');
end;
$$;

create or replace function cs_api.trade_share_set_pilot_invite(p_profile uuid, p_invited boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.manage}');
begin
  if not exists (select 1 from public.profiles p where p.id = p_profile and p.deleted_at is null and not p.is_guest) then
    perform private.api_error(404, 'profile_not_found', 'Profil tidak ditemukan');
  end if;
  if coalesce(p_invited, false) then
    insert into private.trade_share_pilot_invites (profile_id, created_by) values (p_profile, v_me)
    on conflict (profile_id) do nothing;
  else
    delete from private.trade_share_pilot_invites where profile_id = p_profile;
  end if;
  perform cs.audit('trade_share.pilot_invite', null, p_profile, jsonb_build_object('invited', coalesce(p_invited, false)));
  return cs_api.trade_share_pilot_invites();
end;
$$;

create or replace function cs.trade_share_setting_keys()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['trade_share.enabled', 'trade_share.pilot_only', 'trade_share.min_account_age_days',
               'trade_share.reapply_cooldown_days', 'trade_share.min_delay_minutes', 'trade_share.max_delay_minutes',
               'trade_share.force_hide_price', 'trade_share.force_hide_lot', 'trade_share.four_eyes',
               'trade_share.max_subscriptions', 'trade_share.request_expiry_days',
               'trade_share.review_subscriber_threshold', 'trade_share.lot_size', 'trade_share.boards'];
$$;

create or replace function cs_api.trade_share_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('key', s.key, 'value', s.value, 'description', s.description,
                                                       'version', s.version, 'updated_at', s.updated_at,
                                                       'updated_by', s.updated_by)
                                    order by array_position(cs.trade_share_setting_keys(), s.key))
                   from cs.cs_settings s where s.key = any (cs.trade_share_setting_keys())), '[]');
end;
$$;

create or replace function cs.trade_share_check_setting(p_key text, p_value jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_num numeric;
begin
  if p_key in ('trade_share.min_account_age_days', 'trade_share.reapply_cooldown_days',
               'trade_share.min_delay_minutes', 'trade_share.max_delay_minutes', 'trade_share.max_subscriptions',
               'trade_share.request_expiry_days', 'trade_share.review_subscriber_threshold', 'trade_share.lot_size') then
    if jsonb_typeof(p_value) <> 'number' then
      perform private.api_error(400, 'invalid_setting', 'Nilai harus angka');
    end if;
    v_num := (p_value #>> '{}')::numeric;
    if v_num <> trunc(v_num)
       or (p_key = 'trade_share.min_account_age_days' and v_num not between 0 and 3650)
       or (p_key = 'trade_share.reapply_cooldown_days' and v_num not between 0 and 3650)
       or (p_key = 'trade_share.min_delay_minutes' and v_num not between 1 and 1440)
       or (p_key = 'trade_share.max_delay_minutes' and v_num not between 1 and 1440)
       or (p_key = 'trade_share.max_subscriptions' and v_num not between 1 and 500)
       or (p_key = 'trade_share.request_expiry_days' and v_num not between 1 and 90)
       or (p_key = 'trade_share.review_subscriber_threshold' and v_num not between 1 and 10000000)
       or (p_key = 'trade_share.lot_size' and v_num not between 1 and 100000) then
      perform private.api_error(400, 'invalid_setting', 'Nilai di luar batas');
    end if;
  elsif p_key = 'trade_share.boards' then
    if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) = 0
       or exists (select 1 from jsonb_array_elements(p_value) b
                   where jsonb_typeof(b) <> 'string' or b #>> '{}' not in ('RG', 'TN', 'NG', 'ADV')) then
      perform private.api_error(400, 'invalid_setting', 'Board harus berisi RG, TN, NG, atau ADV');
    end if;
  end if;
end;
$$;

create or replace function cs_api.trade_share_update_setting(p_key text, p_value jsonb, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.manage}');
  v_reason text := private.trade_share_reason(p_reason, true);
  v_old    jsonb := cs.setting(p_key);
  v_min    integer;
  v_max    integer;
begin
  if p_key is null or not (p_key = any (cs.trade_share_setting_keys())) then
    perform private.api_error(404, 'setting_not_found', 'Pengaturan tidak dikenal');
  end if;
  perform cs.trade_share_check_setting(p_key, p_value);
  perform cs.set_setting(p_key, p_value, v_me);
  v_min := private.trade_share_int('trade_share.min_delay_minutes', 15);
  v_max := private.trade_share_int('trade_share.max_delay_minutes', 240);
  if v_min > v_max then
    perform private.api_error(400, 'invalid_setting', 'Jeda minimum tidak boleh melebihi jeda maksimum');
  end if;
  if p_key = 'trade_share.min_delay_minutes' then
    with changed as (
      update private.trade_sharers set delay_minutes = v_min, updated_at = now()
       where delay_minutes < v_min
       returning profile_id, status)
    insert into private.trade_share_events (profile_id, action, actor_kind, actor_id, from_status, to_status, details)
    select c.profile_id, 'delay_raised', 'staff', v_me, c.status, c.status, jsonb_build_object('delay_minutes', v_min)
    from changed c;
  end if;
  perform cs.audit('trade_share.setting', null, null,
                   jsonb_build_object('key', p_key, 'from', v_old, 'to', p_value, 'reason', v_reason));
  return cs_api.trade_share_settings();
end;
$$;

revoke execute on function cs.trade_permission_codes() from public;
revoke execute on function cs.has_trade(text[]) from public;
revoke execute on function cs.require_trade(text[]) from public;
revoke execute on function cs.trade_share_profile_ref(uuid) from public;
revoke execute on function cs.trade_share_account_review(uuid) from public;
revoke execute on function cs.trade_share_item(private.trade_sharers) from public;
revoke execute on function cs.trade_share_setting_keys() from public;
revoke execute on function cs.trade_share_check_setting(text, jsonb) from public;
revoke execute on function private.trade_share_bool(text) from public;
revoke execute on function private.trade_share_int(text, integer) from public;
revoke execute on function private.trade_share_enabled() from public;
revoke execute on function private.trade_share_reason(text, boolean) from public;
revoke execute on function private.trade_share_log(uuid, text, text, uuid, text, text, text, jsonb) from public;
revoke execute on function private.trade_share_latest_document(text) from public;
revoke execute on function private.trade_share_account_state(uuid, text) from public;
revoke execute on function private.trade_share_candidate_accounts(uuid) from public;
revoke execute on function private.trade_share_eligibility(uuid) from public;
revoke execute on function private.trade_share_subscriber_counts(uuid) from public;
revoke execute on function private.trade_share_status_view(uuid) from public;
revoke execute on function private.trade_share_refresh(uuid) from public;
revoke execute on function private.trade_share_refresh_cust(text) from public;
revoke execute on function private.trade_share_links_changed() from public;
revoke execute on function private.trade_share_excluded_changed() from public;
revoke execute on function private.trade_share_forget() from public;
revoke execute on function private.trade_share_clean_accounts(text[]) from public;
revoke execute on function private.trade_share_check_accounts(uuid, text[], text[]) from public;
revoke execute on function private.trade_share_check_values(integer, text) from public;
revoke execute on function cs.trade_share_detail_view(uuid) from public;
revoke execute on function private.trade_share_set_accounts(uuid, text[]) from public;
revoke execute on function private.trade_share_end_suspensions() from public;

revoke execute on function public.get_trade_share_status() from public, anon;
grant execute on function public.get_trade_share_status() to authenticated;
revoke execute on function public.submit_trade_share_application(text[], boolean, boolean, integer, text, uuid) from public, anon;
grant execute on function public.submit_trade_share_application(text[], boolean, boolean, integer, text, uuid) to authenticated;
revoke execute on function public.update_trade_share_settings(text[], boolean, boolean, integer, text, boolean) from public, anon;
grant execute on function public.update_trade_share_settings(text[], boolean, boolean, integer, text, boolean) to authenticated;
revoke execute on function public.pause_trade_share() from public, anon;
grant execute on function public.pause_trade_share() to authenticated;
revoke execute on function public.resume_trade_share() from public, anon;
grant execute on function public.resume_trade_share() to authenticated;
revoke execute on function public.withdraw_trade_share() from public, anon;
grant execute on function public.withdraw_trade_share() to authenticated;

revoke execute on function cs_api.admin_set_trade_permissions(uuid, text[]) from public;
grant execute on function cs_api.admin_set_trade_permissions(uuid, text[]) to authenticated;
revoke execute on function cs_api.trade_share_list(text, timestamptz, integer) from public;
grant execute on function cs_api.trade_share_list(text, timestamptz, integer) to authenticated;
revoke execute on function cs_api.trade_share_detail(uuid) from public;
grant execute on function cs_api.trade_share_detail(uuid) to authenticated;
revoke execute on function cs_api.trade_share_decide(uuid, text, text) from public;
grant execute on function cs_api.trade_share_decide(uuid, text, text) to authenticated;
revoke execute on function cs_api.trade_share_suspend(uuid, text, timestamptz) from public;
grant execute on function cs_api.trade_share_suspend(uuid, text, timestamptz) to authenticated;
revoke execute on function cs_api.trade_share_reinstate(uuid, text) from public;
grant execute on function cs_api.trade_share_reinstate(uuid, text) to authenticated;
revoke execute on function cs_api.trade_share_revoke(uuid, text) from public;
grant execute on function cs_api.trade_share_revoke(uuid, text) to authenticated;
revoke execute on function cs_api.trade_share_excluded_accounts() from public;
grant execute on function cs_api.trade_share_excluded_accounts() to authenticated;
revoke execute on function cs_api.trade_share_exclude_account(text, text) from public;
grant execute on function cs_api.trade_share_exclude_account(text, text) to authenticated;
revoke execute on function cs_api.trade_share_unexclude_account(text, text) from public;
grant execute on function cs_api.trade_share_unexclude_account(text, text) to authenticated;
revoke execute on function cs_api.trade_share_pilot_invites() from public;
grant execute on function cs_api.trade_share_pilot_invites() to authenticated;
revoke execute on function cs_api.trade_share_set_pilot_invite(uuid, boolean) from public;
grant execute on function cs_api.trade_share_set_pilot_invite(uuid, boolean) to authenticated;
revoke execute on function cs_api.trade_share_settings() from public;
grant execute on function cs_api.trade_share_settings() to authenticated;
revoke execute on function cs_api.trade_share_update_setting(text, jsonb, text) from public;
grant execute on function cs_api.trade_share_update_setting(text, jsonb, text) to authenticated;
