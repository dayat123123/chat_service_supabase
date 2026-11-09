alter table cs.tickets add column reminded_at timestamptz;

create table cs.faq_flags (
  id          bigint generated always as identity primary key,
  article_id  uuid not null references cs.faq_articles (id) on delete cascade,
  agent_id    uuid not null,
  note        text not null check (char_length(note) between 5 and 300),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);

create index faq_flags_open_idx on cs.faq_flags (article_id) where resolved_at is null;

alter table cs.faq_flags enable row level security;
revoke all on cs.faq_flags from public, anon, authenticated;

insert into cs.cs_settings (key, value, description) values
  ('ticket.reminder_hours', '24',
   'Kirim pengingat ke nasabah bila tiket menunggu balasan nasabah lebih dari N jam (0 = mati), sebelum tutup otomatis'),
  ('messages.waiting_reminder',
   '{"id": "Apakah masih ada yang bisa kami bantu? Balas pesan ini agar tiket #{ticket} tetap dilanjutkan.",
     "en": "Is there anything else we can help with? Reply to this message to continue ticket #{ticket}."}',
   'Pesan pengingat saat tiket menunggu balasan nasabah')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer', 'ticket.reminder_hours')
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

create or replace function cs.remind_waiting_customers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hours integer := coalesce(cs.setting_int('ticket.reminder_hours'), 0);
  v_count integer := 0;
  t       cs.tickets;
begin
  if v_hours <= 0 then
    return 0;
  end if;
  for t in
    select * from cs.tickets x
    where x.status = 'waiting_customer'
      and x.last_agent_message_at is not null
      and x.last_agent_message_at < now() - make_interval(hours => v_hours)
      and (x.last_customer_message_at is null or x.last_customer_message_at < x.last_agent_message_at)
      and (x.reminded_at is null or x.reminded_at < x.last_agent_message_at)
    order by x.last_agent_message_at
    limit 100
    for update skip locked
  loop
    update cs.tickets set reminded_at = now() where id = t.id;
    perform cs.system_message(t, 'waiting_reminder');
    perform cs.log_event(t.id, 'customer_reminded', jsonb_build_object('hours', v_hours));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

select cron.schedule('cs-waiting-reminder', '*/5 * * * *', 'select cs.remind_waiting_customers()');

create or replace function cs_api.agent_faq_search(p_query text, p_language text default 'id')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_agent,cs_super_admin}');
  v_lang  text := case when p_language = 'en' then 'en' else 'id' end;
  v_words text[];
begin
  select array_agg(replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_'))
    into v_words
    from (select w from unnest(regexp_split_to_array(lower(btrim(coalesce(p_query, ''))), '[[:space:]]+')) w
          where char_length(w) >= 2 limit 6) x;
  return coalesce((
    select jsonb_agg(cs.faq_customer_row(a, v_lang) || jsonb_build_object(
             'open_flags', (select count(*) from cs.faq_flags f where f.article_id = a.id and f.resolved_at is null))
           order by a.sort_order, a.created_at)
    from (select x.* from cs.faq_articles x
          join cs.faq_categories c on c.id = x.category_id and c.active
          where x.status = 'published'
            and (v_words is null or not exists (
              select 1 from unnest(v_words) w
              where lower(case when v_lang = 'en' then x.question_en || ' ' || x.answer_en
                               else x.question_id || ' ' || x.answer_id end
                          || ' ' || array_to_string(x.keywords, ' ')) not like '%' || w || '%'))
          order by x.sort_order, x.created_at
          limit 20) a), '[]');
end;
$$;

create or replace function cs_api.agent_flag_faq(p_article_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent,cs_super_admin}');
  v_note text := btrim(coalesce(p_note, ''));
  v_id   bigint;
begin
  if char_length(v_note) not between 5 and 300 then
    perform private.api_error(400, 'reason_required', 'Catatan 5–300 karakter');
  end if;
  if not exists (select 1 from cs.faq_articles a where a.id = p_article_id and a.status <> 'archived') then
    perform private.api_error(404, 'article_not_found', 'Artikel tidak ditemukan');
  end if;
  insert into cs.faq_flags (article_id, agent_id, note) values (p_article_id, v_me, v_note) returning id into v_id;
  perform cs.audit('faq.flag', null, null, jsonb_build_object('article_id', p_article_id, 'flag_id', v_id));
  return jsonb_build_object('id', v_id, 'article_id', p_article_id, 'note', v_note);
end;
$$;

create or replace function cs_api.admin_faq_flags(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', f.id, 'note', f.note, 'agent_name', cs.agent_name(f.agent_id),
                                        'created_at', f.created_at, 'resolved_at', f.resolved_at,
                                        'resolved_by_name', cs.agent_name(f.resolved_by))
                     order by f.resolved_at nulls first, f.created_at desc)
    from (select * from cs.faq_flags x where x.article_id = p_id order by x.created_at desc limit 100) f), '[]');
