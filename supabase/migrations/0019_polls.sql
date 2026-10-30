insert into private.rate_limits (action, max_count, window_seconds) values
  ('poll_vote', 30, 60),
  ('poll_vote', 500, 86400)
on conflict (action, window_seconds) do nothing;

create table if not exists public.post_polls (
  post_id      uuid primary key references public.posts(id) on delete cascade,
  ends_at      timestamptz not null,
  voters_count integer not null default 0 check (voters_count >= 0),
  created_at   timestamptz not null default now()
);

create table if not exists public.post_poll_options (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.post_polls(post_id) on delete cascade,
  position    smallint not null check (position between 0 and 3),
  label       text not null check (char_length(label) between 1 and 40),
  votes_count integer not null default 0 check (votes_count >= 0),
  unique (post_id, position)
);

create table if not exists public.post_poll_votes (
  post_id    uuid not null references public.post_polls(post_id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  option_id  uuid not null references public.post_poll_options(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_poll_votes_user_idx on public.post_poll_votes (user_id, created_at desc);
create index if not exists post_poll_votes_option_idx on public.post_poll_votes (option_id);

alter table public.post_polls enable row level security;
alter table public.post_poll_options enable row level security;
alter table public.post_poll_votes enable row level security;
revoke all on public.post_polls, public.post_poll_options, public.post_poll_votes from anon, authenticated;
grant insert (post_id, user_id, option_id) on public.post_poll_votes to authenticated;

create or replace function private.poll_vote_state(p_post_id uuid, p_option_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when pl.post_id is null then 'poll_not_found'
    when pl.ends_at <= now() then 'poll_closed'
    when not exists (
      select 1 from public.post_poll_options o where o.id = p_option_id and o.post_id = p_post_id
    ) then 'invalid_option'
    when exists (
      select 1 from public.post_poll_votes v where v.post_id = p_post_id and v.user_id = auth.uid()
    ) then 'already_voted'
    else 'ok'
  end
  from (select 1) s
  left join public.post_polls pl on pl.post_id = p_post_id;
$$;

drop policy if exists post_poll_votes_insert on public.post_poll_votes;
create policy post_poll_votes_insert on public.post_poll_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.posts p
      where p.id = post_poll_votes.post_id and p.author_id <> (select auth.uid())
    )
    and private.poll_vote_state(post_id, option_id) = 'ok'
  );

create or replace function private.poll_votes_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.post_poll_options set votes_count = votes_count + 1 where id = new.option_id;
    update public.post_polls set voters_count = voters_count + 1 where post_id = new.post_id;
  else
    update public.post_poll_options set votes_count = greatest(votes_count - 1, 0) where id = old.option_id;
    update public.post_polls set voters_count = greatest(voters_count - 1, 0) where post_id = old.post_id;
  end if;
  return null;
end;
$$;

create or replace trigger post_poll_votes_10_rate_limit
  before insert on public.post_poll_votes
  for each row execute function private.enforce_rate_limit('poll_vote', 'user_id');
create or replace trigger post_poll_votes_counter
  after insert or delete on public.post_poll_votes
  for each row execute function private.poll_votes_counter();

create or replace function private.poll_view(p_post_id uuid, p_author_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ends_at', pl.ends_at,
    'closed', pl.ends_at <= now(),
    'total_votes', pl.voters_count,
    'my_option_id', v.option_id,
    'results_visible', s.visible,
    'options', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'label', o.label,
          'votes', case when s.visible then o.votes_count end
        ) order by o.position)
      from public.post_poll_options o
      where o.post_id = pl.post_id
    ), '[]'::jsonb)
  )
  from public.post_polls pl
  left join public.post_poll_votes v on v.post_id = pl.post_id and v.user_id = auth.uid()
  cross join lateral (
    select v.option_id is not null or pl.ends_at <= now() or p_author_id = auth.uid() as visible
  ) s
  where pl.post_id = p_post_id;
$$;

