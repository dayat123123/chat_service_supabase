import { describe, expect, it } from 'vitest'

import { avatarPath, clampCrop, coverScale, cropSource, MAX_ZOOM } from './avatar-crop'

describe('avatar crop', () => {
  it('scales the photo so it always fills the crop circle', () => {
    expect(coverScale(1200, 600)).toBe(0.4)
    expect(coverScale(300, 900)).toBe(0.8)
  })

  it('keeps the photo inside the circle and the zoom within range', () => {
    expect(clampCrop({ zoom: 1, x: 500, y: 40 }, 1200, 600)).toEqual({ zoom: 1, x: 120, y: 0 })
    expect(clampCrop({ zoom: 9, x: 0, y: 0 }, 1200, 600).zoom).toBe(MAX_ZOOM)
    expect(clampCrop({ zoom: 0.2, x: -999, y: 0 }, 1200, 600)).toEqual({ zoom: 1, x: -120, y: 0 })
  })

  it('maps the visible circle back to a square of the original photo', () => {
    expect(cropSource({ zoom: 1, x: 0, y: 0 }, 1200, 600)).toEqual({ sx: 300, sy: 0, size: 600 })
    expect(cropSource({ zoom: 1, x: 120, y: 0 }, 1200, 600)).toEqual({ sx: 0, sy: 0, size: 600 })
    expect(cropSource({ zoom: 2, x: 0, y: 0 }, 1200, 600)).toEqual({ sx: 450, sy: 150, size: 300 })
  })

  it('only deletes photos stored in the account folder', () => {
    const base = 'http://localhost:8000/storage/v1/object/public/avatars'
    expect(avatarPath(`${base}/acc-1/avatar-1.jpg`, 'acc-1')).toBe('acc-1/avatar-1.jpg')
    expect(avatarPath(`${base}/acc-2/avatar-1.jpg`, 'acc-1')).toBeNull()
    expect(avatarPath(`${base}/acc-1/../acc-2/a.jpg`, 'acc-1')).toBeNull()
    expect(avatarPath('https://cdn.example.com/a.jpg', 'acc-1')).toBeNull()
  })
})
