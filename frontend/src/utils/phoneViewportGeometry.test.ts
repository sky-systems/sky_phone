import { describe, expect, it } from 'vitest'

import {
  normalizePhoneViewportRect,
  readPhoneViewportGeometry,
  type PhoneViewportRect,
} from '@/utils/phoneViewportGeometry'

type RectMeasurement = Pick<
  DOMRectReadOnly,
  'height' | 'left' | 'top' | 'width'
>

function measuredRect(
  left: number,
  top: number,
  width: number,
  height: number,
): RectMeasurement {
  return { height, left, top, width }
}

function expectRectClose(
  actual: PhoneViewportRect,
  expected: PhoneViewportRect,
): void {
  for (const key of [
    'bottom',
    'height',
    'left',
    'right',
    'top',
    'width',
  ] as const) {
    expect(actual[key]).toBeCloseTo(expected[key], 6)
  }
}

function createGeometryFixture(options: {
  canvasOffsetHeight: number
  canvasOffsetWidth: number
  rawCanvasRect: RectMeasurement
  wrapperRect: RectMeasurement
}): { anchor: Element; element: (rect: RectMeasurement) => Element } {
  const wrapper = {
    getBoundingClientRect: () => options.wrapperRect,
  } as unknown as HTMLElement
  const canvas = {
    closest: (selector: string) =>
      selector === '.phone-resolution-wrapper' ? wrapper : null,
    getBoundingClientRect: () => options.rawCanvasRect,
    offsetHeight: options.canvasOffsetHeight,
    offsetWidth: options.canvasOffsetWidth,
  } as unknown as HTMLElement

  return {
    anchor: {
      closest: (selector: string) =>
        selector === '.phone-resolution-canvas' ? canvas : null,
    } as unknown as Element,
    element: (rect) =>
      ({ getBoundingClientRect: () => rect }) as unknown as Element,
  }
}

describe('phone viewport geometry', () => {
  it('leaves modern Chrome measurements unchanged when the canvas BCR is already rendered', () => {
    const wrapper = measuredRect(1573.09, 126.25, 322.92, 698.832)
    const layer = measuredRect(1589.783336, 177.75, 289.533328, 603.2)

    expectRectClose(normalizePhoneViewportRect(layer, wrapper, wrapper), {
      bottom: layer.top + layer.height,
      height: layer.height,
      left: layer.left,
      right: layer.left + layer.width,
      top: layer.top,
      width: layer.width,
    })
  })

  it('calibrates live CEF 103 BCRs back inside the visible wrapper', () => {
    const wrapper = measuredRect(1573.09, 126.25, 322.92, 698.832)
    const rawCanvas = measuredRect(1899.87, 152.5, 389.98, 844)
    const rawLayer = measuredRect(1920.03, 214.25, 349.66, 728.5)
    const corrected = normalizePhoneViewportRect(rawLayer, rawCanvas, wrapper)

    expect(corrected.left).toBeCloseTo(1589.7833360685163, 6)
    expect(corrected.width).toBeCloseTo(289.5333278629674, 6)
    expect(corrected.right).toBeCloseTo(1879.3166639314836, 6)
    expect(corrected.left).toBeGreaterThan(wrapper.left)
    expect(corrected.right).toBeLessThan(wrapper.left + wrapper.width)
  })

  it.each([
    ['80%', 0.6624],
    ['100%', 0.828],
    ['120%', 0.9936],
  ])(
    'normalizes fractional positions, sizes, and deltas at %s scaling',
    (_label, zoom) => {
      const rawCanvas = measuredRect(1900.125, 212.75, 390, 844)
      const wrapper = measuredRect(1530.5, 250.25, 390 * zoom, 844 * zoom)
      const rawStart = measuredRect(
        rawCanvas.left + 20.125,
        rawCanvas.top + 50.375,
        349.75,
        73.125,
      )
      const rawEnd = measuredRect(
        rawStart.left + 73.25,
        rawStart.top - 41.75,
        rawStart.width,
        rawStart.height,
      )
      const start = normalizePhoneViewportRect(rawStart, rawCanvas, wrapper)
      const end = normalizePhoneViewportRect(rawEnd, rawCanvas, wrapper)

      expect(start.left).toBeCloseTo(wrapper.left + 20.125 * zoom, 6)
      expect(start.top).toBeCloseTo(wrapper.top + 50.375 * zoom, 6)
      expect(start.width).toBeCloseTo(349.75 * zoom, 6)
      expect(start.height).toBeCloseTo(73.125 * zoom, 6)
      expect(end.left - start.left).toBeCloseTo(73.25 * zoom, 6)
      expect(end.top - start.top).toBeCloseTo(-41.75 * zoom, 6)
    },
  )

  it('reads visual scale and normalized element rects from a canvas anchor', () => {
    const fixture = createGeometryFixture({
      canvasOffsetHeight: 844,
      canvasOffsetWidth: 390,
      rawCanvasRect: measuredRect(1899.87, 152.5, 389.98, 844),
      wrapperRect: measuredRect(1573.09, 126.25, 322.92, 698.832),
    })
    const geometry = readPhoneViewportGeometry(fixture.anchor)
    const layer = fixture.element(measuredRect(1920.03, 214.25, 349.66, 728.5))

    expect(geometry).not.toBeNull()
    expect(geometry?.scaleX).toBeCloseTo(0.828, 6)
    expect(geometry?.scaleY).toBeCloseTo(0.828, 6)
    expect(geometry?.rect(layer).left).toBeCloseTo(1589.7833360685163, 6)
  })

  it('uses finite identity fallbacks for zero geometry and missing anchors', () => {
    const rawCanvas = measuredRect(100, 50, 0, 0)
    const corrected = normalizePhoneViewportRect(
      measuredRect(112.5, 58.25, 40, 20),
      rawCanvas,
      measuredRect(500, 300, 0, 0),
    )
    const fixture = createGeometryFixture({
      canvasOffsetHeight: 0,
      canvasOffsetWidth: 0,
      rawCanvasRect: rawCanvas,
      wrapperRect: measuredRect(500, 300, 0, 0),
    })
    const geometry = readPhoneViewportGeometry(fixture.anchor)

    expect(corrected).toEqual({
      bottom: 328.25,
      height: 20,
      left: 512.5,
      right: 552.5,
      top: 308.25,
      width: 40,
    })
    expect(Object.values(corrected).every(Number.isFinite)).toBe(true)
    expect(geometry?.scaleX).toBe(1)
    expect(geometry?.scaleY).toBe(1)
    expect(readPhoneViewportGeometry(null)).toBeNull()
    expect(
      readPhoneViewportGeometry({ closest: () => null } as unknown as Element),
    ).toBeNull()
  })
})