end;
$$;

create or replace function cs_api.admin_faq_resolve_flags(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_count integer;
begin
  update cs.faq_flags set resolved_at = now(), resolved_by = v_me where article_id = p_id and resolved_at is null;
  get diagnostics v_count = row_count;
  if v_count > 0 then
    perform cs.audit('faq.flags_resolved', null, null, jsonb_build_object('article_id', p_id, 'count', v_count));
  end if;
  return cs_api.admin_faq_flags(p_id);
end;
$$;

create or replace function cs.faq_admin_row(a cs.faq_articles)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.faq_content(a) || jsonb_build_object(
    'id', a.id,
    'status', a.status,
    'version', a.version,
    'views', a.views,
    'readers', (select count(*) from cs.faq_reads r where r.article_id = a.id),
    'helpful', (select count(*) from cs.faq_feedback f where f.article_id = a.id and f.helpful),
    'not_helpful', (select count(*) from cs.faq_feedback f where f.article_id = a.id and not f.helpful),
    'tickets_after', (select count(*) from cs.faq_reads r
                      where r.article_id = a.id
                        and exists (select 1 from cs.tickets t
                                    where t.customer_id = r.customer_id
                                      and t.created_at between r.read_at and r.read_at + interval '24 hours')),
    'open_flags', (select count(*) from cs.faq_flags f where f.article_id = a.id and f.resolved_at is null),
    'created_at', a.created_at,
    'updated_at', a.updated_at,
    'updated_by_name', (select g.display_name from cs.agents g where g.user_id = a.updated_by),
    'published_at', a.published_at);
$$;

create or replace function cs_api.admin_help_report(p_from date, p_to date)
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
  if v_to <= v_from or v_to - v_from > interval '366 days' then
    perform private.api_error(400, 'invalid_range', 'Rentang 1 hari sampai 1 tahun');
  end if;
  return jsonb_build_object(
    'from', v_from, 'to', v_to,
    'topics', coalesce((
      select jsonb_agg(jsonb_build_object(
               'topic', x.topic,
               'name', (select tp.name_id from cs.support_topics tp where tp.code = x.topic),
               'tickets', x.n,
               'median_first_response_minutes', x.response,
               'median_resolution_minutes', x.resolution) order by x.n desc, x.topic)
      from (select t.topic, count(*) as n,
                   round((percentile_cont(0.5) within group (
                     order by extract(epoch from t.first_response_at - t.queued_at) / 60))::numeric, 1) as response,
                   round((percentile_cont(0.5) within group (
                     order by extract(epoch from t.resolved_at - t.created_at) / 60))::numeric, 1) as resolution
            from cs.tickets t
            where t.created_at >= v_from and t.created_at < v_to
            group by t.topic) x), '[]'),
    'articles', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', x.id, 'question', x.question_id, 'readers', x.readers, 'helpful', x.helpful,
               'not_helpful', x.not_helpful, 'tickets_after', x.tickets_after,
               'prevented', x.readers - x.tickets_after,
               'helpful_percent', case when x.helpful + x.not_helpful > 0
                                       then round(100.0 * x.helpful / (x.helpful + x.not_helpful)) end)
             order by x.helpful desc, x.readers desc)
      from (select a.id, a.question_id,
                   (select count(*) from cs.faq_reads r where r.article_id = a.id
                      and r.read_at >= v_from and r.read_at < v_to) as readers,
                   (select count(*) from cs.faq_feedback f where f.article_id = a.id and f.helpful
                      and f.updated_at >= v_from and f.updated_at < v_to) as helpful,
                   (select count(*) from cs.faq_feedback f where f.article_id = a.id and not f.helpful
                      and f.updated_at >= v_from and f.updated_at < v_to) as not_helpful,
                   (select count(*) from cs.faq_reads r
                    where r.article_id = a.id and r.read_at >= v_from and r.read_at < v_to
                      and exists (select 1 from cs.tickets t where t.customer_id = r.customer_id
                                    and t.created_at between r.read_at and r.read_at + interval '24 hours')) as tickets_after
            from cs.faq_articles a where a.status <> 'archived') x
      where x.readers > 0 or x.helpful + x.not_helpful > 0), '[]'),
    'misses', coalesce((
      select jsonb_agg(jsonb_build_object('query', m.query, 'language', m.language, 'count', m.n) order by m.n desc)
      from (select s.query, s.language, count(*) as n from cs.faq_search_misses s
            where s.created_at >= v_from and s.created_at < v_to
            group by s.query, s.language order by count(*) desc limit 50) m), '[]'));
