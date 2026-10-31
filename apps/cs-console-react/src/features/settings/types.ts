import type { AgentStatus } from '@/features/presence/types'

export const staffRoles = ['cs_agent', 'cs_super_admin', 'compliance'] as const
export type StaffRole = (typeof staffRoles)[number]

export type StaffAccount = {
  id: string
  agent_code: string
  display_name: string
  email: string | null
  roles: string[]
  team: string | null
  max_active_tickets: number
  disabled_at: string | null
  status: AgentStatus
  active_tickets: number
  created_at: string | null
}

export type AccountDraft = {
  email?: string
  display_name: string
  roles: string[]
  team: string
  max_active_tickets: number
  disabled: boolean
}

export type CreatedAccount = { agent: StaffAccount; temporary_password: string }

export type Choice = { code: string; name: string }

export type AdminOptions = { teams: Choice[]; skills: Choice[] }

export type TopicConfig = {
  code: string
  name_id: string
  name_en: string
  skill: string
  default_priority: string
  help_url: string | null
  sort_order: number
  active: boolean
}

export type QuickReplyConfig = {
  id: string | null
  shortcut: string
  title: string
  body: string
  language: 'id' | 'en'
  active: boolean
  updated_at?: string | null
}

export type SettingEntry = {
  key: string
  value: unknown
  description: string | null
  version: number
  updated_at: string | null
  updated_by: string | null
}

export type SavedSetting = Pick<SettingEntry, 'key' | 'value' | 'version' | 'updated_at'>

export const holidayKinds = ['national', 'collective_leave', 'exchange'] as const
export type HolidayKind = (typeof holidayKinds)[number]

export type Holiday = { day: string; name: string; kind: HolidayKind }

export const settingsSections = [
  'accounts',
  'topics',
  'quickReplies',
  'hours',
  'messages',
  'assignment',
] as const
export type SettingsSection = (typeof settingsSections)[number]

export const isStaffRole = (role: string): role is StaffRole =>
  (staffRoles as readonly string[]).includes(role)
