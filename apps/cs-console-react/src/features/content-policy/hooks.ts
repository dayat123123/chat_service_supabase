import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { contentPolicyApi } from './api'
import type {
  BlockedDraft,
  ContentAction,
  ContentCategory,
  ContentRules,
  ContentScope,
  ImageThresholds,
  ManipulationSettings,
  TestSurface,
} from './types'

export const policyKeys = {
  rules: ['content-policy', 'rules'] as const,
  images: ['content-policy', 'images'] as const,
  manipulation: ['content-policy', 'manipulation'] as const,
}

export function useContentRules() {
  return useQuery({ queryKey: policyKeys.rules, queryFn: contentPolicyApi.rules, staleTime: 30_000 })
}

export function useImageThresholds() {
  return useQuery({
    queryKey: policyKeys.images,
    queryFn: contentPolicyApi.imageThresholds,
    staleTime: 30_000,
  })
}

export function useManipulationSettings() {
  return useQuery({
    queryKey: policyKeys.manipulation,
    queryFn: contentPolicyApi.manipulation,
    staleTime: 30_000,
  })
}

function useRulesMutation<TArgs>(run: (args: TArgs) => Promise<ContentRules>) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: (data) => client.setQueryData(policyKeys.rules, data),
    onError: () => void client.invalidateQueries({ queryKey: policyKeys.rules }),
  })
}

export const useSetContentRule = () =>
  useRulesMutation((args: { category: ContentCategory; action: ContentAction; scope: ContentScope }) =>
    contentPolicyApi.setRule(args.category, args.action, args.scope),
  )

export const useSaveBlockedDomain = () =>
  useRulesMutation((draft: BlockedDraft) => contentPolicyApi.saveBlocked(draft))

export const useDeleteBlockedDomain = () =>
  useRulesMutation((domain: string) => contentPolicyApi.deleteBlocked(domain))

export const useSaveAllowedDomain = () =>
  useRulesMutation((args: { domain: string; note: string | null }) =>
    contentPolicyApi.saveAllowed(args.domain, args.note),
  )

export const useDeleteAllowedDomain = () =>
  useRulesMutation((domain: string) => contentPolicyApi.deleteAllowed(domain))

export const useAddTerm = () => useRulesMutation((term: string) => contentPolicyApi.addTerm(term))

export const useDeleteTerm = () => useRulesMutation((term: string) => contentPolicyApi.deleteTerm(term))

export const useAddPhrase = () => useRulesMutation((phrase: string) => contentPolicyApi.addPhrase(phrase))

export const useDeletePhrase = () =>
  useRulesMutation((phrase: string) => contentPolicyApi.deletePhrase(phrase))

export const useSetNewAccountDays = () =>
  useRulesMutation((days: number) => contentPolicyApi.setNewAccountDays(days))

export function useTestContent() {
  return useMutation({
    mutationFn: (args: { text: string; surface: TestSurface }) =>
      contentPolicyApi.test(args.text, args.surface),
  })
}

export function useSetImageThresholds() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (args: { thresholds: ImageThresholds['thresholds']; note: string | null }) =>
      contentPolicyApi.setImageThresholds(args.thresholds, args.note),
    onSuccess: (data) => client.setQueryData(policyKeys.images, data),
    onError: () => void client.invalidateQueries({ queryKey: policyKeys.images }),
  })
}

export function useSetManipulationSettings() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (values: ManipulationSettings) => contentPolicyApi.setManipulation(values),
    onSuccess: (data) => client.setQueryData(policyKeys.manipulation, data),
    onError: () => void client.invalidateQueries({ queryKey: policyKeys.manipulation }),
  })
}
