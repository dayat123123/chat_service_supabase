import { isSuperAdmin } from '@/features/presence/types'
import { format } from '@/lib/time'

import {
  SLOW_MODE_MAX,
  type Appeal,
  type Campaign,
  type CampaignStatus,
  type CommunityPermission,
  type CommunityPost,
  type CommunityTab,
  type CommunityUser,
  type HeldContent,
  type HeldDecision,
  type ModerationQueue,
  type PostStatus,
} from './types'

type Perms = readonly string[]

const can = (perms: Perms, permission: CommunityPermission) => perms.includes(permission)

export const hasCommunity = (agent: { community_permissions: string[] }) =>
  agent.community_permissions.length > 0

export function communityTabsFor(perms: Perms): CommunityTab[] {
  const tabs: CommunityTab[] = []
  if (can(perms, 'community.post') || can(perms, 'community.publish')) tabs.push('stream', 'notifications')
  if (can(perms, 'community.moderate') || can(perms, 'community.sanction')) tabs.push('moderation')
  if (can(perms, 'community.moderate')) tabs.push('rooms')
  if (can(perms, 'community.accounts')) tabs.push('accounts')
  return tabs
}

export function communityPageTabs(agent: {
  roles: string[]
  community_permissions: string[]
}): CommunityTab[] {
  const tabs = communityTabsFor(agent.community_permissions)
  return isSuperAdmin(agent) ? [...tabs, 'analytics'] : tabs
}

type Actor = { id: string; perms: Perms; fourEyes: boolean }

type Reviewable = { status: string; created_by: { id: string } | null }

const mine = (item: Reviewable, actor: Actor) => item.created_by?.id === actor.id

export function canEdit(item: Reviewable, actor: Actor) {
  return (
    can(actor.perms, 'community.post') &&
    mine(item, actor) &&
    ['draft', 'rejected', 'failed'].includes(item.status)
  )
}

export function canSubmit(item: Reviewable, actor: Actor) {
  return can(actor.perms, 'community.post') && mine(item, actor) && item.status === 'draft'
}

export function canReview(item: Reviewable, actor: Actor) {
  if (!can(actor.perms, 'community.publish')) return false
  if (item.status === 'pending') return !(actor.fourEyes && mine(item, actor))
  return item.status === 'draft' && mine(item, actor) && !actor.fourEyes
}

export function reviewBlockedByFourEyes(item: Reviewable, actor: Actor) {
  return (
    can(actor.perms, 'community.publish') && item.status === 'pending' && actor.fourEyes && mine(item, actor)
  )
}

export function canCancel(item: Reviewable, actor: Actor) {
  if (mine(item, actor) && ['draft', 'pending', 'scheduled', 'rejected', 'failed'].includes(item.status))
    return true
  return can(actor.perms, 'community.publish') && ['pending', 'scheduled'].includes(item.status)
}

export function canManagePublished(post: CommunityPost, actor: Actor) {
  return can(actor.perms, 'community.publish') && post.status === 'published' && !post.post?.deleted
}

export const postFilters = ['review', 'scheduled', 'published', 'mine', 'all'] as const
export type PostFilter = (typeof postFilters)[number]

export function filterPosts(posts: CommunityPost[], filter: PostFilter, me: string) {
  switch (filter) {
    case 'review':
      return posts.filter((post) => post.status === 'pending')
    case 'scheduled':
      return posts.filter((post) => post.status === 'scheduled')
    case 'published':
      return posts.filter((post) => post.status === 'published')
    case 'mine':
      return posts.filter(
        (post) =>
          post.created_by?.id === me && ['draft', 'rejected', 'failed', 'pending'].includes(post.status),
      )
    case 'all':
      return posts
  }
}

export const campaignFilters = ['review', 'scheduled', 'sent', 'mine', 'all'] as const
export type CampaignFilter = (typeof campaignFilters)[number]

export function filterCampaigns(campaigns: Campaign[], filter: CampaignFilter, me: string) {
  switch (filter) {
    case 'review':
      return campaigns.filter((campaign) => campaign.status === 'pending')
    case 'scheduled':
      return campaigns.filter((campaign) => campaign.status === 'scheduled' || campaign.status === 'sending')
    case 'sent':
      return campaigns.filter((campaign) => campaign.status === 'sent')
    case 'mine':
      return campaigns.filter(
        (campaign) =>
          campaign.created_by?.id === me && ['draft', 'rejected', 'pending'].includes(campaign.status),
      )
    case 'all':
      return campaigns
  }
}

export type StatusTone = 'ok' | 'warn' | 'late' | 'neutral'

