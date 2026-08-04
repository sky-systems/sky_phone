import { describe, expect, it } from 'vitest'

import { ALARM_SOUND_IDS } from './alarms'
import { phoneToneDuration } from './tones'

describe('phone tones', () => {
  it('defines a playable duration for every alarm sound', () => {
    for (const sound of ALARM_SOUND_IDS) {
      expect(phoneToneDuration(sound)).toBeGreaterThan(0)
      expect(phoneToneDuration(sound)).toBeLessThanOrEqual(1500)
    }
  })
})
