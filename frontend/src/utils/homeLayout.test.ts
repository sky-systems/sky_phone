import { describe, expect, it } from 'vitest'

import {
  createDefaultHomeLayout,
  moveHomeApp,
  parseHomeLayout,
  removeHomeApp,
  restoreHomeApp,
  type HomeLayout,
} from '@/utils/homeLayout'

const installed = ['phone', 'messages', 'mail', 'clock', 'notes'] as const
const defaults = createDefaultHomeLayout(
  [...installed],
  ['phone', 'messages', 'mail', 'clock', 'notes'],
  ['phone', 'messages', 'clock'],
)

describe('home layout', () => {
  it('uses the registry arrangement for devices without a saved layout', () => {
    expect(parseHomeLayout(undefined, defaults, [...installed])).toEqual(
      defaults,
    )
  })

  it('validates persisted ids and appends newly installed apps', () => {
    expect(
      parseHomeLayout(
        {
          dock: ['messages', 'invalid', 'messages'],
          grid: ['mail'],
          hidden: ['phone'],
        },
        defaults,
        [...installed],
      ),
    ).toEqual({
      dock: ['messages'],
      grid: ['mail', 'clock', 'notes'],
      hidden: ['phone'],
    })
  })

  it('reorders grid apps and swaps a full dock slot back into the grid', () => {
    const layout: HomeLayout = {
      dock: ['phone', 'messages', 'clock', 'notes'],
      grid: ['phone', 'messages', 'mail', 'clock', 'notes'],
      hidden: [],
    }

    const reordered = moveHomeApp(layout, 'mail', 'grid', 'grid', 0)
    expect(reordered.grid).toEqual([
      'mail',
      'phone',
      'messages',
      'clock',
      'notes',
    ])

    const docked = moveHomeApp(reordered, 'mail', 'grid', 'dock', 2)
    expect(docked.dock).toEqual(['phone', 'messages', 'mail', 'notes'])
    expect(docked.grid).toEqual(['phone', 'messages', 'clock', 'notes'])
  })

  it('removes every home shortcut and can restore it from the library', () => {
    const removed = removeHomeApp(defaults, 'phone')
    expect(removed.grid).not.toContain('phone')
    expect(removed.dock).not.toContain('phone')
    expect(removed.hidden).toContain('phone')

    const restored = restoreHomeApp(removed, 'phone')
    expect(restored.grid.at(-1)).toBe('phone')
    expect(restored.hidden).not.toContain('phone')
  })
})
