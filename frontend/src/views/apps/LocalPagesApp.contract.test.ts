import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./LocalPagesApp.vue', import.meta.url),
  'utf8',
)

describe('LocalPagesApp Sky UI contract', () => {
  it('uses the current Sky UI navigation and scroll primitives', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toContain('SkyTabBar')
    expect(source).not.toContain('SkyTabButton')
    expect(source).not.toContain('SkyToolbarPane')
    expect(source).toContain('<SkyPillNavigation')
    expect(source).toContain('<SkySegmented')
    expect(source).toContain('<SkyScrollArea')
    expect(source).toContain('with-tabbar')
  })

  it('keeps the city banner copy white on its colored surface', () => {
    expect(source).toMatch(
      /\.pages-hero-glass\s*\{[^}]*background:\s*linear-gradient[^}]*color:\s*#fff/s,
    )
    expect(source).toMatch(/\.pages__hero\s*\{[^}]*color:\s*#fff/s)
    expect(source).toMatch(
      /\.pages-hero-glass \.pages__hero small,[\s\S]*?\.pages-hero-glass \.pages__hero strong,[\s\S]*?\.pages-hero-glass \.pages__hero span\s*\{[^}]*color:\s*#fff/,
    )
  })

  it('animates successful likes and saves with reduced motion support', () => {
    expect(source).toContain('function triggerReactionPulse(')
    expect(source).toContain('triggerReactionPulse(post.id, kind)')
    expect(source).toContain('triggerReactionPulse(selected.value.id, kind)')
    expect(source).toContain('pages-reaction-pop')
    expect(source).toContain('pages-reaction-glow')
    expect(source).toContain('@media (prefers-reduced-motion: reduce)')
  })

  it('gives the composer more top clearance and compact navbar actions', () => {
    expect(source).toMatch(
      /\.pages-create-navbar\s*\{[^}]*--sky-safe-area-top:\s*112px/s,
    )
    expect(source).toMatch(/\.pages__compose-scroll\s*\{[^}]*top:\s*170px/s)
    expect(source).toMatch(
      /\.pages-create-navbar :deep\(\.sky-navbar__left\),[\s\S]*?background:\s*transparent;[\s\S]*?backdrop-filter:\s*none;/,
    )
    expect(source).toMatch(
      /\.pages-create-close,[\s\S]*?min-width:\s*44px[\s\S]*?height:\s*30px[\s\S]*?background:\s*transparent/,
    )
    expect(source).toMatch(
      /class="pages-create-close"[\s\S]*?<SkyIcon :icon="X" :size="17"/,
    )
    expect(source).toMatch(/clear[\s\S]*?class="pages-create-publish"/)
  })

  it('places sign out as an icon in the profile navbar', () => {
    expect(source).toContain('class="pages__navbar-logout"')
    expect(source).toMatch(/clear[\s\S]*?class="pages__navbar-logout"/)
    expect(source).toContain(':aria-label="phone.t(\'Common.signOut\')"')
    expect(source).not.toContain('class="pages__logout-glass"')
    expect(source).not.toContain('class="pages__logout"')
  })
})
