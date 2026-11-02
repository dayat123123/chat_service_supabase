import { expect, test } from '@playwright/test'

import { signIn } from './support/staff'

test.use({
  trace: 'off',
  screenshot: 'off',
  launchOptions: { args: ['--disable-gpu-vsync', '--disable-frame-rate-limit'] },
})

test('1000 tiket dan 5000 pesan tetap mulus saat digulir', async ({ page }) => {
  await signIn(page, 'Laras', { online: false })
  await page.goto('/__perf')
  await expect(page.getByRole('heading', { name: 'Uji kinerja daftar' })).toBeVisible()
  await page.getByTestId('perf-run').click()
  const handle = await page.waitForFunction(
    () => {
      const output = document.querySelector('[data-testid="perf-result"]')
      const fps = output?.getAttribute('data-fps')
      return fps ? { fps: Number(fps), p95: Number(output?.getAttribute('data-p95')) } : null
    },
    undefined,
    { polling: 1_000, timeout: 30_000 },
  )
  const measured = await handle.jsonValue()
  if (!measured) throw new Error('Hasil uji kinerja kosong')
  const { fps, p95 } = measured
  const summary = `${fps} fps, p95 ${p95} ms`
  test.info().annotations.push({ type: 'perf', description: summary })
  process.stdout.write(`perf: ${summary}\n`)
  expect(fps, summary).toBeGreaterThanOrEqual(60)
  expect(p95, summary).toBeLessThanOrEqual(16.7)
})
