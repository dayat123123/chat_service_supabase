import { CalendarPlusIcon, DownloadIcon, FingerprintIcon, LoaderCircleIcon } from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { PriorityText, TicketStatusText } from '@/components/badges'
import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { RadioGroup, RadioGroupItem } from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { MessageBubble, NoteMessage, SystemMessage } from '@/features/conversation/components/message-bubble'
import { buildRows } from '@/features/conversation/rows'
import { isStaffMessage, type ChatMessage } from '@/features/conversation/types'
import { customerName } from '@/features/tickets/types'
import { downloadText } from '@/lib/download'
import { errorText } from '@/lib/error-text'
import { format, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { complianceApi } from '../api'
import { useCaseDetail, useCaseMessages, useExtendDeadline, useReviewCase } from '../hooks'
import {
  detailsText,
  finishedAt,
  isKnownEvent,
  sha256Hex,
  transcriptFileName,
  transcriptText,
} from '../logic'
import { verdicts, type CaseDetail, type Verdict } from '../types'
import { useCaseKindLabel } from '../labels'
import { CaseKindText, DeadlineText, VerdictText } from './case-badges'

const tabs = ['transcript', 'timeline', 'review'] as const
type Tab = (typeof tabs)[number]

const fullStamp = (value: string | null | undefined) =>
  value ? `${format(value, 'd MMM yyyy, HH.mm')} WIB` : null

const noTrustedHost = () => false

const actorTypes = ['customer', 'agent', 'service', 'system']

const systemOutcomes = ['customer_ended', 'superseded', 'reopen_window_passed']

function useOutcomeLabel() {
  const { t, i18n } = useTranslation()
  const agent = useAgent()
  const language = i18n.language === 'en' ? 'en' : 'id'
  return (outcome: string | null) => {
    if (!outcome) return null
    const configured = agent.settings.outcomes[outcome]?.[language]
    if (configured) return configured
    return systemOutcomes.includes(outcome) ? t(`compliance.outcomes.${outcome as 'superseded'}`) : outcome
  }
}

function Fact({ label, children, wide }: { label: string; children: ReactNode; wide?: boolean }) {
  return (
    <div className={cn('flex min-w-0 flex-col gap-0.5', wide && 'sm:col-span-2')}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row break-words">{children ?? '–'}</dd>
    </div>
  )
}

function CaseFacts({ detail }: { detail: CaseDetail }) {
  const { t } = useTranslation()
  const outcome = useOutcomeLabel()
  return (
    <dl className="grid gap-x-6 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
      <Fact label={t('compliance.case.agent')}>
        {detail.agent
          ? `${detail.agent.display_name}${detail.agent.agent_code ? ` (${detail.agent.agent_code})` : ''}`
          : null}
      </Fact>
      <Fact label={t('compliance.case.topic')}>{detail.topic_name ?? detail.topic}</Fact>
      <Fact label={t('compliance.case.created')}>{fullStamp(detail.created_at)}</Fact>
      <Fact label={t('compliance.case.received')}>{fullStamp(detail.complaint_received_at)}</Fact>
      <Fact label={t('compliance.case.due')}>
        {detail.complaint_due_at ? (
          <span className="flex flex-col gap-0.5">
            {fullStamp(detail.complaint_due_at)}
            <DeadlineText deadline={detail.deadline} />
          </span>
        ) : null}
      </Fact>
      <Fact label={t('compliance.case.finished')}>{fullStamp(finishedAt(detail))}</Fact>
      <Fact label={t('compliance.case.outcome')}>{outcome(detail.outcome)}</Fact>
      <Fact label={t('compliance.case.rating')}>
        {detail.rating === null ? null : (
          <>
            {t('compliance.case.ratingValue', { rating: detail.rating })}
            {detail.rating_comment ? (
              <span className="text-muted-foreground"> · {detail.rating_comment}</span>
            ) : null}
          </>
        )}
      </Fact>
      {detail.resolution_summary ? (
        <Fact label={t('compliance.case.summary')} wide>
          <span className="whitespace-pre-wrap">{detail.resolution_summary}</span>
        </Fact>
      ) : null}
      {detail.complaint_extended_at ? (
        <p className="text-xs text-info sm:col-span-2">
          {t('compliance.case.extendedNote', {
            time: fullStamp(detail.complaint_extended_at),
            reason: detail.complaint_extension_reason ?? '–',
          })}
        </p>
      ) : null}
    </dl>
  )
}

function TranscriptButton({ detail, messages }: { detail: CaseDetail; messages: ChatMessage[] | undefined }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const kindLabel = useCaseKindLabel()
  const outcome = useOutcomeLabel()
  const [busy, setBusy] = useState(false)
  const [hash, setHash] = useState<string | null>(null)

  const download = async () => {
    if (!messages) return
    setBusy(true)
    try {
      const text = transcriptText(detail, messages, {
        title: t('compliance.transcript.title', { number: detail.ticket_number }),
        fields: [
          {
            label: t('compliance.case.customer'),
            value: `${customerName(detail)}${detail.customer?.username ? ` (@${detail.customer.username})` : ''}`,
          },
          { label: t('compliance.transcript.kind'), value: kindLabel(detail) },
          { label: t('compliance.case.topic'), value: detail.topic_name ?? detail.topic },
          { label: t('compliance.case.status'), value: t(`tickets.status.${detail.status}`) },
          { label: t('compliance.case.agent'), value: detail.agent?.display_name },
          { label: t('compliance.case.created'), value: fullStamp(detail.created_at) },
          { label: t('compliance.case.received'), value: fullStamp(detail.complaint_received_at) },
          { label: t('compliance.case.due'), value: fullStamp(detail.complaint_due_at) },
          { label: t('compliance.case.finished'), value: fullStamp(finishedAt(detail)) },
          { label: t('compliance.case.outcome'), value: outcome(detail.outcome) },
          { label: t('compliance.transcript.exported'), value: fullStamp(new Date().toISOString()) },
          {
            label: t('compliance.transcript.exportedBy'),
            value: `${agent.display_name} (${agent.agent_code})`,
          },
        ],
        customer: t('compliance.transcript.customer'),
        agent: t('compliance.transcript.agent'),
        system: t('compliance.transcript.system'),
        note: t('compliance.transcript.note'),
        attachment: t('compliance.transcript.attachment'),
        deleted: t('compliance.transcript.deleted'),
      })
      const sha256 = await sha256Hex(text)
      await complianceApi.transcriptExported(detail.id, sha256, messages.length)
      downloadText(transcriptFileName(detail.ticket_number, sha256), text, 'text/plain;charset=utf-8')
      setHash(sha256)
      toast.success(t('compliance.case.downloaded'))
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <Button variant="outline" size="sm" disabled={busy || !messages} onClick={() => void download()}>
        {busy ? <LoaderCircleIcon className="animate-spin" /> : <DownloadIcon />}
        {busy ? t('compliance.case.downloading') : t('compliance.case.download')}
      </Button>
      {hash ? (
        <p className="flex w-full min-w-0 items-center gap-1.5 text-xs text-muted-foreground" title={hash}>
          <FingerprintIcon className="size-3.5 shrink-0" aria-hidden="true" />
          <span className="shrink-0">{t('compliance.case.lastHash')}:</span>
          <span className="truncate font-mono">{hash}</span>
        </p>
      ) : null}
    </>
  )
}

function ExtendDialog({ detail }: { detail: CaseDetail }) {
  const { t } = useTranslation()
  const extend = useExtendDeadline(detail.id)
  const [open, setOpen] = useState(false)
  const [reason, setReason] = useState('')
  const trimmed = reason.trim()
  const valid = trimmed.length >= 10 && trimmed.length <= 500
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (next) setReason('')
      }}
    >
      <Button variant="outline" size="sm" onClick={() => setOpen(true)}>
        <CalendarPlusIcon />
        {t('compliance.case.extend')}
      </Button>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('compliance.case.extendTitle')}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          onSubmit={(event) => {
            event.preventDefault()
            if (!valid) return
            extend.mutate(
              { reason: trimmed, version: detail.version },
              {
                onSuccess: () => {
                  toast.success(t('compliance.case.extendDone'))
                  setOpen(false)
                },
                onError: (error) => toast.error(errorText(error)),
              },
            )
          }}
        >
          <DialogDescription>
            {t('compliance.case.extendBody', {
              due: fullStamp(detail.complaint_due_at) ?? '–',
              days: detail.extension_days,
            })}
          </DialogDescription>
          <div className="flex flex-col gap-2">
            <Label htmlFor="extend-reason">{t('compliance.case.extendReason')}</Label>
            <Textarea
              id="extend-reason"
              autoFocus
              maxLength={500}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
            />
            <p className="text-xs text-muted-foreground">{t('compliance.case.extendReasonHint')}</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={!valid || extend.isPending}>
              {extend.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('compliance.case.extendSubmit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function Transcript({
  detail,
  messages,
}: {
  detail: CaseDetail
  messages: ReturnType<typeof useCaseMessages>
}) {
  const { t } = useTranslation()
  const rows = useMemo(
    () => buildRows(messages.data ?? [], [], { notes: detail.notes }),
    [messages.data, detail.notes],
  )
  if (messages.isError) return <ErrorState error={messages.error} onRetry={() => void messages.refetch()} />
  if (!messages.data) return <ListSkeleton rows={4} />
  if (rows.length === 0) return <EmptyState title={t('compliance.case.transcriptEmpty')} />
  return (
    <div role="log" aria-label={t('compliance.case.tabs.transcript')} className="flex flex-col py-2">
      {rows.map((row) => {
        if (row.kind === 'day') {
          return (
            <div key={row.key} className="flex items-center gap-3 px-(--pane-px) pt-4 pb-1">
              <span className="h-px flex-1 bg-border" />
              <span className="text-xs text-muted-foreground">{row.label}</span>
              <span className="h-px flex-1 bg-border" />
            </div>
          )
        }
        if (row.kind === 'note') return <NoteMessage key={row.key} note={row.note} />
        if (row.kind === 'pending') return null
        const message = row.message
        if (message.kind === 'system' || message.kind === 'csat')
          return <SystemMessage key={row.key} message={message} />
        return (
          <MessageBubble
            key={row.key}
            message={message}
            staff={isStaffMessage(message)}
            first={row.first}
            last={row.last}
            read={false}
            trustedHost={noTrustedHost}
          />
        )
      })}
    </div>
  )
}

