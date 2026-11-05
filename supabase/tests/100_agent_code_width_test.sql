begin;
select plan(5);

select is(private.agent_code(7), 'CS-0007', 'Nomor kecil tetap 4 digit');
select is(private.agent_code(9999), 'CS-9999', 'Batas 4 digit tidak berubah');
select is(private.agent_code(10117), 'CS-10117', 'Nomor di atas 9999 tidak dipotong');
select ok(private.agent_code(10117) <> private.agent_code(1011), 'Nomor 5 digit tidak bentrok dengan nomor 4 digit');
select ok(private.agent_code(123456) ~ '^CS-[0-9]{4,}$', 'Kode tetap sesuai constraint agent_code');

select * from finish();
rollback;
