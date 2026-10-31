import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claimMode, pinAssignmentMode } from './support/settings'
import { claim, openTab, staffPage, ticketCard } from './support/staff'
import { tag } from './support/text'

pinAssignmentMode(claimMode)

test('lepas ke antrean, transfer ke CS lain, lalu selesaikan', async ({ browser }) => {
  const customer = await Customer.login('dewi_cuan')
  const nadia = await staffPage(browser, 'Nadia')
  const bima = await staffPage(browser, 'Bima')
  try {
    const ticket = await customer.openTicket(`Saya mau tanya soal akun ${tag()}`)
    await claim(nadia.page, ticket.id, ticket.ticket_number)

    await nadia.page.getByRole('button', { name: 'Lepas', exact: true }).click()
    const release = nadia.page.getByRole('dialog', { name: 'Lepas tiket ke antrean' })
    await release.getByLabel('Alasan').fill('Perlu dicek tim lain')
    await release.getByRole('button', { name: 'Lepas', exact: true }).click()
    await expect(nadia.page.getByText('Tiket kembali ke antrean.')).toBeVisible()
    await expect(ticketCard(bima.page, ticket.id)).toBeVisible()

    await openTab(nadia.page, /^Terbuka/)
    await claim(nadia.page, ticket.id, ticket.ticket_number)

    await nadia.page.getByRole('button', { name: 'Transfer', exact: true }).click()
    const transfer = nadia.page.getByRole('dialog', { name: 'Transfer ke CS lain' })
    await transfer.getByRole('combobox', { name: 'CS tujuan' }).click()
    await nadia.page.getByRole('option', { name: /Bima/ }).click()
    await transfer.getByLabel('Catatan serah terima').fill('Mohon dilanjutkan, nasabah tanya akun')
    await transfer.getByRole('button', { name: 'Transfer', exact: true }).click()
    await expect(nadia.page.getByText('Permintaan transfer dikirim ke Bima.')).toBeVisible()

    await expect(bima.page.getByText('Transfer masuk')).toBeVisible()
    await bima.page.getByRole('button', { name: 'Terima', exact: true }).click()
    await expect(bima.page.getByText('Transfer diterima. Tiket sekarang milik Anda.')).toBeVisible()
    await expect(bima.page.getByRole('textbox', { name: 'Balas' })).toBeVisible()

    await bima.page.getByRole('button', { name: /^Selesaikan/ }).click()
    const resolve = bima.page.getByRole('dialog', { name: 'Selesaikan tiket' })
    await resolve.getByLabel('Ringkasan').fill('Pertanyaan akun sudah dijawab lengkap')
    await resolve.getByRole('button', { name: 'Selesaikan', exact: true }).click()
    await expect(bima.page.getByText('Tiket diselesaikan.')).toBeVisible()
    await expect(bima.page.getByText(/^Tiket selesai\./)).toBeVisible()
    await expect(bima.page.getByRole('textbox', { name: 'Balas' })).toHaveCount(0)
  } finally {
    await customer.closeActiveTicket()
    await nadia.context.close()
    await bima.context.close()
  }
})
