import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const mediaCapture = readFileSync(
  new URL('./components/PhoneMediaCapture.vue', import.meta.url),
  'utf8',
)
const mediaServer = readFileSync(
  new URL('../../sky_phone/source/server/media.lua', import.meta.url),
  'utf8',
)

describe('media upload diagnostics contracts', () => {
  it('forwards browser upload failure context to the server log', () => {
    expect(mediaCapture).toContain("let debugStage = 'provider_request'")
    expect(mediaCapture).toContain('debugStatus: debug.status')
    expect(mediaServer).toContain('Client-reported upload failure')
    expect(mediaServer).toContain('diagnostic_text(data.debugMessage, 240)')
  })
})
