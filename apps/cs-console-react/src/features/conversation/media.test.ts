import { describe, expect, it } from 'vitest'

import { fileSize, isDocument, mediaProblem } from './media'

const file = (name: string, type: string, size: number) => new File([new Uint8Array(size)], name, { type })

describe('chat media', () => {
  it('accepts images up to 5 MB and PDFs up to 10 MB', () => {
    expect(mediaProblem(file('layar.png', 'image/png', 1024))).toBeNull()
    expect(mediaProblem(file('bukti.pdf', 'application/pdf', 9 * 1024 * 1024))).toBeNull()
    expect(mediaProblem(file('foto.jpg', 'image/jpeg', 6 * 1024 * 1024))).toBe('tooLarge')
    expect(mediaProblem(file('besar.pdf', 'application/pdf', 11 * 1024 * 1024))).toBe('tooLarge')
  })

  it('refuses video, audio, Office files, and archives', () => {
    for (const [name, type] of [
      ['rekaman.mp4', 'video/mp4'],
      ['suara.m4a', 'audio/mp4'],
      ['data.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
      ['surat.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
      ['arsip.zip', 'application/zip'],
      ['foto.heic', 'image/heic'],
    ] as const) {
      expect(mediaProblem(file(name, type, 10))).toBe('badType')
    }
  })

  it('tells documents from images', () => {
    expect(isDocument({ bucket: 'cs-documents', mime: null })).toBe(true)
    expect(isDocument({ mime: 'application/pdf' })).toBe(true)
    expect(isDocument({ mime: 'image/png' })).toBe(false)
  })

  it('formats file sizes for people', () => {
    expect(fileSize(900)).toBe('900 B')
    expect(fileSize(182_000)).toBe('178 KB')
    expect(fileSize(2_621_440)).toBe('2,5 MB')
    expect(fileSize(null)).toBe('')
  })
})
