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
    <div data-slot="skeleton" className={cn('animate-pulse rounded-sm bg-muted', className)} {...props} />
  )
}

function Kbd({ className, ...props }: React.ComponentProps<'kbd'>) {
  return (
    <kbd
      data-slot="kbd"
      className={cn(
        'pointer-events-none inline-flex h-5 min-w-5 items-center justify-center gap-1 rounded-sm border px-1 font-sans text-[11px] font-medium text-muted-foreground select-none',
        className,
      )}
      {...props}
    />
  )
}

function Avatar({ name, className, ...props }: React.ComponentProps<'span'> & { name: string }) {
  return (
    <span
      data-slot="avatar"
      aria-hidden="true"
      className={cn(
        'inline-flex size-7 shrink-0 items-center justify-center rounded-full bg-muted text-[11px] font-medium text-muted-foreground',
        className,
      )}
      {...props}
    >
      {initials(name)}
    </span>
  )
}

export { Avatar, Kbd, Separator, Skeleton }
