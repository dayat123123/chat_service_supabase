import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claimMode, pinAssignmentMode } from './support/settings'
import { claim, openTicket, staffPage } from './support/staff'
import { tag } from './support/text'

pinAssignmentMode(claimMode)

test('CS yang bukan pemilik hanya melihat pratinjau hanya-baca', async ({ browser }) => {
  const customer = await Customer.login('rina_saham')
  const nadia = await staffPage(browser, 'Nadia')
  const bima = await staffPage(browser, 'Bima')
  try {
    const opening = `Portofolio saya tidak muncul ${tag()}`
    const ticket = await customer.openTicket(opening)

    await openTicket(nadia.page, ticket.id, ticket.ticket_number)
    await expect(nadia.page.getByText(opening)).toBeVisible()
    await expect(nadia.page.getByText('Ambil tiket ini untuk membalas')).toBeVisible()
    await expect(nadia.page.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)
    await expect(nadia.page.getByRole('button', { name: 'Ambil tiket', exact: true })).toBeEnabled()

    await claim(bima.page, ticket.id, ticket.ticket_number)
    await expect(nadia.page.getByText('Tiket sudah diambil oleh Bima.')).toBeVisible()
    await expect(nadia.page.getByText('Pilih tiket dari daftar di kiri.')).toBeVisible()
    await expect(nadia.page.getByText(opening)).toHaveCount(0)
    await expect(nadia.page.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)
  } finally {
    await customer.closeActiveTicket()
    await nadia.context.close()
    await bima.context.close()
  }
})
