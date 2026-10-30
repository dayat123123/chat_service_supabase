import { HeadsetIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

export function Logo({ compact = false, className }: { compact?: boolean; className?: string }) {
  const { t } = useTranslation()
  return (
    <div className={cn('flex items-center gap-2', className)}>
      <span
        className={cn(
          'inline-flex items-center justify-center rounded-lg bg-primary text-primary-foreground',
          compact ? 'size-7' : 'size-9',
        )}
        aria-hidden="true"
      >
        <HeadsetIcon className={compact ? 'size-4' : 'size-5'} />
      </span>
      <span className={cn('font-semibold tracking-tight', compact ? 'text-base' : 'text-lg')}>
        {t('app.title')}
      </span>
    </div>
  )
}
