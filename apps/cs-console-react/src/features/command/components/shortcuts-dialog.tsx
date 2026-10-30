import { useTranslation } from 'react-i18next'

import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Kbd } from '@/components/ui/primitives'

import { useOverlays } from '../bus'

const shortcuts = [
  { keys: ['Ctrl', 'K'], label: 'palette' },
  { keys: ['J'], label: 'next' },
  { keys: ['K'], label: 'previous' },
  { keys: ['A'], label: 'claim' },
  { keys: ['R'], label: 'reply' },
  { keys: ['N'], label: 'note' },
  { keys: ['E'], label: 'resolve' },
  { keys: ['Ctrl', 'Enter'], label: 'send' },
  { keys: ['?'], label: 'help' },
] as const

export function ShortcutsDialog() {
  const { t } = useTranslation()
  const open = useOverlays((state) => state.shortcuts)
  const setOpen = useOverlays((state) => state.setShortcuts)
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{t('shortcuts.title')}</DialogTitle>
        </DialogHeader>
        <dl className="flex flex-col divide-y">
          {shortcuts.map((shortcut) => (
            <div key={shortcut.label} className="flex items-center justify-between gap-4 py-2">
              <dt className="text-sm">{t(`shortcuts.${shortcut.label}`)}</dt>
              <dd className="flex items-center gap-1">
                {shortcut.keys.map((key) => (
                  <Kbd key={key} className="h-6 min-w-6 px-1.5 text-xs">
                    {key}
                  </Kbd>
                ))}
              </dd>
            </div>
          ))}
        </dl>
      </DialogContent>
    </Dialog>
  )
}
