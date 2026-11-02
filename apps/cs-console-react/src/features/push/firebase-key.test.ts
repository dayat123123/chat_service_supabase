import { describe, expect, it } from 'vitest'

import { checkKeyFile, keyUsable, readServiceAccount, shortKeyId } from './firebase-key'

async function generatePem() {
  const pair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  )
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))
  const body = btoa(String.fromCharCode(...der))
    .match(/.{1,64}/g)!
    .join('\n')
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----\n`
}

const fakePem = `-----BEGIN PRIVATE KEY-----\n${'MIIEvQIBADANBgkqhkiG9w0BAQEFAASC'.repeat(12)}\n-----END PRIVATE KEY-----\n`

function account(overrides: Record<string, unknown> = {}) {
  return JSON.stringify({
    type: 'service_account',
    project_id: 'olt-prod',
    private_key_id: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
    private_key: fakePem,
    client_email: 'firebase-adminsdk-x1@olt-prod.iam.gserviceaccount.com',
    client_id: '1234567890',
    token_uri: 'https://oauth2.googleapis.com/token',
    ...overrides,
  })
}

describe('readServiceAccount', () => {
  it('keeps only the fields the notifier needs', () => {
    const check = readServiceAccount(account())
    expect(check).toEqual({
      ok: true,
      key: {
        type: 'service_account',
        project_id: 'olt-prod',
        client_email: 'firebase-adminsdk-x1@olt-prod.iam.gserviceaccount.com',
        private_key_id: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
        private_key: fakePem,
      },
    })
  })

  it.each([
    ['not json', 'project_id=olt', 'not_json'],
    ['a json array', '[]', 'not_json'],
    [
      'google-services.json',
      JSON.stringify({ project_info: { project_id: 'olt-prod' }, client: [] }),
      'google_services',
    ],
    ['another credential type', account({ type: 'authorized_user' }), 'not_service_account'],
    ['a bad project id', account({ project_id: 'OLT Prod' }), 'project_id'],
    ['a personal email', account({ client_email: 'admin@gmail.com' }), 'client_email'],
    ['a bad key id', account({ private_key_id: 'bad id!' }), 'private_key_id'],
    ['a truncated key', account({ private_key: '-----BEGIN PRIVATE KEY-----\nMIIE' }), 'private_key'],
  ])('rejects %s', (_, source, problem) => {
    expect(readServiceAccount(source)).toEqual({ ok: false, problem })
  })

  it('accepts a key without a key id', () => {
    const check = readServiceAccount(account({ private_key_id: undefined }))
    expect(check.ok).toBe(true)
    expect(check.ok && 'private_key_id' in check.key).toBe(false)
  })
})

describe('checkKeyFile', () => {
  it('accepts a real Firebase key file', async () => {
    const pem = await generatePem()
    const check = await checkKeyFile(
      new File([account({ private_key: pem })], 'olt-prod-firebase-adminsdk.json'),
    )
    expect(check.ok).toBe(true)
  })

  it('rejects a key the browser cannot read', async () => {
    expect(await keyUsable(fakePem)).toBe(false)
    expect(await checkKeyFile(new File([account()], 'key.json'))).toEqual({
      ok: false,
      problem: 'key_unusable',
    })
  })

  it('rejects files far larger than a key', async () => {
    const file = new File(['x'.repeat(70 * 1024)], 'big.json')
    expect(await checkKeyFile(file)).toEqual({ ok: false, problem: 'too_large' })
  })
})

describe('shortKeyId', () => {
  it('shortens long key ids', () => {
    expect(shortKeyId('a1b2c3d4e5f60718293a')).toBe('a1b2c3d4e5…')
    expect(shortKeyId('kid-1')).toBe('kid-1')
    expect(shortKeyId(null)).toBeNull()
  })
})
