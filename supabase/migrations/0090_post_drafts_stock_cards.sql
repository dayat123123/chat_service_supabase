insert into private.settings (key, value, description) values
  ('drafts.max_per_user', '20', 'Maksimal draf postingan tersimpan per pengguna')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('post_draft', 60, 60)
on conflict (action, window_seconds) do nothing;

create table public.post_drafts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  client_draft_id uuid not null,
  body            text not null default '' check (char_length(body) <= 2000),
  sentiment       text check (sentiment in ('bullish', 'bearish', 'neutral')),
  stocks          text[] not null default '{}' check (cardinality(stocks) <= 10),
  attachments     jsonb not null default '[]'
                  check (jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 4),
  poll            jsonb check (poll is null or (jsonb_typeof(poll) = 'object' and octet_length(poll::text) <= 4000)),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint post_drafts_client_unique unique (user_id, client_draft_id)
);
create index post_drafts_user_idx on public.post_drafts (user_id, updated_at desc);
alter table public.post_drafts enable row level security;
revoke all on public.post_drafts from anon, authenticated;
grant select on public.post_drafts to authenticated;
create policy post_drafts_select_own on public.post_drafts
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function private.post_draft_view(d public.post_drafts)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', d.id, 'client_draft_id', d.client_draft_id, 'body', d.body, 'sentiment', d.sentiment,
    'stocks', to_jsonb(d.stocks), 'attachments', d.attachments, 'poll', d.poll,
    'created_at', d.created_at, 'updated_at', d.updated_at);
$$;

