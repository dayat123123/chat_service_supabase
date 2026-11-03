import { CheckIcon, CopyIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'

export function CopyButton({
  text,
  label,
  onCopied,
  size = 'sm',
}: {
  text: string
  label?: string
  onCopied?: () => void
  size?: 'sm' | 'xs'
}) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  return (
    <Button
      type="button"
      variant="outline"
      size={size}
      aria-label={
        label ? (copied ? `${t('app.copied')}: ${label}` : `${t('app.copy')}: ${label}`) : undefined
      }
      onClick={() =>
        void navigator.clipboard
          .writeText(text)
          .then(() => {
            setCopied(true)
            onCopied?.()
          })
          .catch(() => setCopied(false))
      }
    >
      {copied ? <CheckIcon /> : <CopyIcon />}
      {copied ? t('app.copied') : t('app.copy')}
    </Button>
  )
}
