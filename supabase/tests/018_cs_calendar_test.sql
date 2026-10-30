begin;
select plan(30);

select ok(cs.is_business_day('2026-11-02'), 'Senin biasa adalah hari kerja');
select ok(not cs.is_business_day('2026-10-31'), 'Sabtu bukan hari kerja walaupun CS buka');
select ok(not cs.is_business_day('2026-03-21'), 'Idulfitri bukan hari kerja');
select ok(not cs.is_business_day('2026-03-23'), 'Cuti bersama bukan hari kerja');
select ok(not cs.is_business_day('2026-12-31'), 'Libur bursa akhir tahun bukan hari kerja');
select is((select count(*)::integer from cs.holidays where day between '2026-01-01' and '2026-12-31'), 26,
  'Kalender 2026: 17 libur nasional, 8 cuti bersama, 1 libur bursa');
select is((select count(*)::integer from cs.holidays where day between '2027-01-01' and '2027-12-31'), 27,
  'Kalender 2027: 18 libur nasional, 8 cuti bersama, 1 libur bursa');

select is(cs.regulatory_deadline('2026-10-30 10:00+07', 5), '2026-11-06 23:59:59.999999+07'::timestamptz,
  'Hari penerimaan = hari ke-0; tenggat akhir hari kerja ke-5 pukul 23.59 WIB');
select is(cs.regulatory_deadline('2026-10-29 17:30+00', 5), '2026-11-06 23:59:59.999999+07'::timestamptz,
  'Dihitung dalam WIB: Kamis 17.30 UTC = Jumat 00.30 WIB');
select is(cs.regulatory_deadline('2026-10-31 10:00+07', 5), '2026-11-09 23:59:59.999999+07'::timestamptz,
  'Diterima hari Sabtu dianggap diterima hari kerja berikutnya');
select is(cs.regulatory_deadline('2026-03-17 10:00+07', 1), '2026-03-25 23:59:59.999999+07'::timestamptz,
  'Nyepi, Idulfitri, akhir pekan, dan cuti bersama dilewati');
select is(cs.regulatory_deadline('2026-12-25 10:00+07', 5), '2027-01-07 23:59:59.999999+07'::timestamptz,
  'Pergantian tahun: Natal, libur bursa, Tahun Baru, dan Isra Mikraj 2027 dilewati');
select is(cs.business_days_between('2026-10-30', '2026-11-06'), 5, 'Sisa hari kerja dihitung setelah hari ini');
select is(cs.regulatory_deadline(null, 5), null, 'Tanggal kosong menghasilkan tenggat kosong');

select ok(cs.is_open('2026-10-30 21:30+07'), 'Jumat 21.30 masih dalam jam layanan');
select ok(not cs.is_open('2026-10-30 22:00+07'), 'Jumat 22.00 jam layanan sudah tutup');
select is(cs.next_open_at('2026-10-30 22:30+07'), '2026-10-31 09:00+07'::timestamptz,
  'Setelah tutup, CS buka lagi Sabtu 09.00');
select is(cs.next_open_at('2026-10-31 10:00+07'), '2026-10-31 10:00+07'::timestamptz,
  'Saat jam layanan, waktu buka berikutnya adalah sekarang');
select is(cs.next_open_at('2026-12-23 22:30+07'), '2026-12-26 09:00+07'::timestamptz,
  'CS tutup saat cuti bersama dan Natal, buka lagi Sabtu');
select ok(cs.is_open('2026-12-31 10:00+07') and not cs.is_business_day('2026-12-31'),
  'Libur bursa bukan hari kerja, tetapi CS tetap buka');
select ok(cs.is_market_hours('2026-11-02 10:00+07'), 'Senin 10.00 termasuk jam bursa');
select ok(not cs.is_market_hours('2026-11-02 16:30+07') and not cs.is_market_hours('2026-10-31 10:00+07')
          and not cs.is_market_hours('2026-12-31 10:00+07'), 'Di luar jam bursa, akhir pekan, dan libur bursa');

select is(cs.format_time('2026-10-31 09:00+07', 'id'), 'Sabtu, 31 Oktober 2026 pukul 09.00 WIB', 'Format waktu Indonesia');
select is(cs.format_time('2026-10-31 09:00+07', 'en'), 'Saturday, 31 October 2026, 09:00 WIB', 'Format waktu Inggris');

select is(cs.set_setting('session.reopen_minutes', '45', null), 2, 'Perubahan pengaturan menaikkan versi');
select is((select old_value::text || '>' || new_value::text from cs.cs_settings_history where key = 'session.reopen_minutes'),
  '30>45', 'Riwayat menyimpan nilai lama dan baru');
select is(cs.set_setting('session.reopen_minutes', '45', null), 2, 'Nilai yang sama tidak membuat versi baru');
select throws_ok($$select cs.set_setting('session.reopen_minutes', '"empat puluh lima"', null)$$,
  'PT400', 'invalid_setting', 'Tipe nilai pengaturan diperiksa');
select throws_ok($$update cs.cs_settings_history set new_value = '1'$$, '42501', null,
  'Riwayat pengaturan tidak bisa diubah');

select cs.set_setting('service.hours',
  '{"1": ["08:00", "22:00"], "2": ["08:00", "22:00"], "3": ["08:00", "22:00"], "4": ["08:00", "22:00"], "5": ["08:00", "22:00"], "6": ["10:00", "14:00"]}',
  null) as hours_version \gset
select is(cs.next_open_at('2026-10-30 22:30+07'), '2026-10-31 10:00+07'::timestamptz,
  'Jam layanan dari pengaturan langsung dipakai');

select * from finish();
rollback;