create or replace function public.save_post_draft(p_client_draft_id uuid, p_body text default '',
                                                  p_sentiment text default null, p_stocks text[] default '{}',
                                                  p_attachments jsonb default '[]', p_poll jsonb default null,
                                                  p_base_updated_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_body   text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_att    jsonb := coalesce(p_attachments, '[]');
  v_poll   jsonb := case when jsonb_typeof(p_poll) = 'null' then null else p_poll end;
  v_stocks text[];
  v_old    public.post_drafts;
  v_new    public.post_drafts;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_client_draft_id is null then
    perform private.api_error(400, 'invalid_draft', 'client_draft_id wajib diisi');
  end if;
  perform private.consume_rate_limit(v_uid, 'post_draft');
  if char_length(v_body) > 2000 then
    perform private.api_error(400, 'body_too_long', 'Draf maksimal 2000 karakter');
  end if;
  if p_sentiment is not null and p_sentiment not in ('bullish', 'bearish', 'neutral') then
    perform private.api_error(400, 'invalid_sentiment', 'Sentimen: bullish, bearish, atau neutral');
  end if;
  select coalesce(array_agg(s.code order by s.ord), '{}') into v_stocks
  from (select upper(btrim(x)) as code, min(o) as ord
        from unnest(coalesce(p_stocks, '{}')) with ordinality as u(x, o)
        where btrim(coalesce(x, '')) <> ''
        group by upper(btrim(x))) s;
  if cardinality(v_stocks) > 10 or exists (select 1 from unnest(v_stocks) c where c !~ '^[A-Z][A-Z0-9]{1,11}$') then
    perform private.api_error(400, 'invalid_stocks', 'Maksimal 10 kode saham dengan format valid');
  end if;
  perform private.validate_attachments(v_att, 'posts/' || v_uid || '/');
  if v_poll is not null and (jsonb_typeof(v_poll) <> 'object' or octet_length(v_poll::text) > 4000) then
    perform private.api_error(400, 'invalid_poll', 'Polling draf harus berupa objek maksimal 4000 byte');
  end if;
  if v_body = '' and jsonb_array_length(v_att) = 0 and v_poll is null and cardinality(v_stocks) = 0 then
    perform private.api_error(400, 'empty_draft', 'Draf kosong tidak disimpan');
  end if;

  select * into v_old from public.post_drafts d
  where d.user_id = v_uid and d.client_draft_id = p_client_draft_id
  for update;
  if v_old.id is null then
    if (select count(*) from public.post_drafts d where d.user_id = v_uid)
       >= private.setting_num('drafts.max_per_user', 20) then
      perform private.api_error(409, 'draft_limit', 'Maksimal 20 draf. Hapus draf lama terlebih dahulu');
    end if;
    insert into public.post_drafts (user_id, client_draft_id, body, sentiment, stocks, attachments, poll)
    values (v_uid, p_client_draft_id, v_body, p_sentiment, v_stocks, v_att, v_poll)
    on conflict (user_id, client_draft_id) do update
      set body = excluded.body, sentiment = excluded.sentiment, stocks = excluded.stocks,
          attachments = excluded.attachments, poll = excluded.poll, updated_at = clock_timestamp()
    returning * into v_new;
  else
    if p_base_updated_at is not null and v_old.updated_at > p_base_updated_at then
      perform private.api_error(409, 'draft_conflict', 'Draf sudah diubah di perangkat lain. Muat ulang draf');
    end if;
    update public.post_drafts
       set body = v_body, sentiment = p_sentiment, stocks = v_stocks, attachments = v_att, poll = v_poll,
           updated_at = clock_timestamp()
     where id = v_old.id
    returning * into v_new;
  end if;
  return private.post_draft_view(v_new);
end;
$$;

create or replace function public.get_post_drafts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return coalesce((select jsonb_agg(private.post_draft_view(d) order by d.updated_at desc, d.id)
                   from public.post_drafts d where d.user_id = v_uid), '[]');
end;
$$;

create or replace function public.delete_post_draft(p_client_draft_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  delete from public.post_drafts d where d.user_id = v_uid and d.client_draft_id = p_client_draft_id;
  return found;
end;
$$;

create or replace function private.post_drafts_consume()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.post_drafts d where d.user_id = new.author_id and d.client_draft_id = new.client_id;
  return null;
end;
$$;

create trigger posts_61_consume_draft
  after insert on public.posts
  for each row when (new.client_id is not null)
  execute function private.post_drafts_consume();

create or replace function private.validate_stock_cards(p_items jsonb, p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_codes text[];
begin
  if jsonb_array_length(coalesce(p_items, '[]')) = 0 then
    return '[]';
  end if;
  if exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(400, 'share_not_allowed', 'Kartu saham tidak bisa dikirim ke chat CS');
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) e
             where jsonb_typeof(e.value -> 'code') is distinct from 'string'
                or upper(btrim(e.value ->> 'code')) !~ '^[A-Z][A-Z0-9]{1,11}$') then
    perform private.api_error(400, 'invalid_attachments', 'Kode saham tidak valid');
  end if;
  select array_agg(s.code order by s.ord) into v_codes
  from (select upper(btrim(e.value ->> 'code')) as code, min(e.ordinality) as ord
        from jsonb_array_elements(p_items) with ordinality e
        group by upper(btrim(e.value ->> 'code'))) s;
  if cardinality(v_codes) > 3 then
    perform private.api_error(400, 'invalid_attachments', 'Maksimal 3 kartu saham per pesan');
  end if;
  return (select jsonb_agg(jsonb_build_object('type', 'stock', 'code', u.code) order by u.ord)
          from unnest(v_codes) with ordinality as u(code, ord));
end;
$$;

create or replace function private.messages_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_media  jsonb := new.attachments;
  v_posts  jsonb := '[]';
  v_stocks jsonb := '[]';
begin
  if tg_op = 'INSERT' then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    if jsonb_typeof(new.attachments) = 'array' then
      select coalesce(jsonb_agg(e.value order by e.ordinality)
                        filter (where coalesce(e.value ->> 'type', '') not in ('post', 'stock')), '[]'),
             coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'post'), '[]'),
             coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'stock'), '[]')
        into v_media, v_posts, v_stocks
      from jsonb_array_elements(new.attachments) with ordinality e;
    end if;
    perform private.validate_attachments(
      v_media, 'rooms/' || new.room_id || '/' || new.sender_id || '/');
    perform private.check_message_media(v_media, new.room_id);
    if jsonb_array_length(v_posts) > 0 or jsonb_array_length(v_stocks) > 0 then
      new.attachments := v_media
        || case when jsonb_array_length(v_posts) > 0
                then private.validate_shared_post(v_posts, new.room_id, new.sender_id) else '[]'::jsonb end
        || private.validate_stock_cards(v_stocks, new.room_id);
    end if;
    if new.reply_to_id is not null
       and not exists (select 1 from public.messages
                       where id = new.reply_to_id and room_id = new.room_id) then
      perform private.api_error(400, 'invalid_reply', 'Pesan yang dibalas tidak ada di room ini');
    end if;
  elsif new.deleted_at is null and new.body is distinct from old.body then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create or replace function private.social_forget_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.bookmarks where user_id = new.id;
  delete from public.message_reactions where user_id = new.id;
  delete from private.notification_prefs where user_id = new.id;
  delete from private.notification_settings where user_id = new.id;
  delete from private.notification_actors where actor_id = new.id;
  delete from private.analytics_events where user_id = new.id;
  delete from public.post_drafts where user_id = new.id;
  update private.notification_events set user_id = null where user_id = new.id;
  return null;
