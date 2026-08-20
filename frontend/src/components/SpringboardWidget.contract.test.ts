import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./SpringboardWidget.vue', import.meta.url),
  'utf8',
)

describe('SpringboardWidget UI contract', () => {
  it('uses the Sky widget frame without a Konsta surface', () => {
    expect(source).toContain('<SkyWidgetFrame')
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toContain('<k-glass')
    expect(source).not.toContain('<k-badge')
  })

  it('keeps the full widget surface clickable without affecting layout', () => {
    expect(source).toContain('class="home-widget-open"')
    expect(source).toContain('@click.stop="openWidget"')
    expect(source).toContain('position: absolute;')
    expect(source).toContain('background: transparent;')
  })

  it('shows the reactive clock time in the calendar header', () => {
    expect(source).toContain('class="widget-date-time"')
    expect(source).toContain('{{ clock.time.value }}')
    expect(source).toContain('font-variant-numeric: tabular-nums;')
  })

  it('reuses weather artwork and music metadata from the owning apps', () => {
    expect(source).toContain('<WeatherConditionIcon')
    expect(source).toContain('music.current.value?.artwork')
    expect(source).toContain('music.progress.value')
  })

  it('fades empty music artwork downward while keeping its message above the fade', () => {
    expect(source).toContain('.home-widget--music-empty::after')
    expect(source).toContain(
      '.home-widget--music-empty .widget-music-placeholder',
    )
    expect(source).toContain('-webkit-mask-image: linear-gradient(')
    expect(source).toMatch(/\.widget-music-empty\s*{[\s\S]*?z-index:\s*2;/)
  })

  it.each([
    'sunny',
    'clear',
    'partly_cloudy',
    'cloudy',
    'rain',
    'thunder',
    'fog',
    'snow',
  ])('provides an adaptive %s weather surface', (condition) => {
    expect(source).toContain(`data-weather-condition='${condition}'`)
  })
})
