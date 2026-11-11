insert into cs.cs_settings (key, value, description)
values ('notifications.watchlist_digest_time', '"17:05"'::jsonb,
        'Jam kirim ringkasan saham pantauan harian (WIB, HH:MM); maksimal sekali per hari')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer', 'ticket.reminder_hours', 'guest.enabled',
                   'notifications.watchlist_digest_time')
      or p_key like 'messages.%';
$$;

CREATE OR REPLACE FUNCTION cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_day   text;
  v_hours jsonb;
  v_lang  text;
  v_min   integer := 1;
  v_max   integer := 240;
  v_error text := 'Batas alert 1–240 menit';
begin
  case
    when p_key = 'assignment.mode' then
      if jsonb_typeof(p_value) <> 'string' or p_value #>> '{}' not in ('claim', 'auto_assign') then
        perform private.api_error(400, 'invalid_setting', 'Mode penugasan harus claim atau auto_assign');
      end if;
    when p_key in ('community.four_eyes', 'guest.enabled') then
      if jsonb_typeof(p_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
      end if;
    when p_key = 'notifications.watchlist_digest_time' then
      if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        perform private.api_error(400, 'invalid_setting', 'Jam harus HH:MM, 00:00–23:59 WIB');
      end if;
    when p_key in ('ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'alerts.unclaimed_minutes',
                   'alerts.p1_unclaimed_minutes') then
      if p_key = 'ticket.auto_release_offline_minutes' then
        v_min := 0;
        v_max := 1440;
        v_error := 'Lepas otomatis 0–1440 menit (0 = mati)';
      elsif p_key = 'ticket.auto_close_days' then
        v_max := 30;
        v_error := 'Tutup otomatis 1–30 hari';
      end if;
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_error);
      end if;
    when p_key = 'ticket.reminder_hours' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 0 and 72 then
        perform private.api_error(400, 'invalid_setting', 'Pengingat 0–72 jam (0 = mati)');
      end if;
    when p_key = 'accounts.max_per_customer' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 1 and 200 then
        perform private.api_error(400, 'invalid_setting', 'Batas rekening per nasabah 1–200');
      end if;
    when p_key = 'service.hours' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{1,2,3,4,5,6,7}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Jam layanan harus berisi hari 1–7');
      end if;
      for v_day, v_hours in select * from jsonb_each(p_value) loop
        if jsonb_typeof(v_hours) = 'null' then
          continue;
        end if;
        if jsonb_typeof(v_hours) <> 'array' or jsonb_array_length(v_hours) <> 2
           or (v_hours ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_hours ->> 1) !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$'
           or (v_hours ->> 0) >= (v_hours ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam layanan hari ' || v_day || ' harus HH:MM–HH:MM dan jam buka sebelum jam tutup');
        end if;
      end loop;
    when p_key like 'messages.%' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{en,id}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Pesan otomatis harus punya teks id dan en');
      end if;
      foreach v_lang in array array['id', 'en'] loop
        if jsonb_typeof(p_value -> v_lang) <> 'string' or char_length(btrim(p_value ->> v_lang)) not between 2 and 500 then
          perform private.api_error(400, 'invalid_setting', 'Teks pesan 2–500 karakter');
        end if;
        if not (cs.placeholders(p_value ->> v_lang) <@ cs.placeholders(p_old ->> v_lang)) then
          perform private.api_error(400, 'invalid_setting',
            'Variabel yang boleh dipakai: ' || coalesce(nullif(array_to_string(cs.placeholders(p_old ->> v_lang), ', '), ''), '-'));
        end if;
      end loop;
    else
      perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end case;
end;
$function$;

create or replace function private.watchlist_digest_time()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select v from (select cs.setting('notifications.watchlist_digest_time') #>> '{}' as v) s
                   where s.v ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'), '17:05');
$$;

create or replace function private.watchlist_digest_cron(p_time text)
returns text
language sql
immutable
set search_path = ''
as $$
  select format('%s %s * * *', split_part(p_time, ':', 2)::integer, (split_part(p_time, ':', 1)::integer + 17) % 24);
$$;

create or replace function private.schedule_watchlist_digest()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cron text := private.watchlist_digest_cron(private.watchlist_digest_time());
begin
  perform cron.schedule('social-watchlist-digest', v_cron, 'select private.watchlist_digest()');
  return v_cron;
end;
$$;

create or replace function private.watchlist_digest_time_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.schedule_watchlist_digest();
  return null;
end;
$$;

create trigger cs_settings_watchlist_digest_time
  after insert or update of value on cs.cs_settings
  for each row when (new.key = 'notifications.watchlist_digest_time')
  execute function private.watchlist_digest_time_changed();

select private.schedule_watchlist_digest();

create or replace function private.notification_prefs_view(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'types', (select jsonb_agg(jsonb_build_object(
                       'type', t.type,
                       'in_app', private.notification_pref_in_app_locked(t.type) or coalesce(np.in_app, true),
                       'push', coalesce(np.push, private.notification_pref_default_push(t.type)),
                       'in_app_locked', private.notification_pref_in_app_locked(t.type)) order by t.ord)
              from unnest(private.notification_pref_types()) with ordinality as t(type, ord)
              left join private.notification_prefs np on np.user_id = p_user and np.type = t.type),
    'quiet_hours', coalesce((select jsonb_build_object('enabled', true,
                                                       'start', to_char(s.quiet_start, 'HH24:MI'),
                                                       'end', to_char(s.quiet_end, 'HH24:MI'),
                                                       'timezone', 'Asia/Jakarta')
                             from private.notification_settings s
                             where s.user_id = p_user and s.quiet_start is not null),
                            jsonb_build_object('enabled', false, 'start', null, 'end', null, 'timezone', 'Asia/Jakarta')),
    'aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
    'watchlist_digest', jsonb_build_object('time', private.watchlist_digest_time(), 'timezone', 'Asia/Jakarta'));
$$;

revoke execute on function private.watchlist_digest_time() from public;
revoke execute on function private.watchlist_digest_cron(text) from public;
revoke execute on function private.schedule_watchlist_digest() from public;
revoke execute on function private.watchlist_digest_time_changed() from public;
