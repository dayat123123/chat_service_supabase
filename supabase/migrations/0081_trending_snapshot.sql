alter table private.trending_snapshot drop constraint trending_snapshot_kind_check;
alter table private.trending_snapshot add constraint trending_snapshot_kind_check
  check (kind in ('stock', 'rising', 'post', 'hashtag'));

create or replace function private.trending_refresh(p_since timestamptz)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from      timestamptz := date_bin('5 minutes', coalesce(p_since, now() - interval '1 hour'),
                                      timestamptz '2000-01-01');
  v_new_since timestamptz := now() - make_interval(days => private.setting_num('trending.new_account_days', 7)::integer);
  v_new_w     numeric := least(greatest(private.setting_num('trending.new_account_weight', 0.2), 0), 1);
  v_count     integer;
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
           max(case when pr.trust_level = 0 or pr.created_at > v_new_since then v_new_w else 1 end) as weight
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
  v_alerts    text[] := private.manipulation_alert_codes();
  v_factor    numeric := least(greatest(private.setting_num('trending.manipulation_weight', 0.3), 0), 1);
  v_gravity   numeric := greatest(private.setting_num('trending.post_gravity', 1.5), 0.1);
  v_min       integer := private.setting_num('trending.rising_min_posts', 5)::integer;
  v_authors   integer := private.setting_num('trending.min_authors', 2)::integer;
  v_new_since timestamptz := now() - make_interval(days => private.setting_num('trending.new_account_days', 7)::integer);
  v_new_w     numeric := least(greatest(private.setting_num('trending.new_account_weight', 0.2), 0), 1);
  v_window    text;
  v_span      interval;
  v_now       timestamptz := now();
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
               * case when pr.trust_level = 0 or pr.created_at > v_new_since then v_new_w else 1 end
               * case when cardinality(v_alerts) > 0
                           and exists (select 1 from public.post_stocks ps
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

    insert into private.trending_snapshot (window_key, kind, rank, item_key, score, data, computed_at)
    select v_window, 'hashtag', row_number() over (order by t.score desc, t.posts desc, t.tag), t.tag, t.score,
           jsonb_build_object('tag', t.tag, 'post_count', t.posts, 'author_count', t.authors, 'score', t.score),
           v_now
    from (
      select a.tag, sum(a.posts)::integer as posts, count(*)::integer as authors, round(sum(a.weight), 2) as score
      from (
        select ph.tag, p.author_id, count(*) as posts,
               max(case when pr.trust_level = 0 or pr.created_at > v_new_since then v_new_w else 1 end) as weight
        from public.post_hashtags ph
        join public.posts p on p.id = ph.post_id
        join public.profiles pr on pr.id = p.author_id
        where ph.post_created_at > v_now - v_span
          and p.deleted_at is null
          and p.moderation_status = 'visible'
          and pr.deleted_at is null
        group by ph.tag, p.author_id
      ) a
      group by a.tag
      having count(*) >= v_authors
    ) t
    order by t.score desc, t.posts desc, t.tag
    limit 50;
  end loop;

  update private.trending_state set computed_at = v_now, alert_codes = v_alerts where singleton;
  return jsonb_build_object('computed_at', v_now, 'alerts', cardinality(v_alerts));
end;
$$;

create or replace function public.get_trending_hashtags(p_window text default '24h', p_limit integer default 10)
returns table (tag text, post_count integer, author_count integer, score numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if coalesce(p_window, '24h') not in ('24h', '7d') then
    perform private.api_error(400, 'invalid_window', 'window harus 24h atau 7d');
  end if;

  return query
  select t.item_key, (t.data ->> 'post_count')::integer, (t.data ->> 'author_count')::integer, t.score
  from private.trending_snapshot t
  where t.window_key = coalesce(p_window, '24h') and t.kind = 'hashtag'
  order by t.rank
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
end;
$$;

create or replace function private.content_edits_purge()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from private.content_edits
   where id in (select e.id from private.content_edits e
                where not e.legal_hold
                  and e.retain_until < now()
                  and e.edited_at < now() - make_interval(days => private.setting_num('retention.archive_days', 1825)::integer)
                limit 50000);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

select private.trending_compute();
select cron.schedule('social-content-edits-retention', '35 3 * * *', 'select private.content_edits_purge()');

revoke execute on function private.content_edits_purge() from public;
