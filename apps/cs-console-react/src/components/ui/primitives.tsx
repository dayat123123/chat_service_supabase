import { Separator as SeparatorPrimitive } from 'radix-ui'
import * as React from 'react'

import { cn, initials } from '@/lib/utils'

function Separator({
  className,
  orientation = 'horizontal',
  decorative = true,
  ...props
}: React.ComponentProps<typeof SeparatorPrimitive.Root>) {
  return (
    <SeparatorPrimitive.Root
      data-slot="separator"
      decorative={decorative}
      orientation={orientation}
      className={cn(
        'shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px',
        className,
      )}
      {...props}
    />
  )
}

function Skeleton({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="skeleton" className={cn('animate-pulse rounded-md bg-muted', className)} {...props} />
  )
}

function Kbd({ className, ...props }: React.ComponentProps<'kbd'>) {
  return (
    <kbd
      data-slot="kbd"
      className={cn(
        'pointer-events-none inline-flex h-5 min-w-5 items-center justify-center gap-1 rounded border bg-muted px-1 font-sans text-[11px] font-medium text-muted-foreground select-none',
        className,
      )}
      {...props}
    />
  )
}

function Card({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card"
      className={cn('flex flex-col rounded-xl border bg-card text-card-foreground shadow-xs', className)}
      {...props}
    />
  )
}

function CardHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-header"
      className={cn('flex items-center gap-2 px-4 pt-4 pb-2', className)}
      {...props}
    />
  )
}

function CardTitle({ className, ...props }: React.ComponentProps<'h3'>) {
  return (
    <h3 data-slot="card-title" className={cn('text-sm leading-none font-semibold', className)} {...props} />
  )
}

function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="card-content" className={cn('px-4 pb-4', className)} {...props} />
}

function Avatar({ name, className, ...props }: React.ComponentProps<'span'> & { name: string }) {
  return (
    <span
      data-slot="avatar"
      aria-hidden="true"
      className={cn(
        'inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold text-secondary-foreground',
        className,
      )}
      {...props}
    >
      {initials(name)}
    </span>
  )
}

export { Avatar, Card, CardContent, CardHeader, CardTitle, Kbd, Separator, Skeleton }
