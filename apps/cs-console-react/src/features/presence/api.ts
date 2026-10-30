import { rpc } from '@/lib/supabase'

import { normalizeAgent, type AgentProfile, type AgentStatus, type OnlineAgent } from './types'

export const presenceApi = {
  me: async () => normalizeAgent(await rpc<AgentProfile>('agent_me')),
  setStatus: async (status: AgentStatus, reason?: string) =>
    normalizeAgent(
      await rpc<AgentProfile>('agent_set_status', { p_status: status, p_reason: reason || undefined }),
    ),
  heartbeat: async () => (await rpc<{ active_tickets?: number }>('agent_heartbeat')).active_tickets ?? 0,
  onlineAgents: () => rpc<OnlineAgent[]>('online_agents'),
}
