import { FilePlus2Icon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { formatNumber } from '@/lib/time'

import { useLegalDocument } from '../hooks'
import { wibStamp } from '../logic'
import type { LegalDocument } from '../types'
import { Fact, LegalPreview } from './legal-ui'

function DocumentBody({
  document,
  onDraftFrom,
}: {
  document: LegalDocument
  onDraftFrom: (document: LegalDocument) => void
}) {
  const { t } = useTranslation()
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <p className="text-xs text-muted-foreground">
          {t(`legal.kinds.${document.kind}`)} · {t('legal.version', { version: document.version })}
        </p>
        <h2 className="text-panel font-semibold break-words">{document.title}</h2>
        <p className="text-xs text-muted-foreground">{t('legal.readOnly')}</p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid grid-cols-1 gap-x-4 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
          <Fact label={document.in_effect ? t('legal.effectiveSince') : t('legal.effectiveFrom')}>
            {wibStamp(document.effective_at)}
          </Fact>
          <Fact label={t('legal.acceptedLabel')}>{formatNumber(document.accepted)}</Fact>
          <Fact label={t('legal.author')}>{document.created_by ?? '–'}</Fact>
          <Fact label={t('legal.approver')}>{document.approved_by ?? '–'}</Fact>
          {document.change_summary ? (
            <Fact label={t('legal.changes')} className="sm:col-span-2">
              <span className="whitespace-pre-wrap">{document.change_summary}</span>
            </Fact>
          ) : null}
        </dl>
        <div className="px-5 py-4">
          <LegalPreview title={document.title} body={document.body ?? ''} />
        </div>
      </div>
      <footer className="flex flex-wrap gap-2 border-t px-5 py-3">
        <Button size="sm" variant="outline" onClick={() => onDraftFrom(document)}>
          <FilePlus2Icon />
          {t('legal.draftFromThis')}
        </Button>
      </footer>
    </div>
  )
}

export function DocumentSheet({
  documentId,
  onClose,
  onDraftFrom,
}: {
  documentId: string | null
  onClose: () => void
  onDraftFrom: (document: LegalDocument) => void
}) {
  const { t } = useTranslation()
  const document = useLegalDocument(documentId)
  return (
    <Sheet open={documentId !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('legal.documentTitle')}
        closeLabel={t('app.close')}
        className="w-[min(760px,100vw)] bg-background"
      >
        {document.data ? (
          <DocumentBody document={document.data} onDraftFrom={onDraftFrom} />
        ) : document.isError ? (
          <ErrorState error={document.error} onRetry={() => void document.refetch()} className="h-full" />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </SheetContent>
    </Sheet>
  )
}
