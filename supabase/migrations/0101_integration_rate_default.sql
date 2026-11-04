alter table private.integration_keys alter column rate_limit_per_minute set default 3000;

create or replace function cs_api.integration_key_create(
  p_name                  text,
  p_scopes                text[],
  p_official_account_id   uuid default null,
  p_allowed_cidrs         text[] default '{}',
  p_rate_limit_per_minute integer default 3000
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
  v_rate     integer := coalesce(p_rate_limit_per_minute, 3000);
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
  p_rate_limit_per_minute integer default 3000,
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
  v_rate     integer := coalesce(p_rate_limit_per_minute, 3000);
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

grant execute on function cs_api.integration_key_create(text, text[], uuid, text[], integer) to authenticated;
grant execute on function cs_api.integration_key_update(uuid, text, text[], uuid, text[], integer, boolean) to authenticated;
