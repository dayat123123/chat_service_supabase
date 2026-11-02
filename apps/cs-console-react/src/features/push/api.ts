import { rpc } from '@/lib/supabase'

import type { PushDelivery, PushStatus, PushUser } from './types'

export const pushApi = {
  status: () => rpc<PushStatus>('push_status'),
  findUsers: (query: string) => rpc<PushUser[]>('push_find_users', { p_query: query }),
  test: (userId: string) => rpc<{ queued: number }>('push_test', { p_user_id: userId }),
  campaign: (id: string) => rpc<PushDelivery>('community_campaign_push', { p_id: id }),
}
