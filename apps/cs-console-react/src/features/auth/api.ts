import { toApiError } from '@/lib/errors'
import { supabase } from '@/lib/supabase'

import type { AuthStep } from './types'

type Result<T> = { data: T; error: null } | { data: unknown; error: unknown }

async function unwrap<T>(promise: Promise<Result<T>>): Promise<NonNullable<T>> {
  const result = await promise
  if (result.error || result.data === null || result.data === undefined) throw toApiError(result.error)
  return result.data as NonNullable<T>
}

export const authApi = {
  signIn: async (email: string, password: string) => {
    await unwrap(supabase().auth.signInWithPassword({ email, password }))
  },

  nextStep: async (): Promise<AuthStep> => {
    const auth = supabase().auth
    const { session } = await unwrap(auth.getSession())
    if (!session) return { kind: 'signedOut' }
    const mustChangePassword = session.user.user_metadata?.must_change_password === true
    const level = await unwrap(auth.mfa.getAuthenticatorAssuranceLevel())
    if (level.currentLevel === 'aal2') return mustChangePassword ? { kind: 'password' } : { kind: 'verified' }
    const factors = await unwrap(auth.mfa.listFactors())
    const verified = factors.totp[0]
    if (verified) return { kind: 'totp', factorId: verified.id }
    if (mustChangePassword) return { kind: 'password' }
    for (const factor of factors.all.filter((f) => f.status !== 'verified')) {
      await unwrap(auth.mfa.unenroll({ factorId: factor.id }))
    }
    const enrolled = await unwrap(
      auth.mfa.enroll({ factorType: 'totp', issuer: 'OLT CS Console', friendlyName: 'CS Console' }),
    )
    return { kind: 'enroll', factorId: enrolled.id, secret: enrolled.totp.secret, qr: enrolled.totp.qr_code }
  },

  verify: async (factorId: string, code: string) => {
    const auth = supabase().auth
    await unwrap(auth.mfa.challengeAndVerify({ factorId, code }))
    const { session } = await unwrap(auth.getSession())
    await supabase().realtime.setAuth(session?.access_token ?? null)
  },

  changePassword: async (password: string) => {
    await unwrap(supabase().auth.updateUser({ password, data: { must_change_password: false } }))
  },

  signOut: async () => {
    await supabase().auth.signOut({ scope: 'local' })
  },
}
