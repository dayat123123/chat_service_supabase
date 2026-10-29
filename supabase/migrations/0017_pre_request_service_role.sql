-- 0017_pre_request_service_role.sql
-- PostgREST menjalankan pre-request (private.check_request, 0013) untuk SEMUA role,
-- termasuk service_role yang dipakai auth-bridge. Tanpa grant ini exchange token
-- gagal (permission denied). Fungsinya langsung kembali untuk role selain
-- authenticated.
grant execute on function private.check_request() to service_role;
