import { describe, expect, it } from 'vitest'

import type { LaunchablePhoneAppId } from '@/types/apps'
import {
  addHomeAppToFolder,
  addHomePage,
  createDefaultHomeLayout,
  createHomeFolder,
  deleteHomePage,
  extractHomeFolderApp,
  getHomeFolder,
  HOME_GRID_COLUMNS,
  HOME_GRID_PAGE_SIZE,
  HOME_GRID_ROWS,
  HOME_LAYOUT_VERSION,
  homeKeyboardTarget,
  isHomeFolder,
  MAX_HOME_GRID_PAGES,
  moveHomeApp,
  moveHomeAppToGridPage,
  moveHomeFolderApp,
  parseHomeLayout,
  reflowHomeGridForWidgetChange,
  removeDockGridDuplicates,
  removeHomeApp,
  renameHomeFolder,
  restoreHomeApp,
  type HomeLayout,
} from '@/utils/homeLayout'

const installed = ['phone', 'messages', 'mail', 'clock', 'notes'] as const
const defaults = createDefaultHomeLayout(
  [...installed],
  ['phone', 'messages', 'mail', 'clock', 'notes'],
  ['phone', 'messages', 'clock'],
)

function generatedApp(index: number): LaunchablePhoneAppId {
  return `generated-app-${index}` as LaunchablePhoneAppId
}

function pageLayout(pageCounts: readonly number[]): HomeLayout {
  const grid: HomeLayout['grid'] = Array.from(
    { length: pageCounts.length * HOME_GRID_PAGE_SIZE },
    () => null,
  )
  let appIndex = 0
  for (const [pageIndex, count] of pageCounts.entries()) {
    for (let offset = 0; offset < count; offset += 1) {
      grid[pageIndex * HOME_GRID_PAGE_SIZE + offset] = generatedApp(appIndex)
      appIndex += 1
    }
  }
  return {
    dock: [generatedApp(999), null, null, null],
    grid,
    hidden: [],
    pageCount: pageCounts.length,
    version: HOME_LAYOUT_VERSION,
  }
}

