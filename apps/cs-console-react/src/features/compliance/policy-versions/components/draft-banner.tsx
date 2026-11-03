import { Link } from '@tanstack/react-router'
import { FilePenLineIcon, InfoIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import { usePolicyState } from '../hooks'

export function DraftBanner({ className }: { className?: string }) {
  const { t } = useTranslation()
  const state = usePolicyState()
  if (!state.data) return null
  const { draft, four_eyes: fourEyes, pending_to_review: toReview } = state.data
  return (
    <div
      role="status"
      className={cn(
        'flex flex-col gap-1.5 rounded-lg border px-3 py-2 text-row sm:flex-row sm:items-center sm:justify-between',
        draft ? 'border-warning/50 bg-warning/5' : 'bg-subtle',
        className,
      )}
    >
      <p className="flex items-start gap-2">
        {draft ? (
          <FilePenLineIcon className="mt-0.5 size-4 shrink-0 text-warning" aria-hidden="true" />
        ) : (
          <InfoIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
        )}
        <span>
          {draft
            ? draft.diff.total > 0
              ? t('policy.versions.banner.draft', { count: draft.diff.total })
              : t('policy.versions.banner.draftEmpty')
            : fourEyes
              ? t('policy.versions.banner.idleFourEyes')
              : t('policy.versions.banner.idle')}
          {toReview > 0 ? (
            <span className="ml-1 font-medium">
              {t('policy.versions.banner.toReview', { count: toReview })}
            </span>
          ) : null}
        </span>
      </p>
      {draft || toReview > 0 ? (
        <Link
          to="/compliance/content"
          search={{ tab: 'versions' }}
          className="shrink-0 font-medium text-foreground underline underline-offset-4"
        >
          {draft ? t('policy.versions.banner.review') : t('policy.versions.banner.open')}
        </Link>
      ) : null}
    </div>
  )
}
