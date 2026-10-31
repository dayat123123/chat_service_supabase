import { zodResolver } from '@hookform/resolvers/zod'
import { LoaderCircleIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { PriorityText } from '@/components/badges'
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
import { ticketPriorities } from '@/features/tickets/types'

import { useAdminOptions, useSaveTopic, useTopicConfigs } from '../hooks'
import type { TopicConfig } from '../types'
import { ActiveBadge, FieldMessage, FormError, QueryContent, SectionFrame } from './settings-ui'

type Message =
  'settings.invalidTopicCode' | 'settings.invalidName' | 'settings.requiredField' | 'settings.helpUrlHint'

const topicSchema = z.object({
  code: z
    .string()
    .trim()
    .regex(/^[a-z][a-z0-9_]{1,31}$/, 'settings.invalidTopicCode'),
  name_id: z.string().trim().min(2, 'settings.invalidName').max(40, 'settings.invalidName'),
  name_en: z.string().trim().min(2, 'settings.invalidName').max(40, 'settings.invalidName'),
  skill: z.string().min(1, 'settings.requiredField'),
  default_priority: z.enum(ticketPriorities),
  help_url: z
    .string()
    .trim()
    .refine(
      (value) => value === '' || /^https:\/\/[A-Za-z0-9.-]+(\/\S*)?$/.test(value),
      'settings.helpUrlHint',
    ),
  sort_order: z
    .string()
    .trim()
    .refine((value) => /^\d{1,3}$/.test(value)),
  active: z.boolean(),
})

type TopicForm = z.infer<typeof topicSchema>

function TopicDialog({ topic, onClose }: { topic: TopicConfig | null; onClose: () => void }) {
  const { t } = useTranslation()
  const options = useAdminOptions()
  const save = useSaveTopic()
  const editing = topic !== null
  const skills = options.data?.skills ?? []
  const form = useForm<TopicForm>({
    resolver: zodResolver(topicSchema),
    defaultValues: {
      code: topic?.code ?? '',
      name_id: topic?.name_id ?? '',
      name_en: topic?.name_en ?? '',
      skill: topic?.skill ?? 'general',
      default_priority: ticketPriorities.find((priority) => priority === topic?.default_priority) ?? 'P3',
      help_url: topic?.help_url ?? '',
      sort_order: String(topic?.sort_order ?? 100),
      active: topic?.active ?? true,
    },
  })
  const errors = form.formState.errors
  const message = (value?: string) => (value ? t(value as Message) : undefined)

  const submit = form.handleSubmit(async (values) => {
    try {
      await save.mutateAsync({
        code: values.code.trim(),
        name_id: values.name_id.trim(),
        name_en: values.name_en.trim(),
        skill: values.skill,
        default_priority: values.default_priority,
        help_url: values.help_url.trim() || null,
        sort_order: Number(values.sort_order),
        active: values.active,
      })
      onClose()
    } catch {
      return
    }
  })

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>
            {editing ? t('settings.editTopicTitle', { name: topic.name_id }) : t('settings.addTopic')}
          </DialogTitle>
        </DialogHeader>
        <form className="flex flex-col gap-4" onSubmit={(event) => void submit(event)} noValidate>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="topic-code">{t('settings.topicCode')}</Label>
            <Input
              id="topic-code"
              disabled={editing}
              autoFocus={!editing}
              maxLength={32}
              aria-invalid={errors.code ? true : undefined}
              {...form.register('code')}
            />
            <FieldMessage error={message(errors.code?.message)} hint={t('settings.topicCodeHint')} />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="topic-name-id">{t('settings.topicNameId')}</Label>
              <Input
                id="topic-name-id"
                maxLength={40}
                autoFocus={editing}
                aria-invalid={errors.name_id ? true : undefined}
                {...form.register('name_id')}
              />
              <FieldMessage error={message(errors.name_id?.message)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="topic-name-en">{t('settings.topicNameEn')}</Label>
              <Input
                id="topic-name-en"
                maxLength={40}
                aria-invalid={errors.name_en ? true : undefined}
                {...form.register('name_en')}
              />
              <FieldMessage error={message(errors.name_en?.message)} />
            </div>
          </div>
          <div className="grid grid-cols-[1fr_auto] gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="topic-skill">{t('settings.topicSkill')}</Label>
              <Controller
                control={form.control}
                name="skill"
                render={({ field }) => (
                  <Select
                    value={skills.some((skill) => skill.code === field.value) ? field.value : undefined}
                    onValueChange={field.onChange}
                  >
                    <SelectTrigger id="topic-skill" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {skills.map((skill) => (
                        <SelectItem key={skill.code} value={skill.code}>
                          {skill.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </div>
            <div className="flex w-36 flex-col gap-1.5">
              <Label htmlFor="topic-priority">{t('settings.defaultPriority')}</Label>
              <Controller
                control={form.control}
                name="default_priority"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger id="topic-priority" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {ticketPriorities.map((priority) => (
                        <SelectItem key={priority} value={priority}>
                          {priority}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="topic-help">{t('settings.helpUrl')}</Label>
            <Input
              id="topic-help"
              type="url"
              inputMode="url"
              placeholder="https://"
              aria-invalid={errors.help_url ? true : undefined}
              {...form.register('help_url')}
            />
            <FieldMessage error={message(errors.help_url?.message)} hint={t('settings.helpUrlHint')} />
          </div>
          <div className="grid grid-cols-[auto_1fr] items-end gap-4">
            <div className="flex w-40 flex-col gap-1.5">
              <Label htmlFor="topic-sort">{t('settings.sortOrder')}</Label>
              <Input
                id="topic-sort"
                inputMode="numeric"
                maxLength={3}
                aria-invalid={errors.sort_order ? true : undefined}
                {...form.register('sort_order')}
              />
            </div>
            <Controller
              control={form.control}
              name="active"
              render={({ field }) => (
                <label className="flex h-9 items-center justify-between gap-3 text-sm font-medium">
                  {t('settings.topicActive')}
                  <Switch checked={field.value} onCheckedChange={field.onChange} />
                </label>
              )}
            />
          </div>
          <FieldMessage
            error={errors.sort_order ? t('settings.numberRange', { min: 0, max: 999 }) : undefined}
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

export function TopicsSection() {
  const { t } = useTranslation()
  const topics = useTopicConfigs()
  const options = useAdminOptions()
  const [editing, setEditing] = useState<{ topic: TopicConfig | null; key: number } | null>(null)
  const skillName = (code: string) => options.data?.skills.find((skill) => skill.code === code)?.name ?? code
  return (
    <SectionFrame
      title={t('settings.topics')}
      description={t('settings.topicsDescription')}
      action={
        <Button onClick={() => setEditing({ topic: null, key: Date.now() })}>
          <PlusIcon />
          {t('settings.addTopic')}
        </Button>
      }
    >
      <QueryContent query={topics}>
        {(items) => (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="text-right">{t('settings.colOrder')}</TableHead>
                <TableHead>{t('settings.colCode')}</TableHead>
                <TableHead>{t('settings.colName')}</TableHead>
                <TableHead>{t('settings.colSkill')}</TableHead>
                <TableHead>{t('settings.colDefaultPriority')}</TableHead>
                <TableHead>{t('settings.colHelpLink')}</TableHead>
                <TableHead>{t('settings.colStatus')}</TableHead>
                <TableHead>
                  <span className="sr-only">{t('app.edit')}</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {items.map((topic) => (
                <TableRow key={topic.code}>
                  <TableCell className="tabular text-right">{topic.sort_order}</TableCell>
                  <TableCell className="font-mono text-xs">{topic.code}</TableCell>
                  <TableCell>
                    {topic.name_id} <span className="text-muted-foreground">/ {topic.name_en}</span>
                  </TableCell>
                  <TableCell>{skillName(topic.skill)}</TableCell>
                  <TableCell>
                    <PriorityText priority={topic.default_priority} />
                  </TableCell>
                  <TableCell className="max-w-56 truncate" title={topic.help_url ?? undefined}>
                    {topic.help_url ?? '–'}
                  </TableCell>
                  <TableCell>
                    <ActiveBadge active={topic.active} />
                  </TableCell>
                  <TableCell className="text-right">
                    <Button variant="ghost" size="xs" onClick={() => setEditing({ topic, key: Date.now() })}>
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
        <TopicDialog key={editing.key} topic={editing.topic} onClose={() => setEditing(null)} />
      ) : null}
    </SectionFrame>
  )
}
