export const agentStatuses = ['online', 'busy', 'break', 'offline'] as const
export type AgentStatus = (typeof agentStatuses)[number]

export type Localized = { id: string; en: string }

export type AgentSettings = {
  wait_warn_minutes: number
  wait_late_minutes: number
  idle_logout_minutes: number
  assignment_mode: string
  outcomes: Record<string, Localized>
}

export type AgentProfile = {
  id: string
  agent_code: string
  display_name: string
  roles: string[]
  team: string | null
  languages: string[]
  max_active_tickets: number
  status: AgentStatus
  reason: string | null
  active_tickets: number
  skills: Record<string, number>
  settings: AgentSettings
}

export type OnlineAgent = {
  id: string
  display_name: string
  agent_code: string | null
  roles: string[]
  status: AgentStatus
  active_tickets: number
  max_active_tickets: number
  can_take: boolean
}

export const defaultSettings: AgentSettings = {
  wait_warn_minutes: 5,
  wait_late_minutes: 15,
  idle_logout_minutes: 30,
  assignment_mode: 'claim',
  outcomes: {},
}

export function normalizeAgent(raw: AgentProfile): AgentProfile {
  return {
    ...raw,
    status: agentStatuses.includes(raw.status) ? raw.status : 'offline',
    roles: raw.roles ?? [],
    settings: { ...defaultSettings, ...raw.settings },
  }
}

export const isSupervisor = (agent: Pick<AgentProfile, 'roles'>) => agent.roles.includes('cs_supervisor')
export const isAdmin = (agent: Pick<AgentProfile, 'roles'>) => agent.roles.includes('cs_admin')
export const handlesTickets = (agent: Pick<AgentProfile, 'roles'>) =>
  agent.roles.includes('cs_agent') || agent.roles.includes('cs_supervisor')
export const atCapacity = (agent: Pick<AgentProfile, 'active_tickets' | 'max_active_tickets'>) =>
  agent.active_tickets >= agent.max_active_tickets
