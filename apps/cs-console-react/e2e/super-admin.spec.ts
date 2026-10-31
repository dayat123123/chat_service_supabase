import { expect, test, type Page } from '@playwright/test'

import { Customer } from './support/customer'
import { claimMode, pinAssignmentMode } from './support/settings'
import { openTab, openTicket, staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

pinAssignmentMode(claimMode)

async function moveTo(page: Page, name: string, reason: string) {
  await page.getByRole('button', { name: 'Pindahkan ke…', exact: true }).click()
  const dialog = page.getByRole('dialog', { name: 'Pindahkan tiket' })
  await dialog.getByRole('combobox', { name: 'CS tujuan' }).click()
  await page.getByRole('option', { name: new RegExp(name) }).click()
  await dialog.getByLabel('Alasan').fill(reason)
  await dialog.getByRole('button', { name: 'Pindahkan ke…', exact: true }).click()
  await expect(page.getByText(`Tiket dipindahkan ke ${name}.`)).toBeVisible()
}

test('Super Admin memantau hanya-baca, membagikan tiket terbuka, lalu memindahkannya ke CS lain', async ({
  browser,
}) => {
  const customer = await Customer.login('rudi.setiawan')
  const nadia = await staffPage(browser, 'Nadia')
  const bima = await staffPage(browser, 'Bima')
  const sinta = await staffPage(browser, 'Sinta')
  try {
    const ticket = await customer.openTicket(`Saya mau komplain soal dana ${tag()}`)

    const topBar = sinta.page.getByRole('banner')
    await expect(topBar.getByText('Mode pantau')).toBeVisible()
    await expect(topBar.getByRole('button', { name: /^Ubah status/ })).toHaveCount(0)

    await sinta.page.getByRole('link', { name: 'Dashboard' }).click()
    await expect(sinta.page.getByRole('heading', { name: 'Dashboard', exact: true })).toBeVisible()
    await expect(sinta.page.getByRole('cell', { name: /Nadia/ })).toBeVisible()

    await sinta.page.getByRole('link', { name: 'Tiket' }).click()
    await expect(sinta.page.getByRole('tab', { name: /^Semua aktif/ })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(sinta.page.getByRole('tab', { name: /^Tiket saya/ })).toHaveCount(0)

    await openTab(sinta.page, /^Terbuka/)
    await openTicket(sinta.page, ticket.id, ticket.ticket_number)
    await expect(sinta.page.getByText('Belum diambil CS')).toBeVisible()
    await expect(sinta.page.getByRole('button', { name: 'Ambil tiket', exact: true })).toHaveCount(0)
    await moveTo(sinta.page, 'Nadia', 'Tiket menunggu terlalu lama')
    await openTab(nadia.page, /^Tiket saya/)
    await expect(ticketCard(nadia.page, ticket.id)).toBeVisible()

    await openTab(sinta.page, /^Semua aktif/)
    await openTicket(sinta.page, ticket.id, ticket.ticket_number)
    await expect(sinta.page.getByText('Ditangani oleh Nadia')).toBeVisible()
    await expect(sinta.page.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: 'Gabung', exact: true })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: 'Ambil tiket', exact: true })).toHaveCount(0)
    await expect(sinta.page.getByRole('button', { name: /^Selesaikan/ })).toHaveCount(0)

    await moveTo(sinta.page, 'Bima', 'Bima menangani dana hari ini')
    await expect(sinta.page.getByText('Ditangani oleh Bima')).toBeVisible()
    await openTab(bima.page, /^Tiket saya/)
    await expect(ticketCard(bima.page, ticket.id)).toBeVisible()
    await expect(ticketCard(nadia.page, ticket.id)).toHaveCount(0)
  } finally {
    await customer.closeActiveTicket()
    await nadia.context.close()
    await bima.context.close()
    await sinta.context.close()
  }
})
