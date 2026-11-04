import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import {
  createGapSchedule,
  GAP_FILL_INTERVAL_MS,
  RECHECK_DELAY_MS,
  RECONNECT_JITTER_MS,
} from './gap-schedule'

describe('gap-fill schedule', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  function schedule(roll: number, visible = () => true) {
    const run = vi.fn()
    const gaps = createGapSchedule({ run, random: () => roll, isVisible: visible })
    return { run, gaps }
  }

  it('uses a 0-5 s reconnect jitter, a 5 s recheck base, and a 45 s interval by default', () => {
    expect(RECONNECT_JITTER_MS).toBe(5_000)
    expect(RECHECK_DELAY_MS).toBe(5_000)
    expect(GAP_FILL_INTERVAL_MS).toBe(45_000)
  })

  it('collapses a burst of immediate requests into one catch-up', () => {
    const { run, gaps } = schedule(0.5)
    gaps.now()
    gaps.now()
    gaps.now()
    vi.advanceTimersByTime(200)
    expect(run).toHaveBeenCalledTimes(1)
    gaps.stop()
  })

  it('waits a random jitter after a reconnect, then checks again 5-10 s later for late commits', () => {
    const { run, gaps } = schedule(0.5)
    gaps.reconnected()

    vi.advanceTimersByTime(2_000)
    expect(run).not.toHaveBeenCalled()
    vi.advanceTimersByTime(1_000)
    expect(run).toHaveBeenCalledTimes(1)

    vi.advanceTimersByTime(6_000)
    expect(run).toHaveBeenCalledTimes(1)
    vi.advanceTimersByTime(1_500)
    expect(run).toHaveBeenCalledTimes(2)
    gaps.stop()
  })

  it('spreads reconnecting clients across the jitter window', () => {
    const early = schedule(0)
    const late = schedule(0.99)
    early.gaps.reconnected()
    late.gaps.reconnected()

    vi.advanceTimersByTime(500)
    expect(early.run).toHaveBeenCalledTimes(1)
    expect(late.run).not.toHaveBeenCalled()
    vi.advanceTimersByTime(4_700)
    expect(late.run).toHaveBeenCalledTimes(1)
    early.gaps.stop()
    late.gaps.stop()
  })

  it('replaces the pending catch-ups when the channel reconnects again', () => {
    const { run, gaps } = schedule(0.5)
    gaps.reconnected()
    vi.advanceTimersByTime(1_000)
    gaps.reconnected()
    gaps.reconnected()
    vi.advanceTimersByTime(20_000)
    expect(run).toHaveBeenCalledTimes(2)
    gaps.stop()
  })

  it('polls around the interval with a random spread and skips hidden tabs', () => {
    let visible = true
    const early = schedule(0, () => visible)
    const late = schedule(0.99, () => visible)

    vi.advanceTimersByTime(34_000)
    expect(early.run).toHaveBeenCalledTimes(1)
    expect(late.run).not.toHaveBeenCalled()
    vi.advanceTimersByTime(23_000)
    expect(late.run).toHaveBeenCalledTimes(1)

    visible = false
    vi.advanceTimersByTime(120_000)
    expect(early.run).toHaveBeenCalledTimes(1)
    expect(late.run).toHaveBeenCalledTimes(1)
    early.gaps.stop()
    late.gaps.stop()
  })

  it('stops every timer', () => {
    const { run, gaps } = schedule(0.5)
    gaps.now()
    gaps.reconnected()
    gaps.stop()
    vi.advanceTimersByTime(120_000)
    expect(run).not.toHaveBeenCalled()
  })
})
