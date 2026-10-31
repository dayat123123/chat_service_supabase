drop function cs_api.send_card(uuid, text, text, uuid);
drop function cs_api.customer_data_access(text);
drop function cs_api.agent_customer_access(uuid, text);
drop function cs_api.agent_reveal_access(uuid, text, text);
drop function cs_api.agent_secure_account(uuid);
drop function cs_api.agent_secure_account_result(uuid, boolean, jsonb);
drop function cs.customer_data_ticket(uuid);

delete from cs.cs_settings
 where key in ('customer_data.profile_views_per_hour', 'customer_data.reveals_per_hour',
               'customer_data.reveal_reasons', 'secure_account.actions');

update public.messages set kind = 'text', payload = payload - 'card' - 'ref' where kind = 'card';

alter table public.messages drop constraint messages_kind;
alter table public.messages add constraint messages_kind
  check (kind in ('text', 'system', 'quick_reply', 'help_link', 'identity_request', 'csat'));

drop function cs_api.open_ticket(text, text, text, boolean, text, text);

create function cs_api.open_ticket(p_topic text, p_language text default 'id', p_screen text default null,
                                   p_complaint boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  if coalesce(p_language, '') not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if p_screen is not null and p_screen !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_screen', 'Asal layar tidak valid');
  end if;
  t := cs.open_ticket(v_me, p_topic, p_language,
                      case when p_complaint then array['complaint'] else array[]::text[] end,
                      case when p_screen is null then '{}'::jsonb else jsonb_build_object('screen', p_screen) end,
                      null);
  if p_complaint and not ('complaint' = any (t.flags)) then
    t := cs.flag_ticket(t.id, 'complaint');
  end if;
  return cs.ticket_customer_view(t);
end;
$$;

revoke execute on function cs_api.open_ticket(text, text, text, boolean) from public;
grant execute on function cs_api.open_ticket(text, text, text, boolean) to authenticated;

create or replace function cs.message_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   public.chat_rooms;
  t        cs.tickets;
  v_prio   record;
  v_masked record;
begin
  if tg_op = 'UPDATE' then
    if old.session_id is null
       or (new.body, new.attachments, new.deleted_at, new.kind, new.payload, new.session_id, new.sender_role)
          is not distinct from
          (old.body, old.attachments, old.deleted_at, old.kind, old.payload, old.session_id, old.sender_role)
       or not private.is_end_user()
       or private.admin_role() is not null then
      return new;
    end if;
    if new.deleted_at is not null and old.deleted_at is null then
      return null;
    end if;
    perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa diubah');
  end if;

  select * into v_room from public.chat_rooms where id = new.room_id;
  if v_room.type is distinct from 'support' then
    if new.session_id is not null or new.sender_role is not null then
      perform private.api_error(400, 'invalid_message', 'Pesan ini hanya untuk chat CS');
    end if;
    return new;
  end if;

  if new.sender_id is null then
    new.sender_role := 'system';
  elsif new.sender_id = v_room.customer_id then
    new.sender_role := 'customer';
    if new.kind <> 'text' then
      perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak diizinkan');
    end if;
  elsif new.sender_role is null or new.sender_role not in ('agent', 'supervisor') or not cs.is_staff(new.sender_id) then
    perform private.api_error(403, 'use_cs_api', 'Pesan CS hanya bisa dikirim lewat panel CS');
  end if;

  if new.sender_role = 'customer' and new.session_id is null then
    if new.client_id is not null then
      select m.session_id into new.session_id
      from public.messages m where m.sender_id = new.sender_id and m.client_id = new.client_id;
      if new.session_id is not null then
        return new;
      end if;
    end if;
    perform cs.check_rate('cs_message', new.sender_id);
    select * into t from cs.tickets x where x.room_id = new.room_id order by x.created_at desc limit 1 for update;
    if t.id is not null and t.status in ('open', 'claimed', 'waiting_customer') then
      if t.status = 'waiting_customer' then
        t := cs.set_status(t.id, 'claimed', 'customer_replied');
        perform cs.broadcast_ticket(t, 'ticket_updated');
      end if;
      if t.last_customer_message_at is null then
        select * into v_prio from cs.initial_priority(t.topic, t.flags, new.body, now());
        if v_prio.priority < t.priority or not (v_prio.flags <@ t.flags) then
          update cs.tickets
             set priority = least(priority, v_prio.priority),
                 flags = array(select distinct f from unnest(flags || v_prio.flags) f order by f),
                 required_skill = case when 'fraud' = any (v_prio.flags) then 'fraud' else required_skill end,
                 version = version + 1,
                 updated_at = now()
           where id = t.id
          returning * into t;
          perform cs.log_event(t.id, 'priority_changed', jsonb_build_object('priority', t.priority, 'flags', t.flags));
          perform cs.broadcast_ticket(t, 'ticket_updated');
        end if;
      end if;
    elsif t.id is not null and t.status = 'resolved'
          and t.resolved_at > now() - make_interval(hours => cs.setting_int('ticket.reopen_hours')) then
      t := cs.reopen_ticket(t);
    else
      t := cs.open_ticket(new.sender_id, cs.setting('ticket.default_topic') #>> '{}',
                          coalesce(t.language, 'id'), '{}', '{}', new.body);
    end if;
    new.session_id := t.id;
  end if;

  select * into t from cs.tickets where id = new.session_id;
  if t.room_id is distinct from new.room_id then
    perform private.api_error(400, 'invalid_ticket', 'Tiket tidak sesuai dengan room');
  end if;

  if new.sender_role = 'agent' then
    if t.status not in ('claimed', 'waiting_customer') or t.owner_agent_id is distinct from new.sender_id then
      perform private.api_error(403, 'not_ticket_owner', 'Hanya CS pemilik tiket aktif yang bisa membalas');
    end if;
  elsif new.sender_role = 'supervisor' then
    if t.status not in ('claimed', 'waiting_customer')
       or not exists (select 1 from cs.agents a where a.user_id = new.sender_id and a.disabled_at is null
                      and 'cs_supervisor' = any (a.roles))
       or not exists (select 1 from public.chat_members m where m.room_id = new.room_id and m.user_id = new.sender_id) then
      perform private.api_error(403, 'not_joined', 'Supervisor harus bergabung ke tiket aktif sebelum membalas');
    end if;
  end if;

  if new.sender_role = 'customer' then
    update cs.tickets set last_customer_message_at = clock_timestamp() where id = t.id;
  elsif new.sender_role in ('agent', 'supervisor') then
    update cs.tickets
       set last_agent_message_at = clock_timestamp(),
           first_response_at = coalesce(first_response_at, clock_timestamp())
     where id = t.id;
  end if;

  if new.sender_role <> 'system' and new.body <> '' then
    select * into v_masked from cs.mask_sensitive(new.body);
    if cardinality(v_masked.kinds) > 0 then
      new.body := v_masked.masked;
      new.payload := new.payload || jsonb_build_object('masked', to_jsonb(v_masked.kinds));
    end if;
  end if;
  new.created_at := clock_timestamp();
  return new;
end;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes')))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.agent_send_message(
  p_ticket_id   uuid,
  p_body        text,
  p_client_id   uuid default null,
  p_kind        text default 'text',
  p_payload     jsonb default '{}',
  p_reply_to_id uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t         cs.tickets;
  v_role    text;
  v_body    text := btrim(coalesce(p_body, ''));
  v_payload jsonb := '{}';
  v_url     text;
  v_id      uuid;
begin
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or t.status not in ('claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket tidak sedang ditangani');
  end if;
  if t.owner_agent_id = v_me then
    v_role := 'agent';
  elsif cs.has_role('{cs_supervisor}')
        and exists (select 1 from public.chat_members m where m.room_id = t.room_id and m.user_id = v_me) then
    v_role := 'supervisor';
  else
    perform private.api_error(403, 'not_ticket_owner',
      format('Tiket ini ditangani oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
  end if;
  if char_length(v_body) > 4000 then
    perform private.api_error(400, 'body_too_long', 'Pesan maksimal 4000 karakter');
  end if;
  if p_kind = 'quick_reply' then
    if jsonb_typeof(p_payload -> 'options') <> 'array'
       or jsonb_array_length(p_payload -> 'options') not between 2 and 6
       or exists (select 1 from jsonb_array_elements(p_payload -> 'options') x
                  where jsonb_typeof(x) <> 'string' or char_length(btrim(x #>> '{}')) not between 1 and 40) then
      perform private.api_error(400, 'invalid_options', 'Tombol pilihan berisi 2–6 teks, masing-masing 1–40 karakter');
    end if;
    v_payload := jsonb_build_object('options', p_payload -> 'options');
  elsif p_kind = 'help_link' then
    v_url := p_payload ->> 'url';
    if v_url is null or v_url !~ '^https://[A-Za-z0-9.-]+(/[^\s]*)?$'
       or not (cs.setting('help.allowed_hosts') ? lower(substring(v_url from '^https://([A-Za-z0-9.-]+)'))) then
      perform private.api_error(400, 'invalid_help_link', 'Tautan bantuan harus https ke situs bantuan resmi');
    end if;
    v_payload := jsonb_build_object('url', v_url);
  elsif coalesce(p_kind, '') <> 'text' then
    perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak didukung');
  end if;
  if v_body = '' and (p_kind <> 'text' or jsonb_array_length(coalesce(p_attachments, '[]'::jsonb)) = 0) then
    perform private.api_error(400, 'body_required', 'Isi teks pesan');
  end if;

  if cs.requests_secret(v_body)
     or (p_kind = 'quick_reply' and cs.requests_secret((select string_agg(x #>> '{}', '. ') from jsonb_array_elements(v_payload -> 'options') x))) then
    perform cs.log_event(t.id, 'secret_request_blocked');
    perform cs.audit('message.secret_request_blocked', t.id, t.customer_id,
      jsonb_build_object('excerpt', left((cs.mask_sensitive(v_body)).masked, 200)));
    perform realtime.send(
      jsonb_build_object('event', 'secret_request_blocked', 'ticket_id', t.id, 'ticket_number', t.ticket_number,
                         'agent_id', v_me, 'agent_code', (select a.agent_code from cs.agents a where a.user_id = v_me)),
      'alert', 'cs:queue', true);
    return jsonb_build_object('status', 'blocked', 'code', 'secret_request_blocked',
      'message', 'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.');
  end if;

  insert into public.messages (room_id, sender_id, body, reply_to_id, attachments, client_id, kind, session_id, sender_role, payload)
  values (t.room_id, v_me, v_body, p_reply_to_id, coalesce(p_attachments, '[]'::jsonb), p_client_id,
          p_kind, t.id, v_role, v_payload)
  on conflict (sender_id, client_id) do nothing
  returning id into v_id;
  if v_id is null then
    select m.id into v_id from public.messages m where m.sender_id = v_me and m.client_id = p_client_id;
  end if;
  return jsonb_build_object('status', 'sent',
    'message', (select to_jsonb(m) from private.chat_messages(array[v_id]) m));
end;
$$;

alter table public.post_stocks drop constraint post_stocks_stock_code_fkey;
alter table public.stock_watchers drop constraint stock_watchers_stock_code_fkey;
alter table public.muted_stocks drop constraint muted_stocks_stock_code_fkey;
alter table public.chat_rooms drop constraint chat_rooms_stock_code_fkey;

alter table public.post_stocks add constraint post_stocks_code_format
  check (stock_code ~ '^[A-Z][A-Z0-9]{1,11}$');
alter table public.stock_watchers add constraint stock_watchers_code_format
  check (stock_code ~ '^[A-Z][A-Z0-9]{1,11}$');
alter table public.muted_stocks add constraint muted_stocks_code_format
  check (stock_code ~ '^[A-Z][A-Z0-9]{1,11}$');
alter table public.chat_rooms add constraint chat_rooms_stock_code_format
  check (stock_code ~ '^[A-Z][A-Z0-9]{1,11}$');

drop trigger stock_watchers_counter on public.stock_watchers;
drop function private.stock_watchers_counter();
drop function public.search_stocks(text, integer);
drop function public.sync_stocks(jsonb);

create or replace function private.sync_post_tags()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_codes     text[];
  v_usernames extensions.citext[];
begin
  if tg_op = 'UPDATE'
     and new.body is not distinct from old.body
     and new.deleted_at is not distinct from old.deleted_at then
    return null;
  end if;

  if new.deleted_at is not null then
    delete from public.post_stocks where post_id = new.id;
    delete from public.post_mentions where post_id = new.id;
    return null;
  end if;

  v_codes := (private.extract_cashtags(new.body))[1:10];
  delete from public.post_stocks where post_id = new.id and stock_code <> all(v_codes);
  insert into public.post_stocks (post_id, stock_code, post_created_at)
  select new.id, c.code, new.created_at
  from unnest(v_codes) as c(code)
  on conflict do nothing;

  v_usernames := ((private.extract_mentions(new.body))[1:10])::extensions.citext[];
  delete from public.post_mentions pm
  where pm.post_id = new.id
    and pm.user_id not in (select p.id from public.profiles p where p.username = any(v_usernames));
  insert into public.post_mentions (post_id, user_id)
  select new.id, p.id
  from public.profiles p
  where p.username = any(v_usernames) and p.id <> new.author_id
  on conflict do nothing;

  return null;
end;
$$;

insert into private.rate_limits (action, max_count, window_seconds) values ('stock_room_create', 20, 3600);

create or replace function public.join_stock_room(p_stock_code text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_code text := upper(btrim(coalesce(p_stock_code, '')));
  v_room uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham tidak valid');
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

create function public.get_stock(p_code text)
returns table (code text, watcher_count integer, watching boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select c.code,
         (select count(*)::integer from public.stock_watchers w where w.stock_code = c.code),
         exists (select 1 from public.stock_watchers w where w.stock_code = c.code and w.user_id = auth.uid())
  from (select upper(btrim(coalesce(p_code, ''))) as code) c
  where c.code ~ '^[A-Z][A-Z0-9]{1,11}$';
$$;

revoke execute on function public.get_stock(text) from public, anon;
grant execute on function public.get_stock(text) to authenticated;

drop table public.stocks;
