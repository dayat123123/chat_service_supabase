create table private.post_share_daily (
  post_id   uuid not null references public.posts(id) on delete cascade,
  day       date not null,
  views     integer not null default 0,
  previews  integer not null default 0,
  opens     integer not null default 0,
  app_opens integer not null default 0,
  android   integer not null default 0,
  ios       integer not null default 0,
  windows   integer not null default 0,
  mac       integer not null default 0,
  primary key (post_id, day)
);
create index post_share_daily_day_idx on private.post_share_daily (day);
alter table private.post_share_daily enable row level security;
revoke all on private.post_share_daily from public, anon, authenticated;

create or replace function private.share_stats_day()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Jakarta')::date;
$$;

create or replace function private.share_stat_value(p_value integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_value, 0), 0), 1000000);
$$;

create or replace function public.share_link_record_stats(p_rows jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) > 5000 then
    perform private.api_error(400, 'invalid_share_stats', 'Share stats must be an array of at most 5000 rows');
  end if;
  if exists (select 1 from jsonb_array_elements(p_rows) r where jsonb_typeof(r) <> 'object') then
    perform private.api_error(400, 'invalid_share_stats', 'Every share stats row must be an object');
  end if;

  insert into private.post_share_daily as d (post_id, day, views, previews, opens, android, ios, windows, mac)
  select c.post_id, private.share_stats_day(),
         sum(private.share_stat_value(r.views)), sum(private.share_stat_value(r.previews)),
         sum(private.share_stat_value(r.opens)), sum(private.share_stat_value(r.android)),
         sum(private.share_stat_value(r.ios)), sum(private.share_stat_value(r.windows)),
         sum(private.share_stat_value(r.mac))
  from jsonb_to_recordset(p_rows) as r(code text, views integer, previews integer, opens integer,
                                       android integer, ios integer, windows integer, mac integer)
  join private.post_share_codes c on c.code = r.code
  group by c.post_id
  on conflict (post_id, day) do update
    set views    = least(d.views + excluded.views, 2000000000),
        previews = least(d.previews + excluded.previews, 2000000000),
        opens    = least(d.opens + excluded.opens, 2000000000),
        android  = least(d.android + excluded.android, 2000000000),
        ios      = least(d.ios + excluded.ios, 2000000000),
        windows  = least(d.windows + excluded.windows, 2000000000),
        mac      = least(d.mac + excluded.mac, 2000000000);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.resolve_post_share(p_code text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_post uuid;
begin
  if auth.uid() is null or p_code is null or p_code !~ '^[A-Za-z0-9]{10}$' then
    return null;
  end if;
  select c.post_id into v_post
  from private.post_share_codes c
  where c.code = p_code
    and private.post_shareable(c.post_id);
  if v_post is not null then
    insert into private.post_share_daily as d (post_id, day, app_opens)
    values (v_post, private.share_stats_day(), 1)
    on conflict (post_id, day) do update set app_opens = least(d.app_opens + 1, 2000000000);
  end if;
  return v_post;
end;
$$;

create or replace function cs_api.share_link_stats(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_today date := private.share_stats_day();
  v_from  date;
begin
  if p_days is null or p_days not in (7, 30, 90) then
    perform private.api_error(400, 'invalid_share_stats_days', 'Rentang statistik harus 7, 30, atau 90 hari');
  end if;
  v_from := v_today - (p_days - 1);

  return (
    with rows as (
      select d.* from private.post_share_daily d where d.day between v_from and v_today
    ),
    per_post as (
      select r.post_id, sum(r.views)::bigint as views, sum(r.previews)::bigint as previews,
             sum(r.opens)::bigint as opens, sum(r.app_opens)::bigint as app_opens,
             sum(r.android)::bigint as android, sum(r.ios)::bigint as ios,
             sum(r.windows)::bigint as windows, sum(r.mac)::bigint as mac
      from rows r
      group by r.post_id
    )
    select jsonb_build_object(
      'days', p_days,
      'from', v_from,
      'to', v_today,
      'totals', (
        select jsonb_build_object(
          'views', coalesce(sum(r.views), 0), 'previews', coalesce(sum(r.previews), 0),
          'opens', coalesce(sum(r.opens), 0), 'app_opens', coalesce(sum(r.app_opens), 0),
          'android', coalesce(sum(r.android), 0), 'ios', coalesce(sum(r.ios), 0),
          'windows', coalesce(sum(r.windows), 0), 'mac', coalesce(sum(r.mac), 0),
          'posts', count(distinct r.post_id))
        from rows r),
      'daily', (
        select jsonb_agg(jsonb_build_object(
                 'day', g.day::date,
                 'views', coalesce(x.views, 0), 'opens', coalesce(x.opens, 0),
                 'app_opens', coalesce(x.app_opens, 0), 'downloads', coalesce(x.downloads, 0))
               order by g.day)
        from generate_series(v_from, v_today, interval '1 day') g(day)
        left join (
          select r.day, sum(r.views) as views, sum(r.opens) as opens, sum(r.app_opens) as app_opens,
                 sum(r.android + r.ios + r.windows + r.mac) as downloads
          from rows r group by r.day) x on x.day = g.day::date),
      'top', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'code', c.code,
                 'post_id', p.post_id,
                 'author_username', pr.username::text,
                 'author_name', coalesce(nullif(btrim(pr.display_name), ''), pr.username::text),
                 'body', left(regexp_replace(btrim(po.body), '\s+', ' ', 'g'), 120),
                 'available', private.post_shareable(p.post_id),
                 'views', p.views, 'previews', p.previews, 'opens', p.opens, 'app_opens', p.app_opens,
                 'downloads', p.android + p.ios + p.windows + p.mac)
               order by p.views + p.app_opens desc, p.opens desc, p.post_id)
        from (select * from per_post order by views + app_opens desc, opens desc, post_id limit 10) p
        join public.posts po on po.id = p.post_id
        join public.profiles pr on pr.id = po.author_id
        left join private.post_share_codes c on c.post_id = p.post_id), '[]'::jsonb))
  );
end;
$$;

select cron.schedule('share-stats-purge', '17 3 * * *',
  $$delete from private.post_share_daily where day < (now() at time zone 'Asia/Jakarta')::date - 400$$);

revoke execute on function private.share_stats_day() from public;
revoke execute on function private.share_stat_value(integer) from public;
revoke execute on function public.share_link_record_stats(jsonb) from public, anon, authenticated;
revoke execute on function public.resolve_post_share(text) from public, anon;
revoke execute on function cs_api.share_link_stats(integer) from public;

grant execute on function public.share_link_record_stats(jsonb) to service_role;
grant execute on function public.resolve_post_share(text) to authenticated;
grant execute on function cs_api.share_link_stats(integer) to authenticated;
