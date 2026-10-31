import { zodResolver } from '@hookform/resolvers/zod'
import { LoaderCircleIcon } from 'lucide-react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { StatusDot } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { useOnlineAgents } from '@/features/presence/hooks'

export type TicketAction = 'release' | 'transfer' | 'resolve' | 'reassign'

type Submit = {
  release: (reason: string) => Promise<unknown>
  transfer: (agentId: string, agentName: string, note: string) => Promise<unknown>
  resolve: (outcome: string, summary: string) => Promise<unknown>
  reassign: (agentId: string, agentName: string, reason: string) => Promise<unknown>
}

const reasonSchema = z.object({ text: z.string().trim().min(3, 'conversation.reasonRequired').max(300) })
const transferSchema = z.object({
  agent: z.string().min(1, 'conversation.pickAgent'),
  text: z.string().trim().min(3, 'conversation.transferNoteRequired').max(1000),
})
const resolveSchema = z.object({
  outcome: z.string().min(1),
  text: z.string().trim().min(5, 'conversation.summaryRequired').max(500, 'conversation.summaryRequired'),
})

function Pending({ busy, label }: { busy: boolean; label: string }) {
  return (
    <>
      {busy ? <LoaderCircleIcon className="animate-spin" /> : null}
      {label}
    </>
  )
}

function ReasonForm({
  hint,
  confirm,
  onSubmit,
  onCancel,
}: {
  hint: string
  confirm: string
  onSubmit: (text: string) => Promise<unknown>
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const form = useForm<z.infer<typeof reasonSchema>>({
    resolver: zodResolver(reasonSchema),
    defaultValues: { text: '' },
  })
  const error = form.formState.errors.text
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) => onSubmit(values.text.trim()))}
    >
      <DialogDescription>{hint}</DialogDescription>
      <div className="flex flex-col gap-2">
        <Label htmlFor="action-reason">{t('conversation.reasonLabel')}</Label>
        <Textarea
          id="action-reason"
          autoFocus
          maxLength={300}
          aria-invalid={error ? true : undefined}
          {...form.register('text')}
        />
        {error?.message ? (
          <p className="text-xs text-destructive">{t(error.message as 'conversation.reasonRequired')}</p>
        ) : null}
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={form.formState.isSubmitting}>
          <Pending busy={form.formState.isSubmitting} label={confirm} />
        </Button>
      </DialogFooter>
    </form>
  )
}

