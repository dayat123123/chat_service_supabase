import {
  CheckCircle2Icon,
  DownloadIcon,
  ExternalLinkIcon,
  FingerprintIcon,
  LoaderCircleIcon,
  LockIcon,
  LockOpenIcon,
  ShieldCheckIcon,
  XCircleIcon,
} from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { CopyButton } from '@/components/copy-button'
import { ReasonDialog } from '@/components/reason-dialog'
import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/controls'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { downloadText } from '@/lib/download'
import { errorText } from '@/lib/error-text'
import { format } from '@/lib/time'
import { cn } from '@/lib/utils'

import { evidenceApi } from '../api'
import { useEvidenceDetail, useSetHold, useVerifyEvidence } from '../hooks'
import {
  bundleFileName,
  bundleWithLinks,
  contextText,
  copiedFiles,
  custodyDetails,
  formatBytes,
  shortHash,
} from '../logic'
import {
  EXPORT_LINK_SECONDS,
  VIEW_LINK_SECONDS,
  type CustodyEntry,
  type EvidenceActor,
  type EvidenceDetail,
  type EvidenceFile,
  type VerifyResult,
} from '../types'
import { FileStatusText, RetentionText } from './evidence-badges'

const stampOf = (value: string | null | undefined) =>
  value ? `${format(value, 'd MMM yyyy, HH.mm')} WIB` : '–'

function actorName(actor: EvidenceActor) {
  if (!actor) return null
  return actor.display_name ?? (actor.username ? `@${actor.username}` : (actor.agent_code ?? actor.id))
}

function Section({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-2 border-t px-5 py-4">
      <div className="flex items-center justify-between gap-2">
        <h3 className="text-sm font-semibold">{title}</h3>
        {aside}
      </div>
      {children}
    </section>
  )
}

function HashRow({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className="w-36 shrink-0 text-muted-foreground">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono" title={value ?? undefined}>
        {value ?? '–'}
      </code>
      {value ? <CopyButton text={value} label={label} size="xs" /> : null}
    </div>
  )
}

function Check({ ok, label }: { ok: boolean; label: string }) {
  const { t } = useTranslation()
  return (
    <li className="flex items-center gap-2 text-xs">
      {ok ? (
        <CheckCircle2Icon className="size-4 text-success" aria-hidden="true" />
      ) : (
        <XCircleIcon className="size-4 text-danger" aria-hidden="true" />
      )}
      <span className="flex-1">{label}</span>
      <span className={cn('font-medium', ok ? 'text-success' : 'text-danger')}>
        {ok ? t('evidence.integrity.pass') : t('evidence.integrity.fail')}
      </span>
    </li>
  )
}

function IntegrityResult({ result }: { result: VerifyResult }) {
  const { t } = useTranslation()
  return (
    <div
      role="status"
      className={cn(
        'flex flex-col gap-2 rounded-md border p-3',
        result.ok ? 'border-success/40' : 'border-danger/50',
      )}
    >
      <p className={cn('text-sm font-medium', result.ok ? 'text-success' : 'text-danger')}>
        {result.ok ? t('evidence.integrity.ok') : t('evidence.integrity.broken')}
      </p>
      <p className="text-xs text-muted-foreground">
        {t('evidence.integrity.title', { at: stampOf(result.checked_at) })}
      </p>
      <ul className="flex flex-col gap-1">
        <Check ok={result.content_ok} label={t('evidence.integrity.content')} />
        <Check ok={result.body_ok} label={t('evidence.integrity.body')} />
        <Check ok={result.record_ok} label={t('evidence.integrity.record')} />
        <Check
          ok={result.custody_ok}
          label={t('evidence.integrity.custody', { count: result.custody_entries })}
        />
        <Check ok={result.files_ok} label={t('evidence.integrity.files')} />
      </ul>
    </div>
  )
}

