import { HeadsetIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

export function Logo({ className }: { className?: string }) {
  const { t } = useTranslation()
  return (
    <div className={cn('flex items-center gap-2', className)}>
      <span
        className="inline-flex size-6 items-center justify-center rounded-md bg-primary text-primary-foreground"
        aria-hidden="true"
      >
        <HeadsetIcon className="size-3.5" />
      </span>
      <span className="text-sm font-medium">{t('app.title')}</span>
    </div>
  )
}
