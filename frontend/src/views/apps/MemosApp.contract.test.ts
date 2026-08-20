import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./MemosApp.vue', import.meta.url), 'utf8')

describe('MemosApp layout', () => {
  it('uses the shared horizontal page gutter in list and detail views', () => {
    expect(source).toContain(
      '<SkyScrollArea padded class="memos-page__content">',
    )
    expect(source).toContain(
      '<SkyScrollArea padded class="memo-detail-scroll">',
    )
  })

  it('optically centers playback speed labels without moving the controls', () => {
    expect(source).toContain('<span class="memo-speed-label">')
    expect(source).toContain('.memo-speed-label {')
    expect(source).toContain('transform: translateY(1px)')
  })

  it('centers the skip duration inside a dedicated icon frame', () => {
    expect(source).toContain('<span class="memo-skip-icon" aria-hidden="true">')
    expect(source).toContain('<RotateCcw :size="24" />')
    expect(source).toContain('<RotateCw :size="24" />')
    expect(source).toContain('.memo-skip-icon small {')
    expect(source).toContain('place-items: center')
  })
})
