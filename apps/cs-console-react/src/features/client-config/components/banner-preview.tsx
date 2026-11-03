import { ExternalLinkIcon, InfoIcon, OctagonAlertIcon, TriangleAlertIcon, XIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import type { BannerLevel } from '../types'

const levelStyles: Record<BannerLevel, { box: string; icon: string }> = {
  info: { box: 'border-info/40 bg-info/10', icon: 'text-info' },
  warning: { box: 'border-warning/40 bg-warning/10', icon: 'text-warning' },
  critical: { box: 'border-destructive/40 bg-destructive/10', icon: 'text-destructive' },
}

const levelIcons: Record<BannerLevel, React.ComponentType<{ className?: string }>> = {
  info: InfoIcon,
  warning: TriangleAlertIcon,
  critical: OctagonAlertIcon,
}

export function BannerPreview({
  level,
  title,
  body,
  link,
  dismissible,
}: {
  level: BannerLevel
  title: string
  body: string
  link: string | null
  dismissible: boolean
}) {
  const { t } = useTranslation()
  const Icon = levelIcons[level]
  const levelName = t(`platform.banners.levels.${level}`)
  return (
    <figure className="flex flex-col gap-1.5" aria-label={t('platform.banners.preview.title')}>
      <figcaption className="text-xs text-muted-foreground">
        {t('platform.banners.preview.caption', { level: levelName })}
      </figcaption>
      <div
        data-level={level}
        className={cn('flex items-start gap-2.5 rounded-lg border p-3', levelStyles[level].box)}
      >
        <Icon className={cn('mt-0.5 size-4 shrink-0', levelStyles[level].icon)} aria-hidden="true" />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold break-words">
            {title || t('platform.banners.preview.placeholder')}
          </p>
          {body ? <p className="text-row break-words whitespace-pre-line">{body}</p> : null}
          {link ? (
            <p className="mt-1 inline-flex items-center gap-1 text-row font-medium underline">
              {t('platform.banners.preview.link')}
              <ExternalLinkIcon className="size-3.5" aria-hidden="true" />
            </p>
          ) : null}
        </div>
        {dismissible ? (
          <span className="shrink-0 text-muted-foreground" title={t('platform.banners.preview.close')}>
            <XIcon className="size-4" aria-label={t('platform.banners.preview.close')} />
          </span>
        ) : null}
      </div>
    </figure>
  )
}
