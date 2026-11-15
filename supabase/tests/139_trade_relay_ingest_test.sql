begin;
select plan(48);

update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
update cs.cs_settings set value = 'false' where key = 'trade_notify.enabled';
update cs.cs_settings set value = '["RG"]' where key = 'trade_share.boards';
update cs.cs_settings set value = 'false' where key = 'trade_share.force_hide_price';
delete from private.trade_sharers;
delete from private.trade_orders;
delete from private.trade_notify_receipts;
delete from private.trade_share_excluded_stocks;
update private.trade_relay_config set last_command_at = null, aes_key_secret_id = null, aes_iv_secret_id = null;

select tests.create_user('trl_budi') as budi \gset
select tests.create_user('trl_sari') as sari \gset
select tests.create_user('trl_owner') as owner \gset
insert into private.account_links (cust_id, profile_id) values ('RB1', :'budi'), ('RS1', :'sari'), ('RO1', :'owner');
insert into private.trade_sharers (profile_id, status, delay_minutes, show_price) values
  (:'budi', 'active', 15, true), (:'sari', 'active', 15, false);
insert into private.trade_sharer_accounts (profile_id, cust_id) values (:'budi', 'RB1'), (:'sari', 'RS1');
insert into private.push_devices (user_id, token, platform, locale)
values (:'owner', 'token-owner-0123456789abcdef', 'android', 'id');

create function pg_temp.h(p text) returns text language sql as $$ select encode(sha256(convert_to(p, 'UTF8')), 'hex') $$;
create function pg_temp.ord(p_cust text, p_order text, p_status text, p_price integer, p_shares bigint, p_remain bigint,
                            p_traded bigint, p_board text default 'RG', p_stock text default 'BBCA')
returns jsonb language sql as $$
  select jsonb_build_object('kind', 'order', 'cust_id', p_cust, 'order_ref', pg_temp.h(p_order || p_cust),
                            'seq', pg_temp.h(p_order || p_status || p_price || p_remain || p_traded),
                            'status', p_status, 'stock', p_stock, 'side', 'buy', 'board', p_board,
                            'order_date', '2026-11-16', 'order_shares', p_shares, 'remain_shares', p_remain,
                            'traded_shares', p_traded, 'order_price', p_price)
$$;
create function pg_temp.fill(p_cust text, p_order text, p_trade text, p_price integer, p_shares bigint)
returns jsonb language sql as $$
  select jsonb_build_object('kind', 'fill', 'cust_id', p_cust, 'order_ref', pg_temp.h(p_order || p_cust),
                            'key', pg_temp.h(p_trade || p_cust), 'stock', 'BBCA', 'side', 'buy', 'board', 'RG',
                            'traded_at', '2026-11-16T03:00:00+00', 'shares', p_shares, 'price', p_price)
$$;
create function pg_temp.send(variadic p_events jsonb[]) returns jsonb language sql as $$
  select public.trade_relay_events('test-relay', to_jsonb(p_events))
$$;
create function pg_temp.o(p_order text, p_cust text) returns private.trade_orders language sql as $$
  select * from private.trade_orders where order_ref = pg_temp.h(p_order || p_cust)
$$;

select tests.authenticate_anon();
select throws_ok($$select public.trade_relay_config('x')$$, '42501', null, 'Anon tidak bisa membaca config relay');
select tests.authenticate_as(:'budi');
select throws_ok($$select public.trade_relay_events('x', '[]')$$, '42501', null, 'Nasabah tidak bisa mengirim event relay');
reset role;

