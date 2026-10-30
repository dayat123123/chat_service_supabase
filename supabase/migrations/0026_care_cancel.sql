select cron.unschedule(j.jobname)
from cron.job j
where j.jobname in ('care-sweep', 'care-partitions', 'care-retention');

drop policy if exists olt_care_documents_select on storage.objects;
drop function if exists private.can_read_care_document(text);

select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'care-documents';
delete from storage.buckets where id = 'care-documents';

delete from private.rate_limits where action in ('care_ticket', 'care_message');

create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_topic is null or private.is_banned(auth.uid()) then
    return false;
  end if;
  if p_topic = 'online' then
    return true;
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return exists (
      select 1 from public.chat_members
      where room_id = substring(p_topic from 6)::uuid and user_id = auth.uid()
    );
  end if;
  return false;
end;
$$;

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
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  if private.is_banned(v_uid) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
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

drop schema if exists care_api cascade;
drop schema if exists care cascade;
