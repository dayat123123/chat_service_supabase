import { describe, expect, it } from 'vitest'

import { hoursValue, placeholders, readHours, validDay } from './logic'

describe('service hours', () => {
  it('reads saved hours and fills closed days with defaults', () => {
    const days = readHours({ '1': ['08:00', '17:00'], '6': null, '7': 'invalid' })
    expect(days[1]).toEqual({ open: true, opens: '08:00', closes: '17:00' })
    expect(days[6]).toEqual({ open: false, opens: '08:00', closes: '17:00' })
    expect(days[7]?.open).toBe(false)
    expect(Object.keys(readHours(null))).toHaveLength(7)
  })

  it('validates HH:MM ranges and allows closing at 24:00', () => {
    expect(validDay({ open: true, opens: '08:00', closes: '24:00' })).toBe(true)
    expect(validDay({ open: true, opens: '17:00', closes: '08:00' })).toBe(false)
    expect(validDay({ open: true, opens: '24:00', closes: '24:00' })).toBe(false)
    expect(validDay({ open: true, opens: '8:00', closes: '17:00' })).toBe(false)
    expect(validDay({ open: false, opens: 'x', closes: 'y' })).toBe(true)
  })

  it('serialises every weekday', () => {
    const days = readHours({ '1': [' 08:00 ', '17:00'] })
    expect(hoursValue(days)).toEqual({
      '1': ['08:00', '17:00'],
      '2': null,
      '3': null,
      '4': null,
      '5': null,
      '6': null,
      '7': null,
    })
  })
})

describe('placeholders', () => {
  it('lists unique variables across languages', () => {
    expect(placeholders(['Halo {nama}, tiket {nomor_tiket}', 'Hi {nama}'])).toEqual([
      '{nama}',
      '{nomor_tiket}',
    ])
    expect(placeholders(['Tanpa variabel'])).toEqual([])
  })
})
