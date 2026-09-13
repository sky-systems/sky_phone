import { effectScope, nextTick, shallowRef, type EffectScope } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useMapPanZoom } from './useMapPanZoom'

const scopes: EffectScope[] = []
let resize: () => void
const disconnect = vi.fn()

beforeEach(() => {
  disconnect.mockClear()
  vi.stubGlobal(
    'ResizeObserver',
    class {
      constructor(callback: () => void) {
        resize = callback
      }
      observe() {}
      disconnect = disconnect
    },
  )
})
afterEach(() => {
  for (const scope of scopes.splice(0)) scope.stop()
  vi.unstubAllGlobals()
})

function setup(legacyZoom?: number) {
  const captured = new Set<number>()
  const capture = {
    setPointerCapture: vi.fn((id: number) => captured.add(id)),
    hasPointerCapture: (id: number) => captured.has(id),
    releasePointerCapture: vi.fn((id: number) => captured.delete(id)),
  }
  const phoneWrapper = {
    getBoundingClientRect: () => ({
      left: 100,
      top: 50,
      width: 390 * (legacyZoom ?? 1),
      height: 844 * (legacyZoom ?? 1),
    }),
  }
  const phoneCanvas = {
    offsetWidth: 390,
    offsetHeight: 844,
    closest: () => phoneWrapper,
    getBoundingClientRect: () => ({
      left: 100 / (legacyZoom ?? 1),
      top: 50 / (legacyZoom ?? 1),
      width: 390,
      height: 844,
    }),
  }
  const viewport = {
    ...capture,
    clientWidth: 360,
    clientHeight: 430,
    getBoundingClientRect: () => ({
      left: legacyZoom ? 100 / legacyZoom + 15 : 100,
      top: legacyZoom ? 50 / legacyZoom + 62 : 50,
      width: legacyZoom ? 360 : 180,
      height: legacyZoom ? 430 : 215,
    }),
    closest: (selector: string) =>
      legacyZoom && selector === '.phone-resolution-canvas'
        ? phoneCanvas
        : null,
  } as unknown as HTMLElement
  const canvas = { clientWidth: 300, clientHeight: 430 } as HTMLElement
  const viewportRef = shallowRef<HTMLElement | null>(viewport)
  const canvasRef = shallowRef<HTMLElement | null>(canvas)
  const scope = effectScope()
  scopes.push(scope)
  const map = scope.run(() => useMapPanZoom(viewportRef, canvasRef))!
  const pointer = (x: number, y: number, target = viewport, overrides = {}) =>
    ({
      button: 0,
      isPrimary: true,
      pointerId: 1,
      pointerType: 'mouse',
      clientX: x,
      clientY: y,
      target,
      currentTarget: viewport,
      ...overrides,
    }) as unknown as PointerEvent
  const click = (detail = 1) => ({
    detail,
    preventDefault: vi.fn(),
    stopPropagation: vi.fn(),
  })
  return {
    map,
    viewport,
    viewportRef,
    canvasRef,
    scope,
    pointer,
    click,
    capture,
  }
}

