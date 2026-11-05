import { AlertCircleIcon, RotateCcwIcon } from 'lucide-react'
import * as React from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/primitives'
import { errorText } from '@/lib/error-text'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'

export function EmptyState({
  title,
  className,
  children,
}: {
  title: string
  className?: string
  children?: React.ReactNode
}) {
  return (
    <div className={cn('flex flex-col items-center justify-center gap-2 p-6 text-center', className)}>
      <p className="text-row text-muted-foreground">{title}</p>
      {children}
    </div>
  )
}

export function ErrorState({
  error,
  onRetry,
  className,
}: {
  error: unknown
  onRetry?: () => void
  className?: string
}) {
  const { t } = useTranslation()
  return (
    <div
      role="alert"
      className={cn('flex flex-col items-center justify-center gap-3 p-6 text-center', className)}
    >
      <p className="inline-flex items-center gap-1.5 text-row text-destructive">
        <AlertCircleIcon className="size-4 shrink-0" aria-hidden="true" />
        {errorText(error)}
      </p>
      {onRetry ? (
        <Button variant="outline" size="sm" onClick={onRetry}>
          <RotateCcwIcon />
          {t('app.retry')}
        </Button>
      ) : null}
    </div>
  )
}

export function ListSkeleton({ rows = 6, className }: { rows?: number; className?: string }) {
  return (
    <div className={cn('flex flex-col', className)} aria-busy="true">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="flex flex-col gap-2 border-b px-3 py-3">
          <Skeleton className="h-2.5 w-2/5" />
          <Skeleton className="h-2 w-3/5" />
          <Skeleton className="h-2 w-4/5" />
        </div>
      ))}
    </div>
  )
}

type BoundaryProps = { children: React.ReactNode; label: string; title: string; body: string; reload: string }
type BoundaryState = { failed: boolean; key: number }

class Boundary extends React.Component<BoundaryProps, BoundaryState> {
  override state: BoundaryState = { failed: false, key: 0 }

  static getDerivedStateFromError(): Partial<BoundaryState> {
    return { failed: true }
  }

  override componentDidCatch(error: unknown) {
    logger.error(`Section ${this.props.label} crashed`, error)
  }

  override render() {
    if (this.state.failed) {
      return (
        <div role="alert" className="flex h-full flex-col items-center justify-center gap-2 p-6 text-center">
          <p className="font-medium">{this.props.title}</p>
          <p className="max-w-xs text-row text-muted-foreground">{this.props.body}</p>
          <Button
            variant="outline"
            size="sm"
            onClick={() => this.setState((state) => ({ failed: false, key: state.key + 1 }))}
          >
            <RotateCcwIcon />
            {this.props.reload}
          </Button>
        </div>
      )
    }
    return <React.Fragment key={this.state.key}>{this.props.children}</React.Fragment>
  }
}

export function SectionBoundary({ label, children }: { label: string; children: React.ReactNode }) {
  const { t } = useTranslation()
  return (
    <Boundary
      label={label}
      title={t('app.crashTitle')}
      body={t('app.crashBody')}
      reload={t('app.reloadSection')}
    >
      {children}
    </Boundary>
  )
}
