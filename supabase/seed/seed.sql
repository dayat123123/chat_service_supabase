-- seed.sql - data dummy development (idempoten, aman dijalankan berulang).
--
-- ID user = UUID v5(namespace auth-bridge, olt_user_id), SAMA dengan yang
-- diterbitkan auth-bridge. Jadi token mock berikut langsung login sebagai
-- user di bawah (format: mock:<olt_user_id>:<username>):
--   mock:1001:budi_santoso   mock:1002:sari_invest   mock:1003:andi_trader
--   mock:1004:rina_saham     mock:1005:dewi_cuan     mock:1006:olt_official

create or replace function pg_temp.uid(p_olt_user_id text)
returns uuid
language sql
immutable
as $$
  select extensions.uuid_generate_v5('0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80'::uuid, p_olt_user_id);
$$;

-- ---------------------------------------------------------------------------
-- Saham & indeks IDX populer
-- ---------------------------------------------------------------------------
insert into public.stocks (code, name, type, sector) values
  ('IHSG',  'Indeks Harga Saham Gabungan', 'index', null),
  ('LQ45',  'Indeks LQ45', 'index', null),
  ('IDX30', 'Indeks IDX30', 'index', null),
  ('BBCA', 'Bank Central Asia Tbk', 'stock', 'Financials'),
  ('BBRI', 'Bank Rakyat Indonesia (Persero) Tbk', 'stock', 'Financials'),
  ('BMRI', 'Bank Mandiri (Persero) Tbk', 'stock', 'Financials'),
  ('BBNI', 'Bank Negara Indonesia (Persero) Tbk', 'stock', 'Financials'),
  ('BRIS', 'Bank Syariah Indonesia Tbk', 'stock', 'Financials'),
  ('BBTN', 'Bank Tabungan Negara (Persero) Tbk', 'stock', 'Financials'),
  ('ARTO', 'Bank Jago Tbk', 'stock', 'Financials'),
  ('TLKM', 'Telkom Indonesia (Persero) Tbk', 'stock', 'Infrastructures'),
  ('ISAT', 'Indosat Tbk', 'stock', 'Infrastructures'),
  ('EXCL', 'XLSMART Telecom Sejahtera Tbk', 'stock', 'Infrastructures'),
  ('TOWR', 'Sarana Menara Nusantara Tbk', 'stock', 'Infrastructures'),
  ('JSMR', 'Jasa Marga (Persero) Tbk', 'stock', 'Infrastructures'),
  ('BREN', 'Barito Renewables Energy Tbk', 'stock', 'Infrastructures'),
  ('ASII', 'Astra International Tbk', 'stock', 'Industrials'),
  ('UNTR', 'United Tractors Tbk', 'stock', 'Industrials'),
  ('GOTO', 'GoTo Gojek Tokopedia Tbk', 'stock', 'Technology'),
  ('BUKA', 'Bukalapak.com Tbk', 'stock', 'Technology'),
  ('EMTK', 'Elang Mahkota Teknologi Tbk', 'stock', 'Technology'),
  ('UNVR', 'Unilever Indonesia Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('ICBP', 'Indofood CBP Sukses Makmur Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('INDF', 'Indofood Sukses Makmur Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('MYOR', 'Mayora Indah Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('HMSP', 'H.M. Sampoerna Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('GGRM', 'Gudang Garam Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('CPIN', 'Charoen Pokphand Indonesia Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('AMRT', 'Sumber Alfaria Trijaya Tbk', 'stock', 'Consumer Non-Cyclicals'),
  ('KLBF', 'Kalbe Farma Tbk', 'stock', 'Healthcare'),
  ('MAPI', 'Mitra Adiperkasa Tbk', 'stock', 'Consumer Cyclicals'),
  ('ERAA', 'Erajaya Swasembada Tbk', 'stock', 'Consumer Cyclicals'),
  ('ADRO', 'Alamtri Resources Indonesia Tbk', 'stock', 'Energy'),
  ('PTBA', 'Bukit Asam Tbk', 'stock', 'Energy'),
  ('ITMG', 'Indo Tambangraya Megah Tbk', 'stock', 'Energy'),
  ('MEDC', 'Medco Energi Internasional Tbk', 'stock', 'Energy'),
  ('PGAS', 'Perusahaan Gas Negara Tbk', 'stock', 'Energy'),
  ('CUAN', 'Petrindo Jaya Kreasi Tbk', 'stock', 'Energy'),
  ('ANTM', 'Aneka Tambang Tbk', 'stock', 'Basic Materials'),
  ('INCO', 'Vale Indonesia Tbk', 'stock', 'Basic Materials'),
  ('MDKA', 'Merdeka Copper Gold Tbk', 'stock', 'Basic Materials'),
  ('MBMA', 'Merdeka Battery Materials Tbk', 'stock', 'Basic Materials'),
  ('AMMN', 'Amman Mineral Internasional Tbk', 'stock', 'Basic Materials'),
  ('TPIA', 'Chandra Asri Pacific Tbk', 'stock', 'Basic Materials'),
  ('SMGR', 'Semen Indonesia (Persero) Tbk', 'stock', 'Basic Materials'),
  ('INTP', 'Indocement Tunggal Prakarsa Tbk', 'stock', 'Basic Materials'),
  ('PANI', 'Pantai Indah Kapuk Dua Tbk', 'stock', 'Properties & Real Estate'),
  ('BSDE', 'Bumi Serpong Damai Tbk', 'stock', 'Properties & Real Estate'),
  ('CTRA', 'Ciputra Development Tbk', 'stock', 'Properties & Real Estate')
on conflict (code) do update
  set name = excluded.name, type = excluded.type, sector = excluded.sector;

-- ---------------------------------------------------------------------------
-- Filter kata (contoh)
-- ---------------------------------------------------------------------------
insert into public.banned_words (word, action) values
  ('anjing', 'mask'),
  ('bangsat', 'mask'),
  ('goblok', 'mask'),
  ('jaminan profit', 'block'),
  ('pasti cuan 100 persen', 'block')
on conflict (word) do nothing;

-- ---------------------------------------------------------------------------
-- User
-- ---------------------------------------------------------------------------
insert into public.profiles (id, olt_user_id, username, display_name, bio, is_verified)
select pg_temp.uid(u.olt_id), u.olt_id, u.username, u.display_name, u.bio, u.verified
from (values
  ('1001', 'budi_santoso', 'Budi Santoso',   'Swing trader. Fokus saham bank & telko.', true),
  ('1002', 'sari_invest',  'Sari Wulandari', 'Value investor, pemburu dividen.', false),
  ('1003', 'andi_trader',  'Andi Pratama',   'Scalper, teknikal only. Bukan ajakan beli/jual.', false),
  ('1004', 'rina_saham',   'Rina Kartika',   'Belajar saham sejak 2020.', false),
  ('1005', 'dewi_cuan',    'Dewi Lestari',   'Suka komoditas & energi.', false),
  ('1006', 'olt_official', 'Rendezvous OLT', 'Akun resmi Rendezvous OLT.', true)
) as u(olt_id, username, display_name, bio, verified)
on conflict (id) do nothing;

insert into public.follows (follower_id, following_id)
select pg_temp.uid(f.a), pg_temp.uid(f.b)
from (values
  ('1001', '1002'), ('1001', '1003'), ('1002', '1001'), ('1003', '1001'),
  ('1004', '1001'), ('1004', '1002'), ('1005', '1001'), ('1005', '1006'),
  ('1002', '1006'), ('1003', '1006')
) as f(a, b)
on conflict do nothing;

insert into public.stock_watchers (user_id, stock_code)
select pg_temp.uid(w.u), w.code
from (values
  ('1001', 'BBCA'), ('1001', 'BBRI'), ('1001', 'TLKM'), ('1002', 'BBCA'),
  ('1002', 'UNVR'), ('1003', 'GOTO'), ('1003', 'BUKA'), ('1004', 'BBRI'),
  ('1005', 'ADRO'), ('1005', 'PTBA'), ('1005', 'ANTM')
) as w(u, code)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Post (created_at di masa lalu agar feed terlihat alami)
-- ---------------------------------------------------------------------------
insert into public.posts (id, author_id, body, sentiment, created_at)
select p.id::uuid, pg_temp.uid(p.author), p.body, p.sentiment, now() - p.age::interval
from (values
  ('a0000000-0000-4000-8000-000000000001', '1001',
   E'$BBCA tembus resistance 10.000 dengan volume besar. Target berikutnya 10.500, SL di 9.700.\nGimana menurut @sari_invest?',
   'bullish', '6 hours'),
  ('a0000000-0000-4000-8000-000000000002', '1002',
   'Laporan keuangan $BBRI kuartal ini solid, NIM stabil. Saya tambah posisi pelan-pelan untuk dividen.',
   'bullish', '5 hours'),
  ('a0000000-0000-4000-8000-000000000003', '1003',
   '$GOTO masih sideways di 60-70. Belum ada konfirmasi breakout, saya wait and see dulu.',
   'neutral', '4 hours'),
  ('a0000000-0000-4000-8000-000000000004', '1005',
   'Harga batu bara melemah, hati-hati di $ADRO dan $PTBA. Saya kurangi eksposur komoditas.',
   'bearish', '3 hours 30 minutes'),
  ('a0000000-0000-4000-8000-000000000005', '1004',
   'Pemula mau tanya: lebih baik mulai dari $BBCA atau $TLKM untuk jangka panjang? cc @budi_santoso',
   null, '3 hours'),
  ('a0000000-0000-4000-8000-000000000006', '1006',
   'Pengingat: diskusi di OLT Social adalah opini pengguna, bukan rekomendasi investasi. Selalu lakukan riset sendiri sebelum bertransaksi.',
   null, '2 hours 30 minutes'),
  ('a0000000-0000-4000-8000-000000000007', '1001',
   '$IHSG koreksi sehat setelah reli seminggu. Bank besar seperti $BMRI dan $BBNI masih menarik di area support.',
   'bullish', '2 hours'),
  ('a0000000-0000-4000-8000-000000000008', '1003',
   'Scalping $BUKA hari ini lumayan, tapi volatilitas tinggi. Disiplin cut loss itu wajib.',
   'neutral', '1 hour 30 minutes'),
  ('a0000000-0000-4000-8000-000000000009', '1002',
   'Ada yang pegang $UNVR? Valuasi sudah murah secara historis, tapi pertumbuhan penjualan masih lemah.',
   'neutral', '1 hour'),
  ('a0000000-0000-4000-8000-000000000010', '1005',
   '$ANTM menarik kalau harga emas terus naik. Pantau juga $MDKA dan $INCO.',
   'bullish', '30 minutes')
) as p(id, author, body, sentiment, age)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Thread komentar 5 level di post pertama (+ cabang lain)
-- Disisipkan satu per satu agar path parent selalu sudah ada.
-- ---------------------------------------------------------------------------
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', null,
   pg_temp.uid('1002'), 'Setuju, volume beli asing juga masuk. Tapi RSI sudah mendekati overbought.', now() - interval '5 hours 50 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
   pg_temp.uid('1001'), '@sari_invest betul, makanya saya pasang SL ketat. Kalau tembus 10.500 baru tambah.', now() - interval '5 hours 40 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
   pg_temp.uid('1003'), 'Di timeframe 15 menit sudah ada divergence. Hati-hati pullback dulu.', now() - interval '5 hours 30 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000003',
   pg_temp.uid('1004'), 'Divergence itu maksudnya gimana ya kak? Masih belajar baca chart.', now() - interval '5 hours 20 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000004',
   pg_temp.uid('1003'), 'Harga bikin high baru tapi indikator (mis. RSI) tidak ikut naik. Tanda momentum melemah.', now() - interval '5 hours 10 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
   pg_temp.uid('1005'), 'Saya lebih suka tunggu retest 10.000 baru masuk.', now() - interval '5 hours')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', null,
   pg_temp.uid('1004'), 'Terima kasih analisanya, Pak Budi!', now() - interval '4 hours 30 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000008', 'a0000000-0000-4000-8000-000000000005', null,
   pg_temp.uid('1001'), 'Keduanya bagus untuk jangka panjang. $BBCA lebih defensif, $TLKM dividennya menarik.', now() - interval '2 hours 50 minutes')
on conflict (id) do nothing;
insert into public.comments (id, post_id, parent_id, author_id, body, created_at) values
  ('c0000000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000008',
   pg_temp.uid('1004'), 'Siap, makasih Pak. Saya cicil dua-duanya.', now() - interval '2 hours 40 minutes')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Reaksi
-- ---------------------------------------------------------------------------
insert into public.reactions (user_id, target_type, target_id)
select pg_temp.uid(r.u), r.t, r.id::uuid
from (values
  ('1002', 'post', 'a0000000-0000-4000-8000-000000000001'),
  ('1003', 'post', 'a0000000-0000-4000-8000-000000000001'),
  ('1004', 'post', 'a0000000-0000-4000-8000-000000000001'),
  ('1001', 'post', 'a0000000-0000-4000-8000-000000000002'),
  ('1004', 'post', 'a0000000-0000-4000-8000-000000000002'),
  ('1001', 'post', 'a0000000-0000-4000-8000-000000000006'),
  ('1002', 'post', 'a0000000-0000-4000-8000-000000000006'),
  ('1005', 'post', 'a0000000-0000-4000-8000-000000000007'),
  ('1001', 'comment', 'c0000000-0000-4000-8000-000000000001'),
  ('1004', 'comment', 'c0000000-0000-4000-8000-000000000005')
) as r(u, t, id)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Chat: DM Budi-Sari, grup "Diskusi Perbankan", room saham $BBCA
-- ---------------------------------------------------------------------------
insert into public.chat_rooms (id, type, name, stock_code, direct_key, created_by, created_at)
values
  ('d0000000-0000-4000-8000-000000000001', 'direct', null, null,
   least(pg_temp.uid('1001')::text, pg_temp.uid('1002')::text) || ':' ||
   greatest(pg_temp.uid('1001')::text, pg_temp.uid('1002')::text),
   pg_temp.uid('1001'), now() - interval '1 day'),
  ('d0000000-0000-4000-8000-000000000002', 'group', 'Diskusi Perbankan', null, null,
   pg_temp.uid('1001'), now() - interval '1 day'),
  ('d0000000-0000-4000-8000-000000000003', 'stock', 'Bank Central Asia Tbk', 'BBCA', null,
   pg_temp.uid('1001'), now() - interval '1 day')
on conflict (id) do nothing;

insert into public.chat_members (room_id, user_id, role, last_read_at)
select m.room::uuid, pg_temp.uid(m.u), m.role, now() - interval '1 day'
from (values
  ('d0000000-0000-4000-8000-000000000001', '1001', 'member'),
  ('d0000000-0000-4000-8000-000000000001', '1002', 'member'),
  ('d0000000-0000-4000-8000-000000000002', '1001', 'owner'),
  ('d0000000-0000-4000-8000-000000000002', '1002', 'admin'),
  ('d0000000-0000-4000-8000-000000000002', '1004', 'member'),
  ('d0000000-0000-4000-8000-000000000003', '1001', 'member'),
  ('d0000000-0000-4000-8000-000000000003', '1003', 'member'),
  ('d0000000-0000-4000-8000-000000000003', '1004', 'member')
) as m(room, u, role)
on conflict do nothing;

insert into public.messages (id, room_id, sender_id, body, created_at)
select m.id::uuid, m.room::uuid, pg_temp.uid(m.u), m.body, now() - m.age::interval
from (values
  ('e0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', '1001',
   'Sar, sudah lihat laporan keuangan BBRI?', '50 minutes'),
  ('e0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', '1002',
   'Sudah Bud, NIM-nya stabil. Saya tulis ringkasannya di feed.', '45 minutes'),
  ('e0000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000001', '1001',
   'Mantap, nanti saya baca. Thanks!', '40 minutes'),
  ('e0000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000002', '1001',
   'Selamat datang di grup Diskusi Perbankan 👋', '35 minutes'),
  ('e0000000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8000-000000000002', '1004',
   'Halo semua, salam kenal!', '30 minutes'),
  ('e0000000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8000-000000000003', '1003',
   'BBCA antrean beli tebal di 10.000.', '20 minutes'),
  ('e0000000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8000-000000000003', '1001',
   'Iya, asing net buy dari pagi.', '15 minutes')
) as m(id, room, u, body, age)
on conflict (id) do nothing;

insert into public.posts (id, author_id, body, sentiment, created_at)
values (
  'a0000000-0000-4000-8000-000000000011', pg_temp.uid('1004'),
  'Polling: menurut kalian $IHSG minggu ini ditutup bagaimana?', null, now() - interval '20 minutes'
)
on conflict (id) do nothing;

insert into public.post_polls (post_id, ends_at, created_at)
values ('a0000000-0000-4000-8000-000000000011', now() + interval '7 days', now() - interval '20 minutes')
on conflict (post_id) do nothing;

insert into public.post_poll_options (id, post_id, position, label)
values
  ('f1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000011', 0, 'Menguat'),
  ('f1000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000011', 1, 'Sideways'),
  ('f1000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000011', 2, 'Melemah')
on conflict (id) do nothing;

insert into public.post_poll_votes (post_id, user_id, option_id)
select 'a0000000-0000-4000-8000-000000000011', pg_temp.uid(v.u), v.opt::uuid
from (values
  ('1003', 'f1000000-0000-4000-8000-000000000001'),
  ('1005', 'f1000000-0000-4000-8000-000000000003'),
  ('1006', 'f1000000-0000-4000-8000-000000000001')
) as v(u, opt)
on conflict do nothing;
