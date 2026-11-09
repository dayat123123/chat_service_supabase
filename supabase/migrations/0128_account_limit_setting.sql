insert into cs.cs_settings (key, value, description)
values ('accounts.max_per_customer', '200'::jsonb,
        'Batas rekening per nasabah dari klaim accounts token sosial (1–200); kelebihan diabaikan')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer')
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
    when p_key = 'community.four_eyes' then
      if jsonb_typeof(p_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
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

create or replace function public.set_olt_account_links(p_profile_id uuid, p_accounts jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids     text[];
  v_total   integer;
  v_limit   integer := least(greatest(coalesce(cs.setting_int('accounts.max_per_customer'), 200), 1), 200);
begin
  if jsonb_typeof(p_accounts) is distinct from 'array' then
    perform private.api_error(400, 'invalid_accounts', 'accounts harus berupa array');
  end if;
  v_total := jsonb_array_length(p_accounts);
  if v_total > 1000 then
    perform private.api_error(400, 'invalid_accounts', 'accounts terlalu banyak');
  end if;
  if p_profile_id is null
     or not exists (select 1 from public.profiles p where p.id = p_profile_id and p.deleted_at is null) then
    perform private.api_error(404, 'profile_not_found', 'Profil tidak ditemukan');
  end if;

  select coalesce(array_agg(v.cust_id order by v.ord), '{}') into v_ids
  from (select x.cust_id, min(x.ord) as ord
        from (select private.integration_cust_id(e.value) as cust_id, e.ord
              from jsonb_array_elements(p_accounts) with ordinality as e(value, ord)) x
        where x.cust_id is not null
        group by x.cust_id
        order by min(x.ord)
        limit v_limit) v;

  delete from private.account_links l
   where l.profile_id = p_profile_id and l.cust_id <> all (v_ids);
  insert into private.account_links (cust_id, profile_id)
  select c, p_profile_id from unnest(v_ids) as c
  on conflict (cust_id, profile_id) do update set seen_at = now();

  return jsonb_build_object('linked', cardinality(v_ids), 'ignored', v_total - cardinality(v_ids));
end;
$$;
