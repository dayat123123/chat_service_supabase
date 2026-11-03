create or replace function private.room_mutes(p_room uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.target_user_id, 'until', x.until) order by x.until), '[]')
  from (select a.target_user_id, max(a.mute_until) as until
        from private.room_mod_actions a
        where a.room_id = p_room and a.action = 'mute' and a.undone_at is null
          and a.mute_until > now() and a.target_user_id is not null
        group by a.target_user_id) x;
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
                  where m2.room_id = p_room and m2.pinned_message_id is not null),
    'moderators', coalesce((select jsonb_agg(rm.user_id order by rm.appointed_at)
                            from private.room_moderators rm
                            where rm.room_id = p_room and rm.removed_at is null), '[]'))
    || case when p_user is null then '{}'::jsonb
            else jsonb_build_object('is_moderator', v.moderator, 'muted_until', private.room_mute_until(p_room, p_user))
                 || case when v.moderator then jsonb_build_object('mutes', private.room_mutes(p_room))
                         else '{}'::jsonb end end
  from (select (select rm.pinned_message_id from private.room_moderation rm where rm.room_id = p_room) as pinned_message_id) m
  cross join (select p_user is not null and private.is_room_moderator(p_room, p_user) as moderator) v;
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
      'moderators', '[]'::jsonb, 'is_moderator', false, 'muted_until', null);
  end if;
  return jsonb_build_object('stock_code', v_code) || private.stock_room_state(v_room, auth.uid());
end;
$$;

