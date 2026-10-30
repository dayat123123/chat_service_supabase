import { AlertTriangleIcon, InboxIcon, RotateCcwIcon } from 'lucide-react'
import * as React from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/primitives'
import { errorText } from '@/lib/error-text'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'

export function EmptyState({
  icon: Icon = InboxIcon,
  title,
  className,
  children,
}: {
  icon?: React.ComponentType<{ className?: string }>
  title: string
  className?: string
  children?: React.ReactNode
}) {
  return (
    <div className={cn('flex flex-col items-center justify-center gap-2 p-6 text-center', className)}>
      <Icon className="size-8 text-muted-foreground/60" aria-hidden="true" />
      <p className="text-sm text-muted-foreground">{title}</p>
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
      <AlertTriangleIcon className="size-7 text-destructive" aria-hidden="true" />
      <p className="text-sm">{errorText(error)}</p>
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
    <div className={cn('flex flex-col gap-3 p-3', className)} aria-busy="true">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="flex gap-3">
          <Skeleton className="size-8 rounded-full" />
          <div className="flex flex-1 flex-col gap-2">
            <Skeleton className="h-3.5 w-2/3" />
            <Skeleton className="h-3 w-full" />
          </div>
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
    logger.error(`Gangguan di bagian ${this.props.label}`, error)
  }

  override render() {
    if (this.state.failed) {
      return (
        <div role="alert" className="flex h-full flex-col items-center justify-center gap-3 p-6 text-center">
          <AlertTriangleIcon className="size-7 text-destructive" aria-hidden="true" />
          <p className="font-medium">{this.props.title}</p>
          <p className="max-w-xs text-sm text-muted-foreground">{this.props.body}</p>
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
