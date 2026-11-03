create or replace function private.health_service_label(p_service text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_service
    when 'media' then 'Upload media'
    when 'sentinel' then 'Pemantau sistem'
    when 'backup' then 'Backup'
    when 'notifier' then 'Notifier push'
    when 'janitor' then 'Pembersih storage'
    when 'auth-bridge' then 'Auth bridge'
    when 'nasabah-gateway' then 'Gateway nasabah'
    when 'rest' then 'API (PostgREST)'
    when 'auth' then 'Login staf (GoTrue)'
    when 'storage' then 'Storage'
    when 'realtime' then 'Realtime'
    when 'functions' then 'Edge Functions'
    when 'imgproxy' then 'Imgproxy'
    when 'kong' then 'Kong'
    when 'valkey' then 'Valkey'
    when 'pgbouncer' then 'PgBouncer'
    when 'db' then 'Database'
    when 'cs-console' then 'Web CS'
    when 'integration' then 'Gateway integrasi'
    when 'link-preview' then 'Pratinjau link'
    when 'classifier' then 'Klasifikasi gambar'
    else p_service
  end;
$$;

update private.settings
   set value = (select jsonb_agg(distinct x order by x)
                from jsonb_array_elements_text(value || '["integration", "link-preview", "classifier"]') x)
 where key = 'health.expected_services';
