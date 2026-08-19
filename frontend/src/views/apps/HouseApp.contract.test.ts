import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./HouseApp.vue', import.meta.url), 'utf8')

describe('House app sheets', () => {
  it('closes both sheets through their shared drag gesture or grabber button', () => {
    expect(source.match(/swipe-to-close/g)).toHaveLength(2)
    expect(source.match(/grabber-clickable/g)).toHaveLength(2)
    expect(source).toContain('@swipeclose="selectedPropertyId = null"')
    expect(source).toContain('@swipeclose="candidatesOpened = false"')
    expect(source).toContain('@grabberclick="selectedPropertyId = null"')
    expect(source).toContain('@grabberclick="candidatesOpened = false"')
  })

  it('sizes the panels instead of clipping the overlay roots', () => {
    const rootRule = source.match(
      /:global\(\.house-detail-sheet\),\s*:global\(\.house-candidates-sheet\)\s*\{(?<declarations>[^}]*)\}/,
    )?.groups?.declarations

    expect(rootRule).toBeDefined()
    expect(rootRule).not.toContain('height:')
    expect(source).toMatch(
      /:global\(\.house-detail-sheet \.sky-sheet__panel\),[\s\S]*?height:\s*88%;/,
    )
    expect(source).not.toContain('height: 620px;')
  })

  it('keeps the header clear of the status bar and shows its full subtitle', () => {
    expect(source).not.toContain('--sky-safe-area-top: 46px')
    expect(source).toMatch(
      /\.house-navbar :deep\(\.sky-navbar__heading\)\s*\{[^}]*grid-column:\s*1 \/ -1;/s,
    )
    expect(source).toMatch(
      /\.house-navbar :deep\(\.sky-navbar__subtitle\)\s*\{[^}]*text-overflow:\s*clip;[^}]*white-space:\s*normal;/s,
    )
  })

  it('uses the full popup content width for the keys list', () => {
    expect(source).toContain('class="house-key-list"')
    expect(source).toMatch(
      /\.house-key-list\s*\{[^}]*--sky-list-outer-left:\s*0px;[^}]*--sky-list-outer-right:\s*0px;/s,
    )
  })

  it('can expose key revocation without advertising key grants', () => {
    expect(source).toContain(
      'v-if="selectedProperty.capabilities.keyGrant !== false"',
    )
    expect(source).toContain(
      '<section v-if="selectedProperty.capabilities.keys" class="house-keys">',
    )
  })

  it('centers the resident icon above the Give a Key title', () => {
    expect(source).toMatch(
      /\.house-candidates > svg\s*\{[^}]*display:\s*block;[^}]*margin:\s*0 auto;/s,
    )
  })
})
