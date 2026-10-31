import { ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'

export function Pager({
  page,
  totalPages,
  summary,
  onPage,
}: {
  page: number
  totalPages: number
  summary: string
  onPage: (page: number) => void
}) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-wrap items-center gap-3">
      <span className="tabular text-xs text-muted-foreground" role="status">
        {summary}
      </span>
      {totalPages > 1 ? (
        <div className="ml-auto flex items-center gap-2">
          <span className="tabular text-xs text-muted-foreground">
            {t('nasabah.pager.status', { page, pages: totalPages })}
          </span>
          <Button
            variant="outline"
            size="icon-sm"
            aria-label={t('nasabah.pager.previous')}
            disabled={page <= 1}
            onClick={() => onPage(page - 1)}
          >
            <ChevronLeftIcon />
          </Button>
          <Button
            variant="outline"
            size="icon-sm"
            aria-label={t('nasabah.pager.next')}
            disabled={page >= totalPages}
            onClick={() => onPage(page + 1)}
          >
            <ChevronRightIcon />
          </Button>
        </div>
      ) : null}
    </div>
  )
}
