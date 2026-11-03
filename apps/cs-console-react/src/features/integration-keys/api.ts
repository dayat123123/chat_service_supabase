import type { AccountRef } from '@/features/community/types'
import { rpc } from '@/lib/supabase'

import type { CreatedKey, IntegrationKey, IntegrationStats, KeyDaily, KeyDraft } from './types'

function withoutSecret(raw: IntegrationKey & { key?: unknown }): IntegrationKey {
  const { key: _secret, ...view } = raw
  return { ...view, scopes: view.scopes ?? [], allowed_cidrs: view.allowed_cidrs ?? [] }
}

export const integrationKeysApi = {
  list: async () => (await rpc<IntegrationKey[]>('integration_keys')).map(withoutSecret),
  create: async (draft: KeyDraft): Promise<CreatedKey> => {
    const raw = await rpc<IntegrationKey & { key: string }>('integration_key_create', {
      p_name: draft.name,
      p_scopes: draft.scopes,
      p_official_account_id: draft.official_account_id,
      p_allowed_cidrs: draft.allowed_cidrs,
      p_rate_limit_per_minute: draft.rate_limit_per_minute,
    })
    return { key: withoutSecret(raw), secret: raw.key }
  },
  update: async (id: string, draft: KeyDraft) =>
    withoutSecret(
      await rpc<IntegrationKey>('integration_key_update', {
        p_id: id,
        p_name: draft.name,
        p_scopes: draft.scopes,
        p_official_account_id: draft.official_account_id,
        p_allowed_cidrs: draft.allowed_cidrs,
        p_rate_limit_per_minute: draft.rate_limit_per_minute,
        p_enabled: draft.enabled,
      }),
    ),
  revoke: async (id: string, reason: string) =>
    withoutSecret(await rpc<IntegrationKey>('integration_key_revoke', { p_id: id, p_reason: reason })),
  officialAccounts: () => rpc<AccountRef[]>('integration_official_accounts'),
  statsDaily: async (days: number, keyId: string) =>
    (await rpc<KeyDaily[]>('integration_stats_daily', { p_days: days, p_key_id: keyId })).map((row) => ({
      ...row,
      days: row.days ?? [],
    })),
  stats: async (days: number): Promise<IntegrationStats> => {
    const raw = await rpc<IntegrationStats>('integration_stats', { p_days: days })
    return { ...raw, keys: raw.keys ?? [], daily: raw.daily ?? [] }
  },
}
