import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('../../../../', import.meta.url))

export const apiUrl = process.env.E2E_API_URL ?? 'http://localhost:8000'
export const oltUrl = process.env.E2E_OLT_URL ?? 'http://localhost:8090'
export const anonKey =
  process.env.E2E_ANON_KEY ?? readFileSync(join(root, 'docker/secrets/anon_key'), 'utf8').trim()

export type StaffName = 'Nadia' | 'Bima' | 'Laras' | 'Sinta' | 'Adi' | 'Kirana'

export type StaffMember = {
  id: string
  name: string
  agent_code: string
  email: string
  password: string
  roles: string
}

const staffFile = process.env.E2E_STAFF_FILE ?? join(root, 'scripts/cs-demo/runtime/staff.json')
const staff = (JSON.parse(readFileSync(staffFile, 'utf8')) as { staff: StaffMember[] }).staff

export function member(name: StaffName): StaffMember {
  const found = staff.find((item) => item.name === name)
  if (!found) throw new Error(`Akun staf ${name} tidak ada di ${staffFile}. Jalankan: make cs-staff`)
  return found
}
