export type HistoryItem = {
  id: string
  ticket_number: string | null
  topic: string
  status: string
  flags: string[]
  created_at: string
  resolved_at: string | null
  closed_at: string | null
  outcome: string | null
  rating: number | null
  agent: string | null
}

export type AgentNote = {
  id: string
  kind: string
  body: string
  created_at: string
  ticket_id?: string | null
  session_id?: string | null
  author?: { display_name: string; agent_code?: string | null } | null
}
