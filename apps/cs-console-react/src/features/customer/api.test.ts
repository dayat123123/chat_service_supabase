import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest'

import { ApiError } from '@/lib/errors'
import { authStorageKey, initSupabase, supabase } from '@/lib/supabase'
import { memoryStorage } from '@/test/storage'

import { customerApi } from './api'

const base = 'http://cs.test'
const customerId = '44444444-4444-4444-8444-444444444444'
const rpcUrl = (name: string) => `${base}/rest/v1/rpc/${name}`
const token = 'test-access-token'

const server = setupServer()

beforeAll(() => {
  const storage = memoryStorage()
  const now = Math.floor(Date.now() / 1000)
  storage.setItem(
    authStorageKey(storage),
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
  initSupabase({ supabaseUrl: base, anonKey: 'anon-key-for-tests-000000', appEnv: 'development' }, storage)
  server.listen({ onUnhandledFrame: 'error' })
})

afterEach(() => server.resetHandlers())

afterAll(async () => {
  server.close()
  await supabase().auth.stopAutoRefresh()
})

describe('customer data client', () => {
  it('reads the ticket history from cs_api with the agent token', async () => {
    const item = {
      id: '55555555-5555-4555-8555-555555555555',
      ticket_number: 'CS-000101',
      topic: 'order',
      status: 'closed',
      flags: [],
      created_at: '2026-10-01T02:00:00.000Z',
      resolved_at: '2026-10-01T03:00:00.000Z',
      closed_at: '2026-10-02T03:00:00.000Z',
      outcome: 'answered',
      rating: 5,
      agent: 'Rina',
    }
    server.use(
      http.post(rpcUrl('customer_history'), async ({ request }) => {
        expect(request.headers.get('authorization')).toBe(`Bearer ${token}`)
        expect(request.headers.get('apikey')).toBe('anon-key-for-tests-000000')
        expect(request.headers.get('content-profile')).toBe('cs_api')
        expect(await request.json()).toEqual({ p_customer_id: customerId })
        return HttpResponse.json([item])
      }),
    )
    await expect(customerApi.history(customerId)).resolves.toEqual([item])
  })

  it('reads the agent notes for the customer', async () => {
    server.use(
      http.post(rpcUrl('notes'), async ({ request }) => {
        expect(await request.json()).toEqual({ p_customer_id: customerId })
        return HttpResponse.json([
          { id: 'n1', kind: 'note', body: 'Minta ditelepon balik', created_at: '2026-10-30T02:00:00.000Z' },
        ])
      }),
    )
    await expect(customerApi.notes(customerId)).resolves.toMatchObject([{ id: 'n1', kind: 'note' }])
  })

  it('maps API errors and an expired session', async () => {
    server.use(
      http.post(rpcUrl('customer_history'), () =>
        HttpResponse.json(
          { code: 'PT403', message: 'agent_required', details: 'Butuh akun CS aktif dengan 2FA', hint: null },
          { status: 403 },
        ),
      ),
      http.post(rpcUrl('notes'), () =>
        HttpResponse.json(
          { code: 'PGRST301', message: 'JWT expired', details: null, hint: null },
          { status: 401 },
        ),
      ),
    )
    const error: unknown = await customerApi.history(customerId).catch((reason: unknown) => reason)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({
      code: 'agent_required',
      detail: 'Butuh akun CS aktif dengan 2FA',
      status: 403,
    })
    await expect(customerApi.notes(customerId)).rejects.toMatchObject({ code: 'session_expired' })
  })
})
