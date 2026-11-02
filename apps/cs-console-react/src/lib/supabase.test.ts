import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'

import { memoryStorage } from '@/test/storage'

import { initSupabase } from './supabase'

const env = {
  supabaseUrl: 'http://cs.test',
  anonKey: 'anon-key-for-tests-000000',
  appEnv: 'development' as const,
}

const base64url = (value: object) =>
  btoa(JSON.stringify(value)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')

function session(email: string) {
  const now = Math.floor(Date.now() / 1000)
  const id = crypto.randomUUID()
  return {
    access_token: `${base64url({ alg: 'HS256', typ: 'JWT' })}.${base64url({ sub: id, role: 'authenticated', aud: 'authenticated', exp: now + 3600 })}.c2ln`,
    refresh_token: `refresh-${id}`,
    token_type: 'bearer',
    expires_in: 3600,
    expires_at: now + 3600,
    user: {
      id,
      aud: 'authenticated',
      role: 'authenticated',
      email,
      app_metadata: {},
      user_metadata: {},
      created_at: new Date().toISOString(),
    },
  }
}

const server = setupServer(
  http.post(`${env.supabaseUrl}/auth/v1/token`, () => HttpResponse.json(session('adi@olt.test'))),
)

beforeAll(() => server.listen({ onUnhandledFrame: 'error' }))
afterAll(() => server.close())

describe('initSupabase', () => {
  it('keeps a sign-in in one tab away from tabs signed in as someone else', async () => {
    const adiTab = memoryStorage()
    const adi = initSupabase(env, adiTab)
    const sameTab = initSupabase(env, adiTab)
    const nadia = initSupabase(env, memoryStorage())
    const seen = { sameTab: [] as string[], nadia: [] as string[] }
    sameTab.auth.onAuthStateChange((event) => void seen.sameTab.push(event))
    nadia.auth.onAuthStateChange((event) => void seen.nadia.push(event))

    await adi.auth.signInWithPassword({ email: 'adi@olt.test', password: 'secret-password' })

    await vi.waitFor(() => expect(seen.sameTab).toContain('SIGNED_IN'))
    expect(seen.nadia).not.toContain('SIGNED_IN')
  })
})
