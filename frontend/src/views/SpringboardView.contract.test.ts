import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const viewSource = readFileSync(
  new URL('./SpringboardView.vue', import.meta.url),
  'utf8',
)
const appSource = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')
const appIconSource = readFileSync(
  new URL('../components/AppIcon.vue', import.meta.url),
  'utf8',
)
const folderIconSource = readFileSync(
  new URL('../components/HomeFolderIcon.vue', import.meta.url),
  'utf8',
)
const mainCss = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)
const builtInWallpaperCss = mainCss.slice(
  mainCss.indexOf('.wallpaper--midnight'),
  mainCss.indexOf('.wallpaper--custom'),
)
describe('Springboard page swipe contract', () => {
  it('keeps the built-in wallpapers visually restrained', () => {
    expect(builtInWallpaperCss).not.toMatch(/(?:conic|repeating-\w+)-gradient/)
    expect(builtInWallpaperCss.match(/radial-gradient/g)).toHaveLength(12)
    expect(builtInWallpaperCss.match(/linear-gradient/g)).toHaveLength(12)
  })

  it('replaces the home status row with the edit controls', () => {
    expect(viewSource).toContain("emit('editModeChange', editing)")
    expect(viewSource).toContain("emit('editModeChange', false)")
    expect(appSource).toContain(
      '@edit-mode-change="springboardEditing = $event"',
    )
    expect(appSource).toMatch(
      /v-if="\s*!isLocked && !\(isHomeRoute && springboardEditing\)\s*"/,
    )
    expect(mainCss).toMatch(
      /\.springboard-edit-add\s*\{[^}]*top:\s*14px;[^}]*left:\s*28px;[^}]*width:\s*58px;[^}]*height:\s*30px;/s,
    )
    expect(mainCss).toMatch(
      /\.springboard-edit-done\s*\{[^}]*top:\s*14px;[^}]*right:\s*28px;[^}]*width:\s*58px;[^}]*height:\s*30px;/s,
    )
    expect(viewSource).toContain(
      '<Check :size="20" :stroke-width="3" aria-hidden="true" />',
    )
  })

  it('allows page swipes to start on home apps and widget surfaces', () => {
    expect(viewSource).toContain(
      '.springboard-page--apps .app-icon-button, .home-widget',
    )
    expect(viewSource).toContain('springboardSwipeIntent')
    expect(viewSource).not.toContain(
      "target.closest('button, input, .home-widget-shell')",
    )
  })

  it('keeps blank-surface page swipes available while editing', () => {
    expect(viewSource).not.toMatch(
      /if \(editMode\.value\) return\s+dragging\.value/,
    )
    expect(viewSource).toContain(
      'if (editMode.value || pageSwipeSurface) return',
    )
  })

  it('suppresses app and folder activation after pointer movement', () => {
    expect(appIconSource).toContain('springboardSwipeIntent')
    expect(folderIconSource).toContain('springboardSwipeIntent')
    expect(appIconSource).toContain('suppressClick.value = true')
    expect(folderIconSource).toContain('suppressClick.value = true')
  })

  it('keeps app and folder drags alive independently of element capture', () => {
    expect(appIconSource).toContain('bindPointerDragSession(window, pointerId')
    expect(folderIconSource).toContain(
      'bindPointerDragSession(window, pointerId',
    )
    expect(appIconSource).not.toContain('@lostpointercapture')
    expect(folderIconSource).not.toContain('@lostpointercapture')
  })

  it('converts pointer movement from viewport pixels using measured page geometry', () => {
    expect(appIconSource).toContain('springboardPageDragCompensation')
    expect(folderIconSource).toContain('springboardPageDragCompensation')
    expect(appIconSource).toContain('readSpringboardDragMetrics')
    expect(folderIconSource).toContain('readSpringboardDragMetrics')
    expect(appIconSource).toContain(':style="dragPointerStyle"')
    expect(folderIconSource).toContain(':style="dragPointerStyle"')
  })

  it('uses the same scale-aware in-phone drag path as widgets', () => {
    expect(viewSource).not.toContain('source.cloneNode(true)')
    expect(viewSource).not.toContain('<Teleport to="body">')
    expect(viewSource).not.toContain(':external-drag-visual')
    expect(viewSource).toContain(
      "'springboard--home-dragging': draggingHomeApp !== null",
    )
    expect(viewSource).toContain('draggedElement?.getBoundingClientRect()')
    expect(appIconSource).not.toContain('externalDragVisual')
    expect(folderIconSource).not.toContain('externalDragVisual')
    expect(mainCss).not.toContain('.home-drag-layer')
    expect(mainCss).not.toContain('.home-drag-ghost')
    expect(mainCss).not.toContain('.app-icon-item--drag-source')
    expect(mainCss).toMatch(
      /\.springboard--home-dragging \.springboard-page--apps\s*\{[^}]*overflow:\s*visible;/s,
    )
    expect(mainCss).toMatch(/\.springboard\s*\{[\s\S]*?overflow:\s*hidden;/)
    expect(mainCss).toMatch(
      /\.springboard-page--apps\s*\{[^}]*overflow:\s*hidden;/s,
    )
  })

  it('targets the active visual page and lets grid or dock drags turn pages', () => {
    expect(viewSource).toContain(':data-home-page="page.page"')
    expect(viewSource).toContain(':data-home-target-offset="cell.targetOffset"')
    expect(viewSource).toContain('nearestGridDropTarget')
    expect(viewSource).toContain('moveHomeAppToGridPage')
    expect(viewSource).not.toContain("draggingHomeApp.value?.area === 'grid'")
    expect(viewSource).toContain('event.clientX < pageBounds.left')
    expect(viewSource).toContain('event.clientY > pageBounds.bottom')
    expect(viewSource).toContain('nearestSpringboardRectIndex')
    expect(viewSource).toContain("queueEdgePageTurn(lastHomePointer, 'app')")
    expect(viewSource).toContain("edgePageLocked = dragType === 'widget'")
  })

  it('resolves occupied dock slots from the dock bounds rather than the event target', () => {
    expect(viewSource).toContain("querySelector<HTMLElement>('.app-dock')")
    expect(viewSource).toContain('\'[data-home-area="dock"][data-home-index]\'')
    expect(viewSource).not.toContain(
      '.closest<HTMLElement>(\'[data-home-area="dock"]\')',
    )
  })

  it('keeps a new trailing page temporary until a valid drop', () => {
    expect(viewSource).toContain('temporaryHomePage')
    expect(viewSource).toContain('clearTemporaryHomePage')
    expect(viewSource).toContain('resolveSpringboardHomeEdgeTurn')
    expect(viewSource).toContain('onBeforeUnmount')
  })

  it('materializes page-local app positions before widget layout changes', () => {
    expect(viewSource).toContain('function applyWidgetLayout')
    expect(viewSource).toContain('appStore.applyWidgetGridCapacities')
    expect(viewSource).toContain('homeGridCapacitiesFor(widgets.layout)')
    expect(viewSource).toContain('homeGridCapacitiesFor(nextLayout)')
    expect(viewSource).toContain('previewWidgetAdd')
    expect(viewSource).toContain('previewWidgetMove')
    expect(viewSource).toContain('previewWidgetRemove')
    expect(viewSource).toContain('previewWidgetResize')
  })
})
