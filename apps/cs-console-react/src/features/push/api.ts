import { rpc } from '@/lib/supabase'

import type { ServiceAccountKey } from './firebase-key'
import type { PushCredentials, PushDelivery, PushStatus, PushUser } from './types'

export const pushApi = {
  status: () => rpc<PushStatus>('push_status'),
  findUsers: (query: string) => rpc<PushUser[]>('push_find_users', { p_query: query }),
  test: (userId: string) => rpc<{ queued: number }>('push_test', { p_user_id: userId }),
  campaign: (id: string) => rpc<PushDelivery>('community_campaign_push', { p_id: id }),
  setCredentials: (key: ServiceAccountKey, replaceProject: boolean) =>
    rpc<PushCredentials>('push_set_credentials', { p_credentials: key, p_replace_project: replaceProject }),
  removeCredentials: () => rpc<{ removed: boolean }>('push_remove_credentials'),
}
