import { Toaster } from 'sonner'

import { Dot } from '@/components/badges'
import type { Theme } from '@/lib/preferences'

import { buttonVariants } from './button'

export const toastClasses = {
  toast:
    'flex w-full items-center gap-2.5 rounded-lg border bg-popover px-3.5 py-2.5 text-sm text-popover-foreground shadow-float',
  content: 'flex min-w-0 flex-1 flex-col gap-0.5',
  title: 'leading-snug',
  description: 'text-xs text-muted-foreground',
  icon: 'flex size-3 shrink-0 items-center justify-center',
  actionButton: buttonVariants({ size: 'xs' }),
  cancelButton: buttonVariants({ variant: 'ghost', size: 'xs' }),
}

export function AppToaster({ theme }: { theme: Theme }) {
  return (
    <Toaster
      theme={theme}
      position="bottom-right"
      offset={16}
      gap={8}
      visibleToasts={4}
      toastOptions={{ unstyled: true, classNames: toastClasses }}
      icons={{ success: null, info: null, warning: <Dot tone="warn" />, error: <Dot tone="late" /> }}
    />
  )
}
