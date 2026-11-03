insert into private.settings (key, value, description) values
  ('manipulation.spike_factor', '5', 'Lonjakan: mention 1 jam terakhir > faktor × rata-rata per jam periode dasar'),
  ('manipulation.spike_min_mentions', '20', 'Lonjakan: minimal mention dalam 1 jam terakhir'),
  ('manipulation.baseline_days', '7', 'Lonjakan: panjang periode dasar (hari)'),
  ('manipulation.new_account_share', '0.6', 'Konsentrasi akun baru: porsi mention dari akun baru (0–1)'),
  ('manipulation.new_account_min_mentions', '10', 'Konsentrasi akun baru: minimal mention dalam 1 jam terakhir'),
  ('manipulation.new_account_age_days', '7', 'Konsentrasi akun baru: umur akun yang dianggap baru (hari)'),
  ('manipulation.similarity', '0.8', 'Posting terkoordinasi: kemiripan teks minimal (pg_trgm, 0–1)'),
  ('manipulation.similar_min_authors', '5', 'Posting terkoordinasi: minimal penulis berbeda'),
  ('manipulation.similar_window_minutes', '30', 'Posting terkoordinasi: jendela waktu (menit)'),
  ('manipulation.auto_slow_mode', 'true', 'Aksi otomatis: slow mode di room saham saat ada alert'),
  ('manipulation.auto_slow_mode_seconds', '30', 'Aksi otomatis: jeda slow mode (detik)'),
  ('manipulation.auto_slow_mode_minutes', '60', 'Aksi otomatis: lama slow mode (menit)'),
  ('manipulation.auto_hold_similar', 'true', 'Aksi otomatis: tahan (held) posting mirip terkoordinasi'),
  ('rooms.busy_slow_mode', '10', 'Slow mode otomatis room saham pada jam ramai hari bursa (detik, 0 = mati)'),
  ('rooms.busy_windows', '[["08:55", "09:30"], ["15:50", "16:15"]]', 'Jam ramai (WIB) untuk slow mode otomatis')
on conflict (key) do nothing;

create table cs.manipulation_alerts (
  id               uuid primary key default gen_random_uuid(),
  stock            text not null,
  kind             text not null,
  score            numeric not null,
  evidence         jsonb not null default '{}',
  status           text not null default 'open',
  auto_actions     jsonb not null default '{}',
  detected_at      timestamptz not null default now(),
  last_detected_at timestamptz not null default now(),
  reviewed_by      uuid references cs.agents (user_id),
  reviewed_at      timestamptz,
  review_note      text,
  constraint manipulation_alerts_stock check (stock ~ '^[A-Z][A-Z0-9]{1,11}$'),
  constraint manipulation_alerts_kind check (kind in ('mention_spike', 'new_account_concentration', 'coordinated_posts')),
  constraint manipulation_alerts_status check (status in ('open', 'reviewed', 'dismissed')),
  constraint manipulation_alerts_note check (char_length(review_note) <= 500)
);
create unique index manipulation_alerts_open_idx on cs.manipulation_alerts (stock, kind) where status = 'open';
create index manipulation_alerts_status_idx on cs.manipulation_alerts (status, last_detected_at desc);
alter table cs.manipulation_alerts enable row level security;

create table private.room_moderation (
  room_id           uuid primary key references public.chat_rooms (id) on delete cascade,
  slow_mode_seconds integer not null default 0,
  slow_mode_until   timestamptz,
  slow_mode_source  text,
  alert_id          uuid references cs.manipulation_alerts (id) on delete set null,
  pinned_message_id uuid references public.messages (id) on delete set null,
  pinned_by         uuid,
  pinned_at         timestamptz,
  updated_by        uuid,
  updated_at        timestamptz not null default now(),
  constraint room_moderation_seconds check (slow_mode_seconds between 0 and 3600),
  constraint room_moderation_source check (slow_mode_source in ('manual', 'alert'))
);
alter table private.room_moderation enable row level security;

