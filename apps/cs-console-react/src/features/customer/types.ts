export type MaskedAccount = { bank?: string; number?: string }

export type CustomerProfile = {
  name?: string
  client_code?: string
  sid?: string
  nik?: string
  phone?: string
  email?: string
  birth_date?: string
  address?: string
  rdn?: MaskedAccount
  withdrawal_account?: MaskedAccount
  account_status?: string
  kyc_status?: string
  segment?: string
}

export type CustomerOrder = {
  order_id: string
  time?: string
  code?: string
  side?: string
  type?: string
  price?: number
  lot?: number
  filled_lot?: number
  status?: string
  reject_code?: string
  reject_reason?: string
  channel?: string
}

export type CashTransaction = {
  id: string
  time?: string
  kind?: string
  amount?: number
  bank?: string
  status?: string
  bank_ref?: string
  failure_reason?: string
}

export type DeviceSession = {
  id?: string
  device?: string
  platform?: string
  app_version?: string
  ip?: string
  last_active?: string
}

export type LoginEntry = { device?: string; platform?: string; ip?: string; result?: string; time?: string }

export type Sessions = { sessions?: DeviceSession[]; logins?: LoginEntry[] }

export type SecurityStatus = Record<string, string | number | boolean | null>

export type RevealField =
  'client_code' | 'sid' | 'nik' | 'phone' | 'email' | 'birth_date' | 'address' | 'rdn_number' | 'bank_account'

export type Revealed = { field: RevealField; value: string; until: number }

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
