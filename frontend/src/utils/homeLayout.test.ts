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

  it('preserves independently positioned shortcuts for the same app', () => {
    const grid: HomeLayout['grid'] = Array.from(
      { length: HOME_GRID_PAGE_SIZE },
      () => null,
    )
    grid[0] = 'phone'
    grid[5] = 'phone'

    const layout = parseHomeLayout(
      {
        dock: ['phone', null, null, null],
        grid,
        hidden: [],
        version: 2,
      },
      defaults,
      [...installed],
    )

    expect(layout.grid[0]).toBe('phone')
    expect(layout.grid[5]).toBe('phone')
    expect(layout.dock[0]).toBe('phone')
  })

  it('moves to an exact empty slot without compacting other apps', () => {
    const moved = moveHomeApp(defaults, 'grid', 2, 'grid', 12)

    expect(moved.grid[2]).toBeNull()
    expect(moved.grid[12]).toBe('mail')
    expect(moved.grid[0]).toBe('phone')
    expect(moved.grid[4]).toBe('notes')
  })

  it('shifts occupied grid slots instead of replacing their apps', () => {
    const reordered = moveHomeApp(defaults, 'grid', 2, 'grid', 0)
    expect(reordered.grid.slice(0, 5)).toEqual([
      'mail',
      'phone',
      'messages',
      'clock',
      'notes',
    ])
  })

  it('shifts an occupied dock slot toward its gap', () => {
    const docked = moveHomeApp(defaults, 'grid', 2, 'dock', 2)

    expect(docked.dock).toEqual(['phone', 'messages', 'mail', 'clock'])
    expect(docked.grid[2]).toBeNull()
  })

  it('moves an app displaced from a full dock into the source slot', () => {
    const layout: HomeLayout = {
      ...defaults,
      dock: ['phone', 'messages', 'clock', 'notes'],
    }
    const docked = moveHomeApp(layout, 'grid', 2, 'dock', 1)

    expect(docked.dock).toEqual(['phone', 'mail', 'messages', 'clock'])
    expect(docked.grid[2]).toBe('notes')
  })

  it('moves shortcuts between the dock and grid independently', () => {
    const movedToGrid = moveHomeApp(defaults, 'dock', 0, 'grid', 5)

    expect(movedToGrid.dock[0]).toBeNull()
    expect(movedToGrid.grid[0]).toBe('phone')
    expect(movedToGrid.grid[5]).toBe('phone')

    const movedToDock = moveHomeApp(movedToGrid, 'grid', 1, 'dock', 3)
    expect(movedToDock.grid[1]).toBeNull()
    expect(movedToDock.dock[1]).toBe('messages')
    expect(movedToDock.dock[3]).toBe('messages')
  })

  it('removes shortcuts without closing gaps and restores the first gap', () => {
    const layout: HomeLayout = moveHomeApp(defaults, 'grid', 0, 'grid', 10)
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
