import { rpc } from '@/lib/supabase'

import type { SupervisorOverview } from './types'

export const supervisorApi = {
  overview: async (): Promise<SupervisorOverview> => {
    const raw = await rpc<SupervisorOverview>('supervisor_overview')
    return {
      ...raw,
      overdue: raw.overdue ?? [],
      flagged_open: raw.flagged_open ?? [],
      offline_owned: raw.offline_owned ?? [],
      agents: raw.agents ?? [],
    }
  },
}
