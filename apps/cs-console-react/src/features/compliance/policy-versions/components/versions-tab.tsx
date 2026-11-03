import {
  ChevronDownIcon,
  ChevronRightIcon,
  FlaskConicalIcon,
  HistoryIcon,
  LoaderCircleIcon,
  SendIcon,
  Trash2Icon,
} from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { PolicyCard } from '@/features/content-policy/components/policy-ui'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText, ToneBadge } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { format } from '@/lib/time'

import {
  useDecideChange,
  useDiscardDraft,
  usePolicyChange,
  usePolicyChanges,
  usePolicyState,
  usePolicyVersion,
  usePolicyVersions,
  useRollback,
  useSubmitDraft,
  useWithdrawChange,
} from '../hooks'
import { reasonProblem } from '../logic'
import {
  REASON_MAX,
  REASON_MIN,
  type ChangeStatus,
  type PolicyChange,
  type PolicyDraft,
  type PolicyState,
  type PolicyVersion,
  type SimTarget,
} from '../types'
import { DiffCounts, DiffView } from './diff-view'
import { SimulationDialog } from './simulation-dialog'

const stamp = (value: string) => `${format(value, 'd MMM yyyy, HH.mm')} WIB`

const statusTones: Record<ChangeStatus, 'ok' | 'warn' | 'late' | 'neutral'> = {
  pending: 'warn',
  approved: 'ok',
  rejected: 'late',
  withdrawn: 'neutral',
}

function SimulateButton({ target, label }: { target: SimTarget; label?: string }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button size="sm" variant="outline" aria-label={label} onClick={() => setOpen(true)}>
        <FlaskConicalIcon />
        {t('policy.versions.simulation.open')}
      </Button>
      {open ? <SimulationDialog target={target} open onClose={() => setOpen(false)} /> : null}
    </>
  )
}

function ReasonField({
  id,
  label,
  value,
  onChange,
  error,
  hint,
}: {
  id: string
  label: string
  value: string
  onChange: (value: string) => void
  error?: string
  hint: string
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Textarea
        id={id}
        rows={3}
        maxLength={REASON_MAX + 50}
        value={value}
        aria-invalid={error ? true : undefined}
        aria-describedby={`${id}-hint`}
        onChange={(event) => onChange(event.target.value)}
      />
      <FieldText id={`${id}-hint`} error={error} hint={hint} />
    </div>
  )
}

