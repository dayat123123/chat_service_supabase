import { useQuery } from '@tanstack/react-query'

import { reportsApi } from './api'
import type { DateRange } from './types'

export const reportKeys = {
  summary: (range: DateRange) => ['reports', 'summary', range.from, range.to] as const,
  customers: (range: DateRange, search: string) =>
    ['reports', 'customers', range.from, range.to, search] as const,
  trail: (customerId: string, range: DateRange) =>
    ['reports', 'trail', customerId, range.from, range.to] as const,
}

export function useReport(range: DateRange) {
  return useQuery({
    queryKey: reportKeys.summary(range),
    queryFn: () => reportsApi.summary(range),
    placeholderData: (previous) => previous,
    staleTime: 60_000,
  })
}

export function useCustomerReport(range: DateRange, search: string) {
  return useQuery({
    queryKey: reportKeys.customers(range, search.trim()),
    queryFn: () => reportsApi.customers(range, search),
    placeholderData: (previous) => previous,
    staleTime: 60_000,
  })
}

export function useCustomerTrail(customerId: string, range: DateRange) {
  return useQuery({
    queryKey: reportKeys.trail(customerId, range),
    queryFn: () => reportsApi.customerTrail(customerId, range),
    staleTime: Infinity,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  })
}
