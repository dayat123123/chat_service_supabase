export const GAP_FILL_INTERVAL_MS = 45_000

export const RECONNECT_JITTER_MS = 5_000

export const RECHECK_DELAY_MS = 5_000

const BURST_DEBOUNCE_MS = 120

export type GapSchedule = { now: () => void; reconnected: () => void; stop: () => void }

type Options = {
  run: () => void
  random?: () => number
  isVisible?: () => boolean
  intervalMs?: number
  jitterMs?: number
  recheckMs?: number
}

export function createGapSchedule({
  run,
  random = Math.random,
  isVisible = () => true,
  intervalMs = GAP_FILL_INTERVAL_MS,
  jitterMs = RECONNECT_JITTER_MS,
  recheckMs = RECHECK_DELAY_MS,
}: Options): GapSchedule {
  let stopped = false
  let burst: number | undefined
  let periodic: number | undefined
  let first: number | undefined
  let second: number | undefined

  const now = () => {
    if (stopped) return
    window.clearTimeout(burst)
    burst = window.setTimeout(run, BURST_DEBOUNCE_MS)
  }

  const poll = () => {
    if (stopped || intervalMs <= 0) return
    periodic = window.setTimeout(
      () => {
        if (isVisible()) now()
        poll()
      },
      intervalMs * (0.75 + random() * 0.5),
    )
  }

  const reconnected = () => {
    if (stopped) return
    window.clearTimeout(first)
    window.clearTimeout(second)
    const delay = jitterMs * random()
    first = window.setTimeout(now, delay)
    second = recheckMs > 0 ? window.setTimeout(now, delay + recheckMs + recheckMs * random()) : undefined
  }

  const stop = () => {
    stopped = true
    ;[burst, periodic, first, second].forEach((timer) => window.clearTimeout(timer))
  }

  poll()
  return { now, reconnected, stop }
}