function DraftCard({ state, draft }: { state: PolicyState; draft: PolicyDraft | null }) {
  const { t } = useTranslation()
  const id = useId()
  const submit = useSubmitDraft()
  const discard = useDiscardDraft()
  const [reason, setReason] = useState('')
  const [checked, setChecked] = useState(false)
  const [discarding, setDiscarding] = useState(false)
  const problem = reasonProblem(reason)
  if (!draft) {
    return (
      <PolicyCard title={t('policy.versions.draft.title')} subtitle={t('policy.versions.draft.subtitle')}>
        <p className="text-row text-muted-foreground">{t('policy.versions.draft.empty')}</p>
      </PolicyCard>
    )
  }
  const empty = draft.diff.total === 0
  return (
    <PolicyCard
      title={t('policy.versions.draft.title')}
      subtitle={t('policy.versions.draft.subtitle')}
      action={
        <div className="flex flex-wrap gap-2">
          <SimulateButton target={{ kind: 'draft' }} />
          <Button size="sm" variant="ghost" onClick={() => setDiscarding(true)}>
            <Trash2Icon />
            {t('policy.versions.draft.discard')}
          </Button>
        </div>
      }
    >
      <p className="text-xs text-muted-foreground">
        {t('policy.versions.draft.base', { version: draft.base_version, time: stamp(draft.updated_at) })}
      </p>
      {empty ? (
        <p className="text-row text-muted-foreground">{t('policy.versions.draft.noChanges')}</p>
      ) : (
        <DiffView diff={draft.diff} />
      )}
      <form
        className="flex flex-col gap-3"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (problem || empty) return
          submit
            .mutateAsync(reason.trim())
            .then((change) => {
              toast.success(
                change.status === 'approved'
                  ? t('policy.versions.draft.activated', { version: change.applied_version })
                  : t('policy.versions.draft.submitted'),
              )
              setReason('')
              setChecked(false)
            })
            .catch((caught: unknown) => toast.error(policyErrorText(caught)))
        }}
      >
        <ReasonField
          id={`${id}-reason`}
          label={t('policy.versions.draft.reason')}
          value={reason}
          onChange={setReason}
          error={
            checked && problem
              ? t(`policy.versions.draft.reasonProblems.${problem}`, { min: REASON_MIN, max: REASON_MAX })
              : undefined
          }
          hint={t('policy.versions.draft.reasonHint', { min: REASON_MIN, max: REASON_MAX })}
        />
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" disabled={submit.isPending || empty}>
            {submit.isPending ? <LoaderCircleIcon className="animate-spin" /> : <SendIcon />}
            {state.four_eyes ? t('policy.versions.draft.submit') : t('policy.versions.draft.activate')}
          </Button>
          <span className="text-xs text-muted-foreground">
            {state.four_eyes ? t('policy.versions.fourEyesOnHint') : t('policy.versions.fourEyesOffHint')}
          </span>
        </div>
      </form>
      <Confirm
        open={discarding}
        title={t('policy.versions.draft.discardTitle')}
        body={t('policy.versions.draft.discardBody')}
        action={t('policy.versions.draft.discard')}
        destructive
        pending={discard.isPending}
        onClose={() => setDiscarding(false)}
        onConfirm={() =>
          discard
            .mutateAsync()
            .then(() => {
              toast.success(t('policy.versions.draft.discarded'))
              setDiscarding(false)
            })
            .catch((caught: unknown) => toast.error(policyErrorText(caught)))
        }
      />
    </PolicyCard>
  )
}

function useChangeName() {
  const { t } = useTranslation()
  return (change: PolicyChange): string =>
    change.kind === 'rollback'
      ? t('policy.versions.pending.rollback', { id: change.id, version: change.rollback_to })
      : t('policy.versions.pending.edit', { id: change.id })
}

