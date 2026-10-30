import { randomInt } from 'node:crypto'

export function tag() {
  return Array.from({ length: 6 }, () => String.fromCharCode(97 + randomInt(26))).join('')
}
