create or replace function private.comment_lift_replies(p_comment_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_comment public.comments;
  v_base    extensions.ltree := ''::extensions.ltree;
  v_moved   integer;
begin
  select * into v_comment from public.comments c where c.id = p_comment_id;
  if not found then
    return 0;
  end if;
  if v_comment.parent_id is not null then
    select c.path into v_base from public.comments c where c.id = v_comment.parent_id;
  end if;

  select count(*)::integer into v_moved
  from public.comments c
  where c.parent_id = v_comment.id and c.deleted_at is null;

  update public.comments c
     set parent_id = case when c.parent_id = v_comment.id then v_comment.parent_id else c.parent_id end,
         path = v_base operator(extensions.||) extensions.subpath(c.path, extensions.nlevel(v_comment.path)),
         depth = extensions.nlevel(v_base) + extensions.nlevel(c.path) - extensions.nlevel(v_comment.path) - 1
   where c.post_id = v_comment.post_id
     and c.path operator(extensions.<@) v_comment.path
     and c.id <> v_comment.id;

  update public.comments c set reply_count = 0 where c.id = v_comment.id and c.reply_count <> 0;
  if v_comment.parent_id is not null then
    update public.comments c
       set reply_count = greatest(c.reply_count - 1 + v_moved, 0)
     where c.id = v_comment.parent_id;
  end if;
  return v_moved;
end;
$$;

create or replace function private.comments_after_delete_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    perform private.comment_lift_replies(new.id);
  elsif old.deleted_at is not null and new.deleted_at is null and new.parent_id is not null then
    update public.comments c set reply_count = c.reply_count + 1 where c.id = new.parent_id;
  end if;
  return null;
end;
$$;

create trigger comments_35_lift_replies
  after update of deleted_at on public.comments
  for each row
  when (old.deleted_at is distinct from new.deleted_at)
  execute function private.comments_after_delete_state();

do $$
declare
  v_id uuid;
begin
  for v_id in
    select c.id from public.comments c
    where c.deleted_at is not null
      and exists (select 1 from public.comments ch where ch.parent_id = c.id)
    order by c.depth desc, c.seq desc
  loop
    perform private.comment_lift_replies(v_id);
  end loop;
end;
$$;

update public.comments c
   set reply_count = x.n
  from (select p.id, count(ch.id) filter (where ch.deleted_at is null)::integer as n
        from public.comments p
        left join public.comments ch on ch.parent_id = p.id
        group by p.id) x
 where x.id = c.id and c.reply_count <> x.n;

update public.posts p
   set comment_count = x.n
  from (select c.post_id, count(*) filter (where c.deleted_at is null)::integer as n
        from public.comments c group by c.post_id) x
 where x.post_id = p.id and p.comment_count <> x.n;

create or replace function private.thread_comments(p_ids uuid[])
returns setof public.thread_comment
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select c.id, c.post_id, c.parent_id,
         c.author_id,
         pr.username::text,
         pr.display_name,
         pr.avatar_url,
         pr.is_verified,
         c.body,
         false,
         c.depth, c.path::text, c.like_count, c.reply_count,
         exists (select 1 from public.reactions r
                 where r.user_id = auth.uid() and r.target_type = 'comment' and r.target_id = c.id),
         c.edited_at, c.created_at, c.seq::text,
         case when c.author_id = auth.uid() then c.moderation_status end
  from public.comments c
  join public.profiles pr on pr.id = c.author_id
  where c.id = any(p_ids)
    and c.deleted_at is null
  order by c.path;
$$;

create or replace function public.get_comment_thread(
  p_post_id uuid,
  p_root_comment_id uuid default null,
  p_max_depth integer default 3,
  p_cursor text default null,
  p_limit integer default 20,
  p_replies_limit integer default 3,
  p_include_root boolean default false,
  p_sort text default 'oldest'
)
returns setof public.thread_comment
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_max_depth integer := least(greatest(coalesce(p_max_depth, 3), 0), 20);
  v_limit     integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_replies   integer := least(greatest(coalesce(p_replies_limit, 3), 0), 50);
  v_sort      text := coalesce(nullif(p_sort, ''), 'oldest');
  v_cursor    bigint;
  v_page      uuid[];
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_sort not in ('oldest', 'latest', 'top') then
    perform private.api_error(400, 'invalid_sort', 'Urutan komentar tidak valid');
  end if;
  if not exists (select 1 from public.posts where id = p_post_id) then
    perform private.api_error(404, 'post_not_found', 'Post tidak ditemukan');
  end if;
  if p_cursor is not null and p_cursor <> '' then
    begin
      v_cursor := p_cursor::bigint;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_sort = 'top' and v_cursor < 0 then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  end if;
  if p_root_comment_id is not null
     and not exists (select 1 from public.comments
                     where id = p_root_comment_id and post_id = p_post_id and deleted_at is null) then
    perform private.api_error(404, 'comment_not_found', 'Komentar tidak ditemukan');
  end if;

  select array_agg(x.id order by x.ord) into v_page
  from (
    select c.id,
           row_number() over (
             order by
               case when v_sort = 'top' then c.like_count + c.reply_count end desc nulls last,
               case when v_sort = 'latest' then c.seq end desc nulls last,
               c.seq
           ) as ord
    from public.comments c
    where c.post_id = p_post_id
      and c.parent_id is not distinct from p_root_comment_id
      and c.deleted_at is null
      and (
        v_cursor is null
        or v_sort = 'top'
        or (v_sort = 'oldest' and c.seq > v_cursor)
        or (v_sort = 'latest' and c.seq < v_cursor)
      )
    order by ord
    offset case when v_sort = 'top' then coalesce(v_cursor, 0) else 0 end
    limit v_limit
  ) x;

  return query
  with recursive tree (id, rel_depth, top_id) as (
    select page_id, 0, page_id from unnest(coalesce(v_page, '{}')) as page_id
    union all
    select ch.id, t.rel_depth + 1, t.top_id
    from tree t
    cross join lateral (
      select c.id from public.comments c
      where c.parent_id = t.id and c.deleted_at is null
      order by c.seq
      limit v_replies
    ) ch
    where t.rel_depth < v_max_depth
  ),
  ranked as (
    select tree.id, p.ord
    from tree
    join unnest(coalesce(v_page, '{}')) with ordinality as p(id, ord) on p.id = tree.top_id
    union all
    select p_root_comment_id, 0
    where p_include_root and p_root_comment_id is not null and v_cursor is null
  )
  select tc.*
  from private.thread_comments(array(select id from ranked)) tc
  join ranked on ranked.id = tc.id
  order by case when v_sort = 'oldest' then 0 else ranked.ord end, tc.path;
end;
$$;

revoke execute on function private.comment_lift_replies(uuid) from public;
revoke execute on function private.comments_after_delete_state() from public;
