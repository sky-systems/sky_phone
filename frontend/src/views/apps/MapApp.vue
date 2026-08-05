<script setup lang="ts">
import { kButton, kPage } from 'konsta/vue'
import { LocateFixed, Map, MapPinned, Route, Satellite } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import {
  clampDefaultMapPoint,
  defaultCayoStyle,
  defaultMainlandStyle,
  defaultMapCoordinates,
  defaultMapWorldToPercent,
  type MapPoint,
} from '@/features/map/defaultMapGeometry'
import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'

type MapStyle = 'default' | 'satellite' | 'atlas' | 'roads'

const phone = usePhoneStore()
const mapStyle = ref<MapStyle>('default')
const zoom = ref(1.1)
const pan = ref<MapPoint>({ x: 0, y: 0 })
const currentLocation = ref<MapPoint | null>(null)
const mapAspect = ref(
  defaultMapCoordinates.width / defaultMapCoordinates.height,
)
const imageError = ref(false)
const locating = ref(false)
const viewportRef = ref<HTMLElement | null>(null)
const canvasRef = ref<HTMLElement | null>(null)
const locationRef = ref<HTMLElement | null>(null)
const isPointerDown = ref(false)
const isPanning = ref(false)
let pointerMoveFrame: number | undefined
let wheelZoomFrame: number | undefined
let pendingWheelDirection: -1 | 0 | 1 = 0
let pendingWheelPoint: MapPoint | undefined

const pointerStart = {
  x: 0,
  y: 0,
  panX: 0,
  panY: 0,
}

const mapBounds = {
  minX: -4096,
  maxX: 4096,
  minY: -4096,
  maxY: 4096,
}
const mapOrigin = { x: -336.8, y: -1412.2 }
const mapScale = { x: -2340 / -1548.1, y: 291 / 189.3 }
const zoomFactor = 1.35
const minZoom = 0.7
const maxZoom = 12.3

const mapStyles = [
  { id: 'default' as const, icon: MapPinned },
  { id: 'satellite' as const, icon: Satellite },
  { id: 'atlas' as const, icon: Map },
  { id: 'roads' as const, icon: Route },
]
const activeMapStyle = computed(
  () => mapStyles.find((style) => style.id === mapStyle.value) ?? mapStyles[0],
)

const mapImageUrl = computed(() => {
  const filename =
    mapStyle.value === 'default'
      ? 'gtav-map.svg'
      : mapStyle.value === 'roads'
        ? 'map_roads_4096.webp'
        : mapStyle.value === 'atlas'
          ? 'map_atlas_4096.webp'
          : 'map_satellite_4096.webp'
  return `${import.meta.env.BASE_URL}img/maps/${filename}`
})
const cayoMapImageUrl = `${import.meta.env.BASE_URL}img/maps/cayo-perico.svg`

const canvasStyle = computed(() => ({
  aspectRatio: String(mapAspect.value),
  transform: `translate(-50%, -50%) translate(${pan.value.x}px, ${pan.value.y}px) scale(${zoom.value})`,
  width: 'max(120%, 120vh)',
}))

const mapToWorld = (coords: MapPoint): MapPoint => ({
  x: coords.x / mapScale.x + mapOrigin.x,
  y: coords.y / mapScale.y + mapOrigin.y,
})

const worldToPercent = (coords: MapPoint): MapPoint => {
  if (mapStyle.value === 'default') {
    return defaultMapWorldToPercent(coords)
  }

  const world = mapToWorld(coords)
  return {
    x: Math.min(
      Math.max(
        (world.x - mapBounds.minX) / (mapBounds.maxX - mapBounds.minX),
        0,
      ),
      1,
    ),
    y: Math.min(
      Math.max(
        (mapBounds.maxY - world.y) / (mapBounds.maxY - mapBounds.minY),
        0,
      ),
      1,
    ),
  }
}

const locationStyle = computed(() => {
  if (!currentLocation.value) return undefined
  const percent = worldToPercent(currentLocation.value)
  return {
    left: `${percent.x * 100}%`,
    top: `${percent.y * 100}%`,
    transform: `translate(-50%, -50%) scale(${1 / zoom.value})`,
  }
})

function setMapStyle(style: MapStyle): void {
  mapStyle.value = style
  imageError.value = false
}

