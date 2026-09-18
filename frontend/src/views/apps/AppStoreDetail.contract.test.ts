import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  fileURLToPath(new URL('./AppStoreDetail.vue', import.meta.url)),
  'utf8',
)
const previewSource = readFileSync(
  fileURLToPath(new URL('./AppStorePreviewCard.vue', import.meta.url)),
  'utf8',
)

describe('AppStoreDetail contract', () => {
  it('renders an Apple-style product page with metadata and direct action', () => {
    expect(source).toContain('class="store-detail__toolbar"')
    expect(source).toContain('class="store-detail__hero"')
    expect(source).toContain('class="store-detail__facts"')
    expect(source).toContain('class="store-detail__whats-new"')
    expect(source).toContain("emit('action')")
    expect(source).toContain("emit('back')")
    expect(source).toContain("emit('share')")
    expect(source).toContain('<AppStoreAction :action="action" />')
    expect(source).toContain(
      "'store-detail__action--icon': action === 'installing'",
    )
    expect(source).toContain("'store-detail__action--get': action === 'get'")
    expect(source).toMatch(
      /\.store-detail__hero \.store-detail__action--get\s*\{[^}]*min-width:\s*54px;[^}]*min-height:\s*30px;[^}]*height:\s*30px;/s,
    )
    expect(source).toMatch(
      /\.store-detail__hero \.store-detail__action--icon\s*\{[^}]*width:\s*54px;[^}]*min-width:\s*54px;[^}]*min-height:\s*30px;[^}]*height:\s*30px;/s,
    )
    expect(source).not.toContain(':has(')
    expect(previewSource).not.toContain('color-mix(')
    expect(source).toMatch(
      /\.store-detail\s*\{[^}]*padding:\s*var\(--sky-space-3\) 0 var\(--sky-space-6\)/s,
    )
  })

  it('renders five app-specific screenshot and information panels', () => {
    expect(source).toContain('class="store-detail__previews"')
    expect(source).toContain('<AppStorePreviewCard')
    expect(source).toContain('v-for="screen in previewScreens"')
    expect(source).toContain('getAppStorePreviewImage')
    expect(source).toContain(':preview-image="previewImage"')
    expect(previewSource).toContain('v-if="previewImage && screen < 3"')
    expect(previewSource).toContain(':src="previewImage"')
    expect(previewSource).toContain('store-detail-preview__screenshot')
    expect(previewSource).not.toContain('visual.scene ===')
    expect(source).toContain('getAppStorePreviewVisual')
    expect(source).toContain('Apps.appStore.previews.${props.app.id}')
    expect(previewSource).toContain(':src="iconImage"')
    expect(source).toMatch(/previewScreens\s*=\s*\[0, 1, 2, 3, 4\] as const/)
    expect(previewSource).toContain('screen === 3')
    expect(previewSource).toContain('screen === 4')
    expect(previewSource).toContain('store-detail-preview__details')
    expect(previewSource).toContain('store-detail-preview__about')
    expect(previewSource).toMatch(
      /\.store-detail-preview\s*\{[^}]*width:\s*224px;[^}]*height:\s*354px;/s,
    )
  })

  it('provides accessible previous and next controls for the preview gallery', () => {
    expect(source).toContain('ref="previews"')
    expect(source).toContain('@scroll.passive="updateActivePreview"')
    expect(source).toContain('scrollToPreview(activePreviewIndex - 1)')
    expect(source).toContain('scrollToPreview(activePreviewIndex + 1)')
    expect(source).toContain('details.previousPreview')
    expect(source).toContain('details.nextPreview')
    expect(source).toContain('.store-detail__toolbar-button:hover')
  })

  it('uses shared liquid glass for toolbar and preview controls', () => {
    expect(source).toContain("import { SkyButton } from '@/ui'")
    expect(source.match(/<SkyButton\s+glass/g)).toHaveLength(4)
    expect(source).toContain('class="store-detail__toolbar-button"')
    expect(source).toContain('class="store-detail__preview-control"')
    expect(source).toMatch(
      /\.store-detail__preview-control\s*\{[^}]*width:\s*var\(--sky-touch-target\);[^}]*height:\s*var\(--sky-touch-target\);[^}]*border-radius:\s*50%;/s,
    )
  })
})