create or replace function private.validate_poll(p_poll jsonb, p_attachments jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_options  jsonb := p_poll -> 'options';
  v_labels   text[];
  v_duration integer;
begin
  if jsonb_typeof(p_poll) is distinct from 'object' or jsonb_typeof(v_options) is distinct from 'array' then
    perform private.api_error(400, 'invalid_poll', 'Format polling tidak valid');
  end if;
  if jsonb_array_length(coalesce(p_attachments, '[]'::jsonb)) > 0 then
    perform private.api_error(422, 'poll_with_attachments', 'Polling tidak bisa digabung dengan lampiran');
  end if;
  if jsonb_array_length(v_options) not between 2 and 4 then
    perform private.api_error(422, 'invalid_poll_options', 'Polling harus punya 2 sampai 4 pilihan');
  end if;
  if exists (select 1 from jsonb_array_elements(v_options) e where jsonb_typeof(e) <> 'string') then
    perform private.api_error(400, 'invalid_poll', 'Format polling tidak valid');
  end if;

  select array_agg(btrim(value)) into v_labels from jsonb_array_elements_text(v_options);
  if exists (select 1 from unnest(v_labels) l where char_length(l) not between 1 and 40) then
    perform private.api_error(422, 'invalid_poll_option', 'Setiap pilihan polling berisi 1 sampai 40 karakter');
  end if;
  if (select count(distinct lower(l)) from unnest(v_labels) l) <> cardinality(v_labels) then
    perform private.api_error(422, 'duplicate_poll_option', 'Pilihan polling tidak boleh sama');
  end if;

  if p_poll ? 'duration_minutes' and jsonb_typeof(p_poll -> 'duration_minutes') is distinct from 'number' then
    perform private.api_error(400, 'invalid_poll', 'Durasi polling tidak valid');
  end if;
  v_duration := coalesce((p_poll ->> 'duration_minutes')::numeric, 1440)::integer;
  if v_duration not between 5 and 10080 then
    perform private.api_error(422, 'invalid_poll_duration', 'Durasi polling 5 menit sampai 7 hari');
  end if;
end;
$$;

create or replace function private.create_poll(p_post_id uuid, p_poll jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  if not exists (select 1 from public.posts p where p.id = p_post_id and p.author_id = auth.uid()) then
    perform private.api_error(403, 'forbidden');
  end if;

  insert into public.post_polls (post_id, ends_at)
  values (
    p_post_id,
    now() + make_interval(mins => coalesce((p_poll ->> 'duration_minutes')::numeric, 1440)::integer)
  );

  for r in
    select e.value, e.ordinality
    from jsonb_array_elements_text(p_poll -> 'options') with ordinality as e(value, ordinality)
    order by e.ordinality
  loop
    perform private.validate_text(r.value, 'poll_option');
    insert into public.post_poll_options (post_id, position, label)
    values (p_post_id, r.ordinality - 1, private.apply_content_policy(btrim(r.value)));
  end loop;
end;
$$;

alter type public.feed_post add attribute poll jsonb;

create or replace function private.feed_posts(p_ids uuid[])
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.author_id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         p.body, p.sentiment, p.attachments, p.like_count, p.comment_count,
         coalesce((select array_agg(ps.stock_code order by ps.stock_code)
                   from public.post_stocks ps where ps.post_id = p.id), '{}'),
         exists (select 1 from public.reactions r
                 where r.user_id = auth.uid() and r.target_type = 'post' and r.target_id = p.id),
         p.edited_at, p.created_at,
         private.make_cursor(p.created_at, p.id),
         private.poll_view(p.id, p.author_id)
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  order by u.ord;
$$;

drop function if exists public.create_post(text, text, jsonb, uuid);
create function public.create_post(
  p_body        text,
  p_sentiment   text default null,
  p_attachments jsonb default '[]'::jsonb,
  p_client_id   uuid default null,
  p_poll        jsonb default null
)
returns setof public.feed_post
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_poll is not null then
    perform private.validate_poll(p_poll, p_attachments);
  end if;

  insert into public.posts (author_id, body, sentiment, attachments, client_id)
  values (auth.uid(), coalesce(p_body, ''), p_sentiment, coalesce(p_attachments, '[]'::jsonb), p_client_id)
  on conflict (author_id, client_id) where client_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.posts where author_id = auth.uid() and client_id = p_client_id;
  elsif p_poll is not null then
    perform private.create_poll(v_id, p_poll);
  end if;

  return query select * from private.feed_posts(array[v_id]);
end;
$$;

create or replace function public.vote_poll(p_post_id uuid, p_option_id uuid)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_author uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  select p.author_id into v_author from public.posts p where p.id = p_post_id;
  if not found then
    perform private.api_error(404, 'poll_not_found', 'Polling tidak ditemukan');
  end if;
  if v_author = auth.uid() then
    perform private.api_error(403, 'own_poll', 'Anda tidak bisa memilih di polling sendiri');
  end if;

  case private.poll_vote_state(p_post_id, p_option_id)
    when 'poll_not_found' then
      perform private.api_error(404, 'poll_not_found', 'Polling tidak ditemukan');
    when 'poll_closed' then
      perform private.api_error(422, 'poll_closed', 'Polling sudah berakhir');
    when 'invalid_option' then
      perform private.api_error(422, 'invalid_poll_option', 'Pilihan polling tidak valid');
    when 'already_voted' then
      perform private.api_error(409, 'already_voted', 'Anda sudah memilih di polling ini');
    else
      null;
  end case;

  begin
    insert into public.post_poll_votes (post_id, user_id, option_id)
    values (p_post_id, auth.uid(), p_option_id);
  exception when unique_violation then
    perform private.api_error(409, 'already_voted', 'Anda sudah memilih di polling ini');
  end;

  return private.poll_view(p_post_id, v_author);
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
        'kind', d.kind, 'version', d.version, 'accepted_at', c.accepted_at))
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb)
  );
end;
$$;

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
grant execute on function private.poll_view(uuid, uuid) to authenticated;
grant execute on function private.poll_vote_state(uuid, uuid) to authenticated;
grant execute on function private.validate_poll(jsonb, jsonb) to authenticated;
grant execute on function private.create_poll(uuid, jsonb) to authenticated;
grant execute on function public.create_post(text, text, jsonb, uuid, jsonb) to authenticated;
grant execute on function public.vote_poll(uuid, uuid) to authenticated;
grant execute on function public.export_my_data() to authenticated;