function cycleMapStyle(): void {
  const currentIndex = mapStyles.findIndex(
    (style) => style.id === mapStyle.value,
  )
  setMapStyle(mapStyles[(currentIndex + 1) % mapStyles.length].id)
}

function changeZoom(direction: -1 | 1, focalPoint?: MapPoint): void {
  const targetZoom =
    direction > 0 ? zoom.value * zoomFactor : zoom.value / zoomFactor
  const nextZoom = Math.min(
    Math.max(Math.round(targetZoom * 1000) / 1000, minZoom),
    maxZoom,
  )
  if (nextZoom === zoom.value) return

  if (focalPoint && canvasRef.value) {
    const rect = canvasRef.value.getBoundingClientRect()
    const offsetX = focalPoint.x - rect.left - rect.width / 2
    const offsetY = focalPoint.y - rect.top - rect.height / 2
    const scale = nextZoom / zoom.value
    pan.value = {
      x: pan.value.x - offsetX * (scale - 1),
      y: pan.value.y - offsetY * (scale - 1),
    }
  }

  zoom.value = nextZoom
}

function onPointerDown(event: PointerEvent): void {
  if (event.pointerType === 'mouse' && event.button !== 0) return
  isPointerDown.value = true
  isPanning.value = false
  pointerStart.x = event.clientX
  pointerStart.y = event.clientY
  pointerStart.panX = pan.value.x
  pointerStart.panY = pan.value.y
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function onPointerMove(event: PointerEvent): void {
  if (!isPointerDown.value) return
  const deltaX = event.clientX - pointerStart.x
  const deltaY = event.clientY - pointerStart.y
  if (Math.abs(deltaX) > 4 || Math.abs(deltaY) > 4) {
    isPanning.value = true
  }
  if (!isPanning.value) return
  if (pointerMoveFrame) cancelAnimationFrame(pointerMoveFrame)
  pointerMoveFrame = requestAnimationFrame(() => {
    pointerMoveFrame = undefined
    pan.value = {
      x: pointerStart.panX + deltaX,
      y: pointerStart.panY + deltaY,
    }
  })
}

function onPointerUp(): void {
  isPointerDown.value = false
  isPanning.value = false
}

function onWheel(event: WheelEvent): void {
  event.preventDefault()
  event.stopPropagation()
  pendingWheelDirection = event.deltaY > 0 ? -1 : 1
  pendingWheelPoint = { x: event.clientX, y: event.clientY }
  if (wheelZoomFrame) return
  wheelZoomFrame = requestAnimationFrame(() => {
    wheelZoomFrame = undefined
    if (pendingWheelDirection !== 0) {
      changeZoom(pendingWheelDirection, pendingWheelPoint)
    }
    pendingWheelDirection = 0
    pendingWheelPoint = undefined
  })
}

function onImageLoad(event: Event): void {
  const image = event.target as HTMLImageElement
  mapAspect.value =
    mapStyle.value === 'default'
      ? defaultMapCoordinates.width / defaultMapCoordinates.height
      : image.naturalWidth / image.naturalHeight
  imageError.value = false
}

async function loadCurrentLocation(center: boolean): Promise<void> {
  locating.value = true
  const response = await nuiCall<{ coords?: MapPoint }>('map:getPlayerCoords')
  locating.value = false
  if (!response.success || !response.data?.coords) return

  currentLocation.value = clampDefaultMapPoint(response.data.coords)
  if (!center) return

  zoom.value = 3
  pan.value = { x: 0, y: 0 }
  await nextTick()
  const viewportElement = viewportRef.value
  const viewport = viewportElement?.getBoundingClientRect()
  const location = locationRef.value?.getBoundingClientRect()
  if (!viewportElement || !viewport || !location) return
  const renderedScaleX = viewport.width / viewportElement.clientWidth
  const renderedScaleY = viewport.height / viewportElement.clientHeight
  pan.value = {
    x:
      (viewport.left +
        viewport.width / 2 -
        (location.left + location.width / 2)) /
      renderedScaleX,
    y:
      (viewport.top +
        viewport.height / 2 -
        (location.top + location.height / 2)) /
      renderedScaleY,
  }
}

onMounted(() => {
  void loadCurrentLocation(false)
})

onBeforeUnmount(() => {
  if (pointerMoveFrame) cancelAnimationFrame(pointerMoveFrame)
  if (wheelZoomFrame) cancelAnimationFrame(wheelZoomFrame)
})
</script>

<template>
  <k-page class="map-app">
    <div
      ref="viewportRef"
      class="map-viewport"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
      @wheel="onWheel"
    >
      <div ref="canvasRef" class="map-canvas" :style="canvasStyle">
        <img
          :src="mapImageUrl"
          alt=""
          class="map-image"
          :class="{ 'map-image-default': mapStyle === 'default' }"
          :style="mapStyle === 'default' ? defaultMainlandStyle : undefined"
          decoding="async"
          draggable="false"
          @dragstart.prevent
          @load="onImageLoad"
          @error="imageError = true"
        />
        <img
          v-if="mapStyle === 'default'"
          :src="cayoMapImageUrl"
          alt=""
          class="map-default-layer"
          :style="defaultCayoStyle"
          decoding="async"
          draggable="false"
          @dragstart.prevent
          @error="imageError = true"
        />
        <div
          v-if="currentLocation && locationStyle"
          ref="locationRef"
          class="current-location"
          :style="locationStyle"
        >
          <span class="current-location__pulse"></span>
          <span class="current-location__dot"></span>
        </div>
      </div>

      <p v-if="imageError" class="map-error">
        {{ phone.t('Apps.map.imageError') }}
      </p>
    </div>

    <nav class="map-controls" :aria-label="phone.t('Apps.map.controls')">
      <k-button
        rounded
        tonal
        class="map-control"
        :aria-label="`${phone.t('Apps.map.switchStyle')}: ${phone.t(`Apps.map.styles.${mapStyle}`)}`"
        @click="cycleMapStyle"
      >
        <component :is="activeMapStyle.icon" aria-hidden="true" />
      </k-button>
      <k-button
        rounded
        class="map-control map-control--location"
        :disabled="locating"
        :aria-label="phone.t('Apps.map.currentLocation')"
        @click="loadCurrentLocation(true)"
      >
        <LocateFixed aria-hidden="true" />
      </k-button>
    </nav>
  </k-page>
</template>

<style scoped>
.map-app {
  position: relative;
  overflow: hidden;
  background: #111827;
}

.map-viewport {
  position: absolute;
  inset: 0;
  overflow: hidden;
  touch-action: none;
  user-select: none;
  background: #111827;
}

.map-canvas {
  position: absolute;
  top: 50%;
  left: 50%;
  height: auto;
  transform-origin: center;
  user-select: none;
}

.map-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: saturate(1.05) contrast(1.02);
  user-select: none;
}