create or replace function private.busy_window_end(p_at timestamptz)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_local timestamp := p_at at time zone 'Asia/Jakarta';
  v_win   jsonb;
begin
  if private.setting_num('rooms.busy_slow_mode', 10) <= 0 or not cs.is_business_day(v_local::date) then
    return null;
  end if;
  for v_win in select jsonb_array_elements(private.setting_json('rooms.busy_windows', '[]')) loop
    if v_local::time >= (v_win ->> 0)::time and v_local::time < (v_win ->> 1)::time then
      return (v_local::date + (v_win ->> 1)::time) at time zone 'Asia/Jakarta';
    end if;
  end loop;
  return null;
end;
$$;

create or replace function private.room_slow_mode(p_room uuid, p_at timestamptz default now())
returns table (seconds integer, until timestamptz, source text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_mod  private.room_moderation;
  v_busy timestamptz;
  v_secs integer := 0;
begin
  select r.type into v_type from public.chat_rooms r where r.id = p_room;
  if v_type is distinct from 'stock' then
    return query select 0, null::timestamptz, null::text;
    return;
  end if;
  select * into v_mod from private.room_moderation m
  where m.room_id = p_room and m.slow_mode_seconds > 0 and (m.slow_mode_until is null or m.slow_mode_until > p_at);
  v_busy := private.busy_window_end(p_at);
  if v_busy is not null then
    v_secs := private.setting_num('rooms.busy_slow_mode', 10)::integer;
  end if;
  if v_mod.room_id is not null and v_mod.slow_mode_seconds >= v_secs then
    return query select v_mod.slow_mode_seconds, v_mod.slow_mode_until, v_mod.slow_mode_source;
  elsif v_secs > 0 then
    return query select v_secs, v_busy, 'schedule'::text;
  else
    return query select 0, null::timestamptz, null::text;
  end if;
end;
$$;

create or replace function private.slow_mode_wait(p_room uuid, p_user uuid, p_at timestamptz default now())
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select greatest(0, ceil(s.seconds - extract(epoch from (p_at - (
             select max(m.created_at) from public.messages m
             where m.sender_id = p_user and m.room_id = p_room and m.created_at > p_at - make_interval(secs => s.seconds))))))::integer
    from private.room_slow_mode(p_room, p_at) s
    where s.seconds > 0), 0);
$$;

create or replace function private.enforce_slow_mode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wait integer;
begin
  if not private.is_end_user() or new.sender_id is distinct from auth.uid() then
    return new;
  end if;
  if not exists (select 1 from public.chat_rooms r where r.id = new.room_id and r.type = 'stock') then
    return new;
  end if;
  if private.client_id_exists('public.messages'::regclass, 'sender_id', new.sender_id, new.client_id)
     or private.safety_exempt(new.sender_id) then
    return new;
  end if;
  v_wait := private.slow_mode_wait(new.room_id, new.sender_id);
  if v_wait > 0 then
    raise sqlstate 'PGRST' using
      message = json_build_object('code', 'PT429', 'message', 'slow_mode', 'details', v_wait::text, 'hint', null)::text,
      detail = json_build_object('status', 429, 'headers', json_build_object('Retry-After', v_wait::text))::text;
  end if;
  return new;
end;
$$;

create trigger messages_26_slow_mode
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_slow_mode();

create or replace function private.stock_room_id(p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.id from public.chat_rooms r where r.type = 'stock' and r.stock_code = upper(btrim(coalesce(p_code, '')));
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
      'wait_seconds', 0, 'pinned_message', null, 'pinned_at', null);
  end if;
  return jsonb_build_object('stock_code', v_code) || private.stock_room_state(v_room, auth.uid());
end;
$$;

