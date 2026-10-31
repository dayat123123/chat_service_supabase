import * as React from 'react'

import { cn } from '@/lib/utils'

const fieldClass =
  'w-full min-w-0 rounded-md border bg-background text-sm transition-[border-color,box-shadow] outline-none hover:border-strong focus-visible:border-ring/60 focus-visible:ring-2 focus-visible:ring-ring/15 disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground aria-invalid:border-destructive aria-invalid:ring-destructive/15'

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(fieldClass, 'flex h-(--control-h) px-3 py-1', className)}
      {...props}
    />
  )
}

export { fieldClass, Input }
