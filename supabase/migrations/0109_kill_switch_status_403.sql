create or replace function private.enforce_kill_switch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_end_user() or private.social_enabled() then
    return new;
  end if;
  if tg_op = 'UPDATE' and (new.deleted_at is not null or new.body is not distinct from old.body) then
    return new;
  end if;
  if tg_table_name = 'messages'
     and ((to_jsonb(new) ->> 'session_id') is not null
          or exists (select 1 from public.chat_rooms r where r.id = (to_jsonb(new) ->> 'room_id')::uuid
                     and r.type = 'support')) then
    return new;
  end if;
  perform private.api_error(403, 'social_disabled', 'Fitur komunitas sedang dinonaktifkan sementara');
  return new;
end;
$$;
