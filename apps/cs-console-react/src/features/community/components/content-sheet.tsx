import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { useAgent } from '@/features/auth/hooks'
import { ToneBadge } from '@/features/system/components/system-ui'
import { moderationErrorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import { useCommunityContent } from '../hooks'
import { canEditHistory } from '../logic'
import type { CommunityContent, ContentTarget } from '../types'
import { EditHistoryButton } from './edit-history'
import { EditedMark } from './moderation-ui'

const roomTypes = ['stock', 'group', 'direct'] as const

type RoomKind = (typeof roomTypes)[number] | 'other'

const roomKind = (type: string): RoomKind =>
  (roomTypes as readonly string[]).includes(type) ? (type as RoomKind) : 'other'

function statusTone(content: CommunityContent) {
  if (content.deleted_at) return 'late' as const
  if (content.moderation_status === 'visible') return 'ok' as const
  return 'warn' as const
}

function ContentBody({
  content,
  onUser,
  onOpen,
}: {
  content: CommunityContent
  onUser: (id: string) => void
  onOpen: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const author = content.author.display_name ?? content.author.username ?? '–'
  const status = content.deleted_at
    ? t('moderation.content.deleted')
    : t(
        `moderation.content.status.${content.moderation_status === 'visible' || content.moderation_status === 'held' || content.moderation_status === 'hidden' ? content.moderation_status : 'other'}`,
      )
  const room = content.room
  const roomType = room ? roomKind(room.type) : 'other'
  const attachments = Array.isArray(content.attachments) ? content.attachments.length : 0
  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <p className="flex flex-wrap items-center gap-2 text-panel font-medium">
          {t(`community.targets.${content.type}`)}
          <ToneBadge tone={statusTone(content)}>{status}</ToneBadge>
        </p>
        <p className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
          {stamp(content.created_at)}
          <EditedMark editedAt={content.edited_at} />
          {content.deleted_at ? (
            <span>· {t('moderation.content.deletedAt', { time: stamp(content.deleted_at) })}</span>
          ) : null}
        </p>
      </header>
      <div className="flex flex-col gap-3 px-5 py-4">
        <button
          type="button"
          onClick={() => onUser(content.author.id)}
          className="flex flex-wrap items-center gap-1.5 self-start rounded-sm text-row text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
        >
          {author}
          {content.author.username ? (
            <span className="font-mono text-xs text-muted-foreground">@{content.author.username}</span>
          ) : null}
        </button>
        {room ? (
          <p className="text-xs text-muted-foreground">
            {t(`moderation.content.rooms.${roomType}`, {
              name: room.stock_code ? `$${room.stock_code}` : (room.name ?? '–'),
            })}
          </p>
        ) : null}
        <p className="rounded-md border bg-background p-3 text-row break-words whitespace-pre-wrap">
          {content.body || t('moderation.content.empty')}
        </p>
        <dl className="grid grid-cols-2 gap-3 text-xs sm:grid-cols-3">
          {attachments > 0 ? (
            <div>
              <dt className="text-muted-foreground">{t('moderation.content.attachments')}</dt>
              <dd className="tabular">{formatNumber(attachments)}</dd>
            </div>
          ) : null}
          {content.like_count !== undefined ? (
            <div>
              <dt className="text-muted-foreground">{t('moderation.content.likes')}</dt>
              <dd className="tabular">{formatNumber(content.like_count)}</dd>
            </div>
          ) : null}
          {content.comment_count !== undefined ? (
            <div>
              <dt className="text-muted-foreground">{t('moderation.content.comments')}</dt>
              <dd className="tabular">{formatNumber(content.comment_count)}</dd>
            </div>
          ) : null}
        </dl>
        <div className="flex flex-wrap gap-1.5">
          {content.type === 'comment' && content.post_id ? (
            <Button
              size="xs"
              variant="outline"
              onClick={() => onOpen({ type: 'post', id: content.post_id ?? '' })}
            >
              {t('moderation.content.openPost')}
            </Button>
          ) : null}
          {content.edited_at && canEditHistory(agent.community_permissions, content.type) ? (
            <EditHistoryButton type={content.type === 'comment' ? 'comment' : 'post'} id={content.id} />
          ) : null}
        </div>
        {content.type === 'message' && room && room.type !== 'stock' ? (
          <p className="text-xs text-muted-foreground">{t('moderation.content.privateAudited')}</p>
        ) : null}
      </div>
    </div>
  )
}

function ContentDetail({ target, onUser }: { target: ContentTarget; onUser: (id: string) => void }) {
  const [current, setCurrent] = useState(target)
  const content = useCommunityContent(current)
  if (content.isError) {
    return (
      <p role="alert" className="px-5 pt-12 text-row text-destructive">
        {moderationErrorText(content.error)}
      </p>
    )
  }
  if (!content.data) return <ListSkeleton rows={4} className="pt-10" />
  return <ContentBody content={content.data} onUser={onUser} onOpen={setCurrent} />
}

export function ContentSheet({
  target,
  onClose,
  onUser,
}: {
  target: ContentTarget | null
  onClose: () => void
  onUser: (id: string) => void
}) {
  const { t } = useTranslation()
  return (
    <Sheet open={target !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('moderation.content.title')}
        closeLabel={t('app.close')}
        className="w-[min(520px,100vw)] bg-background"
      >
        {target ? (
          <ContentDetail key={`${target.type}-${target.id}`} target={target} onUser={onUser} />
        ) : null}
      </SheetContent>
    </Sheet>
  )
}
