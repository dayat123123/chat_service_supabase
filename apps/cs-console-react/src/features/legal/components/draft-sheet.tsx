import {
  CircleAlertIcon,
  EyeIcon,
  LoaderCircleIcon,
  PencilIcon,
  SendIcon,
  ShieldCheckIcon,
  Trash2Icon,
  TriangleAlertIcon,
  Undo2Icon,
} from 'lucide-react'
import { useEffect, useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { ReasonDialog } from '@/features/community/components/shared'
import { Confirm } from '@/features/nasabah/components/confirm'
import { legalErrorText } from '@/lib/error-text'
import { formatNumber } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useDraftAction, useLegalDraft, useRejectDraft, useSaveDraft } from '../hooks'
import { draftActions, draftProblems, isoToWibInput, wibInputToIso, wibStamp } from '../logic'
import {
  LEGAL_BODY_MAX,
  LEGAL_BODY_MIN,
  LEGAL_SUMMARY_MAX,
  LEGAL_TITLE_MAX,
  legalKinds,
  type DraftInput,
  type LegalDraft,
  type LegalKind,
  type LegalOverview,
} from '../types'
import { DraftStatusBadge, Fact, LegalPreview } from './legal-ui'

export type DraftTarget = { id: null; seed: Omit<DraftInput, 'id'> } | { id: string }

type Form = {
  kind: LegalKind
  title: string
  body: string
  changeSummary: string
  effectiveInput: string
}

const sameForm = (a: Form, b: Form) =>
  a.kind === b.kind &&
  a.title === b.title &&
  a.body === b.body &&
  a.changeSummary === b.changeSummary &&
  a.effectiveInput === b.effectiveInput

function formOf(source: Omit<DraftInput, 'id'> | LegalDraft): Form {
  const effective = 'effectiveAt' in source ? source.effectiveAt : (source.effective_at ?? null)
  return {
    kind: source.kind,
    title: source.title,
    body: source.body ?? '',
    changeSummary: 'changeSummary' in source ? source.changeSummary : (source.change_summary ?? ''),
    effectiveInput: effective ? isoToWibInput(effective) : '',
  }
}

function FieldHint({ id, error, children }: { id: string; error?: string; children?: React.ReactNode }) {
  return (
    <p id={id} className={cn('text-xs', error ? 'text-destructive' : 'text-muted-foreground')}>
      {error ?? children}
    </p>
  )
}