end;
$$;

create or replace function cs_api.ticket_transcript(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  select * into t from cs.tickets x where x.id = p_ticket_id and x.customer_id = v_me;
  if t.id is null then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if t.status not in ('resolved', 'closed') then
    perform private.api_error(409, 'ticket_active', 'Transkrip tersedia setelah tiket selesai');
  end if;
  return jsonb_build_object(
    'ticket', cs.ticket_customer_view(t),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
               'created_at', m.created_at,
               'sender', case when m.sender_id = v_me then 'customer'
                              when m.sender_id is null then 'system' else 'agent' end,
               'sender_name', case when m.sender_id is not null and m.sender_id <> v_me
                                   then (select a.display_name from cs.agents a where a.user_id = m.sender_id) end,
               'body', case when m.deleted_at is not null then null
                            else coalesce(m.payload -> 'texts' ->> t.language, m.body) end,
               'deleted', m.deleted_at is not null,
               'attachments', (select coalesce(jsonb_agg(coalesce(x ->> 'name', regexp_replace(x ->> 'path', '^.*/', ''))), '[]')
                               from jsonb_array_elements(coalesce(m.attachments, '[]')) x))
             order by m.created_at, m.id)
      from public.messages m
      where m.room_id = t.room_id and m.session_id = t.id), '[]'));
end;
$$;

revoke execute on function cs.remind_waiting_customers() from public;
revoke execute on function cs_api.agent_faq_search(text, text) from public;
revoke execute on function cs_api.agent_flag_faq(uuid, text) from public;
revoke execute on function cs_api.admin_faq_flags(uuid) from public;
revoke execute on function cs_api.admin_faq_resolve_flags(uuid) from public;
revoke execute on function cs_api.admin_help_report(date, date) from public;
revoke execute on function cs_api.ticket_transcript(uuid) from public;
grant execute on function cs_api.agent_faq_search(text, text) to authenticated;
grant execute on function cs_api.agent_flag_faq(uuid, text) to authenticated;
grant execute on function cs_api.admin_faq_flags(uuid) to authenticated;
grant execute on function cs_api.admin_faq_resolve_flags(uuid) to authenticated;
grant execute on function cs_api.admin_help_report(date, date) to authenticated;
grant execute on function cs_api.ticket_transcript(uuid) to authenticated;
