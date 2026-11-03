import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useMemo, useState } from 'react'

import { useAgent } from '@/features/auth/hooks'

import { communityApi } from './api'
import { hasCommunity } from './logic'
import type {
  AlertStatus,
  AppealStatus,
  CampaignDraft,
  ContentMeta,
  ContentTarget,
  HeldDecision,
  HeldTarget,
  MediaStatus,
  PinScope,
  PostDraft,
  ReportAction,
  ReportStatus,
  ReportTarget,
} from './types'

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
  held: ['community', 'held'] as const,
  media: (status: MediaStatus) => ['community', 'media', status] as const,
  alerts: (status: AlertStatus, stock: string | null) => ['community', 'alerts', status, stock] as const,
  appeals: (status: AppealStatus) => ['community', 'appeals', status] as const,
  room: (code: string) => ['community', 'room', code] as const,
  edits: (type: string, id: string) => ['community', 'edits', type, id] as const,
  roomMessages: (code: string) => ['community', 'room-messages', code] as const,
  meta: (key: string) => ['community', 'meta', key] as const,
  content: (type: string, id: string) => ['community', 'content', type, id] as const,
}

export const metaKey = (target: ContentTarget) => `${target.type}:${target.id}`

const META_BATCH = 200

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

export function useOfficialAccounts(enabled = true) {
  return useQuery({
    queryKey: communityKeys.accounts,
    queryFn: communityApi.accounts,
    staleTime: 60_000,
    enabled,
  })
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

export function useHeldContent(enabled = true) {
  return useQuery({ queryKey: communityKeys.held, queryFn: communityApi.held, enabled, ...live })
}

export function useMediaReviews(status: MediaStatus) {
  return useInfiniteQuery({
    queryKey: communityKeys.media(status),
    queryFn: ({ pageParam }) => communityApi.media(status, pageParam),
    initialPageParam: null as number | null,
    getNextPageParam: (page) => page.next_cursor,
    refetchInterval: 60_000,
    staleTime: 15_000,
  })
}

export function useMediaImage(bucket: string, path: string, enabled: boolean) {
  const [state, setState] = useState<{ url: string | null; failed: boolean }>({ url: null, failed: false })
  useEffect(() => {
    if (!enabled) return
    let url: string | null = null
    let cancelled = false
    communityApi
      .mediaImage(bucket, path)
      .then((blob) => {
        if (cancelled) return
        url = URL.createObjectURL(blob)
        setState({ url, failed: false })
      })
      .catch(() => {
        if (!cancelled) setState({ url: null, failed: true })
      })
    return () => {
      cancelled = true
      if (url) URL.revokeObjectURL(url)
    }
  }, [bucket, path, enabled])
  return state
}

export function useManipulationAlerts(status: AlertStatus, stock: string | null) {
  return useQuery({
    queryKey: communityKeys.alerts(status, stock),
    queryFn: () => communityApi.alerts(status, stock),
    placeholderData: (previous) => previous,
    ...live,
  })
}

export function useAppeals(status: AppealStatus) {
  return useQuery({
    queryKey: communityKeys.appeals(status),
    queryFn: () => communityApi.appeals(status),
    ...live,
  })
}

export function useRoomState(code: string | null) {
  return useQuery({
    queryKey: communityKeys.room(code ?? ''),
    queryFn: () => communityApi.roomState(code ?? ''),
    enabled: code !== null,
    retry: false,
    ...live,
  })
}

export function useEditHistory(type: 'post' | 'comment', id: string, enabled: boolean) {
  return useQuery({
    queryKey: communityKeys.edits(type, id),
    queryFn: () => communityApi.editHistory(type, id),
    enabled,
    staleTime: 60_000,
  })
}

export const useDecideHeld = () =>
  useCommunityMutation((args: { type: HeldTarget; id: string; action: HeldDecision; reason: string }) =>
    communityApi.decideHeld(args.type, args.id, args.action, args.reason),
  )

export const useDecideMedia = () =>
  useCommunityMutation((args: { id: number; decision: 'approve' | 'remove'; note: string | null }) =>
    communityApi.decideMedia(args.id, args.decision, args.note),
  )

export const useReviewAlert = () =>
  useCommunityMutation((args: { id: string; status: 'reviewed' | 'dismissed'; note: string }) =>
    communityApi.reviewAlert(args.id, args.status, args.note),
  )

export const useDecideAppeal = () =>
  useCommunityMutation((args: { id: string; accept: boolean; note: string }) =>
    communityApi.decideAppeal(args.id, args.accept, args.note),
  )

export const useZeroTolerance = () =>
  useCommunityMutation((args: { id: string; reason: string }) =>
    communityApi.zeroTolerance(args.id, args.reason),
  )

export function useSetSlowMode() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (args: { code: string; seconds: number; until: string | null }) =>
      communityApi.setSlowMode(args.code, args.seconds, args.until),
    onSuccess: (state) => client.setQueryData(communityKeys.room(state.stock_code), state),
    onSettled: () => void client.invalidateQueries({ queryKey: ['community', 'room'] }),
  })
}

export function usePinMessage() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (args: { roomId: string; messageId: string | null }) =>
      communityApi.pinMessage(args.roomId, args.messageId),
    onSuccess: (state) => client.setQueryData(communityKeys.room(state.stock_code), state),
    onSettled: () => void client.invalidateQueries({ queryKey: ['community', 'room'] }),
  })
}

export function useRoomMessages(code: string | null) {
  return useInfiniteQuery({
    queryKey: communityKeys.roomMessages(code ?? ''),
    queryFn: ({ pageParam }) => communityApi.roomMessages(code ?? '', pageParam),
    initialPageParam: null as string | null,
    getNextPageParam: (page) => (page.items.length >= 30 ? (page.items.at(-1)?.created_at ?? null) : null),
    enabled: code !== null,
    retry: false,
    staleTime: 10_000,
  })
}

export function useContentMeta(targets: ContentTarget[]) {
  const unique = useMemo(() => {
    const seen = new Map<string, ContentTarget>()
    for (const target of targets) seen.set(metaKey(target), { type: target.type, id: target.id })
    return [...seen.values()].sort((a, b) => metaKey(a).localeCompare(metaKey(b)))
  }, [targets])
  const key = unique.map(metaKey).join(',')
  const query = useQuery({
    queryKey: communityKeys.meta(key),
    queryFn: async () => {
      const batches = Array.from({ length: Math.ceil(unique.length / META_BATCH) }, (_, index) =>
        unique.slice(index * META_BATCH, (index + 1) * META_BATCH),
      )
      return (await Promise.all(batches.map((batch) => communityApi.contentMeta(batch)))).flat()
    },
    enabled: unique.length > 0,
    staleTime: 30_000,
  })
  return useMemo(
    () => new Map<string, ContentMeta>((query.data ?? []).map((meta) => [metaKey(meta), meta])),
    [query.data],
  )
}

export function useCommunityContent(target: ContentTarget | null) {
  return useQuery({
    queryKey: communityKeys.content(target?.type ?? '', target?.id ?? ''),
    queryFn: () => communityApi.content(target?.type ?? 'post', target?.id ?? ''),
    enabled: target !== null,
    retry: false,
    staleTime: 30_000,
  })
}
