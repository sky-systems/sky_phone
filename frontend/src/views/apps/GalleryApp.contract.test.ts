import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./GalleryApp.vue', import.meta.url),
  'utf8',
)
const headerActions = source.slice(
  source.indexOf('<template #right>'),
  source.indexOf('</template>', source.indexOf('<template #right>')),
)

describe('GalleryApp import action', () => {
  it('opens a configured wallpaper upload and returns the imported photo directly', () => {
    expect(source).toContain("route.query.wallpaperUpload === '1'")
    expect(source).toContain("requestedMessageMedia.value === 'photo'")
    expect(source).toContain('openImport()')
    expect(source).toContain('messageMedia.complete(response.data)')
    expect(source).toContain('await router.push(returnPath)')
  })

  it('keeps import available as a header button', () => {
    expect(headerActions).toContain('<SkyToolbarPane')
    expect(headerActions).toContain('gallery-header-tool--icon')
    expect(headerActions).toContain('<SkyButton')
    expect(headerActions).toContain('clear')
    expect(headerActions).toContain(
      '<Download :size="21" aria-hidden="true" />',
    )
    expect(headerActions).toContain(
      ':aria-label="phone.t(\'Apps.photos.import.action\')"',
    )
    expect(headerActions).toContain('@click="openImport"')
    expect(source).not.toContain("id: 'import'")
    expect(headerActions).not.toContain('tonal')
  })

  it('renders an iPhone-style large library header with filtered counts', () => {
    expect(source).toContain('<SkyNavbar')
    expect(source).toContain('variant="large"')
    expect(source).toContain(':title="phone.t(\'Apps.photos.library\')"')
    expect(source).toContain(':subtitle="countText"')
    expect(source).toContain("nuiCall<GalleryCounts>('gallery:counts')")
    expect(source).toContain('`Apps.photos.counts.${translationKey}`')
    expect(source).toContain('gridColumnStart: bottomRightGridPosition(')
    expect(source).toContain('gridRowStart: bottomRightGridPosition(')
    expect(source).toContain('var(--sky-navbar-large-title-height) - 30px')
    expect(source).toContain(
      'grid-template-columns: minmax(0, 1fr) 0 max-content;',
    )
    expect(source).toMatch(
      /\.gallery-library-navbar :deep\(\.sky-navbar__right\)\s*\{[^}]*overflow:\s*visible;[^}]*background:\s*transparent;[^}]*box-shadow:\s*none;[^}]*backdrop-filter:\s*none;/s,
    )
    expect(source).toMatch(
      /\.gallery-header-tool\s*\{[^}]*height:\s*var\(--sky-touch-target\);/s,
    )
  })

  it('uses the shared app tab bar for gallery filters', () => {
    expect(source).toContain('<SkyTabBar')
    expect(source).toContain('class="gallery-filter-tabbar"')
    expect(source).toContain('icons')
    expect(source).toContain('<Images :size="21" />')
    expect(source).toContain('<Image :size="21" />')
    expect(source).toContain('<Video :size="21" />')
    expect(source).toContain('<SkyTabButton')
    expect(source).toContain(':active="filter === \'all\'"')
    expect(source).toContain(':active="filter === \'photo\'"')
    expect(source).toContain(':active="filter === \'video\'"')
    expect(source).not.toContain('gallery-filter-navbar')
    expect(source).not.toContain('<sky-segmented')
  })

  it('opens an accessible sort menu from the large header', () => {
    expect(headerActions).toContain('<ListFilter')
    expect(headerActions).toContain('aria-haspopup="menu"')
    expect(headerActions).toContain(':aria-expanded="sortMenuOpened"')
    expect(headerActions).toContain('@click="openSortMenu"')
    expect(source).toContain('<SkyDropdown')
    expect(source).toContain(':target="sortMenuTarget"')
    expect(source).toContain(':items="sortMenuItems"')
    expect(source).toContain("id: 'sort-newest'")
    expect(source).toContain("id: 'sort-oldest'")
    expect(source).toContain("id: 'show-all'")
    expect(source).toContain("id: 'show-favorites'")
    expect(source).toContain("group: 'sort'")
    expect(source).toContain("group: 'show'")
    expect(source).toContain("phone.t('Apps.photos.sorting.title')")
    expect(source).toContain("phone.t('Apps.photos.sorting.show')")
    expect(source).toContain('orderMedia(media.value, sortOrder.value)')
  })

  it('starts with the newest media at the bottom-right and loads older media above', () => {
    expect(source).toContain(
      "const sortOrder = ref<GallerySortOrder>('newest')",
    )
    expect(source).toContain(
      'galleryContent.value.scrollTop = galleryContent.value.scrollHeight',
    )
    expect(source).toContain('v-if="hasMore"')
    expect(source).toContain('class="gallery-load-trigger"')
    expect(source).toContain('position: absolute;')
    expect(source).toContain('top: 0;')
  })

  it('supports selecting, sharing, and deleting multiple media items', () => {
    expect(headerActions).toContain("phone.t('Apps.photos.selection.action')")
    expect(headerActions).toContain('enterSelectionMode')
    expect(source).toContain('v-if="selectionMode"')
    expect(source).toContain('selectedCountText')
    expect(source).toContain('shareSelection')
    expect(
      source.match(/<SkyToolbarPane class="gallery-selection-action">/g),
    ).toHaveLength(2)
    expect(source).toContain('<div class="gallery-selection-actions">')
    expect(source).toMatch(
      /\.gallery-selection-actions\s*\{[^}]*display:\s*flex;[^}]*gap:\s*var\(--sky-space-2\);/s,
    )
    expect(source).toMatch(
      /\.gallery-selection-action\s*\{[^}]*width:\s*48px;[^}]*flex:\s*0 0 48px;/s,
    )
    expect(source).toMatch(
      /\.gallery-selection-action :deep\(\.sky-button\)\s*\{[^}]*color:\s*#fff;/s,
    )
    expect(source).toContain("kind: 'media'")
    expect(source).toContain("nuiCall('gallery:delete-many'")
    expect(source).toContain('media:deleteManyResult')
  })

  it('shows capture time and iPhone-style actions in the media viewer', () => {
    expect(source).toContain(':title="selectedCaptureDay"')
    expect(source).toContain(':subtitle="selectedCaptureTime"')
    expect(source).not.toContain(
      "'Apps.photos.photo'\n            : 'Apps.photos.video'",
    )
    expect(source).toContain("nuiCall<FavoriteResult>('gallery:favorite'")
    expect(source).toContain('<Heart')
    expect(source).toContain('gallery-detail-toolbar')
    expect(source).toContain('<SkyToolbarPane class="gallery-detail-action">')
    expect(source).toMatch(
      /<SkyButton\s+icon-only\s+rounded\s+clear\s+class="gallery-detail-back"/,
    )
    expect(source).toMatch(
      /\.gallery-detail-navbar :deep\(\.gallery-detail-back\)\s*\{[^}]*color:\s*#fff;/s,
    )
    expect(source).toMatch(
      /\.gallery-detail-back:hover:not\(:disabled\)[\s\S]*?background:\s*rgba\(255, 255, 255, 0\.16\);/,
    )
    expect(source).toContain('transform: translateX(-2px);')
    expect(source).toMatch(
      /\.gallery-detail-action\s*\{[^}]*width:\s*48px;[^}]*flex:\s*0 0 48px;/s,
    )
    expect(source).toMatch(
      /\.gallery-detail-toolbar :deep\(\.sky-button\)\s*\{[^}]*color:\s*#fff;/s,
    )
    expect(source).toContain('shareSelected')
    expect(source).toContain('deleteDialogOpened = true')
    expect(source).toContain(
      'galleryReturnScrollTop = galleryContent.value?.scrollTop ?? 0',
    )
    expect(source).toContain(
      'galleryContent.value.scrollTop = galleryReturnScrollTop',
    )
    expect(source).toMatch(
      /async function closeMedia[\s\S]*?await nextTick\(\)/,
    )
    expect(source).toContain('@wheel.prevent="zoomImageWithWheel"')
    expect(source).toContain('media.clientWidth / bounds.width')
    expect(source).toContain('media.clientHeight / bounds.height')
    expect(source).toContain('const zoomRatio = nextZoom / imageZoom.value')
    expect(source).toContain(
      'x: pointerX - (pointerX - imagePan.value.x) * zoomRatio',
    )
    expect(source).toContain(
      'y: pointerY - (pointerY - imagePan.value.y) * zoomRatio',
    )
    expect(source).not.toContain('<ZoomIn')
    expect(source).not.toContain('<ZoomOut')
    expect(source).not.toContain('<RotateCcw')
  })

  it('uses complete local media fixtures when no browser API port is set', () => {
    expect(source).toContain("developmentParameters?.has('apiPort')")
    expect(source).toContain('isDevelopment && !developmentApiEnabled')
    expect(source).toContain('all: developmentMedia.length')
    expect(source).toContain('developmentMedia.filter(')
    expect(source).toMatch(/mockGalleryImage\(\s*'Flower Video'/)
    expect(source).toMatch(/mockGalleryImage\(\s*'Sintel Video'/)
    expect(source).toMatch(/mockGalleryImage\(\s*'Bunny Video'/)
    expect(source).toContain('const additionalPhotos = [')
    expect(source).toContain("['Campfire', '#c2410c', '#431407', '#fef08a']")
    expect(source).toContain('id: 13 + index')
    expect(source).not.toContain('picsum.photos')
  })

  it('routes single-image deletion through the browser API when apiPort is set', () => {
    const deleteSelectedStart = source.indexOf(
      'async function deleteSelected()',
    )
    const deleteSelected = source.slice(
      deleteSelectedStart,
      source.indexOf('function onMessage', deleteSelectedStart),
    )

    expect(deleteSelected).toContain(
      'if (isDevelopment && !developmentApiEnabled)',
    )
    expect(deleteSelected).toContain(
      "const response = await nuiCall('gallery:delete'",
    )
    expect(deleteSelected).toContain(
      'if (isDevelopment && developmentApiEnabled)',
    )
    expect(deleteSelected).toContain("type: 'media:deleteResult'")
    expect(deleteSelected).toContain('error: response.error')
    expect(deleteSelected).toContain('success: response.success')
    expect(deleteSelected).not.toMatch(/if \(isDevelopment\)\s*\{/)
  })
})