select public.trade_relay_config('test-relay') as cfg \gset
select is(:'cfg'::jsonb #> '{accounts,sharers}', '["RB1", "RS1"]'::jsonb, 'Config berisi rekening trader yang aktif');
select is(:'cfg'::jsonb #> '{accounts,owners}', '[]'::jsonb, 'Rekening pemilik kosong saat notifikasi pemilik mati');
select ok(not (public.trade_relay_config('test-relay', (:'cfg'::jsonb ->> 'version')::bigint,
                                         (:'cfg'::jsonb ->> 'accounts_version')::bigint) ? 'accounts'),
  'Daftar rekening tidak dikirim ulang bila versinya tidak berubah');
select :'cfg'::jsonb ->> 'accounts_version' as av \gset
insert into private.account_links (cust_id, profile_id) values ('RO1', :'owner')
on conflict (cust_id, profile_id) do update set seen_at = now();
select is(public.trade_relay_config('test-relay') ->> 'accounts_version', :'av',
  'Login ulang (seen_at diperbarui) tidak menaikkan versi daftar rekening');
update cs.cs_settings set value = 'true' where key = 'trade_notify.enabled';
select ok((public.trade_relay_config('test-relay') ->> 'accounts_version')::bigint > :'av'::bigint,
  'Menyalakan notifikasi pemilik menaikkan versi daftar rekening');
select ok(public.trade_relay_config('test-relay') #> '{accounts,owners}' @> '["RO1"]'::jsonb,
  'Rekening pemilik ikut dikirim saat notifikasi pemilik menyala');

select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'open', 9150, 2500, 2500, 0)) #>> '{results,0,status}', 'accepted',
  'Order baru trader diterima');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'open', 9150, 2500, 2500, 0)) #>> '{results,0,status}', 'duplicate',
  'Update order yang sama persis dianggap duplikat');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'open', 9150, 2500, 1500, 1000)) #>> '{results,0,status}', 'accepted',
  'Match sebagian (status open, traded naik) diterima');
select is((pg_temp.o('O1', 'RB1')).traded_shares, 1000::bigint, 'Volume match tersimpan');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'open', 9150, 2500, 2500, 0)) #>> '{results,0,status}', 'ignored',
  'Paket terlambat dengan volume lebih kecil diabaikan');
select is((pg_temp.o('O1', 'RB1')).traded_shares, 1000::bigint, 'Volume match tidak pernah turun');
select is((pg_temp.o('O1', 'RB1')).remain_shares, 1500::bigint, 'Sisa volume mengikuti update dengan match terbesar');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'matched', 9150, 2500, 500, 2000)) #>> '{results,0,status}', 'accepted',
  'Matched dengan sisa (tidak penuh) diterima');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'matched', 9150, 2500, 0, 2500)) #>> '{results,0,status}', 'accepted',
  'Matched berikutnya dengan volume lebih besar diterima');
select is(pg_temp.send(pg_temp.ord('RB1', 'O1', 'open', 9150, 2500, 1500, 1000)) #>> '{results,0,status}', 'ignored',
  'Open yang datang setelah matched diabaikan');
select is((pg_temp.o('O1', 'RB1')).status, 'matched', 'Status tetap matched');
select is((pg_temp.o('O1', 'RB1')).remain_shares, 0::bigint, 'Order penuh tercatat dengan sisa 0');

select is(pg_temp.send(pg_temp.ord('RB1', 'O2', 'open', 1000, 1000, 1000, 0),
                       pg_temp.ord('RB1', 'O2', 'amending', 1000, 1000, 1000, 0),
                       pg_temp.ord('RB1', 'O2', 'open', 1050, 1000, 1000, 0)) #>> '{counts,accepted}', '3',
  'Rangkaian amend diterima');
select is((pg_temp.o('O2', 'RB1')).order_price, 1050, 'Harga order mengikuti amend terakhir');
select is((pg_temp.o('O2', 'RB1')).amend_count, 1, 'Jumlah amend dihitung');
select is(pg_temp.send(pg_temp.ord('RB1', 'O2', 'withdrawn', 1050, 1000, 1000, 0),
                       pg_temp.ord('RB1', 'O2', 'rejected', 1050, 1000, 1000, 0)) #>> '{results,1,status}', 'ignored',
  'Rejected setelah withdrawn diabaikan');

select is(pg_temp.send(pg_temp.fill('RB1', 'O3', 'T1', 500, 300)) #>> '{results,0,status}', 'accepted',
  'Fill yang datang sebelum paket order diterima');
select ok((pg_temp.o('O3', 'RB1')).status is null, 'Baris order sementara dibuat dari fill');
select is(pg_temp.send(pg_temp.fill('RB1', 'O3', 'T1', 500, 300)) #>> '{results,0,status}', 'duplicate',
  'Fill yang dikirim ulang tidak dihitung dua kali');
