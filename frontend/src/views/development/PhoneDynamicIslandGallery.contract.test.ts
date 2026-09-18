import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const gallerySource = readFileSync(
  new URL('./PhoneDynamicIslandGallery.vue', import.meta.url),
  'utf8',
)
const islandSource = readFileSync(
  new URL('../../components/PhoneDynamicIsland.vue', import.meta.url),
  'utf8',
)
const appSource = readFileSync(
  new URL('../../App.vue', import.meta.url),
  'utf8',
)
const routerSource = readFileSync(
  new URL('../../router/index.ts', import.meta.url),
  'utf8',
)

describe('Dynamic Island development gallery contract', () => {
  it('shows every runtime activity and both supported presentation sizes', () => {
    for (const activity of [
      'incoming-call',
      'call',
      'music',
      'recording',
      'timer',
      'stopwatch',
    ]) {
      expect(gallerySource).toContain(`activity: '${activity}'`)
    }
    expect(gallerySource).toContain("label: 'Compact'")
    expect(gallerySource).toContain("label: 'Expanded'")
    expect(
      gallerySource.match(
        /activity: '(?:incoming-call|call|music|recording|timer|stopwatch)'/g,
      ),
    ).toHaveLength(11)
  })

  it('uses the production component with inert preview data', () => {
    expect(gallerySource).toContain('<PhoneDynamicIsland')
    expect(gallerySource).toContain(':preview-activity="variant.activity"')
    expect(islandSource).toContain('previewActivity?: DynamicIslandActivity')
    expect(islandSource).toContain(
      ':data-preview="props.preview ? \'true\' : undefined"',
    )
    expect(islandSource).toContain(".phone-dynamic-island[data-preview='true']")
    expect(gallerySource).toMatch(
      /\.dynamic-island-gallery__stage\s*\{[^}]*width:\s*100%;/s,
    )
    expect(gallerySource).toMatch(
      /dynamic-island-gallery__preview\.phone-dynamic-island[\s\S]*?max-width:\s*calc\(100% - 12px\);/,
    )
  })

  it('keeps the gallery development-only and hides the live island above it', () => {
    expect(routerSource).toContain("name: 'development-dynamic-islands'")
    expect(routerSource).toContain("path: '/development/dynamic-islands'")
    expect(routerSource).toMatch(
      /const developmentRoutes[^=]*=\s*import\.meta\.env\.DEV/,
    )
    expect(appSource).toContain("route.name === 'development-dynamic-islands'")
    expect(appSource).toContain(
      'v-if="!setupRequired && !isDynamicIslandGalleryRoute"',
    )
  })
})