function Timeline({ detail }: { detail: CaseDetail }) {
  const { t } = useTranslation()
  if (detail.events.length === 0) return <EmptyState title={t('compliance.case.timelineEmpty')} />
  return (
    <ol className="flex flex-col px-5 py-2">
      {detail.events.map((event, index) => {
        const actor =
          event.actor_name ??
          (event.actor_type && actorTypes.includes(event.actor_type)
            ? t(`compliance.actorTypes.${event.actor_type as 'system'}`)
            : event.actor_type)
        const details = detailsText(event.data, (value) => fullStamp(value) ?? value)
        return (
          <li key={`${event.created_at}-${index}`} className="flex gap-3 border-b py-2.5 last:border-b-0">
            <span className="tabular w-28 shrink-0 text-xs text-muted-foreground">
              {format(event.created_at, 'd MMM, HH.mm.ss')}
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-row font-medium">
                {isKnownEvent(event.type) ? t(`compliance.events.${event.type}`) : event.type}
              </p>
              {actor || details ? (
                <p className="text-xs break-words text-muted-foreground">
                  {[actor, details].filter(Boolean).join(' · ')}
                </p>
              ) : null}
            </div>
          </li>
        )
      })}
    </ol>
  )
}

function ReviewSection({ detail }: { detail: CaseDetail }) {
  const { t } = useTranslation()
  const review = useReviewCase(detail.id)
  const [verdict, setVerdict] = useState<Verdict | ''>('')
  const [note, setNote] = useState('')
  const trimmed = note.trim()
  const valid = verdict !== '' && trimmed.length >= 5 && trimmed.length <= 1000
  const now = new Date()
  return (
    <div className="flex flex-col gap-5 px-5 py-4">
      <form
        className="flex flex-col gap-4"
        aria-labelledby="review-title"
        onSubmit={(event) => {
          event.preventDefault()
          if (!valid) return
          review.mutate(
            { verdict, note: trimmed },
            {
              onSuccess: () => {
                toast.success(t('compliance.case.reviewSaved'))
                setVerdict('')
                setNote('')
              },
              onError: (error) => toast.error(errorText(error)),
            },
          )
        }}
      >
        <h3 id="review-title" className="text-row font-semibold">
          {t('compliance.case.reviewTitle')}
        </h3>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-2 text-xs text-muted-foreground">{t('compliance.case.reviewVerdict')}</legend>
          <RadioGroup
            value={verdict}
            onValueChange={(value) => setVerdict(value as Verdict)}
            className="gap-2"
          >
            {verdicts.map((item) => (
              <label key={item} className="flex cursor-pointer items-start gap-2.5">
                <RadioGroupItem value={item} className="mt-0.5" />
                <span className="flex flex-col">
                  <VerdictText verdict={item} className="text-row" />
                  <span className="text-xs text-muted-foreground">{t(`compliance.verdictHint.${item}`)}</span>
                </span>
              </label>
            ))}
          </RadioGroup>
        </fieldset>
        <div className="flex flex-col gap-2">
          <Label htmlFor="review-note">{t('compliance.case.reviewNote')}</Label>
          <Textarea
            id="review-note"
            maxLength={1000}
            value={note}
            onChange={(event) => setNote(event.target.value)}
          />
          <p className="text-xs text-muted-foreground">{t('compliance.case.reviewNoteHint')}</p>
        </div>
        <Button type="submit" size="sm" className="self-start" disabled={!valid || review.isPending}>
          {review.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('compliance.case.reviewSubmit')}
        </Button>
      </form>
      <section className="flex flex-col gap-2" aria-labelledby="reviews-title">
        <h3 id="reviews-title" className="text-row font-semibold">
          {t('compliance.case.reviewsTitle')}
        </h3>
        <p className="text-xs text-muted-foreground">{t('compliance.case.appendOnly')}</p>
        {detail.reviews.length === 0 ? (
          <p className="text-row text-muted-foreground">{t('compliance.case.reviewsEmpty')}</p>
        ) : (
          <ul className="flex flex-col border-y">
            {detail.reviews.map((item, index) => (
              <li key={item.id} className="flex flex-col gap-1 border-b py-2.5 last:border-b-0">
                <p className="flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
                  <VerdictText verdict={item.verdict} />
                  {index === 0 ? (
                    <span className="font-medium text-foreground">· {t('compliance.case.latest')}</span>
                  ) : null}
                  <span>
                    · {item.reviewer ?? '–'} · <span className="tabular">{stamp(item.created_at, now)}</span>
                  </span>
                </p>
                <p className="text-row break-words whitespace-pre-wrap">{item.note}</p>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}

function CaseBody({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const detail = useCaseDetail(ticketId)
  const messages = useCaseMessages(ticketId)
  const [tab, setTab] = useState<Tab>('transcript')
  if (detail.isError) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 p-6">
        <p className="text-row font-medium">{t('compliance.case.loadFailed')}</p>
        <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
      </div>
    )
  }
  if (!detail.data) return <ListSkeleton rows={8} className="pt-10" />
  const data = detail.data
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
          <h2 className="font-mono text-panel font-semibold">{data.ticket_number}</h2>
          <PriorityText priority={data.priority} className="text-xs" />
          <TicketStatusText status={data.status} />
        </div>
        <p className="text-row">
          {customerName(data)}
          {data.customer?.username ? (
            <span className="text-muted-foreground"> @{data.customer.username}</span>
          ) : null}
        </p>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <CaseKindText row={data} />
          {data.deadline ? <DeadlineText deadline={data.deadline} /> : null}
          <VerdictText verdict={data.review?.verdict} />
        </div>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <CaseFacts detail={data} />
        <div className="flex flex-wrap items-center gap-2 border-b px-5 py-3">
          <TranscriptButton detail={data} messages={messages.data} />
          {data.can_extend ? <ExtendDialog detail={data} /> : null}
          <p className="w-full text-xs text-muted-foreground">{t('compliance.case.accessLogged')}</p>
        </div>
        <div
          role="tablist"
          aria-label={t('compliance.case.tabsLabel')}
          className="sticky top-0 z-10 flex gap-4 border-b bg-background px-5"
        >
          {tabs.map((item) => (
            <button
              key={item}
              id={`case-tab-${item}`}
              type="button"
              role="tab"
              aria-selected={tab === item}
              aria-controls={`case-panel-${item}`}
              onClick={() => setTab(item)}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center gap-1.5 text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                tab === item
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(`compliance.case.tabs.${item}`)}
              {item === 'review' && data.reviews.length > 0 ? (
                <span className="tabular font-normal text-muted-foreground">{data.reviews.length}</span>
              ) : null}
            </button>
          ))}
        </div>
        <div role="tabpanel" id={`case-panel-${tab}`} aria-labelledby={`case-tab-${tab}`}>
          {tab === 'transcript' ? <Transcript detail={data} messages={messages} /> : null}
          {tab === 'timeline' ? <Timeline detail={data} /> : null}
          {tab === 'review' ? <ReviewSection detail={data} /> : null}
        </div>
      </div>
    </div>
  )
}

export function CasePanel({ ticketId, onClose }: { ticketId: string | undefined; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Sheet open={Boolean(ticketId)} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('compliance.cases.title')}
        closeLabel={t('app.close')}
        className="w-[min(760px,100vw)] bg-background"
      >
        {ticketId ? <CaseBody key={ticketId} ticketId={ticketId} /> : null}
      </SheetContent>
    </Sheet>
  )
}
