import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery } from '@tanstack/react-query'
import { PlusIcon, Trash2Icon } from 'lucide-react'
import { useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { customerApi } from '@/features/customer/api'
import { customerKeys } from '@/features/customer/hooks'
import { formatRupiah } from '@/lib/time'
import { isHttpsUrl } from '@/lib/utils'

export type SpecialKind = 'card' | 'help' | 'options'

export type SpecialMessage = { kind: string; body: string; payload: Record<string, unknown> }

const cardSchema = z.object({
  card: z.enum(['order', 'cash_transaction']),
  ref: z.string().trim().min(1).max(64),
})
const helpSchema = z.object({
  title: z.string().trim().min(2).max(200),
  url: z.string().trim().refine(isHttpsUrl, 'composer.helpUrlInvalid'),
})
const optionsSchema = z.object({
  question: z.string().trim().min(2).max(500),
  options: z
    .array(z.object({ value: z.string().trim().min(1).max(60) }))
    .min(2)
    .max(4),
})

function CardForm({ ticketId, onSend }: { ticketId: string; onSend: (message: SpecialMessage) => void }) {
  const { t } = useTranslation()
  const form = useForm<z.infer<typeof cardSchema>>({
    resolver: zodResolver(cardSchema),
    defaultValues: { card: 'order', ref: '' },
  })
  const card = form.watch('card')
  const orders = useQuery({
    queryKey: customerKeys.orders(ticketId),
    queryFn: () => customerApi.orders(ticketId),
    enabled: card === 'order',
    retry: false,
  })
  const cash = useQuery({
    queryKey: customerKeys.cash(ticketId),
    queryFn: () => customerApi.cash(ticketId),
    enabled: card === 'cash_transaction',
    retry: false,
  })
  const picks =
    card === 'order'
      ? (orders.data ?? []).map((order) => ({
          ref: order.order_id,
          label: `${order.order_id} · ${order.code ?? ''} ${order.side ?? ''} · ${order.status ?? ''}`,
        }))
      : (cash.data ?? []).map((item) => ({
          ref: item.id,
          label: `${item.id} · ${item.kind ?? ''} ${item.amount !== undefined ? formatRupiah(item.amount) : ''}`,
        }))
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) =>
        onSend({ kind: 'card', body: '', payload: { card: values.card, ref: values.ref.trim() } }),
      )}
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="card-kind">{t('composer.cardKind')}</Label>
        <Select
          value={card}
          onValueChange={(value) => form.setValue('card', value as 'order' | 'cash_transaction')}
        >
          <SelectTrigger id="card-kind">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="order">{t('conversation.cardOrder')}</SelectItem>
            <SelectItem value="cash_transaction">{t('conversation.cardCash')}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      {picks.length > 0 ? (
        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium text-muted-foreground">{t('composer.pickFromOlt')}</p>
          {picks.map((pick) => (
            <button
              key={pick.ref}
              type="button"
              className="truncate rounded-md border px-2 py-1.5 text-left text-xs hover:bg-accent"
              onClick={() => form.setValue('ref', pick.ref, { shouldValidate: true })}
            >
              {pick.label}
            </button>
          ))}
        </div>
      ) : null}
      <div className="flex flex-col gap-2">
        <Label htmlFor="card-ref">{t('composer.cardRef')}</Label>
        <Input
          id="card-ref"
          autoComplete="off"
          aria-invalid={form.formState.errors.ref ? true : undefined}
          {...form.register('ref')}
        />
      </div>
      <DialogFooter>
        <Button type="submit">{t('composer.send')}</Button>
      </DialogFooter>
    </form>
  )
}

function HelpForm({ onSend }: { onSend: (message: SpecialMessage) => void }) {
  const { t } = useTranslation()
  const form = useForm<z.infer<typeof helpSchema>>({
    resolver: zodResolver(helpSchema),
    defaultValues: { title: '', url: 'https://' },
  })
  const errors = form.formState.errors
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) =>
        onSend({ kind: 'help_link', body: values.title.trim(), payload: { url: values.url.trim() } }),
      )}
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="help-title">{t('composer.helpLinkTitle')}</Label>
        <Input id="help-title" aria-invalid={errors.title ? true : undefined} {...form.register('title')} />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="help-url">{t('composer.helpUrl')}</Label>
        <Input
          id="help-url"
          type="url"
          aria-invalid={errors.url ? true : undefined}
          {...form.register('url')}
        />
        {errors.url ? <p className="text-xs text-destructive">{t('composer.helpUrlInvalid')}</p> : null}
      </div>
      <DialogFooter>
        <Button type="submit">{t('composer.send')}</Button>
      </DialogFooter>
    </form>
  )
}

function OptionsForm({ onSend }: { onSend: (message: SpecialMessage) => void }) {
  const { t } = useTranslation()
  const form = useForm<z.infer<typeof optionsSchema>>({
    resolver: zodResolver(optionsSchema),
    defaultValues: { question: '', options: [{ value: '' }, { value: '' }] },
  })
  const options = useFieldArray({ control: form.control, name: 'options' })
  const invalid = Object.keys(form.formState.errors).length > 0
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) =>
        onSend({
          kind: 'quick_reply',
          body: values.question.trim(),
          payload: { options: values.options.map((option) => option.value.trim()) },
        }),
      )}
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="options-question">{t('composer.question')}</Label>
        <Input id="options-question" {...form.register('question')} />
      </div>
      {options.fields.map((field, index) => (
        <div key={field.id} className="flex items-center gap-2">
          <Input
            aria-label={t('composer.option', { n: index + 1 })}
            placeholder={t('composer.option', { n: index + 1 })}
            {...form.register(`options.${index}.value`)}
          />
          {options.fields.length > 2 ? (
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              aria-label={t('app.delete')}
              onClick={() => options.remove(index)}
            >
              <Trash2Icon />
            </Button>
          ) : null}
        </div>
      ))}
      {options.fields.length < 4 ? (
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="self-start"
          onClick={() => options.append({ value: '' })}
        >
          <PlusIcon />
          {t('composer.addOption')}
        </Button>
      ) : null}
      {invalid ? <p className="text-xs text-destructive">{t('composer.optionsInvalid')}</p> : null}
      <DialogFooter>
        <Button type="submit">{t('composer.send')}</Button>
      </DialogFooter>
    </form>
  )
}

export function SpecialMessageDialog({
  kind,
  ticketId,
  onClose,
  onSend,
}: {
  kind: SpecialKind | null
  ticketId: string
  onClose: () => void
  onSend: (message: SpecialMessage) => void
}) {
  const { t } = useTranslation()
  const title =
    kind === 'card'
      ? t('composer.cardTitle')
      : kind === 'help'
        ? t('composer.helpTitle')
        : t('composer.optionsTitle')
  return (
    <Dialog open={kind !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        {kind === 'card' ? <CardForm ticketId={ticketId} onSend={onSend} /> : null}
        {kind === 'help' ? <HelpForm onSend={onSend} /> : null}
        {kind === 'options' ? <OptionsForm onSend={onSend} /> : null}
      </DialogContent>
    </Dialog>
  )
}
