import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./PhoneSetupAssistant.vue', import.meta.url),
  'utf8',
)

describe('PhoneSetupAssistant contract', () => {
  it('uses first-party controls and exposes the complete setup journey', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).toContain('PhonePasscode')
    expect(source).toContain('step === 1')
    expect(source).toContain('step === 8')
    expect(source).toContain("['performance', 'ultimate']")
    expect(source).toContain('setup-mode-preview__card--front')
    expect(source).toContain('setup-mode-preview__card--back')
    expect(source).toContain('WALLPAPER_IDS')
    expect(source).toContain('setAllAppNotifications')
    expect(source).toContain('appStore.claimApp')
    expect(source).toContain('await phone.completeSetup()')
    expect(source).toMatch(
      /if \(step\.value === 8\) \{[\s\S]*void finish\(\)[\s\S]*return/,
    )
    expect(source).toContain(':disabled="setupCompleteBusy"')
    expect(source).toContain("phone.t('Setup.ready.saveFailed')")
  })

  it('persists progress and supports resuming or moving backward', () => {
    expect(source).toContain('phone.preferences.settings.setupStep')
    expect(source).toContain('phone.setSetupStep(step.value)')
    expect(source).toContain('@click="moveTo(step - 1)"')
  })

  it('keeps the development skip control away from setup progress', () => {
    expect(source).toContain('v-if="showDevelopmentSkip && step === 0"')
  })

  it('follows the selected system appearance throughout setup', () => {
    expect(source).toContain(
      '(appearanceSelected || step > 4) && phone.isDarkMode',
    )
    expect(source).toContain("emit('appearanceSelected', true)")
    expect(source).toContain("phone.setPreference('appearanceMode', 'light')")
    expect(source).toContain('.setup-assistant--dark.setup-assistant--step-0')
    expect(source).toContain('--setup-background: #000000')
    expect(source).toContain('background: var(--setup-background)')
  })

  it('applies the selected graphics mode to the setup experience immediately', () => {
    expect(source).toContain("'setup-assistant--performance':")
    expect(source).toContain("'setup-assistant--ultimate':")
    expect(source).toContain(
      '.setup-assistant--performance .setup-forward-enter-active',
    )
    expect(source).toContain(
      '.setup-assistant--ultimate .setup-mode-stack button',
    )
  })
})
