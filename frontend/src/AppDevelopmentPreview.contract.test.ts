import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./App.vue', import.meta.url), 'utf8')
const mainCss = readFileSync(
  new URL('./assets/main.css', import.meta.url),
  'utf8',
)

describe('browser development preview contract', () => {
  it('keeps setup light until the appearance choice has been confirmed', () => {
    expect(source).toContain('const displayedDarkMode = computed(')
    expect(source).toContain('phone.preferences.settings.setupStep > 4')
    expect(source).toContain('setupAppearanceSelected.value')
    expect(source).toContain(
      '@appearance-selected="setupAppearanceSelected = $event"',
    )
    expect(source).toContain(':dark="displayedDarkMode"')
    expect(source).toContain('dark: displayedDarkMode')
  })

  it('starts unlocked while preserving an explicit lock screen preview', () => {
    expect(source).toContain("developmentParameters.has('lockScreenPreview')")
    expect(source).toContain(
      'developmentLockScreenPreview ||\n        (!isDevelopment && phone.security.enabled)',
    )
    expect(source).toContain("developmentParameters.has('setupPreview')")
  })

  it('restores the active route after the lock screen', () => {
    expect(source).toMatch(
      /if \(setupRequired\.value\) \{[\s\S]*?router\.replace\('\/'\)/,
    )
    expect(source).toMatch(
      /else if \(!isLocked\.value\) \{\s*loadUnlockedPhoneData\(\)/,
    )
    expect(source).not.toContain(
      "if (isLocked.value || setupRequired.value) void router.replace('/')",
    )
  })

  it('opens Space-triggered live activities on Home or the enabled lock screen', () => {
    expect(source).toContain(
      'openHomeRequested.value = event.data.openHome === true',
    )
    expect(source).toContain(
      "if (isLocked.value) pendingUnlockRoute.value = '/'",
    )
    expect(source).toContain("void router.replace('/')")
  })

  it('requires the passcode again after a full device lock', () => {
    expect(source).toContain('const passcodeRequired = ref(false)')
    expect(source).toContain(
      'if (phone.security.enabled && passcodeRequired.value)',
    )
    expect(source).toContain(
      'passcodeRequired.value = isLocked.value && phone.security.enabled',
    )
    expect(source).toMatch(
      /function lockPhone\(\): void \{[\s\S]*?passcodeRequired\.value = phone\.security\.enabled[\s\S]*?isLocked\.value = true/,
    )
  })

  it('keeps hairlines at one rendered device pixel through phone zoom', () => {
    expect(source).toContain(
      '...getHairlinePixelStyle(phoneZoom.value, browserDevicePixelRatio.value)',
    )
    expect(source).toContain(':device-pixel-ratio="browserDevicePixelRatio"')
  })

  it('maps the visible device side controls to phone actions', () => {
    expect(source).toContain('@click="toggleHardwareAlertMute"')
    expect(source).toContain('@click="changeHardwareAlertVolume(10)"')
    expect(source).toContain('@click="changeHardwareAlertVolume(-10)"')
    expect(source).toContain('@click="toggleHardwareLock"')
    expect(source).toMatch(
      /function toggleHardwareLock\(\): void \{[\s\S]*?unlockPhone\(\)[\s\S]*?lockPhone\(\)/,
    )
    expect(source).toMatch(
      /function changeHardwareAlertVolume\(delta: number\): void \{[\s\S]*?phone\.setAlertVolumes\(volume\)/,
    )
    expect(mainCss).toMatch(
      /\.phone-hardware-button\s*\{[\s\S]*?position:\s*absolute;[\s\S]*?z-index:\s*101;/,
    )
    expect(mainCss).toContain('.phone-hardware-button--power')
    expect(source).toContain('class="phone-volume-hud"')
    expect(source).toContain('showHardwareVolumeHud()')
    expect(mainCss).toContain('.phone-volume-hud__level')
  })

  it('uses layout zoom so the fixed-resolution phone stays sharply rasterized', () => {
    expect(source).toContain('phone-resolution-canvas--primary')
    expect(source).toContain("'--phone-rendered-height'")
    expect(source).toContain("'--phone-rendered-width'")
    expect(mainCss).toMatch(
      /\.phone-resolution-canvas\s*\{[^}]*zoom:\s*var\(--phone-zoom, 1\);/s,
    )
    expect(mainCss).not.toMatch(
      /\.phone-resolution-canvas\s*\{[^}]*transform:\s*scale\(/s,
    )
  })

  it('matches the production phone size and bottom-right stage in development', () => {
    expect(source).toContain('const PHONE_BASE_SCALE = 0.69 * 1.2')
    expect(source).toContain('() => viewportScale.value * PHONE_BASE_SCALE')
    expect(source).not.toContain('DEVELOPMENT_PHONE_SCALE')
    expect(source).not.toContain("'phone-stage--dev': isDevelopment")
    expect(mainCss).toMatch(
      /\.phone-stage\s*\{[^}]*place-items:\s*end;[^}]*padding:\s*0 var\(--phone-edge-gap, 24px\) var\(--phone-edge-gap, 24px\) 0;/s,
    )
    expect(mainCss).not.toContain('.phone-stage--dev')
  })

  it('fills the dedicated browser embed without clipping the hardware controls', () => {
    expect(source).toContain("developmentParameters.has('browserPreview')")
    expect(source).toContain('import.meta.env.DEV ||')
    expect(source).toContain("'phone-stage--browser-preview': isBrowserPreview")
    expect(source).toContain(
      'return (availableScale * 0.94) / PHONE_BASE_SCALE',
    )
    expect(mainCss).toMatch(
      /\.phone-stage--browser-preview\s*\{[^}]*place-items:\s*center;[^}]*padding:\s*0;/s,
    )
    expect(mainCss).toMatch(
      /\.phone-stage--browser-preview \.phone-device\s*\{[^}]*filter:\s*none;/s,
    )
  })
})
