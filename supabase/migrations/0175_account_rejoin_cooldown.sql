create or replace function private.policy_setting_key(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('safety.new_account_days', 'account.rejoin_cooldown_hours') or p_key like 'manipulation.%'
      or p_key in ('rooms.busy_slow_mode', 'rooms.busy_windows');
$$;

insert into private.settings (key, value, description) values
  ('account.rejoin_cooldown_hours', '72',
   'Jam tunggu setelah akun komunitas dihapus sebelum login yang sama bisa bergabung lagi (0 = tanpa jeda)')
on conflict (key) do nothing;

create or replace function private.account_rejoin_at(p_deleted_at timestamptz)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_deleted_at is null then null
              else p_deleted_at + greatest(private.setting_num('account.rejoin_cooldown_hours', 72), 0) * interval '1 hour'
         end;
$$;

create or replace function public.upsert_olt_profile(
  p_id           uuid,
  p_olt_user_id  text,
  p_username     text,
  p_display_name text default null,
  p_email        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_base     text;
  v_username text;
  v_existing public.profiles;
  v_profile  public.profiles;
  v_attempt  integer := 0;
  v_ban_end  timestamptz;
  v_exists   boolean;
  v_rejoin   timestamptz;
begin
  if p_id is null or coalesce(btrim(p_olt_user_id), '') = '' then
    perform private.api_error(400, 'invalid_profile', 'id dan olt_user_id wajib diisi');
  end if;

  v_base := regexp_replace(coalesce(p_username, ''), '[^A-Za-z0-9_]', '_', 'g');
  if char_length(v_base) < 3 then
    v_base := 'user_' || v_base;
  end if;
  v_base := left(v_base, 30);

  select s.ends_at into v_ban_end
  from private.user_sanctions s
  where s.user_id = p_id and s.kind = 'ban' and s.revoked_at is null
    and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
  order by s.ends_at desc nulls first
  limit 1;

  select * into v_existing from public.profiles where id = p_id;
  v_exists := found;

  if v_exists and v_existing.deleted_at is not null then
    v_rejoin := private.account_rejoin_at(v_existing.deleted_at);
    if v_rejoin > now() then
      return jsonb_build_object(
        'id', v_existing.id,
        'olt_user_id', v_existing.olt_user_id,
        'username', v_existing.username,
        'display_name', null,
        'avatar_url', null,
        'is_verified', false,
        'banned', private.is_banned(p_id),
        'ban_ends_at', v_ban_end,
        'rejoin_at', v_rejoin
      );
    end if;
    update public.profiles
       set deleted_at = null, trust_level = 0, created_at = now(),
           display_name = nullif(left(btrim(p_display_name), 60), '')
     where id = p_id;
  end if;

  if v_exists then
    if v_existing.username::text <> v_base
       and not exists (
         select 1 from public.profiles
         where username = v_base::extensions.citext and id <> p_id
       ) then
      begin
        update public.profiles set username = v_base where id = p_id;
      exception when unique_violation then
        null;
      end;
    end if;
    update public.profiles
       set display_name = coalesce(display_name, nullif(btrim(p_display_name), ''))
     where id = p_id
     returning * into v_profile;
  else
    loop
      v_username := case
        when v_attempt = 0 then v_base
        else left(v_base, 25) || '_' || substr(md5(p_olt_user_id || v_attempt::text), 1, 4)
      end;
      begin
        insert into public.profiles (id, olt_user_id, username, display_name, trust_level)
        values (p_id, p_olt_user_id, v_username, nullif(left(btrim(p_display_name), 60), ''), 0)
        returning * into v_profile;
        exit;
      exception when unique_violation then
        select * into v_profile from public.profiles where id = p_id;
        exit when found;
        v_attempt := v_attempt + 1;
        if v_attempt > 5 then
          perform private.api_error(409, 'username_unavailable', 'Gagal menentukan username unik');
        end if;
      end;
    end loop;
  end if;

  insert into private.user_private (user_id, email, olt_username, last_login_at, updated_at)
  values (p_id, nullif(btrim(p_email), ''), nullif(left(btrim(p_username), 100), ''), now(), now())
  on conflict (user_id) do update
    set email = coalesce(excluded.email, private.user_private.email),
        olt_username = coalesce(excluded.olt_username, private.user_private.olt_username),
        last_login_at = now(),
        updated_at = now();

  return jsonb_build_object(
    'id', v_profile.id,
    'olt_user_id', v_profile.olt_user_id,
    'username', v_profile.username,
    'display_name', v_profile.display_name,
    'avatar_url', v_profile.avatar_url,
    'is_verified', v_profile.is_verified,
    'banned', private.is_banned(p_id),
    'ban_ends_at', v_ban_end
  );
end;
$$;

create or replace function cs.content_rules_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'category', r.category, 'action', r.action, 'scope', r.scope, 'updated_at', r.updated_at,
        'updated_by', cs.staff_ref(r.updated_by)) order by r.category) from cs.content_rules r), '[]'),
    'blocked_domains', coalesce((select jsonb_agg(jsonb_build_object(
        'domain', b.domain, 'match', b.match, 'category', b.category, 'action', b.action, 'note', b.note,
        'created_at', b.created_at) order by b.category, b.domain) from cs.blocked_domains b), '[]'),
    'allowed_domains', coalesce((select jsonb_agg(jsonb_build_object(
        'domain', a.domain, 'note', a.note, 'created_at', a.created_at) order by a.domain) from cs.allowed_domains a), '[]'),
    'allowlist', coalesce((select jsonb_agg(jsonb_build_object('term', t.term, 'created_at', t.created_at) order by t.term)
                           from cs.policy_allowlist t), '[]'),
    'promo_phrases', coalesce((select jsonb_agg(jsonb_build_object('phrase', p.phrase, 'created_at', p.created_at)
                                                order by p.phrase) from cs.promo_phrases p), '[]'),
    'new_account_days', private.setting_num('safety.new_account_days', 3),
    'rejoin_cooldown_hours', private.setting_num('account.rejoin_cooldown_hours', 72));
