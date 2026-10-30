import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'

import { realtime } from '@/lib/realtime'

import { supervisorApi } from './api'

export const supervisorKeys = { overview: ['supervisor', 'overview'] as const }

export function useSupervisorOverview(enabled: boolean) {
  const client = useQueryClient()
  useEffect(() => {
    if (!enabled) return
    let timer: number | undefined
    const stop = realtime.subscribe(() => {
      window.clearTimeout(timer)
      timer = window.setTimeout(
        () => void client.invalidateQueries({ queryKey: supervisorKeys.overview }),
        1_000,
      )
    })
    return () => {
      stop()
      window.clearTimeout(timer)
    }
  }, [client, enabled])
  return useQuery({
    queryKey: supervisorKeys.overview,
    queryFn: supervisorApi.overview,
    enabled,
    refetchInterval: 30_000,
    placeholderData: (previous) => previous,
  })
}
