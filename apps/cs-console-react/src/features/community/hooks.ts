import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { useAgent } from '@/features/auth/hooks'

import { communityApi } from './api'
import { hasCommunity } from './logic'
import type { CampaignDraft, PinScope, PostDraft, ReportAction, ReportStatus, ReportTarget } from './types'

export const communityKeys = {
  all: ['community'] as const,
  overview: ['community', 'overview'] as const,
  accounts: ['community', 'accounts'] as const,
  posts: ['community', 'posts'] as const,
  campaigns: ['community', 'campaigns'] as const,
  reports: (status: ReportStatus) => ['community', 'reports', status] as const,
  user: (id: string) => ['community', 'user', id] as const,
  users: (query: string) => ['community', 'users', query] as const,
  audience: (audience: string, stock: string | null) => ['community', 'audience', audience, stock] as const,
}

const live = { refetchInterval: 30_000, staleTime: 10_000 }

export function useCommunityOverview(enabled = true) {
  return useQuery({ queryKey: communityKeys.overview, queryFn: communityApi.overview, enabled, ...live })
}

export function useCommunityBadge() {
  const agent = useAgent()
  const overview = useCommunityOverview(hasCommunity(agent))
  const data = overview.data
  if (!data) return 0
  const perms = agent.community_permissions
  return (
    (perms.includes('community.publish') ? data.pending_posts + data.pending_campaigns : 0) +
    (perms.includes('community.moderate') ? data.open_reports : 0)
  )
}

export function useOfficialAccounts() {
  return useQuery({ queryKey: communityKeys.accounts, queryFn: communityApi.accounts, staleTime: 60_000 })
}

export function useCommunityPosts() {
  return useQuery({ queryKey: communityKeys.posts, queryFn: communityApi.posts, ...live })
}

export function useCampaigns() {
  return useQuery({ queryKey: communityKeys.campaigns, queryFn: communityApi.campaigns, ...live })
}

export function useReports(status: ReportStatus) {
  return useQuery({
    queryKey: communityKeys.reports(status),
    queryFn: () => communityApi.reports(status),
    ...live,
  })
}

export function useCommunityUser(id: string | null) {
  return useQuery({
    queryKey: communityKeys.user(id ?? ''),
    queryFn: () => communityApi.user(id ?? ''),
    enabled: id !== null,
  })
}

export function useFindUsers(query: string) {
  const text = query.trim()
  return useQuery({
    queryKey: communityKeys.users(text),
    queryFn: () => communityApi.findUsers(text),
    enabled: text.length >= 2,
    placeholderData: (previous) => previous,
  })
}

export function useAudienceSize(audience: string, stock: string | null, enabled: boolean) {
  return useQuery({
    queryKey: communityKeys.audience(audience, stock),
    queryFn: () => communityApi.audienceSize(audience, stock),
    enabled,
    staleTime: 60_000,
  })
}

function useCommunityMutation<TArgs, TResult>(run: (args: TArgs) => Promise<TResult>) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSettled: () => void client.invalidateQueries({ queryKey: communityKeys.all }),
  })
}

export const useSaveAccount = () =>
  useCommunityMutation(
    (args: {
      id: string | null
      values: { username: string; display_name: string; bio: string | null; avatar_url: string | null }
    }) => communityApi.saveAccount(args.id, args.values),
  )

export const useSetAccountDisabled = () =>
  useCommunityMutation((args: { id: string; disabled: boolean }) =>
    communityApi.setAccountDisabled(args.id, args.disabled),
  )

export const useSetVerified = () =>
  useCommunityMutation((args: { id: string; verified: boolean; reason: string }) =>
    communityApi.setVerified(args.id, args.verified, args.reason),
  )

export const useSavePost = () =>
  useCommunityMutation((args: { id: string | null; draft: PostDraft; version: number | null }) =>
    communityApi.savePost(args.id, args.draft, args.version),
  )

export const useSubmitPost = () =>
  useCommunityMutation((args: { id: string; version: number }) =>
    communityApi.submitPost(args.id, args.version),
  )

export const useReviewPost = () =>
  useCommunityMutation((args: { id: string; approve: boolean; note: string | null; version: number }) =>
    communityApi.reviewPost(args.id, args.approve, args.note, args.version),
  )

export const useCancelPost = () =>
  useCommunityMutation((args: { id: string; version: number }) =>
    communityApi.cancelPost(args.id, args.version),
  )

export const usePinPost = () =>
  useCommunityMutation(
    (args: { id: string; scope: PinScope | null; stock: string | null; until: string | null }) =>
      communityApi.pinPost(args.id, args.scope, args.stock, args.until),
  )

export const useDeletePost = () =>
  useCommunityMutation((args: { id: string; reason: string }) =>
    communityApi.deletePost(args.id, args.reason),
  )

export const useSaveCampaign = () =>
  useCommunityMutation((args: { id: string | null; draft: CampaignDraft; version: number | null }) =>
    communityApi.saveCampaign(args.id, args.draft, args.version),
  )

export const useSubmitCampaign = () =>
  useCommunityMutation((args: { id: string; version: number }) =>
    communityApi.submitCampaign(args.id, args.version),
  )

export const useReviewCampaign = () =>
  useCommunityMutation((args: { id: string; approve: boolean; note: string | null; version: number }) =>
    communityApi.reviewCampaign(args.id, args.approve, args.note, args.version),
  )

export const useCancelCampaign = () =>
  useCommunityMutation((args: { id: string; version: number }) =>
    communityApi.cancelCampaign(args.id, args.version),
  )

export const useResolveReport = () =>
  useCommunityMutation((args: { type: ReportTarget; id: string; action: ReportAction; reason: string }) =>
    communityApi.resolveReport(args.type, args.id, args.action, args.reason),
  )

export const useSanction = () =>
  useCommunityMutation((args: { id: string; reason: string; kind: string | null; hours: number | null }) =>
    communityApi.sanction(args.id, args.reason, args.kind, args.hours),
  )

export const useRevokeSanction = () =>
  useCommunityMutation((args: { id: string; reason: string }) =>
    communityApi.revokeSanction(args.id, args.reason),
  )

export const useRevokeSessions = () =>
  useCommunityMutation((args: { id: string; reason: string }) =>
    communityApi.revokeSessions(args.id, args.reason),
  )
