import { BadgeCheckIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { Skeleton } from '@/components/ui/primitives'
import { useSignedUrl } from '@/features/conversation/hooks'
import { appEnv } from '@/lib/supabase'
import { cn, initials } from '@/lib/utils'

import { campaignTone, postTone, staffMediaUrl } from '../logic'
import type { AccountRef, CampaignStatus, PostAttachment, PostStatus } from '../types'

export { ReasonDialog } from '@/components/reason-dialog'

export function OfficialBadge({ className }: { className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-0.5 rounded-sm bg-primary/10 px-1 text-[11px] font-medium text-primary',
        className,
      )}
    >
      <BadgeCheckIcon className="size-3" aria-hidden="true" />
      {t('community.official')}
    </span>
  )
}

export function AccountAvatar({ account, className }: { account: AccountRef; className?: string }) {
  const src = account.avatar_url
    ? staffMediaUrl(account.avatar_url, appEnv().publicApiUrl, appEnv().supabaseUrl)
    : null
  const [failed, setFailed] = useState(false)
  return src && !failed ? (
    <img
      src={src}
      alt=""
      onError={() => setFailed(true)}
      className={cn('size-8 shrink-0 rounded-full border object-cover', className)}
    />
  ) : (
    <span
      aria-hidden="true"
      className={cn(
        'inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-[11px] font-medium text-primary',
        className,
      )}
    >
      {initials(account.display_name ?? account.username)}
    </span>
  )
}

export function AccountChip({ account, className }: { account: AccountRef; className?: string }) {
  return (
    <span className={cn('flex min-w-0 items-center gap-2', className)}>
      <AccountAvatar account={account} className="size-6" />
      <span className="min-w-0 truncate text-row font-medium">
        {account.display_name ?? account.username}
      </span>
      <OfficialBadge />
    </span>
  )
}

export function PostStatusText({ status }: { status: PostStatus }) {
  const { t } = useTranslation()
  return (
    <span className="inline-flex items-center gap-1.5 text-xs whitespace-nowrap text-muted-foreground">
      <Dot tone={postTone(status)} />
      {t(`community.postStatus.${status}`)}
    </span>
  )
}

export function CampaignStatusText({ status }: { status: CampaignStatus }) {
  const { t } = useTranslation()
  return (
    <span className="inline-flex items-center gap-1.5 text-xs whitespace-nowrap text-muted-foreground">
      <Dot tone={campaignTone(status)} />
      {t(`community.campaignStatus.${status}`)}
    </span>
  )
}

function PostImage({ attachment }: { attachment: PostAttachment }) {
  const { t } = useTranslation()
  const url = useSignedUrl(attachment.path)
  if (!url.data) return <Skeleton className="size-20 rounded-md" />
  return (
    <a
      href={url.data}
      target="_blank"
      rel="noreferrer"
      className="block rounded-md outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
    >
      <img src={url.data} alt={t('community.image')} className="size-20 rounded-md border object-cover" />
    </a>
  )
}

export function PostImages({ attachments }: { attachments: PostAttachment[] }) {
  if (attachments.length === 0) return null
  return (
    <div className="flex flex-wrap gap-2">
      {attachments.map((attachment) => (
        <PostImage key={attachment.path} attachment={attachment} />
      ))}
    </div>
  )
}

export function MetaLine({ items }: { items: (string | null | undefined | false)[] }) {
  return <p className="text-xs text-muted-foreground">{items.filter(Boolean).join(' · ')}</p>
}
