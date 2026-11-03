insert into cs.cs_settings (key, value, description) values
  ('compliance.policy_four_eyes', 'true',
   'Perubahan kebijakan konten wajib disetujui staf Kepatuhan lain (bukan pembuatnya) sebelum berlaku')
on conflict (key) do nothing;

create or replace function cs.policy_four_eyes()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((cs.setting('compliance.policy_four_eyes') #>> '{}')::boolean, true);
$$;

create or replace function private.policy_sections()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['banned_words', 'content_rules', 'blocked_domains', 'allowed_domains', 'allowlist', 'promo_phrases',
               'settings', 'image_thresholds'];
$$;

create or replace function private.policy_setting_key(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key = 'safety.new_account_days' or p_key like 'manipulation.%'
      or p_key in ('rooms.busy_slow_mode', 'rooms.busy_windows');
$$;

create or replace function private.policy_snapshot()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'banned_words', coalesce((select jsonb_object_agg(w.word, w.action) from public.banned_words w), '{}'),
    'content_rules', coalesce((select jsonb_object_agg(r.category, jsonb_build_object('action', r.action, 'scope', r.scope))
                               from cs.content_rules r), '{}'),
    'blocked_domains', coalesce((select jsonb_object_agg(b.domain, jsonb_strip_nulls(jsonb_build_object(
                                   'match', b.match, 'category', b.category, 'action', b.action, 'note', b.note)))
                                 from cs.blocked_domains b), '{}'),
    'allowed_domains', coalesce((select jsonb_object_agg(a.domain, jsonb_strip_nulls(jsonb_build_object('note', a.note)))
                                 from cs.allowed_domains a), '{}'),
    'allowlist', coalesce((select jsonb_object_agg(t.term, true) from cs.policy_allowlist t), '{}'),
    'promo_phrases', coalesce((select jsonb_object_agg(p.phrase, true) from cs.promo_phrases p), '{}'),
    'settings', coalesce((select jsonb_object_agg(s.key, s.value) from private.settings s
                          where private.policy_setting_key(s.key)), '{}'),
    'image_thresholds', coalesce((select m.thresholds from private.media_moderation m where m.singleton), '{}'));
$$;

create or replace function private.policy_diff(p_old jsonb, p_new jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  with d as (
    select s.section, x.key,
           case when x.old_value is null then 'added' when x.new_value is null then 'removed' else 'changed' end as op,
           x.old_value, x.new_value,
           row_number() over (partition by s.section order by x.key) as n
    from unnest(private.policy_sections()) s(section)
    cross join lateral (
      select coalesce(o.key, w.key) as key, o.value as old_value, w.value as new_value
      from jsonb_each(coalesce(p_old -> s.section, '{}')) o
      full join jsonb_each(coalesce(p_new -> s.section, '{}')) w on w.key = o.key
      where o.value is distinct from w.value
    ) x
  ), g as (
    select d.section, count(*) as total,
           jsonb_build_object(
             'added', count(*) filter (where d.op = 'added'),
             'removed', count(*) filter (where d.op = 'removed'),
             'changed', count(*) filter (where d.op = 'changed'),
             'items', coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                           'key', d.key, 'op', d.op, 'from', d.old_value, 'to', d.new_value))
                                         order by d.key) filter (where d.n <= 200), '[]')) as summary
    from d
    group by d.section
  )
  select jsonb_build_object('total', coalesce(sum(g.total), 0)::integer,
                            'sections', coalesce(jsonb_object_agg(g.section, g.summary), '{}'))
  from g;
$$;

