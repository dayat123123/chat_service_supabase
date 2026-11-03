import { useQuery } from '@tanstack/react-query'

import type { DateRange } from '@/features/reports/types'

import { analyticsApi } from './api'

export const analyticsKeys = {
  community: (range: DateRange) => ['analytics', 'community', range.from, range.to] as const,
}

export function useCommunityAnalytics(range: DateRange) {
  return useQuery({
    queryKey: analyticsKeys.community(range),
    queryFn: () => analyticsApi.community(range),
    placeholderData: (previous) => previous,
    staleTime: 5 * 60_000,
  })
}
