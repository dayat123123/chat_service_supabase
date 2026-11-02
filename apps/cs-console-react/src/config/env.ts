import { z } from 'zod'

declare global {
  interface Window {
    __CS_CONSOLE_ENV__?: Record<string, unknown>
  }
}

const schema = z.object({
  SUPABASE_URL: z.url({ protocol: /^https?$/ }),
  SUPABASE_ANON_KEY: z.string().min(20),
  PUBLIC_API_URL: z.url({ protocol: /^https?$/ }).optional(),
  APP_ENV: z.enum(['development', 'staging', 'production']).default('production'),
})

export type AppEnv = {
  supabaseUrl: string
  anonKey: string
  appEnv: 'development' | 'staging' | 'production'
  publicApiUrl?: string
}

export type EnvResult = { ok: true; env: AppEnv } | { ok: false; problems: string[] }

export function readEnv(source: Record<string, unknown> | undefined = window.__CS_CONSOLE_ENV__): EnvResult {
  const parsed = schema.safeParse(source ?? {})
  if (!parsed.success) {
    return { ok: false, problems: parsed.error.issues.map((issue) => issue.path.join('.') || issue.message) }
  }
  return {
    ok: true,
    env: {
      supabaseUrl: parsed.data.SUPABASE_URL.replace(/\/+$/, ''),
      anonKey: parsed.data.SUPABASE_ANON_KEY,
      appEnv: parsed.data.APP_ENV,
      publicApiUrl: (parsed.data.PUBLIC_API_URL ?? parsed.data.SUPABASE_URL).replace(/\/+$/, ''),
    },
  }
}
