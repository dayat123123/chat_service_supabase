import { rpc } from '@/lib/supabase'

import { normalizeOverview } from './logic'
import type { AppIntegrationOverview } from './types'

export const appIntegrationApi = {
  overview: async () => normalizeOverview(await rpc<AppIntegrationOverview>('app_integration_overview')),
}
