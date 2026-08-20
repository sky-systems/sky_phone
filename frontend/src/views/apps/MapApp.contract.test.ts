import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./MapApp.vue', import.meta.url), 'utf8')

describe('MapApp interaction contract', () => {
  it('uses Sky UI controls and the central EasyShare store', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).toContain('<SkyAppPage')
    expect(source).toContain('<SkyFab')
    expect(source).toContain('<SkyGlass')
    expect(source).toContain('easyShare.open({')
    expect(source).toContain('subtitle: coordinates')
    expect(source).not.toContain('<EasyShareSheet')
  })

  it('uses translucent liquid glass for every floating map control', () => {
    const controlsStart = source.indexOf('class="map-controls"')
    const controlsEnd = source.indexOf('</nav>', controlsStart)
    const controls = source.slice(controlsStart, controlsEnd)

    expect(controls.match(/variant="glass"/g)).toHaveLength(4)
    expect(controls).not.toContain('variant="neutral"')
    expect(controls).not.toContain('variant="primary"')
    expect(source).toContain('--sky-glass: rgb(247 247 248 / 72%);')
  })

  it('keeps zoom and panning inside scale-aware map bounds', () => {
    expect(source).toContain('minimumCoverZoom(metrics, baseMinZoom)')
    expect(source).toContain('clampMapPan(nextPan, nextZoom, metrics)')
    expect(source).toContain('zoomPanAtPoint(')
    expect(source).not.toContain("width: 'max(120%, 120vh)'")
  })

  it('allows the marker crosshair to be placed by tapping the map', () => {
    expect(source).toContain('placementPoint.value = viewportPoint({')
    expect(source).toContain(':style="placementCrosshairStyle"')
    expect(source).toContain('clientPointToMapPercent(')
  })
})
