import { cva, type VariantProps } from 'class-variance-authority'
import { Slot } from 'radix-ui'
import * as React from 'react'

import { cn } from '@/lib/utils'

const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md text-sm font-medium whitespace-nowrap transition-[color,background-color,border-color,opacity] outline-none focus-visible:ring-2 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/85',
        destructive: 'bg-destructive-solid text-destructive-foreground hover:bg-destructive-solid/90',
        outline: 'border bg-background hover:border-strong hover:bg-muted',
        secondary: 'bg-muted hover:bg-selected',
        ghost: 'text-muted-foreground hover:bg-muted hover:text-foreground',
        link: 'text-primary underline decoration-strong underline-offset-4 hover:decoration-current',
      },
      size: {
        default: 'h-(--control-h) px-3.5',
        sm: 'h-8 px-3 text-row compact:h-7 compact:px-2.5',
        xs: "h-(--control-h-sm) gap-1 px-2 text-xs [&_svg:not([class*='size-'])]:size-3.5",
        icon: 'size-(--control-h)',
        'icon-sm': 'size-8 compact:size-7',
        'icon-xs': "size-(--control-h-sm) [&_svg:not([class*='size-'])]:size-3.5",
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: React.ComponentProps<'button'> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : 'button'
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size, className }))} {...props} />
}

export { Button, buttonVariants }
