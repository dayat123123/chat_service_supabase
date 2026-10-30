import { createHmac } from 'node:crypto'
import { setTimeout as sleep } from 'node:timers/promises'

const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

function decodeBase32(secret: string) {
  let bits = ''
  for (const char of secret.replace(/=+$/, '').toUpperCase()) {
    const value = alphabet.indexOf(char)
    if (value < 0) throw new Error('Secret TOTP bukan base32')
    bits += value.toString(2).padStart(5, '0')
  }
  const bytes = bits.match(/.{8}/g) ?? []
  return Buffer.from(bytes.map((byte) => parseInt(byte, 2)))
}

export function totp(secret: string, at = Date.now()) {
  const counter = Buffer.alloc(8)
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)))
  const digest = createHmac('sha1', decodeBase32(secret)).update(counter).digest()
  const offset = (digest[digest.length - 1] ?? 0) & 0x0f
  const code = (digest.readUInt32BE(offset) & 0x7fffffff) % 1_000_000
  return String(code).padStart(6, '0')
}

export async function freshTotp(secret: string) {
  const remaining = 30_000 - (Date.now() % 30_000)
  if (remaining < 4_000) await sleep(remaining + 500)
  return totp(secret)
}
