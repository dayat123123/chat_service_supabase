import { useQuery } from '@tanstack/react-query'

import { appIntegrationApi } from './api'

export const appIntegrationKeys = {
  overview: ['app-integration', 'overview'] as const,
}

export function useAppIntegration() {
  return useQuery({
    queryKey: appIntegrationKeys.overview,
    queryFn: appIntegrationApi.overview,
    refetchInterval: 30_000,
  })
}
