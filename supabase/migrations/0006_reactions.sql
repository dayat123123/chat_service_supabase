-- 0006_reactions.sql
-- Reaksi (like, bisa dikembangkan) pada post & komentar. Unik per user per target.

create table if not exists public.reactions (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id   uuid not null,
  type        text not null default 'like',
  created_at  timestamptz not null default now(),
  primary key (user_id, target_type, target_id),
  constraint reactions_target_type check (target_type in ('post', 'comment')),
  -- Tambah jenis reaksi baru dengan mengubah constraint ini.
  constraint reactions_type check (type in ('like'))
);
create index if not exists reactions_target_idx on public.reactions (target_type, target_id);
create index if not exists reactions_user_created_idx on public.reactions (user_id, created_at desc);

-- Target harus ada, belum dihapus, dan tidak saling blokir dengan pemiliknya.
create or replace function private.reactions_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author  uuid;
  v_deleted timestamptz;
begin
  if new.target_type = 'post' then
    select author_id, deleted_at into v_author, v_deleted from public.posts where id = new.target_id;
  else
    select author_id, deleted_at into v_author, v_deleted from public.comments where id = new.target_id;
  end if;

  if v_author is null or v_deleted is not null then
    perform private.api_error(404, 'target_not_found', 'Konten tidak ditemukan');
  end if;
  if private.is_blocked_pair(new.user_id, v_author) then
    perform private.api_error(403, 'blocked', 'Tidak bisa memberi reaksi pada konten ini');
  end if;
  return new;
end;
$$;

create or replace function private.bump_like_count(p_target_type text, p_target_id uuid, p_delta integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_target_type = 'post' then
    update public.posts set like_count = greatest(like_count + p_delta, 0) where id = p_target_id;
  else
    update public.comments set like_count = greatest(like_count + p_delta, 0) where id = p_target_id;
  end if;
end;
$$;

create or replace function private.reactions_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.type = 'like' then
      perform private.bump_like_count(new.target_type, new.target_id, 1);
    end if;
  elsif tg_op = 'DELETE' then
    if old.type = 'like' then
      perform private.bump_like_count(old.target_type, old.target_id, -1);
    end if;
  elsif tg_op = 'UPDATE' and new.type is distinct from old.type then
    if old.type = 'like' then
      perform private.bump_like_count(old.target_type, old.target_id, -1);
    end if;
    if new.type = 'like' then
      perform private.bump_like_count(new.target_type, new.target_id, 1);
    end if;
  end if;
  return null;
end;
$$;

-- Notifikasi like, digabung per target selama belum dibaca.
create or replace function private.notify_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author  uuid;
  v_post_id uuid;
  v_body    text;
begin
  if new.target_type = 'post' then
    select author_id, id, body into v_author, v_post_id, v_body from public.posts where id = new.target_id;
  else
    select author_id, post_id, body into v_author, v_post_id, v_body from public.comments where id = new.target_id;
  end if;

  perform private.notify(
    v_author, new.user_id, 'like',
    jsonb_build_object(
      'target_type', new.target_type,
      'target_id', new.target_id,
      'post_id', v_post_id,
      'reaction', new.type,
      'snippet', private.snippet(v_body)
    ),
    'like:' || new.target_type || ':' || new.target_id
  );
  return null;
end;
$$;

-- Hard delete post/komentar (mis. cascade) ikut membersihkan reaksinya.
create or replace function private.cleanup_reactions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.reactions where target_type = tg_argv[0] and target_id = old.id;
  return null;
end;
$$;

create or replace trigger reactions_10_rate_limit
  before insert on public.reactions
  for each row execute function private.enforce_rate_limit('reaction', 'user_id');
create or replace trigger reactions_20_before_insert
  before insert on public.reactions
  for each row execute function private.reactions_before_insert();
create or replace trigger reactions_counter
  after insert or update of type or delete on public.reactions
  for each row execute function private.reactions_counter();
create or replace trigger reactions_notify
  after insert on public.reactions
  for each row execute function private.notify_reaction();
create or replace trigger posts_cleanup_reactions
  after delete on public.posts
  for each row execute function private.cleanup_reactions('post');
create or replace trigger comments_cleanup_reactions
  after delete on public.comments
  for each row execute function private.cleanup_reactions('comment');

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.reactions enable row level security;
revoke all on public.reactions from anon, authenticated;
grant select, delete on public.reactions to authenticated;
grant insert (user_id, target_type, target_id, type) on public.reactions to authenticated;
grant update (type) on public.reactions to authenticated;

drop policy if exists reactions_select on public.reactions;
create policy reactions_select on public.reactions
  for select to authenticated using (true);
drop policy if exists reactions_insert_own on public.reactions;
create policy reactions_insert_own on public.reactions
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists reactions_update_own on public.reactions;
create policy reactions_update_own on public.reactions
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
drop policy if exists reactions_delete_own on public.reactions;
create policy reactions_delete_own on public.reactions
  for delete to authenticated using (user_id = (select auth.uid()));

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
