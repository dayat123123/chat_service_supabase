import { expect, test, type Page } from '@playwright/test'

import { Customer } from './support/customer'
import { openTab, staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

const autoMode = /^Penugasan otomatis/
const claimMode = /^Ambil tiket/

async function assignmentMode(page: Page, mode: RegExp) {
  await page.getByRole('link', { name: 'Pengaturan' }).click()
  await page.getByRole('button', { name: 'Penugasan & alert' }).click()
  const radio = page.getByRole('radio', { name: mode })
  if (await radio.isChecked()) return
  await radio.click()
  const save = page.getByRole('button', { name: 'Simpan', exact: true }).first()
  await save.click()
  await expect(save).toBeDisabled()
}

test('mode otomatis: tiket baru langsung masuk Tiket saya dan CS diberi tahu', async ({ browser }) => {
  const customer = await Customer.login('rina_saham')
  const adi = await staffPage(browser, 'Adi')
  const nadia = await staffPage(browser, 'Nadia')
  await adi.page.getByRole('link', { name: 'Pengaturan' }).click()
  await adi.page.getByRole('button', { name: 'Penugasan & alert' }).click()
  const wasAuto = await adi.page.getByRole('radio', { name: autoMode }).isChecked()
  try {
    await assignmentMode(adi.page, autoMode)
    await openTab(nadia.page, /^Terbuka/)

    const ticket = await customer.openTicket(`Tolong cek akun saya ${tag()}`)

    const toast = nadia.page.getByText('Tiket baru ditugaskan ke Anda')
    await expect(toast).toBeVisible({ timeout: 5_000 })
    await nadia.page.getByRole('button', { name: 'Buka', exact: true }).click()
    await expect(nadia.page.getByRole('textbox', { name: 'Balas' })).toBeVisible()
    await openTab(nadia.page, /^Tiket saya/)
    await expect(ticketCard(nadia.page, ticket.id)).toBeVisible()
  } finally {
    await customer.closeActiveTicket()
    await assignmentMode(adi.page, wasAuto ? autoMode : claimMode)
    await adi.context.close()
    await nadia.context.close()
  }
})