$$;

create function cs_api.compliance_set_rejoin_cooldown_hours(p_hours integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{compliance}');
  v_old jsonb := private.setting_json('account.rejoin_cooldown_hours', '72');
begin
  if p_hours is null or p_hours not between 0 and 720 then
    perform private.api_error(400, 'invalid_setting', 'Jeda bergabung lagi 0–720 jam');
  end if;
  update private.settings set value = to_jsonb(p_hours), updated_at = now() where key = 'account.rejoin_cooldown_hours';
  perform cs.audit('content_rule.rejoin_cooldown_hours', null, null, jsonb_build_object('from', v_old, 'to', p_hours));
  return cs.content_rules_view();
end;
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
    'compliance_set_manipulation_settings', 'compliance_set_rejoin_cooldown_hours');
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
    when 'compliance_set_rejoin_cooldown_hours' then
      if jsonb_typeof(a -> 'p_hours') is distinct from 'number' then
        perform private.api_error(400, 'invalid_setting', 'Jeda bergabung lagi 0–720 jam');
      end if;
      return cs_api.compliance_set_rejoin_cooldown_hours((a ->> 'p_hours')::numeric::integer);
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

create or replace function public.get_client_config(p_platform text default null, p_app_version text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user     uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_version  text := nullif(btrim(coalesce(p_app_version, '')), '');
  v_min      text;
begin
  if v_platform is not null and v_platform <> all (private.client_platforms()) then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_version is not null and private.version_parts(v_version) is null then
    perform private.api_error(400, 'invalid_version', 'Versi aplikasi harus berformat angka, mis. 2.4.1');
  end if;
  select v.min_version into v_min from private.client_versions v where v.platform = v_platform;

  return jsonb_build_object(
    'social_enabled', private.social_enabled(),
    'flags', coalesce((select jsonb_object_agg(f.key, private.flag_enabled(f, v_user, v_platform, v_version))
                       from private.feature_flags f), '{}'),
    'min_version', coalesce((select jsonb_object_agg(v.platform, v.min_version) from private.client_versions v), '{}'),
    'update_required', coalesce(v_min is not null and v_version is not null
                                and private.version_parts(v_version) < private.version_parts(v_min), false),
    'banners', private.client_banners(v_platform, v_version, v_user),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'account_rejoin_cooldown_hours', greatest(private.setting_num('account.rejoin_cooldown_hours', 72), 0),
      'server_time', now()));
end;
$$;

revoke execute on function private.account_rejoin_at(timestamptz) from public;
revoke execute on function cs_api.compliance_set_rejoin_cooldown_hours(integer) from public;
grant execute on function cs_api.compliance_set_rejoin_cooldown_hours(integer) to authenticated;
