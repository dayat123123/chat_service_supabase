import { useQueryClient } from '@tanstack/react-query'
import {
  CalendarClockIcon,
  FilePlus2Icon,
  FileTextIcon,
  LoaderCircleIcon,
  PlusIcon,
  ShieldCheckIcon,
  TriangleAlertIcon,
  XIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
  Switch,
} from '@/components/ui/controls'
import { Confirm } from '@/features/nasabah/components/confirm'
import { legalErrorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import { legalApi } from '../api'
import { legalKeys, useCancelScheduled, useLegalOverview, useSetRequired } from '../hooks'
import { draftFromDocument, sortDrafts, toggleRequired, wibStamp } from '../logic'
import type { LegalDocument, LegalDraft, LegalKindState, LegalOverview } from '../types'
import { DocumentSheet } from './document-sheet'
import { DraftSheet, type DraftTarget } from './draft-sheet'
import { AcceptanceMeter, DraftStatusBadge } from './legal-ui'

type Actions = {
  open: (documentId: string) => void
  draftFrom: (documentId: string) => void
  drafting: string | null
}

function RequiredSwitch({ state, overview }: { state: LegalKindState; overview: LegalOverview }) {
  const { t } = useTranslation()
  const setRequired = useSetRequired()
  const [asking, setAsking] = useState<boolean | null>(null)
  const kind = t(`legal.kinds.${state.kind}`)
  const id = `legal-required-${state.kind}`
  const pendingUsers = state.current ? Math.max(0, overview.active_users - state.current.accepted) : 0
  const body =
    asking === true
      ? state.current
        ? t('legal.confirm.requireOnBody', { kind, count: pendingUsers, users: formatNumber(pendingUsers) })
        : t('legal.confirm.requireOnEmpty', { kind })
      : t('legal.confirm.requireOffBody', { kind })
  return (
    <div className="flex items-center gap-2">
      <Switch
        id={id}
        checked={state.required}
        disabled={setRequired.isPending}
        onCheckedChange={(next) => setAsking(next)}
      />
      <label htmlFor={id} className="text-row">
        {t('legal.required')}
      </label>
      <Confirm
        open={asking !== null}
        title={
          asking ? t('legal.confirm.requireOnTitle', { kind }) : t('legal.confirm.requireOffTitle', { kind })
        }
        body={body}
        action={asking ? t('legal.confirm.requireOn') : t('legal.confirm.requireOff')}
        destructive={asking === true}
        pending={setRequired.isPending}
        onClose={() => setAsking(null)}
        onConfirm={() => {
          const next = asking === true
          void setRequired
            .mutateAsync(toggleRequired(overview.required_kinds, state.kind, next))
            .then(() =>
              toast.success(
                next ? t('legal.toast.requiredOn', { kind }) : t('legal.toast.requiredOff', { kind }),
              ),
            )
            .catch((error: unknown) => toast.error(legalErrorText(error)))
            .finally(() => setAsking(null))
        }}
      />
    </div>
  )
}

function ScheduledRow({ document }: { document: LegalDocument }) {
  const { t } = useTranslation()
  const cancel = useCancelScheduled()
  const [asking, setAsking] = useState(false)
  return (
    <div className="flex flex-col gap-2 rounded-md border border-dashed p-3">
      <p className="flex items-start gap-2 text-row">
        <CalendarClockIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
        <span className="min-w-0 break-words">
          {t('legal.scheduled', {
            version: document.version,
            title: document.title,
            time: wibStamp(document.effective_at),
          })}
        </span>
      </p>
      <Button size="xs" variant="outline" className="self-start" onClick={() => setAsking(true)}>
        <XIcon />
        {t('legal.actions.cancelSchedule')}
      </Button>
      <Confirm
        open={asking}
        title={t('legal.confirm.cancelTitle', { version: document.version })}
        body={t('legal.confirm.cancelBody')}
        action={t('legal.actions.cancelSchedule')}
        destructive
        pending={cancel.isPending}
        onClose={() => setAsking(false)}
        onConfirm={() =>
          void cancel
            .mutateAsync(document.id)
            .then(() => toast.success(t('legal.toast.cancelled')))
            .catch((error: unknown) => toast.error(legalErrorText(error)))
            .finally(() => setAsking(false))
        }
      />
    </div>
  )
}

function History({ state, actions }: { state: LegalKindState; actions: Actions }) {
  const { t } = useTranslation()
  if (state.history.length === 0) return null
  return (
    <Accordion type="single" collapsible>
      <AccordionItem value="history" className="border-b-0">
        <AccordionTrigger>{t('legal.history', { count: state.history.length })}</AccordionTrigger>
        <AccordionContent>
          <ul className="flex flex-col">
            {state.history.map((document) => (
              <li key={document.id} className="flex items-center gap-2 border-t py-1.5">
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-row">
                    {t('legal.versionShort', { version: document.version })} · {document.title}
                  </span>
                  <span className="block text-xs text-muted-foreground">
                    {document.in_effect
                      ? t('legal.historyMeta', {
                          time: stamp(document.effective_at),
                          accepted: formatNumber(document.accepted),
                        })
                      : t('legal.historyScheduled', { time: stamp(document.effective_at) })}
                  </span>
                </span>
                <Button
                  size="xs"
                  variant="ghost"
                  aria-label={t('legal.openVersion', { version: document.version })}
                  onClick={() => actions.open(document.id)}
                >
                  {t('legal.actions.open')}
                </Button>
              </li>
            ))}
          </ul>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  )
}

function KindCard({
  state,
  overview,
  actions,
}: {
  state: LegalKindState
  overview: LegalOverview
  actions: Actions
}) {
  const { t } = useTranslation()
  const current = state.current
  const titleId = `legal-kind-${state.kind}`
  return (
    <section aria-labelledby={titleId} className="flex min-w-0 flex-col gap-3 rounded-lg border p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <h2 id={titleId} className="text-panel font-semibold">
          {t(`legal.kinds.${state.kind}`)}
        </h2>
        <RequiredSwitch state={state} overview={overview} />
      </div>
      {current ? (
        <div className="flex flex-col gap-2">
          <div className="min-w-0">
            <p className="text-row font-medium break-words">{current.title}</p>
            <p className="text-xs text-muted-foreground">
              {t('legal.currentMeta', {
                version: current.version,
                time: wibStamp(current.effective_at),
              })}
            </p>
            <p className="text-xs text-muted-foreground">
              {t('legal.approvedBy', { name: current.approved_by ?? '–' })}
            </p>
          </div>
          <AcceptanceMeter accepted={current.accepted} activeUsers={overview.active_users} />
        </div>
      ) : (
        <p className="text-row text-muted-foreground">{t('legal.noCurrent')}</p>
      )}
      {state.scheduled ? <ScheduledRow document={state.scheduled} /> : null}
      {current ? (
        <div className="flex flex-wrap gap-2">
          <Button size="xs" variant="outline" onClick={() => actions.open(current.id)}>
            <FileTextIcon />
            {t('legal.actions.view')}
          </Button>
          <Button
            size="xs"
            variant="outline"
            disabled={actions.drafting !== null}
            onClick={() => actions.draftFrom(current.id)}
          >
            {actions.drafting === current.id ? (
              <LoaderCircleIcon className="animate-spin" />
            ) : (
              <FilePlus2Icon />
            )}
            {t('legal.actions.draftFromCurrent')}
          </Button>
        </div>
      ) : null}
      <History state={state} actions={actions} />
    </section>
  )
}

function DraftRow({ draft, onOpen }: { draft: LegalDraft; onOpen: () => void }) {
  const { t } = useTranslation()
  return (
    <li className="flex flex-col gap-2 border-b px-1 py-3 sm:flex-row sm:items-center">
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <DraftStatusBadge status={draft.status} />
          <span className="text-xs text-muted-foreground">{t(`legal.kinds.${draft.kind}`)}</span>
        </div>
        <p className="mt-1 text-row font-medium break-words">{draft.title}</p>
        <p className="text-xs text-muted-foreground">
          {draft.status === 'pending' && draft.submitted_at
            ? t('legal.submittedBy', { name: draft.submitted_by ?? '–', time: stamp(draft.submitted_at) })
            : t('legal.updatedBy', { name: draft.updated_by ?? '–', time: stamp(draft.updated_at) })}
          {draft.effective_at ? ` · ${t('legal.effectiveAt', { time: wibStamp(draft.effective_at) })}` : ''}
        </p>
        {draft.status === 'rejected' && draft.review_note ? (
          <p className="mt-1 text-xs break-words text-destructive">
            {t('legal.rejectedNote', { name: draft.reviewed_by ?? '–', note: draft.review_note })}
          </p>
        ) : null}
      </div>
      <Button
        size="sm"
        variant={draft.status === 'pending' ? 'default' : 'outline'}
        className="self-start sm:self-center"
        aria-label={t('legal.openDraft', { title: draft.title })}
        onClick={onOpen}
      >
        {draft.status === 'pending' ? t('legal.actions.review') : t('legal.actions.edit')}
      </Button>
    </li>
  )
}

function FourEyesNotice({ overview }: { overview: LegalOverview }) {
  const { t } = useTranslation()
  return overview.four_eyes ? (
    <p className="flex items-start gap-2 text-row text-muted-foreground">
      <ShieldCheckIcon className="mt-0.5 size-4 shrink-0 text-success" aria-hidden="true" />
      {t('legal.fourEyes.on', { count: overview.reviewers })}
    </p>
  ) : (
    <p role="note" className="flex items-start gap-2 text-row text-warning">
      <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
      {t('legal.fourEyes.off')}
    </p>
  )
}

function LegalContent({ overview }: { overview: LegalOverview }) {
  const { t } = useTranslation()
  const client = useQueryClient()
  const [documentId, setDocumentId] = useState<string | null>(null)
  const [target, setTarget] = useState<DraftTarget | null>(null)
  const [drafting, setDrafting] = useState<string | null>(null)
  const drafts = sortDrafts(overview.drafts)

  const startFrom = (document: LegalDocument) => {
    setDocumentId(null)
    setTarget({ id: null, seed: draftFromDocument(document) })
  }

  const actions: Actions = {
    open: setDocumentId,
    drafting,
    draftFrom: (id) => {
      setDrafting(id)
      void client
        .fetchQuery({
          queryKey: legalKeys.document(id),
          queryFn: () => legalApi.document(id),
          staleTime: 60_000,
        })
        .then(startFrom)
        .catch((error: unknown) => toast.error(legalErrorText(error)))
        .finally(() => setDrafting(null))
    },
  }

  return (
    <>
      <FourEyesNotice overview={overview} />
      <div className="grid gap-4 lg:grid-cols-3">
        {overview.kinds.map((state) => (
          <KindCard key={state.kind} state={state} overview={overview} actions={actions} />
        ))}
      </div>
      <section aria-labelledby="legal-drafts-title" className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 id="legal-drafts-title" className="text-panel font-semibold">
            {t('legal.draftsTitle', { count: drafts.length })}
          </h2>
          <Button
            size="sm"
            onClick={() =>
              setTarget({
                id: null,
                seed: { kind: 'terms', title: '', body: '', changeSummary: '', effectiveAt: null },
              })
            }
          >
            <PlusIcon />
            {t('legal.actions.newDraft')}
          </Button>
        </div>
        {drafts.length === 0 ? (
          <p className="border-y py-6 text-center text-row text-muted-foreground">{t('legal.noDrafts')}</p>
        ) : (
          <ul className="border-t">
            {drafts.map((draft) => (
              <DraftRow key={draft.id} draft={draft} onOpen={() => setTarget({ id: draft.id })} />
            ))}
          </ul>
        )}
      </section>
      <DocumentSheet documentId={documentId} onClose={() => setDocumentId(null)} onDraftFrom={startFrom} />
      <DraftSheet target={target} overview={overview} onTarget={setTarget} onClose={() => setTarget(null)} />
    </>
  )
}

export function LegalPage() {
  const { t } = useTranslation()
  const overview = useLegalOverview()
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1200px] flex-col gap-5 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('legal.title')}</h1>
          <p className="max-w-3xl text-row text-muted-foreground">{t('legal.subtitle')}</p>
        </header>
        {overview.data ? (
          <LegalContent overview={overview.data} />
        ) : overview.isError ? (
          <ErrorState error={overview.error} onRetry={() => void overview.refetch()} />
        ) : (
          <ListSkeleton rows={4} />
        )}
      </div>
    </div>
  )
}