describe('home layout', () => {
  it('uses six-row grid pages and fixed dock slots', () => {
    const layout = parseHomeLayout(undefined, defaults, [...installed])

    expect(HOME_GRID_PAGE_SIZE).toBe(HOME_GRID_COLUMNS * HOME_GRID_ROWS)
    expect(HOME_GRID_ROWS).toBe(6)
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
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('removes dock apps from the grid and normalizes affected folders', () => {
    const layout: HomeLayout = {
      ...defaults,
      dock: [
        'phone',
        {
          apps: ['messages', 'mail'],
          id: 'folder-abcdef',
          name: 'Dock',
          type: 'folder',
        },
        null,
        null,
      ],
      grid: [
        'phone',
        {
          apps: ['messages', 'notes'],
          id: 'folder-ghijkl',
          name: 'Grid',
          type: 'folder',
        },
        'mail',
        'clock',
        ...Array.from({ length: HOME_GRID_PAGE_SIZE - 4 }, () => null),
      ],
    }

    const normalized = removeDockGridDuplicates(layout)

    expect(normalized.grid.slice(0, 3)).toEqual(['notes', 'clock', null])
    expect(normalized.dock).toEqual(layout.dock)
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
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('closes gaps within a versioned page without moving apps between pages', () => {
    const grid: HomeLayout['grid'] = Array.from({ length: 20 }, () => null)
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

    expect(layout.grid.slice(0, 3)).toEqual(['phone', 'mail', null])
    expect(layout.dock).toEqual(['messages', null, 'clock', null])
  })

  it('keeps valid custom-app tombstones while migrating version 3 layouts', () => {
    const grid: HomeLayout['grid'] = Array.from({ length: 20 }, () => null)
    grid[6] = 'temporarily-missing' as HomeLayout['hidden'][number]

    const layout = parseHomeLayout(
      { dock: ['phone'], grid, hidden: [], version: 3 },
      defaults,
      [...installed],
    )

    expect(layout.grid).toContain('temporarily-missing')
    const pageItemCount = layout.grid
      .slice(0, HOME_GRID_PAGE_SIZE)
      .filter((item) => item !== null).length
    expect(layout.grid.slice(0, pageItemCount)).not.toContain(null)
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('preserves page membership while expanding version 3 pages', () => {
    const grid: HomeLayout['grid'] = Array.from({ length: 40 }, () => null)
    grid[0] = 'phone'
    grid[19] = 'messages'
    grid[20] = 'mail'
    grid[39] = 'clock'

    const layout = parseHomeLayout(
      { dock: [], grid, hidden: [], version: 3 },
      defaults,
      [...installed],
    )

    expect(layout.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
    expect(layout.grid.slice(0, 3)).toEqual(['phone', 'messages', 'notes'])
    expect(layout.grid[HOME_GRID_PAGE_SIZE]).toBe('mail')
    expect(layout.grid[HOME_GRID_PAGE_SIZE + 1]).toBe('clock')
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('reads version 4 pages directly before migrating the schema', () => {
    const grid: HomeLayout['grid'] = Array.from(
      { length: HOME_GRID_PAGE_SIZE * 2 },
      () => null,
    )
    grid[20] = 'phone'
    grid[HOME_GRID_PAGE_SIZE] = 'messages'

    const layout = parseHomeLayout(
      { dock: [], grid, hidden: [], version: 4 },
      defaults,
      [...installed],
    )

    expect(layout.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
    expect(layout.grid[0]).toBe('phone')
    expect(layout.grid[HOME_GRID_PAGE_SIZE]).toBe('messages')
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('preserves folders and page membership in version 5 layouts', () => {
    const grid: HomeLayout['grid'] = Array.from(
      { length: HOME_GRID_PAGE_SIZE * 2 },
      () => null,
    )
    grid[8] = {
      apps: ['mail', 'notes'],
      id: 'folder-work-123456',
      name: 'Work',
      type: 'folder',
    }
    grid[HOME_GRID_PAGE_SIZE + 7] = 'clock'

    const layout = parseHomeLayout(
      { dock: ['phone'], grid, hidden: [], version: 5 },
      defaults,
      [...installed],
    )

    expect(getHomeFolder(layout, 'folder-work-123456')?.apps).toEqual([
      'mail',
      'notes',
    ])
    expect(layout.grid[HOME_GRID_PAGE_SIZE]).toBe('clock')
    expect(layout.version).toBe(HOME_LAYOUT_VERSION)
  })

  it('preserves independently positioned shortcuts for the same app', () => {
    const grid: HomeLayout['grid'] = Array.from({ length: 20 }, () => null)
    grid[0] = 'phone'
    grid[5] = 'phone'

    const layout = parseHomeLayout(
      { dock: ['phone'], grid, hidden: [], version: 2 },
      defaults,
      [...installed],
    )

    expect(layout.grid[0]).toBe('phone')
    expect(layout.grid[1]).toBe('phone')
    expect(layout.dock[0]).toBe('phone')
  })

  it('inserts into an empty area and closes the source gap', () => {
    const moved = moveHomeApp(defaults, 'grid', 2, 'grid', 12)

    expect(moved.grid.slice(0, 6)).toEqual([
      'phone',
      'messages',
      'clock',
      'notes',
      'mail',
      null,
    ])
  })

  it('extends the layout when moving an item onto an empty new page', () => {
    const targetIndex = HOME_GRID_PAGE_SIZE + 20
    const moved = moveHomeApp(defaults, 'grid', 0, 'grid', targetIndex)

    expect(moved.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
    expect(moved.grid.slice(0, 5)).toEqual([
      'messages',
      'mail',
      'clock',
      'notes',
      null,
    ])
    expect(moved.grid[HOME_GRID_PAGE_SIZE]).toBe('phone')
  })

  it.each([20, 21, 23])(
    'fills a target page containing %s apps without swapping one backwards',
    (targetCount) => {
      const layout = pageLayout([2, targetCount])
      const dragged = layout.grid[0]
      const originalTarget = layout.grid
        .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
        .filter((item) => item !== null)
      const moved = moveHomeAppToGridPage(layout, 'grid', 0, 2, targetCount)

      expect(moved.grid[0]).toBe(layout.grid[1])
      expect(
        moved.grid
          .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
          .filter((item) => item !== null),
      ).toEqual([...originalTarget, dragged])
    },
  )

  it('cascades a full target page forward into a newly created page', () => {
    const layout = pageLayout([2, HOME_GRID_PAGE_SIZE])
    const dragged = layout.grid[0]
    const displaced = layout.grid[HOME_GRID_PAGE_SIZE * 2 - 1]
    const moved = moveHomeAppToGridPage(layout, 'grid', 0, 2, 0)

    expect(moved.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 3)
    expect(moved.grid.slice(0, 2)).toEqual([layout.grid[1], null])
    expect(moved.grid[HOME_GRID_PAGE_SIZE]).toBe(dragged)
    expect(moved.grid[HOME_GRID_PAGE_SIZE * 2]).toBe(displaced)
  })

  it('uses a later source-page gap for forward overflow', () => {
    const layout = pageLayout([HOME_GRID_PAGE_SIZE, 2])
    const draggedIndex = HOME_GRID_PAGE_SIZE
    const dragged = layout.grid[draggedIndex]
    const displaced = layout.grid[HOME_GRID_PAGE_SIZE - 1]
    const remainingSecondPageItem = layout.grid[draggedIndex + 1]
    const moved = moveHomeAppToGridPage(layout, 'grid', draggedIndex, 1, 4)

    expect(moved.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
    expect(moved.grid[4]).toBe(dragged)
    expect(moved.grid[HOME_GRID_PAGE_SIZE]).toBe(displaced)
    expect(moved.grid[HOME_GRID_PAGE_SIZE + 1]).toBe(remainingSecondPageItem)
  })

  it('rejects a dock insertion atomically when all pages are full', () => {
    const layout = pageLayout(
      Array.from({ length: MAX_HOME_GRID_PAGES }, () => HOME_GRID_PAGE_SIZE),
    )

    expect(moveHomeAppToGridPage(layout, 'dock', 0, 1, 0)).toBe(layout)
  })

  it('moves a dock app onto another page and preserves every other item', () => {
    const layout = pageLayout([3, 2])
    const dockApp = layout.dock[0]
    const before = [...layout.grid.filter(Boolean), dockApp].sort()
    const moved = moveHomeAppToGridPage(layout, 'dock', 0, 2, 1)

    expect(moved.dock[0]).toBeNull()
    expect(moved.grid[HOME_GRID_PAGE_SIZE + 1]).toBe(dockApp)
    expect(moved.grid.filter(Boolean).sort()).toEqual(before)
  })

  it('respects widget-reduced capacities while cascading forward', () => {
    const layout = pageLayout([HOME_GRID_PAGE_SIZE])
    const moved = moveHomeAppToGridPage(layout, 'grid', 0, 1, 0, [
      20,
      HOME_GRID_PAGE_SIZE,
    ])

    expect(moved.grid.slice(0, 20).filter(Boolean)).toHaveLength(20)
    expect(
      moved.grid
        .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
        .filter(Boolean),
    ).toHaveLength(4)
    expect(moved.grid.filter(Boolean).sort()).toEqual(
      layout.grid.filter(Boolean).sort(),
    )
  })

  it('materializes the visible pages before moving a widget forward', () => {
    const layout = pageLayout([0, HOME_GRID_PAGE_SIZE, 7])
    const pageTwoApps = layout.grid
      .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
      .filter((item) => item !== null)
    const pageThreeApps = layout.grid
      .slice(HOME_GRID_PAGE_SIZE * 2, HOME_GRID_PAGE_SIZE * 3)
      .filter((item) => item !== null)
    const reflowed = reflowHomeGridForWidgetChange(
      layout,
      [HOME_GRID_PAGE_SIZE, 20, HOME_GRID_PAGE_SIZE],
      [HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE, 20],
    )

    expect(reflowed).not.toBeNull()
    expect(
      reflowed?.grid
        .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
        .filter(Boolean),
    ).toEqual(pageTwoApps.slice(0, 20))
    expect(
      reflowed?.grid
        .slice(HOME_GRID_PAGE_SIZE * 2, HOME_GRID_PAGE_SIZE * 3)
        .filter(Boolean),
    ).toEqual([...pageTwoApps.slice(20), ...pageThreeApps])
  })

  it('moves widget overflow only to later pages', () => {
    const layout = pageLayout([0, HOME_GRID_PAGE_SIZE, 20])
    const allApps = layout.grid.filter(Boolean).sort()
    const reflowed = reflowHomeGridForWidgetChange(
      layout,
      [HOME_GRID_PAGE_SIZE, 20, HOME_GRID_PAGE_SIZE],
      [HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE, 20],
    )

    expect(reflowed).not.toBeNull()
    expect(
      reflowed?.grid
        .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
        .filter(Boolean),
    ).toHaveLength(20)
    expect(
      reflowed?.grid
        .slice(HOME_GRID_PAGE_SIZE * 2, HOME_GRID_PAGE_SIZE * 3)
        .filter(Boolean),
    ).toHaveLength(20)
    expect(
      reflowed?.grid
        .slice(HOME_GRID_PAGE_SIZE * 3, HOME_GRID_PAGE_SIZE * 4)
        .filter(Boolean),
    ).toHaveLength(4)
    expect(reflowed?.grid.filter(Boolean).sort()).toEqual(allApps)
  })

  it('provides bounded keyboard reorder targets without wrapping rows', () => {
    expect(homeKeyboardTarget(defaults, 'grid', 1, 'right')).toBe(2)
    expect(homeKeyboardTarget(defaults, 'grid', 3, 'right')).toBeNull()
    expect(homeKeyboardTarget(defaults, 'grid', 0, 'up')).toBeNull()
    expect(homeKeyboardTarget(defaults, 'grid', 0, 'down')).toBe(4)
    expect(homeKeyboardTarget(defaults, 'dock', 1, 'left')).toBe(0)
    expect(homeKeyboardTarget(defaults, 'dock', 1, 'down')).toBeNull()
  })

  it('shifts occupied grid slots instead of replacing their items', () => {
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
    expect(docked.grid.slice(0, 5)).toEqual([
      'phone',
      'messages',
      'clock',
      'notes',
      null,
    ])
  })

  it('moves a dock item displaced from a full dock into the source slot', () => {
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
    expect(movedToDock.grid.slice(0, 6)).toEqual([
      'phone',
      'mail',
      'clock',
      'notes',
      'phone',
      null,
    ])
    expect(movedToDock.dock[1]).toBe('messages')
    expect(movedToDock.dock[3]).toBe('messages')
  })

  it('removes and restores shortcuts without leaving a page gap', () => {
    const layout = moveHomeApp(defaults, 'grid', 0, 'grid', 10)
    const removed = removeHomeApp(layout, 'phone')

    expect(removed.grid).not.toContain('phone')
    expect(removed.dock[0]).toBeNull()
    expect(removed.hidden).toContain('phone')

    const restored = restoreHomeApp(removed, 'phone')
    expect(restored.grid[4]).toBe('phone')
    expect(restored.grid.slice(0, 5)).not.toContain(null)
    expect(restored.hidden).not.toContain('phone')
  })

  it('reveals an existing shortcut when restoring a hidden app', () => {
    const hidden = {
      ...defaults,
      grid: [...defaults.grid],
      hidden: [...defaults.hidden, 'health' as const],
    }
    hidden.grid[5] = 'health'

    const restored = restoreHomeApp(hidden, 'health')

    expect(restored.grid[5]).toBe('health')
    expect(restored.hidden).not.toContain('health')
  })

  it('adds persistent empty pages up to the home screen limit', () => {
    let layout = defaults
    for (let page = 1; page < MAX_HOME_GRID_PAGES; page += 1) {
      layout = addHomePage(layout)
    }

    expect(layout.grid).toHaveLength(HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES)
    expect(layout.pageCount).toBe(MAX_HOME_GRID_PAGES)
    expect(addHomePage(layout)).toBe(layout)
  })

  it('restores an explicitly persisted empty trailing page', () => {
    const layout = parseHomeLayout(
      {
        dock: defaults.dock,
        grid: defaults.grid.slice(0, 5),
        hidden: [],
        pageCount: 2,
        version: HOME_LAYOUT_VERSION,
      },
      defaults,
      [...installed],
    )

    expect(layout.pageCount).toBe(2)
    expect(layout.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
    expect(
      layout.grid.slice(HOME_GRID_PAGE_SIZE).every((item) => item === null),
    ).toBe(true)
  })

  it('deletes a page and moves its items into remaining empty slots', () => {
    let layout = addHomePage(defaults)
    layout = moveHomeApp(layout, 'grid', 0, 'grid', HOME_GRID_PAGE_SIZE)
    const deleted = deleteHomePage(layout, 2)

    expect(deleted.grid).toHaveLength(HOME_GRID_PAGE_SIZE)
    expect(deleted.pageCount).toBe(1)
    expect(deleted.grid).toContain('phone')
    expect(deleteHomePage(deleted, 1)).toBe(deleted)
  })

  it('creates, renames, and parses a folder with compact pages', () => {
    const folderLayout = createHomeFolder(
      defaults,
      'grid',
      2,
      'grid',
      4,
      'folder-work-123456',
      'Work',
    )
    const folder = getHomeFolder(folderLayout, 'folder-work-123456')

    expect(folder?.apps).toEqual(['notes', 'mail'])
    expect(folderLayout.grid.slice(0, 4)).toEqual([
      'phone',
      'messages',
      'clock',
      folder,
    ])

    const renamed = renameHomeFolder(
      folderLayout,
      'folder-work-123456',
      '  Dienstprogramme  ',
    )
    const parsed = parseHomeLayout(renamed, defaults, [...installed])
    expect(parsed.version).toBe(HOME_LAYOUT_VERSION)
    expect(getHomeFolder(parsed, 'folder-work-123456')).toEqual({
      apps: ['notes', 'mail'],
      id: 'folder-work-123456',
      name: 'Dienstprogramme',
      type: 'folder',
    })
  })

  it('adds apps to a folder and swaps apps inside it', () => {
    const folderLayout = createHomeFolder(
      defaults,
      'grid',
      2,
      'grid',
      4,
      'folder-tools-123456',
      'Tools',
    )
    const clockIndex = folderLayout.grid.indexOf('clock')
    const expanded = addHomeAppToFolder(
      folderLayout,
      'grid',
      clockIndex,
      'folder-tools-123456',
    )

    expect(getHomeFolder(expanded, 'folder-tools-123456')?.apps).toEqual([
      'notes',
      'mail',
      'clock',
    ])
    const reordered = moveHomeFolderApp(expanded, 'folder-tools-123456', 2, 0)
    expect(getHomeFolder(reordered, 'folder-tools-123456')?.apps).toEqual([
      'clock',
      'mail',
      'notes',
    ])
  })

  it('extracts a folder app and dissolves one-app folders', () => {
    const folderLayout = createHomeFolder(
      defaults,
      'grid',
      2,
      'grid',
      4,
      'folder-social-123456',
      'Social',
    )
    const extracted = extractHomeFolderApp(
      folderLayout,
      'folder-social-123456',
      1,
      'grid',
      12,
    )

    expect(extracted.grid.slice(0, 5)).toEqual([
      'phone',
      'messages',
      'clock',
      'notes',
      'mail',
    ])
    expect(getHomeFolder(extracted, 'folder-social-123456')).toBeNull()
  })

  it('removes hidden apps from folders and dissolves the folder', () => {
    const folderLayout = createHomeFolder(
      defaults,
      'grid',
      2,
      'grid',
      4,
      'folder-mixed-123456',
      'Mixed',
    )
    const removed = removeHomeApp(folderLayout, 'mail')

    expect(removed.grid.slice(0, 4)).toEqual([
      'phone',
      'messages',
      'clock',
      'notes',
    ])
    expect(removed.hidden).toContain('mail')
  })

  it('moves folders as one item without crossing page boundaries', () => {
    const folderLayout = createHomeFolder(
      defaults,
      'grid',
      2,
      'grid',
      4,
      'folder-page-123456',
      'Page two',
    )
    const folderIndex = folderLayout.grid.findIndex(isHomeFolder)
    const moved = moveHomeApp(
      folderLayout,
      'grid',
      folderIndex,
      'grid',
      HOME_GRID_PAGE_SIZE + 8,
    )

    expect(moved.grid.slice(0, 4)).toEqual(['phone', 'messages', 'clock', null])
    const movedFolder = moved.grid[HOME_GRID_PAGE_SIZE]
    expect(isHomeFolder(movedFolder)).toBe(true)
    expect(isHomeFolder(movedFolder) && movedFolder.id).toBe(
      'folder-page-123456',
    )
  })
})
