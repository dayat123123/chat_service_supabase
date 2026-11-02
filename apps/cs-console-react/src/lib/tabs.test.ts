import { afterEach, describe, expect, it, vi } from 'vitest'

import { TabCoordinator } from './tabs'

const opened: TabCoordinator[] = []

function tab(scope: string) {
  const coordinator = new TabCoordinator()
  coordinator.start()
  coordinator.setScope(scope)
  opened.push(coordinator)
  return coordinator
}

afterEach(() => {
  opened.splice(0).forEach((coordinator) => coordinator.stop())
})

describe('TabCoordinator', () => {
  it('elects one leader per signed-in account', async () => {
    const nadia = tab('nadia')
    const adi = tab('adi')
    const nadiaAgain = tab('nadia')

    await vi.waitFor(() => expect(nadia.otherTabs()).toBe(1))
    expect([nadia.isLeader(), nadiaAgain.isLeader()].filter(Boolean)).toHaveLength(1)
    expect(adi.isLeader()).toBe(true)
    expect(adi.otherTabs()).toBe(0)
  })

  it('shares activity only with tabs of the same account', async () => {
    const nadia = tab('nadia')
    const adi = tab('adi')
    const nadiaAgain = tab('nadia')
    const seen = { adi: vi.fn(), nadiaAgain: vi.fn() }
    adi.listen('activity', seen.adi)
    nadiaAgain.listen('activity', seen.nadiaAgain)

    nadia.send('activity', 1)

    await vi.waitFor(() => expect(seen.nadiaAgain).toHaveBeenCalledWith(1))
    expect(seen.adi).not.toHaveBeenCalled()
  })
})
