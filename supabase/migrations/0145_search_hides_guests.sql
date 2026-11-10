create or replace function private.search_users(p_uid uuid, p_query text, p_offset integer, p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term  text := ltrim(btrim(p_query), '@');
  v_like  text := replace(replace(replace(ltrim(btrim(p_query), '@'), '\', '\\'), '%', '\%'), '_', '\_');
  v_typo  boolean := char_length(ltrim(btrim(p_query), '@')) >= private.setting_num('search.typo_min_length', 4);
  v_rows  jsonb;
begin
  select coalesce(jsonb_agg(r.item order by r.n), '[]') into v_rows
  from (
    select jsonb_build_object(
             'id', p.id, 'username', p.username::text, 'display_name', p.display_name,
             'avatar_url', p.avatar_url, 'is_verified', p.is_verified, 'follower_count', p.follower_count,
             'is_official', exists (select 1 from cs.official_accounts o
                                    where o.profile_id = p.id and o.disabled_at is null),
             'is_following', exists (select 1 from public.follows f
                                     where f.follower_id = p_uid and f.following_id = p.id),
             'is_me', p.id = p_uid) as item,
           row_number() over (
             order by (lower(p.username::text) = lower(v_term)) desc,
                      (p.username::text ilike v_like || '%') desc,
                      extensions.similarity(p.username::text, v_term) desc,
                      p.follower_count desc, p.username) as n
    from public.profiles p
    where p.deleted_at is null
      and p.olt_user_id not like 'cs-staff:%'
      and not p.is_guest
      and (p.username::text ilike v_like || '%'
           or p.display_name ilike '%' || v_like || '%'
           or (v_typo and p.username::text operator(extensions.%) v_term))
      and p.id not in (select private.blocked_user_ids())
      and not exists (
        select 1 from private.user_sanctions s
        where s.user_id = p.id and s.kind = 'ban' and s.revoked_at is null
          and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()))
    order by n
    offset p_offset
    limit p_limit + 1
  ) r;

  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(e.value order by e.ordinality)
                       from jsonb_array_elements(v_rows) with ordinality e
                       where e.ordinality <= p_limit), '[]'),
    'next_cursor', case when jsonb_array_length(v_rows) > p_limit then 'o:' || (p_offset + p_limit) end);
end;
$$;

revoke execute on function private.search_users(uuid, text, integer, integer) from public, anon;
