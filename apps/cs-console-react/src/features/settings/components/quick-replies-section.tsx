import { zodResolver } from '@hookform/resolvers/zod'
import { LoaderCircleIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { stamp } from '@/lib/time'

import { useQuickReplyConfigs, useSaveQuickReply } from '../hooks'
import type { QuickReplyConfig } from '../types'
import { ActiveBadge, FieldMessage, FormError, QueryContent, SectionFrame } from './settings-ui'

const quickReplyVariables = '{nama}, {nomor_tiket}, {nama_cs}'

type Message = 'settings.invalidShortcut' | 'settings.requiredField'

const replySchema = z.object({
  shortcut: z
    .string()
    .trim()
    .regex(/^[a-z0-9_-]{2,32}$/, 'settings.invalidShortcut'),
  title: z.string().trim().min(1, 'settings.requiredField').max(80, 'settings.requiredField'),
  body: z.string().trim().min(1, 'settings.requiredField').max(2000, 'settings.requiredField'),
  language: z.enum(['id', 'en']),
  active: z.boolean(),
})

type ReplyForm = z.infer<typeof replySchema>

function ReplyDialog({ reply, onClose }: { reply: QuickReplyConfig | null; onClose: () => void }) {
  const { t } = useTranslation()
  const save = useSaveQuickReply()
  const form = useForm<ReplyForm>({
    resolver: zodResolver(replySchema),
    defaultValues: {
      shortcut: reply?.shortcut ?? '',
      title: reply?.title ?? '',
      body: reply?.body ?? '',
      language: reply?.language === 'en' ? 'en' : 'id',
      active: reply?.active ?? true,
    },
  })
  const errors = form.formState.errors
  const message = (value?: string) => (value ? t(value as Message) : undefined)

  const submit = form.handleSubmit(async (values) => {
    try {
      await save.mutateAsync({
        id: reply?.id ?? null,
        shortcut: values.shortcut.trim(),
        title: values.title.trim(),
        body: values.body.trim(),
        language: values.language,
        active: values.active,
      })
      onClose()
    } catch {
      return
    }
  })

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[520px]" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{reply ? t('settings.editQuickReplyTitle') : t('settings.addQuickReply')}</DialogTitle>
        </DialogHeader>
        <form className="flex flex-col gap-4" onSubmit={(event) => void submit(event)} noValidate>
          <div className="grid grid-cols-[1fr_auto] gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="reply-shortcut">{t('settings.shortcut')}</Label>
              <div className="flex items-center rounded-md border bg-background transition-[border-color,box-shadow] focus-within:border-ring/60 focus-within:ring-2 focus-within:ring-ring/15">
                <span className="pl-3 text-sm text-muted-foreground" aria-hidden="true">
                  /
                </span>
                <Input
                  id="reply-shortcut"
                  autoFocus
                  maxLength={32}
                  className="border-0 pl-1 focus-visible:ring-0"
                  aria-invalid={errors.shortcut ? true : undefined}
                  {...form.register('shortcut')}
                />
              </div>
              <FieldMessage error={message(errors.shortcut?.message)} hint={t('settings.shortcutHint')} />
            </div>
            <div className="flex w-36 flex-col gap-1.5">
              <Label htmlFor="reply-language">{t('settings.language')}</Label>
              <Controller
                control={form.control}
                name="language"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger id="reply-language" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="id">{t('settings.languageId')}</SelectItem>
                      <SelectItem value="en">{t('settings.languageEn')}</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="reply-title">{t('settings.replyTitle')}</Label>
            <Input
              id="reply-title"
              maxLength={80}
              aria-invalid={errors.title ? true : undefined}
              {...form.register('title')}
            />
            <FieldMessage error={message(errors.title?.message)} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="reply-body">{t('settings.replyBody')}</Label>
            <Textarea
              id="reply-body"
              rows={6}
              maxLength={2000}
              aria-invalid={errors.body ? true : undefined}
              {...form.register('body')}
            />
            <FieldMessage
              error={message(errors.body?.message)}
              hint={`${t('settings.variables')}: ${quickReplyVariables}`}
            />
          </div>
          <Controller
            control={form.control}
            name="active"
            render={({ field }) => (
              <label className="flex items-center justify-between gap-3 text-sm font-medium">
                {t('app.active')}
                <Switch checked={field.value} onCheckedChange={field.onChange} />
              </label>
            )}
          />
          <FormError error={save.error} />
          <DialogFooter>
            <Button type="button" variant="ghost" disabled={save.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('app.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export function QuickRepliesSection() {
  const { t } = useTranslation()
  const replies = useQuickReplyConfigs()
  const [editing, setEditing] = useState<{ reply: QuickReplyConfig | null; key: number } | null>(null)
  return (
    <SectionFrame
      title={t('settings.quickReplies')}
      description={t('settings.quickRepliesDescription')}
      action={
        <Button onClick={() => setEditing({ reply: null, key: Date.now() })}>
          <PlusIcon />
          {t('settings.addQuickReply')}
        </Button>
      }
    >
      <QueryContent query={replies}>
        {(items) => (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('settings.colShortcut')}</TableHead>
                <TableHead>{t('settings.colTitle')}</TableHead>
                <TableHead>{t('settings.colBody')}</TableHead>
                <TableHead>{t('settings.colLanguage')}</TableHead>
                <TableHead>{t('settings.colStatus')}</TableHead>
                <TableHead>{t('settings.colUpdated')}</TableHead>
                <TableHead>
                  <span className="sr-only">{t('app.edit')}</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {items.map((reply) => (
                <TableRow key={reply.id ?? `${reply.language}-${reply.shortcut}`}>
                  <TableCell className="font-semibold">/{reply.shortcut}</TableCell>
                  <TableCell>{reply.title}</TableCell>
                  <TableCell className="max-w-md whitespace-normal">
                    <span className="line-clamp-2 text-muted-foreground">{reply.body}</span>
                  </TableCell>
                  <TableCell>
                    {reply.language === 'en' ? t('settings.languageEn') : t('settings.languageId')}
                  </TableCell>
                  <TableCell>
                    <ActiveBadge active={reply.active} />
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {reply.updated_at ? stamp(reply.updated_at) : '–'}
                  </TableCell>
                  <TableCell className="text-right">
                    <Button variant="ghost" size="xs" onClick={() => setEditing({ reply, key: Date.now() })}>
                      {t('app.edit')}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </QueryContent>
      {editing ? (
        <ReplyDialog key={editing.key} reply={editing.reply} onClose={() => setEditing(null)} />
      ) : null}
    </SectionFrame>
  )
}
