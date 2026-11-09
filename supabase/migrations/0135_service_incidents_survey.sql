create table cs.service_incidents (
  id              uuid primary key default gen_random_uuid(),
  title_id        text not null check (char_length(btrim(title_id)) between 3 and 100),
  title_en        text not null check (char_length(btrim(title_en)) between 3 and 100),
  body_id         text not null check (char_length(btrim(body_id)) between 3 and 1000),
  body_en         text not null check (char_length(btrim(body_en)) between 3 and 1000),
  level           text not null check (level in ('info', 'warning', 'critical')),
  starts_at       timestamptz not null default now(),
  ends_at         timestamptz,
  faq_article_id  uuid references cs.faq_articles (id) on delete set null,
  created_by      uuid,
  updated_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create index service_incidents_window_idx on cs.service_incidents (starts_at, ends_at);

alter table cs.service_incidents enable row level security;
revoke all on cs.service_incidents from public, anon, authenticated;

alter table cs.tickets add column rating_reasons text[] not null default '{}';

insert into cs.cs_settings (key, value, description)
values ('survey.config',
        '{"question": {"id": "Bagaimana layanan CS kami?", "en": "How was our customer service?"},
          "scale": 5, "low_max": 2,
          "reasons": [{"code": "slow", "id": "Terlalu lama", "en": "Too slow"},
                      {"code": "unresolved", "id": "Masalah belum selesai", "en": "Problem not solved"},
                      {"code": "unclear", "id": "Penjelasan kurang jelas", "en": "Unclear answer"},
                      {"code": "attitude", "id": "Sikap kurang ramah", "en": "Unfriendly"}]}'::jsonb,
        'Pertanyaan survei kepuasan, skala (3 atau 5), batas nilai rendah, dan pilihan alasan nilai rendah')
on conflict (key) do nothing;

create or replace function cs.incident_customer_row(i cs.service_incidents, p_language text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', i.id,
    'title', case when p_language = 'en' then i.title_en else i.title_id end,
    'body', case when p_language = 'en' then i.body_en else i.body_id end,
    'level', i.level, 'starts_at', i.starts_at, 'ends_at', i.ends_at,
    'faq_article_id', (select a.id from cs.faq_articles a where a.id = i.faq_article_id and a.status = 'published'));
$$;

create or replace function cs.active_incidents(p_language text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(cs.incident_customer_row(i, p_language)
                            order by case i.level when 'critical' then 0 when 'warning' then 1 else 2 end, i.starts_at desc), '[]')
  from cs.service_incidents i
  where i.starts_at <= now() and (i.ends_at is null or i.ends_at > now());
$$;

create or replace function cs.survey_view(p_language text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'question', case when p_language = 'en' then c -> 'question' ->> 'en' else c -> 'question' ->> 'id' end,
    'scale', (c ->> 'scale')::integer,
    'low_max', (c ->> 'low_max')::integer,
    'reasons', coalesce((select jsonb_agg(jsonb_build_object('code', r ->> 'code',
                                  'label', case when p_language = 'en' then r ->> 'en' else r ->> 'id' end))
                         from jsonb_array_elements(c -> 'reasons') r), '[]'))
  from (select coalesce(cs.setting('survey.config'), '{}'::jsonb) as c) x;
$$;

create or replace function cs_api.service_status(p_language text default 'id')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
begin
  return jsonb_build_object('incidents', cs.active_incidents(p_language));
end;
$$;

create or replace function cs_api.support_home()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_customer();
  v_room uuid;
  v_lang text;
  t      cs.tickets;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = v_me;
  select * into t from cs.tickets x
  where x.customer_id = v_me
  order by (x.status in ('open', 'claimed', 'waiting_customer')) desc, x.created_at desc
  limit 1;
  v_lang := coalesce(t.language, 'id');
  return jsonb_build_object(
    'room_id', v_room,
    'support_name', cs.support_name(),
    'ticket', case when t.id is not null then cs.ticket_customer_view(t) end,
    'active', t.id is not null and t.status in ('open', 'claimed', 'waiting_customer'),
    'unread_count', coalesce((
      select count(*)::integer from (
        select 1 from public.messages m
        join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = v_me
        where m.room_id = v_room and m.sender_id is distinct from v_me and m.created_at > cm.last_read_at
          and m.deleted_at is null
        limit 99) x), 0),
    'service_open', cs.is_open(now()),
    'next_open_at', case when not cs.is_open(now()) then cs.next_open_at(now()) end,
    'topic_picker', coalesce(cs.setting('topics.picker'), '{}'::jsonb),
    'incidents', cs.active_incidents(v_lang),
    'survey', jsonb_build_object('id', cs.survey_view('id'), 'en', cs.survey_view('en')));
