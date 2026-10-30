import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claim, signIn } from './support/staff'
import { tag } from './support/text'

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
  'base64',
)

test('balas, tanda dibaca, lampiran gambar, dan pesan nasabah realtime', async ({ page }) => {
  const customer = await Customer.login('andi_trader')
  try {
    await signIn(page, 'Nadia')
    const opening = `Halo, order saya belum masuk ${tag()}`
    const ticket = await customer.openTicket(opening)
    await claim(page, ticket.id, ticket.ticket_number)
    const log = page.getByRole('log')
    await expect(log.getByText(opening)).toBeVisible()

    const box = page.getByRole('textbox', { name: 'Balas' })
    const reply = `Baik, kami cek dulu ya ${tag()}`
    await box.fill(reply)
    await box.press('Enter')
    await expect(box).toHaveValue('')
    await expect(log.getByText(reply)).toHaveCount(1)
    await expect
      .poll(async () => (await customer.messages()).some((message) => message.body === reply))
      .toBe(true)

    await expect(page.getByLabel('Terkirim').last()).toBeVisible()
    await customer.markRead()
    await expect(page.getByLabel('Dibaca').last()).toBeVisible()

    await page
      .locator('input[type="file"]')
      .setInputFiles({ name: 'bukti.png', mimeType: 'image/png', buffer: png })
    await expect(page.getByRole('img', { name: 'bukti.png' })).toBeVisible()
    const caption = `Ini tangkapan layarnya ${tag()}`
    await box.fill(caption)
    await box.press('Enter')
    await expect
      .poll(async () =>
        (await customer.messages()).some(
          (message) => message.body === caption && message.attachments.length === 1,
        ),
      )
      .toBe(true)

    const inbound = `Terima kasih kak ${tag()}`
    await customer.send(inbound)
    await expect(log.getByText(inbound)).toBeVisible()
    await expect(log.getByText(inbound)).toHaveCount(1)
  } finally {
    await customer.closeActiveTicket()
  }
})
