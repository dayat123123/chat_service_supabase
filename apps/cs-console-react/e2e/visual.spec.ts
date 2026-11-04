import { mkdirSync } from 'node:fs'

import { expect, test, type Page } from '@playwright/test'

import { Customer } from './support/customer'
import { audit, checkLayout } from './support/quality'
import { claim, signIn } from './support/staff'
import { tag } from './support/text'

const dir = process.env.E2E_SCREENSHOT_DIR ?? 'e2e-artifacts/screens'
const customerName = process.env.E2E_VISUAL_CUSTOMER ?? 'sari_invest'
const themes = ['light', 'dark'] as const
type Theme = (typeof themes)[number]

function watchErrors(page: Page) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  return errors
}

async function chooseTheme(page: Page, theme: Theme) {
  await page.getByRole('button', { name: 'Akun', exact: true }).click()
  await page.getByRole('menuitem', { name: 'Tema' }).click()
  await page.getByRole('menuitemradio', { name: theme === 'dark' ? 'Gelap' : 'Terang' }).click()
  await page.keyboard.press('Escape')
  await expect(page.getByRole('menu')).toHaveCount(0)
  await expect(page.locator('html')).toHaveClass(theme === 'dark' ? /\bdark\b/ : /^(?!.*\bdark\b)/)
}

async function shoot(page: Page, name: string, fullPage = false) {
  await page.evaluate(() => {
    if (!document.querySelector('[role="dialog"], [role="menu"]'))
      (document.activeElement as HTMLElement | null)?.blur()
  })
  await page.waitForTimeout(250)
  await page.screenshot({ path: `${dir}/${name}.png`, fullPage })
}

async function eachTheme(page: Page, name: string, show?: () => Promise<void>, hide?: () => Promise<void>) {
  for (const theme of themes) {
    await chooseTheme(page, theme)
    await show?.()
    await shoot(page, `${name}-${theme}`)
    await hide?.()
  }
}

test.beforeAll(() => mkdirSync(dir, { recursive: true }))

for (const theme of themes) {
  test(`login (${theme})`, async ({ browser }) => {
    const context = await browser.newContext()
    await context.addInitScript((value) => localStorage.setItem('cs-console.theme', value), theme)
    const page = await context.newPage()
    const errors = watchErrors(page)
    await page.goto('/')
    await expect(page.getByRole('heading', { name: 'Masuk ke Rendezvous Hub' })).toBeVisible()
    await shoot(page, `login-${theme}`)
    expect(errors).toEqual([])
    await context.close()
  })
}

test('halaman acuan /dev/ui', async ({ page }) => {
  const errors = watchErrors(page)
  await page.goto('/dev/ui')
  await expect(page.getByRole('heading', { name: 'Acuan tampilan' })).toBeVisible()
  await expect(page.locator('[data-theme-column]')).toHaveCount(2)
  await page.waitForTimeout(300)
  await page.screenshot({ path: `${dir}/dev-ui.png`, fullPage: true })
  for (const theme of themes) {
    await page.locator(`[data-theme-column="${theme}"]`).screenshot({ path: `${dir}/dev-ui-${theme}.png` })
  }
  expect(errors).toEqual([])
})

test('ruang kerja tiket, percakapan (kontras + resolusi), dialog, palet, layar sempit', async ({ page }) => {
  const errors = watchErrors(page)
  const customer = await Customer.login(customerName)
  try {
    await signIn(page, 'Laras')
    await expect(page.getByText('Pilih tiket dari daftar di kiri.')).toBeVisible()
    await eachTheme(page, 'workspace-empty')

    const ticket = await customer.openTicket(`Penarikan dana saya tertahan sejak kemarin ${tag()}`)
    await claim(page, ticket.id, ticket.ticket_number)
    const followUp = `Mohon dibantu cek ya kak ${tag()}`
    const reply = `Baik, kami cek status penarikannya sekarang ${tag()}`
    await customer.send(followUp)
    const box = page.getByRole('textbox', { name: 'Balas' })
    await box.fill(reply)
    await box.press('Enter')
    const log = page.getByRole('log')
    await expect(log.getByText(followUp)).toBeVisible()
    await expect(log.getByText(reply)).toBeVisible()
    await eachTheme(page, 'conversation')
    for (const theme of themes) {
      await chooseTheme(page, theme)
      await audit(page, `conversation-${theme}`)
    }
    await checkLayout(page, 'percakapan')

    await eachTheme(
      page,
      'dialog-resolve',
      async () => {
        await page.getByRole('button', { name: /^Selesaikan/ }).click()
        await expect(page.getByRole('dialog', { name: 'Selesaikan tiket' })).toBeVisible()
      },
      async () => {
        await page.keyboard.press('Escape')
        await expect(page.getByRole('dialog')).toHaveCount(0)
      },
    )

    await eachTheme(
      page,
      'command-palette',
      async () => {
        await page.keyboard.press('Control+k')
        await expect(page.getByRole('dialog', { name: 'Command palette' })).toBeVisible()
        await page.getByRole('combobox').fill('tiket')
      },
      async () => {
        await page.keyboard.press('Escape')
        await expect(page.getByRole('dialog')).toHaveCount(0)
      },
    )

    await page.setViewportSize({ width: 820, height: 1000 })
    await eachTheme(page, 'conversation-narrow')
    await page.getByRole('button', { name: 'Daftar tiket' }).click()
    await expect(page.getByRole('region', { name: 'Daftar tiket' })).toBeVisible()
    await eachTheme(page, 'tickets-narrow')
    await page.setViewportSize({ width: 1440, height: 900 })
    await chooseTheme(page, 'light')
    expect(errors).toEqual([])
  } finally {
    await customer.closeActiveTicket()
  }
})

test('dashboard dan laporan Super Admin', async ({ page }) => {
  const errors = watchErrors(page)
  await signIn(page, 'Sinta')
  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page.getByRole('heading', { name: 'Dashboard', exact: true })).toBeVisible()
  await expect(page.getByText('Antrean per prioritas')).toBeVisible()
  await eachTheme(page, 'dashboard')
  await page.getByRole('link', { name: 'Laporan' }).click()
  await expect(page.getByRole('heading', { name: 'Laporan' })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Tiket per hari' })).toBeVisible()
  await eachTheme(page, 'reports')
  await chooseTheme(page, 'light')
  expect(errors).toEqual([])
})

test('pengaturan Super Admin', async ({ page }) => {
  const errors = watchErrors(page)
  await signIn(page, 'Adi')
  await page.getByRole('link', { name: 'Pengaturan' }).click()
  await expect(page.getByRole('heading', { name: 'Akun CS' })).toBeVisible()
  await expect(page.getByRole('cell', { name: /^Nadia/ })).toBeVisible()
  await eachTheme(page, 'settings-accounts')
  await page.getByRole('button', { name: 'Jam layanan & libur' }).click()
  await expect(page.getByRole('heading', { name: 'Jam layanan (WIB)' })).toBeVisible()
  await eachTheme(page, 'settings-hours')
  await chooseTheme(page, 'light')
  expect(errors).toEqual([])
})
