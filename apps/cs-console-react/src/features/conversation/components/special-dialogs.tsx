import { zodResolver } from '@hookform/resolvers/zod'
import { PlusIcon, Trash2Icon } from 'lucide-react'
import { useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { isHttpsUrl } from '@/lib/utils'

import type { SendKind } from '../types'

export type SpecialKind = 'help' | 'options'

export type SpecialMessage = { kind: SendKind; body: string; payload: Record<string, unknown> }

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
  onClose,
  onSend,
}: {
  kind: SpecialKind | null
  onClose: () => void
  onSend: (message: SpecialMessage) => void
}) {
  const { t } = useTranslation()
  const title = kind === 'help' ? t('composer.helpTitle') : t('composer.optionsTitle')
  return (
    <Dialog open={kind !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        {kind === 'help' ? <HelpForm onSend={onSend} /> : null}
        {kind === 'options' ? <OptionsForm onSend={onSend} /> : null}
      </DialogContent>
    </Dialog>
  )
}
