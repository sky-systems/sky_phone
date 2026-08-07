import { describe, expect, it } from 'vitest'

import {
  createDefaultHomeLayout,
  HOME_GRID_PAGE_SIZE,
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
  it('uses fixed grid and dock slots for the registry arrangement', () => {
    const layout = parseHomeLayout(undefined, defaults, [...installed])

    expect(layout.grid).toHaveLength(HOME_GRID_PAGE_SIZE)
    expect(layout.grid.slice(0, 6)).toEqual([
      'phone',
      'messages',
      'mail',
      'clock',
      'notes',
      null,
    ])
    expect(layout.dock).toEqual(['phone', 'messages', 'clock', null])
    expect(layout.version).toBe(2)
  })

  it('migrates compact persisted arrays and appends newly installed apps', () => {
    const layout = parseHomeLayout(
      {
        dock: ['messages', 'invalid', 'messages'],
        grid: ['mail'],
        hidden: ['phone'],
      },
      defaults,
      [...installed],
    )

    expect(layout.dock).toEqual(['messages', null, null, null])
    expect(layout.grid.slice(0, 4)).toEqual(['mail', 'clock', 'notes', null])
    expect(layout.hidden).toEqual(['phone'])
    expect(layout.version).toBe(2)
  })

  it('preserves explicit gaps in versioned layouts', () => {
    const grid: HomeLayout['grid'] = Array.from(
      { length: HOME_GRID_PAGE_SIZE },
      () => null,
    )
    grid[0] = 'phone'
    grid[7] = 'mail'

    const layout = parseHomeLayout(
      {
        dock: ['messages', null, 'clock', null],
        grid,
        hidden: ['notes'],
        version: 2,
      },
      defaults,
      [...installed],
    )

    expect(layout.grid[0]).toBe('phone')
    expect(layout.grid[1]).toBeNull()
    expect(layout.grid[7]).toBe('mail')
    expect(layout.dock).toEqual(['messages', null, 'clock', null])
  })

  it('moves to an exact empty slot without compacting other apps', () => {
    const moved = moveHomeApp(defaults, 'mail', 'grid', 'grid', 12)

    expect(moved.grid[2]).toBeNull()
    expect(moved.grid[12]).toBe('mail')
    expect(moved.grid[0]).toBe('phone')
    expect(moved.grid[4]).toBe('notes')
  })

  it('swaps occupied slots and avoids duplicate displaced shortcuts', () => {
    const reordered = moveHomeApp(defaults, 'mail', 'grid', 'grid', 0)
    expect(reordered.grid.slice(0, 5)).toEqual([
      'mail',
      'messages',
      'phone',
      'clock',
      'notes',
    ])

    const docked = moveHomeApp(reordered, 'mail', 'grid', 'dock', 2)
    expect(docked.dock).toEqual(['phone', 'messages', 'mail', null])
    expect(docked.grid[0]).toBeNull()
    expect(docked.grid.filter((id) => id === 'clock')).toHaveLength(1)
  })

  it('removes shortcuts without closing gaps and restores the first gap', () => {
    const layout: HomeLayout = moveHomeApp(
      defaults,
      'phone',
      'grid',
      'grid',
      10,
    )
    const removed = removeHomeApp(layout, 'phone')
    expect(removed.grid[0]).toBeNull()
    expect(removed.grid[10]).toBeNull()
    expect(removed.dock[0]).toBeNull()
    expect(removed.hidden).toContain('phone')

    const restored = restoreHomeApp(removed, 'phone')
    expect(restored.grid[0]).toBe('phone')
    expect(restored.hidden).not.toContain('phone')
  })
})
