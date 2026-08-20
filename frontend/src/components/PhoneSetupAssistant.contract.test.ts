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
    expect(source).toContain("step === 1")
    expect(source).toContain("step === 8")
    expect(source).toContain("['performance', 'ultimate']")
    expect(source).toContain('WALLPAPER_IDS')
    expect(source).toContain('setAllAppNotifications')
    expect(source).toContain('appStore.claimApp')
    expect(source).toContain('await phone.completeSetup()')
    expect(source).toContain(':disabled="setupCompleteBusy"')
    expect(source).toContain("phone.t('Setup.ready.saveFailed')")
  })

  it('persists progress and supports resuming or moving backward', () => {
    expect(source).toContain('phone.preferences.settings.setupStep')
    expect(source).toContain('phone.setSetupStep(step.value)')
    expect(source).toContain('@click="moveTo(step - 1)"')
  })
})
