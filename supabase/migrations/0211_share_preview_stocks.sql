create or replace function public.share_post_preview(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config jsonb := private.share_links_config();
  v_post   uuid;
  v_row    record;
  v_image  jsonb;
  v_avatar text;
begin
  if not private.share_links_ready() then
    return jsonb_build_object('status', 'disabled');
  end if;
  if p_code is null or p_code !~ '^[A-Za-z0-9]{10}$' then
    return jsonb_build_object('status', 'not_found');
  end if;
  select c.post_id into v_post from private.post_share_codes c where c.code = p_code;
  if v_post is null then
    return jsonb_build_object('status', 'not_found');
  end if;
  if not private.post_shareable(v_post) then
    return jsonb_build_object('status', 'unavailable', 'code', p_code);
  end if;
  if (v_config ->> 'preview')::boolean is not true then
    return jsonb_build_object('status', 'ok', 'code', p_code, 'preview', false);
  end if;

  select p.body, p.created_at, p.attachments, p.like_count, p.comment_count,
         pr.username::text as username, pr.display_name, pr.avatar_url, pr.is_verified,
         private.is_official_account(pr.id) as official
    into v_row
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  where p.id = v_post;

  select a into v_image
  from jsonb_array_elements(case when jsonb_typeof(v_row.attachments) = 'array' then v_row.attachments else '[]' end) a
  where a ->> 'mime' like 'image/%'
    and coalesce(a ->> 'path', '') ~ '^posts/[0-9a-f-]{36}/[A-Za-z0-9._-]{1,120}$'
  limit 1;

  v_avatar := substring(coalesce(v_row.avatar_url, '') from '/storage/v1/object/public/avatars/([A-Za-z0-9._/-]{1,200})$');
  if v_avatar like '%..%' then
    v_avatar := null;
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'code', p_code,
    'preview', true,
    'author', jsonb_build_object(
      'username', v_row.username,
      'display_name', coalesce(nullif(btrim(v_row.display_name), ''), v_row.username),
      'verified', v_row.is_verified,
      'official', v_row.official,
      'avatar_path', v_avatar),
    'body', left(regexp_replace(btrim(v_row.body), '\s+', ' ', 'g'), 300),
    'truncated', char_length(regexp_replace(btrim(v_row.body), '\s+', ' ', 'g')) > 300,
    'created_at', v_row.created_at,
    'like_count', v_row.like_count,
    'comment_count', v_row.comment_count,
    'image', case when v_image is not null then jsonb_build_object(
      'path', v_image ->> 'path',
      'width', case when jsonb_typeof(v_image -> 'width') = 'number' then v_image -> 'width' end,
      'height', case when jsonb_typeof(v_image -> 'height') = 'number' then v_image -> 'height' end) end,
    'stocks', coalesce((
      select jsonb_agg(jsonb_build_object('code', c.code, 'name', mi.name) order by c.n)
      from unnest((private.extract_cashtags(v_row.body))[1:3]) with ordinality c(code, n)
      left join private.market_instrument_aliases al on al.alias = c.code
      left join private.market_instruments mi on mi.code = coalesce(al.code, c.code) and mi.enabled), '[]'::jsonb));
end;
$$;
