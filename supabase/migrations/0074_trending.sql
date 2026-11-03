insert into private.settings (key, value, description) values
  ('trending.manipulation_weight', '0.3',
   'Pengali skor trending untuk saham yang punya alert manipulasi terbuka dan post yang membahasnya (0-1)'),
  ('trending.rising_min_posts', '5', 'Saham masuk daftar "diskusi naik" bila minimal sekian post di jendela berjalan'),
  ('trending.post_gravity', '1.5', 'Laju peluruhan skor post populer terhadap umur (jam)'),
  ('trending.bucket_retention_days', '35', 'Agregat 5 menit disimpan selama sekian hari')
on conflict (key) do nothing;

create table private.stock_mention_buckets (
  stock_code text not null,
  bucket     timestamptz not null,
  posts      integer not null,
  authors    integer not null,
  weighted   numeric(12, 3) not null,
  bullish    integer not null default 0,
  bearish    integer not null default 0,
  neutral    integer not null default 0,
  w_bullish  numeric(12, 3) not null default 0,
  w_bearish  numeric(12, 3) not null default 0,
  w_neutral  numeric(12, 3) not null default 0,
  primary key (stock_code, bucket)
);
create index stock_mention_buckets_bucket_idx on private.stock_mention_buckets (bucket);
alter table private.stock_mention_buckets enable row level security;

create table private.trending_snapshot (
  window_key  text not null check (window_key in ('24h', '7d')),
  kind        text not null check (kind in ('stock', 'rising', 'post')),
  rank        integer not null,
  item_key    text not null,
  score       numeric not null,
  data        jsonb not null default '{}',
  computed_at timestamptz not null default now(),
  primary key (window_key, kind, rank)
);
alter table private.trending_snapshot enable row level security;

create table private.trending_state (
  singleton    boolean primary key default true check (singleton),
  refreshed_at timestamptz,
  computed_at  timestamptz,
  alert_codes  text[] not null default '{}'
);
alter table private.trending_state enable row level security;
insert into private.trending_state (singleton) values (true);

create or replace function private.manipulation_alert_codes()
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_codes text[];
begin
  if to_regclass('cs.manipulation_alerts') is null then
    return '{}';
  end if;
  begin
    execute 'select coalesce(array_agg(distinct upper(a.stock::text)), ''{}'') from cs.manipulation_alerts a
             where a.status = ''open'' and a.stock is not null'
      into v_codes;
  exception when undefined_column or undefined_table or invalid_text_representation then
    v_codes := '{}';
  end;
  return coalesce(v_codes, '{}');
end;
$$;

create or replace function private.trending_refresh(p_since timestamptz)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from  timestamptz := date_bin('5 minutes', coalesce(p_since, now() - interval '1 hour'),
                                  timestamptz '2000-01-01');
  v_count integer;
begin
  delete from private.stock_mention_buckets where bucket >= v_from;

  insert into private.stock_mention_buckets (stock_code, bucket, posts, authors, weighted, bullish, bearish, neutral,
                                             w_bullish, w_bearish, w_neutral)
  select a.stock_code, a.bucket, sum(a.posts)::integer, count(*)::integer, sum(a.weight),
         sum(a.bullish)::integer, sum(a.bearish)::integer, sum(a.neutral)::integer,
         sum(a.weight * a.bullish / a.posts), sum(a.weight * a.bearish / a.posts), sum(a.weight * a.neutral / a.posts)
  from (
    select ps.stock_code, date_bin('5 minutes', ps.post_created_at, timestamptz '2000-01-01') as bucket,
           p.author_id, count(*) as posts,
           count(*) filter (where p.sentiment = 'bullish') as bullish,
           count(*) filter (where p.sentiment = 'bearish') as bearish,
           count(*) filter (where p.sentiment = 'neutral') as neutral,
           max(private.author_weight(pr.created_at, pr.trust_level)) as weight
    from public.post_stocks ps
    join public.posts p on p.id = ps.post_id
    join public.profiles pr on pr.id = p.author_id
    where ps.post_created_at >= v_from
      and p.deleted_at is null
      and p.moderation_status = 'visible'
      and pr.deleted_at is null
    group by ps.stock_code, 2, p.author_id
  ) a
  group by a.stock_code, a.bucket;
  get diagnostics v_count = row_count;

  update private.trending_state set refreshed_at = now() where singleton;
  return v_count;
end;
$$;

create or replace function private.trending_compute()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alerts   text[] := private.manipulation_alert_codes();
  v_factor   numeric := least(greatest(private.setting_num('trending.manipulation_weight', 0.3), 0), 1);
  v_gravity  numeric := greatest(private.setting_num('trending.post_gravity', 1.5), 0.1);
  v_min      integer := private.setting_num('trending.rising_min_posts', 5)::integer;
  v_window   text;
  v_span     interval;
  v_now      timestamptz := now();
