import { ShieldAlertIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { useAgent } from '@/features/auth/hooks'
import { ToneBadge } from '@/features/system/components/system-ui'
import { moderationErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useAppeals, useDecideAppeal } from '../hooks'
import { appealBlock } from '../logic'
import {
  APPEAL_NOTE_MAX,
  appealStatuses,
  NOTE_MIN,
  type Appeal,
  type AppealContent,
  type AppealSanction,
  type AppealStatus,
} from '../types'
import { QueueHeader } from './moderation-ui'
import { ReasonDialog } from './shared'

const statusTone = { pending: 'warn', accepted: 'ok', rejected: 'neutral' } as const

const contentStates = ['visible', 'held', 'hidden', 'removed', 'deleted'] as const

function TargetSummary({ appeal }: { appeal: Appeal }) {
  const { t } = useTranslation()
  if (!appeal.target)
    return <p className="text-xs text-muted-foreground">{t('moderation.appeals.targetMissing')}</p>
  if (appeal.target_type === 'sanction') {
    const sanction = appeal.target as AppealSanction
    return (
      <div className="flex flex-col gap-0.5 rounded-md bg-subtle p-2 text-row">
        <p className="font-medium">
          {t(`community.sanctionKinds.${sanction.kind}`)}
          {sanction.active ? (
            <span className="ml-2 text-xs text-danger">{t('community.active')}</span>
          ) : (
            <span className="ml-2 text-xs text-muted-foreground">{t('moderation.appeals.inactive')}</span>
          )}
        </p>
        <p className="text-xs break-words text-muted-foreground">
          {[
            stamp(sanction.starts_at),
            sanction.ends_at
              ? t('community.until', { time: stamp(sanction.ends_at) })
              : t('moderation.appeals.permanent'),
            sanction.reason,
          ].join(' · ')}
        </p>
      </div>
    )
  }
  const content = appeal.target as AppealContent
  const state = (contentStates as readonly string[]).includes(content.state)
    ? t(`moderation.appeals.states.${content.state as (typeof contentStates)[number]}`)
    : content.state
  return (
    <div className="flex flex-col gap-0.5 rounded-md bg-subtle p-2">
      <p className="text-xs text-muted-foreground">
        {state}
        {content.decided_at ? ` · ${stamp(content.decided_at)}` : ''}
      </p>
      <p className="text-row break-words whitespace-pre-wrap">{content.excerpt || '–'}</p>
    </div>
  )
}

function AppealItem({
  appeal,
  onUser,
  onDecide,
}: {
  appeal: Appeal
  onUser: (id: string) => void
  onDecide: (accept: boolean) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const block = appealBlock(appeal, agent.id, agent.community_permissions)
  const name = appeal.user.display_name ?? appeal.user.username
  return (
    <li className="flex flex-col gap-2 border-b py-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
          <span className="font-medium text-foreground">
            {t(`moderation.appeals.targets.${appeal.target_type}`)}
          </span>
          <span>· {stamp(appeal.created_at)}</span>
          {appeal.original_decider ? (
            <span>· {t('moderation.appeals.originalDecider', { name: appeal.original_decider.name })}</span>
          ) : null}
        </span>
        <ToneBadge tone={statusTone[appeal.status]}>
          {t(`moderation.appeals.status.${appeal.status}`)}
        </ToneBadge>
      </div>
      <button
        type="button"
        onClick={() => onUser(appeal.user.id)}
        className="flex flex-wrap items-center gap-1.5 self-start rounded-sm text-xs text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
      >
        {name}
        <span className="font-mono text-muted-foreground">@{appeal.user.username}</span>
        {appeal.user.banned ? <span className="text-danger">{t('community.banned')}</span> : null}
      </button>
      <TargetSummary appeal={appeal} />
      <div className="flex flex-col gap-0.5">
        <p className="text-xs text-muted-foreground">{t('moderation.appeals.reason')}</p>
        <p className="text-row break-words whitespace-pre-wrap">{appeal.reason}</p>
      </div>
      {appeal.status !== 'pending' ? (
        <p className="text-xs break-words text-muted-foreground">
          {t('moderation.appeals.decided', {
            time: appeal.decided_at ? stamp(appeal.decided_at) : '–',
            name: appeal.decided_by?.name ?? '–',
            note: appeal.decision_note ?? '–',
          })}
        </p>
      ) : appeal.can_decide ? (
        <div className="flex flex-wrap gap-1.5">
          <Button size="xs" variant="default" onClick={() => onDecide(true)}>
            {t('moderation.appeals.accept')}
          </Button>
          <Button size="xs" variant="outline" onClick={() => onDecide(false)}>
            {t('moderation.appeals.reject')}
          </Button>
        </div>
      ) : (
        <p role="note" className="flex items-start gap-1.5 text-xs text-warning">
          <ShieldAlertIcon className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
          {t(`moderation.appeals.blocked.${block ?? 'other'}`)}
        </p>
      )}
    </li>
  )
}

export function AppealsQueue({ onUser }: { onUser: (id: string) => void }) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<AppealStatus>('pending')
  const appeals = useAppeals(status)
  const decide = useDecideAppeal()
  const [acting, setActing] = useState<{ appeal: Appeal; accept: boolean } | null>(null)
  return (
    <div className="flex min-w-0 flex-col gap-3">
      <QueueHeader
        title={t('moderation.appeals.title')}
        hint={t('moderation.appeals.hint')}
        count={appeals.data?.length}
      >
        <ToggleGroup
          type="single"
          value={status}
          onValueChange={(value) => {
            if ((appealStatuses as readonly string[]).includes(value)) setStatus(value as AppealStatus)
          }}
          aria-label={t('moderation.filter')}
        >
          {appealStatuses.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`moderation.appeals.status.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </QueueHeader>
      {appeals.isError ? (
        <ErrorState error={appeals.error} onRetry={() => void appeals.refetch()} />
      ) : !appeals.data ? (
        <ListSkeleton rows={3} />
      ) : appeals.data.length === 0 ? (
        <EmptyState title={t(`moderation.appeals.empty.${status}`)} />
      ) : (
        <ul className="border-t">
          {appeals.data.map((appeal) => (
            <AppealItem
              key={appeal.id}
              appeal={appeal}
              onUser={onUser}
              onDecide={(accept) => setActing({ appeal, accept })}
            />
          ))}
        </ul>
      )}
      <ReasonDialog
        key={acting ? `${acting.appeal.id}-${String(acting.accept)}` : 'none'}
        open={acting !== null}
        title={
          acting ? t(acting.accept ? 'moderation.appeals.acceptTitle' : 'moderation.appeals.rejectTitle') : ''
        }
        description={
          acting
            ? t(
                acting.accept
                  ? acting.appeal.target_type === 'sanction'
                    ? 'moderation.appeals.acceptSanctionBody'
                    : 'moderation.appeals.acceptContentBody'
                  : 'moderation.appeals.rejectBody',
              )
            : undefined
        }
        label={t('moderation.appeals.note')}
        hint={t('moderation.appeals.noteHint')}
        min={NOTE_MIN}
        max={APPEAL_NOTE_MAX}
        action={acting ? t(acting.accept ? 'moderation.appeals.accept' : 'moderation.appeals.reject') : ''}
        pending={decide.isPending}
        onClose={() => setActing(null)}
        onSubmit={(note) => {
          if (!acting) return
          void decide
            .mutateAsync({ id: acting.appeal.id, accept: acting.accept, note })
            .then(() => {
              toast.success(t(acting.accept ? 'moderation.appeals.accepted' : 'moderation.appeals.rejected'))
              setActing(null)
            })
            .catch((error: unknown) => toast.error(moderationErrorText(error)))
        }}
      />
    </div>
  )
}
