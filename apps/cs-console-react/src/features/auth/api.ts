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
    const { session } = await unwrap(supabase().auth.getSession())
    if (!session) return { kind: 'signedOut' }
    return session.user.user_metadata?.must_change_password === true
      ? { kind: 'password' }
      : { kind: 'verified' }
  },

  changePassword: async (password: string) => {
    await unwrap(supabase().auth.updateUser({ password, data: { must_change_password: false } }))
  },

  signOut: async () => {
    await supabase().auth.signOut({ scope: 'local' })
  },
}
