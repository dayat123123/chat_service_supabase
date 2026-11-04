import { ArrowLeftIcon, LoaderCircleIcon, PencilIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import i18n from '@/i18n'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'

import { useDeleteMyQuickReply, useMyQuickReplies, useSaveMyQuickReply } from '../hooks'
import { replyDraftProblems } from '../quick-replies'
import { requestsSecret } from '../secret'
import { MAX_PERSONAL_REPLIES, MAX_REPLY_BODY, MAX_REPLY_TITLE, type PersonalQuickReply } from '../types'

const replyErrorCodes = [
  'quick_reply_limit',
  'quick_reply_not_found',
  'duplicate_shortcut',
  'invalid_shortcut',
  'invalid_title',
  'invalid_body',
  'secret_request_blocked',
] as const

type ReplyErrorCode = (typeof replyErrorCodes)[number]

function replyErrorText(error: unknown) {
  const code = toApiError(error).code
  return (replyErrorCodes as readonly string[]).includes(code)
    ? i18n.t(`replies.errors.${code as ReplyErrorCode}`)
    : errorText(error)
}

const variables = '{nama}, {nomor_tiket}, {nama_cs}'

function ReplyForm({ reply, onDone }: { reply: PersonalQuickReply | null; onDone: () => void }) {
  const { t } = useTranslation()
  const save = useSaveMyQuickReply()
  const [title, setTitle] = useState(reply?.title ?? '')
  const [shortcut, setShortcut] = useState(reply?.shortcut ?? '')
  const [body, setBody] = useState(reply?.body ?? '')
  const [touched, setTouched] = useState(false)
  const problems = replyDraftProblems({ title, body, shortcut })
  const secret = requestsSecret(title) || requestsSecret(body)
  const invalid = problems.title || problems.body || problems.shortcut || secret

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    setTouched(true)
    if (invalid) return
    try {
      await save.mutateAsync({
        id: reply?.id ?? null,
        title: title.trim(),
        body: body.trim(),
        shortcut: shortcut.trim(),
      })
      toast.success(t('replies.saved'))
      onDone()
    } catch {
      return
    }
  }

  return (
    <form className="flex flex-col gap-4" onSubmit={(event) => void submit(event)} noValidate>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="personal-reply-title">{t('replies.fieldTitle')}</Label>
        <Input
          id="personal-reply-title"
          autoFocus
          value={title}
          maxLength={MAX_REPLY_TITLE}
          aria-invalid={touched && problems.title ? true : undefined}
          onChange={(event) => setTitle(event.target.value)}
        />
        {touched && problems.title ? (
          <p className="text-xs text-destructive">{t('replies.invalidTitle', { max: MAX_REPLY_TITLE })}</p>
        ) : null}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="personal-reply-shortcut">{t('replies.fieldShortcut')}</Label>
        <div className="flex items-center rounded-md border bg-background transition-[border-color,box-shadow] focus-within:border-ring/60 focus-within:ring-2 focus-within:ring-ring/15">
          <span className="pl-3 text-sm text-muted-foreground" aria-hidden="true">
            /
          </span>
          <Input
            id="personal-reply-shortcut"
            value={shortcut}
            maxLength={32}
            className="border-0 pl-1 focus-visible:ring-0"
            aria-invalid={touched && problems.shortcut ? true : undefined}
            onChange={(event) => setShortcut(event.target.value)}
          />
        </div>
        <p
          className={
            touched && problems.shortcut ? 'text-xs text-destructive' : 'text-xs text-muted-foreground'
          }
        >
          {touched && problems.shortcut ? t('replies.invalidShortcut') : t('replies.shortcutHint')}
        </p>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="personal-reply-body">{t('replies.fieldBody')}</Label>
        <Textarea
          id="personal-reply-body"
          rows={5}
          value={body}
          maxLength={MAX_REPLY_BODY}
          aria-invalid={touched && problems.body ? true : undefined}
          onChange={(event) => setBody(event.target.value)}
        />
        {touched && problems.body ? (
          <p className="text-xs text-destructive">{t('replies.invalidBody', { max: MAX_REPLY_BODY })}</p>
        ) : (
          <p className="text-xs text-muted-foreground">
            {t('replies.variables')}: {variables} · {t('replies.maskedNotice')}
          </p>
        )}
      </div>
      {secret ? (
        <p role="alert" className="text-row text-destructive">
          {t('replies.secretBlocked')}
        </p>
      ) : null}
      {save.error ? (
        <p role="alert" className="text-row text-destructive">
          {replyErrorText(save.error)}
        </p>
      ) : null}
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={save.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending || (touched && invalid)}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}

function ReplyRow({ reply, onEdit }: { reply: PersonalQuickReply; onEdit: () => void }) {
  const { t } = useTranslation()
  const remove = useDeleteMyQuickReply()
  const [confirming, setConfirming] = useState(false)
  const confirm = async () => {
    try {
      await remove.mutateAsync(reply.id)
      toast.success(t('replies.deleted'))
    } catch (error) {
      toast.error(replyErrorText(error))
      setConfirming(false)
    }
  }
  return (
    <li className="flex items-start gap-3 py-2.5">
      <div className="min-w-0 flex-1">
        <div className="flex min-w-0 items-center gap-2">
          <span className="shrink-0 font-mono text-xs text-muted-foreground">/{reply.shortcut}</span>
          <span className="truncate text-sm font-medium">{reply.title}</span>
        </div>
        <p className="line-clamp-2 text-xs text-muted-foreground">{reply.body}</p>
      </div>
      {confirming ? (
        <div
          className="flex shrink-0 items-center gap-1"
          role="group"
          aria-label={t('replies.confirmDelete')}
        >
          <span className="text-xs text-muted-foreground">{t('replies.confirmDelete')}</span>
          <Button size="xs" variant="ghost" disabled={remove.isPending} onClick={() => setConfirming(false)}>
            {t('app.cancel')}
          </Button>
          <Button size="xs" variant="destructive" disabled={remove.isPending} onClick={() => void confirm()}>
            {remove.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('replies.confirm')}
          </Button>
        </div>
      ) : (
        <div className="flex shrink-0 items-center gap-0.5">
          <Button
            size="icon-xs"
            variant="ghost"
            aria-label={t('replies.edit', { title: reply.title })}
            onClick={onEdit}
          >
            <PencilIcon />
          </Button>
          <Button
            size="icon-xs"
            variant="ghost"
            aria-label={t('replies.delete', { title: reply.title })}
            onClick={() => setConfirming(true)}
          >
            <Trash2Icon />
          </Button>
        </div>
      )}
    </li>
  )
}

export function PersonalRepliesDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation()
  const replies = useMyQuickReplies()
  const [editing, setEditing] = useState<{ reply: PersonalQuickReply | null; key: number } | null>(null)
  const items = replies.data ?? []
  const full = items.length >= MAX_PERSONAL_REPLIES
  const title = editing
    ? editing.reply
      ? t('replies.editTitle')
      : t('replies.newTitle')
    : t('replies.title')
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[560px]" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {editing ? (
              <Button
                size="icon-xs"
                variant="ghost"
                aria-label={t('replies.back')}
                onClick={() => setEditing(null)}
              >
                <ArrowLeftIcon />
              </Button>
            ) : null}
            {title}
          </DialogTitle>
        </DialogHeader>
        {editing ? (
          <ReplyForm key={editing.key} reply={editing.reply} onDone={() => setEditing(null)} />
        ) : (
          <div className="flex flex-col gap-3">
            <p className="text-row text-muted-foreground">{t('replies.description')}</p>
            <div className="flex items-center justify-between gap-3">
              <span className="tabular text-xs text-muted-foreground">
                {t('replies.count', { count: items.length, max: MAX_PERSONAL_REPLIES })}
              </span>
              <Button
                size="sm"
                disabled={full || replies.isPending}
                onClick={() => setEditing({ reply: null, key: Date.now() })}
              >
                <PlusIcon />
                {t('replies.add')}
              </Button>
            </div>
            {full ? (
              <p role="status" className="text-xs text-muted-foreground">
                {t('replies.limitReached', { max: MAX_PERSONAL_REPLIES })}
              </p>
            ) : null}
            {replies.isPending ? (
              <ListSkeleton rows={3} />
            ) : replies.isError ? (
              <ErrorState error={replies.error} onRetry={() => void replies.refetch()} />
            ) : items.length === 0 ? (
              <p className="border-t py-4 text-row text-muted-foreground">{t('replies.empty')}</p>
            ) : (
              <ul aria-label={t('replies.title')} className="max-h-[50vh] divide-y overflow-y-auto border-t">
                {items.map((reply) => (
                  <ReplyRow
                    key={reply.id}
                    reply={reply}
                    onEdit={() => setEditing({ reply, key: Date.now() })}
                  />
                ))}
              </ul>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}

export default PersonalRepliesDialog
