import { describe, expect, it } from 'vitest'

import { requestsSecret } from './secret'

describe('requestsSecret', () => {
  it.each([
    'Mohon kirimkan kode OTP Anda',
    'Please send me your password',
    'OTP-nya berapa ya Pak?',
    'Silakan sebutkan PIN Anda agar kami bisa cek',
    'Boleh ketik nomor kartu Anda di sini',
  ])('blocks a request for secrets: %s', (text) => {
    expect(requestsSecret(text)).toBe(true)
  })

  it.each([
    'Jangan berikan OTP kepada siapa pun.',
    'Mohon maaf, PIN Anda terblokir.',
    'Kami tidak pernah meminta password Anda.',
    'Silakan kirim tangkapan layar order Anda.',
    '',
  ])('allows education and normal replies: %s', (text) => {
    expect(requestsSecret(text)).toBe(false)
  })

  it('checks each sentence separately', () => {
    expect(requestsSecret('Jangan berikan OTP ke siapa pun. Tapi tolong kirim PIN Anda ke saya.')).toBe(true)
  })
})
