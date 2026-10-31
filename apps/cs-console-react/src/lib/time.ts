import { differenceInMinutes, format as formatLocal, isSameDay, parseISO, subDays } from 'date-fns'
import { formatInTimeZone, toZonedTime } from 'date-fns-tz'
import { enUS, id as idLocale } from 'date-fns/locale'

import i18n from '@/i18n'

export const TIME_ZONE = 'Asia/Jakarta'

const JAKARTA_OFFSET_MS = 7 * 60 * 60 * 1000

export function jakartaDay(value: string | Date) {
  const time = typeof value === 'string' ? Date.parse(value) : value.getTime()
  return new Date(time + JAKARTA_OFFSET_MS).toISOString().slice(0, 10)
}

const locale = () => (i18n.language === 'en' ? enUS : idLocale)

export function toDate(value: string | Date) {
  return typeof value === 'string' ? new Date(value) : value
}

export function zoned(value: string | Date) {
  return toZonedTime(toDate(value), TIME_ZONE)
}

export function format(value: string | Date, pattern: string) {
  return formatInTimeZone(toDate(value), TIME_ZONE, pattern, { locale: locale() })
}

export function clock(value: string | Date) {
  return format(value, 'HH.mm')
}

export function sameZonedDay(a: string | Date, b: string | Date) {
  return isSameDay(zoned(a), zoned(b))
}

export function stamp(value: string | Date, now: Date = new Date()) {
  if (sameZonedDay(value, now)) return clock(value)
  const sameYear = format(value, 'yyyy') === format(now, 'yyyy')
  return format(value, sameYear ? 'd MMM, HH.mm' : 'd MMM yyyy, HH.mm')
}

export function shortDate(value: string | Date) {
  return format(value, 'd MMM yyyy')
}

export function dayLabel(value: string | Date, now: Date = new Date()) {
  if (sameZonedDay(value, now)) return i18n.t('time.today')
  if (sameZonedDay(value, subDays(now, 1))) return i18n.t('time.yesterday')
  return format(value, 'd MMM yyyy')
}

export function minutesSince(value: string | Date | null | undefined, now: Date = new Date()) {
  if (!value) return 0
  return Math.max(0, differenceInMinutes(now, toDate(value)))
}

export function waitLabel(minutes: number) {
  if (minutes < 1) return '<1m'
  if (minutes < 60) return `${minutes}m`
  if (minutes < 1440) return `${Math.floor(minutes / 60)}j ${minutes % 60}m`
  return `${Math.floor(minutes / 1440)}h ${Math.floor((minutes % 1440) / 60)}j`
}

export function minutesLabel(minutes: number | null | undefined) {
  if (minutes === null || minutes === undefined) return '–'
  if (minutes < 1) return `<1 ${i18n.t('time.minuteShort')}`
  if (minutes < 60)
    return `${new Intl.NumberFormat(i18n.language, { maximumFractionDigits: 1 }).format(minutes)} ${i18n.t('time.minuteShort')}`
  const total = Math.round(minutes)
  return `${Math.floor(total / 60)} ${i18n.t('time.hourShort')} ${total % 60} ${i18n.t('time.minuteShort')}`
}

export function todayInJakarta(now: Date = new Date()) {
  const z = zoned(now)
  return new Date(z.getFullYear(), z.getMonth(), z.getDate())
}

export function isoDay(date: Date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

export function formatDay(day: string, pattern: string) {
  return formatLocal(parseISO(day), pattern, { locale: locale() })
}

const numberLocale = () => (i18n.language === 'en' ? 'en-US' : 'id-ID')

export function formatNumber(value: number) {
  return new Intl.NumberFormat(numberLocale()).format(value)
}

export function formatRating(value: number | null | undefined) {
  if (value === null || value === undefined) return '–'
  return new Intl.NumberFormat(numberLocale(), { minimumFractionDigits: 1, maximumFractionDigits: 2 }).format(
    value,
  )
}

export function formatRupiah(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value)
}
