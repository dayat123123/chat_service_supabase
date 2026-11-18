create table private.mention_preferences (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  policy     text not null default 'everyone',
  updated_at timestamptz not null default now(),
  constraint mention_preferences_policy check (policy in ('everyone', 'following', 'none'))
);
alter table private.mention_preferences enable row level security;

create function private.mention_policy(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select m.policy from private.mention_preferences m where m.user_id = p_user), 'everyone');
$$;

create function private.mention_allowed(p_actor uuid, p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_actor is null or p_target is null or p_actor = p_target then true
    when private.safety_exempt(p_actor) then true
    else case private.mention_policy(p_target)
           when 'none' then false
           when 'following' then private.is_following(p_target, p_actor)
           else true
         end
  end;
$$;

create or replace function private.notify(
  p_user_id   uuid,
  p_actor_id  uuid,
  p_type      text,
  p_payload   jsonb,
  p_group_key text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_user_id = p_actor_id then
    return;
  end if;
  if p_actor_id is not null and private.is_blocked_pair(p_user_id, p_actor_id) then
    return;
  end if;
  if p_type = 'mention' and not private.mention_allowed(p_actor_id, p_user_id) then
    return;
  end if;

  if p_group_key is null then
    insert into public.notifications (user_id, actor_id, type, payload)
    values (p_user_id, p_actor_id, p_type, coalesce(p_payload, '{}'::jsonb));
  else
    insert into public.notifications (user_id, actor_id, type, payload, group_key)
    values (p_user_id, p_actor_id, p_type, coalesce(p_payload, '{}'::jsonb), p_group_key)
    on conflict (user_id, group_key) where read_at is null and group_key is not null
    do update set
      actor_id    = excluded.actor_id,
      payload     = excluded.payload,
      event_count = public.notifications.event_count + 1,
      created_at  = now();
  end if;
end;
$$;

create function public.get_mention_policy()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return jsonb_build_object('policy', private.mention_policy(auth.uid()));
end;
$$;

create function public.set_mention_policy(p_policy text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_policy is null or p_policy not in ('everyone', 'following', 'none') then
    perform private.api_error(400, 'invalid_policy', 'Pilihan: everyone, following, atau none');
  end if;
  if p_policy = 'everyone' then
    delete from private.mention_preferences m where m.user_id = auth.uid();
  else
    insert into private.mention_preferences (user_id, policy) values (auth.uid(), p_policy)
    on conflict (user_id) do update set policy = excluded.policy, updated_at = now();
  end if;
  return public.get_mention_policy();
end;
$$;

drop function public.search_profiles(text, integer);
create function public.search_profiles(p_query text, p_limit integer default 10)
returns table (id uuid, username text, display_name text, avatar_url text, is_verified boolean, is_official boolean,
               can_mention boolean)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified, private.is_official_account(p.id),
         private.mention_allowed(auth.uid(), p.id)
  from public.profiles p, q
  where q.term <> ''
    and (p.username::text ilike q.term || '%' or p.display_name ilike '%' || q.term || '%')
    and p.id not in (select private.blocked_user_ids())
    and not cs.is_staff(p.id)
    and not p.is_guest
  order by (lower(p.username::text) = lower(btrim(p_query))) desc,
           p.follower_count desc,
           p.username
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
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
        'comment_audience', comment_audience, 'created_at', created_at, 'edited_at', edited_at) order by created_at)
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
    'mention_policy', private.mention_policy(v_uid),
    'comment_audience', private.comment_default_audience(v_uid)::text,
    'comments_all_off', private.comments_all_off(v_uid),
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
            order by ne.created_at desc limit 5000) e), '[]'::jsonb),
    'trade_share', private.trade_share_export_user(v_uid)
  );
end;
$$;

revoke execute on function private.mention_policy(uuid) from public;
revoke execute on function private.mention_allowed(uuid, uuid) from public;
revoke execute on function public.get_mention_policy() from public, anon;
revoke execute on function public.set_mention_policy(text) from public, anon;
revoke execute on function public.search_profiles(text, integer) from public, anon;

grant execute on function private.mention_policy(uuid) to authenticated;
grant execute on function private.mention_allowed(uuid, uuid) to authenticated;
grant execute on function public.get_mention_policy() to authenticated;
grant execute on function public.set_mention_policy(text) to authenticated;
grant execute on function public.search_profiles(text, integer) to authenticated;