end;
$$;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.consume_rate_limit(v_uid, 'data_export');
  perform private.log_personal_data_access(v_uid, 'self_export', '{all}');

  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'olt_user_id' from public.profiles p where p.id = v_uid),
    'email', (select up.email from private.user_private up where up.user_id = v_uid),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'body', body, 'sentiment', sentiment, 'attachments', attachments,
        'created_at', created_at, 'edited_at', edited_at) order by created_at)
      from public.posts where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'polls', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', pl.post_id, 'ends_at', pl.ends_at,
        'options', (select jsonb_agg(o.label order by o.position)
                    from public.post_poll_options o where o.post_id = pl.post_id))
        order by pl.created_at)
      from public.post_polls pl join public.posts p on p.id = pl.post_id
      where p.author_id = v_uid and p.deleted_at is null), '[]'::jsonb),
    'poll_votes', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', v.post_id, 'option', o.label, 'created_at', v.created_at) order by v.created_at)
      from public.post_poll_votes v join public.post_poll_options o on o.id = v.option_id
      where v.user_id = v_uid), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'post_id', post_id, 'parent_id', parent_id, 'body', body, 'created_at', created_at)
        order by created_at)
      from public.comments where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'room_id', room_id, 'body', body, 'attachments', attachments, 'created_at', created_at)
        order by created_at)
      from public.messages where sender_id = v_uid and deleted_at is null), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) - 'user_id') from public.reactions r
      where r.user_id = v_uid), '[]'::jsonb),
    'message_reactions', coalesce((select jsonb_agg(jsonb_build_object(
        'message_id', mr.message_id, 'emoji', mr.emoji, 'created_at', mr.created_at) order by mr.created_at)
      from public.message_reactions mr where mr.user_id = v_uid), '[]'::jsonb),
    'bookmarks', coalesce((select jsonb_agg(jsonb_build_object('post_id', b.post_id, 'created_at', b.created_at)
                                            order by b.created_at)
      from public.bookmarks b where b.user_id = v_uid), '[]'::jsonb),
    'following', coalesce((select jsonb_agg(f.following_id) from public.follows f
      where f.follower_id = v_uid), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(b.blocked_id) from public.blocks b
      where b.blocker_id = v_uid), '[]'::jsonb),
    'muted_users', coalesce((select jsonb_agg(m.muted_id) from public.mutes m
      where m.muter_id = v_uid), '[]'::jsonb),
    'muted_keywords', coalesce((select jsonb_agg(k.keyword) from public.muted_keywords k
      where k.user_id = v_uid), '[]'::jsonb),
    'muted_stocks', coalesce((select jsonb_agg(s.stock_code) from public.muted_stocks s
      where s.user_id = v_uid), '[]'::jsonb),
    'watchlist', coalesce((select jsonb_agg(w.stock_code) from public.stock_watchers w
      where w.user_id = v_uid), '[]'::jsonb),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
        'target_type', target_type, 'target_id', target_id, 'reason', reason,
        'status', status, 'created_at', created_at))
      from public.reports where reporter_id = v_uid), '[]'::jsonb),
    'consents', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', d.kind, 'version', d.version, 'title', d.title, 'accepted_at', c.accepted_at)
        order by c.accepted_at)
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb),
    'support_tickets', coalesce((select jsonb_agg(jsonb_build_object(
        'ticket_number', t.ticket_number, 'topic', t.topic, 'status', t.status, 'created_at', t.created_at,
        'closed_at', t.closed_at, 'rating', t.rating, 'rating_comment', t.rating_comment)
        order by t.created_at)
      from cs.tickets t where t.customer_id = v_uid), '[]'::jsonb),
    'push_devices', coalesce((select jsonb_agg(jsonb_build_object(
        'platform', d.platform, 'locale', d.locale, 'app_version', d.app_version,
        'created_at', d.created_at, 'last_seen_at', d.last_seen_at) order by d.created_at)
      from private.push_devices d where d.user_id = v_uid), '[]'::jsonb),
    'notification_preferences', private.notification_prefs_view(v_uid),
    'dm_policy', private.dm_policy(v_uid),
    'linked_accounts', private.export_optional('linked_accounts', v_uid),
    'appeals', private.export_optional('appeals', v_uid),
    'analytics_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'created_at', e.created_at, 'platform', e.platform, 'app_version', e.app_version,
        'props', e.props) order by e.created_at desc)
      from (select * from private.analytics_events a where a.user_id = v_uid order by a.created_at desc limit 5000) e),
      '[]'::jsonb),
    'post_drafts', coalesce((select jsonb_agg(private.post_draft_view(d) order by d.updated_at desc)
      from public.post_drafts d where d.user_id = v_uid), '[]'::jsonb),
    'notification_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'source_type', e.source_type, 'source_id', e.source_id,
        'notification_id', e.notification_id, 'created_at', e.created_at) order by e.created_at desc)
      from (select * from private.notification_events ne where ne.user_id = v_uid
            order by ne.created_at desc limit 5000) e), '[]'::jsonb)
  );
end;
$$;

revoke execute on function private.post_draft_view(public.post_drafts) from public;
revoke execute on function public.save_post_draft(uuid, text, text, text[], jsonb, jsonb, timestamptz) from public, anon;
revoke execute on function public.get_post_drafts() from public, anon;
revoke execute on function public.delete_post_draft(uuid) from public, anon;
revoke execute on function private.post_drafts_consume() from public;
revoke execute on function private.validate_stock_cards(jsonb, uuid) from public;

grant execute on function public.save_post_draft(uuid, text, text, text[], jsonb, jsonb, timestamptz) to authenticated;
grant execute on function public.get_post_drafts() to authenticated;
grant execute on function public.delete_post_draft(uuid) to authenticated;