function DecideDialog({
  change,
  approve,
  onClose,
}: {
  change: PolicyChange
  approve: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const decide = useDecideChange()
  const [note, setNote] = useState('')
  const [checked, setChecked] = useState(false)
  const name = useChangeName()(change)
  const length = note.trim().length
  const invalid = approve ? length > REASON_MAX : reasonProblem(note) !== null
  return (
    <Dialog open onOpenChange={(next) => !next && !decide.isPending && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            setChecked(true)
            if (invalid) return
            decide
              .mutateAsync({ id: change.id, approve, note })
              .then((saved) => {
                toast.success(
                  approve
                    ? t('policy.versions.pending.approved', { name, version: saved.applied_version })
                    : t('policy.versions.pending.rejected', { name }),
                )
                onClose()
              })
              .catch((caught: unknown) => toast.error(policyErrorText(caught)))
          }}
        >
          <DialogHeader>
            <DialogTitle>
              {approve
                ? t('policy.versions.pending.approveTitle', { name })
                : t('policy.versions.pending.rejectTitle', { name })}
            </DialogTitle>
            <DialogDescription>
              {approve ? t('policy.versions.pending.approveBody') : t('policy.versions.pending.rejectBody')}
            </DialogDescription>
          </DialogHeader>
          <ReasonField
            id={`${id}-note`}
            label={t('policy.versions.pending.note')}
            value={note}
            onChange={setNote}
            error={
              checked && invalid
                ? t('policy.versions.pending.noteProblem', { min: approve ? 0 : REASON_MIN, max: REASON_MAX })
                : undefined
            }
            hint={
              approve
                ? t('policy.versions.pending.noteOptional', { max: REASON_MAX })
                : t('policy.versions.pending.noteRequired', { min: REASON_MIN, max: REASON_MAX })
            }
          />
          <DialogFooter>
            <Button type="button" variant="ghost" disabled={decide.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" variant={approve ? 'default' : 'destructive'} disabled={decide.isPending}>
              {decide.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {approve ? t('policy.versions.pending.approve') : t('policy.versions.pending.reject')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function PendingItem({ change }: { change: PolicyChange }) {
  const { t } = useTranslation()
  const withdraw = useWithdrawChange()
  const [deciding, setDeciding] = useState<'approve' | 'reject' | null>(null)
  const [withdrawing, setWithdrawing] = useState(false)
  const name = useChangeName()(change)
  return (
    <li className="flex flex-col gap-2 p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="flex min-w-0 flex-col gap-0.5">
          <p className="flex flex-wrap items-center gap-2 text-row font-medium">
            {name}
            {change.mine ? <ToneBadge tone="neutral">{t('policy.versions.pending.mine')}</ToneBadge> : null}
            {change.stale ? <ToneBadge tone="late">{t('policy.versions.pending.stale')}</ToneBadge> : null}
          </p>
          <p className="text-xs text-muted-foreground">
            {t('policy.versions.pending.by', {
              name: change.created_by?.name ?? '–',
              time: stamp(change.submitted_at ?? change.created_at),
            })}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <SimulateButton target={{ kind: 'change', id: change.id }} />
          {change.can_decide ? (
            <>
              <Button size="sm" onClick={() => setDeciding('approve')}>
                {t('policy.versions.pending.approve')}
              </Button>
              <Button size="sm" variant="outline" onClick={() => setDeciding('reject')}>
                {t('policy.versions.pending.reject')}
              </Button>
            </>
          ) : null}
          {change.mine ? (
            <Button size="sm" variant="ghost" onClick={() => setWithdrawing(true)}>
              {t('policy.versions.pending.withdraw')}
            </Button>
          ) : null}
        </div>
      </div>
      <p className="text-row">
        <span className="text-muted-foreground">{t('policy.versions.pending.reasonLabel')}: </span>
        {change.reason}
      </p>
      <p className="text-row">
        <DiffCounts diff={change.diff} />
      </p>
      {change.stale ? (
        <p className="text-xs text-destructive">{t('policy.versions.pending.staleHint')}</p>
      ) : null}
      {change.mine && !change.can_decide ? (
        <p className="text-xs text-muted-foreground">{t('policy.versions.pending.fourEyesHint')}</p>
      ) : null}
      <ChangeDetail id={change.id} />
      {deciding ? (
        <DecideDialog change={change} approve={deciding === 'approve'} onClose={() => setDeciding(null)} />
      ) : null}
      <Confirm
        open={withdrawing}
        title={t('policy.versions.pending.withdrawTitle', { name })}
        body={t('policy.versions.pending.withdrawBody')}
        action={t('policy.versions.pending.withdraw')}
        destructive
        pending={withdraw.isPending}
        onClose={() => setWithdrawing(false)}
        onConfirm={() =>
          withdraw
            .mutateAsync(change.id)
            .then(() => {
              toast.success(t('policy.versions.pending.withdrawn', { name }))
              setWithdrawing(false)
            })
            .catch((caught: unknown) => toast.error(policyErrorText(caught)))
        }
      />
    </li>
  )
}

function Disclosure({
  showLabel,
  hideLabel,
  children,
}: {
  showLabel: string
  hideLabel: string
  children: () => React.ReactNode
}) {
  const [open, setOpen] = useState(false)
  return (
    <div className="flex flex-col gap-2">
      <Button
        size="xs"
        variant="ghost"
        className="self-start"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        {open ? <ChevronDownIcon /> : <ChevronRightIcon />}
        {open ? hideLabel : showLabel}
      </Button>
      {open ? <div className="rounded-md border bg-subtle p-3">{children()}</div> : null}
    </div>
  )
}

function ChangeDetail({ id }: { id: number }) {
  const { t } = useTranslation()
  return (
    <Disclosure showLabel={t('policy.versions.diff.label')} hideLabel={t('policy.versions.diff.label')}>
      {() => <ChangeDiff id={id} />}
    </Disclosure>
  )
}

function ChangeDiff({ id }: { id: number }) {
  const detail = usePolicyChange(id)
  if (detail.data) return <DiffView diff={detail.data.diff} />
  if (detail.isError) return <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
  return <ListSkeleton rows={2} />
}

function PendingList() {
  const { t } = useTranslation()
  const changes = usePolicyChanges('pending')
  return (
    <PolicyCard title={t('policy.versions.pending.title')} subtitle={t('policy.versions.pending.subtitle')}>
      <QueryContent query={changes}>
        {(rows) =>
          rows.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('policy.versions.pending.empty')}</p>
          ) : (
            <ul className="flex flex-col divide-y rounded-lg border">
              {rows.map((change) => (
                <PendingItem key={change.id} change={change} />
              ))}
            </ul>
          )
        }
      </QueryContent>
    </PolicyCard>
  )
}

function DecidedList() {
  const { t } = useTranslation()
  const changeName = useChangeName()
  const changes = usePolicyChanges('decided')
  return (
    <PolicyCard title={t('policy.versions.pending.decidedTitle')}>
      <QueryContent query={changes}>
        {(rows) =>
          rows.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('policy.versions.pending.decidedEmpty')}</p>
          ) : (
            <ul className="flex flex-col divide-y rounded-lg border">
              {rows.slice(0, 20).map((change) => (
                <li key={change.id} className="flex flex-col gap-1 p-3">
                  <p className="flex flex-wrap items-center gap-2 text-row font-medium">
                    {changeName(change)}
                    <ToneBadge tone={statusTones[change.status]}>
                      {t(`policy.versions.pending.statuses.${change.status}`)}
                    </ToneBadge>
                    {change.applied_version ? (
                      <span className="text-xs font-normal text-muted-foreground">
                        {t('policy.versions.pending.appliedAs', { version: change.applied_version })}
                      </span>
                    ) : null}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {t('policy.versions.pending.by', {
                      name: change.created_by?.name ?? '–',
                      time: stamp(change.submitted_at ?? change.created_at),
                    })}
                    {change.decided_at
                      ? ` · ${t('policy.versions.pending.decidedBy', {
                          status: t(`policy.versions.pending.statuses.${change.status}`),
                          name: change.decided_by?.name ?? '–',
                          time: stamp(change.decided_at),
                        })}`
                      : null}
                  </p>
                  <p className="text-row">
                    <span className="text-muted-foreground">
                      {t('policy.versions.pending.reasonLabel')}:{' '}
                    </span>
                    {change.reason}
                  </p>
                  {change.decision_note ? (
                    <p className="text-row">
                      <span className="text-muted-foreground">
                        {t('policy.versions.pending.noteLabel')}:{' '}
                      </span>
                      {change.decision_note}
                    </p>
                  ) : null}
                </li>
              ))}
            </ul>
          )
        }
      </QueryContent>
    </PolicyCard>
  )
}

function RollbackDialog({
  version,
  fourEyes,
  onClose,
}: {
  version: number
  fourEyes: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const detail = usePolicyVersion(version)
  const rollback = useRollback()
  const [reason, setReason] = useState('')
  const [checked, setChecked] = useState(false)
  const problem = reasonProblem(reason)
  return (
    <Dialog open onOpenChange={(next) => !next && !rollback.isPending && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl" closeLabel={t('app.close')}>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            setChecked(true)
            if (problem) return
            rollback
              .mutateAsync({ version, reason: reason.trim() })
              .then((change) => {
                toast.success(
                  change.status === 'approved'
                    ? t('policy.versions.rollback.applied', { version, applied: change.applied_version })
                    : t('policy.versions.rollback.submitted', { version }),
                )
                onClose()
              })
              .catch((caught: unknown) => toast.error(policyErrorText(caught)))
          }}
        >
          <DialogHeader>
            <DialogTitle>{t('policy.versions.rollback.title', { version })}</DialogTitle>
            <DialogDescription>
              {fourEyes
                ? t('policy.versions.rollback.bodyFourEyes', { version })
                : t('policy.versions.rollback.body', { version })}
            </DialogDescription>
          </DialogHeader>
          <section className="flex flex-col gap-2">
            <h3 className="text-row font-medium">{t('policy.versions.rollback.changes')}</h3>
            {detail.data ? (
              <DiffView diff={detail.data.restore} label={t('policy.versions.rollback.changes')} />
            ) : detail.isError ? (
              <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
            ) : (
              <ListSkeleton rows={3} />
            )}
          </section>
          <ReasonField
            id={`${id}-reason`}
            label={t('policy.versions.rollback.reason')}
            value={reason}
            onChange={setReason}
            error={
              checked && problem
                ? t(`policy.versions.draft.reasonProblems.${problem}`, { min: REASON_MIN, max: REASON_MAX })
                : undefined
            }
            hint={t('policy.versions.draft.reasonHint', { min: REASON_MIN, max: REASON_MAX })}
          />
          <DialogFooter>
            <SimulateButton target={{ kind: 'version', version }} />
            <Button type="button" variant="ghost" disabled={rollback.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={rollback.isPending || detail.data?.restore.total === 0}>
              {rollback.isPending ? <LoaderCircleIcon className="animate-spin" /> : <HistoryIcon />}
              {fourEyes ? t('policy.versions.rollback.submit') : t('policy.versions.rollback.apply')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function VersionDiff({ version }: { version: number }) {
  const detail = usePolicyVersion(version)
  if (detail.data) return <DiffView diff={detail.data.diff} />
  if (detail.isError) return <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
  return <ListSkeleton rows={2} />
}

function VersionRow({
  row,
  canRestore,
  onRestore,
}: {
  row: PolicyVersion
  canRestore: boolean
  onRestore: () => void
}) {
  const { t } = useTranslation()
  return (
    <li className="flex flex-col gap-1.5 p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="flex min-w-0 flex-col gap-0.5">
          <p className="flex flex-wrap items-center gap-2 text-row font-medium">
            <span className="tabular">v{row.version}</span>
            <ToneBadge tone={row.source === 'rollback' ? 'warn' : 'neutral'}>
              {t(`policy.versions.history.sources.${row.source}`)}
            </ToneBadge>
            {row.current ? (
              <ToneBadge tone="ok">{t('policy.versions.history.currentBadge')}</ToneBadge>
            ) : null}
            {row.restored_from ? (
              <span className="text-xs font-normal text-muted-foreground">
                {t('policy.versions.history.restoredFrom', { version: row.restored_from })}
              </span>
            ) : null}
            {row.change_id ? (
              <span className="text-xs font-normal text-muted-foreground">
                {t('policy.versions.history.fromChange', { id: row.change_id })}
              </span>
            ) : null}
          </p>
          <p className="text-xs text-muted-foreground">
            {stamp(row.created_at)} · {row.created_by?.name ?? t('policy.versions.history.system')}
          </p>
        </div>
        {canRestore && !row.current ? (
          <Button
            size="sm"
            variant="outline"
            aria-label={t('policy.versions.history.restoreLabel', { version: row.version })}
            onClick={onRestore}
          >
            <HistoryIcon />
            {t('policy.versions.history.restore')}
          </Button>
        ) : null}
      </div>
      <p className="text-row">{row.reason ?? t('policy.versions.history.noReason')}</p>
      <p className="text-row">
        <DiffCounts diff={row.summary} />
      </p>
      <Disclosure
        showLabel={t('policy.versions.history.showDiff', { version: row.version })}
        hideLabel={t('policy.versions.history.hideDiff', { version: row.version })}
      >
        {() => <VersionDiff version={row.version} />}
      </Disclosure>
    </li>
  )
}

function HistoryList({ fourEyes, canRestore }: { fourEyes: boolean; canRestore: boolean }) {
  const { t } = useTranslation()
  const versions = usePolicyVersions()
  const [restoring, setRestoring] = useState<number | null>(null)
  const rows = versions.data?.pages.flatMap((page) => page.rows) ?? []
  return (
    <PolicyCard title={t('policy.versions.history.title')} subtitle={t('policy.versions.history.subtitle')}>
      {versions.isError && rows.length === 0 ? (
        <ErrorState error={versions.error} onRetry={() => void versions.refetch()} />
      ) : versions.isPending ? (
        <ListSkeleton rows={4} />
      ) : rows.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('policy.versions.history.empty')}</p>
      ) : (
        <>
          <ul className="flex flex-col divide-y rounded-lg border">
            {rows.map((row) => (
              <VersionRow
                key={row.version}
                row={row}
                canRestore={canRestore}
                onRestore={() => setRestoring(row.version)}
              />
            ))}
          </ul>
          {versions.hasNextPage ? (
            <Button
              size="sm"
              variant="outline"
              className="self-start"
              disabled={versions.isFetchingNextPage}
              onClick={() => void versions.fetchNextPage()}
            >
              {versions.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('policy.versions.history.loadMore')}
            </Button>
          ) : null}
        </>
      )}
      {restoring !== null ? (
        <RollbackDialog version={restoring} fourEyes={fourEyes} onClose={() => setRestoring(null)} />
      ) : null}
    </PolicyCard>
  )
}

function StatusHeader({ state }: { state: PolicyState }) {
  const { t } = useTranslation()
  return (
    <section className="flex flex-col gap-2 rounded-lg border p-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex min-w-0 flex-col gap-0.5">
        <p className="text-panel font-semibold">
          {t('policy.versions.current', { version: state.current.version })}
        </p>
        <p className="text-xs text-muted-foreground">
          {t('policy.versions.currentMeta', {
            time: stamp(state.current.created_at),
            source: t(`policy.versions.history.sources.${state.current.source}`),
          })}
        </p>
      </div>
      <div className="flex flex-col items-start gap-1 sm:items-end">
        <ToneBadge tone={state.four_eyes ? 'ok' : 'warn'}>
          {state.four_eyes ? t('policy.versions.fourEyesOn') : t('policy.versions.fourEyesOff')}
        </ToneBadge>
        <p className="max-w-sm text-xs text-muted-foreground sm:text-right">
          {state.four_eyes ? t('policy.versions.fourEyesOnHint') : t('policy.versions.fourEyesOffHint')}
        </p>
      </div>
    </section>
  )
}

export function VersionsTab({ canEdit = true }: { canEdit?: boolean }) {
  const { t } = useTranslation()
  const state = usePolicyState()
  return (
    <div className="flex flex-col gap-6">
      <p className="max-w-3xl text-row text-muted-foreground">{t('policy.versions.subtitle')}</p>
      <QueryContent query={state}>
        {(data) => (
          <div className="flex flex-col gap-6">
            <StatusHeader state={data} />
            {canEdit ? <DraftCard key={data.draft?.id ?? 0} state={data} draft={data.draft} /> : null}
            <PendingList />
            <HistoryList fourEyes={data.four_eyes} canRestore={canEdit} />
            <DecidedList />
          </div>
        )}
      </QueryContent>
    </div>
  )
}