end;
$$;

drop function cs_api.rate_ticket(uuid, integer, text);

create function cs_api.rate_ticket(p_ticket_id uuid, p_rating integer, p_comment text default null,
                                   p_reasons text[] default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_customer();
  v_config  jsonb := coalesce(cs.setting('survey.config'), '{}'::jsonb);
  v_reasons text[] := array(select distinct r from unnest(coalesce(p_reasons, '{}')) r order by r);
  t         cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id and customer_id = v_me for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not (t.status in ('resolved', 'closed') and t.first_claimed_at is not null and t.rating is null) then
    perform private.api_error(409, 'cannot_rate', 'Tiket ini tidak bisa diberi nilai');
  end if;
  if p_rating is null or p_rating not between 1 and 5
     or ((v_config ->> 'scale')::integer = 3 and p_rating not in (1, 3, 5)) then
    perform private.api_error(400, 'invalid_rating', 'Nilai tidak sesuai skala survei');
  end if;
  if char_length(coalesce(p_comment, '')) > 500 then
    perform private.api_error(400, 'comment_too_long', 'Komentar maksimal 500 karakter');
  end if;
  if cardinality(v_reasons) > 0 and (p_rating > coalesce((v_config ->> 'low_max')::integer, 2)
       or exists (select 1 from unnest(v_reasons) r
                  where not exists (select 1 from jsonb_array_elements(v_config -> 'reasons') c where c ->> 'code' = r))) then
    perform private.api_error(400, 'invalid_reasons', 'Alasan tidak sesuai survei');
  end if;
  update cs.tickets
     set rating = p_rating,
         rating_comment = nullif(btrim((cs.mask_sensitive(coalesce(p_comment, ''))).masked), ''),
         rating_reasons = v_reasons,
         rated_at = now(), updated_at = now()
   where id = t.id
  returning * into t;
  perform cs.log_event(t.id, 'rated', jsonb_build_object('rating', p_rating, 'reasons', to_jsonb(v_reasons)));
  if t.status = 'resolved' then
    t := cs.finalize_ticket(t.id, 'rated');
  else
    perform cs.broadcast_ticket(t, 'ticket_updated', array[t.last_owner_id]);
  end if;
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs.incident_admin_row(i cs.service_incidents)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(i) || jsonb_build_object(
    'active', i.starts_at <= now() and (i.ends_at is null or i.ends_at > now()),
    'tickets', (select count(*) from cs.tickets t
                where t.created_at >= i.starts_at and t.created_at <= coalesce(i.ends_at, now())),
    'updated_by_name', cs.agent_name(i.updated_by));
$$;

create or replace function cs_api.admin_incidents()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((select jsonb_agg(cs.incident_admin_row(i) order by i.starts_at desc)
                   from (select * from cs.service_incidents x order by x.starts_at desc limit 100) i), '[]');
end;
$$;

create or replace function cs_api.admin_save_incident(
  p_id uuid, p_title_id text, p_title_en text, p_body_id text, p_body_en text, p_level text,
  p_starts_at timestamptz default null, p_ends_at timestamptz default null, p_faq_article_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old cs.service_incidents;
  i     cs.service_incidents;
begin
  if char_length(btrim(coalesce(p_title_id, ''))) not between 3 and 100
     or char_length(btrim(coalesce(p_title_en, ''))) not between 3 and 100 then
    perform private.api_error(400, 'invalid_incident', 'Judul 3–100 karakter dalam dua bahasa');
  end if;
  if char_length(btrim(coalesce(p_body_id, ''))) not between 3 and 1000
     or char_length(btrim(coalesce(p_body_en, ''))) not between 3 and 1000 then
    perform private.api_error(400, 'invalid_incident', 'Isi 3–1.000 karakter dalam dua bahasa');
  end if;
  if p_level is null or p_level not in ('info', 'warning', 'critical') then
    perform private.api_error(400, 'invalid_incident', 'Tingkat harus info, warning, atau critical');
  end if;
  if p_ends_at is not null and p_ends_at <= coalesce(p_starts_at, now()) then
    perform private.api_error(400, 'invalid_incident', 'Waktu selesai harus setelah waktu mulai');
  end if;
  if p_faq_article_id is not null
     and not exists (select 1 from cs.faq_articles a where a.id = p_faq_article_id and a.status = 'published') then
    perform private.api_error(400, 'invalid_incident', 'Artikel FAQ harus sudah terbit');
  end if;
  if p_id is null then
    insert into cs.service_incidents (title_id, title_en, body_id, body_en, level, starts_at, ends_at, faq_article_id,
                                      created_by, updated_by)
    values (btrim(p_title_id), btrim(p_title_en), btrim(p_body_id), btrim(p_body_en), p_level,
            coalesce(p_starts_at, now()), p_ends_at, p_faq_article_id, v_me, v_me)
    returning * into i;
  else
    select * into v_old from cs.service_incidents x where x.id = p_id for update;
    if v_old.id is null then
      perform private.api_error(404, 'incident_not_found', 'Pengumuman tidak ditemukan');
    end if;
    update cs.service_incidents
       set title_id = btrim(p_title_id), title_en = btrim(p_title_en), body_id = btrim(p_body_id),
           body_en = btrim(p_body_en), level = p_level, starts_at = coalesce(p_starts_at, starts_at),
           ends_at = p_ends_at, faq_article_id = p_faq_article_id, updated_by = v_me, updated_at = now()
     where id = p_id
    returning * into i;
  end if;
  perform cs.audit('incident.save', null, null, jsonb_build_object('id', i.id,
    'before', case when v_old.id is not null then to_jsonb(v_old) end, 'after', to_jsonb(i)));
  return cs.incident_admin_row(i);
end;
$$;

create or replace function cs_api.admin_end_incident(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
  i    cs.service_incidents;
begin
  update cs.service_incidents
     set ends_at = greatest(now(), starts_at + interval '1 second'), updated_by = v_me, updated_at = now()
   where id = p_id and (ends_at is null or ends_at > now())
  returning * into i;
  if i.id is null then
    perform private.api_error(404, 'incident_not_found', 'Pengumuman aktif tidak ditemukan');
  end if;
  perform cs.audit('incident.end', null, null, jsonb_build_object('id', i.id));
  return cs.incident_admin_row(i);
end;
$$;

create or replace function cs_api.admin_survey_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return jsonb_build_object('config', coalesce(cs.setting('survey.config'), '{}'::jsonb),
    'updated_at', (select s.updated_at from cs.cs_settings s where s.key = 'survey.config'),
    'updated_by', (select cs.agent_name(s.updated_by) from cs.cs_settings s where s.key = 'survey.config'));
end;
$$;

create or replace function cs_api.admin_set_survey_config(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin}');
  v_old     jsonb := cs.setting('survey.config');
  v_scale   integer;
  v_low     integer;
  v_reasons jsonb := '[]';
  v_reason  jsonb;
  v_codes   text[] := '{}';
  v_value   jsonb;
begin
  if jsonb_typeof(p_config) is distinct from 'object'
     or char_length(btrim(coalesce(p_config -> 'question' ->> 'id', ''))) not between 5 and 120
     or char_length(btrim(coalesce(p_config -> 'question' ->> 'en', ''))) not between 5 and 120 then
    perform private.api_error(400, 'invalid_survey', 'Pertanyaan 5–120 karakter dalam dua bahasa');
  end if;
  v_scale := (p_config ->> 'scale')::integer;
  v_low := (p_config ->> 'low_max')::integer;
  if v_scale is null or v_scale not in (3, 5) then
    perform private.api_error(400, 'invalid_survey', 'Skala harus 3 atau 5');
  end if;
  if v_low is null or v_low not between 1 and 4 then
    perform private.api_error(400, 'invalid_survey', 'Batas nilai rendah 1–4');
  end if;
  if jsonb_typeof(p_config -> 'reasons') is distinct from 'array' or jsonb_array_length(p_config -> 'reasons') > 8 then
    perform private.api_error(400, 'invalid_survey', 'Maksimal 8 alasan');
  end if;
  for v_reason in select value from jsonb_array_elements(p_config -> 'reasons') loop
    if coalesce(v_reason ->> 'code', '') !~ '^[a-z][a-z0-9_]{1,31}$' or (v_reason ->> 'code') = any (v_codes)
       or char_length(btrim(coalesce(v_reason ->> 'id', ''))) not between 2 and 60
       or char_length(btrim(coalesce(v_reason ->> 'en', ''))) not between 2 and 60 then
      perform private.api_error(400, 'invalid_survey', 'Alasan butuh kode unik dan label 2–60 karakter');
    end if;
    v_codes := v_codes || (v_reason ->> 'code');
    v_reasons := v_reasons || jsonb_build_array(jsonb_build_object('code', v_reason ->> 'code',
      'id', btrim(v_reason ->> 'id'), 'en', btrim(v_reason ->> 'en')));
  end loop;
  v_value := jsonb_build_object('question', jsonb_build_object('id', btrim(p_config -> 'question' ->> 'id'),
                                                               'en', btrim(p_config -> 'question' ->> 'en')),
                                'scale', v_scale, 'low_max', v_low, 'reasons', v_reasons);
  perform cs.set_setting('survey.config', v_value, v_me);
  perform cs.audit('survey.config', null, null, jsonb_build_object('before', v_old, 'after', v_value));
  return cs_api.admin_survey_config();
end;
$$;

create or replace function cs_api.admin_rating_reasons(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_from timestamptz := coalesce(p_from, current_date - 30)::timestamptz;
  v_to   timestamptz := (coalesce(p_to, current_date) + 1)::timestamptz;
begin
  if v_to - v_from > interval '366 days' then
    perform private.api_error(400, 'invalid_range', 'Rentang maksimal 1 tahun');
  end if;
  return jsonb_build_object(
    'by_topic', coalesce((
      select jsonb_agg(jsonb_build_object('topic', x.topic, 'reason', x.reason, 'count', x.n) order by x.n desc, x.topic)
      from (select t.topic, r as reason, count(*) as n
            from cs.tickets t, unnest(t.rating_reasons) r
            where t.rated_at >= v_from and t.rated_at < v_to
            group by t.topic, r) x), '[]'),
    'by_agent', coalesce((
      select jsonb_agg(jsonb_build_object('agent_id', x.agent, 'agent_name', cs.agent_name(x.agent), 'reason', x.reason,
                                          'count', x.n) order by x.n desc)
      from (select t.last_owner_id as agent, r as reason, count(*) as n
            from cs.tickets t, unnest(t.rating_reasons) r
            where t.rated_at >= v_from and t.rated_at < v_to and t.last_owner_id is not null
            group by t.last_owner_id, r) x), '[]'));
end;
$$;

revoke execute on function cs.incident_customer_row(cs.service_incidents, text) from public;
revoke execute on function cs.active_incidents(text) from public;
revoke execute on function cs.survey_view(text) from public;
revoke execute on function cs.incident_admin_row(cs.service_incidents) from public;
revoke execute on function cs_api.service_status(text) from public;
revoke execute on function cs_api.rate_ticket(uuid, integer, text, text[]) from public;
revoke execute on function cs_api.admin_incidents() from public;
revoke execute on function cs_api.admin_save_incident(uuid, text, text, text, text, text, timestamptz, timestamptz, uuid) from public;
revoke execute on function cs_api.admin_end_incident(uuid) from public;
revoke execute on function cs_api.admin_survey_config() from public;
revoke execute on function cs_api.admin_set_survey_config(jsonb) from public;
revoke execute on function cs_api.admin_rating_reasons(date, date) from public;
grant execute on function cs_api.service_status(text) to authenticated;
grant execute on function cs_api.rate_ticket(uuid, integer, text, text[]) to authenticated;
grant execute on function cs_api.admin_incidents() to authenticated;
grant execute on function cs_api.admin_save_incident(uuid, text, text, text, text, text, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function cs_api.admin_end_incident(uuid) to authenticated;
grant execute on function cs_api.admin_survey_config() to authenticated;
grant execute on function cs_api.admin_set_survey_config(jsonb) to authenticated;
grant execute on function cs_api.admin_rating_reasons(date, date) to authenticated;
