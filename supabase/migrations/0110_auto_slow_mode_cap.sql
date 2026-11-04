update private.settings
   set value = '10', updated_at = now()
 where key = 'manipulation.auto_slow_mode_seconds' and value = '30'::jsonb;

update private.settings
   set description = 'Aksi otomatis: jeda slow mode (detik), paling ketat sama dengan slow mode jam ramai'
 where key = 'manipulation.auto_slow_mode_seconds';

create or replace function private.auto_slow_mode_cap()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when private.setting_num('rooms.busy_slow_mode', 10) > 0
              then private.setting_num('rooms.busy_slow_mode', 10)::integer
              else 10 end;
$$;

create or replace function cs.manipulation_slow_mode(p_alert cs.manipulation_alerts, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room    uuid := private.stock_room_id(p_alert.stock);
  v_cap     integer := private.auto_slow_mode_cap();
  v_seconds integer := least(private.setting_num('manipulation.auto_slow_mode_seconds', 10)::integer, v_cap);
  v_until   timestamptz := p_at + make_interval(mins => private.setting_num('manipulation.auto_slow_mode_minutes', 60)::integer);
  v_mod     private.room_moderation;
begin
  if v_room is null or not (private.setting_json('manipulation.auto_slow_mode', 'true') = 'true'::jsonb)
     or v_seconds <= 0 then
    return;
  end if;
  select * into v_mod from private.room_moderation where room_id = v_room for update;
  if v_mod.room_id is not null and v_mod.slow_mode_seconds > 0
     and (v_mod.slow_mode_until is null or v_mod.slow_mode_until > p_at)
     and (v_mod.slow_mode_source = 'manual' or v_mod.slow_mode_until is null) then
    return;
  end if;
  insert into private.room_moderation (room_id, slow_mode_seconds, slow_mode_until, slow_mode_source, alert_id)
  values (v_room, v_seconds, v_until, 'alert', p_alert.id)
  on conflict (room_id) do update
    set slow_mode_seconds = least(greatest(excluded.slow_mode_seconds,
                                           case when private.room_moderation.slow_mode_until > p_at
                                                then private.room_moderation.slow_mode_seconds else 0 end), v_cap),
        slow_mode_until = greatest(excluded.slow_mode_until, private.room_moderation.slow_mode_until),
        slow_mode_source = 'alert', alert_id = excluded.alert_id, updated_at = now();
  update cs.manipulation_alerts
     set auto_actions = auto_actions || jsonb_build_object('slow_mode', jsonb_build_object(
           'seconds', (select m.slow_mode_seconds from private.room_moderation m where m.room_id = v_room),
           'until', (select m.slow_mode_until from private.room_moderation m where m.room_id = v_room)))
   where id = p_alert.id;
  perform private.broadcast_room_state(v_room);
end;
$$;

update private.room_moderation
   set slow_mode_seconds = private.auto_slow_mode_cap(), updated_at = now()
 where slow_mode_source = 'alert' and slow_mode_seconds > private.auto_slow_mode_cap()
   and (slow_mode_until is null or slow_mode_until > now());

revoke execute on function private.auto_slow_mode_cap() from public;