create or replace function cs.room_admin_view(p_room uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.stock_room_state(p_room, null)
      || jsonb_build_object(
           'stock_code', r.stock_code,
           'mutes', private.room_mutes(p_room),
           'override', (select jsonb_build_object('seconds', m.slow_mode_seconds, 'until', m.slow_mode_until,
                                                  'source', m.slow_mode_source, 'alert_id', m.alert_id,
                                                  'updated_by', cs.staff_ref(m.updated_by), 'updated_at', m.updated_at,
                                                  'pinned_by', cs.staff_ref(m.pinned_by))
                        from private.room_moderation m where m.room_id = p_room),
           'open_alerts', coalesce((select jsonb_agg(cs.alert_view(a) order by a.last_detected_at desc)
                                    from cs.manipulation_alerts a where a.stock = r.stock_code and a.status = 'open'), '[]'))
  from public.chat_rooms r
  where r.id = p_room;
$$;

create or replace function private.room_mute_notice(p_room uuid, p_user uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz := private.room_mute_until(p_room, p_user);
begin
  perform private.moderation_notice('room', p_room, p_user, case when v_until is null then 'unmuted' else 'muted' end, null,
    jsonb_build_object('room_id', p_room,
                       'stock_code', (select r.stock_code from public.chat_rooms r where r.id = p_room),
                       'until', v_until, 'reason', p_reason, 'appealable', false));
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
  perform private.room_mute_notice(p_room_id, p_user_id, v_reason);
  return private.room_mod_result(v_action);
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
    perform private.room_mute_notice(v_action.room_id, v_action.target_user_id);
  end if;
  perform cs.audit('community.room_moderator_undo', null, v_action.target_user_id,
                   jsonb_build_object('action_id', v_action.id, 'action', v_action.action, 'room', v_action.room_id,
                                      'moderator', v_action.moderator_id, 'message', v_action.message_id,
                                      'note', v_note));
  return cs.room_mod_action_view(v_action);
end;
$$;

create or replace function private.notification_push(n public.notifications)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name     text;
  v_username text;
  v_id       text;
  v_en       text;
  v_others   integer := n.event_count - 1;
  v_snippet  text := coalesce(n.payload ->> 'snippet', '');
  v_snip_en  text;
  v_room     text := nullif(btrim(coalesce(n.payload ->> 'room_name', '')), '');
  v_place    text;
  v_codes    text;
  v_more     integer;
  v_what_id  text;
  v_what_en  text;
  v_title    jsonb;
  v_body     jsonb;
  v_until    text;
begin
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text), p.username::text into v_name, v_username
  from public.profiles p where p.id = n.actor_id;
  v_id := coalesce(v_name, 'Seseorang');
  v_en := coalesce(v_name, 'Someone');
  v_snip_en := case when v_snippet = '[lampiran]' then '[attachment]' else v_snippet end;
  v_body := jsonb_build_object('id', v_snippet, 'en', v_snip_en);

  case n.type
    when 'reply' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya membalas postingan Anda', v_id, v_others),
                                'en', format('%s and %s others replied to your post', v_en, v_others))
        else jsonb_build_object('id', format('%s membalas Anda', v_id), 'en', format('%s replied to you', v_en)) end;
    when 'mention' then
      if n.payload ? 'room_id' then
        v_place := coalesce('$' || nullif(n.payload ->> 'stock_code', ''), v_room, 'room saham');
        v_title := jsonb_build_object('id', format('%s menyebut Anda di %s', v_id, v_place),
                                      'en', format('%s mentioned you in %s', v_en, v_place));
      else
        v_title := jsonb_build_object('id', format('%s menyebut Anda', v_id), 'en', format('%s mentioned you', v_en));
      end if;
    when 'like' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya menyukai konten Anda', v_id, v_others),
                                'en', format('%s and %s others liked your content', v_en, v_others))
        else jsonb_build_object('id', format('%s menyukai konten Anda', v_id),
                                'en', format('%s liked your content', v_en)) end;
    when 'follow' then
      v_title := jsonb_build_object('id', format('%s mulai mengikuti Anda', v_id),
                                    'en', format('%s started following you', v_en));
      v_body := '""';
    when 'message' then
      if n.payload ->> 'room_type' = 'support' then
        v_title := to_jsonb(coalesce(v_room, cs.setting('brand.support_name') #>> '{}', 'Customer Service'));
      elsif n.payload ->> 'room_type' = 'group' then
        v_title := to_jsonb(coalesce(v_room, v_id));
        v_body := jsonb_build_object('id', format('%s: %s', v_id, v_snippet), 'en', format('%s: %s', v_en, v_snip_en));
      elsif n.event_count > 1 then
        v_title := jsonb_build_object('id', format('%s · %s pesan baru', v_id, n.event_count),
                                      'en', format('%s · %s new messages', v_en, n.event_count));
      else
        v_title := jsonb_build_object('id', v_id, 'en', v_en);
      end if;
    when 'announcement' then
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          jsonb_build_object('id', format('%s membuat pengumuman', v_id),
                                             'en', format('%s posted an announcement', v_en)));
      v_body := to_jsonb(coalesce(n.payload ->> 'body', ''));
    when 'followed_post' then
      v_title := jsonb_build_object('id', format('%s membuat postingan baru', v_id),
                                    'en', format('%s shared a new post', v_en));
    when 'watchlist_digest' then
      select string_agg('$' || t.code, ', ' order by t.ord) into v_codes
      from jsonb_array_elements_text(coalesce(n.payload -> 'stocks', '[]')) with ordinality as t(code, ord);
      v_more := greatest(coalesce((n.payload ->> 'stock_count')::integer, 0)
                         - jsonb_array_length(coalesce(n.payload -> 'stocks', '[]')), 0);
      v_title := '{"id": "Ringkasan saham pantauan", "en": "Watchlist digest"}';
      v_body := jsonb_build_object(
        'id', format('%s postingan baru tentang %s', n.payload ->> 'post_count', coalesce(v_codes, 'saham pantauan'))
              || case when v_more > 0 then format(', dan %s saham lainnya', v_more) else '' end,
        'en', format('%s new posts about %s', n.payload ->> 'post_count', coalesce(v_codes, 'your watchlist'))
              || case when v_more > 0 then format(' and %s more', v_more) else '' end);
    when 'moderation' then
      if n.payload ->> 'target_type' = 'room' then
        v_place := coalesce('$' || nullif(n.payload ->> 'stock_code', ''), v_room, 'room saham');
        v_until := to_char((n.payload ->> 'until')::timestamptz at time zone 'Asia/Jakarta', 'DD/MM HH24:MI');
        if n.payload ->> 'state' = 'muted' then
          v_title := jsonb_build_object('id', format('Anda dibisukan moderator di %s', v_place),
                                        'en', format('A moderator muted you in %s', v_place));
          v_body := case when v_until is null then '{"id": "", "en": ""}'::jsonb
            else jsonb_build_object('id', format('Anda bisa mengirim pesan lagi setelah %s WIB', v_until),
                                    'en', format('You can send messages again after %s WIB', v_until)) end;
        else
          v_title := jsonb_build_object('id', format('Bisu Anda di %s dicabut', v_place),
                                        'en', format('Your mute in %s was lifted', v_place));
          v_body := '{"id": "Anda bisa mengirim pesan lagi di room ini", "en": "You can send messages in this room again"}'::jsonb;
        end if;
      else
        v_what_id := case n.payload ->> 'target_type' when 'post' then 'Postingan' when 'comment' then 'Komentar' else 'Pesan' end;
        v_what_en := case n.payload ->> 'target_type' when 'post' then 'post' when 'comment' then 'comment' else 'message' end;
        v_title := case when n.payload ->> 'state' = 'removed'
          then jsonb_build_object('id', v_what_id || ' Anda dihapus moderator',
                                  'en', format('Your %s was removed by a moderator', v_what_en))
          else jsonb_build_object('id', v_what_id || ' Anda disembunyikan moderator',
                                  'en', format('Your %s was hidden by a moderator', v_what_en)) end;
        v_body := case when coalesce((n.payload ->> 'appealable')::boolean, false)
          then '{"id": "Ketuk untuk melihat detail dan mengajukan banding", "en": "Tap to see details and appeal"}'::jsonb
          else '{"id": "Ketuk untuk melihat detail", "en": "Tap to see details"}'::jsonb end;
      end if;
    else
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          '{"id": "Notifikasi baru", "en": "New notification"}'::jsonb);
      v_body := coalesce(to_jsonb(n.payload ->> 'body'), v_body);
  end case;

  return private.push_enqueue(
    n.user_id, n.type, v_title, v_body,
    (select coalesce(jsonb_object_agg(e.key, e.value), '{}') from jsonb_each(n.payload) e
      where e.key not in ('title', 'body', 'snippet', 'excerpt'))
      || jsonb_build_object('source', 'rendezvous_community', 'type', n.type, 'notification_id', n.id,
                            'actor_id', n.actor_id, 'actor_username', v_username),
    jsonb_build_object(
      'collapse_key', n.group_key,
      'priority', case when n.type in ('like', 'follow', 'followed_post', 'watchlist_digest') then 'normal' else 'high' end,
      'ref', case when n.payload ? 'campaign_id' then 'campaign:' || (n.payload ->> 'campaign_id') end));
end;
$$;

revoke execute on function private.room_mutes(uuid) from public;
revoke execute on function private.room_mute_notice(uuid, uuid, text) from public;