describe('CityWarn map interaction', () => {
  it.each([0.667, 0.828, 1.656])(
    'keeps wheel zoom and panning under the pointer at CEF CSS zoom %s',
    (phoneZoom) => {
      const { map, pointer } = setup(phoneZoom)
      const focal = {
        x: 100 + (15 + 270) * phoneZoom,
        y: 50 + (62 + 215) * phoneZoom,
      }
      map.onWheel({
        deltaY: -180,
        deltaMode: 0,
        clientX: focal.x,
        clientY: focal.y,
        preventDefault: vi.fn(),
        stopPropagation: vi.fn(),
      } as unknown as WheelEvent)
      const expectedZoom = Math.exp(180 * 0.0024)
      const zoomPan = map.canvasStyle.value.transform
        .match(/translate\(([^,]+)px, ([^)]+)px\)/)!
        .slice(1)
        .map(Number)
      expect(map.zoom.value).toBeCloseTo(expectedZoom)
      expect(zoomPan[0]).toBeCloseTo(90 * (1 - expectedZoom))
      expect(zoomPan[1]).toBeCloseTo(0)

      map.reset()
      map.changeZoom(2)
      map.onPointerDown(pointer(focal.x, focal.y))
      map.onPointerMove(
        pointer(focal.x + 20 * phoneZoom, focal.y + 16 * phoneZoom),
      )
      const dragPan = map.canvasStyle.value.transform
        .match(/translate\(([^,]+)px, ([^)]+)px\)/)!
        .slice(1)
        .map(Number)
      expect(dragPan[0]).toBeCloseTo(20)
      expect(dragPan[1]).toBeCloseTo(16)
    },
  )

  it('zooms around the mouse position even when the phone is scaled', () => {
    const { map } = setup()
    map.changeZoom(2, { x: 235, y: 157.5 })
    expect(map.canvasStyle.value.transform).toBe(
      'translate(-90px, 0px) scale(2)',
    )
    expect(map.canvasStyle.value['--citywarn-map-pin-scale']).toBe('0.5')
    map.changeZoom(1, { x: 235, y: 157.5 })
    expect(map.canvasStyle.value.transform).toBe('translate(0px, 0px) scale(1)')
  })

  it.each(['mouse', 'touch'])(
    'pans with a %s pointer, bounds the map and prevents a drag from opening a pin',
    (pointerType) => {
      const { map, pointer, viewport, click, capture } = setup()
      const pin = {
        ...capture,
        closest: (selector: string) => (selector === 'button' ? pin : null),
      } as unknown as HTMLElement
      map.changeZoom(2)
      map.onPointerDown(pointer(150, 100, pin, { pointerType }))
      map.onPointerMove(pointer(175, 125, pin, { pointerType }))
      expect(map.canvasStyle.value.transform).toBe(
        'translate(50px, 50px) scale(2)',
      )
      map.onPointerMove(pointer(1000, 1000, viewport, { pointerType }))
      expect(map.canvasStyle.value.transform).toBe(
        'translate(120px, 215px) scale(2)',
      )
      map.onPointerEnd(pointer(1000, 1000))
      expect(capture.releasePointerCapture).toHaveBeenCalledWith(1)
      const draggedClick = click()
      map.onClickCapture(draggedClick as unknown as MouseEvent)
      expect(draggedClick.preventDefault).toHaveBeenCalledOnce()
      const keyboardClick = click(0)
      map.onClickCapture(keyboardClick as unknown as MouseEvent)
      expect(keyboardClick.preventDefault).not.toHaveBeenCalled()
    },
  )

  it('keeps a pin tap clickable and lets controls work after a cancelled drag', () => {
    const { map, pointer, click, capture } = setup()
    map.onPointerDown(pointer(150, 100))
    map.onPointerMove(pointer(151, 101))
    map.onPointerEnd(pointer(151, 101))
    const tap = click()
    map.onClickCapture(tap as unknown as MouseEvent)
    expect(tap.preventDefault).not.toHaveBeenCalled()
    map.onPointerDown(pointer(150, 100))
    map.onPointerMove(pointer(170, 100))
    map.onPointerEnd(pointer(170, 100))
    const control = { closest: () => control } as unknown as HTMLElement
    map.onPointerDown(pointer(170, 100, control))
    const controlClick = click()
    map.onClickCapture(controlClick as unknown as MouseEvent)
    expect(controlClick.preventDefault).not.toHaveBeenCalled()
    expect(capture.setPointerCapture).toHaveBeenCalledTimes(2)
  })

  it('normalizes wheel units and consumes scrolling only on the map', () => {
    const { map } = setup()
    const event = {
      deltaY: -3,
      deltaMode: 1,
      clientX: 190,
      clientY: 157.5,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
    }
    map.onWheel(event as unknown as WheelEvent)
    const lineZoom = map.zoom.value
    expect(lineZoom).toBeGreaterThan(1)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    map.reset()
    map.onWheel({
      ...event,
      deltaY: -48,
      deltaMode: 0,
    } as unknown as WheelEvent)
    expect(map.zoom.value).toBeCloseTo(lineZoom)
  })

  it('supports bounded keyboard zoom, arrow movement and returning to the full map', () => {
    const { map, viewport } = setup()
    const key = (value: string) => ({
      key: value,
      target: viewport,
      currentTarget: viewport,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
    })
    map.changeZoom(99)
    expect(map.zoom.value).toBe(8)
    map.onKeydown(key('ArrowLeft') as unknown as KeyboardEvent)
    expect(map.canvasStyle.value.transform).toContain('translate(40px, 0px)')
    map.onKeydown(key('Home') as unknown as KeyboardEvent)
    expect(map.canvasStyle.value.transform).toBe('translate(0px, 0px) scale(1)')
    map.onKeydown(key('-') as unknown as KeyboardEvent)
    expect(map.zoom.value).toBe(1)
    const childKey = { ...key('+'), target: {} }
    map.onKeydown(childKey as unknown as KeyboardEvent)
    expect(childKey.preventDefault).not.toHaveBeenCalled()
  })

  it('releases pointer capture and observation when the map tab disappears', async () => {
    const { map, pointer, viewportRef, capture } = setup()
    map.onPointerDown(pointer(150, 100))
    viewportRef.value = null
    await nextTick()
    expect(disconnect).toHaveBeenCalledOnce()
    expect(capture.releasePointerCapture).toHaveBeenCalledWith(1)
    expect(map.dragging.value).toBe(false)
  })

  it('reclamps the view on resize without resetting the zoom', () => {
    const { map, pointer, viewport } = setup()
    map.changeZoom(2)
    map.onPointerDown(pointer(150, 100))
    map.onPointerMove(pointer(500, 500))
    Object.defineProperty(viewport, 'clientWidth', { value: 580 })
    resize()
    expect(map.zoom.value).toBe(2)
    expect(map.canvasStyle.value.transform).toContain('translate(10px, 215px)')
  })
})
