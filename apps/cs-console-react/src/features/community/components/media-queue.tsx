import { EyeIcon, EyeOffIcon, ImageOffIcon, LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Skeleton } from '@/components/ui/primitives'
import { ToneBadge } from '@/features/system/components/system-ui'
import { moderationErrorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useDecideMedia, useMediaImage, useMediaReviews } from '../hooks'
import { scorePercent, topScores } from '../logic'
import {
  mediaStatuses,
  NOTE_MAX,
  NOTE_MIN,
  type ContentTarget,
  type MediaReview,
  type MediaStatus,
} from '../types'
import { QueueHeader } from './moderation-ui'
import { ReasonDialog } from './shared'

const mediaCategories = ['porn', 'hentai', 'sexy', 'drawings', 'neutral'] as const

function useCategoryLabel() {
  const { t } = useTranslation()
  return (category: string) =>
    (mediaCategories as readonly string[]).includes(category)
      ? t(`moderation.media.categories.${category as (typeof mediaCategories)[number]}`)
      : category
}

export function BlurredImage({ review }: { review: Pick<MediaReview, 'bucket' | 'path' | 'object_exists'> }) {
  const { t } = useTranslation()
  const [revealed, setRevealed] = useState(false)
  const image = useMediaImage(review.bucket, review.path, review.object_exists)
  const box = 'relative size-32 shrink-0 overflow-hidden rounded-md border bg-muted'
  if (!review.object_exists || image.failed) {
    return (
      <div
        className={cn(
          box,
          'flex flex-col items-center justify-center gap-1 p-2 text-center text-xs text-muted-foreground',
        )}
      >
        <ImageOffIcon className="size-4" aria-hidden="true" />
        {review.object_exists ? t('moderation.media.failed') : t('moderation.media.gone')}
      </div>
    )
  }
  if (!image.url) return <Skeleton className="size-32 shrink-0 rounded-md" />
  return (
    <div className={box} data-slot="held-image" data-state={revealed ? 'revealed' : 'blurred'}>
      <img
        src={image.url}
        alt={revealed ? t('moderation.media.alt') : ''}
        aria-hidden={revealed ? undefined : true}
        draggable={false}
        className={cn('size-full object-cover select-none', !revealed && 'scale-110 blur-xl')}
      />
      {revealed ? (
        <Button
          type="button"
          size="icon-xs"
          variant="secondary"
          className="absolute top-1 right-1"
          aria-label={t('moderation.media.hide')}
          onClick={() => setRevealed(false)}
        >
          <EyeOffIcon />
        </Button>
      ) : (
        <button
          type="button"
          onClick={() => setRevealed(true)}
          className="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-scrim text-xs font-medium text-media-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
        >
          <EyeIcon className="size-4" aria-hidden="true" />
          {t('moderation.media.reveal')}
        </button>
      )}
    </div>
  )
}

const statusTone = { pending: 'warn', approved: 'ok', removed: 'late' } as const

