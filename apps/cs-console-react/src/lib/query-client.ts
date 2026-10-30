import { QueryClient } from '@tanstack/react-query'

import { ApiError } from '@/lib/errors'

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 15_000,
        gcTime: 5 * 60_000,
        refetchOnWindowFocus: true,
        refetchOnReconnect: true,
        retry: (failures, error) => {
          if (error instanceof ApiError && error.status !== undefined && error.status < 500) return false
          return failures < 2
        },
      },
      mutations: { retry: false },
    },
  })
}
