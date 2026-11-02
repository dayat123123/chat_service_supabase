import { ExternalLinkIcon, FileTextIcon, LoaderCircleIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import { useSignedUrl } from '../hooks'
import { DOCUMENT_BUCKET, fileSize } from '../media'
import type { Attachment } from '../types'

const card =
  'flex w-60 max-w-full items-center gap-2.5 rounded-lg border border-current/20 px-2.5 py-2 text-left'

export function DocumentLabel({ name, size }: { name: string; size?: number | null }) {
  const { t } = useTranslation()
  return (
    <>
      <FileTextIcon className="size-5 shrink-0" aria-hidden="true" />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-row font-medium">{name}</span>
        <span className="block text-xs opacity-75">
          {[t('conversation.pdf'), fileSize(size)].filter(Boolean).join(' · ')}
        </span>
      </span>
    </>
  )
}

export function AttachmentFile({ attachment }: { attachment: Attachment }) {
  const { t } = useTranslation()
  const url = useSignedUrl(attachment.path, attachment.bucket ?? DOCUMENT_BUCKET)
  const name = attachment.name || t('conversation.documentFallback')
  if (url.isError) {
    return (
      <div className={cn(card, 'opacity-80')}>
        <DocumentLabel name={name} size={attachment.size} />
        <span className="text-xs">{t('conversation.documentFailed')}</span>
      </div>
    )
  }
  return (
    <a
      href={url.data}
      target="_blank"
      rel="noopener noreferrer"
      aria-disabled={url.data ? undefined : true}
      aria-label={t('conversation.openDocument', { name })}
      onClick={(event) => {
        if (!url.data) event.preventDefault()
      }}
      className={cn(
        card,
        'transition-colors outline-none hover:bg-current/5 focus-visible:ring-2 focus-visible:ring-ring/50',
      )}
    >
      <DocumentLabel name={name} size={attachment.size} />
      {url.data ? (
        <ExternalLinkIcon className="size-4 shrink-0 opacity-70" aria-hidden="true" />
      ) : (
        <LoaderCircleIcon className="size-4 shrink-0 animate-spin opacity-70" aria-hidden="true" />
      )}
    </a>
  )
}
