import { expect, test, type Browser, type Page } from '@playwright/test'

import { staffPage } from './staff'

export const autoMode = /^Penugasan otomatis/
export const claimMode = /^Ambil tiket/

async function openAssignmentSettings(page: Page) {
  await page.getByRole('link', { name: 'Pengaturan' }).click()
  await page.getByRole('button', { name: 'Penugasan, tiket & alert' }).click()
}

export async function currentAssignmentMode(page: Page) {
  await openAssignmentSettings(page)
  return (await page.getByRole('radio', { name: autoMode }).isChecked()) ? autoMode : claimMode
}

export async function setAssignmentMode(page: Page, mode: RegExp) {
  await openAssignmentSettings(page)
  const radio = page.getByRole('radio', { name: mode })
  if (await radio.isChecked()) return
  await radio.click()
  const save = page.getByRole('button', { name: 'Simpan', exact: true }).first()
  await save.click()
  await expect(save).toBeDisabled()
}

export async function asSuperAdmin<T>(browser: Browser, run: (page: Page) => Promise<T>) {
  const admin = await staffPage(browser, 'Adi')
  try {
    return await run(admin.page)
  } finally {
    await admin.context.close()
  }
}

export function keepAssignmentMode() {
  let previous: RegExp = claimMode
  return {
    remember: async (browser: Browser) => {
      previous = await asSuperAdmin(browser, currentAssignmentMode)
    },
    restore: (browser: Browser) => asSuperAdmin(browser, (page) => setAssignmentMode(page, previous)),
  }
}

export function pinAssignmentMode(mode: RegExp) {
  const saved = keepAssignmentMode()
  test.beforeAll(async ({ browser }) => {
    await saved.remember(browser)
    await asSuperAdmin(browser, (page) => setAssignmentMode(page, mode))
  })
  test.afterAll(({ browser }) => saved.restore(browser))
}