function DraftEditor({
  draft,
  seed,
  overview,
  onSaved,
  onDirty,
  onClose,
  onDone,
}: {
  draft: LegalDraft | null
  seed: Omit<DraftInput, 'id'> | null
  overview: LegalOverview
  onSaved: (id: string) => void
  onDirty: (dirty: boolean) => void
  onClose: () => void
  onDone: () => void
}) {
  const { t } = useTranslation()
  const ids = useId()
  const save = useSaveDraft()
  const action = useDraftAction()
  const [baseline, setBaseline] = useState<Form>(() =>
    draft ? formOf(draft) : formOf(seed ?? { kind: 'terms', title: '', body: '', changeSummary: '', effectiveAt: null }),
  )
  const [form, setForm] = useState<Form>(baseline)
  const [mode, setMode] = useState<'write' | 'preview'>('write')
  const [checked, setChecked] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const problems = draftProblems(form)
  const shown = checked ? problems : {}
  const valid = Object.keys(problems).length === 0
  const dirty = !sameForm(form, baseline)
  const busy = save.isPending || action.isPending
  const bodyLength = form.body.trim().length
  const update = (patch: Partial<Form>) => setForm((current) => ({ ...current, ...patch }))

  useEffect(() => {
    onDirty(dirty)
    return () => onDirty(false)
  }, [dirty, onDirty])

  const persist = async () => {
    const effectiveAt = form.effectiveInput.trim() ? wibInputToIso(form.effectiveInput) : null
    const saved = await save.mutateAsync({
      id: draft?.id ?? null,
      kind: form.kind,
      title: form.title,
      body: form.body,
      changeSummary: form.changeSummary,
      effectiveAt,
    })
    setBaseline(form)
    return saved
  }

  const run = async (submit: boolean) => {
    setChecked(true)
    if (!valid) {
      setMode('write')
      return
    }
    try {
      const saved = dirty || !draft ? await persist() : draft
      if (submit) {
        await action.mutateAsync({ id: saved.id, action: 'submit' })
        toast.success(t('legal.toast.submitted'))
      } else {
        toast.success(t('legal.toast.saved'))
      }
      if (!draft) onSaved(saved.id)
    } catch (error) {
      toast.error(legalErrorText(error))
    }
  }

  const problemText = (field: 'title' | 'body' | 'changeSummary' | 'effectiveAt') => {
    const problem = shown[field]
    return problem ? t(`legal.editor.problems.${field}.${problem}` as 'legal.editor.problems.title.length') : undefined
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-2 border-b px-5 pt-4 pr-12 pb-3">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-panel font-semibold">{draft ? t('legal.editor.editTitle') : t('legal.editor.newTitle')}</h2>
          {draft ? <DraftStatusBadge status={draft.status} /> : null}
          {dirty ? <span className="text-xs text-muted-foreground">{t('legal.editor.unsaved')}</span> : null}
        </div>
        <ToggleGroup
          type="single"
          value={mode}
          onValueChange={(value) => value && setMode(value as 'write' | 'preview')}
          aria-label={t('legal.editor.modeLabel')}
        >
          <ToggleGroupItem value="write">
            <PencilIcon className="size-4" aria-hidden="true" />
            {t('legal.editor.write')}
          </ToggleGroupItem>
          <ToggleGroupItem value="preview">
            <EyeIcon className="size-4" aria-hidden="true" />
            {t('legal.editor.preview')}
          </ToggleGroupItem>
        </ToggleGroup>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">
        {draft?.status === 'rejected' && draft.review_note ? (
          <p role="note" className="mb-4 flex items-start gap-2 rounded-md border border-destructive/40 p-3 text-row">
            <CircleAlertIcon className="mt-0.5 size-4 shrink-0 text-destructive" aria-hidden="true" />
            <span className="min-w-0 break-words">
              <span className="font-medium">
                {t('legal.rejectedBy', {
                  name: draft.reviewed_by ?? '–',
                  time: draft.reviewed_at ? wibStamp(draft.reviewed_at) : '–',
                })}
              </span>{' '}
              {draft.review_note}
            </span>
          </p>
        ) : null}
        {mode === 'preview' ? (
          <LegalPreview title={form.title} body={form.body} />
        ) : (
          <form
            id={`${ids}-form`}
            className="flex flex-col gap-4"
            noValidate
            onSubmit={(event) => {
              event.preventDefault()
              void run(false)
            }}
          >
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor={`${ids}-kind`}>{t('legal.editor.kind')}</Label>
                <Select value={form.kind} onValueChange={(value) => update({ kind: value as LegalKind })}>
                  <SelectTrigger id={`${ids}-kind`}>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {legalKinds.map((kind) => (
                      <SelectItem key={kind} value={kind}>
                        {t(`legal.kinds.${kind}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor={`${ids}-effective`}>{t('legal.editor.effective')}</Label>
                <Input
                  id={`${ids}-effective`}
                  type="datetime-local"
                  value={form.effectiveInput}
                  min={isoToWibInput(new Date().toISOString())}
                  aria-invalid={shown.effectiveAt ? true : undefined}
                  aria-describedby={`${ids}-effective-hint`}
                  onChange={(event) => update({ effectiveInput: event.target.value })}
                />
                <FieldHint id={`${ids}-effective-hint`} error={problemText('effectiveAt')}>
                  {t('legal.editor.effectiveHint')}
                </FieldHint>
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${ids}-title`}>{t('legal.editor.title')}</Label>
              <Input
                id={`${ids}-title`}
                value={form.title}
                maxLength={LEGAL_TITLE_MAX}
                aria-invalid={shown.title ? true : undefined}
                aria-describedby={`${ids}-title-hint`}
                onChange={(event) => update({ title: event.target.value })}
              />
              <FieldHint id={`${ids}-title-hint`} error={problemText('title')} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${ids}-body`}>{t('legal.editor.body')}</Label>
              <Textarea
                id={`${ids}-body`}
                value={form.body}
                rows={18}
                maxLength={LEGAL_BODY_MAX}
                spellCheck
                className="min-h-80 font-mono text-row leading-relaxed"
                aria-invalid={shown.body ? true : undefined}
                aria-describedby={`${ids}-body-hint`}
                onChange={(event) => update({ body: event.target.value })}
              />
              <p
                id={`${ids}-body-hint`}
                className={cn('flex flex-wrap justify-between gap-2 text-xs', shown.body ? 'text-destructive' : 'text-muted-foreground')}
              >
                <span>{problemText('body') ?? t('legal.editor.bodyHint')}</span>
                <span className="tabular" aria-live="polite">
                  {t('legal.editor.count', {
                    count: bodyLength,
                    value: formatNumber(bodyLength),
                    min: formatNumber(LEGAL_BODY_MIN),
                    max: formatNumber(LEGAL_BODY_MAX),
                  })}
                </span>
              </p>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${ids}-summary`}>{t('legal.editor.summary')}</Label>
              <Textarea
                id={`${ids}-summary`}
                value={form.changeSummary}
                rows={4}
                maxLength={LEGAL_SUMMARY_MAX}
                aria-invalid={shown.changeSummary ? true : undefined}
                aria-describedby={`${ids}-summary-hint`}
                onChange={(event) => update({ changeSummary: event.target.value })}
              />
              <FieldHint id={`${ids}-summary-hint`} error={problemText('changeSummary')}>
                {t('legal.editor.summaryHint', { max: formatNumber(LEGAL_SUMMARY_MAX) })}
              </FieldHint>
            </div>
          </form>
        )}
      </div>
      <footer className="flex flex-col gap-2 border-t px-5 py-3">
        {overview.required_kinds.includes(form.kind) ? (
          <p className="text-xs text-muted-foreground">{t('legal.editor.requiredNote')}</p>
        ) : null}
        <div className="flex flex-wrap items-center gap-2">
          <Button size="sm" disabled={busy} onClick={() => void run(true)}>
            {action.isPending ? <LoaderCircleIcon className="animate-spin" /> : <SendIcon />}
            {dirty || !draft ? t('legal.actions.saveSubmit') : t('legal.actions.submit')}
          </Button>
          <Button size="sm" variant="outline" disabled={busy || (!dirty && draft !== null)} onClick={() => void run(false)}>
            {save.isPending && !action.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('legal.actions.save')}
          </Button>
          {draft ? (
            <Button
              size="sm"
              variant="ghost"
              className="text-destructive"
              disabled={busy}
              onClick={() => setDeleting(true)}
            >
              <Trash2Icon />
              {t('legal.actions.delete')}
            </Button>
          ) : null}
          <Button size="sm" variant="ghost" className="ml-auto" disabled={busy} onClick={onClose}>
            {t('app.close')}
          </Button>
        </div>
      </footer>
      <Confirm
        open={deleting}
        title={t('legal.confirm.deleteTitle')}
        body={t('legal.confirm.deleteBody')}
        action={t('legal.actions.delete')}
        destructive
        pending={action.isPending}
        onClose={() => setDeleting(false)}
        onConfirm={() =>
          void action
            .mutateAsync({ id: draft?.id ?? '', action: 'remove' })
            .then(() => {
              setDeleting(false)
              toast.success(t('legal.toast.deleted'))
              onDone()
            })
            .catch((error: unknown) => {
              setDeleting(false)
              toast.error(legalErrorText(error))
            })
        }
      />
    </div>
  )
}

function ApproveDialog({
  open,
  draft,
  self,
  required,
  pending,
  onConfirm,
  onClose,
}: {
  open: boolean
  draft: LegalDraft
  self: boolean
  required: boolean
  pending: boolean
  onConfirm: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const later = draft.effective_at && Date.parse(draft.effective_at) > Date.now()
  return (
    <AlertDialog open={open} onOpenChange={(next) => !next && !pending && onClose()}>
      <AlertDialogContent>
        <AlertDialogTitle>{t('legal.confirm.approveTitle', { kind: t(`legal.kinds.${draft.kind}`) })}</AlertDialogTitle>
        <AlertDialogDescription>
          {later
            ? t('legal.confirm.approveLater', { time: wibStamp(draft.effective_at ?? '') })
            : t('legal.confirm.approveNow')}
        </AlertDialogDescription>
        {required ? <p className="text-sm text-muted-foreground">{t('legal.confirm.approveRequired')}</p> : null}
        {self ? (
          <p role="alert" className="flex items-start gap-2 text-sm text-warning">
            <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
            {t('legal.fourEyes.selfWarning')}
          </p>
        ) : null}
        <div className="flex justify-end gap-2">
          <AlertDialogCancel disabled={pending}>{t('app.cancel')}</AlertDialogCancel>
          <Button disabled={pending} onClick={onConfirm}>
            {pending ? <LoaderCircleIcon className="animate-spin" /> : <ShieldCheckIcon />}
            {later ? t('legal.actions.approveSchedule') : t('legal.actions.approve')}
          </Button>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}

function DraftReview({
  draft,
  overview,
  onClose,
  onDone,
}: {
  draft: LegalDraft
  overview: LegalOverview
  onClose: () => void
  onDone: () => void
}) {
  const { t } = useTranslation()
  const ids = useId()
  const agent = useAgent()
  const action = useDraftAction()
  const reject = useRejectDraft()
  const [approving, setApproving] = useState(false)
  const [rejecting, setRejecting] = useState(false)
  const allowed = draftActions(draft, agent.id, overview.four_eyes)
  const busy = action.isPending || reject.isPending
  const later = draft.effective_at && Date.parse(draft.effective_at) > Date.now()

  const approve = () =>
    void action
      .mutateAsync({ id: draft.id, action: 'approve' })
      .then(() => {
        setApproving(false)
        toast.success(later ? t('legal.toast.scheduled') : t('legal.toast.published'))
        onDone()
      })
      .catch((error: unknown) => {
        setApproving(false)
        toast.error(legalErrorText(error))
      })

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs text-muted-foreground">{t(`legal.kinds.${draft.kind}`)}</span>
          <DraftStatusBadge status={draft.status} />
        </div>
        <h2 className="text-panel font-semibold break-words">{draft.title}</h2>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid grid-cols-1 gap-x-4 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
          <Fact label={t('legal.author')}>
            {t('legal.byAt', { name: draft.created_by ?? '–', time: wibStamp(draft.created_at) })}
          </Fact>
          <Fact label={t('legal.submitted')}>
            {draft.submitted_at
              ? t('legal.byAt', { name: draft.submitted_by ?? '–', time: wibStamp(draft.submitted_at) })
              : '–'}
          </Fact>
          <Fact label={t('legal.effectiveFrom')}>
            {later ? wibStamp(draft.effective_at ?? '') : t('legal.effectiveOnApproval')}
          </Fact>
          <Fact label={t('legal.bodyLength')}>{t('legal.characters', { value: formatNumber(draft.body_length) })}</Fact>
          <Fact label={t('legal.changes')} className="sm:col-span-2">
            <span className="whitespace-pre-wrap">{draft.change_summary ?? t('legal.noChanges')}</span>
          </Fact>
        </dl>
        <div className="px-5 py-4">
          <LegalPreview title={draft.title} body={draft.body ?? ''} />
        </div>
      </div>
      <footer className="flex flex-col gap-2 border-t px-5 py-3">
        {allowed.approve === 'blocked' ? (
          <p id={`${ids}-four-eyes`} className="flex items-start gap-2 text-xs text-muted-foreground">
            <ShieldCheckIcon className="mt-px size-3.5 shrink-0" aria-hidden="true" />
            {t('legal.fourEyes.blocked')}
          </p>
        ) : null}
        {allowed.approve === 'self' ? (
          <p className="flex items-start gap-2 text-xs text-warning">
            <TriangleAlertIcon className="mt-px size-3.5 shrink-0" aria-hidden="true" />
            {t('legal.fourEyes.selfHint')}
          </p>
        ) : null}
        <div className="flex flex-wrap items-center gap-2">
          {allowed.approve !== 'hidden' ? (
            <Button
              size="sm"
              disabled={busy || allowed.approve === 'blocked'}
              aria-describedby={allowed.approve === 'blocked' ? `${ids}-four-eyes` : undefined}
              onClick={() => setApproving(true)}
            >
              <ShieldCheckIcon />
              {later ? t('legal.actions.approveSchedule') : t('legal.actions.approve')}
            </Button>
          ) : null}
          {allowed.reject ? (
            <Button size="sm" variant="outline" disabled={busy} onClick={() => setRejecting(true)}>
              {t('legal.actions.reject')}
            </Button>
          ) : null}
          {allowed.withdraw ? (
            <Button
              size="sm"
              variant="ghost"
              disabled={busy}
              onClick={() =>
                void action
                  .mutateAsync({ id: draft.id, action: 'withdraw' })
                  .then(() => toast.success(t('legal.toast.withdrawn')))
                  .catch((error: unknown) => toast.error(legalErrorText(error)))
              }
            >
              <Undo2Icon />
              {t('legal.actions.withdraw')}
            </Button>
          ) : null}
          <Button size="sm" variant="ghost" className="ml-auto" onClick={onClose}>
            {t('app.close')}
          </Button>
        </div>
      </footer>
      <ApproveDialog
        open={approving}
        draft={draft}
        self={allowed.approve === 'self'}
        required={overview.required_kinds.includes(draft.kind)}
        pending={action.isPending}
        onConfirm={approve}
        onClose={() => setApproving(false)}
      />
      <ReasonDialog
        open={rejecting}
        title={t('legal.confirm.rejectTitle')}
        description={t('legal.confirm.rejectBody')}
        label={t('legal.confirm.rejectNote')}
        action={t('legal.actions.reject')}
        destructive
        pending={reject.isPending}
        onClose={() => setRejecting(false)}
        onSubmit={(note) =>
          void reject
            .mutateAsync({ id: draft.id, note })
            .then(() => {
              setRejecting(false)
              toast.success(t('legal.toast.rejected'))
            })
            .catch((error: unknown) => toast.error(legalErrorText(error)))
        }
      />
    </div>
  )
}

function ExistingDraft({
  id,
  overview,
  onDirty,
  onClose,
  onDone,
}: {
  id: string
  overview: LegalOverview
  onDirty: (dirty: boolean) => void
  onClose: () => void
  onDone: () => void
}) {
  const draft = useLegalDraft(id)
  if (!draft.data) {
    return draft.isError ? (
      <ErrorState error={draft.error} onRetry={() => void draft.refetch()} className="h-full" />
    ) : (
      <ListSkeleton rows={6} />
    )
  }
  if (draft.data.status === 'pending' || draft.data.status === 'published') {
    return <DraftReview draft={draft.data} overview={overview} onClose={onClose} onDone={onDone} />
  }
  return (
    <DraftEditor
      key={`${draft.data.id}-${draft.data.status}`}
      draft={draft.data}
      seed={null}
      overview={overview}
      onSaved={() => undefined}
      onDirty={onDirty}
      onClose={onClose}
      onDone={onDone}
    />
  )
}

export function DraftSheet({
  target,
  overview,
  onTarget,
  onClose,
}: {
  target: DraftTarget | null
  overview: LegalOverview
  onTarget: (target: DraftTarget) => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const [dirty, setDirty] = useState(false)
  const [discarding, setDiscarding] = useState(false)
  const requestClose = () => (dirty ? setDiscarding(true) : onClose())
  const done = () => {
    setDirty(false)
    onClose()
  }
  return (
    <Sheet open={target !== null} onOpenChange={(open) => !open && requestClose()}>
      <SheetContent
        title={t('legal.editor.sheetTitle')}
        closeLabel={t('app.close')}
        className="w-[min(880px,100vw)] bg-background"
      >
        {target === null ? null : target.id === null ? (
          <DraftEditor
            draft={null}
            seed={target.seed}
            overview={overview}
            onSaved={(id) => onTarget({ id })}
            onDirty={setDirty}
            onClose={requestClose}
            onDone={done}
          />
        ) : (
          <ExistingDraft
            key={target.id}
            id={target.id}
            overview={overview}
            onDirty={setDirty}
            onClose={requestClose}
            onDone={done}
          />
        )}
      </SheetContent>
      <Confirm
        open={discarding}
        title={t('legal.confirm.discardTitle')}
        body={t('legal.confirm.discardBody')}
        action={t('legal.confirm.discard')}
        destructive
        pending={false}
        onClose={() => setDiscarding(false)}
        onConfirm={() => {
          setDiscarding(false)
          done()
        }}
      />
    </Sheet>
  )
}
