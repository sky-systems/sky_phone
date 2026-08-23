import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./SkyRideApp.vue', import.meta.url),
  'utf8',
)
const types = readFileSync(
  new URL('../../types/skyride.ts', import.meta.url),
  'utf8',
)

describe('SkyRide app layout', () => {
  it('shows the server-authoritative ride distance in history', () => {
    expect(types).toContain('distanceMeters: number')
    expect(source).toContain('formatRideDistance(ride.distanceMeters)')
    expect(source).toContain('skyride-history-card__distance')
  })

  it('explains that requests require an online player driver', () => {
    expect(source).toContain("phone.t('Apps.skyride.playerDriverNotice')")
    expect(source).toContain('class="skyride-player-driver-notice"')
  })

  it('aligns rider and activity surfaces to one content width', () => {
    expect(source).toMatch(
      /\.skyride-location-list,\s*\.skyride-activity-list\s*\{[^}]*margin-inline:\s*2px !important;/s,
    )
    expect(source).toMatch(
      /\.skyride-home-panel\s*\{[^}]*background:\s*linear-gradient/s,
    )
  })

  it('scrolls Ride and Drive away without full-width nav backgrounds', () => {
    expect(source).toMatch(
      /\.skyride-navbar :deep\(\.sky-navbar__blur\),\s*\.skyride-navbar :deep\(\.sky-navbar__background\)\s*\{[^}]*display:\s*none;/s,
    )
    expect(source).toMatch(
      /<div class="skyride-scroll">\s*<div class="skyride-mode">/s,
    )
    expect(source).toMatch(
      /\.skyride-scroll\s*\{[^}]*box-sizing:\s*border-box;[^}]*inset:\s*114px 0 0;[^}]*padding:\s*0 0 116px;/s,
    )
    expect(source).toMatch(
      /\.skyride-tabbar :deep\(\.sky-tabbar__blur\),\s*\.skyride-tabbar :deep\(\.sky-tabbar__background\)\s*\{[^}]*display:\s*none;/s,
    )
    expect(source).not.toMatch(
      /\.skyride-tabbar :deep\(\.sky-tabbar__pane\)\s*\{\s*border:/s,
    )
  })

  it('keeps active-ride card spacing even and outline actions contrasted', () => {
    expect(source).toMatch(
      /\.skyride-ride-status-card\s*\{[^}]*margin-bottom:\s*12px;/s,
    )
    expect(source).toMatch(
      /\.skyride-person-card\s*\{[^}]*margin-bottom:\s*12px;/s,
    )
    expect(source).toMatch(
      /\.skyride-trip-card\s*\{[^}]*margin-bottom:\s*12px;/s,
    )
    expect(source).toContain('.sky-button--primary:not(.sky-button--outline)')
    expect(source).not.toMatch(
      /\.skyride-app :deep\(\.sky-button--primary\)\s*\{/,
    )
  })

  it('aligns pickup and destination text to one timeline axis', () => {
    expect(source).toMatch(
      /\.skyride-route-stop\s*\{[^}]*grid-template-columns:\s*18px minmax\(0, 1fr\);/s,
    )
    expect(source).toMatch(
      /\.skyride-route-stop > \.skyride-dot\s*\{[^}]*justify-self:\s*center;/s,
    )
    expect(source).toMatch(
      /\.skyride-trip-card > i\s*\{[^}]*margin:\s*1px 0 1px 8px;/s,
    )
  })

  it('uses a compact swipeable profile editor with equal actions', () => {
    expect(source).toContain('class="skyride-profile-sheet"')
    expect(source).toContain('swipe-to-close')
    expect(source).toContain('@swipeclose="closeProfileEditor"')
    expect(source).toMatch(
      /\.skyride-profile-sheet :deep\(\.sky-sheet__panel\)\s*\{[^}]*max-height:\s*78%;/s,
    )
    expect(source.match(/<SkyButton\s+block\s+large\s+rounded/g)).toHaveLength(
      2,
    )
    expect(source).toContain('skyride-profile-media-button')
  })
})
