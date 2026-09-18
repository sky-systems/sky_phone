import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./WeatherApp.vue', import.meta.url),
  'utf8',
)
const styles = readFileSync(
  new URL('../../assets/main.css', import.meta.url),
  'utf8',
)

describe('WeatherApp layout contract', () => {
  it('preserves its exact custom forecast gutter instead of generic page padding', () => {
    expect(source).toMatch(
      /<SkyScrollArea[\s\S]*?class="weather-scroll"[\s\S]*?>/,
    )
    expect(source).toMatch(
      /\.weather-scroll\s*\{\s*padding:\s*4px 14px 24px;\s*\}/,
    )
    expect(source).not.toMatch(
      /<SkyScrollArea[\s\S]*?class="weather-scroll"[\s\S]*?\spadded(?:\s|=)[\s\S]*?>/,
    )
  })

  it('removes generic card margins from the compact forecast layout', () => {
    expect(styles).toMatch(
      /\.weather-details > \.weather-detail-card\s*{[\s\S]*?margin:\s*0;/,
    )
    expect(styles).toMatch(
      /\.weather-scroll > \.weather-panel\s*{\s*margin:\s*0;/,
    )
  })

  it('keeps hourly separators straight outside the highlighted current hour', () => {
    expect(styles).toMatch(
      /\.weather-hour\s*{[\s\S]*?border-left:[\s\S]*?border-radius:\s*0;/,
    )
    expect(styles).toMatch(
      /\.weather-hour:first-child\s*{[\s\S]*?border-radius:\s*var\(--sky-radius-control\);/,
    )
  })
})
