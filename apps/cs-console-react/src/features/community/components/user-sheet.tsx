import { BadgeCheckIcon, LoaderCircleIcon, OctagonAlertIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Avatar } from '@/components/ui/primitives'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import {
  metaKey,
  useCommunityUser,
  useContentMeta,
  useRevokeSanction,
  useRevokeSessions,
  useSanction,
} from '../hooks'
import { hasZeroTolerance } from '../logic'
import { EditHistoryButton } from './edit-history'
import { EditedMark } from './moderation-ui'
import { OfficialBadge, ReasonDialog } from './shared'
import { ZeroToleranceDialog } from './zero-tolerance'

const sanctionChoices = [
  { value: 'ladder', kind: null, hours: null },
  { value: 'warning', kind: 'warning', hours: null },
  { value: 'mute24', kind: 'mute', hours: 24 },
  { value: 'mute168', kind: 'mute', hours: 168 },
  { value: 'ban7', kind: 'ban', hours: 168 },
  { value: 'ban', kind: 'ban', hours: null },
] as const

type SanctionChoice = (typeof sanctionChoices)[number]['value']

function SanctionDialog({ userId, name, onClose }: { userId: string; name: string; onClose: () => void }) {
  const { t } = useTranslation()
  const sanction = useSanction()
  const [choice, setChoice] = useState<SanctionChoice>('ladder')
  const [reason, setReason] = useState('')
  const [touched, setTouched] = useState(false)
  const valid = reason.trim().length >= 5 && reason.trim().length <= 500
  const picked = sanctionChoices.find((item) => item.value === choice) ?? sanctionChoices[0]
  return (
    <Dialog open onOpenChange={(next) => !next && !sanction.isPending && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('community.sanctionTitle', { name })}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault()
            setTouched(true)
            if (!valid) return
            void sanction
              .mutateAsync({ id: userId, reason: reason.trim(), kind: picked.kind, hours: picked.hours })
              .then(() => {
                toast.success(t('community.sanctioned'))
                onClose()
              })
              .catch((error: unknown) => toast.error(errorText(error)))
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="sanction-kind">{t('community.sanctionKind')}</Label>
            <Select value={choice} onValueChange={(value) => setChoice(value as SanctionChoice)}>
              <SelectTrigger id="sanction-kind" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {sanctionChoices.map((item) => (
                  <SelectItem key={item.value} value={item.value}>
                    {t(`community.sanctionChoices.${item.value}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="sanction-reason">{t('community.reason')}</Label>
            <Textarea
              id="sanction-reason"
              rows={3}
              maxLength={500}
              value={reason}
              aria-invalid={touched && !valid ? true : undefined}
              onChange={(event) => setReason(event.target.value)}
            />
            <p className={cn('text-xs', touched && !valid ? 'text-destructive' : 'text-muted-foreground')}>
              {t('community.reasonHint')}
            </p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" disabled={sanction.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" variant="destructive" disabled={sanction.isPending}>
              {sanction.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('community.applySanction')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function UserDetail({ userId }: { userId: string }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const user = useCommunityUser(userId)
  const revoke = useRevokeSanction()
  const sessions = useRevokeSessions()
  const [sanctioning, setSanctioning] = useState(false)
  const [revoking, setRevoking] = useState<string | null>(null)
  const [signingOut, setSigningOut] = useState(false)
  const [zero, setZero] = useState(false)
  const canSanction = agent.community_permissions.includes('community.sanction')
  const canModerate = agent.community_permissions.includes('community.moderate')
  const metas = useContentMeta([
    ...(user.data?.recent_posts ?? []).map((item) => ({ type: 'post' as const, id: item.id })),
    ...(user.data?.recent_comments ?? []).map((item) => ({ type: 'comment' as const, id: item.id })),
  ])
  if (user.isError) return <ErrorState error={user.error} onRetry={() => void user.refetch()} />
  if (!user.data) return <ListSkeleton rows={6} className="pt-10" />
  const { profile, counts } = user.data
  const name = profile.display_name ?? profile.username
  const protectedAccount = profile.is_official || profile.is_staff
  const zeroApplied = hasZeroTolerance(user.data)
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex items-center gap-3 border-b px-5 pt-4 pr-12 pb-3">
        <Avatar name={name} className="size-9 text-xs" />
        <div className="min-w-0">
          <p className="flex items-center gap-1.5 truncate text-panel font-medium">
            {name}
            {profile.is_verified && !profile.is_official ? (
              <BadgeCheckIcon className="size-4 text-primary" aria-label={t('community.verified')} />
            ) : null}
            {profile.is_official ? <OfficialBadge /> : null}
          </p>
          <p className="truncate font-mono text-xs text-muted-foreground">@{profile.username}</p>
        </div>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid grid-cols-2 gap-x-4 gap-y-3 border-b px-5 py-4 sm:grid-cols-4">
          {(
            [
              ['posts', counts.posts],
              ['comments', counts.comments],
              ['reportsAgainst', counts.reports_against],
              ['reportsMade', counts.reports_made],
            ] as const
          ).map(([key, value]) => (
            <div key={key}>
              <dt className="text-xs text-muted-foreground">{t(`community.counts.${key}`)}</dt>
              <dd className="tabular text-row font-medium">{formatNumber(value)}</dd>
            </div>
          ))}
        </dl>
        <div className="flex flex-wrap items-center gap-2 border-b px-5 py-3 text-xs text-muted-foreground">
          <span>{t('community.joined', { time: stamp(profile.created_at) })}</span>
          <span>· {t('community.trust', { level: profile.trust_level })}</span>
          {profile.banned ? <span className="font-medium text-danger">· {t('community.banned')}</span> : null}
          {profile.muted ? <span className="font-medium text-warning">· {t('community.muted')}</span> : null}
          {zeroApplied ? (
            <span className="font-medium text-danger">· {t('moderation.zero.badge')}</span>
          ) : null}
        </div>
        {canSanction && !protectedAccount ? (
          <div className="flex flex-wrap gap-2 border-b px-5 py-3">
            <Button size="sm" variant="destructive" onClick={() => setSanctioning(true)}>
              {t('community.applySanction')}
            </Button>
            <Button size="sm" variant="outline" onClick={() => setSigningOut(true)}>
              {t('community.revokeSessions')}
            </Button>
            {zeroApplied ? null : (
              <Button
                size="sm"
                variant="outline"
                className="border-destructive/40 text-destructive"
                onClick={() => setZero(true)}
              >
                <OctagonAlertIcon />
                {t('moderation.zero.action')}
              </Button>
            )}
          </div>
        ) : null}
        <section className="border-b px-5 py-3" aria-labelledby="user-sanctions">
          <h3 id="user-sanctions" className="mb-1 text-xs font-medium text-muted-foreground">
            {t('community.sanctions')}
          </h3>
          {user.data.sanctions.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('community.noSanctions')}</p>
          ) : (
            <ul>
              {user.data.sanctions.map((item) => (
                <li
                  key={item.id}
                  className="flex items-start justify-between gap-3 border-b py-2 last:border-b-0"
                >
                  <div className="min-w-0">
                    <p className="text-row font-medium">
                      {t(`community.sanctionKinds.${item.kind}`)}
                      {item.active ? (
                        <span className="ml-2 text-xs text-danger">{t('community.active')}</span>
                      ) : null}
                    </p>
                    <p className="text-xs break-words text-muted-foreground">
                      {[
                        stamp(item.created_at),
                        item.ends_at ? t('community.until', { time: stamp(item.ends_at) }) : null,
                        item.created_by,
                        item.reason,
                        item.revoked_at ? t('community.revokedAt', { time: stamp(item.revoked_at) }) : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </p>
                  </div>
                  {canSanction && item.active ? (
                    <Button size="xs" variant="ghost" onClick={() => setRevoking(item.id)}>
                      {t('community.revoke')}
                    </Button>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </section>
        <section className="px-5 py-3" aria-labelledby="user-posts">
          <h3 id="user-posts" className="mb-1 text-xs font-medium text-muted-foreground">
            {t('community.recentPosts')}
          </h3>
          {user.data.recent_posts.length + user.data.recent_comments.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('community.noContent')}</p>
          ) : (
            <ul>
              {[...user.data.recent_posts, ...user.data.recent_comments]
                .sort((a, b) => b.created_at.localeCompare(a.created_at))
                .slice(0, 12)
                .map((item) => {
                  const type = 'post_id' in item ? ('comment' as const) : ('post' as const)
                  const editedAt = metas.get(metaKey({ type, id: item.id }))?.edited_at
                  return (
                    <li key={item.id} className="border-b py-2 last:border-b-0">
                      <p className="text-row break-words">{item.body || '–'}</p>
                      <div className="flex flex-wrap items-center justify-between gap-1">
                        <p className="text-xs text-muted-foreground">
                          {stamp(item.created_at)}
                          {'post_id' in item ? ` · ${t('community.comment')}` : ''}
                          {item.moderation_status !== 'visible'
                            ? ` · ${t(`community.moderation.${item.moderation_status === 'hidden' ? 'hidden' : 'held'}`)}`
                            : ''}{' '}
                          <EditedMark editedAt={editedAt} />
                        </p>
                        {canModerate && editedAt ? <EditHistoryButton type={type} id={item.id} /> : null}
                      </div>
                    </li>
                  )
                })}
            </ul>
          )}
        </section>
      </div>
      {sanctioning ? (
        <SanctionDialog userId={userId} name={name} onClose={() => setSanctioning(false)} />
      ) : null}
      {zero ? (
        <ZeroToleranceDialog
          target={{ id: userId, username: profile.username, name }}
          onClose={() => setZero(false)}
        />
      ) : null}
      <ReasonDialog
        open={revoking !== null}
        title={t('community.revokeTitle')}
        label={t('community.reason')}
        action={t('community.revoke')}
        pending={revoke.isPending}
        onClose={() => setRevoking(null)}
        onSubmit={(reason) =>
          void revoke
            .mutateAsync({ id: revoking ?? '', reason })
            .then(() => {
              setRevoking(null)
              toast.success(t('community.revoked'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
      <ReasonDialog
        open={signingOut}
        title={t('community.revokeSessionsTitle', { name })}
        description={t('community.revokeSessionsBody')}
        label={t('community.reason')}
        action={t('community.revokeSessions')}
        destructive
        pending={sessions.isPending}
        onClose={() => setSigningOut(false)}
        onSubmit={(reason) =>
          void sessions
            .mutateAsync({ id: userId, reason })
            .then(() => {
              setSigningOut(false)
              toast.success(t('community.sessionsRevoked'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
    </div>
  )
}

export function UserSheet({ userId, onClose }: { userId: string | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Sheet open={userId !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('community.userDetail')}
        closeLabel={t('app.close')}
        className="w-[min(560px,100vw)] bg-background"
      >
        {userId ? <UserDetail key={userId} userId={userId} /> : null}
      </SheetContent>
    </Sheet>
  )
}
