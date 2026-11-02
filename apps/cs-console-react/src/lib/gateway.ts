import { ApiError } from '@/lib/errors'
import { supabase } from '@/lib/supabase'

const BASE = '/api-nasabah'

export type GatewayQuery = Record<string, string | number | undefined>

type ErrorBody = { code?: unknown; message?: unknown }

function parseBody(text: string): ErrorBody | null {
  if (!text) return null
  try {
    return JSON.parse(text) as ErrorBody
  } catch {
    return null
  }
}

const statusCode: Record<number, string> = {
  400: 'bad_request',
  401: 'session_expired',
  403: 'permission_denied',
  404: 'not_found',
  409: 'conflict',
}

export async function gatewayRequest<T>(
  method: 'GET' | 'POST' | 'PUT',
  path: string,
  query: GatewayQuery = {},
  body?: unknown,
): Promise<T> {
  const { data } = await supabase().auth.getSession()
  const token = data.session?.access_token
  if (!token) throw new ApiError('session_expired', undefined, 401)
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== '') params.set(key, String(value))
  }
  const suffix = params.size > 0 ? `?${params.toString()}` : ''
  let response: Response
  try {
    response = await fetch(`${BASE}${path}${suffix}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError('network')
  }
  const json = parseBody(await response.text())
  if (!response.ok) {
    const code =
      typeof json?.code === 'string'
        ? json.code
        : (statusCode[response.status] ?? (response.status >= 500 ? 'upstream_error' : 'unknown'))
    throw new ApiError(code, typeof json?.message === 'string' ? json.message : undefined, response.status)
  }
  return json as T
}
