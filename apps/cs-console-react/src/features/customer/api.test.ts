import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest'

import { ApiError } from '@/lib/errors'
import { initSupabase, supabase } from '@/lib/supabase'

import { customerApi } from './api'

const base = 'http://cs.test'
const ticketId = '22222222-2222-4222-8222-222222222222'
const route = `${base}/cs/v1/agent/tickets/${ticketId}/customer`
const token = 'test-access-token'

function memoryStorage(): Storage {
  const items = new Map<string, string>()
  return {
    get length() {
      return items.size
    },
    clear: () => items.clear(),
    getItem: (key) => items.get(key) ?? null,
    key: (index) => [...items.keys()][index] ?? null,
    removeItem: (key) => void items.delete(key),
    setItem: (key, value) => void items.set(key, value),
  }
}

const server = setupServer()

beforeAll(() => {
  const storage = memoryStorage()
  const now = Math.floor(Date.now() / 1000)
  storage.setItem(
    'cs-console.auth',
    JSON.stringify({
      access_token: token,
      refresh_token: 'test-refresh-token',
      token_type: 'bearer',
      expires_in: 3600,
      expires_at: now + 3600,
      user: {
        id: '11111111-1111-4111-8111-111111111111',
        aud: 'authenticated',
        role: 'authenticated',
        email: 'cs01@olt.test',
        app_metadata: {},
        user_metadata: {},
        created_at: new Date().toISOString(),
      },
    }),
  )
  initSupabase(
    {
      supabaseUrl: base,
      anonKey: 'anon-key-for-tests-000000',
      appEnv: 'development',
      adapterUrl: `${base}/cs/v1`,
    },
    storage,
  )
  server.listen({ onUnhandledFrame: 'error' })
})

afterEach(() => server.resetHandlers())

afterAll(async () => {
  server.close()
  await supabase().auth.stopAutoRefresh()
})

describe('customer adapter client', () => {
  it('sends the agent token and unwraps the envelope', async () => {
    server.use(
      http.get(`${route}/profile`, ({ request }) => {
        expect(request.headers.get('authorization')).toBe(`Bearer ${token}`)
        expect(request.headers.get('apikey')).toBe('anon-key-for-tests-000000')
        return HttpResponse.json({ available: true, data: { name: 'Budi Santoso', nik: '3174********0001' } })
      }),
    )
    await expect(customerApi.profile(ticketId)).resolves.toEqual({
      name: 'Budi Santoso',
      nik: '3174********0001',
    })
  })

  it('reports OLT outages separately from other errors', async () => {
    server.use(http.get(`${route}/orders`, () => HttpResponse.json({ available: false }, { status: 503 })))
    await expect(customerApi.orders(ticketId)).rejects.toMatchObject({ code: 'olt_unavailable' })
  })

  it('maps an expired session and adapter errors', async () => {
    server.use(
      http.get(`${route}/sessions`, () => HttpResponse.json({ code: 'unauthorized' }, { status: 401 })),
      http.get(`${route}/security`, () =>
        HttpResponse.json({ code: 'not_owner', message: 'Hanya pemilik tiket' }, { status: 403 }),
      ),
    )
    await expect(customerApi.sessions(ticketId)).rejects.toMatchObject({ code: 'session_expired' })
    const error: unknown = await customerApi.security(ticketId).catch((reason: unknown) => reason)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ code: 'not_owner', detail: 'Hanya pemilik tiket', status: 403 })
  })

  it('posts the reveal reason and returns a time-boxed value', async () => {
    server.use(
      http.post(`${route}/reveal`, async ({ request }) => {
        expect(await request.json()).toEqual({ field: 'nik', reason: 'verification' })
        return HttpResponse.json({ available: true, data: { value: '3174012345670001', valid_seconds: 120 } })
      }),
    )
    const before = Date.now()
    const revealed = await customerApi.reveal(ticketId, 'nik', 'verification')
    expect(revealed.value).toBe('3174012345670001')
    expect(revealed.until).toBeGreaterThanOrEqual(before + 120_000)
    expect(revealed.until).toBeLessThanOrEqual(Date.now() + 120_000)
  })
})