select is(pg_temp.send(pg_temp.fill('RB1', 'O3', 'T2', 510, 200)) #>> '{results,0,status}', 'accepted', 'Fill kedua diterima');
select is(round((pg_temp.o('O3', 'RB1')).fill_value / (pg_temp.o('O3', 'RB1')).fill_priced), 504::numeric,
  'Harga rata-rata tertimbang dari fill');
select is(pg_temp.send(pg_temp.ord('RB1', 'O3', 'open', 500, 1000, 500, 500)) #>> '{results,0,status}', 'accepted',
  'Paket order melengkapi baris sementara');
select is((pg_temp.o('O3', 'RB1')).order_shares, 1000::bigint, 'Lot order diambil dari paket order');

select is(pg_temp.send(pg_temp.ord('RS1', 'O4', 'open', 7000, 100, 100, 0)) #>> '{results,0,status}', 'accepted',
  'Order trader yang menyembunyikan harga diterima');
select ok((pg_temp.o('O4', 'RS1')).order_price is null, 'Harga dibuang bila trader menyembunyikan harga');
select is(pg_temp.send(pg_temp.ord('RB1', 'O5', 'open', 100, 100, 100, 0, 'NG')) #>> '{results,0,reason}',
  'board_not_shared', 'Board yang tidak dibagikan dibuang');
insert into private.trade_share_excluded_stocks (stock, reason, created_by) values ('GORE', 'Papan pemantauan', :'budi');
select is(pg_temp.send(pg_temp.ord('RB1', 'O6', 'open', 100, 100, 100, 0, 'RG', 'GORE')) #>> '{results,0,reason}',
  'stock_excluded', 'Saham dikecualikan dibuang');
select is(pg_temp.send(pg_temp.ord('ZZZ9', 'O7', 'open', 100, 100, 100, 0)) #>> '{results,0,reason}', 'not_shared',
  'Rekening yang tidak dibagikan dibuang');
select is(pg_temp.send('{"kind":"order","cust_id":"RB1"}'::jsonb) #>> '{results,0,status}', 'invalid',
  'Event tidak lengkap ditolak per event');

select is(pg_temp.send(pg_temp.fill('RO1', 'O8', 'T8', 9150, 500)) #>> '{results,0,status}', 'accepted',
  'Fill milik pemilik rekening diterima untuk notifikasi');
select is((select count(*)::integer from private.push_queue where user_id = :'owner' and kind = 'olt.trade.matched'), 1,
  'Push trade match diantrekan ke pemilik order');
select is((select body from private.push_queue where user_id = :'owner' and kind = 'olt.trade.matched'), '5 lot @ 9.150',
  'Isi push memakai lot dan format harga Indonesia');
select is(pg_temp.send(pg_temp.fill('RO1', 'O8', 'T8', 9150, 500)) #>> '{results,0,status}', 'duplicate',
  'Fill pemilik yang dikirim ulang tidak menghasilkan push kedua');
select ok(not exists (select 1 from private.trade_orders where cust_id = 'RO1'),
  'Isi trade nasabah yang bukan trader tidak disimpan');

select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.authenticate_agent(:'superadmin');
select throws_ok($$select cs_api.trade_relay_set_aes('ecb', 'pendek', null, 'Uji')$$, 'PT400', 'invalid_aes_key',
  'Kunci AES dengan panjang salah ditolak');
select is(cs_api.trade_relay_set_aes('cbc', 'ABCDEFGHIJKLMNOP', 'IVIVIVIVIVIVIVIV', 'Uji kunci') #>> '{aes,configured}', 'true',
  'Super Admin mengatur kunci AES');
select ok(cs_api.trade_relay_get()::text !~ 'ABCDEFGHIJKLMNOP', 'Kunci AES tidak pernah ditampilkan ke Hub');
select is(cs_api.trade_relay_command('restart', 'Uji restart') ->> 'restart_generation', '1', 'Perintah restart menaikkan generation');
select throws_ok($$select cs_api.trade_relay_command('reconnect', 'Lagi')$$, 'PT429', 'command_rate_limited',
  'Perintah relay dibatasi satu per menit');
reset role;
select is(public.trade_relay_config('test-relay') #>> '{aes,key}', 'ABCDEFGHIJKLMNOP', 'Relay menerima kunci AES dari Vault');

select * from finish();
rollback;