begin
  delete from private.trending_snapshot;

  foreach v_window in array array['24h', '7d'] loop
    v_span := case v_window when '24h' then interval '24 hours' else interval '7 days' end;

    insert into private.trending_snapshot (window_key, kind, rank, item_key, score, data, computed_at)
    select v_window, 'stock', row_number() over (order by s.score desc, s.posts desc, s.stock_code),
           s.stock_code, s.score,
           jsonb_build_object(
             'code', s.stock_code, 'posts', s.posts, 'score', round(s.score, 2),
             'bullish_pct', case when s.labeled > 0 then round(100 * s.w_bullish / s.labeled) end,
             'bearish_pct', case when s.labeled > 0 then round(100 * s.w_bearish / s.labeled) end,
             'neutral_pct', case when s.labeled > 0 then round(100 * s.w_neutral / s.labeled) end,
             'growth_pct', case when s.prev_score > 0 then round(100 * (s.score - s.prev_score) / s.prev_score) end),
           v_now
    from (
      select b.stock_code::text as stock_code,
             sum(b.posts) filter (where b.bucket >= v_now - v_span)::integer as posts,
             coalesce(sum(b.weighted) filter (where b.bucket >= v_now - v_span), 0)
               * case when b.stock_code = any (v_alerts) then v_factor else 1 end as score,
             coalesce(sum(b.weighted) filter (where b.bucket < v_now - v_span), 0)
               * case when b.stock_code = any (v_alerts) then v_factor else 1 end as prev_score,
             sum(b.w_bullish) filter (where b.bucket >= v_now - v_span) as w_bullish,
             sum(b.w_bearish) filter (where b.bucket >= v_now - v_span) as w_bearish,
             sum(b.w_neutral) filter (where b.bucket >= v_now - v_span) as w_neutral,
             sum(b.w_bullish + b.w_bearish + b.w_neutral) filter (where b.bucket >= v_now - v_span) as labeled
      from private.stock_mention_buckets b
      where b.bucket >= v_now - 2 * v_span
      group by b.stock_code
    ) s
    where s.posts > 0
    order by s.score desc, s.posts desc, s.stock_code
    limit 50;

    insert into private.trending_snapshot (window_key, kind, rank, item_key, score, data, computed_at)
    select v_window, 'rising', row_number() over (order by g.growth desc, g.posts desc, g.stock_code),
           g.stock_code, g.growth,
           jsonb_build_object('code', g.stock_code, 'posts', g.posts, 'prev_posts', g.prev_posts,
                              'growth_pct', round(100 * g.growth)),
           v_now
    from (
      select b.stock_code::text as stock_code,
             sum(b.posts) filter (where b.bucket >= v_now - v_span)::integer as posts,
             coalesce(sum(b.posts) filter (where b.bucket < v_now - v_span), 0)::integer as prev_posts,
             (coalesce(sum(b.weighted) filter (where b.bucket >= v_now - v_span), 0)
               - coalesce(sum(b.weighted) filter (where b.bucket < v_now - v_span), 0))
               / greatest(coalesce(sum(b.weighted) filter (where b.bucket < v_now - v_span), 0), 1)
               * case when b.stock_code = any (v_alerts) then v_factor else 1 end as growth
      from private.stock_mention_buckets b
      where b.bucket >= v_now - 2 * v_span
      group by b.stock_code
    ) g
    where g.posts >= v_min and g.growth > 0
    order by g.growth desc, g.posts desc, g.stock_code
    limit 50;

    insert into private.trending_snapshot (window_key, kind, rank, item_key, score, data, computed_at)
    select v_window, 'post', row_number() over (order by h.score desc, h.created_at desc), h.id::text, h.score,
           '{}'::jsonb, v_now
    from (
      select p.id, p.created_at,
             (p.like_count + 2 * p.comment_count + 1)
               * private.author_weight(pr.created_at, pr.trust_level)
               * case when exists (select 1 from public.post_stocks ps
                                   where ps.post_id = p.id and ps.stock_code = any (v_alerts))
                      then v_factor else 1 end
               / power(extract(epoch from (v_now - p.created_at)) / 3600 + 2, v_gravity) as score
      from public.posts p
      join public.profiles pr on pr.id = p.author_id
      where p.created_at >= v_now - v_span
        and p.deleted_at is null
        and p.moderation_status = 'visible'
        and pr.deleted_at is null
    ) h
    order by h.score desc, h.created_at desc
    limit 100;
  end loop;

  update private.trending_state set computed_at = v_now, alert_codes = v_alerts where singleton;
  return jsonb_build_object('computed_at', v_now, 'alerts', cardinality(v_alerts));
end;
$$;

create or replace function private.trending_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buckets integer := private.trending_refresh(now() - interval '1 hour');
begin
  return private.trending_compute() || jsonb_build_object('buckets', v_buckets);
