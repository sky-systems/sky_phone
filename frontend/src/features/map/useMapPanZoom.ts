import { computed, ref, watch, type Ref } from 'vue'

import type { MapPoint } from './defaultMapGeometry'
import { clampMapPan, zoomPanAtPoint } from './mapViewport'

export function useMapPanZoom(
  viewportRef: Ref<HTMLElement | null>,
  canvasRef: Ref<HTMLElement | null>,
) {
  const zoom = ref(1)
  const pan = ref<MapPoint>({ x: 0, y: 0 })
  const dragging = ref(false)
  const minZoom = 1
  const maxZoom = 8
  let gesture: {
    id: number
    start: MapPoint
    previous: MapPoint
    target: Element
  } | null = null
  let suppressClick = false

  const canvasStyle = computed(() => ({
    transform: `translate(${pan.value.x}px, ${pan.value.y}px) scale(${zoom.value})`,
    '--citywarn-map-pin-scale': String(1 / zoom.value),
  }))

  function metrics() {
    const viewport = viewportRef.value
    const canvas = canvasRef.value
    if (!viewport || !canvas || !viewport.clientWidth || !viewport.clientHeight)
      return null
    return {
      viewportWidth: viewport.clientWidth,
      viewportHeight: viewport.clientHeight,
      canvasWidth: canvas.clientWidth,
      canvasHeight: canvas.clientHeight,
    }
  }

  function move(next: MapPoint): void {
    const size = metrics()
    if (size) pan.value = clampMapPan(next, zoom.value, size)
  }

  function localPoint(client: MapPoint): MapPoint | null {
    const viewport = viewportRef.value
    const bounds = viewport?.getBoundingClientRect()
    if (!viewport || !bounds?.width || !bounds.height) return null
    // The phone itself can be scaled; client coordinates are rendered pixels.
    return {
      x: ((client.x - bounds.left) * viewport.clientWidth) / bounds.width,
      y: ((client.y - bounds.top) * viewport.clientHeight) / bounds.height,
    }
  }

  function changeZoom(requested: number, focalClientPoint?: MapPoint): void {
    const size = metrics()
    if (!size) return
    const next = Math.max(minZoom, Math.min(maxZoom, requested))
    const focal = focalClientPoint
      ? localPoint(focalClientPoint)
      : { x: size.viewportWidth / 2, y: size.viewportHeight / 2 }
    if (!focal) return
    const nextPan = zoomPanAtPoint(pan.value, zoom.value, next, focal, {
      x: size.viewportWidth,
      y: size.viewportHeight,
    })
    zoom.value = next
    move(nextPan)
  }

  function endGesture(): void {
    const previous = gesture
    gesture = null
    dragging.value = false
    if (previous?.target.hasPointerCapture(previous.id))
      previous.target.releasePointerCapture(previous.id)
  }

  function reset(): void {
    endGesture()
    zoom.value = minZoom
    pan.value = { x: 0, y: 0 }
  }

  function onPointerDown(event: PointerEvent): void {
    if (!event.isPrimary || event.button !== 0 || gesture) return
    suppressClick = false
    if ((event.target as Element).closest('[data-map-controls]')) return
    const viewport = viewportRef.value
    if (!viewport) return
    // Capture on the original pin when tapped, so a click still reaches that pin.
    const target = (event.target as Element).closest('button') ?? viewport
    const point = { x: event.clientX, y: event.clientY }
    gesture = { id: event.pointerId, start: point, previous: point, target }
    target.setPointerCapture(event.pointerId)
  }

  function onPointerMove(event: PointerEvent): void {
    if (!gesture || event.pointerId !== gesture.id) return
    const point = { x: event.clientX, y: event.clientY }
    if (
      !dragging.value &&
      Math.hypot(point.x - gesture.start.x, point.y - gesture.start.y) < 4
    )
      return
    const previous = localPoint(gesture.previous)
    const current = localPoint(point)
    if (!previous || !current) return
    dragging.value = true
    suppressClick = true
    move({
      x: pan.value.x + current.x - previous.x,
      y: pan.value.y + current.y - previous.y,
    })
    gesture.previous = point
  }

  function onPointerEnd(event: PointerEvent): void {
    if (event.pointerId === gesture?.id) endGesture()
  }

  function onClickCapture(event: MouseEvent): void {
    // Pointer-generated clicks after a drag are suppressed; keyboard clicks remain usable.
    if (suppressClick && event.detail !== 0) {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  function onWheel(event: WheelEvent): void {
    event.preventDefault()
    event.stopPropagation()
    const unit =
      event.deltaMode === 1
        ? 16
        : event.deltaMode === 2
          ? (viewportRef.value?.clientHeight ?? 430)
          : 1
    const delta = Math.max(-240, Math.min(240, event.deltaY * unit))
    changeZoom(zoom.value * Math.exp(-delta * 0.0024), {
      x: event.clientX,
      y: event.clientY,
    })
  }

  function onKeydown(event: KeyboardEvent): void {
    if (event.target !== event.currentTarget) return
    const moves: Record<string, MapPoint> = {
      ArrowLeft: { x: 40, y: 0 },
      ArrowRight: { x: -40, y: 0 },
      ArrowUp: { x: 0, y: 40 },
      ArrowDown: { x: 0, y: -40 },
    }
    if (moves[event.key])
      move({
        x: pan.value.x + moves[event.key]!.x,
        y: pan.value.y + moves[event.key]!.y,
      })
    else if (event.key === '+' || event.key === '=')
      changeZoom(zoom.value * 1.25)
    else if (event.key === '-') changeZoom(zoom.value / 1.25)
    else if (event.key === 'Home') reset()
    else return
    event.preventDefault()
    event.stopPropagation()
  }

  watch(
    [viewportRef, canvasRef],
    ([viewport, canvas], _, onCleanup) => {
      if (!viewport || !canvas) return
      const observer = new ResizeObserver(() => move(pan.value))
      observer.observe(viewport)
      observer.observe(canvas)
      move(pan.value)
      onCleanup(() => {
        observer.disconnect()
        endGesture()
      })
    },
    { flush: 'post', immediate: true },
  )

  return {
    canvasStyle,
    changeZoom,
    dragging,
    maxZoom,
    minZoom,
    onClickCapture,
    onKeydown,
    onPointerDown,
    onPointerEnd,
    onPointerMove,
    onWheel,
    reset,
    zoom,
  }
}
