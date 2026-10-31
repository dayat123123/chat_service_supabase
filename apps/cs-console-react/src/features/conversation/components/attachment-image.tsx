import { ImageOffIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { stamp } from '@/lib/time'

import { useSignedUrl } from '../hooks'
import type { Attachment } from '../types'

function Watermark({ label }: { label: string }) {
  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-0 overflow-hidden select-none">
      <div className="absolute -inset-1/2 flex rotate-[-24deg] flex-wrap content-center gap-x-16 gap-y-14 opacity-25">
        {Array.from({ length: 36 }, (_, i) => (
          <span
            key={i}
            className="text-sm font-medium whitespace-nowrap text-media-foreground mix-blend-difference"
          >
            {label}
          </span>
        ))}
      </div>
    </div>
  )
}

export function AttachmentImage({ attachment, compact }: { attachment: Attachment; compact?: boolean }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const url = useSignedUrl(attachment.path)
  const [open, setOpen] = useState(false)
  const [failed, setFailed] = useState(false)
  const watermark = t('conversation.watermark', {
    name: `${agent.display_name} ${agent.agent_code}`,
    time: stamp(new Date()),
  })
  const ratio = attachment.width && attachment.height ? attachment.width / attachment.height : 4 / 3
  const box = compact ? 'h-24 w-32' : 'max-h-64 w-56'

  if (url.isError || failed) {
    return (
      <div
        className={`flex ${box} items-center justify-center gap-1.5 rounded-lg border bg-muted text-xs text-muted-foreground`}
      >
        <ImageOffIcon className="size-4" />
        {t('conversation.imageFailed')}
      </div>
    )
  }
  if (!url.data) return <Skeleton className={`${box} rounded-lg`} style={{ aspectRatio: String(ratio) }} />
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="relative block overflow-hidden rounded-lg border bg-muted outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
        aria-label={t('conversation.openImage')}
      >
        <img
          src={url.data}
          alt={t('conversation.attachment')}
          loading="lazy"
          decoding="async"
          className={`${box} object-cover`}
          onError={() => setFailed(true)}
        />
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent
          className="max-w-[min(92vw,1100px)] border-0 bg-media p-2 sm:max-w-[min(92vw,1100px)]"
          closeLabel={t('app.close')}
        >
          <DialogTitle className="sr-only">{t('conversation.attachment')}</DialogTitle>
          <DialogDescription className="sr-only">{watermark}</DialogDescription>
          <div className="relative flex max-h-[85vh] items-center justify-center overflow-hidden">
            <img
              src={url.data}
              alt={t('conversation.attachment')}
              className="max-h-[85vh] w-auto object-contain"
            />
            <Watermark label={watermark} />
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}
