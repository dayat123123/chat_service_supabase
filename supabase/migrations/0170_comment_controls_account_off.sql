alter table private.comment_preferences add column all_off boolean not null default false;

create function private.comments_all_off(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.all_off from private.comment_preferences c where c.user_id = p_user), false);
$$;

create function private.effective_comment_audience(p_author uuid, p_audience public.comment_audience)
returns public.comment_audience
language sql
stable
security definer
set search_path = ''
as $$
  select case when private.comments_all_off(p_author) then 'off'::public.comment_audience else p_audience end;
$$;

create or replace function private.comments_off_post_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from public.posts p where p.comment_audience = 'off'
  union all
  select p.id
  from private.comment_preferences c
  join public.posts p on p.author_id = c.user_id
  where c.all_off and p.comment_audience <> 'off';
$$;

create or replace function private.comments_enforce_audience()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post        public.posts;
  v_restriction text;
begin
  select * into v_post from public.posts p where p.id = new.post_id;
  if not found then
    return new;
  end if;
  v_restriction := private.comment_restriction(
    v_post.author_id,
    private.effective_comment_audience(v_post.author_id, v_post.comment_audience),
    new.author_id);
  if v_restriction = 'off' then
    perform private.api_error(403, 'comments_off', 'Komentar untuk postingan ini dinonaktifkan');
  elsif v_restriction = 'blocked' then
    perform private.api_error(403, 'blocked', 'Tidak bisa berkomentar di post ini');
  elsif v_restriction is not null then
    perform private.api_error(403, 'comments_restricted', 'Anda tidak termasuk yang boleh berkomentar di postingan ini');
  end if;
  return new;
end;
$$;

alter type public.feed_post add attribute comments_off_by_account boolean;

create or replace function private.feed_posts(p_ids uuid[])
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.author_id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         p.body, p.sentiment, p.attachments, p.like_count,
         case when ea.audience = 'off' and p.author_id is distinct from auth.uid() then null
              else p.comment_count end,
         coalesce((select array_agg(ps.stock_code order by ps.stock_code)
                   from public.post_stocks ps where ps.post_id = p.id), '{}'),
         exists (select 1 from public.reactions r
                 where r.user_id = auth.uid() and r.target_type = 'post' and r.target_id = p.id),
         p.edited_at, p.created_at,
         private.make_cursor(p.created_at, p.id),
         private.poll_view(p.id, p.author_id),
         exists (select 1 from public.bookmarks b where b.user_id = auth.uid() and b.post_id = p.id),
         coalesce((select array_agg(ph.tag order by ph.tag) from public.post_hashtags ph where ph.post_id = p.id), '{}'),
         private.post_is_bot(p.id),
         private.is_official_account(p.author_id),
         case when p.author_id = auth.uid() then p.moderation_status end,
         case when p.comment_count > 0 and ea.audience <> 'off' then (
           select to_jsonb(tc)
           from private.thread_comments(array(
             select c.id from public.comments c
             where c.post_id = p.id
               and c.parent_id is null
               and c.deleted_at is null
               and c.moderation_status = 'visible'
             order by c.like_count + c.reply_count desc, c.seq
             limit 1)) tc)
         end,
         case when p.author_id = auth.uid() then p.comment_audience::text end,
         cr.restriction is null,
         cr.restriction,
         case when p.author_id = auth.uid() then ao.all_off end
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  cross join lateral (select private.comments_all_off(p.author_id) as all_off) ao
  cross join lateral (
    select case when ao.all_off then 'off'::public.comment_audience else p.comment_audience end as audience) ea
  cross join lateral (
    select private.comment_restriction(p.author_id, ea.audience, auth.uid()) as restriction) cr
  order by u.ord;
$$;

create or replace function private.shared_post_preview(p_attachments jsonb, p_viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when x.post_id is null then null else coalesce((
    select jsonb_build_object(
             'post_id', p.id, 'available', true, 'author_id', p.author_id,
             'author_username', pr.username::text, 'author_display_name', pr.display_name,
             'author_avatar_url', pr.avatar_url, 'author_is_verified', pr.is_verified,
             'body', private.snippet(p.body, 280), 'attachments', p.attachments, 'sentiment', p.sentiment,
             'stock_codes', coalesce((select jsonb_agg(ps.stock_code order by ps.stock_code)
                                      from public.post_stocks ps where ps.post_id = p.id), '[]'),
             'like_count', p.like_count,
             'comment_count', case when private.effective_comment_audience(p.author_id, p.comment_audience) = 'off'
                                        and p.author_id is distinct from p_viewer then null
                                   else p.comment_count end,
             'created_at', p.created_at)
    from public.posts p
    join public.profiles pr on pr.id = p.author_id
    where p.id = x.post_id
      and p.deleted_at is null
      and (p.moderation_status = 'visible' or p.author_id = p_viewer)
      and not private.is_blocked_pair(p_viewer, p.author_id)
  ), jsonb_build_object('post_id', x.post_id, 'available', false)) end
  from (
    select (select (e.value ->> 'post_id')::uuid
            from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments
                                           else '[]'::jsonb end) e
            where e.value ->> 'type' = 'post'
            limit 1) as post_id
  ) x;
$$;

create or replace function public.get_comment_settings()
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
  return jsonb_build_object('audience', private.comment_default_audience(auth.uid())::text,
                            'all_off', private.comments_all_off(auth.uid()));
end;
$$;

create function public.set_all_comments_off(p_off boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_off is null then
    perform private.api_error(400, 'invalid_comment_setting', 'Pilihan matikan semua komentar wajib diisi');
  end if;
  insert into private.comment_preferences (user_id, all_off) values (auth.uid(), p_off)
  on conflict (user_id) do update set all_off = excluded.all_off, updated_at = now();
  return public.get_comment_settings();
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

revoke execute on function private.comments_all_off(uuid) from public;
revoke execute on function private.effective_comment_audience(uuid, public.comment_audience) from public;
revoke execute on function public.set_all_comments_off(boolean) from public, anon;

grant execute on function private.comments_all_off(uuid) to authenticated;
grant execute on function private.effective_comment_audience(uuid, public.comment_audience) to authenticated;
grant execute on function public.set_all_comments_off(boolean) to authenticated;
