insert into private.settings (key, value, description) values
  ('room_mods.min_trust_level', '2', 'Moderator room: trust level minimal nasabah yang bisa ditunjuk (1–3)'),
  ('room_mods.sanction_free_days', '90', 'Moderator room: tanpa sanksi dalam sekian hari terakhir (0–365)'),
  ('room_mods.max_mute_hours', '24', 'Moderator room: lama bisu maksimal yang boleh diberikan moderator (jam, 1–24)'),
  ('room_mods.max_per_room', '10', 'Moderator room: jumlah moderator aktif maksimal per room saham (1–50)'),
  ('room_mods.max_rooms_per_user', '3', 'Moderator room: jumlah room maksimal yang dimoderasi satu nasabah (1–20)')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('room_mod_action', 15, 3600),
  ('room_mod_action', 50, 86400)
on conflict (action, window_seconds) do nothing;

create table private.room_moderators (
  id            uuid primary key default gen_random_uuid(),
  room_id       uuid not null references public.chat_rooms (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  note          text,
  appointed_by  uuid,
  appointed_at  timestamptz not null default now(),
  removed_at    timestamptz,
  removed_by    uuid,
  remove_reason text,
  constraint room_moderators_note check (char_length(note) <= 500),
  constraint room_moderators_remove_reason check (char_length(remove_reason) <= 500),
  constraint room_moderators_removed check ((removed_at is null) = (remove_reason is null))
);
create unique index room_moderators_active_idx on private.room_moderators (room_id, user_id) where removed_at is null;
create index room_moderators_user_idx on private.room_moderators (user_id) where removed_at is null;
create index room_moderators_room_idx on private.room_moderators (room_id, appointed_at desc);
alter table private.room_moderators enable row level security;

create table private.room_mod_actions (
  id             uuid primary key default gen_random_uuid(),
  room_id        uuid not null references public.chat_rooms (id) on delete cascade,
  moderator_id   uuid references public.profiles (id) on delete set null,
  action         text not null,
  target_user_id uuid references public.profiles (id) on delete set null,
  message_id     uuid references public.messages (id) on delete set null,
  reason         text not null,
  note           text,
  mute_until     timestamptz,
  report_id      uuid references public.reports (id) on delete set null,
  created_at     timestamptz not null default now(),
  undone_at      timestamptz,
  undone_by      uuid,
  undo_note      text,
  constraint room_mod_actions_action check (action in ('hide', 'mute', 'escalate')),
  constraint room_mod_actions_reason check (
    reason in ('spam', 'abuse', 'scam', 'pump_and_dump', 'misinformation', 'other')),
  constraint room_mod_actions_note check (char_length(note) <= 500),
  constraint room_mod_actions_undo_note check (char_length(undo_note) <= 500),
  constraint room_mod_actions_mute check ((action = 'mute') = (mute_until is not null))
);
create index room_mod_actions_room_idx on private.room_mod_actions (room_id, created_at desc, id desc);
create index room_mod_actions_created_idx on private.room_mod_actions (created_at desc, id desc);
create index room_mod_actions_moderator_idx on private.room_mod_actions (moderator_id, created_at desc);
create index room_mod_actions_message_idx on private.room_mod_actions (message_id) where message_id is not null;
create index room_mod_actions_mute_idx on private.room_mod_actions (room_id, target_user_id, mute_until)
  where action = 'mute' and undone_at is null;
alter table private.room_mod_actions enable row level security;

create or replace function private.room_mod_reasons()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['spam', 'abuse', 'scam', 'pump_and_dump', 'misinformation', 'other'];
$$;

create or replace function private.is_room_moderator(p_room uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from private.room_moderators m
                 where m.room_id = p_room and m.user_id = p_user and m.removed_at is null);
$$;

create or replace function private.room_mute_until(p_room uuid, p_user uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(a.mute_until) from private.room_mod_actions a
  where a.room_id = p_room and a.target_user_id = p_user and a.action = 'mute'
    and a.undone_at is null and a.mute_until > now();
$$;

create or replace function private.room_moderator_problems(p_user uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select case when p.id is null or p.deleted_at is not null then array['user_not_found'] else array_remove(array[
    case when p.olt_user_id like 'cs-staff:%' or p.olt_user_id like 'official:%'
              or private.is_official_account(p.id)
              or exists (select 1 from cs.agents a where a.user_id = p.id) then 'protected_account' end,
    case when p.trust_level < private.setting_num('room_mods.min_trust_level', 2) then 'trust_level' end,
    case when exists (select 1 from private.user_sanctions s
                      where s.user_id = p.id and s.category = 'zero_tolerance' and s.revoked_at is null)
         then 'zero_tolerance' end,
    case when exists (select 1 from private.user_sanctions s
                      where s.user_id = p.id and s.revoked_at is null
                        and (s.created_at > now() - private.setting_num('room_mods.sanction_free_days', 90) * interval '1 day'
                             or (s.kind <> 'warning' and (s.ends_at is null or s.ends_at > now()))))
         then 'recent_sanction' end
  ], null) end
  from (select p_user as id) x
  left join public.profiles p on p.id = x.id;
$$;

create or replace function private.room_mod_target_problem(p_target uuid, p_actor uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p.id is null then 'user_not_found'
    when p.id = p_actor then 'self_target'
    when p.olt_user_id like 'cs-staff:%' or p.olt_user_id like 'official:%' or private.is_official_account(p.id)
         or exists (select 1 from cs.agents a where a.user_id = p.id) then 'protected_account'
    when exists (select 1 from private.room_moderators m where m.user_id = p.id and m.removed_at is null)
         then 'moderator_target'
  end
  from (select p_target as id) x
  left join public.profiles p on p.id = x.id;
$$;

create or replace function private.require_room_moderator(p_room uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not private.is_room_moderator(p_room, v_me) then
    perform private.api_error(403, 'not_room_moderator', 'Anda bukan moderator room ini');
  end if;
  if cardinality(private.room_moderator_problems(v_me)) > 0 or private.is_muted(v_me) then
    perform private.api_error(403, 'room_moderator_suspended', 'Hak moderator Anda sedang ditangguhkan');
  end if;
  return v_me;
end;
$$;

create or replace function private.room_mod_check_note(p_note text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if char_length(v_note) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 500 karakter');
  end if;
  return v_note;
end;
$$;

create or replace function private.room_moderation_people(p_room uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'moderators', coalesce((select jsonb_agg(m.user_id order by m.appointed_at)
                            from private.room_moderators m
                            where m.room_id = p_room and m.removed_at is null), '[]'),
    'mutes', coalesce((select jsonb_agg(jsonb_build_object('user_id', x.target_user_id, 'until', x.until) order by x.until)
                       from (select a.target_user_id, max(a.mute_until) as until
                             from private.room_mod_actions a
                             where a.room_id = p_room and a.action = 'mute' and a.undone_at is null
                               and a.mute_until > now() and a.target_user_id is not null
                             group by a.target_user_id) x), '[]'));
$$;

create or replace function private.stock_room_state(p_room uuid, p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_id', p_room,
    'slow_mode', (select jsonb_build_object('seconds', s.seconds, 'until', s.until, 'source', s.source)
                  from private.room_slow_mode(p_room) s),
    'wait_seconds', case when p_user is null then 0 else private.slow_mode_wait(p_room, p_user) end,
    'pinned_message', (select to_jsonb(x) from private.chat_messages(array[m.pinned_message_id]) x
                       join public.messages msg on msg.id = x.id
                       where msg.deleted_at is null and msg.moderation_status = 'visible'),
    'pinned_at', (select m2.pinned_at from private.room_moderation m2
                  where m2.room_id = p_room and m2.pinned_message_id is not null))
    || private.room_moderation_people(p_room)
    || case when p_user is null then '{}'::jsonb
            else jsonb_build_object('is_moderator', private.is_room_moderator(p_room, p_user),
                                    'muted_until', private.room_mute_until(p_room, p_user)) end
  from (select (select rm.pinned_message_id from private.room_moderation rm where rm.room_id = p_room) as pinned_message_id) m;
$$;

create or replace function public.get_stock_room_state(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_room uuid;
  v_busy timestamptz;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham tidak valid');
  end if;
  v_room := private.stock_room_id(v_code);
  if v_room is null then
    v_busy := private.busy_window_end(now());
    return jsonb_build_object(
      'stock_code', v_code, 'room_id', null,
      'slow_mode', jsonb_build_object(
        'seconds', case when v_busy is null then 0 else private.setting_num('rooms.busy_slow_mode', 10)::integer end,
        'until', v_busy, 'source', case when v_busy is not null then 'schedule' end),
      'wait_seconds', 0, 'pinned_message', null, 'pinned_at', null,
      'moderators', '[]'::jsonb, 'mutes', '[]'::jsonb, 'is_moderator', false, 'muted_until', null);
  end if;
  return jsonb_build_object('stock_code', v_code) || private.stock_room_state(v_room, auth.uid());
end;
$$;

create or replace function private.room_broadcast(p_room uuid, p_event text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(p_payload, p_event, 'room:' || p_room::text, true);
exception when others then
  null;
end;
$$;

create or replace function private.enforce_room_mute()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  if new.sender_id is null then
    return new;
  end if;
  v_until := private.room_mute_until(new.room_id, new.sender_id);
  if v_until is null
     or private.client_id_exists('public.messages'::regclass, 'sender_id', new.sender_id, new.client_id) then
    return new;
  end if;
  perform private.api_error(403, 'room_muted',
    to_char(v_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  return new;
end;
$$;

create trigger messages_08_room_mute
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_room_mute();

create or replace function private.room_mod_message(p_message uuid)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg public.messages;
begin
  select m.* into v_msg from public.messages m
  join public.chat_rooms r on r.id = m.room_id and r.type = 'stock'
  where m.id = p_message and m.deleted_at is null and m.session_id is null and m.sender_id is not null
  for update of m;
  if v_msg.id is null then
    perform private.api_error(404, 'message_not_found', 'Pesan tidak ditemukan di room saham');
  end if;
  return v_msg;
end;
$$;

create or replace function private.room_mod_check_reason(p_reason text)
returns text
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_reason is null or p_reason <> all (private.room_mod_reasons()) then
    perform private.api_error(400, 'invalid_mod_reason',
      'Alasan: spam, abuse, scam, pump_and_dump, misinformation, atau other');
  end if;
  return p_reason;
end;
$$;

create or replace function private.room_mod_result(p_action private.room_mod_actions)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_action.id, 'room_id', p_action.room_id, 'action', p_action.action, 'reason', p_action.reason,
    'note', p_action.note, 'target_user_id', p_action.target_user_id, 'message_id', p_action.message_id,
    'mute_until', p_action.mute_until, 'created_at', p_action.created_at);
$$;

create or replace function public.room_mod_hide_message(p_message_id uuid, p_reason text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason  text := private.room_mod_check_reason(p_reason);
  v_note    text := private.room_mod_check_note(p_note);
  v_msg     public.messages;
  v_me      uuid;
  v_problem text;
  v_action  private.room_mod_actions;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_msg := private.room_mod_message(p_message_id);
  v_me := private.require_room_moderator(v_msg.room_id);
  v_problem := private.room_mod_target_problem(v_msg.sender_id, v_me);
  if v_problem is not null then
    perform private.api_error(403, v_problem, 'Pesan ini tidak bisa dimoderasi oleh moderator room');
  end if;
  if v_msg.moderation_status <> 'visible' then
    perform private.api_error(409, 'already_moderated', 'Pesan ini sudah dimoderasi');
  end if;
  perform private.consume_rate_limit(v_me, 'room_mod_action');
  update public.messages set moderation_status = 'hidden', moderated_at = now() where id = v_msg.id;
  insert into private.room_mod_actions (room_id, moderator_id, action, target_user_id, message_id, reason, note)
  values (v_msg.room_id, v_me, 'hide', v_msg.sender_id, v_msg.id, v_reason, v_note)
  returning * into v_action;
  perform private.room_broadcast(v_msg.room_id, 'message_hidden',
                                 jsonb_build_object('message_id', v_msg.id, 'user_id', v_msg.sender_id));
  return private.room_mod_result(v_action);
end;
$$;

create or replace function public.room_mod_mute_user(p_room_id uuid, p_user_id uuid, p_minutes integer, p_reason text,
                                                     p_note text default null, p_message_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason  text := private.room_mod_check_reason(p_reason);
  v_note    text := private.room_mod_check_note(p_note);
  v_max     integer := (private.setting_num('room_mods.max_mute_hours', 24) * 60)::integer;
  v_me      uuid;
  v_problem text;
  v_until   timestamptz;
  v_action  private.room_mod_actions;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_minutes is null or p_minutes < 5 or p_minutes > v_max then
    perform private.api_error(400, 'invalid_duration', 'Lama bisu 5 menit sampai ' || (v_max / 60) || ' jam');
  end if;
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'stock') then
    perform private.api_error(404, 'room_not_found', 'Room saham tidak ditemukan');
  end if;
  v_me := private.require_room_moderator(p_room_id);
  v_problem := private.room_mod_target_problem(p_user_id, v_me);
  if v_problem is not null then
    perform private.api_error(403, v_problem, 'Pengguna ini tidak bisa dibisukan oleh moderator room');
  end if;
  if not exists (select 1 from public.chat_members cm where cm.room_id = p_room_id and cm.user_id = p_user_id) then
    perform private.api_error(404, 'user_not_found', 'Pengguna bukan anggota room ini');
  end if;
  if p_message_id is not null and not exists (
       select 1 from public.messages m where m.id = p_message_id and m.room_id = p_room_id and m.sender_id = p_user_id) then
    perform private.api_error(400, 'invalid_message', 'Pesan harus milik pengguna ini di room yang sama');
  end if;
  v_until := now() + make_interval(mins => p_minutes);
  if private.room_mute_until(p_room_id, p_user_id) >= v_until then
    perform private.api_error(409, 'already_muted', 'Pengguna ini sudah dibisukan lebih lama');
  end if;
  perform private.consume_rate_limit(v_me, 'room_mod_action');
  insert into private.room_mod_actions (room_id, moderator_id, action, target_user_id, message_id, reason, note, mute_until)
  values (p_room_id, v_me, 'mute', p_user_id, p_message_id, v_reason, v_note, v_until)
  returning * into v_action;
  perform private.broadcast_room_state(p_room_id);
  return private.room_mod_result(v_action);
end;
$$;

create or replace function public.room_mod_escalate(p_message_id uuid, p_reason text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := private.room_mod_check_reason(p_reason);
  v_note   text := private.room_mod_check_note(p_note);
  v_msg    public.messages;
  v_me     uuid;
  v_code   text;
  v_report uuid;
  v_action private.room_mod_actions;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_msg := private.room_mod_message(p_message_id);
  v_me := private.require_room_moderator(v_msg.room_id);
  if v_msg.sender_id = v_me then
    perform private.api_error(403, 'self_target', 'Pesan sendiri tidak bisa dieskalasi');
  end if;
  if exists (select 1 from private.room_mod_actions a
             where a.message_id = v_msg.id and a.action = 'escalate' and a.undone_at is null) then
    perform private.api_error(409, 'already_escalated', 'Pesan ini sudah dieskalasi ke staf');
  end if;
  perform private.consume_rate_limit(v_me, 'room_mod_action');
  select r.stock_code into v_code from public.chat_rooms r where r.id = v_msg.room_id;
  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values (v_me, 'message', v_msg.id, v_reason,
          left('[Moderator room $' || v_code || ']' || coalesce(' ' || v_note, ''), 1000))
  on conflict (reporter_id, target_type, target_id) do update
    set reason = excluded.reason, details = excluded.details, status = 'open',
        resolution_note = null, resolved_at = null
  returning id into v_report;
  insert into private.room_mod_actions (room_id, moderator_id, action, target_user_id, message_id, reason, note, report_id)
  values (v_msg.room_id, v_me, 'escalate', v_msg.sender_id, v_msg.id, v_reason, v_note, v_report)
  returning * into v_action;
  return private.room_mod_result(v_action) || jsonb_build_object('report_id', v_report);
end;
$$;

create or replace function private.room_moderators_on_sanction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rooms uuid[];
  v_room  uuid;
begin
  with removed as (
    update private.room_moderators
       set removed_at = now(), removed_by = new.created_by,
           remove_reason = left('Otomatis: sanksi ' || new.kind || ' — ' || new.reason, 500)
     where user_id = new.user_id and removed_at is null
    returning room_id
  )
  select coalesce(array_agg(room_id), '{}') into v_rooms from removed;
  if cardinality(v_rooms) > 0 then
    perform cs.audit('community.room_moderator_auto_remove', null, new.user_id,
                     jsonb_build_object('rooms', to_jsonb(v_rooms), 'sanction_id', new.id, 'kind', new.kind));
    foreach v_room in array v_rooms loop
      perform private.broadcast_room_state(v_room);
    end loop;
  end if;
  return null;
end;
$$;

create trigger user_sanctions_40_room_moderators
  after insert on private.user_sanctions
  for each row execute function private.room_moderators_on_sanction();

create or replace function cs.room_mod_user_ref(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p.id is not null then jsonb_build_object(
    'id', p.id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
    'trust_level', p.trust_level, 'deleted', p.deleted_at is not null) end
  from (select p_user as id) x
  left join public.profiles p on p.id = x.id;
$$;

create or replace function cs.room_moderator_view(p_row private.room_moderators)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_row.id, 'room_id', p_row.room_id,
    'user', cs.community_user_row(p),
    'note', p_row.note, 'appointed_by', cs.staff_ref(p_row.appointed_by), 'appointed_at', p_row.appointed_at,
    'removed_at', p_row.removed_at, 'removed_by', cs.staff_ref(p_row.removed_by), 'remove_reason', p_row.remove_reason,
    'problems', to_jsonb(private.room_moderator_problems(p_row.user_id)),
    'actions_7d', (select count(*) from private.room_mod_actions a
                   where a.moderator_id = p_row.user_id and a.room_id = p_row.room_id
                     and a.created_at > now() - interval '7 days'),
    'undone_7d', (select count(*) from private.room_mod_actions a
                  where a.moderator_id = p_row.user_id and a.room_id = p_row.room_id
                    and a.created_at > now() - interval '7 days' and a.undone_at is not null))
  from public.profiles p
  where p.id = p_row.user_id;
$$;

create or replace function cs.room_mod_settings_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(s.key, s.value order by s.key), '{}')
  from private.settings s
  where s.key like 'room_mods.%';
$$;

create or replace function cs.room_moderators_view(p_room uuid, p_code text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_id', p_room,
    'stock_code', upper(btrim(coalesce(p_code, ''))),
    'moderators', coalesce((select jsonb_agg(cs.room_moderator_view(m) order by m.appointed_at)
                            from private.room_moderators m
                            where m.room_id = p_room and m.removed_at is null), '[]'),
    'removed', coalesce((select jsonb_agg(cs.room_moderator_view(m) order by m.removed_at desc)
                         from (select * from private.room_moderators m
                               where m.room_id = p_room and m.removed_at is not null
                               order by m.removed_at desc limit 20) m), '[]'),
    'settings', cs.room_mod_settings_view());
$$;

create or replace function cs_api.community_room_moderators(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_code text := upper(btrim(coalesce(p_code, '')));
begin
  if v_code !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham tidak valid');
  end if;
  return cs.room_moderators_view(private.stock_room_id(v_code), v_code);
end;
$$;

create or replace function cs_api.community_room_moderator_candidates(p_code text, p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid := private.stock_room_id(p_code);
  v_text text := btrim(coalesce(p_query, ''));
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(ltrim(v_text, '@'), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(cs.community_user_row(x) || jsonb_build_object(
             'problems', to_jsonb(private.room_moderator_problems(x.id)),
             'eligible', cardinality(private.room_moderator_problems(x.id)) = 0,
             'is_moderator', v_room is not null and private.is_room_moderator(v_room, x.id),
             'moderated_rooms', (select count(*) from private.room_moderators m
                                 where m.user_id = x.id and m.removed_at is null),
             'member', v_room is not null and exists (select 1 from public.chat_members cm
                                                     where cm.room_id = v_room and cm.user_id = x.id))
           order by x.username)
    from (select p.* from public.profiles p
          where p.olt_user_id not like 'cs-staff:%' and p.deleted_at is null
            and (p.username::text ilike v_like or p.display_name ilike v_like)
          order by (p.username::text ilike ltrim(v_text, '@')) desc, p.username
          limit 20) x), '[]');
end;
$$;

create or replace function cs_api.community_appoint_room_moderator(p_code text, p_user_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.moderate}');
  v_note     text := private.room_mod_check_note(p_note);
  v_room     uuid;
  v_problems text[];
begin
  v_problems := private.room_moderator_problems(p_user_id);
  if 'user_not_found' = any (v_problems) then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  if cardinality(v_problems) > 0 then
    perform private.api_error(400, 'not_eligible', array_to_string(v_problems, ','));
  end if;
  v_room := cs.ensure_stock_room(p_code);
  perform 1 from public.chat_rooms r where r.id = v_room for update;
  if private.is_room_moderator(v_room, p_user_id) then
    perform private.api_error(409, 'already_moderator', 'Pengguna ini sudah menjadi moderator room ini');
  end if;
  if (select count(*) from private.room_moderators m where m.room_id = v_room and m.removed_at is null)
     >= private.setting_num('room_mods.max_per_room', 10) then
    perform private.api_error(409, 'room_moderator_limit', 'Jumlah moderator room ini sudah maksimal');
  end if;
  if (select count(*) from private.room_moderators m where m.user_id = p_user_id and m.removed_at is null)
     >= private.setting_num('room_mods.max_rooms_per_user', 3) then
    perform private.api_error(409, 'user_moderator_limit', 'Pengguna ini sudah memoderasi jumlah room maksimal');
  end if;
  insert into private.room_moderators (room_id, user_id, note, appointed_by)
  values (v_room, p_user_id, v_note, v_me);
  insert into public.chat_members (room_id, user_id) values (v_room, p_user_id) on conflict do nothing;
  perform cs.audit('community.room_moderator_appoint', null, p_user_id,
                   jsonb_build_object('room', v_room, 'stock', upper(btrim(p_code)), 'note', v_note));
  perform private.broadcast_room_state(v_room);
  return cs.room_moderators_view(v_room, p_code);
end;
$$;

create or replace function cs_api.community_remove_room_moderator(p_code text, p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.moderate}');
  v_reason text := btrim(coalesce(p_reason, ''));
  v_room   uuid := private.stock_room_id(p_code);
  v_row    private.room_moderators;
begin
  if char_length(v_reason) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  update private.room_moderators
     set removed_at = now(), removed_by = v_me, remove_reason = v_reason
   where room_id = v_room and user_id = p_user_id and removed_at is null
  returning * into v_row;
  if v_row.id is null then
    perform private.api_error(404, 'moderator_not_found', 'Moderator room tidak ditemukan');
  end if;
  perform cs.audit('community.room_moderator_remove', null, p_user_id,
                   jsonb_build_object('room', v_room, 'stock', upper(btrim(p_code)), 'reason', v_reason,
                                      'appointed_at', v_row.appointed_at));
  perform private.broadcast_room_state(v_room);
  return cs.room_moderators_view(v_room, p_code);
end;
$$;

create or replace function cs.room_mod_action_view(p_action private.room_mod_actions)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_action.id, 'room_id', p_action.room_id,
    'stock_code', (select r.stock_code from public.chat_rooms r where r.id = p_action.room_id),
    'action', p_action.action, 'reason', p_action.reason, 'note', p_action.note,
    'created_at', p_action.created_at, 'mute_until', p_action.mute_until,
    'mute_active', p_action.action = 'mute' and p_action.undone_at is null and p_action.mute_until > now(),
    'moderator', cs.room_mod_user_ref(p_action.moderator_id),
    'moderator_active', p_action.moderator_id is not null
                        and private.is_room_moderator(p_action.room_id, p_action.moderator_id),
    'target', cs.room_mod_user_ref(p_action.target_user_id),
    'message', (select jsonb_build_object('id', m.id, 'excerpt', left(m.body, 280),
                                          'attachments', jsonb_array_length(coalesce(m.attachments, '[]'::jsonb)),
                                          'moderation_status', m.moderation_status,
                                          'deleted', m.deleted_at is not null, 'created_at', m.created_at)
                from public.messages m where m.id = p_action.message_id),
    'report', (select jsonb_build_object('id', r.id, 'status', r.status)
               from public.reports r where r.id = p_action.report_id),
    'appeal', (select jsonb_build_object('id', a.id, 'status', a.status)
               from public.appeals a
               where p_action.action = 'hide' and a.target_type = 'message' and a.target_id = p_action.message_id),
    'undone_at', p_action.undone_at, 'undone_by', cs.staff_ref(p_action.undone_by), 'undo_note', p_action.undo_note,
    'can_undo', p_action.undone_at is null and case p_action.action
      when 'hide' then exists (select 1 from public.messages m
                               where m.id = p_action.message_id and m.moderation_status = 'hidden'
                                 and m.deleted_at is null)
      when 'mute' then p_action.mute_until > now()
      else false end);
$$;

create or replace function cs_api.community_room_moderator_actions(p_code text default null, p_limit integer default 50,
                                                                   p_before timestamptz default null,
                                                                   p_before_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.moderate}');
  v_code  text := nullif(upper(btrim(coalesce(p_code, ''))), '');
  v_room  uuid;
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if v_code is not null then
    v_room := private.stock_room_id(v_code);
    if v_room is null then
      return jsonb_build_object('items', '[]'::jsonb);
    end if;
  end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(cs.room_mod_action_view(a) order by a.created_at desc, a.id desc)
    from (select * from private.room_mod_actions a
          where (v_room is null or a.room_id = v_room)
            and (p_before is null or a.created_at < p_before
                 or (p_before_id is not null and a.created_at = p_before and a.id < p_before_id))
          order by a.created_at desc, a.id desc
          limit v_limit) a), '[]'));
end;
$$;

create or replace function cs_api.community_undo_room_moderator_action(p_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.moderate}');
  v_note   text := btrim(coalesce(p_note, ''));
  v_action private.room_mod_actions;
  v_count  integer := 0;
  v_appeal public.appeals;
begin
  if char_length(v_note) not between 5 and 500 then
    perform private.api_error(400, 'note_required', 'Catatan 5–500 karakter');
  end if;
  select * into v_action from private.room_mod_actions where id = p_id for update;
  if v_action.id is null then
    perform private.api_error(404, 'action_not_found', 'Aksi moderator tidak ditemukan');
  end if;
  if v_action.undone_at is not null then
    perform private.api_error(409, 'action_undone', 'Aksi ini sudah dibatalkan');
  end if;
  if v_action.action = 'escalate' then
    perform private.api_error(400, 'undo_not_supported', 'Eskalasi ditindaklanjuti dari antrean laporan');
  end if;
  if v_action.action = 'hide' then
    update public.messages set moderation_status = 'visible', moderated_at = now()
     where id = v_action.message_id and moderation_status = 'hidden' and deleted_at is null;
    get diagnostics v_count = row_count;
    if v_count > 0 then
      for v_appeal in
        update public.appeals
           set status = 'accepted', decided_by = v_me, decided_at = now(),
               decision_note = left('Dipulihkan staf: ' || v_note, 1000)
         where target_type = 'message' and target_id = v_action.message_id and status = 'pending'
        returning *
      loop
        perform private.notify(v_appeal.user_id, null, 'appeal', jsonb_build_object(
          'appeal_id', v_appeal.id, 'status', 'accepted', 'target_type', 'message',
          'target_id', v_appeal.target_id, 'note', v_appeal.decision_note,
          'title', 'Banding Anda diterima', 'body', 'Konten Anda telah dipulihkan.'));
      end loop;
    end if;
  else
    v_count := case when v_action.mute_until > now() then 1 else 0 end;
  end if;
  if v_count = 0 then
    perform private.api_error(409, 'nothing_to_undo', 'Tidak ada yang perlu dibatalkan');
  end if;
  update private.room_mod_actions
     set undone_at = now(), undone_by = v_me, undo_note = v_note
   where id = p_id
  returning * into v_action;
  if v_action.action = 'mute' then
    perform private.broadcast_room_state(v_action.room_id);
  end if;
  perform cs.audit('community.room_moderator_undo', null, v_action.target_user_id,
                   jsonb_build_object('action_id', v_action.id, 'action', v_action.action, 'room', v_action.room_id,
                                      'moderator', v_action.moderator_id, 'message', v_action.message_id,
                                      'note', v_note));
  return cs.room_mod_action_view(v_action);
end;
$$;

create or replace function cs_api.community_room_moderator_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  return cs.room_mod_settings_view();
end;
$$;

create or replace function cs_api.community_set_room_moderator_settings(p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_old   jsonb := cs.room_mod_settings_view();
  v_key   text;
  v_value jsonb;
  v_min   numeric;
  v_max   numeric;
begin
  if jsonb_typeof(p_values) is distinct from 'object' or p_values = '{}'::jsonb then
    perform private.api_error(400, 'invalid_setting', 'Kirim objek pengaturan');
  end if;
  for v_key, v_value in select * from jsonb_each(p_values) loop
    select x.lo, x.hi into v_min, v_max
    from (values ('room_mods.min_trust_level', 1, 3), ('room_mods.sanction_free_days', 0, 365),
                 ('room_mods.max_mute_hours', 1, 24), ('room_mods.max_per_room', 1, 50),
                 ('room_mods.max_rooms_per_user', 1, 20)) x(k, lo, hi)
    where x.k = v_key;
    if v_min is null then
      perform private.api_error(400, 'invalid_setting', 'Pengaturan tidak dikenal: ' || v_key);
    end if;
    if jsonb_typeof(v_value) <> 'number' or (v_value #>> '{}')::numeric <> trunc((v_value #>> '{}')::numeric)
       or (v_value #>> '{}')::numeric not between v_min and v_max then
      perform private.api_error(400, 'invalid_setting', v_key || ' harus bilangan bulat ' || v_min || '–' || v_max);
    end if;
    update private.settings set value = v_value, updated_at = now() where key = v_key;
  end loop;
  perform cs.audit('community.room_moderator_settings', null, null,
    jsonb_build_object('from', (select jsonb_object_agg(k, v_old -> k) from jsonb_object_keys(p_values) k), 'to', p_values));
  return cs.room_mod_settings_view();
end;
$$;

revoke execute on function private.room_mod_reasons() from public;
revoke execute on function private.is_room_moderator(uuid, uuid) from public;
revoke execute on function private.room_mute_until(uuid, uuid) from public;
revoke execute on function private.room_moderator_problems(uuid) from public;
revoke execute on function private.room_mod_target_problem(uuid, uuid) from public;
revoke execute on function private.require_room_moderator(uuid) from public;
revoke execute on function private.room_mod_check_note(text) from public;
revoke execute on function private.room_mod_check_reason(text) from public;
revoke execute on function private.room_moderation_people(uuid) from public;
revoke execute on function private.room_broadcast(uuid, text, jsonb) from public;
revoke execute on function private.enforce_room_mute() from public;
revoke execute on function private.room_mod_message(uuid) from public;
revoke execute on function private.room_mod_result(private.room_mod_actions) from public;
revoke execute on function private.room_moderators_on_sanction() from public;
revoke execute on function public.room_mod_hide_message(uuid, text, text) from public, anon;
revoke execute on function public.room_mod_mute_user(uuid, uuid, integer, text, text, uuid) from public, anon;
revoke execute on function public.room_mod_escalate(uuid, text, text) from public, anon;
revoke execute on function cs.room_mod_user_ref(uuid) from public;
revoke execute on function cs.room_moderator_view(private.room_moderators) from public;
revoke execute on function cs.room_mod_settings_view() from public;
revoke execute on function cs.room_moderators_view(uuid, text) from public;
revoke execute on function cs.room_mod_action_view(private.room_mod_actions) from public;
revoke execute on function cs_api.community_room_moderators(text) from public;
revoke execute on function cs_api.community_room_moderator_candidates(text, text) from public;
revoke execute on function cs_api.community_appoint_room_moderator(text, uuid, text) from public;
revoke execute on function cs_api.community_remove_room_moderator(text, uuid, text) from public;
revoke execute on function cs_api.community_room_moderator_actions(text, integer, timestamptz, uuid) from public;
revoke execute on function cs_api.community_undo_room_moderator_action(uuid, text) from public;
revoke execute on function cs_api.community_room_moderator_settings() from public;
revoke execute on function cs_api.community_set_room_moderator_settings(jsonb) from public;

grant execute on function public.room_mod_hide_message(uuid, text, text) to authenticated;
grant execute on function public.room_mod_mute_user(uuid, uuid, integer, text, text, uuid) to authenticated;
grant execute on function public.room_mod_escalate(uuid, text, text) to authenticated;
grant execute on function cs_api.community_room_moderators(text) to authenticated;
grant execute on function cs_api.community_room_moderator_candidates(text, text) to authenticated;
grant execute on function cs_api.community_appoint_room_moderator(text, uuid, text) to authenticated;
grant execute on function cs_api.community_remove_room_moderator(text, uuid, text) to authenticated;
grant execute on function cs_api.community_room_moderator_actions(text, integer, timestamptz, uuid) to authenticated;
grant execute on function cs_api.community_undo_room_moderator_action(uuid, text) to authenticated;
grant execute on function cs_api.community_room_moderator_settings() to authenticated;
grant execute on function cs_api.community_set_room_moderator_settings(jsonb) to authenticated;
