import { describe, expect, it } from 'vitest'

import {
  normalizePhoneViewportRect,
  phoneViewportRectContainsPoint,
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

const PHONE_BASE_ZOOM = 0.69 * 1.2
const PHONE_HEIGHT = 844
const PHONE_WIDTH = 390
const REFERENCE_VIEWPORT_HEIGHT = 1080
const REFERENCE_VIEWPORT_WIDTH = 1920

const displayCases = [
  { height: 1080, label: '1080p 16:9', width: 1920 },
  { height: 2160, label: '4K 16:9', width: 3840 },
  { height: 1440, label: '21:9', width: 3440 },
  { height: 1440, label: '32:9', width: 5120 },
  { height: 1600, label: '16:10', width: 2560 },
] as const

const phoneScales = [80, 100, 120] as const

function productionPhoneZoom(
  viewportWidth: number,
  viewportHeight: number,
  phoneScale: number,
): number {
  const viewportScale = Math.min(
    viewportWidth / REFERENCE_VIEWPORT_WIDTH,
    viewportHeight / REFERENCE_VIEWPORT_HEIGHT,
  )
  const preferred = PHONE_BASE_ZOOM * viewportScale * (phoneScale / 100)
  const edgeGap = 24 * viewportScale
  const viewportMaximum = Math.max(
    0,
    Math.min(
      (viewportWidth - edgeGap) / PHONE_WIDTH,
      (viewportHeight - edgeGap) / PHONE_HEIGHT,
    ),
  )

  return Math.min(viewportMaximum, Math.max(260 / PHONE_WIDTH, preferred))
}

const cefDisplayMatrix = displayCases.flatMap((display) =>
  phoneScales.map((phoneScale) => ({ display, phoneScale })),
)

describe('phone viewport geometry', () => {
  it('treats every rectangle boundary as inside and rejects points beyond it', () => {
    const rect: PhoneViewportRect = {
      bottom: 260,
      height: 160,
      left: 120,
      right: 360,
      top: 100,
      width: 240,
    }

    expect(phoneViewportRectContainsPoint(rect, 240, 180)).toBe(true)
    expect(phoneViewportRectContainsPoint(rect, rect.left, rect.top)).toBe(true)
    expect(phoneViewportRectContainsPoint(rect, rect.right, rect.bottom)).toBe(
      true,
    )
    expect(phoneViewportRectContainsPoint(rect, rect.left - 0.001, 180)).toBe(
      false,
    )
    expect(phoneViewportRectContainsPoint(rect, rect.right + 0.001, 180)).toBe(
      false,
    )
    expect(phoneViewportRectContainsPoint(rect, 240, rect.top - 0.001)).toBe(
      false,
    )
    expect(phoneViewportRectContainsPoint(rect, 240, rect.bottom + 0.001)).toBe(
      false,
    )
  })

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

  it.each(cefDisplayMatrix)(
    'keeps an opened folder panel hit-test exact at $phoneScale% on $display.label',
    ({ display, phoneScale }) => {
      const viewportScale = Math.min(
        display.width / REFERENCE_VIEWPORT_WIDTH,
        display.height / REFERENCE_VIEWPORT_HEIGHT,
      )
      const zoom = productionPhoneZoom(
        display.width,
        display.height,
        phoneScale,
      )
      const edgeGap = 24 * viewportScale
      const wrapper = measuredRect(
        display.width - edgeGap - PHONE_WIDTH * zoom,
        display.height - edgeGap - PHONE_HEIGHT * zoom,
        PHONE_WIDTH * zoom,
        PHONE_HEIGHT * zoom,
      )
      // Live CEF 103 can report the zoomed canvas in a different coordinate
      // space from pointer events. Preserve that mismatch in this fixture.
      const rawCanvas = measuredRect(
        display.width + 117.375,
        83.625,
        PHONE_WIDTH,
        PHONE_HEIGHT,
      )
      const rawPanel = measuredRect(
        rawCanvas.left + 23.25,
        rawCanvas.top + 246.75,
        343.5,
        324.25,
      )
      const panel = normalizePhoneViewportRect(rawPanel, rawCanvas, wrapper)
      const expected = {
        bottom: wrapper.top + (246.75 + 324.25) * zoom,
        height: 324.25 * zoom,
        left: wrapper.left + 23.25 * zoom,
        right: wrapper.left + (23.25 + 343.5) * zoom,
        top: wrapper.top + 246.75 * zoom,
        width: 343.5 * zoom,
      }

      expectRectClose(panel, expected)
      expect(
        phoneViewportRectContainsPoint(
          panel,
          panel.left + panel.width / 2,
          panel.top + panel.height / 2,
        ),
      ).toBe(true)
      expect(phoneViewportRectContainsPoint(panel, panel.left, panel.top)).toBe(
        true,
      )
      expect(
        phoneViewportRectContainsPoint(panel, panel.right, panel.bottom),
      ).toBe(true)
      expect(
        phoneViewportRectContainsPoint(panel, panel.left - 0.25, panel.top),
      ).toBe(false)
      expect(
        phoneViewportRectContainsPoint(panel, panel.right + 0.25, panel.bottom),
      ).toBe(false)
      expect(panel.left).toBeGreaterThanOrEqual(0)
      expect(panel.right).toBeLessThanOrEqual(display.width)
      expect(panel.top).toBeGreaterThanOrEqual(0)
      expect(panel.bottom).toBeLessThanOrEqual(display.height)
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