function MediaCard({
  review,
  onUser,
  onContent,
  onDecide,
}: {
  review: MediaReview
  onUser: (id: string) => void
  onContent: (target: ContentTarget) => void
  onDecide: (decision: 'approve' | 'remove') => void
}) {
  const { t } = useTranslation()
  const label = useCategoryLabel()
  const uploader = review.uploader.display_name ?? review.uploader.username ?? '–'
  return (
    <li className="flex flex-col gap-3 border-b py-3 sm:flex-row">
      <BlurredImage review={review} />
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-row font-medium">
            {t('moderation.media.score', {
              category: label(review.category),
              score: formatNumber(scorePercent(review.score)),
            })}
          </span>
          <ToneBadge tone={statusTone[review.status]}>
            {t(`moderation.media.status.${review.status}`)}
          </ToneBadge>
        </div>
        <p className="text-xs text-muted-foreground">
          {topScores(review.scores)
            .map(([name, value]) => `${label(name)} ${formatNumber(scorePercent(value))}%`)
            .join(' · ')}
        </p>
        <p className="flex flex-wrap items-center gap-x-1.5 text-xs text-muted-foreground">
          {t('moderation.media.uploadedBy')}
          <button
            type="button"
            onClick={() => onUser(review.uploader.id)}
            className="rounded-sm text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            {uploader}
            {review.uploader.username ? (
              <span className="font-mono"> @{review.uploader.username}</span>
            ) : null}
          </button>
          {review.uploader.deleted ? <span>({t('moderation.media.deletedUser')})</span> : null}
          <span>· {stamp(review.created_at)}</span>
        </p>
        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium">{t('moderation.media.usedIn')}</p>
          {review.used_in.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('moderation.media.notUsed')}</p>
          ) : (
            <ul className="flex flex-col gap-1">
              {review.used_in.map((use) => (
                <li key={`${use.type}-${use.id}`} className="flex flex-wrap items-center gap-2 text-xs">
                  <span>
                    {use.type === 'post'
                      ? t('moderation.media.usePost')
                      : t('moderation.media.useMessage', {
                          room: t(
                            `moderation.media.rooms.${use.room_type === 'stock' || use.room_type === 'group' || use.room_type === 'direct' ? use.room_type : 'other'}`,
                          ),
                        })}
                  </span>
                  <span className="text-muted-foreground">· {stamp(use.created_at)}</span>
                  {use.deleted ? (
                    <span className="text-muted-foreground">· {t('moderation.media.useDeleted')}</span>
                  ) : null}
                  <Button size="xs" variant="ghost" onClick={() => onContent({ type: use.type, id: use.id })}>
                    {t('moderation.content.open')}
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </div>
        {review.status !== 'pending' ? (
          <p className="text-xs break-words text-muted-foreground">
            {t('moderation.media.decided', {
              time: review.decided_at ? stamp(review.decided_at) : '–',
              name: review.decided_by ?? '–',
            })}
            {review.note ? ` · ${review.note}` : ''}
            {review.stripped.length > 0
              ? ` · ${t('moderation.media.stripped', { count: review.stripped.length })}`
              : ''}
          </p>
        ) : (
          <div className="flex flex-wrap gap-1.5">
            <Button size="xs" variant="outline" onClick={() => onDecide('approve')}>
              {t('moderation.media.approve')}
            </Button>
            <Button size="xs" variant="destructive" onClick={() => onDecide('remove')}>
              {t('moderation.media.remove')}
            </Button>
          </div>
        )}
        <p className="text-xs text-muted-foreground">
          {t('moderation.media.model', { model: review.model, revision: review.thresholds_revision ?? '–' })}
        </p>
      </div>
    </li>
  )
}

export function MediaQueue({
  onUser,
  onContent,
}: {
  onUser: (id: string) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<MediaStatus>('pending')
  const reviews = useMediaReviews(status)
  const decide = useDecideMedia()
  const [acting, setActing] = useState<{ review: MediaReview; decision: 'approve' | 'remove' } | null>(null)
  const pages = reviews.data?.pages ?? []
  const items = pages.flatMap((page) => page.items)
  const pending = pages[0]?.pending
  return (
    <div className="flex min-w-0 flex-col gap-3">
      <QueueHeader
        title={t('moderation.media.title')}
        hint={t('moderation.media.hint')}
        count={status === 'pending' ? pending : undefined}
      >
        <ToggleGroup
          type="single"
          value={status}
          onValueChange={(value) => {
            if ((mediaStatuses as readonly string[]).includes(value)) setStatus(value as MediaStatus)
          }}
          aria-label={t('moderation.filter')}
        >
          {mediaStatuses.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`moderation.media.status.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </QueueHeader>
      {reviews.isError ? (
        <ErrorState error={reviews.error} onRetry={() => void reviews.refetch()} />
      ) : !reviews.data ? (
        <ListSkeleton rows={3} />
      ) : items.length === 0 ? (
        <EmptyState title={t(`moderation.media.empty.${status}`)} />
      ) : (
        <>
          <ul className="border-t">
            {items.map((review) => (
              <MediaCard
                key={review.id}
                review={review}
                onUser={onUser}
                onContent={onContent}
                onDecide={(decision) => setActing({ review, decision })}
              />
            ))}
          </ul>
          {reviews.hasNextPage ? (
            <Button
              variant="outline"
              size="sm"
              className="self-center"
              disabled={reviews.isFetchingNextPage}
              onClick={() => void reviews.fetchNextPage()}
            >
              {reviews.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('moderation.loadMore')}
            </Button>
          ) : null}
        </>
      )}
      <ReasonDialog
        key={acting ? `${acting.review.id}-${acting.decision}` : 'none'}
        open={acting !== null}
        title={acting ? t(`moderation.media.titles.${acting.decision}`) : ''}
        description={acting ? t(`moderation.media.bodies.${acting.decision}`) : undefined}
        label={acting?.decision === 'remove' ? t('community.reason') : t('moderation.note')}
        hint={acting?.decision === 'remove' ? undefined : t('moderation.noteOptional')}
        optional={acting?.decision !== 'remove'}
        min={NOTE_MIN}
        max={NOTE_MAX}
        action={acting ? t(`moderation.media.${acting.decision}`) : ''}
        destructive={acting?.decision === 'remove'}
        pending={decide.isPending}
        onClose={() => setActing(null)}
        onSubmit={(note) => {
          if (!acting) return
          void decide
            .mutateAsync({ id: acting.review.id, decision: acting.decision, note: note || null })
            .then(() => {
              toast.success(t(`moderation.media.done.${acting.decision}`))
              setActing(null)
            })
            .catch((error: unknown) => toast.error(moderationErrorText(error)))
        }}
      />
    </div>
  )
}