end;
$$;

create or replace function private.trending_rebuild()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buckets integer := private.trending_refresh(now() - interval '15 days');
  v_purged  integer;
begin
  delete from private.stock_mention_buckets
   where bucket < now() - make_interval(days => private.setting_num('trending.bucket_retention_days', 35)::integer);
  get diagnostics v_purged = row_count;
  return private.trending_compute() || jsonb_build_object('buckets', v_buckets, 'purged', v_purged);
end;
$$;

create or replace function public.get_stock_sentiment(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code   text := upper(ltrim(btrim(coalesce(p_code, '')), '$'));
  v_result jsonb := '{}';
  v_window text;
  r        record;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham tidak valid');
  end if;

  foreach v_window in array array['24h', '7d'] loop
    select coalesce(sum(b.posts), 0)::integer as posts,
           coalesce(sum(b.bullish), 0)::integer as bullish,
           coalesce(sum(b.bearish), 0)::integer as bearish,
           coalesce(sum(b.neutral), 0)::integer as neutral,
           coalesce(sum(b.w_bullish), 0) as w_bullish,
           coalesce(sum(b.w_bearish), 0) as w_bearish,
           coalesce(sum(b.w_neutral), 0) as w_neutral
      into r
    from private.stock_mention_buckets b
    where b.stock_code = v_code
      and b.bucket >= now() - case v_window when '24h' then interval '24 hours' else interval '7 days' end;

    v_result := v_result || jsonb_build_object(v_window, jsonb_build_object(
      'posts', r.posts, 'bullish', r.bullish, 'bearish', r.bearish, 'neutral', r.neutral,
      'unlabeled', r.posts - r.bullish - r.bearish - r.neutral,
      'bullish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_bullish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
      'bearish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_bearish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
      'neutral_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                          then round(100 * r.w_neutral / (r.w_bullish + r.w_bearish + r.w_neutral)) end));
  end loop;

  return jsonb_build_object('code', v_code)
      || v_result
      || jsonb_build_object('updated_at', (select s.refreshed_at from private.trending_state s where s.singleton));
end;
$$;

create or replace function public.get_trending(p_window text default '24h')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_window text := coalesce(nullif(btrim(p_window), ''), '24h');
  v_ids    uuid[];
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_window not in ('24h', '7d') then
    perform private.api_error(400, 'invalid_window', 'window harus 24h atau 7d');
  end if;

  select array_agg(x.id order by x.rank) into v_ids
  from (
    select p.id, t.rank
    from private.trending_snapshot t
    join public.posts p on p.id = t.item_key::uuid
    where t.window_key = v_window and t.kind = 'post'
      and p.deleted_at is null
      and p.moderation_status = 'visible'
      and p.author_id not in (select private.blocked_user_ids())
      and p.author_id not in (select m.muted_id from public.mutes m where m.muter_id = v_uid)
      and not exists (
        select 1 from public.post_stocks ps
        join public.muted_stocks ms on ms.stock_code = ps.stock_code and ms.user_id = v_uid
        where ps.post_id = p.id)
    order by t.rank
    limit 10
  ) x;

  return jsonb_build_object(
    'window', v_window,
    'computed_at', (select s.computed_at from private.trending_state s where s.singleton),
    'stocks', coalesce((select jsonb_agg(t.data order by t.rank) from private.trending_snapshot t
                        where t.window_key = v_window and t.kind = 'stock' and t.rank <= 10), '[]'),
    'rising', coalesce((select jsonb_agg(t.data order by t.rank) from private.trending_snapshot t
                        where t.window_key = v_window and t.kind = 'rising' and t.rank <= 10), '[]'),
    'posts', coalesce((select jsonb_agg(to_jsonb(f) order by u.ord)
                       from unnest(coalesce(v_ids, '{}')) with ordinality as u(id, ord)
                       join private.feed_posts(coalesce(v_ids, '{}')) f on f.id = u.id), '[]'),
    'hashtags', coalesce((select jsonb_agg(to_jsonb(h)) from public.get_trending_hashtags(v_window, 10) h), '[]'));
end;
$$;

select private.trending_rebuild();

select cron.schedule('social-trending', '*/5 * * * *', 'select private.trending_tick()');
select cron.schedule('social-trending-rebuild', '40 2 * * *', 'select private.trending_rebuild()');

revoke execute on function private.manipulation_alert_codes() from public;
revoke execute on function private.trending_refresh(timestamptz) from public;
revoke execute on function private.trending_compute() from public;
revoke execute on function private.trending_tick() from public;
revoke execute on function private.trending_rebuild() from public;
revoke execute on function public.get_stock_sentiment(text) from public, anon;
revoke execute on function public.get_trending(text) from public, anon;
grant execute on function public.get_stock_sentiment(text) to authenticated;
grant execute on function public.get_trending(text) to authenticated;
