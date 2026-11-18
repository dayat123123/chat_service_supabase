begin;
select plan(4);

select is((select words_max from private.policy_patterns where id),
          coalesce((select max(cardinality(string_to_array(w.word, ' '))) from public.banned_words w), 0),
  'words_max sesuai kata terpanjang di daftar kata terlarang');
select is((select promo_max from private.policy_patterns where id),
          coalesce((select max(cardinality(string_to_array(p.phrase, ' '))) from cs.promo_phrases p), 0),
  'promo_max sesuai frasa promosi terpanjang');
select is((select count(*)::int from public.banned_words w
           where not exists (select 1 from private.policy_forms f where f.source = 'word' and f.word = w.word)
             and private.policy_collapse(private.normalize_for_policy(w.word)) ~ '^[a-z0-9]+( [a-z0-9]+)*$'
             and char_length(private.policy_collapse(private.normalize_for_policy(w.word))) >= 2), 0,
  'Setiap kata terlarang punya bentuk pencocokan');
select is((select allow from private.policy_patterns where id),
          private.policy_alternation(array(select a.term from cs.policy_allowlist a)),
  'Pola pengecualian sesuai daftar pengecualian');

select * from finish();
rollback;
