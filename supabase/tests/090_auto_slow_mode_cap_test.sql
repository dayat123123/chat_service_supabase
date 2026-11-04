begin;
select plan(10);

update private.settings set value = 'true' where key = 'manipulation.auto_slow_mode';
update private.settings set value = '10' where key = 'rooms.busy_slow_mode';
update private.settings set value = '60' where key = 'manipulation.auto_slow_mode_minutes';
delete from cs.manipulation_alerts where stock like 'ASM%';

create function pg_temp.alert(p_stock text) returns cs.manipulation_alerts language sql as $$
  insert into cs.manipulation_alerts (stock, kind, score, evidence)
  values (p_stock, 'mention_spike', 99, '{}')
  returning *;
$$;

create function pg_temp.slow(p_stock text) returns text language sql as $$
  select m.slow_mode_seconds || '/' || m.slow_mode_source
  from private.room_moderation m
  where m.room_id = private.stock_room_id(p_stock);
$$;

select cs.ensure_stock_room('ASMA') as room_a \gset
select cs.ensure_stock_room('ASMB') as room_b \gset
select cs.ensure_stock_room('ASMC') as room_c \gset
select cs.ensure_stock_room('ASMD') as room_d \gset
select cs.ensure_stock_room('ASME') as room_e \gset

select is((select description from private.settings where key = 'manipulation.auto_slow_mode_seconds'),
  'Aksi otomatis: jeda slow mode (detik), paling ketat sama dengan slow mode jam ramai',
  'Deskripsi pengaturan menyebut batas atas');

update private.settings set value = '30' where key = 'manipulation.auto_slow_mode_seconds';
select cs.manipulation_slow_mode(pg_temp.alert('ASMA'), now());
select is(pg_temp.slow('ASMA'), '10/alert', 'Alert tidak lebih ketat dari slow mode jam ramai 10 detik');
select is((select auto_actions -> 'slow_mode' ->> 'seconds' from cs.manipulation_alerts where stock = 'ASMA'), '10',
  'Aksi otomatis tercatat dengan detik yang dibatasi');

update private.settings set value = '5' where key = 'manipulation.auto_slow_mode_seconds';
select cs.manipulation_slow_mode(pg_temp.alert('ASMB'), now());
select is(pg_temp.slow('ASMB'), '5/alert', 'Pengaturan yang lebih longgar dari batas tetap dipakai');

update private.settings set value = '30' where key = 'manipulation.auto_slow_mode_seconds';
update private.settings set value = '15' where key = 'rooms.busy_slow_mode';
select cs.manipulation_slow_mode(pg_temp.alert('ASMC'), now());
select is(pg_temp.slow('ASMC'), '15/alert', 'Batas mengikuti slow mode jam ramai yang diubah Kepatuhan');

update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
select cs.manipulation_slow_mode(pg_temp.alert('ASMD'), now());
select is(pg_temp.slow('ASMD'), '10/alert', 'Bila slow mode jam ramai mati, batasnya 10 detik');

update private.settings set value = '10' where key = 'rooms.busy_slow_mode';
insert into private.room_moderation (room_id, slow_mode_seconds, slow_mode_until, slow_mode_source)
values (:'room_e', 30, now() + interval '30 minutes', 'alert')
on conflict (room_id) do update set slow_mode_seconds = 30, slow_mode_until = now() + interval '30 minutes',
  slow_mode_source = 'alert';
select cs.manipulation_slow_mode(pg_temp.alert('ASME'), now());
select is(pg_temp.slow('ASME'), '10/alert', 'Slow mode alert lama yang lebih ketat ikut diturunkan');

update private.room_moderation
   set slow_mode_seconds = 30, slow_mode_until = now() + interval '1 hour', slow_mode_source = 'manual', alert_id = null
 where room_id = :'room_a';
delete from cs.manipulation_alerts where stock = 'ASMA';
select cs.manipulation_slow_mode(pg_temp.alert('ASMA'), now());
select is(pg_temp.slow('ASMA'), '30/manual', 'Slow mode manual staf 30 detik tidak diubah oleh alert');

select is((select seconds from private.room_slow_mode(:'room_a')), 30, 'Pengguna merasakan slow mode manual 30 detik');

select ok(not has_function_privilege('authenticated', 'private.auto_slow_mode_cap()', 'execute'),
  'Fungsi batas tidak bisa dipanggil pengguna');

select * from finish();
rollback;
