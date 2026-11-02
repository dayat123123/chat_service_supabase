import type { AgentProfile } from '@/features/presence/types'
import type { ApiError } from '@/lib/errors'

export type AuthStep = { kind: 'signedOut' } | { kind: 'password' } | { kind: 'verified' }

export type SignOutReason = 'manual' | 'idle' | 'expired' | 'notStaff'

export type AuthPhase =
  | { kind: 'checking' }
  | { kind: 'signedOut'; reason?: SignOutReason }
  | { kind: 'password' }
  | { kind: 'ready'; agent: AgentProfile }

export type AuthState = {
  phase: AuthPhase
  busy: boolean
  error: ApiError | null
}
