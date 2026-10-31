type Json = Record<string, unknown>

class ApiError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message)
  }
}

const required = (name: string): string => {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`${name} belum diatur`)
  return value
}

const gateway = required('SUPABASE_URL')
const anonKey = required('SUPABASE_ANON_KEY')
const serviceKey = required('SUPABASE_SERVICE_ROLE_KEY')

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const emailPattern = /^[^\s@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$/
const passwordAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
const permanentBan = '876000h'

const authMessages: Record<string, [number, string]> = {
  email_exists: [409, 'Email sudah dipakai akun lain'],
  weak_password: [400, 'Password sementara ditolak kebijakan password'],
  user_not_found: [404, 'Akun login tidak ditemukan'],
}

function upstreamError(status: number, body: Json | null): ApiError {
  if (typeof body?.code === 'string' && body.code.startsWith('PT')) {
    return new ApiError(Number(body.code.slice(2)) || status, String(body.message), String(body.details ?? ''))
  }
  const authCode = typeof body?.error_code === 'string' ? body.error_code : ''
  const known = authMessages[authCode]
  if (known) return new ApiError(known[0], authCode, known[1])
  if (status === 401) return new ApiError(401, 'session_expired', 'Sesi berakhir, silakan login ulang')
  return new ApiError(502, 'upstream_failed', 'Layanan sedang bermasalah, coba lagi')
}

async function request(path: string, token: string, method: string, body?: unknown, schema?: string): Promise<unknown> {
  const headers: Record<string, string> = {
    apikey: token === serviceKey ? serviceKey : anonKey,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  }
  if (schema) headers['Content-Profile'] = schema
  const response = await fetch(`${gateway}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await response.text()
  let data: unknown = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = null
  }
  if (!response.ok) throw upstreamError(response.status, data as Json | null)
  return data
}

const rpc = (name: string, token: string, args: Json) => request(`/rest/v1/rpc/${name}`, token, 'POST', args, 'cs_api')

const authAdmin = (method: string, path: string, body?: unknown) =>
  request(`/auth/v1/admin/${path}`, serviceKey, method, body)

function temporaryPassword(length = 20): string {
  const limit = 256 - (256 % passwordAlphabet.length)
  const chars: string[] = []
  while (chars.length < length) {
    for (const byte of crypto.getRandomValues(new Uint8Array(length * 2))) {
      if (byte < limit && chars.length < length) chars.push(passwordAlphabet[byte % passwordAlphabet.length])
    }
  }
  return chars.join('')
}

async function requireSuperAdmin(token: string): Promise<string> {
  const me = (await rpc('agent_me', token, {})) as Json
  const roles = Array.isArray(me.roles) ? me.roles : []
  if (!roles.includes('cs_super_admin')) throw new ApiError(403, 'role_forbidden', 'Peran Anda tidak cukup untuk aksi ini')
  return String(me.id)
}

function agentFields(body: Json) {
  return {
    p_display_name: typeof body.display_name === 'string' ? body.display_name.trim() : '',
    p_roles: Array.isArray(body.roles) ? body.roles.map(String) : [],
    p_team: typeof body.team === 'string' && body.team ? body.team : null,
    p_max_active_tickets: Number.isInteger(body.max_active_tickets) ? body.max_active_tickets : 0,
  }
}

async function createAgent(adminId: string, body: Json): Promise<Response> {
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''
  if (!emailPattern.test(email)) throw new ApiError(400, 'invalid_email', 'Format email tidak valid')
  const password = temporaryPassword()
  const user = (await authAdmin('POST', 'users', {
    email,
    password,
    email_confirm: true,
    app_metadata: { cs_staff: true },
    user_metadata: { must_change_password: true },
  })) as Json
  const userId = String(user.id)
  try {
    const agent = await rpc('service_create_agent', serviceKey, { p_user_id: userId, ...agentFields(body), p_created_by: adminId })
    console.log(`cs-admin: akun CS ${userId} dibuat oleh ${adminId}`)
    return Response.json({ agent, temporary_password: password }, { status: 201 })
  } catch (error) {
    await authAdmin('DELETE', `users/${userId}`).catch(() => undefined)
    throw error
  }
}

async function updateAgent(token: string, agentId: string, body: Json): Promise<Response> {
  if (!uuidPattern.test(agentId)) throw new ApiError(400, 'invalid_agent', 'ID akun CS tidak valid')
  const disabled = body.disabled === true
  const agent = await rpc('admin_update_agent', token, { p_agent_id: agentId, ...agentFields(body), p_disabled: disabled })
  try {
    await authAdmin('PUT', `users/${agentId}`, { ban_duration: disabled ? permanentBan : 'none' })
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'user_not_found')) throw error
  }
  return Response.json({ agent })
}

async function resetPassword(token: string, agentId: string): Promise<Response> {
  if (!uuidPattern.test(agentId)) throw new ApiError(400, 'invalid_agent', 'ID akun CS tidak valid')
  const agent = await rpc('admin_reset_password', token, { p_agent_id: agentId })
  const password = temporaryPassword()
  await authAdmin('PUT', `users/${agentId}`, { password, user_metadata: { must_change_password: true } })
  console.log(`cs-admin: password akun CS ${agentId} direset`)
  return Response.json({ agent, temporary_password: password })
}

async function readBody(req: Request): Promise<Json> {
  const text = await req.text()
  if (!text.trim()) return {}
  try {
    const body: unknown = JSON.parse(text)
    if (body && typeof body === 'object' && !Array.isArray(body)) return body as Json
  } catch {
    throw new ApiError(400, 'invalid_body', 'Isi permintaan harus JSON')
  }
  throw new ApiError(400, 'invalid_body', 'Isi permintaan harus JSON')
}

async function handle(req: Request): Promise<Response> {
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!token) throw new ApiError(401, 'session_expired', 'Sesi berakhir, silakan login ulang')
  const parts = new URL(req.url).pathname.split('/').filter(Boolean)
  const reset = parts.length === 4 && parts[3] === 'reset-password'
  if (parts[0] !== 'cs-admin' || parts[1] !== 'agents' || (parts.length > 3 && !reset)) {
    throw new ApiError(404, 'not_found', 'Alamat tidak dikenal')
  }
  const body = await readBody(req)
  const adminId = await requireSuperAdmin(token)
  if (req.method === 'POST' && parts.length === 2) return await createAgent(adminId, body)
  if (req.method === 'PATCH' && parts.length === 3) return await updateAgent(token, parts[2], body)
  if (req.method === 'POST' && reset) return await resetPassword(token, parts[2])
  throw new ApiError(405, 'method_not_allowed', 'Metode tidak didukung')
}

Deno.serve(async (req) => {
  try {
    return await handle(req)
  } catch (error) {
    if (error instanceof ApiError) {
      return Response.json({ code: error.code, message: error.message }, { status: error.status })
    }
    console.error(`cs-admin: ${error instanceof Error ? error.name : 'error'}`)
    return Response.json({ code: 'internal', message: 'Terjadi kesalahan, coba lagi' }, { status: 500 })
  }
})
