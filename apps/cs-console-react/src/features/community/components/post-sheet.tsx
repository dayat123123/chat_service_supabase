import { LoaderCircleIcon, PinIcon, PinOffIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { useAgent } from '@/features/auth/hooks'
import { Confirm } from '@/features/nasabah/components/confirm'
import { errorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import { useCancelPost, useDeletePost, usePinPost, useReviewPost, useSubmitPost } from '../hooks'
import {
  canCancel,
  canEdit,
  canManagePublished,
  canReview,
  canSubmit,
  reviewBlockedByFourEyes,
} from '../logic'
import type { CommunityPost } from '../types'
import { AccountChip, CampaignStatusText, PostImages, PostStatusText, ReasonDialog } from './shared'

function Fact({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row">{children}</dd>
    </div>
  )
}

function Step({
  label,
  at,
  by,
  note,
}: {
  label: string
  at: string | null
  by?: string | null
  note?: string | null
}) {
  if (!at) return null
  return (
    <li className="flex gap-3 border-b py-2 last:border-b-0">
      <span className="tabular w-28 shrink-0 text-xs text-muted-foreground">{stamp(at)}</span>
      <div className="min-w-0">
        <p className="text-row font-medium">{label}</p>
        {by || note ? (
          <p className="text-xs break-words text-muted-foreground">
            {[by, note].filter(Boolean).join(' · ')}
          </p>
        ) : null}
      </div>
    </li>
  )
}

export function PostDetail({ post, onEdit }: { post: CommunityPost; onEdit: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const actor = {
    id: agent.id,
    perms: agent.community_permissions,
    fourEyes: agent.settings.community_four_eyes,
  }
  const submit = useSubmitPost()
  const review = useReviewPost()
  const cancel = useCancelPost()
  const pin = usePinPost()
  const remove = useDeletePost()
  const [rejecting, setRejecting] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [cancelling, setCancelling] = useState(false)
  const busy = submit.isPending || review.isPending || cancel.isPending || pin.isPending || remove.isPending
  const run = (action: Promise<unknown>, message: string) =>
    void action.then(() => toast.success(message)).catch((error: unknown) => toast.error(errorText(error)))
  const pinLabel = post.pin_scope
    ? post.pin_scope === 'stock'
      ? t('community.pinnedStock', { code: post.pin_stock })
      : t('community.pinnedGlobal')
    : t('community.notPinned')

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-2 border-b px-5 pt-4 pr-12 pb-3">
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <AccountChip account={post.account} />
          <PostStatusText status={post.status} />
        </div>
        <p className="text-xs text-muted-foreground">
          {t(`community.kinds.${post.kind}`)}
          {post.pinned ? ` · ${pinLabel}` : ''}
        </p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <article className="flex flex-col gap-3 border-b px-5 py-4">
          {post.title ? <h2 className="text-panel font-semibold">{post.title}</h2> : null}
          <p className="text-sm break-words whitespace-pre-wrap">{post.body}</p>
          <PostImages attachments={post.attachments} />
        </article>
        <dl className="grid grid-cols-2 gap-x-4 gap-y-3 border-b px-5 py-4">
          <Fact label={t('community.pin')}>
            {post.pin_scope
              ? `${pinLabel}${post.pin_until ? ` · ${t('community.until', { time: stamp(post.pin_until) })}` : ''}`
              : t('community.notPinned')}
          </Fact>
          <Fact label={t('community.publishTime')}>
            {post.published_at
              ? stamp(post.published_at)
              : post.publish_at
                ? t('community.scheduledAt', { time: stamp(post.publish_at) })
                : t('community.publishNow')}
          </Fact>
          <Fact label={t('community.notify')}>
            {post.campaign ? (
              <span className="inline-flex items-center gap-2">
                <CampaignStatusText status={post.campaign.status} />
                <span className="tabular text-xs text-muted-foreground">
                  {t('community.recipients', { count: post.campaign.recipients })}
                </span>
              </span>
            ) : post.notify ? (
              t('community.notifyOnPublish')
            ) : (
              t('community.noNotify')
            )}
          </Fact>
          {post.post ? (
            <Fact label={t('community.engagement')}>
              {post.post.deleted
                ? t('community.deleted')
                : t('community.engagementValue', {
                    likes: formatNumber(post.post.like_count),
                    comments: formatNumber(post.post.comment_count),
                  })}
            </Fact>
          ) : null}
        </dl>
        <section className="px-5 py-3" aria-labelledby="post-history">
          <h3 id="post-history" className="text-xs font-medium text-muted-foreground">
            {t('community.history')}
          </h3>
          <ol>
            <Step label={t('community.steps.created')} at={post.created_at} by={post.created_by?.name} />
            <Step label={t('community.steps.submitted')} at={post.submitted_at} />
            <Step
              label={
                post.status === 'rejected' ? t('community.steps.rejected') : t('community.steps.approved')
              }
              at={post.reviewed_at}
              by={post.reviewed_by?.name}
              note={post.review_note}
            />
            <Step label={t('community.steps.published')} at={post.published_at} />
          </ol>
          {post.error ? <p className="mt-2 text-xs text-destructive">{post.error}</p> : null}
        </section>
      </div>
      <footer className="flex flex-col gap-2 border-t px-5 py-3">
        {reviewBlockedByFourEyes(post, actor) ? (
          <p className="text-xs text-muted-foreground">{t('community.fourEyesHint')}</p>
        ) : null}
        <div className="flex flex-wrap items-center gap-2">
          {canEdit(post, actor) ? (
            <Button variant="outline" size="sm" disabled={busy} onClick={onEdit}>
              {t('app.edit')}
            </Button>
          ) : null}
          {canSubmit(post, actor) ? (
            <Button
              size="sm"
              disabled={busy}
              onClick={() =>
                run(submit.mutateAsync({ id: post.id, version: post.version }), t('community.saved.submit'))
              }
            >
              {t('community.submit')}
            </Button>
          ) : null}
          {canReview(post, actor) ? (
            <>
              <Button
                size="sm"
                disabled={busy}
                onClick={() =>
                  run(
                    review.mutateAsync({ id: post.id, approve: true, note: null, version: post.version }),
                    post.publish_at && post.publish_at > new Date().toISOString()
                      ? t('community.saved.scheduled')
                      : t('community.saved.publish'),
                  )
                }
              >
                {review.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
                {post.publish_at && post.publish_at > new Date().toISOString()
                  ? t('community.approveSchedule')
                  : t('community.approvePublish')}
              </Button>
              {post.status === 'pending' ? (
                <Button variant="outline" size="sm" disabled={busy} onClick={() => setRejecting(true)}>
                  {t('community.reject')}
                </Button>
              ) : null}
            </>
          ) : null}
          {canManagePublished(post, actor) ? (
            <>
              <Button
                variant="outline"
                size="sm"
                disabled={busy}
                onClick={() =>
                  run(
                    post.pinned
                      ? pin.mutateAsync({ id: post.id, scope: null, stock: null, until: null })
                      : pin.mutateAsync({
                          id: post.id,
                          scope: post.pin_scope ?? 'global',
                          stock: post.pin_stock,
                          until:
                            post.pin_until && post.pin_until > new Date().toISOString()
                              ? post.pin_until
                              : null,
                        }),
                    post.pinned ? t('community.unpinned') : t('community.pinnedDone'),
                  )
                }
              >
                {post.pinned ? <PinOffIcon /> : <PinIcon />}
                {post.pinned ? t('community.unpin') : t('community.repin')}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive"
                disabled={busy}
                onClick={() => setDeleting(true)}
              >
                {t('community.deletePost')}
              </Button>
            </>
          ) : null}
          {canCancel(post, actor) ? (
            <Button variant="ghost" size="sm" disabled={busy} onClick={() => setCancelling(true)}>
              {t('community.cancel')}
            </Button>
          ) : null}
        </div>
      </footer>
      <ReasonDialog
        open={rejecting}
        title={t('community.rejectTitle')}
        label={t('community.rejectNote')}
        action={t('community.reject')}
        pending={review.isPending}
        onClose={() => setRejecting(false)}
        onSubmit={(note) =>
          void review
            .mutateAsync({ id: post.id, approve: false, note, version: post.version })
            .then(() => {
              setRejecting(false)
              toast.success(t('community.rejected'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
      <ReasonDialog
        open={deleting}
        title={t('community.deleteTitle')}
        description={t('community.deleteBody')}
        label={t('community.reason')}
        action={t('community.deletePost')}
        destructive
        pending={remove.isPending}
        onClose={() => setDeleting(false)}
        onSubmit={(reason) =>
          void remove
            .mutateAsync({ id: post.id, reason })
            .then(() => {
              setDeleting(false)
              toast.success(t('community.deletedDone'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
      <Confirm
        open={cancelling}
        title={t('community.cancelTitle')}
        body={t('community.cancelBody')}
        action={t('community.cancel')}
        pending={cancel.isPending}
        destructive
        onConfirm={() =>
          void cancel
            .mutateAsync({ id: post.id, version: post.version })
            .then(() => {
              setCancelling(false)
              toast.success(t('community.cancelled'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
        onClose={() => setCancelling(false)}
      />
    </div>
  )
}

export function PostSheet({
  post,
  onClose,
  onEdit,
}: {
  post: CommunityPost | null
  onClose: () => void
  onEdit: (post: CommunityPost) => void
}) {
  const { t } = useTranslation()
  return (
    <Sheet open={post !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('community.postDetail')}
        closeLabel={t('app.close')}
        className="w-[min(640px,100vw)] bg-background"
      >
        {post ? <PostDetail key={post.id} post={post} onEdit={() => onEdit(post)} /> : null}
      </SheetContent>
    </Sheet>
  )
}
