import { policyCall } from '@/features/compliance/policy-versions/api'
import { rpc } from '@/lib/supabase'

import type {
  BlockedDraft,
  ContentAction,
  ContentCategory,
  ContentRules,
  ContentScope,
  ContentTest,
  ImageThresholds,
  ManipulationSettings,
  TestSurface,
} from './types'

function rules(raw: ContentRules): ContentRules {
  return {
    categories: raw.categories ?? [],
    blocked_domains: raw.blocked_domains ?? [],
    allowed_domains: raw.allowed_domains ?? [],
    allowlist: raw.allowlist ?? [],
    promo_phrases: raw.promo_phrases ?? [],
    new_account_days: Number(raw.new_account_days ?? 0),
  }
}

export const contentPolicyApi = {
  rules: async () => rules(await policyCall<ContentRules>('compliance_content_rules')),
  setRule: async (category: ContentCategory, action: ContentAction, scope: ContentScope) =>
    rules(
      await policyCall<ContentRules>('compliance_set_content_rule', {
        p_category: category,
        p_action: action,
        p_scope: scope,
      }),
    ),
  saveBlocked: async (draft: BlockedDraft) =>
    rules(
      await policyCall<ContentRules>('compliance_save_blocked_domain', {
        p_domain: draft.domain,
        p_category: draft.category,
        p_action: draft.action,
        p_note: draft.note,
        p_match: draft.match,
      }),
    ),
  deleteBlocked: async (domain: string) =>
    rules(await policyCall<ContentRules>('compliance_delete_blocked_domain', { p_domain: domain })),
  saveAllowed: async (domain: string, note: string | null) =>
    rules(
      await policyCall<ContentRules>('compliance_save_allowed_domain', { p_domain: domain, p_note: note }),
    ),
  deleteAllowed: async (domain: string) =>
    rules(await policyCall<ContentRules>('compliance_delete_allowed_domain', { p_domain: domain })),
  addTerm: async (term: string) =>
    rules(await policyCall<ContentRules>('compliance_add_allowlist_term', { p_term: term })),
  deleteTerm: async (term: string) =>
    rules(await policyCall<ContentRules>('compliance_delete_allowlist_term', { p_term: term })),
  addPhrase: async (phrase: string) =>
    rules(await policyCall<ContentRules>('compliance_add_promo_phrase', { p_phrase: phrase })),
  deletePhrase: async (phrase: string) =>
    rules(await policyCall<ContentRules>('compliance_delete_promo_phrase', { p_phrase: phrase })),
  setNewAccountDays: async (days: number) =>
    rules(await policyCall<ContentRules>('compliance_set_new_account_days', { p_days: days })),
  test: async (text: string, surface: TestSurface) => {
    const raw = await rpc<ContentTest>('compliance_test_content', { p_text: text, p_surface: surface })
    return { ...raw, categories: raw.categories ?? [] }
  },
  imageThresholds: async () => {
    const raw = await policyCall<ImageThresholds>('compliance_image_thresholds')
    return { ...raw, thresholds: raw.thresholds ?? {}, categories: raw.categories ?? [] }
  },
  setImageThresholds: async (thresholds: ImageThresholds['thresholds'], note: string | null) => {
    const raw = await policyCall<ImageThresholds>('compliance_set_image_thresholds', {
      p_thresholds: thresholds,
      p_note: note,
    })
    return { ...raw, thresholds: raw.thresholds ?? {}, categories: raw.categories ?? [] }
  },
  manipulation: () => policyCall<ManipulationSettings>('compliance_manipulation_settings'),
  setManipulation: (values: ManipulationSettings) =>
    policyCall<ManipulationSettings>('compliance_set_manipulation_settings', { p_values: values }),
}
