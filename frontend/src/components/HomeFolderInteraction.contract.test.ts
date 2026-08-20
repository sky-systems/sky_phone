import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const iconSource = readFileSync(
  new URL('./HomeFolderIcon.vue', import.meta.url),
  'utf8',
)
const overlaySource = readFileSync(
  new URL('./HomeFolderOverlay.vue', import.meta.url),
  'utf8',
)
const dragSource = readFileSync(
  new URL('../utils/springboardDrag.ts', import.meta.url),
  'utf8',
)
const springboardSource = readFileSync(
  new URL('../views/SpringboardView.vue', import.meta.url),
  'utf8',
)
const appIconSource = readFileSync(
  new URL('./AppIcon.vue', import.meta.url),
  'utf8',
)
const mainCss = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)
const openedFolderAppBlocks =
  overlaySource.match(/<AppIcon\b[\s\S]*?\/>/g) ?? []
const homeFolderIconBlocks =
  springboardSource.match(/<HomeFolderIcon\b[\s\S]*?\/>/g) ?? []

describe('Home folder interaction contract', () => {
  it('opens folders from edit mode and starts dragging only after movement', () => {
    expect(iconSource).toContain('if (props.editMode) return')
    expect(iconSource).toMatch(
      /if \(props\.editMode\) \{\s+beginPointerDrag\(event\)/,
    )
    expect(iconSource).not.toContain('props.editMode || suppressClick.value')
  })

  it('keeps whole-folder dragging aligned at every phone scale', () => {
    expect(dragSource).toContain("'.springboard-page, .home-folder-panel'")
    expect(dragSource).toContain('viewportWidth: bounds.width')
    expect(dragSource).not.toContain("getPropertyValue('zoom')")
    expect(iconSource).toContain('springboardViewportToLocal')
    expect(iconSource).not.toContain('@pointerleave')
    expect(springboardSource).not.toContain(
      '(event.currentTarget as HTMLElement | null)?.closest',
    )
  })

  it('routes whole folders from both the grid and dock through the shared drag portal', () => {
    expect(homeFolderIconBlocks).toHaveLength(2)
    for (const area of ['grid', 'dock'] as const) {
      const block = homeFolderIconBlocks.find((candidate) =>
        candidate.includes(`data-home-area="${area}"`),
      )

      expect(block).toBeDefined()
      expect(block).toContain(':external-drag-visual="homeDragVisualActive"')
      expect(block).toContain('@dragcancel="stopHomeDrag"')
      expect(block).toContain('@dragend="finishHomeDrag"')
      expect(block).toContain('@dragmove="moveHomeDrag"')
      expect(block).toContain(`@dragstart="startHomeDrag('${area}',`)
    }
  })

  it('uses the external viewport visual for apps dragged from an opened folder', () => {
    expect(openedFolderAppBlocks).toHaveLength(1)
    expect(overlaySource).toMatch(/externalDragVisual\??:\s*boolean/)
    expect(openedFolderAppBlocks[0]).toContain(
      ':external-drag-visual="externalDragVisual"',
    )
    expect(appIconSource).toContain('externalDragVisual?: boolean')
    expect(appIconSource).toContain('app-icon-item--drag-source')
  })

  it('forwards opened-folder pointer start, move, and cancellation to the parent session', () => {
    expect(overlaySource).toMatch(
      /function startFolderAppDrag\(index: number, event: PointerEvent\)/,
    )
    expect(overlaySource).toContain("emit('dragstart', index, event)")
    expect(overlaySource).toContain("emit('dragmove', event)")
    expect(overlaySource).toContain("emit('dragcancel')")
    expect(openedFolderAppBlocks[0]).toContain(
      '@dragstart="startFolderAppDrag(entry.index, $event)"',
    )
    expect(openedFolderAppBlocks[0]).toContain('@dragmove="moveFolderAppDrag"')
    expect(openedFolderAppBlocks[0]).toContain(
      '@dragcancel="stopFolderAppDrag"',
    )
  })

  it('hit-tests the opened folder panel and app targets in normalized viewport coordinates', () => {
    expect(overlaySource).toContain('readPhoneViewportGeometry')
    expect(overlaySource).toContain('phoneViewportRectContainsPoint')
    expect(overlaySource).toContain('folderDragViewportRect(panel)')
    expect(overlaySource).toContain('folderDragViewportRect(element)')
    expect(overlaySource).toMatch(/geometry\?\.rect\(element\)/)
    expect(overlaySource).not.toContain(
      'panelElement.value?.getBoundingClientRect()',
    )
    expect(overlaySource).not.toContain('document.elementsFromPoint')
  })

  it('edits the folder name inline with Sky UI controls', () => {
    expect(overlaySource).toContain('<SkyField')
    expect(overlaySource).toContain('home-folder-heading--editing')
    expect(overlaySource).toContain('<Check')
    expect(overlaySource).toContain('<X')
    expect(overlaySource).not.toContain('<SkyDialog')
    expect(overlaySource).not.toContain('<SkySheet')
  })

  it('visually closes the folder while an app leaves and closes after extraction', () => {
    expect(overlaySource).toContain('@dragmove="moveFolderAppDrag"')
    expect(overlaySource).toContain("emit('drag-outside-change', outside)")
    expect(overlaySource).toContain('home-folder-layer--dragging-out')
    expect(springboardSource).toContain(
      '@drag-outside-change="folderDraggingOutside = $event"',
    )
    expect(overlaySource).toContain('if (draggingIndex.value === null) return')
    expect(overlaySource).toContain(
      'if (!draggingOutside.value && !isPointerInsidePanel(event))',
    )
    expect(overlaySource).toContain(
      'draggingOutside.value || !isPointerInsidePanel(event)',
    )
    expect(springboardSource).toContain(
      "'springboard--folder-open': folderOverlayVisible",
    )
    expect(springboardSource).toContain(
      'editMode && isEditablePage && !folderOverlayVisible',
    )
    expect(springboardSource).toMatch(
      /extractHomeFolderApp\([\s\S]*?closeFolder\(\)/,
    )
  })

  it('keeps the folder title left-aligned and gives the rename field more height', () => {
    expect(overlaySource).toMatch(
      /\.home-folder-heading\s*\{[^}]*justify-content:\s*flex-start;/s,
    )
    expect(overlaySource).toMatch(
      /\.home-folder-title\s*\{[^}]*text-align:\s*left;/s,
    )
    expect(overlaySource).toMatch(
      /\.home-folder-rename-field :deep\(\.sky-field__input\)\s*\{[^}]*height:\s*46px;[^}]*min-height:\s*46px;/s,
    )
  })

  it('uses one native iOS-style removal badge inside and outside folders', () => {
    expect(appIconSource).toContain('<span class="app-icon-remove__badge"')
    expect(appIconSource).not.toContain(
      '<k-badge class="app-icon-remove__badge"',
    )
    expect(mainCss).toMatch(
      /\.app-icon-remove__badge\s*\{[^}]*background:\s*rgb\(174 174 178 \/ 88%\);[^}]*color:\s*#111;/s,
    )
  })
})
