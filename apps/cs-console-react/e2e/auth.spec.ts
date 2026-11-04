import { expect, test } from '@playwright/test'

import { member } from './support/env'
import { goOnline, signOut } from './support/staff'

test('login email + password tanpa TOTP, password salah ditolak, lalu keluar', async ({ page }) => {
  const nadia = member('Nadia')
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Masuk ke Rendezvous Hub' })).toBeVisible()

  await page.getByLabel('Email', { exact: true }).fill(nadia.email)
  await page.getByLabel('Password', { exact: true }).fill('password-yang-salah')
  await page.getByRole('button', { name: 'Masuk', exact: true }).click()
  await expect(page.getByText('Email atau password salah.')).toBeVisible()

  await page.getByLabel('Password', { exact: true }).fill(nadia.password)
  await page.getByRole('button', { name: 'Masuk', exact: true }).click()
  await page.getByRole('button', { name: 'Akun', exact: true }).click()
  await expect(page.getByRole('menu')).toContainText('Nadia')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('button', { name: 'Ubah status' })).toContainText('Offline')
  await expect(page).toHaveTitle(/Rendezvous Hub/)

  await goOnline(page)
  await signOut(page)
  await page.reload()
  await expect(page.getByRole('button', { name: 'Masuk', exact: true })).toBeVisible()
})
