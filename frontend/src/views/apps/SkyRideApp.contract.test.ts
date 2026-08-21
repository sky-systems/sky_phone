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
