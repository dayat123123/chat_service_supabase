insert into private.settings (key, value, description) values
  ('manipulation.sentiment_share', '0.9',
   'Sentimen seragam: porsi postingan berlabel yang searah (bullish saja atau bearish saja) dalam 1 jam terakhir (0,5–1)'),
  ('manipulation.sentiment_min_mentions', '15', 'Sentimen seragam: minimal postingan berlabel sentimen dalam 1 jam terakhir'),
  ('manipulation.sentiment_min_authors', '8', 'Sentimen seragam: minimal penulis berbeda yang searah'),
  ('manipulation.sentiment_spike_factor', '3',
   'Sentimen seragam: mention 1 jam terakhir harus melebihi faktor × rata-rata per jam periode dasar (1 = tanpa syarat lonjakan)')
on conflict (key) do nothing;

alter table cs.manipulation_alerts drop constraint manipulation_alerts_kind;
alter table cs.manipulation_alerts add constraint manipulation_alerts_kind
  check (kind in ('mention_spike', 'new_account_concentration', 'coordinated_posts', 'one_sided_sentiment'));

create or replace function cs.detect_manipulation(p_at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days         numeric := private.setting_num('manipulation.baseline_days', 7);
  v_factor       numeric := private.setting_num('manipulation.spike_factor', 5);
  v_spike_min    numeric := private.setting_num('manipulation.spike_min_mentions', 20);
  v_share        numeric := private.setting_num('manipulation.new_account_share', 0.6);
  v_share_min    numeric := private.setting_num('manipulation.new_account_min_mentions', 10);
  v_age          numeric := private.setting_num('manipulation.new_account_age_days', 7);
  v_sim          numeric := private.setting_num('manipulation.similarity', 0.8);
  v_authors      numeric := private.setting_num('manipulation.similar_min_authors', 5);
  v_window       numeric := private.setting_num('manipulation.similar_window_minutes', 30);
  v_sent_share   numeric := private.setting_num('manipulation.sentiment_share', 0.9);
  v_sent_min     numeric := private.setting_num('manipulation.sentiment_min_mentions', 15);
  v_sent_authors numeric := private.setting_num('manipulation.sentiment_min_authors', 8);
  v_sent_factor  numeric := private.setting_num('manipulation.sentiment_spike_factor', 3);
  v_count        integer := 0;
  v_alert        cs.manipulation_alerts;
  v_held         uuid[];
  v_dir          text;
  v_dir_count    integer;
  v_dir_authors  integer;
  v_dir_ids      uuid[];
  r              record;
begin
  for r in
    with cur as (
      select ps.stock_code, count(*) as mentions,
             count(*) filter (where pr.created_at > p_at - v_age * interval '1 day' or pr.trust_level = 0) as new_mentions,
             count(distinct p.author_id) as authors,
             count(*) filter (where p.sentiment in ('bullish', 'bearish', 'neutral')) as labeled,
             count(*) filter (where p.sentiment = 'bullish') as bullish,
             count(*) filter (where p.sentiment = 'bearish') as bearish,
             count(distinct p.author_id) filter (where p.sentiment = 'bullish') as bullish_authors,
             count(distinct p.author_id) filter (where p.sentiment = 'bearish') as bearish_authors,
             (array_agg(p.id order by ps.post_created_at desc, p.id))[1:50] as post_ids,
             (array_agg(p.id order by ps.post_created_at desc, p.id) filter (where p.sentiment = 'bullish'))[1:50] as bullish_ids,
             (array_agg(p.id order by ps.post_created_at desc, p.id) filter (where p.sentiment = 'bearish'))[1:50] as bearish_ids,
             (array_agg(distinct p.author_id))[1:50] as author_ids,
             (array_agg(distinct p.author_id) filter (where pr.created_at > p_at - v_age * interval '1 day'
                                                       or pr.trust_level = 0))[1:50] as new_author_ids,
             (array_agg(distinct p.author_id) filter (where p.sentiment = 'bullish'))[1:50] as bullish_author_ids,
             (array_agg(distinct p.author_id) filter (where p.sentiment = 'bearish'))[1:50] as bearish_author_ids
      from public.post_stocks ps
      join public.posts p on p.id = ps.post_id
      join public.profiles pr on pr.id = p.author_id
      where ps.post_created_at > p_at - interval '1 hour' and ps.post_created_at <= p_at and p.deleted_at is null
      group by ps.stock_code
      having count(*) >= least(v_spike_min, v_share_min, v_sent_min)
    ), base as (
      select ps.stock_code, count(*)::numeric / (v_days * 24) as hourly
      from public.post_stocks ps
      join cur on cur.stock_code = ps.stock_code
      where ps.post_created_at > p_at - interval '1 hour' - v_days * interval '1 day'
        and ps.post_created_at <= p_at - interval '1 hour'
      group by ps.stock_code
    )
    select cur.*, coalesce(base.hourly, 0) as hourly from cur left join base using (stock_code)
  loop
    if r.mentions >= v_spike_min and r.mentions > v_factor * r.hourly then
      v_alert := cs.manipulation_upsert(r.stock_code, 'mention_spike',
        round(r.mentions / greatest(r.hourly, 0.1), 2),
        jsonb_build_object('mentions_last_hour', r.mentions, 'hourly_average', round(r.hourly, 2),
                           'authors', r.authors, 'post_ids', to_jsonb(r.post_ids),
                           'author_ids', to_jsonb(r.author_ids), 'window_end', p_at), p_at);
      perform cs.manipulation_slow_mode(v_alert, p_at);
      v_count := v_count + 1;
    end if;
    if r.mentions >= v_share_min and r.new_mentions::numeric / r.mentions > v_share then
      v_alert := cs.manipulation_upsert(r.stock_code, 'new_account_concentration',
        round(r.new_mentions::numeric / r.mentions, 2),
        jsonb_build_object('mentions_last_hour', r.mentions, 'new_account_mentions', r.new_mentions,
                           'new_account_days', v_age, 'post_ids', to_jsonb(r.post_ids),
                           'author_ids', to_jsonb(coalesce(r.new_author_ids, '{}')), 'window_end', p_at), p_at);
      perform cs.manipulation_slow_mode(v_alert, p_at);
      v_count := v_count + 1;
    end if;
    if r.labeled >= v_sent_min and r.mentions > v_sent_factor * r.hourly then
      v_dir := case when r.bullish::numeric / r.labeled >= v_sent_share then 'bullish'
                    when r.bearish::numeric / r.labeled >= v_sent_share then 'bearish' end;
      v_dir_count := case v_dir when 'bullish' then r.bullish when 'bearish' then r.bearish end;
      v_dir_authors := case v_dir when 'bullish' then r.bullish_authors when 'bearish' then r.bearish_authors end;
      v_dir_ids := case v_dir when 'bullish' then r.bullish_ids when 'bearish' then r.bearish_ids end;
      if v_dir is not null and v_dir_authors >= v_sent_authors then
        v_alert := cs.manipulation_upsert(r.stock_code, 'one_sided_sentiment',
          round(v_dir_count::numeric / r.labeled, 2),
          jsonb_build_object('direction', v_dir, 'mentions_last_hour', r.mentions, 'labeled', r.labeled,
                             'bullish', r.bullish, 'bearish', r.bearish, 'authors', v_dir_authors,
                             'new_account_mentions', r.new_mentions, 'hourly_average', round(r.hourly, 2),
                             'post_ids', to_jsonb(v_dir_ids),
                             'author_ids', to_jsonb(case v_dir when 'bullish' then r.bullish_author_ids
                                                               else r.bearish_author_ids end),
                             'window_end', p_at), p_at);
        perform cs.manipulation_slow_mode(v_alert, p_at);
        v_count := v_count + 1;
      end if;
    end if;
  end loop;

  for r in
    with recent as (
      select ps.stock_code, p.id, p.author_id, p.body, p.created_at
      from public.post_stocks ps
      join public.posts p on p.id = ps.post_id
      where ps.post_created_at > p_at - v_window * interval '1 minute' and ps.post_created_at <= p_at
        and p.deleted_at is null
    ), ranked as (
      select x.*, row_number() over (partition by x.stock_code order by x.created_at desc) as rn from recent x
    ), pairs as (
      select a.stock_code, a.id, array_agg(distinct b.id) as similar_ids, count(distinct b.author_id) as authors,
             array_agg(distinct b.author_id) as author_ids
      from ranked a
      join ranked b on b.stock_code = a.stock_code and b.rn <= 300
                   and (b.id = a.id or extensions.similarity(a.body, b.body) >= v_sim)
      where a.rn <= 300
      group by a.stock_code, a.id
    ), best as (
      select distinct on (p.stock_code) p.stock_code, p.id, p.similar_ids, p.authors, p.author_ids
      from pairs p
      where p.authors >= v_authors
      order by p.stock_code, p.authors desc, p.id
    )
    select b.*, (select left(x.body, 280) from public.posts x where x.id = b.id) as sample from best b
  loop
    v_alert := cs.manipulation_upsert(r.stock_code, 'coordinated_posts', r.authors,
      jsonb_build_object('post_ids', to_jsonb(r.similar_ids), 'authors', r.authors, 'sample', r.sample,
                         'author_ids', to_jsonb(r.author_ids[1:50]),
                         'window_minutes', v_window, 'window_end', p_at), p_at);
    if private.setting_json('manipulation.auto_hold_similar', 'true') = 'true'::jsonb then
      with held as (
        update public.posts set moderation_status = 'held', moderated_at = now()
         where id = any (r.similar_ids) and moderation_status = 'visible' and deleted_at is null
        returning id
      )
      select coalesce(array_agg(id), '{}') into v_held from held;
      perform private.flag_content('post', h, '{coordinated}', 'manipulation', v_alert.id) from unnest(v_held) h;
      if cardinality(v_held) > 0 then
        update cs.manipulation_alerts
           set auto_actions = auto_actions || jsonb_build_object('held_posts',
                 coalesce(auto_actions -> 'held_posts', '[]'::jsonb) || to_jsonb(v_held))
         where id = v_alert.id;
      end if;
    end if;
    perform cs.manipulation_slow_mode(v_alert, p_at);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.alert_uuid_list(p_value jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg((v #>> '{}')::uuid), '{}')
  from jsonb_array_elements(case when jsonb_typeof(p_value) = 'array' then p_value else '[]'::jsonb end) v
  where jsonb_typeof(v) = 'string'
    and (v #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$$;

create or replace function cs_api.community_manipulation_accounts(p_days integer default 30, p_min_alerts integer default 2)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_community('{community.moderate}');
  v_age numeric := private.setting_num('manipulation.new_account_age_days', 7);
begin
  if p_days is null or p_days not between 1 and 90 then
    perform private.api_error(400, 'invalid_days', 'Rentang 1–90 hari');
  end if;
  if p_min_alerts is null or p_min_alerts not between 2 and 50 then
    perform private.api_error(400, 'invalid_min_alerts', 'Minimal alert 2–50');
  end if;
  return coalesce((
    with alerts as (
      select a.id, a.stock, a.last_detected_at, a.status, a.evidence
      from cs.manipulation_alerts a
      where a.last_detected_at > now() - make_interval(days => p_days)
        and a.status <> 'dismissed'
    ), links as (
      select al.id, al.stock, al.last_detected_at, x.author_id
      from alerts al
      cross join lateral (
        select u as author_id from unnest(cs.alert_uuid_list(al.evidence -> 'author_ids')) u
        union
        select p.author_id from public.posts p where p.id = any (cs.alert_uuid_list(al.evidence -> 'post_ids'))
      ) x
    ), agg as (
      select l.author_id, count(distinct l.id) as alerts, array_agg(distinct l.stock order by l.stock) as stocks,
             max(l.last_detected_at) as last_at
      from links l
      group by l.author_id
      having count(distinct l.id) >= p_min_alerts
    )
    select jsonb_agg(jsonb_build_object(
             'user_id', g.author_id,
             'username', pr.username::text,
             'display_name', coalesce(nullif(btrim(pr.display_name), ''), pr.username::text),
             'created_at', pr.created_at,
             'new_account', pr.created_at > now() - v_age * interval '1 day' or pr.trust_level = 0,
             'alerts', g.alerts,
             'stocks', to_jsonb(g.stocks),
             'last_alert_at', g.last_at,
             'banned', private.has_active_sanction(pr.id, '{ban}'),
             'deleted', pr.deleted_at is not null)
           order by g.alerts desc, g.last_at desc, g.author_id)
    from (select * from agg order by alerts desc, last_at desc, author_id limit 100) g
    join public.profiles pr on pr.id = g.author_id), '[]');
end;
$$;

create or replace function cs_api.compliance_set_manipulation_settings(p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_key   text;
  v_value jsonb;
  v_min   numeric;
  v_max   numeric;
  v_win   jsonb;
  v_old   jsonb := cs.manipulation_settings_view();
begin
  if jsonb_typeof(p_values) is distinct from 'object' or p_values = '{}'::jsonb then
    perform private.api_error(400, 'invalid_setting', 'Kirim objek pengaturan');
  end if;
  for v_key, v_value in select * from jsonb_each(p_values) loop
    if not (v_old ? v_key) then
      perform private.api_error(400, 'invalid_setting', 'Pengaturan tidak dikenal: ' || v_key);
    end if;
    if v_key in ('manipulation.auto_slow_mode', 'manipulation.auto_hold_similar') then
      if jsonb_typeof(v_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', v_key || ' harus true atau false');
      end if;
    elsif v_key = 'rooms.busy_windows' then
      if jsonb_typeof(v_value) <> 'array' or jsonb_array_length(v_value) > 6 then
        perform private.api_error(400, 'invalid_setting', 'Jam ramai: daftar maksimal 6 rentang');
      end if;
      for v_win in select jsonb_array_elements(v_value) loop
        if jsonb_typeof(v_win) <> 'array' or jsonb_array_length(v_win) <> 2
           or (v_win ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or (v_win ->> 1) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_win ->> 0) >= (v_win ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam ramai harus HH:MM–HH:MM dan jam mulai sebelum jam selesai');
        end if;
      end loop;
    else
      select x.lo, x.hi into v_min, v_max
      from (values ('manipulation.spike_factor', 1.5, 100), ('manipulation.spike_min_mentions', 1, 100000),
                   ('manipulation.baseline_days', 1, 60), ('manipulation.new_account_share', 0.1, 1),
                   ('manipulation.new_account_min_mentions', 1, 100000), ('manipulation.new_account_age_days', 1, 90),
                   ('manipulation.similarity', 0.3, 1), ('manipulation.similar_min_authors', 2, 1000),
                   ('manipulation.similar_window_minutes', 5, 1440), ('manipulation.auto_slow_mode_seconds', 0, 3600),
                   ('manipulation.auto_slow_mode_minutes', 1, 1440), ('rooms.busy_slow_mode', 0, 300),
                   ('manipulation.sentiment_share', 0.5, 1), ('manipulation.sentiment_min_mentions', 1, 100000),
                   ('manipulation.sentiment_min_authors', 2, 1000), ('manipulation.sentiment_spike_factor', 1, 100))
             x(k, lo, hi)
      where x.k = v_key;
      if v_min is null then
        perform private.api_error(400, 'invalid_setting', 'Pengaturan tidak dikenal: ' || v_key);
      end if;
      if jsonb_typeof(v_value) <> 'number' or (v_value #>> '{}')::numeric not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_key || ' harus angka ' || v_min || '–' || v_max);
      end if;
    end if;
    update private.settings set value = v_value, updated_at = now() where key = v_key;
  end loop;
  perform cs.audit('manipulation.settings', null, null,
    jsonb_build_object('from', (select jsonb_object_agg(k, v_old -> k) from jsonb_object_keys(p_values) k), 'to', p_values));
  return cs.manipulation_settings_view();
end;
$$;

revoke execute on function cs.detect_manipulation(timestamptz) from public;
revoke execute on function cs.alert_uuid_list(jsonb) from public;
revoke execute on function cs_api.community_manipulation_accounts(integer, integer) from public;
revoke execute on function cs_api.compliance_set_manipulation_settings(jsonb) from public;
grant execute on function cs_api.community_manipulation_accounts(integer, integer) to authenticated;
grant execute on function cs_api.compliance_set_manipulation_settings(jsonb) to authenticated;
