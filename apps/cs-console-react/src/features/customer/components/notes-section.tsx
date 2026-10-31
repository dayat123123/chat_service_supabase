import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Textarea } from '@/components/ui/textarea'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useAddNote, useNotes } from '../hooks'

export function NotesSection({ customerId, ticketId }: { customerId: string; ticketId: string }) {
  const { t } = useTranslation()
  const notes = useNotes(customerId)
  const addNote = useAddNote(customerId)
  const [body, setBody] = useState('')
  const [scope, setScope] = useState<'ticket' | 'customer'>('ticket')
  const submit = () => {
    const text = body.trim()
    if (!text) return
    addNote.mutate(
      { body: text, ticketId: scope === 'ticket' ? ticketId : undefined },
      {
        onSuccess: () => {
          setBody('')
          toast.success(t('composer.noteSaved'))
        },
        onError: (error) => toast.error(errorText(error)),
      },
    )
  }
  return (
    <div className="flex flex-col gap-2">
      <p className="text-xs text-muted-foreground">{t('customer.notesHint')}</p>
      <Textarea
        value={body}
        maxLength={2000}
        onChange={(event) => setBody(event.target.value)}
        placeholder={t('customer.notePlaceholder')}
        aria-label={t('customer.addNote')}
        className="min-h-16 text-row"
      />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <ToggleGroup
          type="single"
          value={scope}
          onValueChange={(value) => value && setScope(value as 'ticket' | 'customer')}
        >
          <ToggleGroupItem value="ticket" className="h-7 px-2 text-xs">
            {t('customer.noteTicket')}
          </ToggleGroupItem>
          <ToggleGroupItem value="customer" className="h-7 px-2 text-xs">
            {t('customer.noteCustomer')}
          </ToggleGroupItem>
        </ToggleGroup>
        <Button size="xs" disabled={!body.trim() || addNote.isPending} onClick={submit}>
          {t('customer.addNote')}
        </Button>
      </div>
      {notes.data?.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('customer.noNotes')}</p>
      ) : null}
      <ul className="flex flex-col gap-1.5">
        {(notes.data ?? []).map((note) => (
          <li
            key={note.id}
            className={cn(
              'border-l-2 px-2.5 py-1.5',
              note.kind === 'handover' ? 'border-strong bg-muted' : 'border-note-border bg-note',
            )}
          >
            <div className="tabular text-xs text-muted-foreground">
              {note.author?.display_name ?? '–'} · {stamp(note.created_at)}
            </div>
            <p className="mt-0.5 text-row whitespace-pre-wrap">{note.body}</p>
          </li>
        ))}
      </ul>
    </div>
  )
}
