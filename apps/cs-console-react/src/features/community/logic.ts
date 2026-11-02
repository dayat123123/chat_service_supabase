import { format } from '@/lib/time'

import type {
  Campaign,
  CampaignStatus,
  CommunityPermission,
  CommunityPost,
  CommunityTab,
  PostStatus,
} from './types'

type Perms = readonly string[]

const can = (perms: Perms, permission: CommunityPermission) => perms.includes(permission)

export const hasCommunity = (agent: { community_permissions: string[] }) =>
  agent.community_permissions.length > 0

export function communityTabsFor(perms: Perms): CommunityTab[] {
  const tabs: CommunityTab[] = []
  if (can(perms, 'community.post') || can(perms, 'community.publish')) tabs.push('stream', 'notifications')
  if (can(perms, 'community.moderate') || can(perms, 'community.sanction')) tabs.push('moderation')
  if (can(perms, 'community.accounts')) tabs.push('accounts')
  return tabs
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
