alter table cs.support_topics
  add column description_id text check (description_id is null or char_length(description_id) between 1 and 120),
  add column description_en text check (description_en is null or char_length(description_en) between 1 and 120),
  add column icon text check (icon is null or icon in ('account', 'wallet', 'receipt', 'chart', 'tools', 'shield', 'help',
                                                      'document', 'phone', 'card', 'chat', 'star', 'bell', 'lock',
                                                      'globe', 'gift')),
  add column style text not null default 'normal' check (style in ('normal', 'danger'));

update cs.support_topics t
   set icon = v.icon, description_id = v.description_id, description_en = v.description_en
  from (values
    ('account', 'account', 'Login, password, PIN, dan data akun', 'Login, password, PIN, and account data'),
    ('funds', 'wallet', 'Setor, tarik dana, dan saldo RDN', 'Deposits, withdrawals, and RDN balance'),
    ('orders', 'receipt', 'Status order, transaksi match, dan penolakan', 'Order status, matched trades, and rejections'),
    ('portfolio', 'chart', 'Kepemilikan, rights, waran, dan dividen', 'Holdings, rights, warrants, and dividends'),
    ('technical', 'tools', 'Error, aplikasi lambat, atau masalah koneksi', 'Errors, slow app, or connection issues'),
    ('fraud', 'shield', 'Aktivitas mencurigakan atau orang yang mengaku CS',
     'Suspicious activity or someone posing as customer service'),
    ('other', 'help', 'Hal lain yang perlu dibantu', 'Anything else you need help with')
  ) as v(code, icon, description_id, description_en)
 where t.code = v.code;

update cs.support_topics set style = 'danger' where 'fraud' = any (flags);

insert into cs.cs_settings (key, value, description)
values ('topics.picker', '{}'::jsonb,
        'Judul dan petunjuk halaman pilih topik chat CS (ID/EN); kosong = teks bawaan aplikasi')
on conflict (key) do nothing;

create or replace function cs.topic_admin_row(t cs.support_topics)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'code', t.code, 'name_id', t.name_id, 'name_en', t.name_en, 'skill', t.skill,
    'default_priority', t.default_priority, 'help_url', t.help_url, 'sort_order', t.sort_order,
    'active', t.active, 'description_id', t.description_id, 'description_en', t.description_en,
    'icon', t.icon, 'style', t.style, 'flags', to_jsonb(t.flags));
$$;

create or replace function cs_api.topics(p_language text default 'id')
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', t.code,
           'name', case when p_language = 'en' then t.name_en else t.name_id end,
           'description', case when p_language = 'en' then t.description_en else t.description_id end,
           'icon', t.icon,
           'style', t.style,
           'help_url', t.help_url,
           'urgent', t.default_priority = 'P1')
         order by t.sort_order, t.code), '[]')
  from cs.support_topics t
  where t.active;
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
  t      cs.tickets;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = v_me;
  select * into t from cs.tickets x
  where x.customer_id = v_me
  order by (x.status in ('open', 'claimed', 'waiting_customer')) desc, x.created_at desc
  limit 1;
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
    'topic_picker', coalesce(cs.setting('topics.picker'), '{}'::jsonb));
end;
$$;

create or replace function cs_api.admin_topics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((select jsonb_agg(cs.topic_admin_row(t) order by t.sort_order, t.code) from cs.support_topics t), '[]');
end;
$$;

drop function cs_api.admin_save_topic(text, text, text, text, text, text, integer, boolean);

