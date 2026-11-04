create or replace function private.check_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid;
  v_revoked timestamptz;
  v_iat     numeric;
  v_headers jsonb;
  v_profile text;
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  v_headers := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  v_profile := coalesce(case when current_setting('request.method', true) in ('GET', 'HEAD')
                             then v_headers ->> 'accept-profile'
                             else v_headers ->> 'content-profile' end, 'public');
  if v_profile <> 'cs_api' and private.is_banned(v_uid)
     and not (v_profile = 'public'
              and coalesce(current_setting('request.path', true), '')
                  in ('/rpc/create_appeal', '/rpc/get_my_appeals', '/rpc/get_my_sanctions')) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
  end if;
  if v_profile = 'public' and cs.is_staff(v_uid) then
    perform private.api_error(403, 'cs_staff_social_forbidden', 'Akun CS tidak bisa memakai fitur sosial');
  end if;
  if v_headers ->> 'x-olt-edge' = 'public' and cs.is_staff(v_uid) then
    perform private.api_error(403, 'cs_staff_public_edge', 'Akun CS hanya bisa dipakai dari domain web CS');
  end if;
  select s.revoked_before into v_revoked from private.user_sessions s where s.user_id = v_uid;
  if v_revoked is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::numeric;
    if v_iat is null or to_timestamp(v_iat) < v_revoked then
      perform private.api_error(401, 'session_revoked', 'Sesi sudah dicabut, silakan masuk ulang');
    end if;
  end if;
end;
$$;

grant execute on function private.check_request() to anon, authenticated;