create or replace function private.broadcast_room_state(p_room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(private.stock_room_state(p_room, null), 'room_state', 'room:' || p_room::text, true);
exception when others then
  null;
end;
$$;

create or replace function cs.ensure_stock_room(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_room uuid;
begin
  if v_code !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham tidak valid');
  end if;
  v_room := private.stock_room_id(v_code);
  if v_room is null then
    insert into public.chat_rooms (type, name, stock_code) values ('stock', v_code, v_code)
    on conflict (stock_code) where type = 'stock' do nothing
    returning id into v_room;
    v_room := coalesce(v_room, private.stock_room_id(v_code));
  end if;
  return v_room;
end;
$$;

create or replace function cs.alert_view(a cs.manipulation_alerts)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.id, 'stock', a.stock, 'kind', a.kind, 'score', a.score, 'evidence', a.evidence, 'status', a.status,
    'auto_actions', a.auto_actions, 'detected_at', a.detected_at, 'last_detected_at', a.last_detected_at,
    'reviewed_by', cs.staff_ref(a.reviewed_by), 'reviewed_at', a.reviewed_at, 'review_note', a.review_note);
$$;

create or replace function cs.manipulation_upsert(p_stock text, p_kind text, p_score numeric, p_evidence jsonb,
                                                  p_at timestamptz)
returns cs.manipulation_alerts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alert cs.manipulation_alerts;
begin
  update cs.manipulation_alerts
     set score = greatest(score, p_score), evidence = p_evidence, last_detected_at = p_at
   where stock = p_stock and kind = p_kind and status = 'open'
  returning * into v_alert;
  if v_alert.id is null then
    insert into cs.manipulation_alerts (stock, kind, score, evidence, detected_at, last_detected_at)
    values (p_stock, p_kind, p_score, p_evidence, p_at, p_at)
    on conflict (stock, kind) where status = 'open' do update
      set score = greatest(cs.manipulation_alerts.score, excluded.score), evidence = excluded.evidence,
          last_detected_at = excluded.last_detected_at
    returning * into v_alert;
  end if;
  return v_alert;
end;
$$;

create or replace function cs.manipulation_slow_mode(p_alert cs.manipulation_alerts, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room    uuid := private.stock_room_id(p_alert.stock);
  v_seconds integer := private.setting_num('manipulation.auto_slow_mode_seconds', 30)::integer;
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
    set slow_mode_seconds = greatest(excluded.slow_mode_seconds,
                                     case when private.room_moderation.slow_mode_until > p_at
                                          then private.room_moderation.slow_mode_seconds else 0 end),
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

create or replace function cs.detect_manipulation(p_at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days      numeric := private.setting_num('manipulation.baseline_days', 7);
  v_factor    numeric := private.setting_num('manipulation.spike_factor', 5);
  v_spike_min numeric := private.setting_num('manipulation.spike_min_mentions', 20);
  v_share     numeric := private.setting_num('manipulation.new_account_share', 0.6);
  v_share_min numeric := private.setting_num('manipulation.new_account_min_mentions', 10);
  v_age       numeric := private.setting_num('manipulation.new_account_age_days', 7);
  v_sim       numeric := private.setting_num('manipulation.similarity', 0.8);
  v_authors   numeric := private.setting_num('manipulation.similar_min_authors', 5);
  v_window    numeric := private.setting_num('manipulation.similar_window_minutes', 30);
  v_count     integer := 0;
  v_alert     cs.manipulation_alerts;
  v_held      uuid[];
  r           record;
begin
  for r in
    with cur as (
      select ps.stock_code, count(*) as mentions,
             count(*) filter (where pr.created_at > p_at - v_age * interval '1 day' or pr.trust_level = 0) as new_mentions,
             count(distinct p.author_id) as authors
      from public.post_stocks ps
      join public.posts p on p.id = ps.post_id
      join public.profiles pr on pr.id = p.author_id
      where ps.post_created_at > p_at - interval '1 hour' and ps.post_created_at <= p_at and p.deleted_at is null
      group by ps.stock_code
      having count(*) >= least(v_spike_min, v_share_min)
    ), base as (
      select ps.stock_code, count(*)::numeric / (v_days * 24) as hourly
      from public.post_stocks ps
      join cur on cur.stock_code = ps.stock_code
      where ps.post_created_at > p_at - interval '1 hour' - v_days * interval '1 day'
        and ps.post_created_at <= p_at - interval '1 hour'
      group by ps.stock_code
    )
    select cur.*, coalesce(base.hourly, 0) as hourly from cur left join base using (stock_code)
  loop
    if r.mentions >= v_spike_min and r.mentions > v_factor * r.hourly then
      v_alert := cs.manipulation_upsert(r.stock_code, 'mention_spike',
        round(r.mentions / greatest(r.hourly, 0.1), 2),
        jsonb_build_object('mentions_last_hour', r.mentions, 'hourly_average', round(r.hourly, 2),
                           'authors', r.authors, 'window_end', p_at), p_at);
      perform cs.manipulation_slow_mode(v_alert, p_at);
      v_count := v_count + 1;
    end if;
    if r.mentions >= v_share_min and r.new_mentions::numeric / r.mentions > v_share then
      v_alert := cs.manipulation_upsert(r.stock_code, 'new_account_concentration',
        round(r.new_mentions::numeric / r.mentions, 2),
        jsonb_build_object('mentions_last_hour', r.mentions, 'new_account_mentions', r.new_mentions,
                           'new_account_days', v_age, 'window_end', p_at), p_at);
      perform cs.manipulation_slow_mode(v_alert, p_at);
      v_count := v_count + 1;
    end if;
  end loop;

  for r in
    with recent as (
      select ps.stock_code, p.id, p.author_id, p.body, p.created_at
      from public.post_stocks ps
      join public.posts p on p.id = ps.post_id
      where ps.post_created_at > p_at - v_window * interval '1 minute' and ps.post_created_at <= p_at
        and p.deleted_at is null
    ), ranked as (
      select x.*, row_number() over (partition by x.stock_code order by x.created_at desc) as rn from recent x
    ), pairs as (
      select a.stock_code, a.id, array_agg(distinct b.id) as similar_ids, count(distinct b.author_id) as authors
      from ranked a
      join ranked b on b.stock_code = a.stock_code and b.rn <= 300
                   and (b.id = a.id or extensions.similarity(a.body, b.body) >= v_sim)
      where a.rn <= 300
      group by a.stock_code, a.id
    ), best as (
      select distinct on (p.stock_code) p.stock_code, p.id, p.similar_ids, p.authors
      from pairs p
      where p.authors >= v_authors
      order by p.stock_code, p.authors desc, p.id
    )
    select b.*, (select left(x.body, 280) from public.posts x where x.id = b.id) as sample from best b
  loop
    v_alert := cs.manipulation_upsert(r.stock_code, 'coordinated_posts', r.authors,
      jsonb_build_object('post_ids', to_jsonb(r.similar_ids), 'authors', r.authors, 'sample', r.sample,
                         'window_minutes', v_window, 'window_end', p_at), p_at);
    if private.setting_json('manipulation.auto_hold_similar', 'true') = 'true'::jsonb then
      with held as (
        update public.posts set moderation_status = 'held', moderated_at = now()
         where id = any (r.similar_ids) and moderation_status = 'visible' and deleted_at is null
        returning id
      )
      select coalesce(array_agg(id), '{}') into v_held from held;
      perform private.flag_content('post', h, '{coordinated}', 'manipulation', v_alert.id) from unnest(v_held) h;
      if cardinality(v_held) > 0 then
        update cs.manipulation_alerts
           set auto_actions = auto_actions || jsonb_build_object('held_posts',
                 coalesce(auto_actions -> 'held_posts', '[]'::jsonb) || to_jsonb(v_held))
         where id = v_alert.id;
      end if;
    end if;
    perform cs.manipulation_slow_mode(v_alert, p_at);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

select cron.schedule('safety-manipulation', '*/5 * * * *', 'select cs.detect_manipulation()');

create or replace function cs_api.community_manipulation_alerts(p_status text default 'open', p_stock text default null,
                                                                p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  if coalesce(p_status, '') not in ('open', 'reviewed', 'dismissed') then
    perform private.api_error(400, 'invalid_status', 'Status alert: open, reviewed, atau dismissed');
  end if;
  return coalesce((
    select jsonb_agg(cs.alert_view(a) order by a.last_detected_at desc)
    from (select * from cs.manipulation_alerts a
          where a.status = p_status and (p_stock is null or a.stock = upper(btrim(p_stock)))
          order by a.last_detected_at desc
          limit least(greatest(coalesce(p_limit, 100), 1), 500)) a), '[]');
end;
$$;

create or replace function cs_api.community_manipulation_review(p_id uuid, p_status text, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.moderate}');
  v_note     text := btrim(coalesce(p_note, ''));
  v_alert    cs.manipulation_alerts;
  v_released integer := 0;
  v_room     uuid;
begin
  if p_status is null or p_status not in ('reviewed', 'dismissed') then
    perform private.api_error(400, 'invalid_status', 'Status: reviewed atau dismissed');
  end if;
  if char_length(v_note) not between 5 and 500 then
    perform private.api_error(400, 'note_required', 'Catatan 5–500 karakter');
  end if;
  select * into v_alert from cs.manipulation_alerts where id = p_id for update;
  if not found then
    perform private.api_error(404, 'alert_not_found', 'Alert tidak ditemukan');
  end if;
  if v_alert.status <> 'open' then
    perform private.api_error(409, 'alert_reviewed', 'Alert ini sudah ditinjau');
  end if;
  if p_status = 'dismissed' then
    update public.posts p set moderation_status = 'visible', moderated_at = now()
      from private.content_flags f
     where f.target_type = 'post' and f.target_id = p.id and f.alert_id = v_alert.id
       and f.source = 'manipulation' and p.moderation_status = 'held';
    get diagnostics v_released = row_count;
    update private.room_moderation
       set slow_mode_seconds = 0, slow_mode_until = null, slow_mode_source = null, alert_id = null,
           updated_by = v_me, updated_at = now()
     where alert_id = v_alert.id and slow_mode_source = 'alert'
    returning room_id into v_room;
    if v_room is not null then
      perform private.broadcast_room_state(v_room);
    end if;
  end if;
  update cs.manipulation_alerts
     set status = p_status, reviewed_by = v_me, reviewed_at = now(), review_note = v_note
   where id = p_id
  returning * into v_alert;
  perform cs.audit('community.manipulation_review', null, null,
    jsonb_build_object('alert', p_id, 'stock', v_alert.stock, 'kind', v_alert.kind, 'status', p_status,
                       'note', v_note, 'released_posts', v_released, 'slow_mode_cleared', v_room is not null));
  return cs.alert_view(v_alert) || jsonb_build_object('released_posts', v_released);
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

create or replace function cs_api.community_room_state(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid := private.stock_room_id(p_code);
begin
  if v_room is null then
    perform private.api_error(404, 'room_not_found', 'Room saham belum ada');
  end if;
  return cs.room_admin_view(v_room);
end;
$$;

create or replace function cs_api.community_room_settings(p_code text, p_slow_mode_seconds integer,
                                                          p_until timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid;
  v_old  private.room_moderation;
begin
  if p_slow_mode_seconds is null or p_slow_mode_seconds not between 0 and 3600 then
    perform private.api_error(400, 'invalid_slow_mode', 'Slow mode 0–3600 detik');
  end if;
  if p_until is not null and (p_until <= now() or p_until > now() + interval '30 days') then
    perform private.api_error(400, 'invalid_until', 'Batas waktu harus di masa depan, maksimal 30 hari');
  end if;
  v_room := cs.ensure_stock_room(p_code);
  select * into v_old from private.room_moderation where room_id = v_room for update;
  insert into private.room_moderation (room_id, slow_mode_seconds, slow_mode_until, slow_mode_source, updated_by)
  values (v_room, p_slow_mode_seconds, case when p_slow_mode_seconds > 0 then p_until end,
          case when p_slow_mode_seconds > 0 then 'manual' end, v_me)
  on conflict (room_id) do update
    set slow_mode_seconds = excluded.slow_mode_seconds, slow_mode_until = excluded.slow_mode_until,
        slow_mode_source = excluded.slow_mode_source, alert_id = null, updated_by = v_me, updated_at = now();
  perform cs.audit('community.room_settings', null, null,
    jsonb_build_object('stock', upper(btrim(p_code)), 'slow_mode_seconds', p_slow_mode_seconds, 'until', p_until,
                       'previous', case when v_old.room_id is not null then jsonb_build_object(
                         'seconds', v_old.slow_mode_seconds, 'until', v_old.slow_mode_until,
                         'source', v_old.slow_mode_source) end));
  perform private.broadcast_room_state(v_room);
  return cs.room_admin_view(v_room);
end;
$$;

create or replace function cs_api.community_pin_message(p_room uuid, p_message uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_community('{community.moderate}');
  v_old uuid;
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room and r.type = 'stock') then
    perform private.api_error(404, 'room_not_found', 'Room saham tidak ditemukan');
  end if;
  if p_message is not null and not exists (
       select 1 from public.messages m
       where m.id = p_message and m.room_id = p_room and m.deleted_at is null and m.moderation_status = 'visible') then
    perform private.api_error(400, 'invalid_message', 'Pesan harus pesan yang tampil di room ini');
  end if;
  select pinned_message_id into v_old from private.room_moderation where room_id = p_room for update;
  insert into private.room_moderation (room_id, pinned_message_id, pinned_by, pinned_at, updated_by)
  values (p_room, p_message, case when p_message is not null then v_me end,
          case when p_message is not null then now() end, v_me)
  on conflict (room_id) do update
    set pinned_message_id = excluded.pinned_message_id, pinned_by = excluded.pinned_by,
        pinned_at = excluded.pinned_at, updated_by = v_me, updated_at = now();
  perform cs.audit(case when p_message is null then 'community.room_unpin' else 'community.room_pin' end, null, null,
                   jsonb_build_object('room', p_room, 'message', p_message, 'previous', v_old));
  perform private.broadcast_room_state(p_room);
  return cs.room_admin_view(p_room);
end;
$$;

create or replace function cs.manipulation_settings_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(s.key, s.value order by s.key), '{}')
  from private.settings s
  where s.key like 'manipulation.%' or s.key in ('rooms.busy_slow_mode', 'rooms.busy_windows');
$$;

create or replace function cs_api.compliance_manipulation_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  return cs.manipulation_settings_view();
end;
$$;

create or replace function cs_api.compliance_set_manipulation_settings(p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_key   text;
  v_value jsonb;
  v_min   numeric;
  v_max   numeric;
  v_win   jsonb;
  v_old   jsonb := cs.manipulation_settings_view();
begin
  if jsonb_typeof(p_values) is distinct from 'object' or p_values = '{}'::jsonb then
    perform private.api_error(400, 'invalid_setting', 'Kirim objek pengaturan');
  end if;
  for v_key, v_value in select * from jsonb_each(p_values) loop
    if not (v_old ? v_key) then
      perform private.api_error(400, 'invalid_setting', 'Pengaturan tidak dikenal: ' || v_key);
    end if;
    if v_key in ('manipulation.auto_slow_mode', 'manipulation.auto_hold_similar') then
      if jsonb_typeof(v_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', v_key || ' harus true atau false');
      end if;
    elsif v_key = 'rooms.busy_windows' then
      if jsonb_typeof(v_value) <> 'array' or jsonb_array_length(v_value) > 6 then
        perform private.api_error(400, 'invalid_setting', 'Jam ramai: daftar maksimal 6 rentang');
      end if;
      for v_win in select jsonb_array_elements(v_value) loop
        if jsonb_typeof(v_win) <> 'array' or jsonb_array_length(v_win) <> 2
           or (v_win ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or (v_win ->> 1) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_win ->> 0) >= (v_win ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam ramai harus HH:MM–HH:MM dan jam mulai sebelum jam selesai');
        end if;
      end loop;
    else
      select x.lo, x.hi into v_min, v_max
      from (values ('manipulation.spike_factor', 1.5, 100), ('manipulation.spike_min_mentions', 1, 100000),
                   ('manipulation.baseline_days', 1, 60), ('manipulation.new_account_share', 0.1, 1),
                   ('manipulation.new_account_min_mentions', 1, 100000), ('manipulation.new_account_age_days', 1, 90),
                   ('manipulation.similarity', 0.3, 1), ('manipulation.similar_min_authors', 2, 1000),
                   ('manipulation.similar_window_minutes', 5, 1440), ('manipulation.auto_slow_mode_seconds', 0, 3600),
                   ('manipulation.auto_slow_mode_minutes', 1, 1440), ('rooms.busy_slow_mode', 0, 300)) x(k, lo, hi)
      where x.k = v_key;
      if jsonb_typeof(v_value) <> 'number' or (v_value #>> '{}')::numeric not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_key || ' harus angka ' || v_min || '–' || v_max);
      end if;
    end if;
    update private.settings set value = v_value, updated_at = now() where key = v_key;
  end loop;
  perform cs.audit('manipulation.settings', null, null,
    jsonb_build_object('from', (select jsonb_object_agg(k, v_old -> k) from jsonb_object_keys(p_values) k), 'to', p_values));
  return cs.manipulation_settings_view();
end;
$$;

revoke execute on function private.busy_window_end(timestamptz) from public;
revoke execute on function private.room_slow_mode(uuid, timestamptz) from public;
revoke execute on function private.slow_mode_wait(uuid, uuid, timestamptz) from public;
revoke execute on function private.enforce_slow_mode() from public;
revoke execute on function private.stock_room_id(text) from public;
revoke execute on function private.stock_room_state(uuid, uuid) from public;
revoke execute on function private.broadcast_room_state(uuid) from public;
revoke execute on function public.get_stock_room_state(text) from public, anon;
revoke execute on function cs.ensure_stock_room(text) from public;
revoke execute on function cs.alert_view(cs.manipulation_alerts) from public;
revoke execute on function cs.manipulation_upsert(text, text, numeric, jsonb, timestamptz) from public;
revoke execute on function cs.manipulation_slow_mode(cs.manipulation_alerts, timestamptz) from public;
revoke execute on function cs.detect_manipulation(timestamptz) from public;
revoke execute on function cs.room_admin_view(uuid) from public;
revoke execute on function cs.manipulation_settings_view() from public;
revoke execute on function cs_api.community_manipulation_alerts(text, text, integer) from public;
revoke execute on function cs_api.community_manipulation_review(uuid, text, text) from public;
revoke execute on function cs_api.community_room_state(text) from public;
revoke execute on function cs_api.community_room_settings(text, integer, timestamptz) from public;
revoke execute on function cs_api.community_pin_message(uuid, uuid) from public;
revoke execute on function cs_api.compliance_manipulation_settings() from public;
revoke execute on function cs_api.compliance_set_manipulation_settings(jsonb) from public;

grant execute on function public.get_stock_room_state(text) to authenticated;
grant execute on function cs_api.community_manipulation_alerts(text, text, integer) to authenticated;
grant execute on function cs_api.community_manipulation_review(uuid, text, text) to authenticated;
grant execute on function cs_api.community_room_state(text) to authenticated;
grant execute on function cs_api.community_room_settings(text, integer, timestamptz) to authenticated;
grant execute on function cs_api.community_pin_message(uuid, uuid) to authenticated;
grant execute on function cs_api.compliance_manipulation_settings() to authenticated;
grant execute on function cs_api.compliance_set_manipulation_settings(jsonb) to authenticated;