function FileRow({ file }: { file: EvidenceFile }) {
  const { t } = useTranslation()
  const [checking, setChecking] = useState(false)
  const [opening, setOpening] = useState(false)
  const [match, setMatch] = useState<boolean | null>(null)
  const copied = file.status === 'copied'

  const open = async () => {
    const tab = window.open('', '_blank')
    setOpening(true)
    try {
      const url = await evidenceApi.signedUrl(file.object_name, VIEW_LINK_SECONDS)
      if (tab) {
        tab.opener = null
        tab.location.href = url
      }
    } catch (error) {
      tab?.close()
      toast.error(errorText(error))
    } finally {
      setOpening(false)
    }
  }

  const check = async () => {
    setChecking(true)
    try {
      const hash = await evidenceApi.fileHash(file.object_name)
      const result = await evidenceApi.fileChecked(file.id, hash)
      setMatch(result.match)
      const message = t(result.match ? 'evidence.detail.fileMatch' : 'evidence.detail.fileMismatch', {
        position: file.position,
      })
      if (result.match) toast.success(message)
      else toast.error(message)
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setChecking(false)
    }
  }

  return (
    <li className="flex flex-col gap-1.5 border-b py-2 last:border-b-0">
      <div className="flex flex-wrap items-center gap-2">
        <span className="tabular w-6 text-xs text-muted-foreground">#{file.position}</span>
        <span className="min-w-0 flex-1 truncate font-mono text-xs" title={file.object_name}>
          {file.object_name.split('/').pop()}
        </span>
        <FileStatusText status={file.status} />
        <span className="tabular text-xs text-muted-foreground">{formatBytes(file.size)}</span>
        {copied ? (
          <>
            <Button size="xs" variant="outline" disabled={opening} onClick={() => void open()}>
              {opening ? <LoaderCircleIcon className="animate-spin" /> : <ExternalLinkIcon />}
              {t('evidence.detail.open')}
            </Button>
            <Button size="xs" variant="outline" disabled={checking} onClick={() => void check()}>
              {checking ? <LoaderCircleIcon className="animate-spin" /> : <FingerprintIcon />}
              {checking ? t('evidence.detail.checking') : t('evidence.detail.checkFile')}
            </Button>
          </>
        ) : null}
      </div>
      <p
        className="truncate pl-8 text-xs text-muted-foreground"
        title={`${file.source_bucket}/${file.source_name}`}
      >
        {t('evidence.detail.fileFrom', { bucket: file.source_bucket, name: file.source_name })}
      </p>
      {file.sha256 ? (
        <p className="flex items-center gap-1.5 pl-8 text-xs">
          <code
            className={cn(
              'truncate font-mono',
              match === true && 'text-success',
              match === false && 'font-medium text-danger',
            )}
            title={file.sha256}
          >
            SHA-256 {file.sha256}
          </code>
        </p>
      ) : null}
      {file.error && file.status !== 'copied' ? (
        <p className="pl-8 text-xs text-danger">{t('evidence.detail.fileError', { error: file.error })}</p>
      ) : null}
    </li>
  )
}

function CustodyList({ entries }: { entries: CustodyEntry[] }) {
  const { t } = useTranslation()
  return (
    <ol className="flex flex-col">
      {entries.map((entry) => {
        const details = custodyDetails(entry.details)
        const actor = actorName(entry.actor)
        return (
          <li key={entry.id} className="flex flex-col gap-0.5 border-b py-2 text-xs last:border-b-0">
            <div className="flex flex-wrap items-baseline gap-x-2">
              <span className="font-medium">
                {t(`evidence.custodyActions.${entry.action}`, { defaultValue: entry.action })}
              </span>
              <span className="tabular text-muted-foreground">{stampOf(entry.at)}</span>
              <span className="text-muted-foreground">
                ·{' '}
                {actor ??
                  t(`evidence.actorTypes.${entry.actor_type as 'system'}`, {
                    defaultValue: entry.actor_type,
                  })}
                {entry.actor_roles.length > 0
                  ? ` (${entry.actor_roles.map((role) => t(`roles.${role as 'cs_agent'}`, { defaultValue: role })).join(', ')})`
                  : ''}
              </span>
            </div>
            {details ? <p className="break-words text-muted-foreground">{details}</p> : null}
            <code
              className="truncate font-mono text-[11px] text-muted-foreground/80"
              title={entry.entry_sha256}
            >
              {shortHash(entry.entry_sha256, 24)}
            </code>
          </li>
        )
      })}
    </ol>
  )
}

function ContentBlock({ detail }: { detail: EvidenceDetail }) {
  const { t } = useTranslation()
  const content = detail.content
  if (detail.target_type === 'user') {
    return (
      <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-row">
        <dt className="text-muted-foreground">{t('evidence.detail.username')}</dt>
        <dd className="break-words">{content.username ? `@${content.username}` : '–'}</dd>
        <dt className="text-muted-foreground">{t('evidence.detail.displayName')}</dt>
        <dd className="break-words">{content.display_name ?? '–'}</dd>
        <dt className="text-muted-foreground">{t('evidence.detail.bio')}</dt>
        <dd className="break-words whitespace-pre-wrap">{content.body ?? '–'}</dd>
      </dl>
    )
  }
  return (
    <p className="rounded-md bg-muted px-3 py-2 text-row break-words whitespace-pre-wrap">
      {content.body ? (
        content.body
      ) : (
        <span className="text-muted-foreground">{t('evidence.detail.emptyBody')}</span>
      )}
    </p>
  )
}

