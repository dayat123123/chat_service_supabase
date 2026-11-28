begin;
select plan(21);
update cs.cs_settings set value = 'false' where key = 'compliance.policy_four_eyes';

delete from cs.manipulation_alerts;
update cs.agents set community_permissions = '{}';
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
update private.settings set value = '100000' where key in ('manipulation.spike_min_mentions', 'manipulation.new_account_min_mentions');
update private.settings set value = '1000' where key = 'manipulation.similar_min_authors';
update private.settings set value = '1' where key = 'manipulation.baseline_days';

select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 1}') as nadia \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';

insert into public.profiles (id, olt_user_id, username, display_name, created_at)
select ('b1890000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'test:ms' || g, 'ms_user_' || g, 'User ' || g,
       now() - interval '90 days'
from generate_series(1, 90) g;

create function pg_temp.author(n integer) returns uuid language sql immutable as $$
  select ('b1890000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;

insert into public.posts (author_id, body, sentiment, created_at)
select pg_temp.author(g), 'Gas $ZQBL ' || md5(g::text) || md5((g * 3)::text), 'bullish', now() - make_interval(mins => g * 2)
from generate_series(1, 16) g;
insert into public.posts (author_id, body, sentiment, created_at)
values (pg_temp.author(17), 'Netral soal $ZQBL ' || md5('n'), 'neutral', now() - interval '5 minutes');
insert into public.posts (author_id, body, created_at)
select pg_temp.author(18), 'Tanpa label $ZQBL ' || md5((g + 50)::text), now() - interval '7 minutes'
from generate_series(1, 3) g;

insert into public.posts (author_id, body, sentiment, created_at)
select pg_temp.author(21 + g % 10), 'Buang $ZQBR ' || md5((g + 100)::text) || md5((g + 101)::text), 'bearish',
       now() - make_interval(mins => g * 3)
from generate_series(1, 15) g;

insert into public.posts (author_id, body, sentiment, created_at)
select pg_temp.author(30 + g), 'Campur $ZQMX ' || md5((g + 200)::text),
       case when g <= 10 then 'bullish' else 'bearish' end, now() - make_interval(mins => g * 2)
from generate_series(1, 18) g;

insert into public.posts (author_id, body, sentiment, created_at)
select pg_temp.author(50 + g), 'Ramai $ZQBS ' || md5((g + 300)::text), 'bullish', now() - make_interval(mins => g * 2)
from generate_series(1, 16) g;
insert into public.posts (author_id, body, created_at)
select pg_temp.author(70), 'Biasa $ZQBS ' || md5((g + 400)::text), now() - interval '2 hours' - make_interval(mins => g * 8)
from generate_series(1, 150) g;

insert into public.posts (author_id, body, sentiment, created_at)
select pg_temp.author(81 + g % 4), 'Sedikit akun $ZQFW ' || md5((g + 500)::text), 'bullish', now() - make_interval(mins => g * 2)
from generate_series(1, 16) g;

select ok(cs.detect_manipulation(now()) >= 2, 'Deteksi berjalan dan menemukan sentimen seragam');

select is((select evidence ->> 'direction' from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'one_sided_sentiment'),
  'bullish', 'Mayoritas bullish dari banyak akun memicu alert sentimen seragam');
select is((select score from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'one_sided_sentiment'), 0.94::numeric,
  'Skor = porsi postingan berlabel yang searah');
select is((select row((evidence ->> 'labeled')::int, (evidence ->> 'authors')::int, (evidence ->> 'mentions_last_hour')::int)::text
           from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'one_sided_sentiment'),
  '(17,16,20)', 'Bukti memuat jumlah berlabel, penulis searah, dan semua mention');
select is((select jsonb_array_length(evidence -> 'post_ids') from cs.manipulation_alerts
           where stock = 'ZQBL' and kind = 'one_sided_sentiment'), 16, 'Bukti hanya memuat postingan yang searah');
select is((select jsonb_array_length(evidence -> 'author_ids') from cs.manipulation_alerts
           where stock = 'ZQBL' and kind = 'one_sided_sentiment'), 16, 'Bukti memuat akun yang searah');
select is((select evidence ->> 'direction' from cs.manipulation_alerts where stock = 'ZQBR' and kind = 'one_sided_sentiment'),
  'bearish', 'Sentimen bearish seragam juga terdeteksi');
select ok(not exists (select 1 from cs.manipulation_alerts where stock = 'ZQMX'), 'Sentimen campuran tidak memicu alert');
select ok(not exists (select 1 from cs.manipulation_alerts where stock = 'ZQBS'),
  'Saham yang memang ramai setiap hari tidak memicu alert sentimen');
select ok(not exists (select 1 from cs.manipulation_alerts where stock = 'ZQFW'),
  'Sentimen seragam dari sedikit akun tidak memicu alert');

update private.settings set value = '16' where key = 'manipulation.spike_min_mentions';
select ok(cs.detect_manipulation(now()) >= 1, 'Deteksi kedua berjalan');
select is((select row(jsonb_array_length(evidence -> 'post_ids'), jsonb_array_length(evidence -> 'author_ids'))::text
           from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'mention_spike'),
  '(20,18)', 'Alert lonjakan kini membawa daftar postingan dan akun');
select is((select count(*)::integer from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'one_sided_sentiment'), 1,
  'Alert yang masih terbuka diperbarui, tidak digandakan');

select id as spike_id from cs.manipulation_alerts where stock = 'ZQBL' and kind = 'mention_spike' \gset

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.community_manipulation_accounts()$$, 'PT403', null,
  'Agen tanpa izin moderasi tidak bisa melihat akun berulang');
reset role;

select tests.authenticate_agent(:'dodi');
select cs_api.community_manipulation_accounts(30, 2) as accounts \gset
select is(jsonb_array_length(:'accounts'::jsonb), 16, 'Akun yang muncul di dua alert terbuka ikut terdaftar');
select is(:'accounts'::jsonb -> 0 -> 'stocks', '["ZQBL"]'::jsonb, 'Daftar saham per akun');
select is((:'accounts'::jsonb -> 0 ->> 'alerts')::int, 2, 'Jumlah alert per akun');
select throws_ok($$select cs_api.community_manipulation_accounts(0, 2)$$, 'PT400', 'invalid_days', 'Rentang hari divalidasi');
select lives_ok(format('select cs_api.community_manipulation_review(%L, %L, %L)', :'spike_id', 'dismissed', 'Bukan manipulasi'),
  'Moderator menolak alert lonjakan');
select is(jsonb_array_length(cs_api.community_manipulation_accounts(30, 2)), 0, 'Alert yang ditolak tidak dihitung');
reset role;

select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.compliance_set_manipulation_settings('{"manipulation.sentiment_share": 0.4}')$$,
  'PT400', 'invalid_setting', 'Porsi sentimen di bawah 50% ditolak');
reset role;

select * from finish();
rollback;
