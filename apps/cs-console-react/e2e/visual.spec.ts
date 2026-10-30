import { mkdirSync } from 'node:fs'

import { expect, test, type Page } from '@playwright/test'

import { Customer } from './support/customer'
import { claim, signIn } from './support/staff'
import { tag } from './support/text'

const dir = process.env.E2E_SCREENSHOT_DIR ?? 'e2e-artifacts/screens'

function watchErrors(page: Page) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  return errors
}

async function chooseTheme(page: Page, theme: 'Terang' | 'Gelap') {
  await page.getByRole('button', { name: 'Akun' }).click()
  await page.getByRole('menuitem', { name: 'Tema' }).click()
  await page.getByRole('menuitemradio', { name: theme }).click()
  await page.keyboard.press('Escape')
}

test.beforeAll(() => mkdirSync(dir, { recursive: true }))

for (const scheme of ['light', 'dark'] as const) {
  test(`halaman login (${scheme})`, async ({ browser }) => {
    const context = await browser.newContext({ colorScheme: scheme })
    const page = await context.newPage()
    const errors = watchErrors(page)
    await page.goto('/')
    await expect(page.getByRole('heading', { name: 'Masuk ke CS Console' })).toBeVisible()
    await expect(page.locator('html')).toHaveClass(scheme === 'dark' ? /dark/ : /^(?!.*dark)/)
    await page.screenshot({ path: `${dir}/login-${scheme}.png` })
    expect(errors).toEqual([])
    await context.close()
  })
}

test('ruang kerja tiket terang dan gelap', async ({ page }) => {
  const errors = watchErrors(page)
  const customer = await Customer.login('sari_invest')
  try {
    await signIn(page, 'Laras')
    await expect(page.getByText('Pilih tiket dari daftar di kiri.')).toBeVisible()
    await page.screenshot({ path: `${dir}/workspace-empty-light.png` })
    const ticket = await customer.openTicket(`Penarikan dana saya tertahan sejak kemarin ${tag()}`)
    await claim(page, ticket.id, ticket.ticket_number)
    await customer.send('Mohon dibantu cek ya kak, terima kasih')
    const box = page.getByRole('textbox', { name: 'Balas' })
    await box.fill('Baik Bu Sari, kami cek status penarikannya sekarang.')
    await box.press('Enter')
    await expect(page.getByRole('log').getByText('Mohon dibantu cek ya kak, terima kasih')).toBeVisible()
    await chooseTheme(page, 'Terang')
    await page.screenshot({ path: `${dir}/workspace-light.png` })
    await chooseTheme(page, 'Gelap')
    await expect(page.locator('html')).toHaveClass(/dark/)
    await page.screenshot({ path: `${dir}/workspace-dark.png` })
    await page.keyboard.press('Control+k')
    await expect(page.getByRole('dialog', { name: 'Command palette' })).toBeVisible()
    await page.getByRole('combobox').fill('selesai')
    await page.screenshot({ path: `${dir}/command-palette-dark.png` })
    await page.keyboard.press('Escape')
    await chooseTheme(page, 'Terang')
    await page.setViewportSize({ width: 820, height: 1000 })
    await expect(page.getByRole('button', { name: 'Daftar tiket' })).toBeVisible()
    await page.screenshot({ path: `${dir}/workspace-narrow-light.png` })
    await page.getByRole('button', { name: 'Daftar tiket' }).click()
    await expect(page.getByRole('region', { name: 'Daftar tiket' })).toBeVisible()
    await page.screenshot({ path: `${dir}/tickets-narrow-light.png` })
    expect(errors).toEqual([])
  } finally {
    await customer.closeActiveTicket()
  }
})

test('dashboard dan laporan supervisor', async ({ page }) => {
  const errors = watchErrors(page)
  await signIn(page, 'Sinta')
  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page.getByRole('heading', { name: 'Dashboard supervisor' })).toBeVisible()
  await expect(page.getByText('Antrean per prioritas')).toBeVisible()
  await page.screenshot({ path: `${dir}/dashboard-light.png`, fullPage: true })
  await page.getByRole('link', { name: 'Laporan' }).click()
  await expect(page.getByRole('heading', { name: 'Laporan' })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Tiket per hari' })).toBeVisible()
  await page.screenshot({ path: `${dir}/reports-light.png`, fullPage: true })
  expect(errors).toEqual([])
})

test('pengaturan admin', async ({ page }) => {
  const errors = watchErrors(page)
  await signIn(page, 'Adi')
  await expect(page.getByRole('heading', { name: 'Akun CS' })).toBeVisible()
  await expect(page.getByRole('cell', { name: /Nadia/ })).toBeVisible()
  await page.screenshot({ path: `${dir}/settings-accounts-light.png`, fullPage: true })
  await page.getByRole('button', { name: 'Jam layanan & libur' }).click()
  await expect(page.getByRole('heading', { name: 'Jam layanan (WIB)' })).toBeVisible()
  await page.screenshot({ path: `${dir}/settings-hours-light.png`, fullPage: true })
  expect(errors).toEqual([])
})
