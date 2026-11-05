import { presenceApi } from '@/features/presence/api'
import { ApiError, toApiError } from '@/lib/errors'
import { logger } from '@/lib/logger'
import { rpc, supabase } from '@/lib/supabase'

import { normalizeProfile, normalizeStats } from './logic'
import type { MyProfile, MyStats, PasswordChangeResult, StatsPeriod } from './types'

async function currentEmail() {
  const { data, error } = await supabase().auth.getSession()
  const email = data.session?.user.email
  if (error || !email) throw new ApiError('session_expired', undefined, 401)
  return email
}

export const accountApi = {
  profile: async (): Promise<MyProfile> =>
    normalizeProfile(await rpc<Partial<MyProfile> | null>('agent_my_profile')),

  stats: async (period: StatsPeriod): Promise<MyStats> =>
    normalizeStats(await rpc<Partial<MyStats> | null>('agent_my_stats', { p_period: period }), period),

  changePassword: async (current: string, next: string): Promise<PasswordChangeResult> => {
    const auth = supabase().auth
    const email = await currentEmail()
    const verified = await auth.signInWithPassword({ email, password: current })
    if (verified.error) {
      const error = toApiError(verified.error)
      throw error.code === 'invalid_credentials'
        ? new ApiError('wrong_current_password', undefined, 400)
        : error
    }
    const updated = await auth.updateUser({ password: next })
    if (updated.error) throw toApiError(updated.error)
    const others = await auth.signOut({ scope: 'others' })
    if (others.error) logger.warn('Other sessions stayed signed in after the password change', others.error)
    await rpc('agent_password_changed').catch((error: unknown) =>
      logger.warn('Password change audit could not be recorded', error),
    )
    return { othersSignedOut: !others.error }
  },

  signOutEverywhere: async (goOffline: boolean) => {
    await rpc('agent_signed_out_everywhere')
    if (goOffline) await presenceApi.setStatus('offline').catch(() => undefined)
    const { error } = await supabase().auth.signOut({ scope: 'global' })
    if (error) throw toApiError(error)
  },
}
