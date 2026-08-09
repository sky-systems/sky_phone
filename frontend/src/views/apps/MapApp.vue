<script setup lang="ts">
import {
  kButton,
  kFab,
  kList,
  kListInput,
  kPage,
  kPreloader,
  kSheet,
  kToast,
} from 'konsta/vue'
import {
  LocateFixed,
  Map,
  MapPin,
  MapPinned,
  MapPinPlus,
  Route,
  Satellite,
  Trash2,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import {
  clampDefaultMapPoint,
  defaultCayoStyle,
  defaultMainlandStyle,
  defaultMapCoordinates,
  defaultMapPercentToWorld,
  defaultMapWorldToPercent,
  type MapPoint,
} from '@/features/map/defaultMapGeometry'
import { useMapStore } from '@/stores/map'
import { usePhoneStore } from '@/stores/phone'
import type { MapMarker, MapMarkerColor } from '@/types/map'
import { nuiCall, type NuiResponse } from '@/utils/nui'

type MapStyle = 'default' | 'satellite' | 'atlas' | 'roads'

const phone = usePhoneStore()
const mapStore = useMapStore()
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
const placingMarker = ref(false)
const draftCoords = ref<(MapPoint & { z: number }) | null>(null)
const markerLabel = ref('')
const markerColor = ref<MapMarkerColor>('blue')
const selectedMarker = ref<MapMarker | null>(null)
const markerError = ref('')
const toastText = ref('')
let pointerMoveFrame: number | undefined
let wheelZoomFrame: number | undefined
let toastTimer: number | undefined
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
const markerColors: Array<{ id: MapMarkerColor; value: string }> = [
  { id: 'blue', value: '#0a84ff' },
  { id: 'green', value: '#30d158' },
  { id: 'orange', value: '#ff9f0a' },
  { id: 'red', value: '#ff453a' },
  { id: 'purple', value: '#bf5af2' },
]
const mapControlColors = {
  bgIos: 'bg-ios-light-glass dark:bg-ios-dark-glass',
  activeBgIos: 'active:bg-white/90 dark:active:bg-white/20',
  textIos: 'text-black dark:text-white',
}
const locationControlColors = {
  ...mapControlColors,
  textIos: 'text-white',
}
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

const percentToWorld = (point: MapPoint): MapPoint => {
  if (mapStyle.value === 'default') {
    return defaultMapPercentToWorld(point)
  }

  const projected = {
    x: mapBounds.minX + point.x * (mapBounds.maxX - mapBounds.minX),
    y: mapBounds.maxY - point.y * (mapBounds.maxY - mapBounds.minY),
  }
  return {
    x: (projected.x - mapOrigin.x) * mapScale.x,
    y: (projected.y - mapOrigin.y) * mapScale.y,
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

function markerStyle(marker: MapMarker): Record<string, string> {
  const percent = worldToPercent(marker.coords)
  return {
    left: `${percent.x * 100}%`,
    top: `${percent.y * 100}%`,
    transform: `translate(-50%, -100%) scale(${1 / zoom.value})`,
  }
}

function markerColorValue(color: MapMarkerColor): string {
  return (
    markerColors.find((candidate) => candidate.id === color)?.value ??
    markerColors[0].value
  )
}

function showToast(message: string): void {
  if (toastTimer) window.clearTimeout(toastTimer)
  toastText.value = message
  toastTimer = window.setTimeout(() => {
    toastText.value = ''
    toastTimer = undefined
  }, 2200)
}

function markerErrorText(error?: string): string {
  const key = error ?? 'request_failed'
  const translated = phone.t(`Apps.map.errors.${key}`)
  return translated === `Apps.map.errors.${key}`
    ? phone.t('Apps.map.errors.request_failed')
    : translated
}

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

function startMarkerPlacement(): void {
  selectedMarker.value = null
  draftCoords.value = null
  markerError.value = ''
  placingMarker.value = true
}

function cancelMarkerPlacement(): void {
  placingMarker.value = false
}

function openMarkerEditor(): void {
  const viewport = viewportRef.value?.getBoundingClientRect()
  const canvas = canvasRef.value?.getBoundingClientRect()
  if (!viewport || !canvas || canvas.width <= 0 || canvas.height <= 0) {
    showToast(phone.t('Apps.map.errors.request_failed'))
    return
  }

  const percent = {
    x: Math.min(
      1,
      Math.max(
        0,
        (viewport.left + viewport.width / 2 - canvas.left) / canvas.width,
      ),
    ),
    y: Math.min(
      1,
      Math.max(
        0,
        (viewport.top + viewport.height / 2 - canvas.top) / canvas.height,
      ),
    ),
  }
  const coords = percentToWorld(percent)
  draftCoords.value = {
    x: Math.round(coords.x * 100) / 100,
    y: Math.round(coords.y * 100) / 100,
    z: 0,
  }
  markerLabel.value = ''
  markerColor.value = 'blue'
  markerError.value = ''
  placingMarker.value = false
}

function updateMarkerLabel(event: Event): void {
  markerLabel.value = (event.target as HTMLInputElement).value
}

function closeMarkerSheet(): void {
  if (mapStore.isLoading) return
  draftCoords.value = null
  selectedMarker.value = null
  markerError.value = ''
}

function selectMarker(marker: MapMarker): void {
  if (placingMarker.value) return
  selectedMarker.value = marker
  markerError.value = ''
}

function handleMarkerResponse(
  response: NuiResponse,
  successMessage: string,
): boolean {
  if (!response.success) {
    markerError.value = markerErrorText(response.error)
    return false
  }
  showToast(successMessage)
  return true
}

async function saveMarker(): Promise<void> {
  const coords = draftCoords.value
  const label = markerLabel.value.trim()
  if (!coords || !label || label.length > 40) {
    markerError.value = phone.t('Apps.map.errors.invalid_marker')
    return
  }

  const response = await mapStore.create({
    color: markerColor.value,
    coords,
    label,
  })
  if (!handleMarkerResponse(response, phone.t('Apps.map.markerSaved'))) return
  draftCoords.value = null
}

async function deleteSelectedMarker(): Promise<void> {
  const marker = selectedMarker.value
  if (!marker) return
  const response = await mapStore.remove(marker.id)
  if (!handleMarkerResponse(response, phone.t('Apps.map.markerDeleted'))) return
  selectedMarker.value = null
}

async function setSelectedMarkerWaypoint(): Promise<void> {
  const marker = selectedMarker.value
  if (!marker) return

  const response = await nuiCall('map:setWaypoint', { coords: marker.coords })
  if (!handleMarkerResponse(response, phone.t('Apps.map.waypointSet'))) return
  selectedMarker.value = null
}

function changeZoom(direction: -1 | 1, focalPoint?: MapPoint): void {
  const targetZoom =
    direction > 0 ? zoom.value * zoomFactor : zoom.value / zoomFactor
  const nextZoom = Math.min(
    Math.max(Math.round(targetZoom * 1000) / 1000, minZoom),
    maxZoom,
  )
  if (nextZoom === zoom.value) return

  if (focalPoint && canvasRef.value && viewportRef.value) {
    const rect = canvasRef.value.getBoundingClientRect()
    const viewport = viewportRef.value.getBoundingClientRect()
    const renderedScaleX = viewport.width / viewportRef.value.clientWidth
    const renderedScaleY = viewport.height / viewportRef.value.clientHeight
    const offsetX = focalPoint.x - rect.left - rect.width / 2
    const offsetY = focalPoint.y - rect.top - rect.height / 2
    const scale = nextZoom / zoom.value
    pan.value = {
      x: pan.value.x - (offsetX * (scale - 1)) / renderedScaleX,
      y: pan.value.y - (offsetY * (scale - 1)) / renderedScaleY,
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
    const viewportElement = viewportRef.value
    const viewport = viewportElement?.getBoundingClientRect()
    if (!viewportElement || !viewport) return
    const renderedScaleX = viewport.width / viewportElement.clientWidth
    const renderedScaleY = viewport.height / viewportElement.clientHeight
    pan.value = {
      x: pointerStart.panX + deltaX / renderedScaleX,
      y: pointerStart.panY + deltaY / renderedScaleY,
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
  void mapStore.load()
})

onBeforeUnmount(() => {
  if (pointerMoveFrame) cancelAnimationFrame(pointerMoveFrame)
  if (wheelZoomFrame) cancelAnimationFrame(wheelZoomFrame)
  if (toastTimer) window.clearTimeout(toastTimer)
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
        <button
          v-for="marker in mapStore.markers"
          :key="marker.id"
          type="button"
          class="custom-map-marker"
          :style="markerStyle(marker)"
          :aria-label="marker.label"
          @pointerdown.stop
          @click.stop="selectMarker(marker)"
        >
          <MapPin
            :size="30"
            :style="{ color: markerColorValue(marker.color) }"
            fill="currentColor"
            aria-hidden="true"
          />
          <span>{{ marker.label }}</span>
        </button>
      </div>

      <div
        v-if="placingMarker"
        class="map-placement-crosshair"
        aria-hidden="true"
      >
        <span></span>
      </div>

      <p v-if="imageError" class="map-error">
        {{ phone.t('Apps.map.imageError') }}
      </p>
    </div>

    <nav class="map-controls" :aria-label="phone.t('Apps.map.controls')">
      <k-fab
        component="button"
        type="button"
        class="map-control"
        :colors="mapControlColors"
        :aria-label="`${phone.t('Apps.map.switchStyle')}: ${phone.t(`Apps.map.styles.${mapStyle}`)}`"
        @click="cycleMapStyle"
      >
        <template #icon>
          <component :is="activeMapStyle.icon" aria-hidden="true" />
        </template>
      </k-fab>
      <k-fab
        component="button"
        type="button"
        class="map-control map-control--marker"
        :colors="locationControlColors"
        :disabled="placingMarker"
        :aria-label="phone.t('Apps.map.addMarker')"
        @click="startMarkerPlacement"
      >
        <template #icon>
          <MapPinPlus aria-hidden="true" />
        </template>
      </k-fab>
      <k-fab
        component="button"
        type="button"
        class="map-control map-control--location"
        :colors="locationControlColors"
        :disabled="locating"
        :aria-label="phone.t('Apps.map.currentLocation')"
        @click="loadCurrentLocation(true)"
      >
        <template #icon>
          <LocateFixed aria-hidden="true" />
        </template>
      </k-fab>
    </nav>

    <section v-if="placingMarker" class="map-placement-panel">
      <strong>{{ phone.t('Apps.map.placeMarker') }}</strong>
      <span>{{ phone.t('Apps.map.placeMarkerHint') }}</span>
      <div>
        <k-button small rounded outline @click="cancelMarkerPlacement">
          <X :size="16" />
          {{ phone.t('Common.cancel') }}
        </k-button>
        <k-button small rounded @click="openMarkerEditor">
          <MapPin :size="16" />
          {{ phone.t('Apps.map.addHere') }}
        </k-button>
      </div>
    </section>

    <k-sheet
      :opened="Boolean(draftCoords || selectedMarker)"
      class="map-marker-sheet"
      @backdropclick="closeMarkerSheet"
    >
      <section
        v-if="draftCoords"
        class="map-marker-sheet__content"
        :class="{ 'map-marker-sheet__content--dark': phone.isDarkMode }"
        role="dialog"
        aria-modal="true"
        :aria-label="phone.t('Apps.map.newMarker')"
      >
        <h2>{{ phone.t('Apps.map.newMarker') }}</h2>
        <p>{{ phone.t('Apps.map.newMarkerDescription') }}</p>
        <k-list inset strong>
          <k-list-input
            input-id="map-marker-label"
            :label="phone.t('Apps.map.markerName')"
            :placeholder="phone.t('Apps.map.markerNamePlaceholder')"
            :value="markerLabel"
            maxlength="40"
            outline
            @input="updateMarkerLabel"
            @keydown.enter="saveMarker"
          />
        </k-list>
        <span class="map-marker-sheet__label">{{
          phone.t('Apps.map.markerColor')
        }}</span>
        <div
          class="map-marker-colors"
          role="radiogroup"
          :aria-label="phone.t('Apps.map.markerColor')"
        >
          <button
            v-for="color in markerColors"
            :key="color.id"
            type="button"
            role="radio"
            :aria-checked="markerColor === color.id"
            :aria-label="phone.t(`Apps.map.colors.${color.id}`)"
            :class="{ 'map-marker-color--active': markerColor === color.id }"
            :style="{ backgroundColor: color.value }"
            @click="markerColor = color.id"
          ></button>
        </div>
        <p v-if="markerError" class="map-marker-error" role="alert">
          {{ markerError }}
        </p>
        <k-button
          large
          rounded
          :disabled="mapStore.isLoading || !markerLabel.trim()"
          @click="saveMarker"
        >
          <k-preloader v-if="mapStore.isLoading" />
          <template v-else>{{ phone.t('Apps.map.saveMarker') }}</template>
        </k-button>
      </section>

      <section
        v-else-if="selectedMarker"
        class="map-marker-sheet__content map-marker-sheet__content--details"
        :class="{ 'map-marker-sheet__content--dark': phone.isDarkMode }"
        role="dialog"
        aria-modal="true"
        :aria-label="selectedMarker.label"
      >
        <span
          class="map-marker-sheet__pin"
          :style="{ color: markerColorValue(selectedMarker.color) }"
        >
          <MapPin :size="32" fill="currentColor" />
        </span>
        <h2>{{ selectedMarker.label }}</h2>
        <p>
          {{ selectedMarker.coords.x.toFixed(1) }},
          {{ selectedMarker.coords.y.toFixed(1) }}
        </p>
        <p v-if="markerError" class="map-marker-error" role="alert">
          {{ markerError }}
        </p>
        <k-button
          large
          rounded
          class="map-marker-waypoint"
          :disabled="mapStore.isLoading"
          @click="setSelectedMarkerWaypoint"
        >
          <Route :size="17" />
          {{ phone.t('Apps.map.setWaypoint') }}
        </k-button>
        <k-button
          large
          rounded
          class="map-marker-delete"
          :disabled="mapStore.isLoading"
          @click="deleteSelectedMarker"
        >
          <k-preloader v-if="mapStore.isLoading" />
          <template v-else>
            <Trash2 :size="17" />
            {{ phone.t('Apps.map.deleteMarker') }}
          </template>
        </k-button>
      </section>
    </k-sheet>

    <k-toast :opened="Boolean(toastText)" position="center">
      {{ toastText }}
    </k-toast>
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

.custom-map-marker {
  position: absolute;
  z-index: 2;
  display: flex;
  padding: 0;
  align-items: center;
  flex-direction: column;
  border: 0;
  color: #fff;
  background: transparent;
  filter: drop-shadow(0 2px 3px rgb(0 0 0 / 45%));
  transform-origin: 50% 100%;
  white-space: nowrap;
}

.custom-map-marker svg {
  stroke: #fff;
  stroke-width: 1.8;
}

.custom-map-marker span {
  max-width: 112px;
  padding: 3px 7px;
  overflow: hidden;
  border: 0.5px solid rgb(255 255 255 / 18%);
  border-radius: 8px;
  background: rgb(20 20 22 / 84%);
  box-shadow: 0 2px 7px rgb(0 0 0 / 30%);
  backdrop-filter: blur(12px);
  font-size: 10px;
  font-weight: 650;
  text-overflow: ellipsis;
}

.map-placement-crosshair {
  position: absolute;
  z-index: 2;
  top: 50%;
  left: 50%;
  width: 42px;
  height: 42px;
  border: 1px solid rgb(255 255 255 / 80%);
  border-radius: 50%;
  box-shadow:
    0 2px 12px rgb(0 0 0 / 40%),
    inset 0 0 0 1px rgb(0 0 0 / 16%);
  transform: translate(-50%, -50%);
  pointer-events: none;
}

.map-placement-crosshair::before,
.map-placement-crosshair::after,
.map-placement-crosshair span {
  position: absolute;
  top: 50%;
  left: 50%;
  background: #fff;
  content: '';
  transform: translate(-50%, -50%);
}

.map-placement-crosshair::before {
  width: 16px;
  height: 1px;
}

.map-placement-crosshair::after {
  width: 1px;
  height: 16px;
}

.map-placement-crosshair span {
  width: 5px;
  height: 5px;
  border: 1px solid rgb(0 0 0 / 35%);
  border-radius: 50%;
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
  --color-primary: #8e8e93;
}

.map-control svg {
  width: 21px;
  height: 21px;
}

.map-control--marker {
  --color-primary: #0a84ff;
}

.map-placement-panel {
  position: absolute;
  z-index: 4;
  right: 66px;
  bottom: 28px;
  left: 12px;
  display: flex;
  min-height: 84px;
  padding: 12px;
  flex-direction: column;
  border: 0.5px solid rgb(255 255 255 / 22%);
  border-radius: 18px;
  color: #fff;
  background: rgb(24 24 27 / 86%);
  box-shadow: 0 8px 24px rgb(0 0 0 / 32%);
  backdrop-filter: blur(22px) saturate(145%);
}

.map-placement-panel strong {
  font-size: 13px;
}

.map-placement-panel > span {
  margin-top: 2px;
  color: rgb(255 255 255 / 64%);
  font-size: 10px;
  line-height: 1.25;
}

.map-placement-panel > div {
  display: grid;
  margin-top: 10px;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}

.map-placement-panel :deep(button) {
  min-height: 32px;
  font-size: 11px;
}

.map-marker-sheet__content {
  display: flex;
  min-height: 350px;
  padding: 22px 16px calc(18px + env(safe-area-inset-bottom));
  flex-direction: column;
  color: #111;
}

.map-marker-sheet__content--dark {
  color: #fff;
}

.map-marker-sheet__content h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 750;
  letter-spacing: -0.4px;
  text-align: center;
}

.map-marker-sheet__content > p {
  margin: 5px 0 14px;
  color: rgb(60 60 67 / 60%);
  font-size: 12px;
  line-height: 1.4;
  text-align: center;
}

.map-marker-sheet__content--dark > p {
  color: rgb(235 235 245 / 60%);
}

.map-marker-sheet__label {
  margin: 13px 5px 8px;
  color: rgb(60 60 67 / 60%);
  font-size: 12px;
}

.map-marker-sheet__content--dark .map-marker-sheet__label {
  color: rgb(235 235 245 / 60%);
}

.map-marker-colors {
  display: flex;
  margin-bottom: 18px;
  justify-content: center;
  gap: 14px;
}

.map-marker-colors button {
  width: 31px;
  height: 31px;
  padding: 0;
  border: 3px solid transparent;
  border-radius: 50%;
  box-shadow: 0 1px 4px rgb(0 0 0 / 25%);
}

.map-marker-colors .map-marker-color--active {
  border-color: #fff;
  outline: 2px solid #0a84ff;
}

.map-marker-error {
  color: #ff3b30 !important;
  font-size: 11px !important;
}

.map-marker-sheet__content--details {
  min-height: 250px;
  align-items: center;
}

.map-marker-sheet__pin {
  display: grid;
  width: 58px;
  height: 58px;
  margin-bottom: 10px;
  place-items: center;
  border-radius: 18px;
  background: rgb(120 120 128 / 12%);
}

.map-marker-sheet__pin svg {
  stroke: #fff;
}

.map-marker-sheet__content .map-marker-delete {
  width: 100%;
  margin-top: 10px;
  color: #fff;
  background: #ff3b30;
}

.map-marker-sheet__content .map-marker-waypoint {
  width: 100%;
  margin-top: auto;
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
