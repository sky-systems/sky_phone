import { describe, expect, it } from 'vitest'
import { validDisplayFrame } from './displayFrame'

function jpegHeader(width: number, height: number) {
  const bytes = [
    255,
    216,
    255,
    192,
    0,
    11,
    8,
    height >> 8,
    height & 255,
    width >> 8,
    width & 255,
    1,
    1,
    17,
    0,
    ...Array(90).fill(0),
  ]
  return 'data:image/jpeg;base64,' + btoa(String.fromCharCode(...bytes))
}
describe('spectator pixel boundary', () => {
  it('accepts the fixed-size JPEG header and rejects decode bombs', () => {
    expect(validDisplayFrame(jpegHeader(360, 780))).toBe(true)
    expect(validDisplayFrame(jpegHeader(65535, 65535))).toBe(false)
    expect(validDisplayFrame(jpegHeader(780, 360))).toBe(false)
  })
  it('rejects URLs, SVG, HTML, truncation and excessive payloads', () => {
    for (const frame of [
      null,
      {},
      'https://example.com/a.jpg',
      '<script>alert(1)</script>',
      'data:image/svg+xml;base64,AAAA',
      jpegHeader(360, 780).slice(0, 40),
      jpegHeader(360, 780) + 'A'.repeat(64000),
    ])
      expect(validDisplayFrame(frame)).toBe(false)
  })
})
