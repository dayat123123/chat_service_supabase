import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import type { AppEnv } from '@/config/env'
import { fromPostgrest } from '@/lib/errors'
import type { Database } from '@/types/database'

export type Client = SupabaseClient<Database, 'cs_api'>
export type Functions = Database['cs_api']['Functions']

let current: { client: Client; env: AppEnv } | undefined
let cachedToken: string | null = null

export function reconnectDelay(tries: number) {
  const base = Math.min(30_000, 1_000 * 2 ** Math.max(0, tries - 1))
  return Math.round(base * (0.5 + Math.random() * 0.5))
}

export function initSupabase(env: AppEnv, storage: Storage = window.sessionStorage): Client {
  const client = createClient<Database, 'cs_api'>(env.supabaseUrl, env.anonKey, {
    db: { schema: 'cs_api' },
    auth: {
      storage,
      storageKey: 'cs-console.auth',
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
    realtime: {
      reconnectAfterMs: reconnectDelay,
      heartbeatIntervalMs: 20_000,
      worker: typeof Worker !== 'undefined',
    },
    global: { headers: { 'X-Client-Info': 'cs-console-react/0.1.0' } },
  })
  current = { client, env }
  client.auth.onAuthStateChange((_event, session) => {
    cachedToken = session?.access_token ?? null
  })
  return client
}

export function cachedAccessToken() {
  return cachedToken
}

export function supabase(): Client {
  if (!current) throw new Error('Supabase belum diinisialisasi')
  return current.client
}

export function appEnv(): AppEnv {
  if (!current) throw new Error('Supabase belum diinisialisasi')
  return current.env
}

type NullableArgs<T> = { [P in keyof T]: T[P] | null }

export async function rpc<T, K extends keyof Functions = keyof Functions>(
  name: K,
  args?: NullableArgs<Functions[K]['Args']>,
): Promise<T> {
  const { data, error, status } = await supabase().rpc(name as never, (args ?? {}) as never)
  if (error) throw fromPostgrest(error, status)
  return data
}

export async function accessToken(): Promise<string> {
  const { data } = await supabase().auth.getSession()
  const token = data.session?.access_token
  if (!token) throw fromPostgrest({ code: 'PGRST301', message: 'session' }, 401)
  return token
}
