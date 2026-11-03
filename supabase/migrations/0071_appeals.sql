alter table public.notifications drop constraint notifications_type;
alter table public.notifications add constraint notifications_type
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal'));

insert into private.settings (key, value, description) values
  ('appeals.window_days', '30', 'Batas hari sejak sanksi/penindakan konten untuk mengajukan banding')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values ('appeal', 10, 86400)
on conflict (action, window_seconds) do nothing;

create table private.moderation_events (
  id          bigint generated always as identity primary key,
  target_type text not null check (target_type in ('post', 'comment', 'message')),
  target_id   uuid not null,
  status      text not null check (status in ('visible', 'held', 'hidden', 'removed')),
  actor_id    uuid,
  created_at  timestamptz not null default now()
);
create index moderation_events_target_idx on private.moderation_events (target_type, target_id, created_at desc);
alter table private.moderation_events enable row level security;

create or replace function private.log_moderation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.moderation_events (target_type, target_id, status, actor_id)
  values (tg_argv[0], new.id,
          case when new.deleted_at is not null and old.deleted_at is null then 'removed' else new.moderation_status end,
          auth.uid());
  return null;
end;
$$;

create trigger posts_32_moderation_log
  after update of moderation_status, deleted_at on public.posts
  for each row when (new.moderation_status is distinct from old.moderation_status
                     or (new.deleted_at is not null and old.deleted_at is null))
  execute function private.log_moderation_event('post');
create trigger comments_32_moderation_log
  after update of moderation_status, deleted_at on public.comments
  for each row when (new.moderation_status is distinct from old.moderation_status
                     or (new.deleted_at is not null and old.deleted_at is null))
  execute function private.log_moderation_event('comment');
create trigger messages_32_moderation_log
  after update of moderation_status, deleted_at on public.messages
  for each row when (new.session_id is null and (new.moderation_status is distinct from old.moderation_status
                     or (new.deleted_at is not null and old.deleted_at is null)))
  execute function private.log_moderation_event('message');

create table public.appeals (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  target_type      text not null,
  target_id        uuid not null,
  reason           text not null,
  status           text not null default 'pending',
  original_decider uuid,
  decided_by       uuid,
  decided_at       timestamptz,
  decision_note    text,
  created_at       timestamptz not null default now(),
  constraint appeals_target_type check (target_type in ('sanction', 'post', 'comment', 'message')),
  constraint appeals_reason check (char_length(btrim(reason)) between 10 and 1000),
  constraint appeals_status check (status in ('pending', 'accepted', 'rejected')),
  constraint appeals_note check (char_length(decision_note) <= 1000),
  constraint appeals_decided check ((status = 'pending') = (decided_at is null)),
  constraint appeals_target_unique unique (target_type, target_id)
);
create index appeals_user_idx on public.appeals (user_id, created_at desc);
create index appeals_pending_idx on public.appeals (created_at) where status = 'pending';
alter table public.appeals enable row level security;
revoke all on public.appeals from anon, authenticated;
grant select (id, user_id, target_type, target_id, reason, status, decided_at, decision_note, created_at)
  on public.appeals to authenticated;
create policy appeals_select_own on public.appeals
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function private.check_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid;
  v_revoked timestamptz;
  v_iat     numeric;
  v_headers jsonb;
  v_profile text;
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  v_headers := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  v_profile := coalesce(case when current_setting('request.method', true) in ('GET', 'HEAD')
                             then v_headers ->> 'accept-profile'
                             else v_headers ->> 'content-profile' end, 'public');
  if v_profile <> 'cs_api' and private.is_banned(v_uid)
     and not (v_profile = 'public'
              and coalesce(current_setting('request.path', true), '')
                  in ('/rpc/create_appeal', '/rpc/get_my_appeals', '/rpc/get_my_sanctions')) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
  end if;
  if v_profile = 'public' and cs.is_staff(v_uid) then
    perform private.api_error(403, 'cs_staff_social_forbidden', 'Akun CS tidak bisa memakai fitur sosial');
  end if;
  select s.revoked_before into v_revoked from private.user_sessions s where s.user_id = v_uid;
  if v_revoked is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::numeric;
    if v_iat is null or to_timestamp(v_iat) < v_revoked then
      perform private.api_error(401, 'session_revoked', 'Sesi sudah dicabut, silakan masuk ulang');
    end if;
  end if;
