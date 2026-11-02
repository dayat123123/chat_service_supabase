export const agentStatuses = ['online', 'busy', 'break', 'offline'] as const
export type AgentStatus = (typeof agentStatuses)[number]

export type Localized = { id: string; en: string }

export type AgentSettings = {
  wait_warn_minutes: number
  wait_late_minutes: number
  idle_logout_minutes: number
  assignment_mode: string
  outcomes: Record<string, Localized>
  nasabah_ready: boolean
  community_four_eyes: boolean
  community_push_ready: boolean
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
  nasabah_permissions: string[]
  community_permissions: string[]
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
  nasabah_ready: false,
  community_four_eyes: true,
  community_push_ready: false,
}

export function normalizeAgent(raw: AgentProfile): AgentProfile {
  return {
    ...raw,
    status: agentStatuses.includes(raw.status) ? raw.status : 'offline',
    roles: raw.roles ?? [],
    nasabah_permissions: raw.nasabah_permissions ?? [],
    community_permissions: raw.community_permissions ?? [],
    settings: { ...defaultSettings, ...raw.settings },
  }
}

export const isSuperAdmin = (agent: Pick<AgentProfile, 'roles'>) => agent.roles.includes('cs_super_admin')
export const worksTickets = (agent: Pick<AgentProfile, 'roles'>) => agent.roles.includes('cs_agent')
export const hasNasabah = (agent: Pick<AgentProfile, 'nasabah_permissions'>) =>
  agent.nasabah_permissions.length > 0
export const isCompliance = (agent: Pick<AgentProfile, 'roles'>) => agent.roles.includes('compliance')
export const isMonitor = (agent: Pick<AgentProfile, 'roles'>) => isSuperAdmin(agent) && !worksTickets(agent)
export const hasCommunityAccess = (agent: Pick<AgentProfile, 'community_permissions'>) =>
  agent.community_permissions.length > 0
export const canViewTickets = (agent: Pick<AgentProfile, 'roles'>) =>
  worksTickets(agent) || isSuperAdmin(agent)
export const atCapacity = (agent: Pick<AgentProfile, 'active_tickets' | 'max_active_tickets'>) =>
  agent.active_tickets >= agent.max_active_tickets

export type GuardedAction = 'claim' | 'acceptTransfer' | 'reply'
export type ActionBlock = 'needOnline' | 'capacity' | 'offline'

export function actionBlock(
  agent: Pick<AgentProfile, 'status' | 'active_tickets' | 'max_active_tickets'>,
  action: GuardedAction,
): ActionBlock | null {
  if (action === 'reply') return agent.status === 'offline' ? 'offline' : null
  if (agent.status !== 'online') return 'needOnline'
  return atCapacity(agent) ? 'capacity' : null
}
