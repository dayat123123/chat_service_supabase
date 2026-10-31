alter table private.user_private
  add column olt_username text check (olt_username is null or char_length(olt_username) between 1 and 100);

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
begin
  if p_id is null or coalesce(btrim(p_olt_user_id), '') = '' then
    perform private.api_error(400, 'invalid_profile', 'id dan olt_user_id wajib diisi');
  end if;

  v_base := regexp_replace(coalesce(p_username, ''), '[^A-Za-z0-9_]', '_', 'g');
  if char_length(v_base) < 3 then
    v_base := 'user_' || v_base;
  end if;
  v_base := left(v_base, 30);

  select * into v_existing from public.profiles where id = p_id;
  v_exists := found;

  if v_exists and v_existing.deleted_at is not null then
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

  select s.ends_at into v_ban_end
  from private.user_sanctions s
  where s.user_id = p_id and s.kind = 'ban' and s.revoked_at is null
    and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
  order by s.ends_at desc nulls first
  limit 1;

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

create or replace function cs_api.ticket_customer_login(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  perform cs.require_agent();
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return (
    select jsonb_build_object('login_id', coalesce(up.olt_username, p.username::text),
                              'source', case when up.olt_username is null then 'profile' else 'olt' end)
    from public.profiles p
    left join private.user_private up on up.user_id = p.id
    where p.id = t.customer_id);
end;
$$;

revoke execute on function cs_api.ticket_customer_login(uuid) from public;
grant execute on function cs_api.ticket_customer_login(uuid) to authenticated;