const postTones: Record<PostStatus, StatusTone> = {
  draft: 'neutral',
  pending: 'warn',
  scheduled: 'ok',
  published: 'ok',
  rejected: 'late',
  cancelled: 'neutral',
  failed: 'late',
}

const campaignTones: Record<CampaignStatus, StatusTone> = {
  draft: 'neutral',
  pending: 'warn',
  scheduled: 'ok',
  sending: 'ok',
  sent: 'ok',
  rejected: 'late',
  cancelled: 'neutral',
}

export const postTone = (status: PostStatus) => postTones[status]
export const campaignTone = (status: CampaignStatus) => campaignTones[status]

export function jakartaInput(iso: string | null) {
  return iso ? format(iso, "yyyy-MM-dd'T'HH:mm") : ''
}

export function fromJakartaInput(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return null
  const date = new Date(`${value}:00+07:00`)
  return Number.isNaN(date.getTime()) ? null : date.toISOString()
}

export function staffMediaUrl(url: string | null, publicBase: string | undefined, staffBase: string) {
  if (!url) return null
  if (publicBase && url.startsWith(`${publicBase}/`)) return `${staffBase}${url.slice(publicBase.length)}`
  return url
}

export const stockCodePattern = /^[A-Z][A-Z0-9]{1,11}$/

export function cleanStock(value: string) {
  return value.trim().replace(/^\$/, '').toUpperCase()
}

export function excerpt(text: string, max = 160) {
  const single = text.replace(/\s+/g, ' ').trim()
  return single.length > max ? `${single.slice(0, max - 1)}…` : single
}

export function moderationQueuesFor(perms: Perms): ModerationQueue[] {
  const moderate = can(perms, 'community.moderate')
  const sanction = can(perms, 'community.sanction')
  const queues: ModerationQueue[] = []
  if (moderate || sanction) queues.push('reports')
  if (moderate) queues.push('held', 'media', 'alerts')
  if (moderate || sanction) queues.push('appeals')
  return queues
}

export const heldDecisions: HeldDecision[] = ['approve', 'hide', 'remove']

export const canEditHistory = (perms: Perms, type: string): type is 'post' | 'comment' =>
  can(perms, 'community.moderate') && (type === 'post' || type === 'comment')

export type AppealBlock = 'conflict' | 'needSanction' | 'needModerate' | null

export function appealBlock(appeal: Appeal, me: string, perms: Perms): AppealBlock {
  if (appeal.status !== 'pending' || appeal.can_decide) return null
  const needed = appeal.target_type === 'sanction' ? 'community.sanction' : 'community.moderate'
  if (!can(perms, needed)) return needed === 'community.sanction' ? 'needSanction' : 'needModerate'
  if (appeal.original_decider?.id === me) return 'conflict'
  return null
}

export function hasZeroTolerance(user: Pick<CommunityUser, 'sanctions'>) {
  return user.sanctions.some((item) => item.active && item.category === 'zero_tolerance')
}

export function heldAuthorName(row: HeldContent) {
  return row.author.display_name ?? row.author.username ?? '–'
}

export type SlowModeProblem = 'seconds' | 'untilPast' | 'untilFar' | 'untilFormat'

export function slowModeProblem(
  seconds: number,
  untilInput: string,
  now: Date = new Date(),
): SlowModeProblem | null {
  if (!Number.isInteger(seconds) || seconds < 0 || seconds > SLOW_MODE_MAX) return 'seconds'
  if (seconds === 0 || untilInput === '') return null
  const until = fromJakartaInput(untilInput)
  if (!until) return 'untilFormat'
  const time = Date.parse(until)
  if (time <= now.getTime()) return 'untilPast'
  if (time > now.getTime() + 30 * 24 * 60 * 60 * 1000) return 'untilFar'
  return null
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export const isUuid = (value: string) => uuidPattern.test(value.trim())

export function scorePercent(score: number) {
  return Math.round(score * 1000) / 10
}

export function topScores(scores: Record<string, number>, limit = 3) {
  return Object.entries(scores)
    .filter(([, value]) => typeof value === 'number')
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
}

export function evidenceNumber(evidence: Record<string, unknown>, key: string) {
  const value = evidence[key]
  return typeof value === 'number' ? value : typeof value === 'string' && value !== '' ? Number(value) : null
}

export function evidenceText(evidence: Record<string, unknown>, key: string) {
  const value = evidence[key]
  return typeof value === 'string' ? value : null
}

export function evidenceIds(evidence: Record<string, unknown>, key: string) {
  const value = evidence[key]
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : []
}
