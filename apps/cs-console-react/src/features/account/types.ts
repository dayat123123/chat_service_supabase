export const statsPeriods = ['today', '7d', '30d'] as const
export type StatsPeriod = (typeof statsPeriods)[number]

export const ratingValues = [5, 4, 3, 2, 1] as const
export type RatingValue = (typeof ratingValues)[number]

export type LocalizedName = { id: string; en: string }

export type MyProfile = {
  id: string
  agent_code: string
  display_name: string
  email: string | null
  roles: string[]
  team: string | null
  team_name: LocalizedName | null
  languages: string[]
  max_active_tickets: number
  nasabah_permissions: string[]
  community_permissions: string[]
  created_at: string | null
  password_changed_at: string | null
}

export type MyStats = {
  period: StatsPeriod
  from: string
  to: string
  handled: number
  resolved: number
  active_tickets: number
  avg_first_response_minutes: number | null
  avg_resolution_minutes: number | null
  avg_rating: number | null
  ratings: number
  rating_counts: Record<RatingValue, number>
  complaints: number
}

export type RatingRow = { rating: RatingValue; count: number; ratio: number }

export type AccountDialog = 'profile' | 'performance' | 'password' | 'signOutEverywhere'

export type PasswordValues = { current: string; next: string; confirm: string }

export type PasswordChangeResult = { othersSignedOut: boolean }
