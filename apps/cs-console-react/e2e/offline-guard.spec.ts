import { expect, test, type Page } from '@playwright/test'

import { Customer } from './support/customer'
import { asSuperAdmin, claimMode, keepAssignmentMode, setAssignmentMode } from './support/settings'
import { claim, goOffline, openTab, signIn, ticketCard } from './support/staff'
import { tag } from './support/text'

const mode = keepAssignmentMode()
test.beforeAll(({ browser }) => mode.remember(browser))
test.afterAll(({ browser }) => mode.restore(browser))

function toast(page: Page, text: string) {
  return page.locator('[data-sonner-toast]').filter({ hasText: text })
}

test('CS Offline diminta Online dulu saat mengambil tiket atau membalas nasabah', async ({ browser }) => {
  const customer = await Customer.login('rudi.setiawan')
  await asSuperAdmin(browser, (page) => setAssignmentMode(page, claimMode))
  const bimaContext = await browser.newContext()
  const bima = await bimaContext.newPage()
  await signIn(bima, 'Bima', { online: false })
  await goOffline(bima)
  try {
    const ticket = await customer.openTicket(`Mohon dibantu cek saldo ${tag()}`)
    await openTab(bima, /^Terbuka/)

    await ticketCard(bima, ticket.id)
      .getByRole('button', { name: `Ambil ${ticket.ticket_number}` })
      .click()
    const claimNotice = toast(bima, 'Status Anda Offline. Ubah ke Online dulu untuk mengambil tiket.')
    await expect(claimNotice).toBeVisible()
    await expect(bima.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)

    await claimNotice.getByRole('button', { name: 'Ubah ke Online' }).click()
    await expect(bima.getByRole('button', { name: 'Ubah status' })).toContainText('Online')
    await claim(bima, ticket.id, ticket.ticket_number)

    const replyText = `Halo, saya bantu cek saldonya ${tag()}`
    const reply = bima.getByRole('textbox', { name: 'Balas' })
    await reply.fill(replyText)
    await goOffline(bima)

    const hint = bima.getByRole('status').filter({
      hasText: 'Anda sedang Offline. Ubah ke Online untuk mengetik dan mengirim balasan.',
    })
    await expect(hint).toBeVisible()
    await expect(reply).toBeDisabled()
    await expect(reply).toHaveValue(replyText)
    await expect(bima.getByRole('button', { name: 'Kirim', exact: true })).toBeDisabled()
    await expect(bima.getByRole('button', { name: 'Lampirkan gambar' })).toBeDisabled()
    const bodies = (await customer.messages()).map((message) => message.body)
    expect(bodies).not.toContain(replyText)

    await hint.getByRole('button', { name: 'Ubah ke Online' }).click()
    await expect(reply).toBeEnabled()
    await reply.press('Enter')
    await expect
      .poll(async () => (await customer.messages()).map((message) => message.body))
      .toContain(replyText)
  } finally {
    await customer.closeActiveTicket()
    await bimaContext.close()
  }
})
