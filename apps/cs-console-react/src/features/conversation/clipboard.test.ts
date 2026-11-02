import { afterEach, describe, expect, it, vi } from 'vitest'

import { clipboardImages, fitImage, pasteBelongsElsewhere, scaledSize } from './clipboard'

function clipboard(files: File[], extra: { kind: string; type: string }[] = []) {
  return {
    items: [
      ...extra.map((item) => ({ ...item, getAsFile: () => null })),
      ...files.map((file) => ({ kind: 'file', type: file.type, getAsFile: () => file })),
    ],
  } as unknown as DataTransfer
}

describe('clipboardImages', () => {
  it('takes only pasted images, like a Print Screen capture', () => {
    const shot = new File(['png'], 'image.png', { type: 'image/png' })
    const video = new File(['mp4'], 'clip.mp4', { type: 'video/mp4' })
    expect(clipboardImages(clipboard([shot, video], [{ kind: 'string', type: 'text/html' }]))).toEqual([shot])
    expect(clipboardImages(null)).toEqual([])
  })
})

describe('pasteBelongsElsewhere', () => {
  it('leaves pastes into fields and dialogs alone', () => {
    document.body.innerHTML = `
      <input id="search" />
      <div contenteditable="true" id="editor"></div>
      <div role="dialog"><button id="inside">ok</button></div>
      <ul id="messages"><li id="message">Halo</li></ul>`
    expect(pasteBelongsElsewhere(document.getElementById('search'))).toBe(true)
    expect(pasteBelongsElsewhere(document.getElementById('editor'))).toBe(true)
    expect(pasteBelongsElsewhere(document.getElementById('inside'))).toBe(true)
    expect(pasteBelongsElsewhere(document.getElementById('message'))).toBe(false)
    expect(pasteBelongsElsewhere(document.body)).toBe(false)
  })
})

describe('scaledSize', () => {
  it('keeps the aspect ratio within the longest edge', () => {
    expect(scaledSize(5120, 2880, 2560)).toEqual({ width: 2560, height: 1440 })
    expect(scaledSize(1080, 2400, 1920)).toEqual({ width: 864, height: 1920 })
    expect(scaledSize(800, 600, 2560)).toEqual({ width: 800, height: 600 })
  })
})

describe('fitImage', () => {
  const originalBitmap = globalThis.createImageBitmap
  afterEach(() => {
    globalThis.createImageBitmap = originalBitmap
    vi.restoreAllMocks()
  })

  function fakeCanvas(sizes: number[]) {
    const drawn: { width: number; height: number }[] = []
    globalThis.createImageBitmap = vi.fn(() =>
      Promise.resolve({ width: 5120, height: 2880, close: vi.fn() } as unknown as ImageBitmap),
    )
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(function (
      this: HTMLCanvasElement,
    ) {
      drawn.push({ width: this.width, height: this.height })
      return { fillStyle: '', fillRect: vi.fn(), drawImage: vi.fn() } as unknown as CanvasRenderingContext2D
    })
    let attempt = 0
    vi.spyOn(HTMLCanvasElement.prototype, 'toBlob').mockImplementation((done, type) => {
      done(new Blob([new Uint8Array(sizes[attempt++] ?? 0)], { type }))
    })
    return drawn
  }

  it('keeps images that already fit and never touches GIFs', async () => {
    const small = new File([new Uint8Array(10)], 'kecil.png', { type: 'image/png' })
    const gif = new File([new Uint8Array(50)], 'animasi.gif', { type: 'image/gif' })
    expect(await fitImage(small, 20)).toBe(small)
    expect(await fitImage(gif, 20)).toBe(gif)
  })

  it('shrinks a large screenshot into a JPEG under the limit', async () => {
    const drawn = fakeCanvas([30, 12])
    const shot = new File([new Uint8Array(100)], 'layar.png', { type: 'image/png', lastModified: 7 })

    const fitted = await fitImage(shot, 20)

    expect(drawn).toEqual([
      { width: 2560, height: 1440 },
      { width: 1920, height: 1080 },
    ])
    expect(fitted.name).toBe('layar.jpg')
    expect(fitted.type).toBe('image/jpeg')
    expect(fitted.size).toBe(12)
  })

  it('returns the original when it cannot be made small enough', async () => {
    fakeCanvas([30, 25])
    const shot = new File([new Uint8Array(100)], 'layar.png', { type: 'image/png' })
    expect(await fitImage(shot, 20)).toBe(shot)
  })
})
