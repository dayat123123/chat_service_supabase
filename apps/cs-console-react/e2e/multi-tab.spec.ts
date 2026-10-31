import { expect, test, type Page } from '@playwright/test'

import { signIn, signOut } from './support/staff'

const connection = (page: Page) =>
  page.getByRole('status').filter({ hasText: /^(Terhubung|Offline|Menyambung ulang…)$/ })

test('akun lain di tab lain tidak memutus realtime maupun sesi tab ini', async ({ browser }) => {
  const context = await browser.newContext()
  try {
    const bima = await context.newPage()
    await signIn(bima, 'Bima', { online: false })
    await expect(connection(bima)).toContainText('Terhubung')

    const adi = await context.newPage()
    await signIn(adi, 'Adi')
    await expect(connection(adi)).toContainText('Terhubung')
    await expect(connection(bima)).toContainText('Terhubung')

    await signOut(adi)
    await expect(bima.getByRole('button', { name: 'Akun', exact: true })).toBeVisible()
    await expect(connection(bima)).toContainText('Terhubung')
  } finally {
    await context.close()
  }
})
