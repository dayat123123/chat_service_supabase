create index if not exists follows_follower_created_idx on public.follows (follower_id, created_at desc);

create function public.get_follow_list(p_user_id uuid, p_kind text, p_cursor text default null,
                                       p_limit integer default 30)
returns table (
  id           uuid,
  username     text,
  display_name text,
  avatar_url   text,
  is_verified  boolean,
  is_official  boolean,
  is_me        boolean,
  is_following boolean,
  follows_me   boolean,
  followed_at  timestamptz,
  cursor       text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 50);
  v_ts    timestamptz;
  v_id    uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if coalesce(p_kind, '') not in ('followers', 'following') then
    perform private.api_error(400, 'invalid_kind', 'Jenis daftar harus followers atau following');
  end if;
  if p_user_id is null
     or not exists (select 1 from public.profiles t
                    where t.id = p_user_id and t.deleted_at is null and not t.is_guest)
     or private.is_blocked_pair(v_uid, p_user_id) then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  return query
  with edges as (
    select f.follower_id as profile_id, f.created_at as at
    from public.follows f
    where p_kind = 'followers' and f.following_id = p_user_id
    union all
    select f.following_id, f.created_at
    from public.follows f
    where p_kind = 'following' and f.follower_id = p_user_id
  )
  select pr.id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         private.is_official_account(pr.id),
         pr.id = v_uid,
         exists (select 1 from public.follows x where x.follower_id = v_uid and x.following_id = pr.id),
         exists (select 1 from public.follows x where x.follower_id = pr.id and x.following_id = v_uid),
         e.at,
         private.make_cursor(e.at, pr.id)
  from edges e
  join public.profiles pr on pr.id = e.profile_id
  where pr.deleted_at is null
    and not pr.is_guest
    and not cs.is_staff(pr.id)
    and not private.is_banned(pr.id)
    and not private.is_blocked_pair(v_uid, pr.id)
    and (v_ts is null or (e.at, pr.id) < (v_ts, v_id))
  order by e.at desc, pr.id desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_follow_list(uuid, text, text, integer) from public, anon;
grant execute on function public.get_follow_list(uuid, text, text, integer) to authenticated;
