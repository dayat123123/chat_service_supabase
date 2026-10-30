import { format as formatLocal } from 'date-fns'
import { enUS, id as idLocale } from 'date-fns/locale'
import { ChevronLeftIcon, ChevronRightIcon, LoaderCircleIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@/components/ui/controls'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatDay, todayInJakarta } from '@/lib/time'
import { cn } from '@/lib/utils'

import {
  findSetting,
  useDeleteHoliday,
  useHolidays,
  useSaveHoliday,
  useSaveSettings,
  useSettingEntries,
} from '../hooks'
import { hoursValue, readHours, validDay, weekdays, type DayHours } from '../logic'
import { holidayKinds, type Holiday, type HolidayKind, type SettingEntry } from '../types'
import { ChangedBy, FieldMessage, FormError, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

function weekdayName(day: number, language: string) {
  return formatLocal(new Date(2024, 0, day), 'EEEE', { locale: language === 'en' ? enUS : idLocale })
}

function ServiceHours({ entry }: { entry: SettingEntry }) {
  const { t, i18n } = useTranslation()
  const save = useSaveSettings()
  const [days, setDays] = useState(() => readHours(entry.value))
  const [showErrors, setShowErrors] = useState(false)
  const update = (day: number, patch: Partial<DayHours>) =>
    setDays((current) => ({ ...current, [day]: { ...(current[day] as DayHours), ...patch } }))

  const submit = () => {
    setShowErrors(true)
    if (weekdays.some((day) => !validDay(days[day] as DayHours))) return
    save.mutate({ 'service.hours': hoursValue(days) })
  }

  return (
    <SettingsCard title={t('settings.serviceHours')}>
      <div className="flex flex-col divide-y">
        {weekdays.map((day) => {
          const hours = days[day] as DayHours
          const name = weekdayName(day, i18n.language)
          const invalid = showErrors && !validDay(hours)
          return (
            <div key={day} className="flex flex-wrap items-center gap-x-4 gap-y-2 py-2">
              <span className="w-24 text-sm font-medium capitalize">{name}</span>
              <label className="flex w-28 items-center gap-2 text-sm">
                <Switch
                  checked={hours.open}
                  aria-label={`${name}: ${hours.open ? t('settings.dayOpen') : t('settings.dayClosed')}`}
                  onCheckedChange={(open) => update(day, { open })}
                />
                {hours.open ? t('settings.dayOpen') : t('settings.dayClosed')}
              </label>
              {hours.open ? (
                <div className="flex items-center gap-2">
                  <Input
                    aria-label={`${name} ${t('settings.opensAt')}`}
                    className="tabular w-20 text-center"
                    inputMode="numeric"
                    maxLength={5}
                    placeholder="HH:MM"
                    value={hours.opens}
                    aria-invalid={invalid ? true : undefined}
                    onChange={(event) => update(day, { opens: event.target.value })}
                  />
                  <span aria-hidden="true">–</span>
                  <Input
                    aria-label={`${name} ${t('settings.closesAt')}`}
                    className="tabular w-20 text-center"
                    inputMode="numeric"
                    maxLength={5}
                    placeholder="HH:MM"
                    value={hours.closes}
                    aria-invalid={invalid ? true : undefined}
                    onChange={(event) => update(day, { closes: event.target.value })}
                  />
                </div>
              ) : null}
              {invalid ? <p className="text-xs text-destructive">{t('settings.hoursInvalid')}</p> : null}
            </div>
          )
        })}
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button disabled={save.isPending} onClick={submit}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('settings.saveHours')}
        </Button>
        <ChangedBy entry={entry} />
      </div>
    </SettingsCard>
  )
}

function HolidayDialog({ year, onClose }: { year: number; onClose: () => void }) {
  const { t } = useTranslation()
  const save = useSaveHoliday(year)
  const [day, setDay] = useState('')
  const [name, setName] = useState('')
  const [kind, setKind] = useState<HolidayKind>('national')
  const [touched, setTouched] = useState(false)
  const dayValid = day.startsWith(`${year}-`) && /^\d{4}-\d{2}-\d{2}$/.test(day)
  const nameValid = name.trim().length >= 2 && name.trim().length <= 120

  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    setTouched(true)
    if (!dayValid || !nameValid) return
    save.mutate({ day, name: name.trim(), kind }, { onSuccess: onClose })
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{t('settings.addHoliday')}</DialogTitle>
        </DialogHeader>
        <form className="flex flex-col gap-4" onSubmit={submit} noValidate>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="holiday-day">{t('settings.holidayDate')}</Label>
            <Input
              id="holiday-day"
              type="date"
              autoFocus
              min={`${year}-01-01`}
              max={`${year}-12-31`}
              value={day}
              aria-invalid={touched && !dayValid ? true : undefined}
              onChange={(event) => setDay(event.target.value)}
            />
            <FieldMessage
              error={touched && !dayValid ? t('settings.holidayDateRequired', { year }) : undefined}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="holiday-name">{t('settings.holidayName')}</Label>
            <Input
              id="holiday-name"
              maxLength={120}
              value={name}
              aria-invalid={touched && !nameValid ? true : undefined}
              onChange={(event) => setName(event.target.value)}
            />
            <FieldMessage error={touched && !nameValid ? t('settings.invalidHolidayName') : undefined} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="holiday-kind">{t('settings.holidayKind')}</Label>
            <Select value={kind} onValueChange={(value) => setKind(value as HolidayKind)}>
              <SelectTrigger id="holiday-kind" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {holidayKinds.map((item) => (
                  <SelectItem key={item} value={item}>
                    {t(`settings.holidayKinds.${item}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <FormError error={save.error} />
          <DialogFooter>
            <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
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

function Holidays() {
  const { t } = useTranslation()
  const [year, setYear] = useState(() => todayInJakarta().getFullYear())
  const holidays = useHolidays(year)
  const remove = useDeleteHoliday(year)
  const [adding, setAdding] = useState(false)
  const [deleting, setDeleting] = useState<Holiday | null>(null)
  return (
    <SettingsCard title={t('settings.holidaysTitle', { year })} subtitle={t('settings.holidaysHint')}>
      <div className="flex flex-wrap items-center gap-2">
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label={t('settings.previousYear')}
          onClick={() => setYear(year - 1)}
        >
          <ChevronLeftIcon />
        </Button>
        <span className="tabular text-sm font-semibold">{year}</span>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label={t('settings.nextYear')}
          onClick={() => setYear(year + 1)}
        >
          <ChevronRightIcon />
        </Button>
        <Button variant="outline" size="sm" className="ml-auto" onClick={() => setAdding(true)}>
          <PlusIcon />
          {t('settings.addHoliday')}
        </Button>
      </div>
      <QueryContent query={holidays}>
        {(items) =>
          items.length === 0 ? (
            <p className="py-2 text-sm text-muted-foreground">{t('settings.noHolidays')}</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('settings.holidayDate')}</TableHead>
                  <TableHead>{t('settings.holidayName')}</TableHead>
                  <TableHead>{t('settings.holidayKind')}</TableHead>
                  <TableHead>
                    <span className="sr-only">{t('app.delete')}</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((holiday) => (
                  <TableRow key={holiday.day}>
                    <TableCell className="tabular">{formatDay(holiday.day, 'EEE, d MMM yyyy')}</TableCell>
                    <TableCell className="whitespace-normal">{holiday.name}</TableCell>
                    <TableCell>
                      <span
                        className={cn(
                          'inline-flex h-5 items-center rounded-full px-2 text-[11px] font-semibold',
                          holiday.kind === 'exchange'
                            ? 'bg-accent text-accent-foreground'
                            : 'bg-sla-warn/14 text-sla-warn',
                        )}
                      >
                        {holidayKinds.includes(holiday.kind)
                          ? t(`settings.holidayKinds.${holiday.kind}`)
                          : holiday.kind}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant="ghost"
                        size="icon-xs"
                        aria-label={`${t('app.delete')} ${holiday.name}`}
                        onClick={() => setDeleting(holiday)}
                      >
                        <Trash2Icon />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )
        }
      </QueryContent>
      {adding ? <HolidayDialog year={year} onClose={() => setAdding(false)} /> : null}
      <AlertDialog open={deleting !== null} onOpenChange={(open) => !open && setDeleting(null)}>
        <AlertDialogContent className="sm:max-w-md">
          <AlertDialogTitle>{t('settings.deleteHolidayTitle')}</AlertDialogTitle>
          <AlertDialogDescription>
            {deleting
              ? t('settings.deleteHolidayBody', {
                  name: deleting.name,
                  date: formatDay(deleting.day, 'd MMM yyyy'),
                })
              : null}
          </AlertDialogDescription>
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <AlertDialogCancel>{t('app.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                if (deleting) remove.mutate(deleting.day)
              }}
            >
              {t('app.delete')}
            </AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialog>
    </SettingsCard>
  )
}

export function HoursSection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  return (
    <SectionFrame title={t('settings.hours')} description={t('settings.hoursDescription')}>
      <QueryContent query={settings}>
        {(items) => {
          const entry = findSetting(items, 'service.hours')
          return entry ? <ServiceHours key={entry.version} entry={entry} /> : null
        }}
      </QueryContent>
      <Holidays />
    </SectionFrame>
  )
}