function AgentForm({
  hint,
  noteLabel,
  confirm,
  excludeSelf,
  onSubmit,
  onCancel,
}: {
  hint: string
  noteLabel: string
  confirm: string
  excludeSelf: boolean
  onSubmit: (agentId: string, agentName: string, text: string) => Promise<unknown>
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const me = useAgent()
  const agents = useOnlineAgents(true)
  const options = (agents.data ?? []).filter((agent) => !excludeSelf || agent.id !== me.id)
  const form = useForm<z.infer<typeof transferSchema>>({
    resolver: zodResolver(transferSchema),
    defaultValues: { agent: '', text: '' },
  })
  const errors = form.formState.errors
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) => {
        const target = options.find((agent) => agent.id === values.agent)
        return onSubmit(values.agent, target?.display_name ?? '', values.text.trim())
      })}
    >
      <DialogDescription>{hint}</DialogDescription>
      <div className="flex flex-col gap-2">
        <Label htmlFor="action-agent">{t('conversation.transferAgent')}</Label>
        <Controller
          control={form.control}
          name="agent"
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="action-agent" aria-invalid={errors.agent ? true : undefined}>
                <SelectValue placeholder={t('conversation.pickAgent')} />
              </SelectTrigger>
              <SelectContent>
                {options.map((agent) => (
                  <SelectItem key={agent.id} value={agent.id} disabled={excludeSelf && !agent.can_take}>
                    <StatusDot status={agent.status} />
                    {agent.display_name} ({agent.agent_code}) · {agent.active_tickets}/
                    {agent.max_active_tickets}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        {options.length === 0 && !agents.isPending ? (
          <p className="text-xs text-muted-foreground">{t('conversation.noOnlineAgents')}</p>
        ) : null}
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="action-note">{noteLabel}</Label>
        <Textarea
          id="action-note"
          maxLength={1000}
          aria-invalid={errors.text ? true : undefined}
          {...form.register('text')}
        />
        {errors.text?.message ? (
          <p className="text-xs text-destructive">
            {t(errors.text.message as 'conversation.transferNoteRequired')}
          </p>
        ) : null}
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={form.formState.isSubmitting}>
          <Pending busy={form.formState.isSubmitting} label={confirm} />
        </Button>
      </DialogFooter>
    </form>
  )
}

function ResolveForm({ onSubmit, onCancel }: { onSubmit: Submit['resolve']; onCancel: () => void }) {
  const { t, i18n } = useTranslation()
  const agent = useAgent()
  const outcomes = Object.entries(agent.settings.outcomes)
  const language = i18n.language === 'en' ? 'en' : 'id'
  const form = useForm<z.infer<typeof resolveSchema>>({
    resolver: zodResolver(resolveSchema),
    defaultValues: {
      outcome: outcomes.some(([code]) => code === 'answered') ? 'answered' : (outcomes[0]?.[0] ?? ''),
      text: '',
    },
  })
  const error = form.formState.errors.text
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) => onSubmit(values.outcome, values.text.trim()))}
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="resolve-outcome">{t('conversation.outcome')}</Label>
        <Controller
          control={form.control}
          name="outcome"
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="resolve-outcome">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {outcomes.map(([code, names]) => (
                  <SelectItem key={code} value={code}>
                    {names[language]}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="resolve-summary">{t('conversation.summary')}</Label>
        <Textarea
          id="resolve-summary"
          autoFocus
          maxLength={500}
          placeholder={t('conversation.summaryHint')}
          aria-invalid={error ? true : undefined}
          {...form.register('text')}
        />
        {error?.message ? (
          <p className="text-xs text-destructive">{t(error.message as 'conversation.summaryRequired')}</p>
        ) : null}
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={form.formState.isSubmitting}>
          <Pending busy={form.formState.isSubmitting} label={t('conversation.resolve')} />
        </Button>
      </DialogFooter>
    </form>
  )
}

export function ActionDialog({
  action,
  onClose,
  submit,
}: {
  action: TicketAction | null
  onClose: () => void
  submit: Submit
}) {
  const { t } = useTranslation()
  const titles: Record<TicketAction, string> = {
    release: t('conversation.releaseTitle'),
    transfer: t('conversation.transferTitle'),
    resolve: t('conversation.resolveTitle'),
    reassign: t('conversation.reassignTitle'),
  }
  const done = (promise: Promise<unknown>) => promise.then(onClose).catch(() => undefined)
  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{action ? titles[action] : ''}</DialogTitle>
        </DialogHeader>
        {action === 'release' ? (
          <ReasonForm
            hint={t('conversation.releaseHint')}
            confirm={t('conversation.release')}
            onCancel={onClose}
            onSubmit={(reason) => done(submit.release(reason))}
          />
        ) : null}
        {action === 'transfer' ? (
          <AgentForm
            hint={t('conversation.transferHint')}
            noteLabel={t('conversation.transferNote')}
            confirm={t('conversation.transfer')}
            excludeSelf
            onCancel={onClose}
            onSubmit={(agentId, name, note) => done(submit.transfer(agentId, name, note))}
          />
        ) : null}
        {action === 'reassign' ? (
          <AgentForm
            hint={t('conversation.reassignHint')}
            noteLabel={t('conversation.reasonLabel')}
            confirm={t('conversation.reassign')}
            excludeSelf={false}
            onCancel={onClose}
            onSubmit={(agentId, name, reason) => done(submit.reassign(agentId, name, reason))}
          />
        ) : null}
        {action === 'resolve' ? (
          <ResolveForm
            onCancel={onClose}
            onSubmit={(outcome, summary) => done(submit.resolve(outcome, summary))}
          />
        ) : null}
      </DialogContent>
    </Dialog>
  )
}
