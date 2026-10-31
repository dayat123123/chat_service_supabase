import { expect, test, type Browser, type Page } from '@playwright/test'

import { member, type StaffName } from './support/env'
import { audit } from './support/quality'
import { signIn } from './support/staff'

const themes = ['light', 'dark'] as const
type Theme = (typeof themes)[number]

async function themedPage(browser: Browser, theme: Theme) {
  const context = await browser.newContext()
  await context.addInitScript((value) => localStorage.setItem('cs-console.theme', value), theme)
  return { context, page: await context.newPage() }
}

async function asStaff(browser: Browser, theme: Theme, name: StaffName, run: (page: Page) => Promise<void>) {
  const { context, page } = await themedPage(browser, theme)
  try {
    await signIn(page, name)
    await run(page)
  } finally {
    await context.close()
  }
}

for (const theme of themes) {
  test.describe(`kontras WCAG AA (${theme})`, () => {
    test('login, verifikasi dua langkah, dan /dev/ui', async ({ browser }) => {
      const { context, page } = await themedPage(browser, theme)
      const person = member('Laras')
      await page.goto('/')
      await expect(page.getByRole('heading', { name: 'Masuk ke CS Console' })).toBeVisible()
      await audit(page, `login-${theme}`)
      await page.getByLabel('Email', { exact: true }).fill(person.email)
      await page.getByLabel('Password', { exact: true }).fill(person.password)
      await page.getByRole('button', { name: 'Masuk', exact: true }).click()
      await expect(page.getByLabel('Kode 6 digit')).toBeVisible()
      await audit(page, `totp-${theme}`)
      await page.goto('/dev/ui')
      await expect(page.locator('[data-theme-column]')).toHaveCount(2)
      await audit(page, `dev-ui-${theme}`)
      await context.close()
    })

    test('daftar tiket, dashboard, laporan, dan pengaturan', async ({ browser }) => {
      await asStaff(browser, theme, 'Sinta', async (page) => {
        await expect(page.getByRole('region', { name: 'Daftar tiket' })).toBeVisible()
        await audit(page, `tickets-${theme}`)
        await page.getByRole('link', { name: 'Dashboard' }).click()
        await expect(page.getByRole('heading', { name: 'Dashboard supervisor' })).toBeVisible()
        await audit(page, `dashboard-${theme}`)
        await page.getByRole('link', { name: 'Laporan' }).click()
        await expect(page.getByRole('heading', { name: 'Tiket per hari' })).toBeVisible()
        await audit(page, `reports-${theme}`)
      })
      await asStaff(browser, theme, 'Adi', async (page) => {
        await expect(page.getByRole('heading', { name: 'Akun CS' })).toBeVisible()
        await audit(page, `settings-${theme}`)
      })
    })
  })
}