create function cs_api.admin_save_topic(
  p_code             text,
  p_name_id          text,
  p_name_en          text,
  p_skill            text,
  p_default_priority text,
  p_help_url         text,
  p_sort_order       integer,
  p_active           boolean,
  p_description_id   text default null,
  p_description_en   text default null,
  p_icon             text default null,
  p_style            text default 'normal',
  p_flags            text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_url    text := nullif(btrim(coalesce(p_help_url, '')), '');
  v_desc_id text := nullif(btrim(coalesce(p_description_id, '')), '');
  v_desc_en text := nullif(btrim(coalesce(p_description_en, '')), '');
  v_old    cs.support_topics;
  v_new    cs.support_topics;
  v_flags  text[];
begin
  if coalesce(p_code, '') !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_code', 'Kode topik 2–32 huruf kecil, angka, atau garis bawah');
  end if;
  if char_length(btrim(coalesce(p_name_id, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_name_en, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama topik (ID dan EN) 2–40 karakter');
  end if;
  if char_length(coalesce(v_desc_id, '')) > 120 or char_length(coalesce(v_desc_en, '')) > 120 then
    perform private.api_error(400, 'invalid_description', 'Deskripsi topik maksimal 120 karakter');
  end if;
  if p_icon is not null and p_icon not in ('account', 'wallet', 'receipt', 'chart', 'tools', 'shield', 'help', 'document',
                                           'phone', 'card', 'chat', 'star', 'bell', 'lock', 'globe', 'gift') then
    perform private.api_error(400, 'invalid_icon', 'Ikon topik tidak dikenal');
  end if;
  if coalesce(p_style, 'normal') not in ('normal', 'danger') then
    perform private.api_error(400, 'invalid_style', 'Gaya topik harus normal atau danger');
  end if;
  if not exists (select 1 from cs.skills s where s.code = p_skill) then
    perform private.api_error(400, 'invalid_skill', 'Skill tidak dikenal');
  end if;
  if coalesce(p_default_priority, '') not in ('P1', 'P2', 'P3', 'P4') then
    perform private.api_error(400, 'invalid_priority', 'Prioritas harus P1–P4');
  end if;
  if coalesce(p_sort_order, -1) not between 0 and 999 then
    perform private.api_error(400, 'invalid_sort', 'Urutan 0–999');
  end if;
  if v_url is not null and (v_url !~ '^https://[A-Za-z0-9.-]+(/\S*)?$'
     or not (cs.setting('help.allowed_hosts') ? lower(substring(v_url from '^https://([A-Za-z0-9.-]+)')))) then
    perform private.api_error(400, 'invalid_help_link', 'Tautan bantuan harus https ke situs bantuan resmi');
  end if;
  if not coalesce(p_active, true) and p_code = cs.setting('ticket.default_topic') #>> '{}' then
    perform private.api_error(400, 'default_topic', 'Topik bawaan tidak bisa dinonaktifkan');
  end if;

  select * into v_old from cs.support_topics where code = p_code for update;
  v_flags := case when p_flags is null then coalesce(v_old.flags, '{}')
                  else array(select distinct f from unnest(p_flags) f order by f) end;
  if p_flags is not null and not (v_flags <@ '{complaint,fraud}'::text[]) then
    perform private.api_error(400, 'invalid_flags', 'Tanda topik hanya pengaduan atau penipuan');
  end if;
  if v_flags is distinct from coalesce(v_old.flags, '{}') and not cs.has_role('{cs_super_admin}') then
    perform private.api_error(403, 'flags_forbidden', 'Hanya Super Admin yang bisa mengubah tanda pengaduan/penipuan');
  end if;

  insert into cs.support_topics (code, name_id, name_en, skill, default_priority, help_url, sort_order, active,
                                 description_id, description_en, icon, style, flags)
  values (p_code, btrim(p_name_id), btrim(p_name_en), p_skill, p_default_priority, v_url, p_sort_order,
          coalesce(p_active, true), v_desc_id, v_desc_en, p_icon, coalesce(p_style, 'normal'), v_flags)
  on conflict (code) do update
    set name_id = excluded.name_id, name_en = excluded.name_en, skill = excluded.skill,
        default_priority = excluded.default_priority, help_url = excluded.help_url,
        sort_order = excluded.sort_order, active = excluded.active,
        description_id = excluded.description_id, description_en = excluded.description_en,
        icon = excluded.icon, style = excluded.style, flags = excluded.flags
  returning * into v_new;

  perform cs.audit('topic.save', null, null, jsonb_build_object(
    'code', p_code, 'active', v_new.active,
    'before', case when v_old.code is not null then cs.topic_admin_row(v_old) end,
    'after', cs.topic_admin_row(v_new)));
  if v_new.flags is distinct from coalesce(v_old.flags, '{}') then
    perform cs.audit('topic.flags', null, null, jsonb_build_object(
      'code', p_code, 'before', to_jsonb(coalesce(v_old.flags, '{}')), 'after', to_jsonb(v_new.flags)));
  end if;
  return cs_api.admin_topics();
end;
$$;

create or replace function cs_api.admin_topic_picker()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce(cs.setting('topics.picker'), '{}'::jsonb);
end;
$$;

create or replace function cs_api.admin_set_topic_picker(p_title_id text, p_title_en text, p_hint_id text, p_hint_en text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_title jsonb := jsonb_strip_nulls(jsonb_build_object('id', nullif(btrim(coalesce(p_title_id, '')), ''),
                                                        'en', nullif(btrim(coalesce(p_title_en, '')), '')));
  v_hint  jsonb := jsonb_strip_nulls(jsonb_build_object('id', nullif(btrim(coalesce(p_hint_id, '')), ''),
                                                        'en', nullif(btrim(coalesce(p_hint_en, '')), '')));
  v_value jsonb;
  v_old   jsonb := coalesce(cs.setting('topics.picker'), '{}'::jsonb);
begin
  if exists (select 1 from jsonb_each_text(v_title) e where char_length(e.value) > 80)
     or exists (select 1 from jsonb_each_text(v_hint) e where char_length(e.value) > 160) then
    perform private.api_error(400, 'invalid_picker_text', 'Judul maksimal 80 karakter, petunjuk maksimal 160 karakter');
  end if;
  v_value := jsonb_strip_nulls(jsonb_build_object(
    'title', case when v_title = '{}'::jsonb then null else v_title end,
    'hint', case when v_hint = '{}'::jsonb then null else v_hint end));
  perform cs.set_setting('topics.picker', v_value, v_me);
  perform cs.audit('topic_picker.save', null, null, jsonb_build_object('before', v_old, 'after', v_value));
  return v_value;
end;
$$;

revoke execute on function cs.topic_admin_row(cs.support_topics) from public;
revoke execute on function cs_api.admin_save_topic(text, text, text, text, text, text, integer, boolean, text, text, text, text, text[]) from public;
revoke execute on function cs_api.admin_topic_picker() from public;
revoke execute on function cs_api.admin_set_topic_picker(text, text, text, text) from public;
grant execute on function cs_api.admin_save_topic(text, text, text, text, text, text, integer, boolean, text, text, text, text, text[]) to authenticated;
grant execute on function cs_api.admin_topic_picker() to authenticated;
grant execute on function cs_api.admin_set_topic_picker(text, text, text, text) to authenticated;
