import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { asSuperAdmin, autoMode, keepAssignmentMode, setAssignmentMode } from './support/settings'
import { openTab, staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

const mode = keepAssignmentMode()
test.beforeAll(({ browser }) => mode.remember(browser))
test.afterAll(({ browser }) => mode.restore(browser))

test('mode otomatis: tiket baru langsung masuk Tiket saya dan CS diberi tahu', async ({ browser }) => {
  const customer = await Customer.login('rina_saham')
  await asSuperAdmin(browser, (page) => setAssignmentMode(page, autoMode))
  const nadia = await staffPage(browser, 'Nadia')
  try {
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
    await nadia.context.close()
  }
})