create or replace function private.policy_diff_counts(p_diff jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('total', coalesce(p_diff -> 'total', '0'),
                            'sections', coalesce((select jsonb_object_agg(e.key, e.value - 'items')
                                                  from jsonb_each(coalesce(p_diff -> 'sections', '{}')) e), '{}'));
$$;

create or replace function private.policy_rebase(p_base jsonb, p_draft jsonb, p_live jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_object_agg(s.section, coalesce((
    select jsonb_object_agg(m.key, m.value)
    from (
      select l.key, l.value
      from jsonb_each(coalesce(p_live -> s.section, '{}')) l
      where (p_base -> s.section -> l.key) is not distinct from (p_draft -> s.section -> l.key)
      union all
      select d.key, d.value
      from jsonb_each(coalesce(p_draft -> s.section, '{}')) d
      where (p_base -> s.section -> d.key) is distinct from d.value
    ) m), '{}'))
  from unnest(private.policy_sections()) s(section);
$$;

create or replace function private.policy_check_limits(p_snapshot jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_section text;
  v_limit   integer;
  v_label   text;
begin
  for v_section, v_limit, v_label in
    select x.s, x.l, x.t
    from (values ('banned_words', cs.banned_word_limit(), 'kata terlarang'), ('blocked_domains', 5000, 'domain diblokir'),
                 ('allowed_domains', 1000, 'domain tepercaya'), ('allowlist', 500, 'pengecualian'),
                 ('promo_phrases', 500, 'frasa promosi')) x(s, l, t)
  loop
    if (select count(*) from jsonb_object_keys(coalesce(p_snapshot -> v_section, '{}'))) > v_limit then
      perform private.api_error(400, 'policy_limit', 'Daftar ' || v_label || ' melebihi batas ' || v_limit);
    end if;
  end loop;
end;
$$;

create or replace function private.policy_load(p_target jsonb, p_actor uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_live jsonb := private.policy_snapshot();
  v_part jsonb;
begin
  v_part := coalesce(p_target -> 'banned_words', '{}');
  if v_live -> 'banned_words' is distinct from v_part then
    delete from public.banned_words w where not v_part ? w.word;
    insert into public.banned_words (word, action)
    select e.key, e.value #>> '{}' from jsonb_each(v_part) e
    on conflict (word) do update set action = excluded.action
    where public.banned_words.action <> excluded.action;
  end if;

  v_part := coalesce(p_target -> 'content_rules', '{}');
  if v_live -> 'content_rules' is distinct from v_part then
    update cs.content_rules r
       set action = e.value ->> 'action', scope = e.value ->> 'scope', updated_at = now(), updated_by = p_actor
      from jsonb_each(v_part) e
     where r.category = e.key and (r.action, r.scope) is distinct from (e.value ->> 'action', e.value ->> 'scope');
  end if;

  v_part := coalesce(p_target -> 'blocked_domains', '{}');
  if v_live -> 'blocked_domains' is distinct from v_part then
    delete from cs.blocked_domains b where not v_part ? b.domain;
    insert into cs.blocked_domains (domain, match, category, action, note, created_by)
    select e.key, coalesce(e.value ->> 'match', 'domain'), e.value ->> 'category', e.value ->> 'action', e.value ->> 'note',
           p_actor
    from jsonb_each(v_part) e
    on conflict (domain) do update
      set match = excluded.match, category = excluded.category, action = excluded.action, note = excluded.note
    where (cs.blocked_domains.match, cs.blocked_domains.category, cs.blocked_domains.action, cs.blocked_domains.note)
          is distinct from (excluded.match, excluded.category, excluded.action, excluded.note);
  end if;

  v_part := coalesce(p_target -> 'allowed_domains', '{}');
  if v_live -> 'allowed_domains' is distinct from v_part then
    delete from cs.allowed_domains a where not v_part ? a.domain;
    insert into cs.allowed_domains (domain, note, created_by)
    select e.key, e.value ->> 'note', p_actor from jsonb_each(v_part) e
    on conflict (domain) do update set note = excluded.note
    where cs.allowed_domains.note is distinct from excluded.note;
  end if;

  v_part := coalesce(p_target -> 'allowlist', '{}');
  if v_live -> 'allowlist' is distinct from v_part then
    delete from cs.policy_allowlist t where not v_part ? t.term;
    insert into cs.policy_allowlist (term, created_by)
    select e.key, p_actor from jsonb_object_keys(v_part) e(key)
    on conflict (term) do nothing;
  end if;

  v_part := coalesce(p_target -> 'promo_phrases', '{}');
  if v_live -> 'promo_phrases' is distinct from v_part then
    delete from cs.promo_phrases p where not v_part ? p.phrase;
    insert into cs.promo_phrases (phrase, created_by)
    select e.key, p_actor from jsonb_object_keys(v_part) e(key)
    on conflict (phrase) do nothing;
  end if;

  v_part := coalesce(p_target -> 'settings', '{}');
  if v_live -> 'settings' is distinct from v_part then
    update private.settings s
       set value = e.value, updated_at = now()
      from jsonb_each(v_part) e
     where s.key = e.key and private.policy_setting_key(s.key) and s.value is distinct from e.value;
  end if;

  if p_target ? 'image_thresholds' and v_live -> 'image_thresholds' is distinct from p_target -> 'image_thresholds' then
    update private.media_moderation m
       set thresholds = p_target -> 'image_thresholds', revision = m.revision + 1, updated_by = p_actor, updated_at = now()
     where m.singleton;
  end if;
end;
$$;

create table cs.policy_versions (
  version       integer primary key,
  snapshot      jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  diff          jsonb not null,
  source        text not null check (source in ('baseline', 'direct', 'change', 'rollback', 'system')),
  reason        text check (char_length(reason) <= 500),
  change_id     bigint,
  restored_from integer references cs.policy_versions (version),
  created_by    uuid,
  created_at    timestamptz not null default now()
);
alter table cs.policy_versions enable row level security;

create trigger policy_versions_append_only
  before update or delete on cs.policy_versions
  for each row execute function cs.reject_change();
create trigger policy_versions_no_truncate
  before truncate on cs.policy_versions
  for each statement execute function cs.reject_change();

create table cs.policy_changes (
  id              bigint generated always as identity primary key,
  kind            text not null check (kind in ('edit', 'rollback')),
  status          text not null default 'draft' check (status in ('draft', 'pending', 'approved', 'rejected', 'withdrawn')),
  base_version    integer not null references cs.policy_versions (version),
  snapshot        jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  rollback_to     integer references cs.policy_versions (version),
  reason          text check (char_length(reason) between 5 and 500),
  created_by      uuid not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  submitted_at    timestamptz,
  decided_by      uuid,
  decided_at      timestamptz,
  decision_note   text check (char_length(decision_note) <= 500),
  applied_version integer references cs.policy_versions (version),
  constraint policy_changes_reason check (status = 'draft' or reason is not null),
  constraint policy_changes_rollback check ((kind = 'rollback') = (rollback_to is not null)),
  constraint policy_changes_decided check ((status in ('approved', 'rejected')) = (decided_at is not null))
);
create unique index policy_changes_one_draft on cs.policy_changes (created_by) where status = 'draft';
create index policy_changes_status_idx on cs.policy_changes (status, id desc);
alter table cs.policy_changes enable row level security;

alter table cs.policy_versions
  add constraint policy_versions_change_fk foreign key (change_id) references cs.policy_changes (id);

insert into cs.policy_versions (version, snapshot, diff, source, reason)
select 1, s.snap, private.policy_diff('{}', s.snap), 'baseline', 'Versi awal saat versi kebijakan diaktifkan'
from (select private.policy_snapshot() as snap) s;

create table private.policy_pending (
  txid bigint primary key
);
alter table private.policy_pending enable row level security;

create or replace function private.policy_current_version()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select max(v.version) from cs.policy_versions v;
$$;

create or replace function private.policy_commit(p_source text, p_reason text, p_change bigint, p_restored integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := cs.current_agent_id();
  v_last    cs.policy_versions;
  v_snap    jsonb;
  v_version integer;
begin
  delete from private.policy_pending where txid = txid_current();
  perform pg_advisory_xact_lock(hashtext('cs.policy_versions'));
  v_snap := private.policy_snapshot();
  select * into v_last from cs.policy_versions order by version desc limit 1;
  if v_last.snapshot is not distinct from v_snap then
    return null;
  end if;
  v_version := coalesce(v_last.version, 0) + 1;
  insert into cs.policy_versions (version, snapshot, diff, source, reason, change_id, restored_from, created_by)
  values (v_version, v_snap, private.policy_diff(coalesce(v_last.snapshot, '{}'), v_snap),
          coalesce(p_source, case when v_actor is null then 'system' else 'direct' end), p_reason, p_change, p_restored,
          v_actor);
  return v_version;
end;
$$;

create or replace function private.policy_touched()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mode text := coalesce(current_setting('cs.policy_mode', true), '');
begin
  if v_mode = 'sandbox' then
    return null;
  end if;
  if v_mode <> 'apply' and cs.policy_four_eyes() and cs.current_agent_id() is not null then
    perform private.api_error(409, 'policy_review_required',
      'Perubahan kebijakan konten harus lewat draf dan disetujui staf Kepatuhan lain');
  end if;
  insert into private.policy_pending (txid) values (txid_current()) on conflict (txid) do nothing;
  return null;
end;
$$;

create or replace function private.policy_pending_commit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from private.policy_pending p where p.txid = new.txid) then
    perform private.policy_commit(null, null, null, null);
  end if;
  return null;
end;
$$;

create constraint trigger policy_pending_commit
  after insert on private.policy_pending
  deferrable initially deferred
  for each row execute function private.policy_pending_commit();

create trigger banned_words_32_policy_version
  after insert or update or delete or truncate on public.banned_words
  for each statement execute function private.policy_touched();
create trigger content_rules_32_policy_version
  after insert or update or delete or truncate on cs.content_rules
  for each statement execute function private.policy_touched();
create trigger blocked_domains_32_policy_version
  after insert or update or delete or truncate on cs.blocked_domains
  for each statement execute function private.policy_touched();
create trigger allowed_domains_32_policy_version
  after insert or update or delete or truncate on cs.allowed_domains
  for each statement execute function private.policy_touched();
create trigger policy_allowlist_32_policy_version
  after insert or update or delete or truncate on cs.policy_allowlist
  for each statement execute function private.policy_touched();
create trigger promo_phrases_32_policy_version
  after insert or update or delete or truncate on cs.promo_phrases
  for each statement execute function private.policy_touched();
create trigger media_moderation_32_policy_version
  after insert or update or delete on private.media_moderation
  for each statement execute function private.policy_touched();
create trigger settings_32_policy_version
  after update of value on private.settings
  for each row when (private.policy_setting_key(new.key) and new.value is distinct from old.value)
  execute function private.policy_touched();
create trigger settings_33_policy_version_insert
  after insert on private.settings
  for each row when (private.policy_setting_key(new.key))
  execute function private.policy_touched();

create or replace function private.policy_read_call(p_fn text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_fn in ('compliance_banned_words', 'compliance_content_rules', 'compliance_image_thresholds',
                  'compliance_manipulation_settings');
$$;

create or replace function private.policy_call_known(p_fn text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select private.policy_read_call(p_fn) or p_fn in (
    'compliance_add_banned_word', 'compliance_set_banned_word_action', 'compliance_delete_banned_word',
    'compliance_import_banned_words', 'compliance_set_content_rule', 'compliance_save_blocked_domain',
    'compliance_delete_blocked_domain', 'compliance_save_allowed_domain', 'compliance_delete_allowed_domain',
    'compliance_add_allowlist_term', 'compliance_delete_allowlist_term', 'compliance_add_promo_phrase',
    'compliance_delete_promo_phrase', 'compliance_set_new_account_days', 'compliance_set_image_thresholds',
    'compliance_set_manipulation_settings');
$$;

create or replace function private.policy_dispatch(p_fn text, p_args jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a jsonb := coalesce(p_args, '{}');
begin
  case p_fn
    when 'compliance_banned_words' then return cs_api.compliance_banned_words();
    when 'compliance_add_banned_word' then return cs_api.compliance_add_banned_word(a ->> 'p_word', a ->> 'p_action');
    when 'compliance_set_banned_word_action' then
      return cs_api.compliance_set_banned_word_action(a ->> 'p_word', a ->> 'p_action');
    when 'compliance_delete_banned_word' then return cs_api.compliance_delete_banned_word(a ->> 'p_word');
    when 'compliance_import_banned_words' then return cs_api.compliance_import_banned_words(a -> 'p_rows');
    when 'compliance_content_rules' then return cs_api.compliance_content_rules();
    when 'compliance_set_content_rule' then
      return cs_api.compliance_set_content_rule(a ->> 'p_category', a ->> 'p_action', a ->> 'p_scope');
    when 'compliance_save_blocked_domain' then
      return cs_api.compliance_save_blocked_domain(a ->> 'p_domain', a ->> 'p_category', a ->> 'p_action', a ->> 'p_note',
                                                   coalesce(a ->> 'p_match', 'domain'));
    when 'compliance_delete_blocked_domain' then return cs_api.compliance_delete_blocked_domain(a ->> 'p_domain');
    when 'compliance_save_allowed_domain' then
      return cs_api.compliance_save_allowed_domain(a ->> 'p_domain', a ->> 'p_note');
    when 'compliance_delete_allowed_domain' then return cs_api.compliance_delete_allowed_domain(a ->> 'p_domain');
    when 'compliance_add_allowlist_term' then return cs_api.compliance_add_allowlist_term(a ->> 'p_term');
    when 'compliance_delete_allowlist_term' then return cs_api.compliance_delete_allowlist_term(a ->> 'p_term');
    when 'compliance_add_promo_phrase' then return cs_api.compliance_add_promo_phrase(a ->> 'p_phrase');
    when 'compliance_delete_promo_phrase' then return cs_api.compliance_delete_promo_phrase(a ->> 'p_phrase');
    when 'compliance_set_new_account_days' then
      if jsonb_typeof(a -> 'p_days') is distinct from 'number' then
        perform private.api_error(400, 'invalid_setting', 'Masa akun baru 0–30 hari');
      end if;
      return cs_api.compliance_set_new_account_days((a ->> 'p_days')::numeric::integer);
    when 'compliance_image_thresholds' then return cs_api.compliance_image_thresholds();
    when 'compliance_set_image_thresholds' then
      return cs_api.compliance_set_image_thresholds(a -> 'p_thresholds', a ->> 'p_note');
    when 'compliance_manipulation_settings' then return cs_api.compliance_manipulation_settings();
    when 'compliance_set_manipulation_settings' then
      return cs_api.compliance_set_manipulation_settings(a -> 'p_values');
    else
      perform private.api_error(400, 'invalid_policy_call', 'Aksi kebijakan tidak dikenal');
  end case;
  return null;
end;
$$;

create or replace function private.policy_eval(p_text text, p_surface text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_body   text;
  v_banned integer := 0;
  v_result jsonb;
  v_level  integer;
begin
  begin
    v_body := private.apply_content_policy(p_text);
    if v_body is distinct from p_text then
      v_banned := 1;
    end if;
  exception when sqlstate 'PT422' then
    v_banned := 3;
    v_body := p_text;
  end;
  v_result := private.evaluate_content(v_body, p_surface);
  v_level := greatest(v_banned, array_position(array['allow', 'censor', 'hold', 'block'], v_result ->> 'action') - 1);
  return jsonb_build_object(
    'action', (array['allow', 'censor', 'hold', 'block'])[v_level + 1],
    'categories', case when v_banned > 0 then coalesce(v_result -> 'categories', '[]') || '["banned_words"]'::jsonb
                       else coalesce(v_result -> 'categories', '[]') end);
end;
$$;

create or replace function private.policy_eval_items(p_items jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(private.policy_eval(i.item ->> 'body', i.item ->> 'surface') order by i.o), '[]')
  from jsonb_array_elements(coalesce(p_items, '[]')) with ordinality i(item, o);
$$;

create or replace function private.policy_sandbox(p_snapshot jsonb, p_fn text, p_args jsonb, p_capture boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_out jsonb;
begin
  begin
    perform set_config('cs.policy_mode', 'sandbox', true);
    perform private.policy_load(p_snapshot, null);
    if p_fn = 'eval' then
      v_out := jsonb_build_object('result', private.policy_eval_items(p_args));
    else
      v_out := jsonb_build_object('result', private.policy_dispatch(p_fn, p_args));
    end if;
    if p_capture then
      v_out := v_out || jsonb_build_object('snapshot', private.policy_snapshot());
    end if;
    raise exception using errcode = 'PSBOX';
  exception when sqlstate 'PSBOX' then
    null;
  end;
  return v_out;
end;
$$;

create or replace function private.policy_my_draft(p_me uuid, p_create boolean)
returns cs.policy_changes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_draft   cs.policy_changes;
  v_current integer := private.policy_current_version();
begin
  select * into v_draft from cs.policy_changes c where c.created_by = p_me and c.status = 'draft' for update;
  if found then
    if v_draft.base_version <> v_current then
      update cs.policy_changes c
         set snapshot = private.policy_rebase((select v.snapshot from cs.policy_versions v where v.version = c.base_version),
                                              c.snapshot, private.policy_snapshot()),
             base_version = v_current
       where c.id = v_draft.id
      returning * into v_draft;
    end if;
    return v_draft;
  end if;
  if not p_create then
    return v_draft;
  end if;
  insert into cs.policy_changes (kind, status, base_version, snapshot, created_by)
  values ('edit', 'draft', v_current, private.policy_snapshot(), p_me)
  on conflict (created_by) where status = 'draft' do nothing;
  select * into v_draft from cs.policy_changes c where c.created_by = p_me and c.status = 'draft' for update;
  return v_draft;
end;
$$;

create or replace function private.policy_target(p_change cs.policy_changes)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_change.kind = 'rollback' then p_change.snapshot
    else private.policy_rebase((select v.snapshot from cs.policy_versions v where v.version = p_change.base_version),
                               p_change.snapshot, private.policy_snapshot()) end;
$$;

create or replace function private.policy_apply_change(p_id bigint, p_actor uuid, p_note text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_change  cs.policy_changes;
  v_current integer := private.policy_current_version();
  v_target  jsonb;
  v_version integer;
begin
  select * into v_change from cs.policy_changes c where c.id = p_id for update;
  if v_change.kind = 'rollback' and v_change.base_version <> v_current then
    perform private.api_error(409, 'policy_stale',
      'Kebijakan sudah berubah sejak pemulihan ini diajukan. Ajukan ulang pemulihan dari riwayat versi.');
  end if;
  v_target := private.policy_target(v_change);
  perform private.policy_check_limits(v_target);
  if (private.policy_diff(private.policy_snapshot(), v_target) ->> 'total')::integer = 0 then
    perform private.api_error(409, 'policy_no_change', 'Isi perubahan ini sudah berlaku. Tarik atau tolak permintaannya.');
  end if;
  perform set_config('cs.policy_mode', 'apply', true);
  perform private.policy_load(v_target, p_actor);
  perform set_config('cs.policy_mode', '', true);
  v_version := private.policy_commit(case v_change.kind when 'rollback' then 'rollback' else 'change' end,
                                     v_change.reason, v_change.id, v_change.rollback_to);
  update cs.policy_changes c
     set status = 'approved', decided_by = p_actor, decided_at = now(), decision_note = p_note,
         applied_version = v_version, updated_at = now()
   where c.id = p_id;
  if v_change.kind = 'rollback' then
    perform cs.audit('policy.rollback', null, null,
      jsonb_build_object('change', p_id, 'from', v_current, 'to', v_change.rollback_to, 'version', v_version,
                         'reason', v_change.reason));
  end if;
  return v_version;
end;
$$;

create or replace function cs.policy_version_ref(p_version cs.policy_versions)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'version', p_version.version, 'source', p_version.source, 'reason', p_version.reason,
    'change_id', p_version.change_id, 'restored_from', p_version.restored_from,
    'created_by', cs.staff_ref(p_version.created_by), 'created_at', p_version.created_at,
    'summary', private.policy_diff_counts(p_version.diff),
    'current', p_version.version = private.policy_current_version());
$$;

create or replace function cs.policy_change_view(p_id bigint, p_items boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id, 'kind', c.kind, 'status', c.status, 'base_version', c.base_version, 'rollback_to', c.rollback_to,
    'reason', c.reason, 'created_by', cs.staff_ref(c.created_by), 'created_at', c.created_at,
    'updated_at', c.updated_at, 'submitted_at', c.submitted_at, 'decided_by', cs.staff_ref(c.decided_by),
    'decided_at', c.decided_at, 'decision_note', c.decision_note, 'applied_version', c.applied_version,
    'mine', c.created_by is not distinct from cs.current_agent_id(),
    'can_decide', c.status = 'pending' and cs.has_role('{compliance}')
                  and (not cs.policy_four_eyes() or c.created_by is distinct from cs.current_agent_id()),
    'stale', c.status = 'pending' and c.kind = 'rollback' and c.base_version <> private.policy_current_version(),
    'diff', case when p_items then d.diff else private.policy_diff_counts(d.diff) end)
  from cs.policy_changes c
  cross join lateral (
    select private.policy_diff((select v.snapshot from cs.policy_versions v where v.version = c.base_version),
                               c.snapshot) as diff
  ) d
  where c.id = p_id;
$$;

create or replace function cs.policy_reason(p_reason text, p_code text, p_label text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if char_length(coalesce(v_reason, '')) not between 5 and 500 then
    perform private.api_error(400, p_code, p_label || ' 5–500 karakter');
  end if;
  return v_reason;
end;
$$;

create or replace function cs_api.compliance_policy_call(p_fn text, p_args jsonb default '{}')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_read  boolean := private.policy_read_call(p_fn);
  v_draft cs.policy_changes;
  v_out   jsonb;
begin
  if p_fn is null or not private.policy_call_known(p_fn) then
    perform private.api_error(400, 'invalid_policy_call', 'Aksi kebijakan tidak dikenal');
  end if;
  v_draft := private.policy_my_draft(v_me, not v_read);
  if v_draft.id is null then
    return private.policy_dispatch(p_fn, p_args);
  end if;
  v_out := private.policy_sandbox(v_draft.snapshot, p_fn, p_args, not v_read);
  if not v_read then
    update cs.policy_changes c set snapshot = v_out -> 'snapshot', updated_at = now() where c.id = v_draft.id;
    v_draft.snapshot := v_out -> 'snapshot';
  end if;
  return coalesce(v_out -> 'result', '{}') || jsonb_build_object('policy_draft', jsonb_build_object(
    'id', v_draft.id,
    'changes', (private.policy_diff(private.policy_snapshot(), v_draft.snapshot) ->> 'total')::integer));
end;
$$;

create or replace function cs_api.compliance_policy_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_draft cs.policy_changes := private.policy_my_draft(v_me, false);
  v_live  jsonb := private.policy_snapshot();
begin
  return jsonb_build_object(
    'four_eyes', cs.policy_four_eyes(),
    'current', (select cs.policy_version_ref(v) from cs.policy_versions v order by v.version desc limit 1),
    'draft', case when v_draft.id is not null then jsonb_build_object(
               'id', v_draft.id, 'base_version', v_draft.base_version, 'created_at', v_draft.created_at,
               'updated_at', v_draft.updated_at, 'diff', private.policy_diff(v_live, v_draft.snapshot)) end,
    'pending', (select count(*) from cs.policy_changes c where c.status = 'pending'),
    'pending_mine', (select count(*) from cs.policy_changes c where c.status = 'pending' and c.created_by = v_me),
    'pending_to_review', (select count(*) from cs.policy_changes c
                          where c.status = 'pending' and cs.has_role('{compliance}')
                            and (not cs.policy_four_eyes() or c.created_by <> v_me)));
end;
$$;

create or replace function cs_api.compliance_policy_discard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  delete from cs.policy_changes c where c.created_by = v_me and c.status = 'draft';
  return cs_api.compliance_policy_state();
end;
$$;

create or replace function cs_api.compliance_policy_submit(p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_reason  text := cs.policy_reason(p_reason, 'invalid_reason', 'Alasan perubahan');
  v_draft   cs.policy_changes := private.policy_my_draft(v_me, false);
  v_changes integer;
  v_version integer;
begin
  if v_draft.id is null then
    perform private.api_error(404, 'policy_draft_not_found', 'Belum ada draf perubahan kebijakan');
  end if;
  v_changes := (private.policy_diff(private.policy_snapshot(), v_draft.snapshot) ->> 'total')::integer;
  if v_changes = 0 then
    perform private.api_error(400, 'policy_no_change', 'Draf belum berisi perubahan');
  end if;
  perform private.policy_check_limits(v_draft.snapshot);
  update cs.policy_changes c
     set status = 'pending', reason = v_reason, submitted_at = now(), updated_at = now()
   where c.id = v_draft.id;
  perform cs.audit('policy_change.submit', null, null,
    jsonb_build_object('change', v_draft.id, 'kind', 'edit', 'reason', v_reason, 'changes', v_changes));
  if not cs.policy_four_eyes() then
    v_version := private.policy_apply_change(v_draft.id, v_me, null);
    perform cs.audit('policy_change.apply', null, null,
      jsonb_build_object('change', v_draft.id, 'version', v_version, 'reason', v_reason));
  end if;
  return cs.policy_change_view(v_draft.id, true);
end;
$$;

create or replace function cs_api.compliance_policy_changes(p_status text default 'pending', p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance,cs_super_admin}');
begin
  if p_status is not null and p_status not in ('pending', 'decided') then
    perform private.api_error(400, 'invalid_status', 'Status: pending atau decided');
  end if;
  return coalesce((
    select jsonb_agg(cs.policy_change_view(c.id, false) order by c.id desc)
    from (
      select c.id from cs.policy_changes c
      where c.status <> 'draft'
        and (p_status is null or (p_status = 'pending' and c.status = 'pending')
             or (p_status = 'decided' and c.status in ('approved', 'rejected', 'withdrawn')))
      order by c.id desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) c), '[]');
end;
$$;

create or replace function cs_api.compliance_policy_change(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_change cs.policy_changes;
begin
  select * into v_change from cs.policy_changes c where c.id = p_id and c.status <> 'draft';
  if not found then
    perform private.api_error(404, 'policy_change_not_found', 'Permintaan perubahan kebijakan tidak ditemukan');
  end if;
  return cs.policy_change_view(p_id, true) || jsonb_build_object(
    'effective', case when v_change.status = 'pending'
                      then private.policy_diff(private.policy_snapshot(), private.policy_target(v_change)) end);
end;
$$;

create or replace function cs_api.compliance_policy_decide(p_id bigint, p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_note    text := nullif(btrim(coalesce(p_note, '')), '');
  v_change  cs.policy_changes;
  v_version integer;
begin
  if p_approve is null then
    perform private.api_error(400, 'invalid_decision', 'Pilih setujui atau tolak');
  end if;
  if char_length(coalesce(v_note, '')) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 500 karakter');
  end if;
  if not p_approve and char_length(coalesce(v_note, '')) < 5 then
    perform private.api_error(400, 'note_required', 'Alasan penolakan 5–500 karakter');
  end if;
  select * into v_change from cs.policy_changes c where c.id = p_id and c.status <> 'draft' for update;
  if not found then
    perform private.api_error(404, 'policy_change_not_found', 'Permintaan perubahan kebijakan tidak ditemukan');
  end if;
  if v_change.status <> 'pending' then
    perform private.api_error(409, 'policy_change_decided', 'Permintaan ini sudah diputuskan');
  end if;
  if cs.policy_four_eyes() and v_change.created_by = v_me then
    perform private.api_error(403, 'four_eyes', 'Perubahan kebijakan harus disetujui staf Kepatuhan lain, bukan pembuatnya');
  end if;
  if p_approve then
    v_version := private.policy_apply_change(p_id, v_me, v_note);
    perform cs.audit('policy_change.approve', null, null,
      jsonb_build_object('change', p_id, 'kind', v_change.kind, 'version', v_version, 'note', v_note));
  else
    update cs.policy_changes c
       set status = 'rejected', decided_by = v_me, decided_at = now(), decision_note = v_note, updated_at = now()
     where c.id = p_id;
    perform cs.audit('policy_change.reject', null, null,
      jsonb_build_object('change', p_id, 'kind', v_change.kind, 'note', v_note));
  end if;
  return cs.policy_change_view(p_id, true);
end;
$$;

create or replace function cs_api.compliance_policy_withdraw(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_change cs.policy_changes;
begin
  select * into v_change from cs.policy_changes c where c.id = p_id and c.status <> 'draft' for update;
  if not found or v_change.created_by <> v_me then
    perform private.api_error(404, 'policy_change_not_found', 'Permintaan perubahan kebijakan tidak ditemukan');
  end if;
  if v_change.status <> 'pending' then
    perform private.api_error(409, 'policy_change_decided', 'Permintaan ini sudah diputuskan');
  end if;
  update cs.policy_changes c set status = 'withdrawn', updated_at = now() where c.id = p_id;
  perform cs.audit('policy_change.withdraw', null, null, jsonb_build_object('change', p_id, 'kind', v_change.kind));
  return cs.policy_change_view(p_id, true);
end;
$$;

create or replace function cs_api.compliance_policy_versions(p_before integer default null, p_limit integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_rows  jsonb;
  v_last  integer;
begin
  select coalesce(jsonb_agg(cs.policy_version_ref(x.v) order by (x.v).version desc), '[]'), min((x.v).version)
    into v_rows, v_last
  from (
    select v from cs.policy_versions v
    where p_before is null or v.version < p_before
    order by v.version desc
    limit v_limit
  ) x;
  return jsonb_build_object(
    'rows', v_rows,
    'next', case when v_last is not null and exists (select 1 from cs.policy_versions v where v.version < v_last)
                 then v_last end);
end;
$$;

create or replace function cs_api.compliance_policy_version(p_version integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_version cs.policy_versions;
begin
  select * into v_version from cs.policy_versions v where v.version = p_version;
  if not found then
    perform private.api_error(404, 'policy_version_not_found', 'Versi kebijakan tidak ditemukan');
  end if;
  return cs.policy_version_ref(v_version) || jsonb_build_object(
    'diff', v_version.diff,
    'restore', private.policy_diff(private.policy_snapshot(), v_version.snapshot),
    'sizes', (select jsonb_object_agg(s.section, (select count(*) from jsonb_object_keys(coalesce(v_version.snapshot -> s.section, '{}'))))
              from unnest(private.policy_sections()) s(section)));
end;
$$;

create or replace function cs_api.compliance_policy_rollback(p_version integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_reason  text := cs.policy_reason(p_reason, 'invalid_reason', 'Alasan pemulihan');
  v_target  cs.policy_versions;
  v_current integer := private.policy_current_version();
  v_id      bigint;
  v_version integer;
begin
  select * into v_target from cs.policy_versions v where v.version = p_version;
  if not found then
    perform private.api_error(404, 'policy_version_not_found', 'Versi kebijakan tidak ditemukan');
  end if;
  if (private.policy_diff(private.policy_snapshot(), v_target.snapshot) ->> 'total')::integer = 0 then
    perform private.api_error(400, 'policy_no_change', 'Isi versi ini sama dengan kebijakan yang sedang berlaku');
  end if;
  insert into cs.policy_changes (kind, status, base_version, snapshot, rollback_to, reason, created_by, submitted_at)
  values ('rollback', 'pending', v_current, v_target.snapshot, p_version, v_reason, v_me, now())
  returning id into v_id;
  perform cs.audit('policy_change.submit', null, null,
    jsonb_build_object('change', v_id, 'kind', 'rollback', 'to', p_version, 'reason', v_reason));
  if not cs.policy_four_eyes() then
    v_version := private.policy_apply_change(v_id, v_me, null);
  end if;
  return cs.policy_change_view(v_id, true);
end;
$$;

create or replace function private.media_decide(p_scores jsonb, p_thresholds jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when exists (select 1 from jsonb_each(coalesce(p_thresholds, '{}')) t
                 where jsonb_typeof(t.value -> 'block') = 'number' and jsonb_typeof(p_scores -> t.key) = 'number'
                   and (p_scores ->> t.key)::numeric >= (t.value ->> 'block')::numeric) then 'block'
    when exists (select 1 from jsonb_each(coalesce(p_thresholds, '{}')) t
                 where jsonb_typeof(t.value -> 'hold') = 'number' and jsonb_typeof(p_scores -> t.key) = 'number'
                   and (p_scores ->> t.key)::numeric >= (t.value ->> 'hold')::numeric) then 'hold'
    else 'allow' end;
$$;

create or replace function cs_api.compliance_policy_simulate(
  p_change_id bigint default null,
  p_version   integer default null,
  p_text      text default null,
  p_surface   text default 'post',
  p_days      integer default 7,
  p_limit     integer default 300
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_days    integer := least(greatest(coalesce(p_days, 7), 1), 30);
  v_limit   integer := least(greatest(coalesce(p_limit, 300), 1), 1000);
  v_text    text := nullif(btrim(coalesce(p_text, '')), '');
  v_surface text := coalesce(p_surface, 'post');
  v_live    jsonb := private.policy_snapshot();
  v_change  cs.policy_changes;
  v_target  jsonb;
  v_kind    text;
  v_id      bigint;
  v_items   jsonb;
  v_current jsonb;
  v_draft   jsonb;
  v_sample  jsonb;
  v_content jsonb;
  v_images  jsonb;
begin
  if v_surface not in ('post', 'comment', 'stock', 'group', 'direct') then
    perform private.api_error(400, 'invalid_surface', 'Tempat: post, comment, stock, group, atau direct');
  end if;
  if v_text is not null and char_length(v_text) > 4000 then
    perform private.api_error(400, 'invalid_text', 'Teks 1–4000 karakter');
  end if;
  if p_change_id is not null then
    select * into v_change from cs.policy_changes c
    where c.id = p_change_id and (c.status = 'pending' or (c.status = 'draft' and c.created_by = v_me));
    if not found then
      perform private.api_error(404, 'policy_change_not_found', 'Permintaan perubahan kebijakan tidak ditemukan');
    end if;
    v_kind := case when v_change.status = 'draft' then 'draft' else 'change' end;
    v_id := v_change.id;
    v_target := private.policy_target(v_change);
  elsif p_version is not null then
    select v.snapshot into v_target from cs.policy_versions v where v.version = p_version;
    if v_target is null then
      perform private.api_error(404, 'policy_version_not_found', 'Versi kebijakan tidak ditemukan');
    end if;
    v_kind := 'version';
    v_id := p_version;
  else
    select * into v_change from cs.policy_changes c where c.created_by = v_me and c.status = 'draft';
    if not found then
      perform private.api_error(404, 'policy_draft_not_found', 'Belum ada draf perubahan kebijakan');
    end if;
    v_kind := 'draft';
    v_id := v_change.id;
    v_target := private.policy_target(v_change);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('type', x.type, 'id', x.id, 'surface', x.surface, 'body', x.body,
                                               'created_at', x.created_at) order by x.created_at desc), '[]')
    into v_items
  from (
    select * from (
      select 'post' as type, p.id, 'post' as surface, p.body, p.created_at, p.author_id as author
      from public.posts p
      where p.deleted_at is null and p.created_at > now() - make_interval(days => v_days) and btrim(p.body) <> ''
      union all
      select 'comment', c.id, 'comment', c.body, c.created_at, c.author_id
      from public.comments c
      where c.deleted_at is null and c.created_at > now() - make_interval(days => v_days) and btrim(c.body) <> ''
      union all
      select 'message', m.id, 'stock', m.body, m.created_at, m.sender_id
      from public.messages m
      join public.chat_rooms r on r.id = m.room_id and r.type = 'stock'
      where m.deleted_at is null and m.session_id is null and m.created_at > now() - make_interval(days => v_days)
        and btrim(m.body) <> ''
    ) u
    where not private.safety_exempt(u.author)
    order by u.created_at desc
    limit v_limit
  ) x;

  if v_text is not null then
    v_items := v_items || jsonb_build_array(jsonb_build_object('type', 'sample', 'surface', v_surface, 'body', v_text));
  end if;
  v_current := private.policy_eval_items(v_items);
  v_draft := private.policy_sandbox(v_target, 'eval', v_items, false) -> 'result';

  with r as (
    select i.item, c.res as cur, d.res as new,
           array_position(array['allow', 'censor', 'hold', 'block'], c.res ->> 'action') as cur_level,
           array_position(array['allow', 'censor', 'hold', 'block'], d.res ->> 'action') as new_level
    from jsonb_array_elements(v_items) with ordinality i(item, o)
    join jsonb_array_elements(v_current) with ordinality c(res, o) on c.o = i.o
    join jsonb_array_elements(v_draft) with ordinality d(res, o) on d.o = i.o
  ), content as (
    select * from r where r.item ->> 'type' <> 'sample'
  ), changed as (
    select * from content where content.cur is distinct from content.new
  )
  select (select jsonb_build_object('surface', r.item ->> 'surface', 'current', r.cur, 'draft', r.new)
          from r where r.item ->> 'type' = 'sample'),
         jsonb_build_object(
           'days', v_days, 'limit', v_limit,
           'scanned', (select count(*) from content),
           'current', jsonb_build_object(
             'allow', (select count(*) from content where content.cur ->> 'action' = 'allow'),
             'censor', (select count(*) from content where content.cur ->> 'action' = 'censor'),
             'hold', (select count(*) from content where content.cur ->> 'action' = 'hold'),
             'block', (select count(*) from content where content.cur ->> 'action' = 'block')),
           'draft', jsonb_build_object(
             'allow', (select count(*) from content where content.new ->> 'action' = 'allow'),
             'censor', (select count(*) from content where content.new ->> 'action' = 'censor'),
             'hold', (select count(*) from content where content.new ->> 'action' = 'hold'),
             'block', (select count(*) from content where content.new ->> 'action' = 'block')),
           'changed', (select count(*) from changed),
           'stricter', (select count(*) from changed where changed.new_level > changed.cur_level),
           'looser', (select count(*) from changed where changed.new_level < changed.cur_level),
           'items', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'type', x.item ->> 'type', 'id', x.item ->> 'id', 'surface', x.item ->> 'surface',
                      'excerpt', left(x.item ->> 'body', 200), 'created_at', x.item ->> 'created_at',
                      'current', x.cur, 'draft', x.new)
                    order by (x.new_level > x.cur_level) desc, x.item ->> 'created_at' desc)
             from (select * from changed order by (changed.new_level > changed.cur_level) desc,
                                                  changed.item ->> 'created_at' desc limit 100) x), '[]'))
    into v_sample, v_content;

  with m as (
    select private.media_decide(r.scores, v_live -> 'image_thresholds') as cur,
           private.media_decide(r.scores, v_target -> 'image_thresholds') as new
    from private.media_reviews r
    where r.created_at > now() - make_interval(days => v_days)
  )
  select jsonb_build_object(
           'scanned', count(*),
           'current', jsonb_build_object('allow', count(*) filter (where m.cur = 'allow'),
                                         'hold', count(*) filter (where m.cur = 'hold'),
                                         'block', count(*) filter (where m.cur = 'block')),
           'draft', jsonb_build_object('allow', count(*) filter (where m.new = 'allow'),
                                       'hold', count(*) filter (where m.new = 'hold'),
                                       'block', count(*) filter (where m.new = 'block')),
           'changed', count(*) filter (where m.cur <> m.new))
    into v_images
  from m;

  return jsonb_build_object(
    'target', jsonb_build_object('kind', v_kind, 'id', v_id,
                                 'summary', private.policy_diff_counts(private.policy_diff(v_live, v_target))),
    'sample', v_sample,
    'content', v_content,
    'images', v_images);
end;
$$;

create or replace function cs.policy_four_eyes_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('enabled', coalesce((s.value #>> '{}')::boolean, true), 'version', s.version,
                            'updated_at', s.updated_at, 'updated_by', cs.agent_name(s.updated_by))
  from cs.cs_settings s
  where s.key = 'compliance.policy_four_eyes';
$$;

create or replace function cs_api.admin_policy_four_eyes()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return cs.policy_four_eyes_view();
end;
$$;

create or replace function cs_api.admin_set_policy_four_eyes(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  if p_enabled is null then
    perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
  end if;
  if cs.policy_four_eyes() is distinct from p_enabled then
    perform cs.set_setting('compliance.policy_four_eyes', to_jsonb(p_enabled), v_me);
    perform cs.audit('setting.update', null, null,
      jsonb_build_object('key', 'compliance.policy_four_eyes', 'value', p_enabled));
  end if;
  return cs.policy_four_eyes_view();
end;
$$;

revoke execute on function cs.policy_four_eyes() from public;
revoke execute on function private.policy_sections() from public;
revoke execute on function private.policy_setting_key(text) from public;
revoke execute on function private.policy_snapshot() from public;
revoke execute on function private.policy_diff(jsonb, jsonb) from public;
revoke execute on function private.policy_diff_counts(jsonb) from public;
revoke execute on function private.policy_rebase(jsonb, jsonb, jsonb) from public;
revoke execute on function private.policy_check_limits(jsonb) from public;
revoke execute on function private.policy_load(jsonb, uuid) from public;
revoke execute on function private.policy_current_version() from public;
revoke execute on function private.policy_commit(text, text, bigint, integer) from public;
revoke execute on function private.policy_touched() from public;
revoke execute on function private.policy_pending_commit() from public;
revoke execute on function private.policy_read_call(text) from public;
revoke execute on function private.policy_call_known(text) from public;
revoke execute on function private.policy_dispatch(text, jsonb) from public;
revoke execute on function private.policy_eval(text, text) from public;
revoke execute on function private.policy_eval_items(jsonb) from public;
revoke execute on function private.policy_sandbox(jsonb, text, jsonb, boolean) from public;
revoke execute on function private.policy_my_draft(uuid, boolean) from public;
revoke execute on function private.policy_target(cs.policy_changes) from public;
revoke execute on function private.policy_apply_change(bigint, uuid, text) from public;
revoke execute on function private.media_decide(jsonb, jsonb) from public;
revoke execute on function cs.policy_version_ref(cs.policy_versions) from public;
revoke execute on function cs.policy_change_view(bigint, boolean) from public;
revoke execute on function cs.policy_reason(text, text, text) from public;
revoke execute on function cs.policy_four_eyes_view() from public;
revoke execute on function cs_api.compliance_policy_call(text, jsonb) from public;
revoke execute on function cs_api.compliance_policy_state() from public;
revoke execute on function cs_api.compliance_policy_discard() from public;
revoke execute on function cs_api.compliance_policy_submit(text) from public;
revoke execute on function cs_api.compliance_policy_changes(text, integer) from public;
revoke execute on function cs_api.compliance_policy_change(bigint) from public;
revoke execute on function cs_api.compliance_policy_decide(bigint, boolean, text) from public;
revoke execute on function cs_api.compliance_policy_withdraw(bigint) from public;
revoke execute on function cs_api.compliance_policy_versions(integer, integer) from public;
revoke execute on function cs_api.compliance_policy_version(integer) from public;
revoke execute on function cs_api.compliance_policy_rollback(integer, text) from public;
revoke execute on function cs_api.compliance_policy_simulate(bigint, integer, text, text, integer, integer) from public;
revoke execute on function cs_api.admin_policy_four_eyes() from public;
revoke execute on function cs_api.admin_set_policy_four_eyes(boolean) from public;

grant execute on function cs_api.compliance_policy_call(text, jsonb) to authenticated;
grant execute on function cs_api.compliance_policy_state() to authenticated;
grant execute on function cs_api.compliance_policy_discard() to authenticated;
grant execute on function cs_api.compliance_policy_submit(text) to authenticated;
grant execute on function cs_api.compliance_policy_changes(text, integer) to authenticated;
grant execute on function cs_api.compliance_policy_change(bigint) to authenticated;
grant execute on function cs_api.compliance_policy_decide(bigint, boolean, text) to authenticated;
grant execute on function cs_api.compliance_policy_withdraw(bigint) to authenticated;
grant execute on function cs_api.compliance_policy_versions(integer, integer) to authenticated;
grant execute on function cs_api.compliance_policy_version(integer) to authenticated;
grant execute on function cs_api.compliance_policy_rollback(integer, text) to authenticated;
grant execute on function cs_api.compliance_policy_simulate(bigint, integer, text, text, integer, integer) to authenticated;
grant execute on function cs_api.admin_policy_four_eyes() to authenticated;
grant execute on function cs_api.admin_set_policy_four_eyes(boolean) to authenticated;
