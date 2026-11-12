create or replace function private.canonical_stock_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := private.stock_code(new.stock_code);
begin
  if v_code is null then
    raise exception using errcode = 'check_violation', message = 'invalid_stock_code',
      detail = 'Kode saham atau indeks tidak valid';
  end if;
  new.stock_code := v_code;
  return new;
end;
$$;

revoke execute on function private.stock_code_format(text) from public;
grant execute on function private.stock_code_format(text) to authenticated, service_role;
