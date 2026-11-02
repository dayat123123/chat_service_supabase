export const KEY_FILE_MAX_BYTES = 64 * 1024

export const keyProblems = [
  'too_large',
  'not_json',
  'google_services',
  'not_service_account',
  'project_id',
  'client_email',
  'private_key_id',
  'private_key',
  'key_unusable',
] as const

export type KeyProblem = (typeof keyProblems)[number]

export type ServiceAccountKey = {
  type: 'service_account'
  project_id: string
  client_email: string
  private_key_id?: string
  private_key: string
}

export type KeyCheck = { ok: true; key: ServiceAccountKey } | { ok: false; problem: KeyProblem }

const PROJECT_ID = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/
const CLIENT_EMAIL = /^[^@\s]{1,100}@[a-z0-9.-]{1,100}\.gserviceaccount\.com$/
const KEY_ID = /^[A-Za-z0-9_-]{1,100}$/
const PEM = /-----BEGIN (RSA )?PRIVATE KEY-----[\s\S]+-----END (RSA )?PRIVATE KEY-----/

const problem = (code: KeyProblem): KeyCheck => ({ ok: false, problem: code })

const text = (value: unknown) => (typeof value === 'string' ? value.trim() : '')

export function readServiceAccount(source: string): KeyCheck {
  let value: unknown
  try {
    value = JSON.parse(source)
  } catch {
    return problem('not_json')
  }
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return problem('not_json')
  const raw = value as Record<string, unknown>
  if ('project_info' in raw) return problem('google_services')
  if (raw.type !== 'service_account') return problem('not_service_account')
  const projectId = text(raw.project_id)
  if (!PROJECT_ID.test(projectId)) return problem('project_id')
  const clientEmail = text(raw.client_email)
  if (!CLIENT_EMAIL.test(clientEmail)) return problem('client_email')
  const keyId = text(raw.private_key_id)
  if ('private_key_id' in raw && !KEY_ID.test(keyId)) return problem('private_key_id')
  const privateKey = typeof raw.private_key === 'string' ? raw.private_key : ''
  if (privateKey.length < 200 || privateKey.length > 10_000 || !PEM.test(privateKey)) {
    return problem('private_key')
  }
  return {
    ok: true,
    key: {
      type: 'service_account',
      project_id: projectId,
      client_email: clientEmail,
      ...(keyId ? { private_key_id: keyId } : {}),
      private_key: privateKey,
    },
  }
}

export async function keyUsable(pem: string): Promise<boolean | undefined> {
  const subtle = globalThis.crypto?.subtle
  if (!subtle || pem.includes('RSA PRIVATE KEY')) return undefined
  try {
    const body = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '')
    const der = Uint8Array.from(atob(body), (char) => char.charCodeAt(0))
    await subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
    return true
  } catch {
    return false
  }
}

export async function checkKeyFile(file: File): Promise<KeyCheck> {
  if (file.size > KEY_FILE_MAX_BYTES) return problem('too_large')
  const check = readServiceAccount(await file.text())
  if (!check.ok) return check
  if ((await keyUsable(check.key.private_key)) === false) return problem('key_unusable')
  return check
}

export function shortKeyId(keyId: string | null | undefined) {
  if (!keyId) return null
  return keyId.length > 10 ? `${keyId.slice(0, 10)}…` : keyId
}