function DetailBody({ detail }: { detail: EvidenceDetail }) {
  const { t } = useTranslation()
  const verify = useVerifyEvidence()
  const setHold = useSetHold()
  const [result, setResult] = useState<VerifyResult | null>(null)
  const [holdOpen, setHoldOpen] = useState(false)
  const [exportOpen, setExportOpen] = useState(false)
  const [exporting, setExporting] = useState(false)
  const author = detail.author

  const runVerify = () =>
    verify.mutate(detail.id, {
      onSuccess: setResult,
      onError: (error) => toast.error(errorText(error)),
    })

  const submitHold = (reason: string) =>
    setHold.mutate(
      { id: detail.id, hold: !detail.legal_hold, reason },
      {
        onSuccess: (status) => {
          setHoldOpen(false)
          toast.success(
            t(status.legal_hold ? 'evidence.holdDialog.setDone' : 'evidence.holdDialog.releaseDone'),
          )
        },
        onError: (error) => toast.error(errorText(error)),
      },
    )

  const submitExport = async (purpose: string) => {
    setExporting(true)
    try {
      const bundle = await evidenceApi.exportBundle(detail.id, purpose)
      const files = copiedFiles(bundle.files)
      const links = await Promise.all(
        files.map(async (file) => ({
          object_name: file.object_name,
          url: await evidenceApi.signedUrl(file.object_name, EXPORT_LINK_SECONDS),
        })),
      )
      const expiresAt = new Date(Date.now() + EXPORT_LINK_SECONDS * 1000).toISOString()
      downloadText(
        bundleFileName(bundle.evidence.code, bundle.manifest_sha256),
        `${JSON.stringify(bundleWithLinks(bundle, links, expiresAt), null, 2)}\n`,
        'application/json;charset=utf-8',
      )
      setExportOpen(false)
      toast.success(t('evidence.exportDialog.done', { hash: shortHash(bundle.manifest_sha256) }))
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setExporting(false)
    }
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
      <header className="flex flex-col gap-2 px-5 pt-5 pb-4">
        <div className="flex flex-wrap items-center gap-2 pr-8">
          <h2 className="font-mono text-lg font-semibold">{detail.code}</h2>
          <span className="rounded bg-muted px-1.5 py-0.5 text-xs">
            {t(`evidence.sources.${detail.source}`)}
          </span>
          <span className="rounded bg-muted px-1.5 py-0.5 text-xs">
            {t(`evidence.targets.${detail.target_type}`)}
          </span>
          <RetentionText row={detail} />
        </div>
        <dl className="grid grid-cols-[9rem_1fr] gap-x-3 gap-y-1 text-xs">
          <dt className="text-muted-foreground">{t('evidence.columns.author')}</dt>
          <dd className="break-words">
            {author?.display_name ?? '–'}
            {author?.username ? ` · @${author.username}` : ''}
          </dd>
          <dt className="text-muted-foreground">{t('evidence.columns.target')}</dt>
          <dd className="font-mono break-all">{detail.target_id}</dd>
          <dt className="text-muted-foreground">{t('evidence.detail.capturedAt')}</dt>
          <dd>{stampOf(detail.captured_at)}</dd>
          <dt className="text-muted-foreground">{t('evidence.detail.capturedBy')}</dt>
          <dd>{actorName(detail.captured_by) ?? '–'}</dd>
          <dt className="text-muted-foreground">{t('evidence.detail.retainUntil')}</dt>
          <dd>{stampOf(detail.retain_until)}</dd>
        </dl>
        {detail.hold ? (
          <p className="rounded-md border border-warning/40 px-3 py-2 text-xs">
            <span className="font-medium">
              {t('evidence.detail.holdBy', {
                name: actorName(detail.hold.by) ?? '–',
                at: stampOf(detail.hold.at),
              })}
            </span>
            <br />
            {detail.hold.reason}
          </p>
        ) : null}
        <div className="flex flex-wrap gap-2">
          <Button size="sm" variant="outline" disabled={verify.isPending} onClick={runVerify}>
            {verify.isPending ? <LoaderCircleIcon className="animate-spin" /> : <ShieldCheckIcon />}
            {verify.isPending ? t('evidence.actions.verifying') : t('evidence.actions.verify')}
          </Button>
          {detail.can_manage ? (
            <>
              <Button size="sm" variant="outline" onClick={() => setHoldOpen(true)}>
                {detail.legal_hold ? <LockOpenIcon /> : <LockIcon />}
                {detail.legal_hold ? t('evidence.actions.release') : t('evidence.actions.hold')}
              </Button>
              <Button size="sm" variant="outline" disabled={exporting} onClick={() => setExportOpen(true)}>
                {exporting ? <LoaderCircleIcon className="animate-spin" /> : <DownloadIcon />}
                {exporting ? t('evidence.actions.exporting') : t('evidence.actions.export')}
              </Button>
            </>
          ) : null}
        </div>
        {result ? <IntegrityResult result={result} /> : null}
        <p className="text-xs text-muted-foreground">{t('evidence.detail.viewNotice')}</p>
      </header>

      <Section
        title={detail.target_type === 'user' ? t('evidence.detail.profile') : t('evidence.detail.content')}
      >
        <ContentBlock detail={detail} />
      </Section>

      <Section title={t('evidence.detail.files')}>
        {detail.files_detail.length > 0 ? (
          <ul className="flex flex-col">
            {detail.files_detail.map((file) => (
              <FileRow key={file.id} file={file} />
            ))}
          </ul>
        ) : (
          <p className="text-xs text-muted-foreground">{t('evidence.detail.noFiles')}</p>
        )}
      </Section>

      <Section title={t('evidence.detail.hashes')}>
        <HashRow label={t('evidence.detail.contentHash')} value={detail.content_sha256} />
        <HashRow label={t('evidence.detail.bodyHash')} value={detail.body_sha256} />
        <HashRow label={t('evidence.detail.recordHash')} value={detail.record_sha256} />
      </Section>

      <Section title={t('evidence.detail.reports')}>
        {detail.reports.length > 0 ? (
          <ul className="flex flex-col">
            {detail.reports.map((report) => (
              <li key={report.id} className="flex flex-col gap-0.5 border-b py-2 text-xs last:border-b-0">
                <span className="font-medium">
                  {report.reason} · {report.status}
                </span>
                <span className="text-muted-foreground">
                  {t('evidence.detail.reporter')}: {report.reporter.display_name ?? '–'}
                  {report.reporter.username ? ` · @${report.reporter.username}` : ''} ·{' '}
                  {stampOf(report.created_at)}
                </span>
                {report.details ? (
                  <span className="break-words whitespace-pre-wrap">{report.details}</span>
                ) : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-xs text-muted-foreground">{t('evidence.detail.noReports')}</p>
        )}
      </Section>

      <Section title={t('evidence.detail.context')}>
        <Accordion type="single" collapsible>
          <AccordionItem value="context">
            <AccordionTrigger className="text-xs">JSON</AccordionTrigger>
            <AccordionContent>
              <pre className="max-h-80 overflow-auto rounded-md bg-muted p-3 font-mono text-[11px] leading-relaxed">
                {contextText(detail.context)}
              </pre>
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </Section>

      <Section
        title={t('evidence.detail.custody')}
        aside={
          <span className="text-xs text-muted-foreground">
            {t('evidence.detail.custodyCount', { count: detail.custody.length })}
          </span>
        }
      >
        <CustodyList entries={detail.custody} />
      </Section>

      <ReasonDialog
        open={holdOpen}
        title={detail.legal_hold ? t('evidence.holdDialog.releaseTitle') : t('evidence.holdDialog.setTitle')}
        description={
          detail.legal_hold
            ? t('evidence.holdDialog.releaseDescription')
            : t('evidence.holdDialog.setDescription')
        }
        label={t('evidence.holdDialog.label')}
        hint={t('evidence.holdDialog.hint')}
        action={detail.legal_hold ? t('evidence.actions.release') : t('evidence.actions.hold')}
        min={10}
        max={500}
        pending={setHold.isPending}
        onSubmit={submitHold}
        onClose={() => setHoldOpen(false)}
      />
      <ReasonDialog
        open={exportOpen}
        title={t('evidence.exportDialog.title')}
        description={t('evidence.exportDialog.description')}
        label={t('evidence.exportDialog.label')}
        hint={t('evidence.exportDialog.hint')}
        action={t('evidence.actions.export')}
        min={5}
        max={500}
        pending={exporting}
        onSubmit={(purpose) => void submitExport(purpose)}
        onClose={() => setExportOpen(false)}
      />
    </div>
  )
}

export function EvidenceSheet({ id, onClose }: { id: string | null; onClose: () => void }) {
  const { t } = useTranslation()
  const detail = useEvidenceDetail(id)
  return (
    <Sheet open={id !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={
          detail.data ? t('evidence.detail.title', { code: detail.data.code }) : t('evidence.detail.loading')
        }
        closeLabel={t('app.close')}
        className="w-[min(760px,100vw)] bg-background"
      >
        {detail.data ? (
          <DetailBody detail={detail.data} />
        ) : detail.isError ? (
          <ErrorState error={detail.error} onRetry={() => void detail.refetch()} className="h-full" />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </SheetContent>
    </Sheet>
  )
}
