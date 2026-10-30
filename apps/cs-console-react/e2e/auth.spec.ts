import { expect, test } from '@playwright/test'

import { member } from './support/env'
import { goOnline, signOut } from './support/staff'
import { freshTotp } from './support/totp'

test('login email + password lalu TOTP, salah kode ditolak, lalu keluar', async ({ page }) => {
  const nadia = member('Nadia')
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Masuk ke CS Console' })).toBeVisible()

  await page.getByLabel('Email', { exact: true }).fill(nadia.email)
  await page.getByLabel('Password', { exact: true }).fill('password-yang-salah')
  await page.getByRole('button', { name: 'Masuk', exact: true }).click()
  await expect(page.getByText('Email atau password salah.')).toBeVisible()

  await page.getByLabel('Password', { exact: true }).fill(nadia.password)
  await page.getByRole('button', { name: 'Masuk', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Verifikasi dua langkah' })).toBeVisible()

  const code = await freshTotp(nadia.totp_secret)
  const wrong = String((Number(code) + 500_000) % 1_000_000).padStart(6, '0')
  await page.getByLabel('Kode 6 digit').fill(wrong)
  await page.getByRole('button', { name: 'Verifikasi' }).click()
  await expect(page.getByText('Kode tidak valid atau sudah kedaluwarsa.')).toBeVisible()

  await page.getByLabel('Kode 6 digit').fill(await freshTotp(nadia.totp_secret))
  await page.getByRole('button', { name: 'Verifikasi' }).click()
  await expect(page.getByRole('button', { name: 'Akun' })).toContainText('Nadia')
  await expect(page.getByRole('button', { name: 'Ubah status' })).toContainText('Offline')
  await expect(page).toHaveTitle(/CS Console/)

  await goOnline(page)
  await signOut(page)
  await page.reload()
  await expect(page.getByRole('button', { name: 'Masuk', exact: true })).toBeVisible()
})
