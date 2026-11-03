import type { DateRange } from '@/features/reports/types'
import { rpc } from '@/lib/supabase'

import type { CommunityAnalytics } from './types'

export const analyticsApi = {
  community: async (range: DateRange): Promise<CommunityAnalytics> => {
    const raw = await rpc<CommunityAnalytics>('admin_analytics', { p_from: range.from, p_to: range.to })
    return {
      ...raw,
      active_users: { ...raw.active_users, dau: raw.active_users.dau ?? [] },
      retention: (raw.retention ?? []).map((cohort) => ({ ...cohort, weeks: cohort.weeks ?? [] })),
      content: { ...raw.content, daily: raw.content.daily ?? [] },
      top_stocks: raw.top_stocks ?? [],
      events: raw.events ?? {},
      order_taps: {
        ...raw.order_taps,
        by_source: raw.order_taps.by_source ?? {},
        top_stocks: raw.order_taps.top_stocks ?? [],
      },
    }
  },
}
