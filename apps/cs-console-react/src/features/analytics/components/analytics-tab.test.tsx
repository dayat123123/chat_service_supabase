import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { analyticsApi } from '../api'
import type { CommunityAnalytics } from '../types'
import { AnalyticsTab } from './analytics-tab'

vi.mock('../api', () => ({ analyticsApi: { community: vi.fn() } }))

const report: CommunityAnalytics = {
  from: '2026-10-05',
  to: '2026-11-03',
  timezone: 'Asia/Jakarta',
  generated_at: '2026-11-03T03:00:00.000Z',
  active_users: {
    dau: [
      { date: '2026-11-02', users: 120 },
      { date: '2026-11-03', users: 140 },
    ],
    avg_dau: 130,
    wau: 400,
    mau: 650,
    stickiness_pct: 20,
  },
  retention: [
    {
      cohort_week: '2026-10-26',
      users: 50,
      weeks: [
        { week: 0, active: 50, pct: 100 },
        { week: 1, active: 21, pct: 42 },
      ],
    },
  ],
  content: {
    posts: 310,
    comments: 920,
    messages: 4100,
    likes: 7800,
    daily: [
      { date: '2026-11-02', posts: 10, comments: 30 },
      { date: '2026-11-03', posts: 12, comments: 28 },
    ],
  },
  top_stocks: [{ code: 'BBCA', posts: 44, authors: 30 }],
  events: { feed_open: 900, order_tap: 25, stock_tap: 300 },
  order_taps: {
    taps: 25,
    users: 18,
    stock_tap_users: 120,
    conversion_pct: 15,
    by_source: { post: 15, stock: 10 },
    top_stocks: [{ code: 'BBRI', taps: 9 }],
  },
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(analyticsApi.community).mockResolvedValue(report)
})

describe('AnalyticsTab', () => {
  it('shows active users, retention cohorts, content, top stocks, events, and order taps', async () => {
    renderWithProviders(<AnalyticsTab />, monitorFixture)

    expect(await screen.findByText('650')).toBeVisible()
    expect(screen.getByText('20%')).toBeVisible()
    const retention = screen.getByRole('table', { name: 'Retensi mingguan' })
    expect(within(retention).getByRole('row', { name: /Minggu 26 Okt 2026/ })).toHaveTextContent('42%')
    expect(
      within(screen.getByRole('table', { name: 'Saham paling dibahas' })).getByText('$BBCA'),
    ).toBeVisible()
    expect(within(screen.getByRole('table', { name: 'Event aplikasi' })).getByText('Buka feed')).toBeVisible()
    expect(
      within(screen.getByRole('table', { name: 'Ketukan order per sumber' })).getByText('Postingan'),
    ).toBeVisible()
    expect(screen.getByText('15%')).toBeVisible()
  })

  it('reloads for a preset range', async () => {
    const user = userEvent.setup()
    renderWithProviders(<AnalyticsTab />, monitorFixture)
    await screen.findByText('650')
    await user.click(screen.getByRole('radio', { name: '7 hari' }))
    await waitFor(() => expect(analyticsApi.community).toHaveBeenCalledTimes(2))
    const [range] = vi.mocked(analyticsApi.community).mock.calls[1] ?? []
    expect(range && range.from < range.to).toBe(true)
  })
})
