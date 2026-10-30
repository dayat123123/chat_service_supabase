begin;
select plan(14);

select is((cs.mask_sensitive('OTP saya 123456 tolong cek')).masked, 'OTP saya ****** tolong cek', 'OTP disamarkan');
select is((cs.mask_sensitive('kartu 4111 1111 1111 1111')).masked, 'kartu **** **** **** 1111',
  'Nomor kartu valid (Luhn) disamarkan, 4 digit terakhir tetap');
select is((cs.mask_sensitive('kartu 4111 1111 1111 1112')).masked, 'kartu 4111 1111 1111 1112',
  'Angka mirip kartu yang tidak lolos Luhn tidak disamarkan');
select is((cs.mask_sensitive('rekening 1234567890, hp 081234567890 / +6281234567890')).masked,
  'rekening ******7890, hp 081234567890 / +6281234567890', 'Rekening disamarkan, nomor HP tidak');
select is((cs.mask_sensitive('NIK saya 3174056708900001')).masked, 'NIK saya 3174********0001', 'NIK disamarkan');
select is((cs.mask_sensitive('password: Rahasia123')).masked, 'password: ********', 'Password disamarkan');
select is((cs.mask_sensitive('password saya lupa, tolong reset')).masked, 'password saya lupa, tolong reset',
  'Menyebut lupa password tidak disamarkan');
select is((cs.mask_sensitive('PIN saya terblokir')).kinds, '{}'::text[], 'Menyebut PIN tanpa angka tidak disamarkan');
select is((cs.mask_sensitive(' 482913 ')).masked, '******', 'Pesan yang hanya berisi kode angka dianggap OTP');
select is((cs.mask_sensitive('OTP 123456, rekening 1234567890')).kinds, '{account,otp}'::text[],
  'Jenis data yang disamarkan dicatat');
select ok(cs.requests_secret('Mohon kirimkan kode OTP Anda') and cs.requests_secret('Please send me your password')
          and cs.requests_secret('OTP-nya berapa ya Pak?'), 'Permintaan data rahasia terdeteksi');
select ok(not cs.requests_secret('Jangan berikan OTP kepada siapa pun.')
          and not cs.requests_secret('Mohon maaf, PIN Anda terblokir.'), 'Edukasi dan pemberitahuan biasa tidak ditahan');

select tests.create_user('cs_mask_budi') as budi \gset
select tests.authenticate_as(:'budi');
select is(cs_api.check_sensitive('OTP saya 123456') - 'requests_secret',
  '{"kinds": ["otp"], "masked": true, "preview": "OTP saya ******"}'::jsonb,
  'Aplikasi bisa memperingatkan nasabah sebelum mengirim data sensitif');
select is(cs_api.check_sensitive('Sebutkan PIN Anda') ->> 'requests_secret', 'true',
  'Panel CS bisa memeriksa pesan agen sebelum dikirim');

select * from finish();
rollback;