end;
$$;

create or replace function private.appeal_target(p_user uuid, p_type text, p_id uuid)
returns table (decider uuid, decided_at timestamptz, state text, excerpt text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_author  uuid;
  v_deleted timestamptz;
  v_status  text;
  v_body    text;
  v_event   private.moderation_events;
  v_archive private.content_archive;
begin
  if p_type = 'sanction' then
    return query
    select s.created_by, s.created_at,
           case when s.revoked_at is not null then 'revoked'
                when s.category = 'zero_tolerance' then 'zero_tolerance'
                else 'active' end,
           left(s.kind || ': ' || s.reason, 280)
    from private.user_sanctions s
    where s.id = p_id and s.user_id = p_user;
    return;
  end if;

  if p_type = 'post' then
    select p.author_id, p.deleted_at, p.moderation_status, p.body into v_author, v_deleted, v_status, v_body
    from public.posts p where p.id = p_id;
  elsif p_type = 'comment' then
    select c.author_id, c.deleted_at, c.moderation_status, c.body into v_author, v_deleted, v_status, v_body
    from public.comments c where c.id = p_id;
  elsif p_type = 'message' then
    select m.sender_id, m.deleted_at, m.moderation_status, m.body into v_author, v_deleted, v_status, v_body
    from public.messages m where m.id = p_id and m.session_id is null;
  else
    return;
  end if;
  if v_author is null or v_author <> p_user then
    return;
  end if;

  if v_deleted is not null then
    select * into v_archive from private.content_archive a
    where a.target_type = p_type and a.target_id = p_id and a.reason = 'moderator_remove'
    order by a.id desc limit 1;
    if v_archive.id is null then
      return query select null::uuid, v_deleted, 'deleted'::text, null::text;
    else
      return query select v_archive.deleted_by, v_archive.deleted_at, 'removed'::text, left(v_archive.body, 280);
    end if;
    return;
  end if;
  select * into v_event from private.moderation_events e
  where e.target_type = p_type and e.target_id = p_id
  order by e.created_at desc, e.id desc limit 1;
  return query select v_event.actor_id, coalesce(v_event.created_at, now()), v_status, left(v_body, 280);
end;
$$;

create or replace function public.create_appeal(p_target_type text, p_target_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_target record;
  v_appeal public.appeals;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_target_type is null or p_target_type not in ('sanction', 'post', 'comment', 'message') then
    perform private.api_error(400, 'invalid_target', 'Banding untuk: sanction, post, comment, atau message');
  end if;
  if char_length(v_reason) not between 10 and 1000 then
    perform private.api_error(400, 'invalid_reason', 'Alasan banding 10–1000 karakter');
  end if;
  select * into v_target from private.appeal_target(v_me, p_target_type, p_target_id);
  if not found then
    perform private.api_error(404, 'target_not_found', 'Sanksi atau konten tidak ditemukan');
  end if;
  if v_target.state in ('zero_tolerance') or (p_target_type <> 'sanction' and exists (
       select 1 from private.user_sanctions s
       where s.user_id = v_me and s.category = 'zero_tolerance' and s.revoked_at is null)) then
    perform private.api_error(403, 'appeal_not_allowed', 'Penindakan ini tidak bisa diajukan banding');
  end if;
  if v_target.state not in ('active', 'hidden', 'removed') then
    perform private.api_error(409, 'appeal_not_allowed', 'Sanksi atau konten ini tidak sedang dibatasi');
  end if;
  if v_target.decided_at < now() - private.setting_num('appeals.window_days', 30) * interval '1 day' then
    perform private.api_error(400, 'appeal_window_closed', 'Batas waktu pengajuan banding sudah lewat');
  end if;
  if exists (select 1 from public.appeals a where a.target_type = p_target_type and a.target_id = p_target_id) then
    perform private.api_error(409, 'appeal_exists', 'Banding untuk ini sudah pernah diajukan');
  end if;
  perform private.consume_rate_limit(v_me, 'appeal');
  insert into public.appeals (user_id, target_type, target_id, reason, original_decider)
  values (v_me, p_target_type, p_target_id, v_reason, v_target.decider)
  on conflict (target_type, target_id) do nothing
  returning * into v_appeal;
  if v_appeal.id is null then
    perform private.api_error(409, 'appeal_exists', 'Banding untuk ini sudah pernah diajukan');
  end if;
  return jsonb_build_object('id', v_appeal.id, 'target_type', v_appeal.target_type, 'target_id', v_appeal.target_id,
                            'reason', v_appeal.reason, 'status', v_appeal.status, 'created_at', v_appeal.created_at);
end;
$$;

create or replace function public.get_my_appeals()
returns table (id uuid, target_type text, target_id uuid, reason text, status text, decision_note text,
               created_at timestamptz, decided_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.target_type, a.target_id, a.reason, a.status, a.decision_note, a.created_at, a.decided_at
  from public.appeals a
  where a.user_id = auth.uid()
  order by a.created_at desc
  limit 100;
$$;

create or replace function cs.appeal_permission(p_target_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_target_type = 'sanction' then 'community.sanction' else 'community.moderate' end;
$$;

create or replace function cs.appeal_reviewer_conflict(p_appeal public.appeals, p_agent uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_appeal.original_decider = p_agent
     and exists (select 1 from cs.agents a
                 where a.user_id <> p_agent and a.disabled_at is null
                   and a.community_permissions && array[cs.appeal_permission(p_appeal.target_type)]);
$$;

create or replace function cs.appeal_view(p_id uuid, p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.id, 'status', a.status, 'target_type', a.target_type, 'target_id', a.target_id, 'reason', a.reason,
    'created_at', a.created_at, 'decided_at', a.decided_at, 'decision_note', a.decision_note,
    'user', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name,
                               'avatar_url', p.avatar_url, 'banned', private.is_banned(p.id)),
    'target', case when a.target_type = 'sanction' then (
        select jsonb_build_object('kind', s.kind, 'category', s.category, 'reason', s.reason, 'starts_at', s.starts_at,
                                  'ends_at', s.ends_at, 'revoked_at', s.revoked_at,
                                  'active', s.revoked_at is null and (s.ends_at is null or s.ends_at > now()))
        from private.user_sanctions s where s.id = a.target_id)
      else (select jsonb_build_object('state', t.state, 'excerpt', t.excerpt, 'decided_at', t.decided_at)
            from private.appeal_target(a.user_id, a.target_type, a.target_id) t) end,
    'original_decider', case when a.original_decider is not null then jsonb_build_object(
                          'id', a.original_decider, 'name', coalesce(cs.agent_name(a.original_decider), 'Admin')) end,
    'decided_by', cs.staff_ref(a.decided_by),
    'can_decide', a.status = 'pending'
                  and cs.has_community(array[cs.appeal_permission(a.target_type)])
                  and not cs.appeal_reviewer_conflict(a, p_agent))
  from public.appeals a
  join public.profiles p on p.id = a.user_id
  where a.id = p_id;
$$;

create or replace function cs_api.community_appeals(p_status text default 'pending', p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate,community.sanction}');
begin
  if coalesce(p_status, '') not in ('pending', 'accepted', 'rejected') then
    perform private.api_error(400, 'invalid_status', 'Status banding: pending, accepted, atau rejected');
  end if;
  return coalesce((
    select jsonb_agg(cs.appeal_view(x.id, v_me) order by x.created_at)
    from (select a.id, a.created_at from public.appeals a
          where a.status = p_status
          order by case when p_status = 'pending' then a.created_at end asc, a.decided_at desc nulls last
          limit least(greatest(coalesce(p_limit, 100), 1), 500)) x), '[]');
end;
$$;

create or replace function private.restore_removed_content(p_type text, p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_archive private.content_archive;
begin
  select * into v_archive from private.content_archive a
  where a.target_type = p_type and a.target_id = p_id and a.reason = 'moderator_remove'
  order by a.id desc limit 1;
  if v_archive.id is null then
    return false;
  end if;
  if p_type = 'post' then
    perform cs.as_system(format(
      'update public.posts set body = %L, attachments = %L::jsonb, deleted_at = null, moderation_status = %L,'
      || ' moderated_at = now() where id = %L and deleted_at is not null',
      v_archive.body, coalesce(v_archive.attachments, '[]'::jsonb), 'visible', p_id));
  elsif p_type = 'comment' then
    perform cs.as_system(format(
      'update public.comments set body = %L, deleted_at = null, moderation_status = %L, moderated_at = now()'
      || ' where id = %L and deleted_at is not null',
      v_archive.body, 'visible', p_id));
  else
    perform cs.as_system(format(
      'update public.messages set body = %L, attachments = %L::jsonb, deleted_at = null, moderation_status = %L,'
      || ' moderated_at = now() where id = %L and deleted_at is not null',
      v_archive.body, coalesce(v_archive.attachments, '[]'::jsonb), 'visible', p_id));
  end if;
  return true;
end;
$$;

create or replace function cs_api.community_appeal_decide(p_id uuid, p_accept boolean, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.moderate,community.sanction}');
  v_note   text := btrim(coalesce(p_note, ''));
  v_appeal public.appeals;
  v_target record;
  v_status text := case when p_accept then 'accepted' else 'rejected' end;
begin
  if p_accept is null then
    perform private.api_error(400, 'invalid_decision', 'Pilih terima atau tolak');
  end if;
  if char_length(v_note) not between 5 and 1000 then
    perform private.api_error(400, 'note_required', 'Catatan keputusan 5–1000 karakter');
  end if;
  select * into v_appeal from public.appeals where id = p_id for update;
  if not found then
    perform private.api_error(404, 'appeal_not_found', 'Banding tidak ditemukan');
  end if;
  if not cs.has_community(array[cs.appeal_permission(v_appeal.target_type)]) then
    perform private.api_error(403, 'community_forbidden', 'Izin komunitas Anda tidak cukup untuk aksi ini');
  end if;
  if v_appeal.status <> 'pending' then
    perform private.api_error(409, 'appeal_decided', 'Banding ini sudah diputuskan');
  end if;
  if cs.appeal_reviewer_conflict(v_appeal, v_me) then
    perform private.api_error(403, 'appeal_reviewer_conflict', 'Banding harus ditinjau staf lain, bukan pemberi keputusan awal');
  end if;

  if p_accept then
    if v_appeal.target_type = 'sanction' then
      update private.user_sanctions
         set revoked_at = now(), revoked_by = v_me, revoke_reason = left('Banding diterima: ' || v_note, 500)
       where id = v_appeal.target_id and revoked_at is null;
    else
      select * into v_target from private.appeal_target(v_appeal.user_id, v_appeal.target_type, v_appeal.target_id);
      if v_target.state = 'removed' then
        perform private.restore_removed_content(v_appeal.target_type, v_appeal.target_id);
      elsif v_target.state in ('hidden', 'held') then
        if v_appeal.target_type = 'post' then
          update public.posts set moderation_status = 'visible', moderated_at = now() where id = v_appeal.target_id;
        elsif v_appeal.target_type = 'comment' then
          update public.comments set moderation_status = 'visible', moderated_at = now() where id = v_appeal.target_id;
        else
          update public.messages set moderation_status = 'visible', moderated_at = now() where id = v_appeal.target_id;
        end if;
      end if;
    end if;
  end if;

  update public.appeals
     set status = v_status, decided_by = v_me, decided_at = now(), decision_note = v_note
   where id = p_id;
  perform private.notify(v_appeal.user_id, null, 'appeal', jsonb_build_object(
    'appeal_id', v_appeal.id, 'status', v_status, 'target_type', v_appeal.target_type,
    'target_id', v_appeal.target_id, 'note', v_note,
    'title', case when p_accept then 'Banding Anda diterima' else 'Banding Anda ditolak' end,
    'body', case when p_accept and v_appeal.target_type = 'sanction' then 'Sanksi Anda telah dicabut.'
                 when p_accept then 'Konten Anda telah dipulihkan.'
                 else 'Keputusan moderasi tetap berlaku.' end));
  perform cs.audit('community.appeal_decide', null, v_appeal.user_id,
    jsonb_build_object('appeal', v_appeal.id, 'accept', p_accept, 'target_type', v_appeal.target_type,
                       'target_id', v_appeal.target_id, 'note', v_note));
  return cs.appeal_view(p_id, v_me);
end;
$$;

create or replace function cs_api.community_zero_tolerance(p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.sanction}');
  v_reason   text := btrim(coalesce(p_reason, ''));
  v_row      private.user_sanctions;
  v_posts    integer;
  v_comments integer;
  v_messages integer;
begin
  if char_length(v_reason) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  perform cs.check_moderation_target(p_user_id);
  v_row := private.apply_sanction(p_user_id, v_reason, 'zero_tolerance', 'ban', null, v_me);
  update public.posts set moderation_status = 'hidden', moderated_at = now()
   where author_id = p_user_id and deleted_at is null and moderation_status <> 'hidden';
  get diagnostics v_posts = row_count;
  update public.comments set moderation_status = 'hidden', moderated_at = now()
   where author_id = p_user_id and deleted_at is null and moderation_status <> 'hidden';
  get diagnostics v_comments = row_count;
  update public.messages set moderation_status = 'hidden', moderated_at = now()
   where sender_id = p_user_id and deleted_at is null and session_id is null and moderation_status <> 'hidden';
  get diagnostics v_messages = row_count;
  perform cs.audit('community.zero_tolerance', null, p_user_id,
    jsonb_build_object('sanction_id', v_row.id, 'reason', v_reason, 'hidden_posts', v_posts,
                       'hidden_comments', v_comments, 'hidden_messages', v_messages));
  return cs_api.community_user(p_user_id)
         || jsonb_build_object('hidden', jsonb_build_object('posts', v_posts, 'comments', v_comments, 'messages', v_messages));
end;
$$;

revoke execute on function private.log_moderation_event() from public;
revoke execute on function private.appeal_target(uuid, text, uuid) from public;
revoke execute on function private.restore_removed_content(text, uuid) from public;
revoke execute on function cs.appeal_permission(text) from public;
revoke execute on function cs.appeal_reviewer_conflict(public.appeals, uuid) from public;
revoke execute on function cs.appeal_view(uuid, uuid) from public;
revoke execute on function public.create_appeal(text, uuid, text) from public, anon;
revoke execute on function public.get_my_appeals() from public, anon;
revoke execute on function cs_api.community_appeals(text, integer) from public;
revoke execute on function cs_api.community_appeal_decide(uuid, boolean, text) from public;
revoke execute on function cs_api.community_zero_tolerance(uuid, text) from public;

grant execute on function private.check_request() to anon, authenticated;
grant execute on function public.create_appeal(text, uuid, text) to authenticated;
grant execute on function public.get_my_appeals() to authenticated;
grant execute on function cs_api.community_appeals(text, integer) to authenticated;
grant execute on function cs_api.community_appeal_decide(uuid, boolean, text) to authenticated;
grant execute on function cs_api.community_zero_tolerance(uuid, text) to authenticated;
