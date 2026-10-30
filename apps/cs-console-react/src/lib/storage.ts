export const PREFIX = 'cs-console.'

export function readLocal(key: string): string | null {
  try {
    return window.localStorage.getItem(PREFIX + key)
  } catch {
    return null
  }
}

export function writeLocal(key: string, value: string | null) {
  try {
    if (value === null) window.localStorage.removeItem(PREFIX + key)
    else window.localStorage.setItem(PREFIX + key, value)
  } catch {
    return
  }
}

export function readJson<T>(key: string, fallback: T): T {
  const raw = readLocal(key)
  if (raw === null) return fallback
  try {
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function writeJson(key: string, value: unknown) {
  writeLocal(key, JSON.stringify(value))
}

export function removeLocalPrefix(prefix: string) {
  try {
    const keys: string[] = []
    for (let i = 0; i < window.localStorage.length; i += 1) {
      const key = window.localStorage.key(i)
      if (key?.startsWith(PREFIX + prefix)) keys.push(key)
    }
    keys.forEach((key) => window.localStorage.removeItem(key))
  } catch {
    return
  }
}
