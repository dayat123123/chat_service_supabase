import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

test('dua CS mengambil tiket yang sama: hanya satu yang berhasil', async ({ browser }) => {
  const customer = await Customer.login('joko_prasetyo')
  const nadia = await staffPage(browser, 'Nadia')
  const bima = await staffPage(browser, 'Bima')
  try {
    const ticket = await customer.openTicket(`Halo, saya butuh bantuan ${tag()}`)
    const claimButton = (page: typeof nadia.page) =>
      ticketCard(page, ticket.id).getByRole('button', { name: `Ambil ${ticket.ticket_number}` })
    await expect(claimButton(nadia.page)).toBeEnabled()
    await expect(claimButton(bima.page)).toBeEnabled()

    await Promise.all([claimButton(nadia.page).click(), claimButton(bima.page).click()])

    const outcome = async (page: typeof nadia.page) => {
      const composer = page.getByRole('textbox', { name: 'Balas' })
      const taken = page.getByText(/Tiket sudah diambil oleh (Nadia|Bima)/)
      await expect(composer.or(taken).first()).toBeVisible()
      return (await composer.isVisible()) ? 'won' : 'lost'
    }
    const results = [await outcome(nadia.page), await outcome(bima.page)]
    expect(results.filter((result) => result === 'won')).toHaveLength(1)

    const loser = results[0] === 'lost' ? nadia.page : bima.page
    await expect(ticketCard(loser, ticket.id)).toHaveCount(0)
  } finally {
    await customer.closeActiveTicket()
    await nadia.context.close()
    await bima.context.close()
  }
})
