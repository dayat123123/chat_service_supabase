export type ReportStats = {
  day?: string
  created: number
  resolved: number
  avg_claim_minutes: number | null
  avg_first_response_minutes: number | null
  avg_resolution_minutes: number | null
  avg_rating: number | null
  ratings: number
}

export type AgentReport = {
  id: string
  display_name: string
  agent_code: string | null
  handled: number
  resolved: number
  avg_first_response_minutes: number | null
  avg_rating: number | null
  ratings: number
}

export type TopicCount = { topic: string; name: string; count: number }

export type ReportSummary = {
  from: string
  to: string
  totals: ReportStats
  daily: ReportStats[]
  agents: AgentReport[]
  topics: TopicCount[]
}

export type ReportPreset = 'today' | 'week' | 'month' | 'custom'

export type DateRange = { from: string; to: string }

export type ReportExport = 'daily' | 'agents' | 'topics'

export const MAX_REPORT_DAYS = 93

export const emptyStats: ReportStats = {
  created: 0,
  resolved: 0,
  avg_claim_minutes: null,
  avg_first_response_minutes: null,
  avg_resolution_minutes: null,
  avg_rating: null,
  ratings: 0,
}

export type CustomerReport = {
  id: string
  display_name: string | null
  username: string | null
  tickets: number
  resolved: number
  reopened: number
  complaints: number
  avg_first_response_minutes: number | null
  avg_resolution_minutes: number | null
  avg_rating: number | null
  ratings: number
  closed_unrated: number
  last_ticket_at: string
}

export type TrailEvent = {
  type: string
  actor_type: string | null
  actor_name: string | null
  data: Record<string, unknown>
  created_at: string
}

export type TrailTicket = {
  id: string
  ticket_number: string
  topic: string
  topic_name: string
  status: string
  priority: string
  flags: string[]
  outcome: string | null
  close_reason: string | null
  agent: string | null
  created_at: string
  first_claimed_at: string | null
  first_response_at: string | null
  resolved_at: string | null
  closed_at: string | null
  claim_minutes: number | null
  first_response_minutes: number | null
  resolution_minutes: number | null
  rating: number | null
  rating_comment: string | null
  rated_at: string | null
  reopened: number
  transfers: number
  events: TrailEvent[]
}

export type CustomerTrail = {
  customer: { id: string; display_name: string | null; username: string | null }
  from: string
  to: string
  tickets: TrailTicket[]
}

export const MAX_CUSTOMER_ROWS = 200
