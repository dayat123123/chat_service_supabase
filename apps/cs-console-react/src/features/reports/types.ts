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
