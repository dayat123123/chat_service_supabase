create or replace function private.merge_stock_code(p_from text, p_to text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_from is null or p_to is null or p_from = p_to then
    return;
  end if;
  insert into public.stock_watchers (user_id, stock_code, created_at)
  select w.user_id, p_to, w.created_at from public.stock_watchers w where w.stock_code = p_from
  on conflict do nothing;
  delete from public.stock_watchers where stock_code = p_from;
  insert into public.muted_stocks (user_id, stock_code, created_at)
  select m.user_id, p_to, m.created_at from public.muted_stocks m where m.stock_code = p_from
  on conflict do nothing;
  delete from public.muted_stocks where stock_code = p_from;
  if not exists (select 1 from public.chat_rooms r where r.type = 'stock' and r.stock_code = p_to) then
    update public.chat_rooms set stock_code = p_to, name = p_to where type = 'stock' and stock_code = p_from;
  end if;
  insert into private.stock_mention_buckets as b (stock_code, bucket, posts, authors, weighted, bullish, bearish,
                                                  neutral, w_bullish, w_bearish, w_neutral)
  select p_to, s.bucket, s.posts, s.authors, s.weighted, s.bullish, s.bearish, s.neutral, s.w_bullish, s.w_bearish,
         s.w_neutral
  from private.stock_mention_buckets s
  where s.stock_code = p_from
  on conflict (stock_code, bucket) do update
    set posts = b.posts + excluded.posts, authors = b.authors + excluded.authors,
        weighted = b.weighted + excluded.weighted, bullish = b.bullish + excluded.bullish,
        bearish = b.bearish + excluded.bearish, neutral = b.neutral + excluded.neutral,
        w_bullish = b.w_bullish + excluded.w_bullish, w_bearish = b.w_bearish + excluded.w_bearish,
        w_neutral = b.w_neutral + excluded.w_neutral;
  delete from private.stock_mention_buckets where stock_code = p_from;
  update cs.community_posts set pin_stock = p_to where pin_stock = p_from;
  update cs.community_campaigns set audience_stock = p_to where audience_stock = p_from;
  insert into private.stock_codes (code) values (p_to) on conflict do nothing;
end;
$$;

delete from private.market_instrument_aliases where alias = 'COMPOSITE' and code = 'IHSG';
update private.market_instruments
   set code = 'COMPOSITE', updated_at = now()
 where code = 'IHSG'
   and not exists (select 1 from private.market_instruments i where i.code = 'COMPOSITE');
delete from private.market_instruments where code = 'PEFINDO25' and updated_by is null;

insert into private.market_instruments as m (code, name, position) values
  ('COMPOSITE', 'Indeks Harga Saham Gabungan', 0),
  ('LQ45', 'Indeks LQ45', 1),
  ('JII', 'Jakarta Islamic Index', 2),
  ('MBX', 'Indeks Papan Utama', 3),
  ('DBX', 'Indeks Papan Pengembangan', 4),
  ('KOMPAS100', 'Indeks Kompas100', 5),
  ('BISNIS-27', 'Indeks Bisnis-27', 6),
  ('SRI-KEHATI', 'Indeks SRI-KEHATI', 7),
  ('ISSI', 'Indeks Saham Syariah Indonesia', 8),
  ('IDX30', 'Indeks IDX30', 9),
  ('INFOBANK15', 'Indeks Infobank15', 10),
  ('SMINFRA18', 'Indeks SMinfra18', 11),
  ('MNC36', 'Indeks MNC36', 12),
  ('INVESTOR33', 'Indeks Investor33', 13),
  ('I-GRADE', 'Indeks I-Grade', 14),
  ('IDXSMC-COM', 'IDX SMC Composite', 15),
  ('IDXSMC-LIQ', 'IDX SMC Liquid', 16),
  ('IDXHIDIV20', 'IDX High Dividend 20', 17),
  ('IDXBUMN20', 'IDX BUMN20', 18),
  ('JII70', 'Jakarta Islamic Index 70', 19),
  ('IDX80', 'Indeks IDX80', 20),
  ('IDXV30', 'IDX Value30', 21),
  ('IDXG30', 'IDX Growth30', 22),
  ('IDXQ30', 'IDX Quality30', 23),
  ('IDXESGL', 'IDX ESG Leaders', 24),
  ('IDXENERGY', 'IDX Sektor Energi', 25),
  ('IDXBASIC', 'IDX Sektor Barang Baku', 26),
  ('IDXINDUST', 'IDX Sektor Perindustrian', 27),
  ('IDXNONCYC', 'IDX Sektor Barang Konsumen Primer', 28),
  ('IDXCYCLIC', 'IDX Sektor Barang Konsumen Non-Primer', 29),
  ('IDXHEALTH', 'IDX Sektor Kesehatan', 30),
  ('IDXFINANCE', 'IDX Sektor Keuangan', 31),
  ('IDXPROPERT', 'IDX Sektor Properti & Real Estat', 32),
  ('IDXTECHNO', 'IDX Sektor Teknologi', 33),
  ('IDXINFRA', 'IDX Sektor Infrastruktur', 34),
  ('IDXTRANS', 'IDX Sektor Transportasi & Logistik', 35),
  ('IDXMESBUMN', 'IDX MES BUMN 17', 36),
  ('ESGSKEHATI', 'ESG Sector Leaders IDX KEHATI', 37),
  ('ESGQKEHATI', 'ESG Quality 45 IDX KEHATI', 38),
  ('IDXSHAGROW', 'IDX Sharia Growth', 39),
  ('IDXLQ45LCL', 'IDX LQ45 Low Carbon Leaders', 40),
  ('ABX', 'Indeks Papan Akselerasi', 41),
  ('PRIMBANK10', 'Indeks PRIMBANK10', 42),
  ('ECONOMIC30', 'Indeks Economic30', 43),
  ('IDXVESTA28', 'Indeks IDXVESTA28', 44),
  ('IDXCMDTY20', 'Indeks IDXCMDTY20', 45)
on conflict (code) do update
  set position = excluded.position,
      name = case when m.updated_by is null then excluded.name else m.name end,
      updated_at = now();

update private.market_instruments i
   set position = 46 + o.n
  from (select x.code, row_number() over (order by x.position, x.code) - 1 as n
        from private.market_instruments x
        where x.code <> all (array['COMPOSITE', 'LQ45', 'JII', 'MBX', 'DBX', 'KOMPAS100', 'BISNIS-27', 'SRI-KEHATI',
                                   'ISSI', 'IDX30', 'INFOBANK15', 'SMINFRA18', 'MNC36', 'INVESTOR33', 'I-GRADE',
                                   'IDXSMC-COM', 'IDXSMC-LIQ', 'IDXHIDIV20', 'IDXBUMN20', 'JII70', 'IDX80', 'IDXV30',
                                   'IDXG30', 'IDXQ30', 'IDXESGL', 'IDXENERGY', 'IDXBASIC', 'IDXINDUST', 'IDXNONCYC',
                                   'IDXCYCLIC', 'IDXHEALTH', 'IDXFINANCE', 'IDXPROPERT', 'IDXTECHNO', 'IDXINFRA',
                                   'IDXTRANS', 'IDXMESBUMN', 'ESGSKEHATI', 'ESGQKEHATI', 'IDXSHAGROW', 'IDXLQ45LCL',
                                   'ABX', 'PRIMBANK10', 'ECONOMIC30', 'IDXVESTA28', 'IDXCMDTY20'])) o
 where i.code = o.code;

insert into private.market_instrument_aliases (alias, code) values
  ('IHSG', 'COMPOSITE'),
  ('JCI', 'COMPOSITE'),
  ('IGRADE', 'I-GRADE')
on conflict (alias) do nothing;

select private.merge_stock_code('IHSG', 'COMPOSITE');
select private.merge_stock_code('IGRADE', 'I-GRADE');
select private.retag_posts(array['IHSG', 'COMPOSITE', 'JCI', 'I-GRADE', 'IGRADE', 'PEFINDO25']);
