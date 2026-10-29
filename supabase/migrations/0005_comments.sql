-- 0005_comments.sql
-- Komentar berantai tanpa batas kedalaman (materialized path ltree).
--
-- path  : label per level = seq 12 digit (zero-padded), mis. 000000000012.000000000047
--         sehingga ORDER BY path = urutan pohon, saudara urut kronologis.
-- depth : 0 untuk komentar langsung di post.
-- reply_count  : jumlah balasan langsung (termasuk yang dihapus, karena tetap tampil
--                sebagai "[komentar dihapus]").
-- comment_count (posts): jumlah komentar yang belum dihapus.

create table if not exists public.comments (
  id          uuid primary key default gen_random_uuid(),
  seq         bigint generated always as identity,
  post_id     uuid not null references public.posts(id) on delete cascade,
  parent_id   uuid references public.comments(id) on delete cascade,
  author_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null,
  path        extensions.ltree not null,
  depth       integer not null check (depth >= 0),
  like_count  integer not null default 0 check (like_count >= 0),
  reply_count integer not null default 0 check (reply_count >= 0),
  edited_at   timestamptz,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint comments_seq_key unique (seq),
  constraint comments_body_length check (
    deleted_at is not null or (char_length(body) between 1 and 1000)
  )
);
create index if not exists comments_path_gist_idx on public.comments using gist (path);
create index if not exists comments_post_path_idx on public.comments (post_id, path);
create index if not exists comments_toplevel_idx on public.comments (post_id, seq) where parent_id is null;
create index if not exists comments_parent_idx on public.comments (parent_id, seq);
create index if not exists comments_author_created_idx on public.comments (author_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Trigger
-- ---------------------------------------------------------------------------

-- Validasi + isi path/depth. security definer: membaca post/parent apa adanya.
create or replace function private.comments_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_post   public.posts;
  v_parent public.comments;
  v_label  text;
begin
  new.body := regexp_replace(new.body, '^\s+|\s+$', '', 'g');

  select * into v_post from public.posts where id = new.post_id;
  if not found or v_post.deleted_at is not null then
    perform private.api_error(404, 'post_not_found', 'Post tidak ditemukan');
  end if;
  if private.is_blocked_pair(new.author_id, v_post.author_id) then
    perform private.api_error(403, 'blocked', 'Tidak bisa berkomentar di post ini');
  end if;

  v_label := lpad(new.seq::text, 12, '0');
  if new.parent_id is null then
    new.path := text2ltree(v_label);
    new.depth := 0;
  else
    select * into v_parent from public.comments where id = new.parent_id;
    if not found or v_parent.post_id <> new.post_id then
      perform private.api_error(400, 'invalid_parent', 'Komentar induk tidak valid');
    end if;
    if v_parent.deleted_at is not null then
      perform private.api_error(409, 'parent_deleted', 'Komentar yang dibalas sudah dihapus');
    end if;
    if private.is_blocked_pair(new.author_id, v_parent.author_id) then
      perform private.api_error(403, 'blocked', 'Tidak bisa membalas komentar ini');
    end if;
    new.path := v_parent.path || text2ltree(v_label);
    new.depth := v_parent.depth + 1;
  end if;
  return new;
end;
$$;

create or replace function private.comments_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  if new.deleted_at is null and new.body is distinct from old.body then
    new.body := regexp_replace(new.body, '^\s+|\s+$', '', 'g');
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create or replace function private.comments_counters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.deleted_at is null then
      update public.posts set comment_count = comment_count + 1 where id = new.post_id;
    end if;
    if new.parent_id is not null then
      update public.comments set reply_count = reply_count + 1 where id = new.parent_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.deleted_at is null and new.deleted_at is not null then
      update public.posts set comment_count = greatest(comment_count - 1, 0) where id = new.post_id;
    elsif old.deleted_at is not null and new.deleted_at is null then
      update public.posts set comment_count = comment_count + 1 where id = new.post_id;
    end if;
  elsif tg_op = 'DELETE' then
    if old.deleted_at is null then
      update public.posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
    end if;
    if old.parent_id is not null then
      update public.comments set reply_count = greatest(reply_count - 1, 0) where id = old.parent_id;
    end if;
  end if;
  return null;
end;
$$;

-- Notifikasi: balasan langsung -> penulis komentar induk; komentar baru -> penulis
-- post (digabung per post); @mention di komentar -> user yang disebut.
create or replace function private.notify_comment()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_post_author   uuid;
  v_parent_author uuid;
  v_payload       jsonb;
  v_user          uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  v_payload := jsonb_build_object(
    'post_id', new.post_id,
    'comment_id', new.id,
    'parent_id', new.parent_id,
    'snippet', private.snippet(new.body)
  );

  if new.parent_id is not null then
    select author_id into v_parent_author from public.comments where id = new.parent_id;
    perform private.notify(v_parent_author, new.author_id, 'reply', v_payload);
  end if;

  if v_post_author is distinct from v_parent_author then
    perform private.notify(v_post_author, new.author_id, 'reply', v_payload,
                           'comments:post:' || new.post_id);
  end if;

  for v_user in
    select p.id from public.profiles p
    where p.username = any(((private.extract_mentions(new.body))[1:10])::extensions.citext[])
  loop
    if v_user is distinct from v_parent_author and v_user is distinct from v_post_author then
      perform private.notify(v_user, new.author_id, 'mention', v_payload);
    end if;
  end loop;

  return null;
end;
$$;

create or replace trigger comments_10_rate_limit
  before insert on public.comments
  for each row execute function private.enforce_rate_limit('comment', 'author_id');
create or replace trigger comments_20_before_insert
  before insert on public.comments
  for each row execute function private.comments_before_insert();
create or replace trigger comments_20_before_update
  before update on public.comments
  for each row execute function private.comments_before_update();
create or replace trigger comments_30_content_policy
  before insert or update of body on public.comments
  for each row execute function private.enforce_content_policy();
create or replace trigger comments_counters
  after insert or update of deleted_at or delete on public.comments
  for each row execute function private.comments_counters();
create or replace trigger comments_notify
  after insert on public.comments
  for each row execute function private.notify_comment();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.comments enable row level security;
revoke all on public.comments from anon, authenticated;
grant select on public.comments to authenticated;
grant insert (id, post_id, parent_id, author_id, body) on public.comments to authenticated;
grant update (body) on public.comments to authenticated;

-- Komentar terhapus tetap terlihat (body kosong) agar struktur thread utuh.
drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments
  for select to authenticated
  using (author_id not in (select private.blocked_user_ids()));
drop policy if exists comments_insert_own on public.comments;
create policy comments_insert_own on public.comments
  for insert to authenticated
  with check (author_id = (select auth.uid()));
drop policy if exists comments_update_own on public.comments;
create policy comments_update_own on public.comments
  for update to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null)
  with check (author_id = (select auth.uid()) and deleted_at is null);

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Soft delete komentar milik sendiri; isi asli diarsipkan.
create or replace function public.delete_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_comment public.comments;
begin
  select * into v_comment from public.comments
  where id = p_comment_id and deleted_at is null
  for update;
  if not found then
    perform private.api_error(404, 'not_found', 'Komentar tidak ditemukan');
  end if;
  if v_comment.author_id is distinct from auth.uid() and coalesce(auth.role(), '') <> 'service_role' then
    perform private.api_error(403, 'forbidden', 'Hanya pemilik yang bisa menghapus komentar ini');
  end if;

  insert into private.content_archive (target_type, target_id, author_id, body, deleted_by)
  values ('comment', v_comment.id, v_comment.author_id, v_comment.body, auth.uid());

  update public.comments set deleted_at = now(), body = '' where id = p_comment_id;
end;
$$;

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.delete_comment(uuid) to authenticated;
