import type { AgentStatus } from '@/features/presence/types'
import type { Ticket } from '@/features/tickets/types'

export type AgentLoad = {
  id: string
  display_name: string
  agent_code: string | null
  roles: string[]
  status: AgentStatus
  connected: boolean
  active_tickets: number
  max_active_tickets: number
  resolved_today: number
  status_changed_at: string | null
}

export type SupervisorOverview = {
  generated_at: string
  thresholds: { unclaimed_minutes: number; p1_unclaimed_minutes: number }
  open_count: number
  oldest_open_at: string | null
  active_count: number
  resolved_today: number
  overdue: Ticket[]
  flagged_open: Ticket[]
  offline_owned: Ticket[]
  agents: AgentLoad[]
}

export function attentionCount(overview: SupervisorOverview | undefined) {
  if (!overview) return 0
  return new Set(
    [...overview.overdue, ...overview.flagged_open, ...overview.offline_owned].map((ticket) => ticket.id),
  ).size
}
