import { HistoryIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { stamp } from '@/lib/time'

import { useEditHistory } from '../hooks'

function History({ type, id }: { type: 'post' | 'comment'; id: string }) {
  const { t } = useTranslation()
  const history = useEditHistory(type, id, true)
  if (history.isError) return <ErrorState error={history.error} onRetry={() => void history.refetch()} />
  if (!history.data) return <ListSkeleton rows={2} />
  if (history.data.length === 0)
    return <p className="text-row text-muted-foreground">{t('moderation.edits.none')}</p>
  return (
    <ol className="flex flex-col gap-3">
      {[...history.data].reverse().map((version, index) => (
        <li
          key={`${version.edited_at}-${index}`}
          className="flex flex-col gap-1 border-b pb-3 last:border-b-0"
        >
          <p className="text-xs text-muted-foreground">
            {t('moderation.edits.before', { time: stamp(version.edited_at) })}
          </p>
          <p className="rounded-md bg-subtle p-2 text-row break-words whitespace-pre-wrap">
            {version.body || '–'}
          </p>
        </li>
      ))}
    </ol>
  )
}

export function EditHistoryButton({ type, id }: { type: 'post' | 'comment'; id: string }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const label = t(`moderation.edits.open.${type}`)
  return (
    <>
      <Button size="xs" variant="ghost" onClick={() => setOpen(true)}>
        <HistoryIcon />
        {label}
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
          <DialogHeader>
            <DialogTitle>{label}</DialogTitle>
            <DialogDescription>{t('moderation.edits.hint')}</DialogDescription>
          </DialogHeader>
          {open ? <History type={type} id={id} /> : null}
        </DialogContent>
      </Dialog>
    </>
  )
}
