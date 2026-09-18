import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const appSource = readFileSync(new URL('./App.vue', import.meta.url), 'utf8')
const audioSource = readFileSync(
  new URL('./utils/phoneAudio.ts', import.meta.url),
  'utf8',
)
const mainCss = readFileSync(
  new URL('./assets/main.css', import.meta.url),
  'utf8',
)
const musicSource = readFileSync(
  new URL('./stores/music.ts', import.meta.url),
  'utf8',
)

describe('phone audio output contract', () => {
  it('applies the hardware volume to app media and live YouTube playback', () => {
    expect(appSource).toContain('installPhoneAudioController()')
    expect(appSource).toContain('setPhoneOutputVolume(volume / 100)')
    expect(appSource).toContain(
      'if (radio.data.connected) void radio.setVolume(volume)',
    )
    expect(audioSource).toContain(
      "document.addEventListener('play', onMediaPlay, true)",
    )
    expect(audioSource).toContain('localVolume * outputVolume')
    expect(musicSource).toContain('registerPhoneMediaElement(new Audio())')
    expect(musicSource).toContain('store.volume * getPhoneOutputVolume() * 100')
  })

  it('renders the hardware speaker symbol in grey', () => {
    expect(mainCss).toMatch(/\.phone-volume-hud\s*\{[\s\S]*?color:\s*#a9abb2;/)
  })
})
