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

  it('renders the home drag visual through the unzoomed phone portal', () => {
    expect(viewSource).toContain('source.cloneNode(true)')
    expect(viewSource).toContain(
      '<Teleport defer to="#phone-home-drag-portal">',
    )
    expect(viewSource).toContain(
      '<div ref="homeDragLayer" class="home-drag-layer" aria-hidden="true"></div>',
    )
    expect(viewSource).toContain('readPhoneViewportGeometry')
    expect(viewSource).toMatch(/const sourceBounds = \w+\.rect\(source\)/)
    expect(viewSource).toMatch(/const clipBounds = \w+\.rect\(\w+\)/)
    expect(viewSource).not.toContain('homeDragLocalPoint')
    expect(viewSource).not.toContain('springboardViewportToLocal')
    expect(viewSource).toContain("position.className = 'home-drag-position'")
    expect(viewSource).toMatch(
      /homeDragGrip = \{\s*x: event\.clientX - sourceBounds\.left,\s*y: event\.clientY - sourceBounds\.top,/,
    )
    expect(viewSource).toMatch(
      /ghost\.style\.transform = `scale\(\$\{\w+\.scaleX\}, \$\{\w+\.scaleY\}\)`/,
    )
    expect(
      viewSource.match(/:external-drag-visual="homeDragVisualActive"/g),
    ).toHaveLength(4)
    expect(viewSource).toContain('updateHomeDragGhost(event)')
    expect(viewSource).toContain('const dropGhost = homeDragGhost')
    expect(viewSource).toContain('const dropOrigin = homeDragPreviewBounds')
    expect(viewSource).not.toContain('dropGhost?.getBoundingClientRect()')
    expect(viewSource).toContain('clearHomeDragGhost(dropGhost)')
    expect(viewSource).not.toContain('draggedElement?.getBoundingClientRect()')
    expect(viewSource).not.toContain('springboard--home-dragging')
    expect(appIconSource).toContain('externalDragVisual?: boolean')
    expect(folderIconSource).toContain('externalDragVisual?: boolean')
    expect(appIconSource).toContain('app-icon-item--drag-source')
    expect(folderIconSource).toContain('app-icon-item--drag-source')
    expect(mainCss).toMatch(
      /\.phone-home-drag-portal\s*\{[^}]*pointer-events:\s*none;/s,
    )
    expect(mainCss).toContain('.home-drag-position')
    expect(mainCss).toContain('.home-drag-ghost')
    expect(mainCss).toContain('.app-icon-item--drag-source')
    expect(mainCss).toMatch(/\.springboard\s*\{[\s\S]*?overflow:\s*hidden;/)
    expect(mainCss).toMatch(
      /\.springboard-page--apps\s*\{[^}]*overflow:\s*hidden;/s,
    )
  })

  it('cleans up the external drag visual on every terminal path', () => {
    expect(
      viewSource.match(
        /@dragstart="startHomeDrag\('(grid|dock)', [^,]+, \$event\)"/g,
      ),
    ).toHaveLength(4)
    expect(viewSource.match(/@dragcancel="stopHomeDrag"/g)).toHaveLength(4)
    expect(viewSource).toContain(
      'if (expectedGhost && homeDragGhost !== expectedGhost) return',
    )
    expect(viewSource).toMatch(
      /if \(!dragged\) \{\s*clearHomeDragGhost\(\)\s*return/,
    )
    expect(viewSource).toMatch(
      /animateHomeItemDrop\(\s*draggedItem,\s*dropArea,\s*dropIndex,\s*dropOrigin,?\s*\)\.finally\(/,
    )
    expect(viewSource).toMatch(
      /function stopHomeDrag[\s\S]*?clearHomeDragGhost\(\)/,
    )
    expect(viewSource).toMatch(
      /if \(folderId\) \{[\s\S]*?clearHomeDragGhost\(\)/,
    )
    expect(viewSource).toMatch(
      /onBeforeUnmount\(\(\) => \{[\s\S]*?clearHomeDragGhost\(\)/,
    )
  })

  it('targets the active visual page and lets grid or dock drags turn pages', () => {
    expect(viewSource).toContain(':data-home-page="page.page"')
    expect(viewSource).toContain(':data-home-target-offset="cell.targetOffset"')
    expect(viewSource).toContain('nearestGridDropTarget')
    expect(viewSource).toContain('moveHomeAppToGridPage')
    expect(viewSource).not.toContain("draggingHomeApp.value?.area === 'grid'")
    expect(viewSource).toContain('event.clientX < springboardBounds.left')
    expect(viewSource).toContain('event.clientY > springboardBounds.bottom')
    expect(viewSource).toContain('function homeDragViewportRect(')
    expect(viewSource).toContain('if (geometry) return geometry.rect(element)')
    expect(viewSource).toContain('homeDragViewportRect(pageElement, geometry)')
    expect(viewSource).toContain('homeDragViewportRect(springboard, geometry)')
    expect(viewSource).toContain('homeDragViewportRect(slot, geometry)')
    expect(viewSource).toContain('homeDragViewportRect(dock, geometry)')
    expect(viewSource).toMatch(
      /homeDragViewportRect\(\s*appElement,\s*readPhoneViewportGeometry\(appElement\),?\s*\)/,
    )
    expect(viewSource).toContain(
      'springboardBounds.left + (bounds.left - pageBounds.left)',
    )
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
