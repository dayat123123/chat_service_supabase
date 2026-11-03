import { useTranslation } from 'react-i18next'

import { formatNumber, stamp } from '@/lib/time'

const knownCategories = [
  'gambling',
  'porn',
  'phishing',
  'blocked',
  'shortener',
  'messenger',
  'phone',
  'promotion',
  'other_link',
  'coordinated',
] as const

type KnownCategory = (typeof knownCategories)[number]

const isKnown = (value: string): value is KnownCategory =>
  (knownCategories as readonly string[]).includes(value)

export function CategoryList({ categories }: { categories: string[] }) {
  const { t } = useTranslation()
  if (categories.length === 0) return null
  return (
    <ul className="flex flex-wrap gap-1" aria-label={t('moderation.categoriesLabel')}>
      {categories.map((category) => (
        <li key={category} className="rounded-sm border border-warning/40 px-1.5 py-px text-xs text-warning">
          {isKnown(category) ? t(`moderation.categories.${category}`) : category}
        </li>
      ))}
    </ul>
  )
}

export function QueueHeader({
  title,
  hint,
  count,
  children,
}: {
  title: string
  hint?: string
  count?: number
  children?: React.ReactNode
}) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="flex items-center gap-2 text-panel font-semibold">
          {title}
          {count !== undefined ? (
            <span className="tabular text-xs font-normal text-muted-foreground">
              {t('moderation.count', { count, value: formatNumber(count) })}
            </span>
          ) : null}
        </h2>
        {children}
      </div>
      {hint ? <p className="max-w-3xl text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  )
}

export function EditedMark({ editedAt }: { editedAt: string | null | undefined }) {
  const { t } = useTranslation()
  if (!editedAt) return null
  return (
    <span className="text-xs text-muted-foreground" title={t('moderation.edited', { time: stamp(editedAt) })}>
      · {t('moderation.editedShort')}
    </span>
  )
}
