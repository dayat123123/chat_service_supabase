import { create } from 'zustand'

import { presenceApi } from '@/features/presence/api'
import type { AgentProfile } from '@/features/presence/types'
import { toApiError } from '@/lib/errors'
import { supabase } from '@/lib/supabase'

import { authApi } from './api'
import type { AuthPhase, AuthState, SignOutReason } from './types'

type AuthActions = {
  start: () => Promise<void>
  signIn: (email: string, password: string) => Promise<void>
  changePassword: (password: string) => Promise<void>
  signOut: (reason?: SignOutReason) => Promise<void>
  updateAgent: (agent: AgentProfile) => void
}

const cleanups = new Set<() => void>()

export function onSignedOut(cleanup: () => void) {
  cleanups.add(cleanup)
  return () => {
    cleanups.delete(cleanup)
  }
}

let watching = false

export const useAuth = create<AuthState & AuthActions>((set, get) => {
  const advance = async (fresh: boolean) => {
    try {
      const step = await authApi.nextStep()
      let phase: AuthPhase
      switch (step.kind) {
        case 'verified': {
          const agent = fresh ? await presenceApi.setStatus('offline') : await presenceApi.me()
          phase = { kind: 'ready', agent }
          break
        }
        case 'signedOut':
          phase = { kind: 'signedOut' }
          break
        default:
          phase = step
      }
      set({ phase, busy: false, error: null })
    } catch (error) {
      const apiError = toApiError(error)
      if (apiError.code === 'agent_required') {
        await authApi.signOut().catch(() => undefined)
        set({ phase: { kind: 'signedOut', reason: 'notStaff' }, busy: false, error: null })
        return
      }
      set({ phase: { kind: 'signedOut' }, busy: false, error: apiError })
    }
  }

  const watch = () => {
    if (watching) return
    watching = true
    supabase().auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT' && get().phase.kind === 'ready') {
        cleanups.forEach((cleanup) => cleanup())
        set({ phase: { kind: 'signedOut', reason: 'expired' }, busy: false, error: null })
      }
    })
  }

  return {
    phase: { kind: 'checking' },
    busy: false,
    error: null,

    start: async () => {
      watch()
      await advance(false)
    },

    signIn: async (email, password) => {
      set({ busy: true, error: null })
      try {
        await authApi.signIn(email.trim(), password)
        await advance(true)
      } catch (error) {
        set({ busy: false, error: toApiError(error) })
      }
    },

    changePassword: async (password) => {
      set({ busy: true, error: null })
      try {
        await authApi.changePassword(password)
        await advance(true)
      } catch (error) {
        set({ busy: false, error: toApiError(error) })
      }
    },

    signOut: async (reason = 'manual') => {
      if (get().phase.kind === 'ready') await presenceApi.setStatus('offline').catch(() => undefined)
      await authApi.signOut().catch(() => undefined)
      cleanups.forEach((cleanup) => cleanup())
      set({ phase: { kind: 'signedOut', reason }, busy: false, error: null })
    },

    updateAgent: (agent) => {
      if (get().phase.kind === 'ready') set({ phase: { kind: 'ready', agent } })
    },
  }
})

export function useAgent(): AgentProfile {
  const phase = useAuth((state) => state.phase)
  if (phase.kind !== 'ready') throw new Error('Agent belum siap')
  return phase.agent
}