.map-image-default,
.map-default-layer {
  position: absolute;
  display: block;
  object-fit: fill;
}

.map-default-layer {
  pointer-events: none;
  user-select: none;
}

.current-location {
  position: absolute;
  width: 18px;
  height: 18px;
  pointer-events: none;
}

.current-location__pulse,
.current-location__dot {
  position: absolute;
  inset: 0;
  border-radius: 50%;
}

.current-location__pulse {
  background: rgb(0 122 255 / 25%);
  border: 1px solid rgb(255 255 255 / 80%);
}

.current-location__dot {
  inset: 5px;
  background: #007aff;
  border: 1.5px solid #fff;
  box-shadow: 0 1px 4px rgb(0 0 0 / 35%);
}

.map-controls {
  position: absolute;
  z-index: 3;
  right: 12px;
  bottom: 28px;
  display: flex;
  flex-direction: column;
  gap: 7px;
  pointer-events: auto;
}

.map-control {
  width: 46px;
  min-width: 46px;
  height: 46px;
  padding: 0;
  color: #1c1c1e;
  background: rgb(242 242 247 / 90%);
  box-shadow: 0 5px 18px rgb(0 0 0 / 24%);
}

.map-control svg {
  width: 21px;
  height: 21px;
}

.map-control--location {
  color: #fff;
  background: #007aff;
}

.map-error {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 70%;
  padding: 12px;
  margin: 0;
  color: #fff;
  text-align: center;
  transform: translate(-50%, -50%);
  border-radius: 12px;
  background: rgb(0 0 0 / 70%);
}
</style>
