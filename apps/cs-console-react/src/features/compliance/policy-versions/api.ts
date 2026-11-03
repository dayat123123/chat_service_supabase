import { rpc } from '@/lib/supabase'
import type { Json } from '@/types/database'

import type {
  PolicyChange,
  PolicyDiff,
  PolicyState,
  SimInput,
  Simulation,
  VersionDetail,
  VersionPage,
} from './types'

export type PolicyFn =
  | 'compliance_banned_words'
  | 'compliance_add_banned_word'
  | 'compliance_set_banned_word_action'
  | 'compliance_delete_banned_word'
  | 'compliance_import_banned_words'
  | 'compliance_content_rules'
  | 'compliance_set_content_rule'
  | 'compliance_save_blocked_domain'
  | 'compliance_delete_blocked_domain'
  | 'compliance_save_allowed_domain'
  | 'compliance_delete_allowed_domain'
  | 'compliance_add_allowlist_term'
  | 'compliance_delete_allowlist_term'
  | 'compliance_add_promo_phrase'
  | 'compliance_delete_promo_phrase'
  | 'compliance_set_new_account_days'
  | 'compliance_image_thresholds'
  | 'compliance_set_image_thresholds'
  | 'compliance_manipulation_settings'
  | 'compliance_set_manipulation_settings'

export async function policyCall<T>(fn: PolicyFn, args: Record<string, unknown> = {}): Promise<T> {
  const raw = await rpc<Record<string, unknown>>('compliance_policy_call', { p_fn: fn, p_args: args as Json })
  delete raw.policy_draft
  return raw as T
}

const diffOf = (raw: PolicyDiff | null | undefined): PolicyDiff => ({
  total: Number(raw?.total ?? 0),
  sections: raw?.sections ?? {},
})

function change(raw: PolicyChange): PolicyChange {
  return {
    ...raw,
    diff: diffOf(raw.diff),
    effective: raw.effective === undefined || raw.effective === null ? null : diffOf(raw.effective),
  }
}

export const policyVersionsApi = {
  state: async (): Promise<PolicyState> => {
    const raw = await rpc<PolicyState>('compliance_policy_state')
    return {
      ...raw,
      current: { ...raw.current, summary: diffOf(raw.current.summary) },
      draft: raw.draft ? { ...raw.draft, diff: diffOf(raw.draft.diff) } : null,
      pending: Number(raw.pending ?? 0),
      pending_mine: Number(raw.pending_mine ?? 0),
      pending_to_review: Number(raw.pending_to_review ?? 0),
    }
  },
  discard: () => rpc<PolicyState>('compliance_policy_discard'),
  submit: async (reason: string) =>
    change(await rpc<PolicyChange>('compliance_policy_submit', { p_reason: reason })),
  changes: async (status: 'pending' | 'decided') =>
    (
      (await rpc<PolicyChange[] | null>('compliance_policy_changes', { p_status: status, p_limit: 50 })) ?? []
    ).map(change),
  change: async (id: number) => change(await rpc<PolicyChange>('compliance_policy_change', { p_id: id })),
  decide: async (id: number, approve: boolean, note: string) =>
    change(
      await rpc<PolicyChange>('compliance_policy_decide', {
        p_id: id,
        p_approve: approve,
        p_note: note.trim() || null,
      }),
    ),
  withdraw: async (id: number) => change(await rpc<PolicyChange>('compliance_policy_withdraw', { p_id: id })),
  versions: async (before: number | null, limit: number): Promise<VersionPage> => {
    const raw = await rpc<VersionPage>('compliance_policy_versions', { p_before: before, p_limit: limit })
    return {
      rows: (raw.rows ?? []).map((row) => ({ ...row, summary: diffOf(row.summary) })),
      next: raw.next ?? null,
    }
  },
  version: async (version: number): Promise<VersionDetail> => {
    const raw = await rpc<VersionDetail>('compliance_policy_version', { p_version: version })
    return {
      ...raw,
      summary: diffOf(raw.summary),
      diff: diffOf(raw.diff),
      restore: diffOf(raw.restore),
    }
  },
  rollback: async (version: number, reason: string) =>
    change(await rpc<PolicyChange>('compliance_policy_rollback', { p_version: version, p_reason: reason })),
  simulate: async ({ target, text, surface, days }: SimInput): Promise<Simulation> => {
    const raw = await rpc<Simulation>('compliance_policy_simulate', {
      p_change_id: target.kind === 'change' ? target.id : null,
      p_version: target.kind === 'version' ? target.version : null,
      p_text: text.trim() || null,
      p_surface: surface,
      p_days: days,
      p_limit: 300,
    })
    return {
      ...raw,
      target: { ...raw.target, summary: diffOf(raw.target.summary) },
      content: { ...raw.content, items: raw.content.items ?? [] },
    }
  },
  fourEyes: () => rpc<FourEyesSetting>('admin_policy_four_eyes'),
  setFourEyes: (enabled: boolean) =>
    rpc<FourEyesSetting>('admin_set_policy_four_eyes', { p_enabled: enabled }),
}

export type FourEyesSetting = {
  enabled: boolean
  version: number
  updated_at: string
  updated_by: string | null
}
