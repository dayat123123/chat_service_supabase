import { ExternalLinkIcon, InfoIcon, OctagonAlertIcon, TriangleAlertIcon, XIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import type { BannerDisplay, BannerLevel } from '../types'

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

const POPUP_RADIUS = 16

type PreviewProps = {
  display?: BannerDisplay
  level: BannerLevel
  title: string
  body: string
  link: string | null
  cta?: string | null
  image?: string | null
  dismissible: boolean
}

function StripPreview({ level, title, body, link, cta, dismissible }: PreviewProps) {
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
              {cta || t('platform.banners.preview.link')}
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

function PopupPreview({ title, body, link, cta, image, dismissible }: PreviewProps) {
  const { t } = useTranslation()
  return (
    <figure className="flex flex-col items-center gap-1.5" aria-label={t('platform.banners.preview.title')}>
      <figcaption className="self-start text-xs text-muted-foreground">
        {t('platform.banners.preview.popupCaption')}
      </figcaption>
      <div
        data-display="popup"
        className="relative aspect-[9/19] w-56 overflow-hidden rounded-xl border-4 border-foreground/80 bg-subtle"
      >
        <div aria-hidden="true" className="flex flex-col gap-2 p-3">
          <span className="h-3 w-24 rounded-sm bg-muted-foreground/30" />
          {[0, 1, 2, 3, 4].map((row) => (
            <span key={row} className="h-12 rounded-md bg-muted-foreground/15" />
          ))}
        </div>
        <div aria-hidden="true" className="absolute inset-0 bg-scrim" />
        <div
          data-testid="popup-card"
          className="absolute inset-x-3 top-1/2 max-h-[92%] -translate-y-1/2 overflow-hidden bg-background shadow-float"
          style={{ borderRadius: POPUP_RADIUS }}
        >
          {dismissible ? (
            <span
              className="absolute top-2 right-2 grid size-6 place-items-center rounded-full bg-background/90 text-foreground"
              title={t('platform.banners.preview.close')}
            >
              <XIcon className="size-3.5" aria-label={t('platform.banners.preview.close')} />
            </span>
          ) : null}
          {image ? (
            <img src={image} alt={t('platform.banners.image.alt')} className="max-h-56 w-full object-cover" />
          ) : null}
          <div className="flex flex-col gap-1 p-3">
            <p className="text-sm leading-snug font-semibold break-words">
              {title || t('platform.banners.preview.placeholder')}
            </p>
            {body ? (
              <p className="line-clamp-4 text-xs break-words whitespace-pre-line text-muted-foreground">
                {body}
              </p>
            ) : null}
            {link ? (
              <span className="mt-1.5 block truncate rounded-lg bg-primary px-3 py-1.5 text-center text-xs font-medium text-primary-foreground">
                {cta || t('platform.banners.preview.cta')}
              </span>
            ) : null}
          </div>
        </div>
      </div>
    </figure>
  )
}

export function BannerPreview(props: PreviewProps) {
  return props.display === 'popup' ? <PopupPreview {...props} /> : <StripPreview {...props} />
}
