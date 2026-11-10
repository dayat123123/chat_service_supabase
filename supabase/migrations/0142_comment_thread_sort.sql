drop function if exists public.get_comment_thread(uuid, uuid, integer, text, integer, integer, boolean);

create function public.get_comment_thread(
  p_post_id         uuid,
  p_root_comment_id uuid default null,
  p_max_depth       integer default 3,
  p_cursor          text default null,
  p_limit           integer default 20,
  p_replies_limit   integer default 3,
  p_include_root    boolean default false,
  p_sort            text default 'oldest'
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
     and not exists (select 1 from public.comments where id = p_root_comment_id and post_id = p_post_id) then
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
      where c.parent_id = t.id
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

revoke execute on function public.get_comment_thread(uuid, uuid, integer, text, integer, integer, boolean, text) from public, anon;
grant execute on function public.get_comment_thread(uuid, uuid, integer, text, integer, integer, boolean, text) to authenticated;
