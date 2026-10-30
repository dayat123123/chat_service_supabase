import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claim, signIn } from './support/staff'
import { tag } from './support/text'

test('koneksi putus lalu tersambung: pesan susulan masuk tanpa duplikat', async ({ page, context }) => {
  const customer = await Customer.login('budi_santoso')
  try {
    await signIn(page, 'Nadia')
    const ticket = await customer.openTicket(`Dana saya belum masuk ${tag()}`)
    await claim(page, ticket.id, ticket.ticket_number)
    const status = page.getByRole('status').filter({ hasText: /Terhubung|Offline|Menyambung/ })
    await expect(status).toContainText('Terhubung')
    const log = page.getByRole('log')

    await context.setOffline(true)
    await expect(status).toContainText('Offline')

    const missed = [`Halo kak masih ada? ${tag()}`, `Saya tunggu ya ${tag()}`]
    for (const text of missed) await customer.send(text)

    const box = page.getByRole('textbox', { name: 'Balas' })
    const offlineReply = `Mohon ditunggu ${tag()}`
    await box.fill(offlineReply)
    await box.press('Enter')
    await expect(page.getByText('Gagal terkirim')).toBeVisible()

    await context.setOffline(false)
    await expect(status).toContainText('Terhubung', { timeout: 60_000 })
    for (const text of missed) {
      await expect(log.getByText(text)).toBeVisible({ timeout: 30_000 })
      await expect(log.getByText(text)).toHaveCount(1)
    }

    await page.getByRole('button', { name: 'Kirim ulang' }).click()
    await expect
      .poll(async () => (await customer.messages()).filter((message) => message.body === offlineReply).length)
      .toBe(1)
    await expect(log.getByText(offlineReply)).toHaveCount(1)
    await expect(page.getByText('Gagal terkirim')).toHaveCount(0)
  } finally {
    await context.setOffline(false)
    await customer.closeActiveTicket()
  }
})
