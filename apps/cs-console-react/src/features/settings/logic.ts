export type DayHours = { open: boolean; opens: string; closes: string }

export const weekdays = [1, 2, 3, 4, 5, 6, 7] as const

const opensPattern = /^([01]\d|2[0-3]):[0-5]\d$/
const closesPattern = /^(([01]\d|2[0-3]):[0-5]\d|24:00)$/

function readDay(value: unknown): DayHours {
  if (
    Array.isArray(value) &&
    value.length === 2 &&
    typeof value[0] === 'string' &&
    typeof value[1] === 'string'
  ) {
    return { open: true, opens: value[0], closes: value[1] }
  }
  return { open: false, opens: '08:00', closes: '17:00' }
}

export function readHours(value: unknown): Record<number, DayHours> {
  const source = typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
  return Object.fromEntries(weekdays.map((day) => [day, readDay(source[String(day)])]))
}

export function validDay(day: DayHours) {
  if (!day.open) return true
  const opens = day.opens.trim()
  const closes = day.closes.trim()
  return opensPattern.test(opens) && closesPattern.test(closes) && opens < closes
}

export function hoursValue(days: Record<number, DayHours>): Record<string, [string, string] | null> {
  return Object.fromEntries(
    weekdays.map((day) => {
      const hours = days[day]
      return [String(day), hours?.open ? [hours.opens.trim(), hours.closes.trim()] : null]
    }),
  )
}

export function placeholders(texts: string[]) {
  return [...new Set(texts.flatMap((text) => text.match(/\{[a-z_]+\}/g) ?? []))]
}

const csadminUrlPattern =
  /^https?:\/\/[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:\d{1,5})?(\/[A-Za-z0-9._~-]+)*\/?$/
const clientIdPattern = /^[A-Za-z0-9._-]{1,50}$/

export const validCsadminUrl = (url: string) => url.length <= 200 && csadminUrlPattern.test(url)

export const validClientId = (clientId: string) => clientIdPattern.test(clientId)

export const textSetting = (value: unknown) => (typeof value === 'string' ? value : '')

export function csadminConfigBlock(clientId: string, publicKey: string) {
  return [
    '#INTEGRATION (web CS gateway)',
    'integration {',
    `        client_id       = ${clientId}`,
    `        public_key      = ${publicKey}`,
    '        #DURATION IN MINUTES (1-60)',
    '        duration_token_minutes = 15',
    '}',
  ].join('\n')
}
