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

function setup() {
  const captured = new Set<number>()
  const capture = {
    setPointerCapture: vi.fn((id: number) => captured.add(id)),
    hasPointerCapture: (id: number) => captured.has(id),
    releasePointerCapture: vi.fn((id: number) => captured.delete(id)),
  }
  const viewport = {
    ...capture,
    clientWidth: 360,
    clientHeight: 430,
    getBoundingClientRect: () => ({
      left: 100,
      top: 50,
      width: 180,
      height: 215,
    }),
    closest: () => null,
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
