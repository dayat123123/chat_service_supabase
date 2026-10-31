import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claim, openTab, openTicket, staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

test('supervisor memantau tiket hanya-baca lalu memindahkannya ke CS lain', async ({ browser }) => {
  const customer = await Customer.login('rudi.setiawan')
  const nadia = await staffPage(browser, 'Nadia')
  const bima = await staffPage(browser, 'Bima')
  const sinta = await staffPage(browser, 'Sinta')
  try {
    const ticket = await customer.openTicket(`Saya mau komplain soal dana ${tag()}`)
    await claim(nadia.page, ticket.id, ticket.ticket_number)

    const topBar = sinta.page.getByRole('banner')
    await expect(topBar.getByText('Mode pantau')).toBeVisible()
    await expect(topBar.getByRole('button', { name: /^Ubah status/ })).toHaveCount(0)

    await sinta.page.getByRole('link', { name: 'Dashboard' }).click()
    await expect(sinta.page.getByRole('heading', { name: 'Dashboard supervisor' })).toBeVisible()
    await expect(sinta.page.getByRole('cell', { name: /Nadia/ })).toBeVisible()

    await sinta.page.getByRole('link', { name: 'Tiket' }).click()
    await expect(sinta.page.getByRole('tab', { name: /^Semua aktif/ })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(sinta.page.getByRole('tab', { name: /^Tiket saya/ })).toHaveCount(0)
    await openTicket(sinta.page, ticket.id, ticket.ticket_number)
    await expect(sinta.page.getByText('Ditangani oleh Nadia')).toBeVisible()
    await expect(sinta.page.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: 'Gabung', exact: true })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: 'Ambil tiket', exact: true })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: /^Selesaikan/ })).toHaveCount(0)

    await sinta.page.getByRole('button', { name: 'Pindahkan ke…', exact: true }).click()
    const reassign = sinta.page.getByRole('dialog', { name: 'Pindahkan tiket' })
    await reassign.getByRole('combobox', { name: 'CS tujuan' }).click()
    await sinta.page.getByRole('option', { name: /Bima/ }).click()
    await reassign.getByLabel('Alasan').fill('Bima menangani dana hari ini')
    await reassign.getByRole('button', { name: 'Pindahkan ke…', exact: true }).click()
    await expect(sinta.page.getByText('Tiket dipindahkan ke Bima.')).toBeVisible()
    await expect(sinta.page.getByText('Ditangani oleh Bima')).toBeVisible()

    await openTab(bima.page, /^Tiket saya/)
    await expect(ticketCard(bima.page, ticket.id)).toBeVisible()
    await openTab(nadia.page, /^Tiket saya/)
    await expect(ticketCard(nadia.page, ticket.id)).toHaveCount(0)
  } finally {
    await customer.closeActiveTicket()
    await nadia.context.close()
    await bima.context.close()
    await sinta.context.close()
  }
})
