import { useQuery } from '@tanstack/react-query'

import { reportsApi } from './api'
import type { DateRange } from './types'

export const reportKeys = {
  summary: (range: DateRange) => ['reports', 'summary', range.from, range.to] as const,
}

export function useReport(range: DateRange) {
  return useQuery({
    queryKey: reportKeys.summary(range),
    queryFn: () => reportsApi.summary(range),
    placeholderData: (previous) => previous,
    staleTime: 60_000,
  })
}
