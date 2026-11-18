begin;
select plan(4);

create function pg_temp.flatten(p_text text) returns text language plpgsql immutable as $$
declare
  v_prev text;
  v_text text := regexp_replace(regexp_replace(p_text, '--[^\n]*', '', 'g'), '''[^'']*''', '''x''', 'g');
begin
  loop
    v_prev := v_text;
    v_text := regexp_replace(v_text, '\([^()]*\)', ' ', 'g');
    exit when v_text = v_prev;
  end loop;
  return lower(v_text);
end;
$$;

create temp table unguarded as
select n.nspname || '.' || p.proname as fn, btrim(regexp_replace(s.stmt, '\s+', ' ', 'g')) as stmt
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_language l on l.oid = p.prolang and l.lanname in ('plpgsql', 'sql')
cross join lateral regexp_split_to_table(pg_temp.flatten(p.prosrc), ';') s(stmt)
where n.nspname in ('public', 'private', 'cs', 'cs_api')
  and s.stmt ~ '\m(update\s+(only\s+)?[a-z_."]+(\s+(as\s+)?[a-z_]+)?\s+set|delete\s+from)\M'
  and s.stmt !~ '\mwhere\M';

select is((select string_agg(fn, ', ' order by fn) from unguarded where fn <> 'private.trending_compute'), null,
  'Fungsi yang bisa dipanggil lewat PostgREST tidak punya UPDATE/DELETE tanpa WHERE (safeupdate menolaknya)');
select ok((select count(*) from unguarded where fn = 'private.trending_compute') <= 1,
  'Pengecualian hanya trending_compute, yang dijalankan cron sebagai postgres');

select tests.create_agent('Kirana SU', '{compliance}', '{}') as kirana \gset
insert into public.banned_words (word, action) values ('katauji', 'block');
select tests.authenticate_agent(:'kirana');
select cs_api.compliance_test_content('ada katauji di sini', 'post') as tested \gset
reset role;
select is((:'tested'::jsonb ->> 'banned_words'), 'block', 'Uji teks memakai daftar kata terlarang yang berlaku');
select is((:'tested'::jsonb ->> 'banned_word_total')::int, (select count(*)::int from public.banned_words),
  'Uji teks melaporkan jumlah kata di daftar supaya hasil lolos bisa dijelaskan');

select * from finish();
rollback;
