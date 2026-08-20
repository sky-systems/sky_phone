import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./SettingsApp.vue', import.meta.url),
  'utf8',
)

describe('SettingsApp Sky UI contract', () => {
  it('uses the first-party settings surface without direct Konsta markup', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toMatch(/<\/?k-[a-z]/)
    expect(source).toContain('<SkyAppPage')
    expect(source).toContain('<SkyNavbar')
    expect(source).toContain('class="settings-navbar"')
    expect(source).toContain(
      '.settings-navbar.sky-navbar--large.sky-navbar--no-navigation',
    )
    expect(source).toContain(
      ":variant=\"activeView === 'root' ? 'large' : 'compact'\"",
    )
    expect(source).toContain('<SkyScrollArea')
    expect(source).toContain('<SkySettingsGroup')
    expect(source).toContain('<SkySettingsRow')
    expect(source).toContain('<SkySettingsRangeRow')
    expect(source).toContain('<template #leading><Volume1 /></template>')
    expect(source).toContain('<template #trailing><Volume2 /></template>')
    expect(source).toContain(
      `<template v-if="activeView === 'account' && !account.email" #right>`,
    )
  })

  it('uses the navbar control gap only once on compact subpages', () => {
    expect(source).toContain(
      ":class=\"{ 'settings-content--subpage': activeView !== 'root' }\"",
    )
    expect(source).toMatch(
      /\.settings-content\s*\{[^}]*padding-top:\s*var\(--sky-space-2\)/,
    )
    expect(source).toMatch(
      /\.settings-content--subpage\s*\{[^}]*padding-top:\s*0/,
    )
  })

  it('offers photo, camera, configured custom upload, recent, and built-in wallpaper choices', () => {
    expect(source).toContain("openWallpaperMedia('photos')")
    expect(source).toContain("openWallpaperMedia('camera')")
    expect(source).toContain('customWallpaperUploadAvailable')
    expect(source).toContain('openWallpaperCustomUpload')
    expect(source).toContain("nuiCall<MediaConfig>('media:config')")
    expect(source).toContain('nuiCall<MediaImportSources>')
    expect(source).toContain("'media:import:sources'")
    expect(source).toContain('`settings:wallpaper:${wallpaperTarget.value}`')
    expect(source).toContain("wallpaperTarget === 'home'")
    expect(source).toContain("wallpaperTarget === 'lock'")
    expect(source).toContain('class="settings-wallpaper-history"')
    expect(source).toContain('class="settings-wallpaper-grid"')
    expect(source).toMatch(
      /\.settings-wallpaper-grid\s*\{[^}]*grid-template-columns:\s*repeat\(2,/,
    )
  })

  it('places destructive erasure behind a dedicated reset explanation', () => {
    expect(source).toContain("openView('reset')")
    expect(source).toContain("activeView === 'reset'")
    expect(source).toContain("phone.t('Apps.settings.keepSimData')")
    expect(source).toContain("phone.t('Apps.settings.keepCloudData')")
    expect(source).toContain('phone.resetAfterFactoryReset()')
  })

  it('provides a non-destructive development preview for the reset progress screen', () => {
    expect(source).toContain('import.meta.env.DEV')
    expect(source).toContain("has('factoryResetPreview')")
    expect(source).toContain('factoryResetProgress.value = 46')
  })
})
