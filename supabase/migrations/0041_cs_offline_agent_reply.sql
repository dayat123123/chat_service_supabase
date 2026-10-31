create or replace function cs.reject_offline_agent_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from cs.agent_status st where st.agent_id = new.sender_id and st.status = 'offline') then
    perform private.api_error(409, 'agent_offline', 'Anda sedang Offline. Ubah ke Online dulu untuk membalas nasabah');
  end if;
  return new;
end;
$$;

revoke execute on function cs.reject_offline_agent_reply() from public;

create trigger messages_reject_offline_agent_reply
before insert on public.messages
for each row
when (new.session_id is not null and new.sender_id is not null)
execute function cs.reject_offline_agent_reply();
