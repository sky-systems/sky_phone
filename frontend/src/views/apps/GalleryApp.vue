<script setup lang="ts">
import {
  kBlock,
  kButton,
  kDialog,
  kLink,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPreloader,
  kSegmented,
  kSegmentedButton,
  kToast,
} from 'konsta/vue'
import { Play, RotateCcw, Trash2, ZoomIn, ZoomOut } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { DeleteResult, GalleryFilter, PhoneMedia } from '@/types/media'
import { mediaErrorKey, mergeMedia } from '@/utils/media'
import { nuiCall } from '@/utils/nui'

const isDevelopment = import.meta.env.DEV
const developmentGalleryState = isDevelopment
  ? new URLSearchParams(window.location.search).get('galleryMock')
  : null
const pageSize = 36
const phone = usePhoneStore()
const media = ref<PhoneMedia[]>([])
const filter = ref<GalleryFilter>('all')
const loading = ref(true)
const fetching = ref(false)
const hasMore = ref(true)
const loadError = ref('')
const selected = ref<PhoneMedia | null>(null)
const deleteDialogOpened = ref(false)
const cancelButtonColors = {
  fillBgIos: 'bg-[#8e8e93] active:bg-[#7a7a7f]',
  fillBgMaterial: 'bg-[#8e8e93] active:bg-[#7a7a7f]',
  fillTextIos: 'text-white',
  fillTextMaterial: 'text-white',
}
const deleteButtonColors = {
  fillBgIos: 'bg-[#ff3b30] active:bg-[#d9342b]',
  fillBgMaterial: 'bg-[#ff3b30] active:bg-[#d9342b]',
  fillTextIos: 'text-white',
  fillTextMaterial: 'text-white',
}
const deleting = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
const loadTrigger = ref<HTMLElement | null>(null)
const imageZoom = ref(1)
const imagePan = ref({ x: 0, y: 0 })
const dragging = ref(false)
const dragStart = ref({ panX: 0, panY: 0, x: 0, y: 0 })
let observer: IntersectionObserver | null = null
let toastTimer: number | undefined
let pendingDeleteCorrelation = ''

const countLabel = computed(() =>
  phone.t('Apps.photos.count', { count: String(media.value.length) }),
)
const imageStyle = computed(() => ({
  cursor:
    imageZoom.value > 1 ? (dragging.value ? 'grabbing' : 'grab') : 'zoom-in',
  transform: `translate3d(${imagePan.value.x}px, ${imagePan.value.y}px, 0) scale(${imageZoom.value})`,
}))

function buildMockPhoto(
  id: number,
  label: string,
  first: string,
  second: string,
): PhoneMedia {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="1200"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${first}"/><stop offset="1" stop-color="${second}"/></linearGradient></defs><rect width="900" height="1200" fill="url(#g)"/><circle cx="680" cy="290" r="180" fill="#ffffff20"/><path d="M0 930 230 650l190 190 120-130 360 300v190H0z" fill="#08131d66"/><text x="70" y="1080" fill="white" font-size="54" font-family="sans-serif">${label}</text></svg>`
  return {
    createdAt: Date.now() - id * 3_600_000,
    id,
    mediaType: 'photo',
    url: `data:image/svg+xml,${encodeURIComponent(svg)}`,
  }
}

function mockMedia(): PhoneMedia[] {
  const photos = [
    buildMockPhoto(1, 'Vespucci', '#23567b', '#e08d5c'),
    buildMockPhoto(2, 'Downtown', '#442c69', '#c86a77'),
    buildMockPhoto(3, 'Paleto Bay', '#1f6653', '#d1a85b'),
    buildMockPhoto(4, 'Mirror Park', '#355c7d', '#6c5b7b'),
    buildMockPhoto(5, 'Del Perro', '#b06ab3', '#4568dc'),
    buildMockPhoto(6, 'Sandy Shores', '#7b4f35', '#d2a35f'),
    buildMockPhoto(7, 'Rockford', '#203a43', '#2c5364'),
    buildMockPhoto(8, 'Little Seoul', '#8e2de2', '#4a00e0'),
  ]
  return [
    photos[0],
    {
      createdAt: Date.now() - 1_800_000,
      id: 100,
      mediaType: 'video',
      url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    },
    ...photos.slice(1),
  ]
}

function showToast(text: string): void {
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  toastText.value = text
  toastOpened.value = true
  toastTimer = window.setTimeout(() => {
    toastOpened.value = false
  }, 3000)
}

function formatDate(timestamp: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(timestamp))
}

async function fetchMore(): Promise<void> {
  if (fetching.value || !hasMore.value) return
  fetching.value = true
  const offset = media.value.length
  const response = await nuiCall<PhoneMedia[]>('gallery:list', {
    limit: pageSize,
    mediaType: filter.value === 'all' ? undefined : filter.value,
    mockState: developmentGalleryState ?? undefined,
    offset,
  })
  if (response.success && Array.isArray(response.data)) {
    media.value = mergeMedia(media.value, response.data)
    hasMore.value = response.data.length === pageSize
  } else if (
    isDevelopment &&
    developmentGalleryState !== 'error' &&
    offset === 0
  ) {
    const mock = mockMedia().filter(
      (entry) => filter.value === 'all' || entry.mediaType === filter.value,
    )
    media.value = mock
    hasMore.value = false
  } else {
    if (offset === 0) {
      loadError.value = phone.t(
        `Apps.photos.errors.${mediaErrorKey(response.error)}`,
      )
    }
    hasMore.value = false
  }
  fetching.value = false
}

async function loadGallery(): Promise<void> {
  media.value = []
  hasMore.value = true
  loadError.value = ''
  loading.value = true
  await fetchMore()
  loading.value = false
  await nextTick()
  observeMore()
}

function observeMore(): void {
  observer?.disconnect()
  observer = null
  if (!hasMore.value || !loadTrigger.value) return
  observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) void fetchMore()
    },
    { rootMargin: '180px' },
  )
  observer.observe(loadTrigger.value)
}

function openMedia(entry: PhoneMedia): void {
  selected.value = entry
  imageZoom.value = 1
  imagePan.value = { x: 0, y: 0 }
}

function closeMedia(): void {
  selected.value = null
  deleteDialogOpened.value = false
  stopDragging()
}

function setZoom(value: number): void {
  imageZoom.value = Math.min(4, Math.max(1, value))
  if (imageZoom.value === 1) imagePan.value = { x: 0, y: 0 }
}

function startDragging(event: PointerEvent): void {
  if (imageZoom.value === 1) {
    setZoom(2)
    return
  }
  dragging.value = true
  dragStart.value = {
    panX: imagePan.value.x,
    panY: imagePan.value.y,
    x: event.clientX,
    y: event.clientY,
  }
  window.addEventListener('pointermove', moveImage)
  window.addEventListener('pointerup', stopDragging)
}

function moveImage(event: PointerEvent): void {
  if (!dragging.value) return
  imagePan.value = {
    x: dragStart.value.panX + event.clientX - dragStart.value.x,
    y: dragStart.value.panY + event.clientY - dragStart.value.y,
  }
}

function stopDragging(): void {
  dragging.value = false
  window.removeEventListener('pointermove', moveImage)
  window.removeEventListener('pointerup', stopDragging)
}

async function deleteSelected(): Promise<void> {
  if (!selected.value || deleting.value) return
  deleting.value = true
  deleteDialogOpened.value = false
  pendingDeleteCorrelation = `${Date.now()}-${crypto.randomUUID()}`
  if (isDevelopment) {
    window.setTimeout(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          data: {
            data: {
              correlationId: pendingDeleteCorrelation,
              id: selected.value?.id,
              success: true,
            },
            type: 'media:deleteResult',
          },
        }),
      )
    }, 500)
    return
  }
  await nuiCall('gallery:delete', {
    correlationId: pendingDeleteCorrelation,
    id: selected.value.id,
  })
}

function onMessage(event: MessageEvent): void {
  const message = event.data as { data?: DeleteResult; type?: string }
  if (
    message.type !== 'media:deleteResult' ||
    message.data?.correlationId !== pendingDeleteCorrelation
  ) {
    return
  }
  deleting.value = false
  if (message.data.success && message.data.id) {
    media.value = media.value.filter((entry) => entry.id !== message.data?.id)
    closeMedia()
    showToast(phone.t('Apps.photos.deleted'))
  } else {
    showToast(
      phone.t(`Apps.photos.errors.${mediaErrorKey(message.data.error)}`),
    )
  }
}

watch(filter, () => void loadGallery())
watch(hasMore, () => void nextTick().then(observeMore))

onMounted(() => {
  window.addEventListener('message', onMessage)
  void loadGallery()
})

onBeforeUnmount(() => {
  observer?.disconnect()
  stopDragging()
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  window.removeEventListener('message', onMessage)
})
</script>

<template>
  <k-page
    v-if="!selected"
    class="gallery-page !pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.photos.name')"
  >
    <k-navbar large transparent :title="phone.t('Apps.photos.name')">
      <template #right>
        <span class="gallery-count">{{ countLabel }}</span>
      </template>
      <template #subnavbar>
        <k-segmented class="gallery-filter">
          <k-segmented-button
            :active="filter === 'all'"
            @click="filter = 'all'"
          >
            {{ phone.t('Apps.photos.filters.all') }}
          </k-segmented-button>
          <k-segmented-button
            :active="filter === 'photo'"
            @click="filter = 'photo'"
          >
            {{ phone.t('Apps.photos.filters.photos') }}
          </k-segmented-button>
          <k-segmented-button
            :active="filter === 'video'"
            @click="filter = 'video'"
          >
            {{ phone.t('Apps.photos.filters.videos') }}
          </k-segmented-button>
        </k-segmented>
      </template>
    </k-navbar>

    <div v-if="loading" class="gallery-state">
      <k-preloader />
      <span>{{ phone.t('Apps.photos.loading') }}</span>
    </div>
    <k-block v-else-if="loadError" strong inset class="gallery-error">
      {{ loadError }}
    </k-block>
    <div v-else-if="!media.length" class="gallery-state gallery-empty">
      <strong>{{ phone.t('Apps.photos.emptyTitle') }}</strong>
      <span>{{ phone.t('Apps.photos.emptyBody') }}</span>
    </div>
    <div v-else class="gallery-grid">
      <button
        v-for="entry in media"
        :key="entry.id"
        class="gallery-tile"
        type="button"
        :aria-label="
          phone.t(
            entry.mediaType === 'video'
              ? 'Apps.photos.videoAlt'
              : 'Apps.photos.photoAlt',
          )
        "
        @click="openMedia(entry)"
      >
        <img
          v-if="entry.mediaType === 'photo'"
          :src="entry.url"
          alt=""
          loading="lazy"
        />
        <video
          v-else
          :src="entry.url"
          muted
          playsinline
          preload="metadata"
        ></video>
        <span v-if="entry.mediaType === 'video'" class="gallery-video-badge">
          <Play :size="16" fill="currentColor" />
        </span>
      </button>
      <span
        v-if="hasMore"
        ref="loadTrigger"
        class="gallery-load-trigger"
      ></span>
    </div>
  </k-page>

  <k-page v-else class="gallery-detail !pt-[44px] !pb-[25px]">
    <k-navbar
      :title="
        phone.t(
          selected.mediaType === 'video'
            ? 'Apps.photos.video'
            : 'Apps.photos.photo',
        )
      "
    >
      <template #left>
        <k-navbar-back-link
          component="button"
          :text="phone.t('Common.back')"
          @click="closeMedia"
        />
      </template>
      <template #right>
        <k-link
          component="button"
          icon-only
          class="text-red-500"
          :aria-label="phone.t('Apps.photos.delete')"
          :disabled="deleting"
          @click="deleteDialogOpened = true"
        >
          <Trash2 :size="20" />
        </k-link>
      </template>
    </k-navbar>

    <div class="gallery-detail-stage">
      <img
        v-if="selected.mediaType === 'photo'"
        :src="selected.url"
        :alt="phone.t('Apps.photos.photoAlt')"
        :style="imageStyle"
        draggable="false"
        @pointerdown="startDragging"
        @dblclick="setZoom(imageZoom === 1 ? 2 : 1)"
      />
      <video v-else :src="selected.url" controls autoplay playsinline></video>
    </div>

    <nav v-if="selected.mediaType === 'photo'" class="gallery-zoom-controls">
      <k-link
        component="button"
        icon-only
        :aria-label="phone.t('Apps.photos.zoomOut')"
        :disabled="imageZoom === 1"
        @click="setZoom(imageZoom - 0.5)"
        ><ZoomOut :size="20"
      /></k-link>
      <k-link
        component="button"
        icon-only
        :aria-label="phone.t('Apps.photos.resetZoom')"
        :disabled="imageZoom === 1"
        @click="setZoom(1)"
        ><RotateCcw :size="19"
      /></k-link>
      <k-link
        component="button"
        icon-only
        :aria-label="phone.t('Apps.photos.zoomIn')"
        :disabled="imageZoom === 4"
        @click="setZoom(imageZoom + 0.5)"
        ><ZoomIn :size="20"
      /></k-link>
    </nav>
    <div class="gallery-detail-date">{{ formatDate(selected.createdAt) }}</div>
  </k-page>

  <k-dialog
    :opened="deleteDialogOpened"
    @backdropclick="deleteDialogOpened = false"
  >
    <template #title>{{ phone.t('Apps.photos.deleteTitle') }}</template>
    <p>{{ phone.t('Apps.photos.deleteBody') }}</p>
    <template #buttons>
      <k-button
        large
        rounded
        :colors="cancelButtonColors"
        @click="deleteDialogOpened = false"
      >
        {{ phone.t('Common.cancel') }}
      </k-button>
      <k-button
        large
        rounded
        :colors="deleteButtonColors"
        @click="deleteSelected"
      >
        {{ phone.t('Common.delete') }}
      </k-button>
    </template>
  </k-dialog>

  <k-toast :opened="toastOpened" position="center" @click="toastOpened = false">
    {{ toastText }}
  </k-toast>
</template>

<style scoped>
.gallery-count {
  color: #8e8e93;
  font-size: 12px;
}
.gallery-filter {
  width: calc(100% - 24px);
  margin: 0 12px 8px;
}
.gallery-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
  padding: 8px 2px 30px;
}
.gallery-tile {
  position: relative;
  aspect-ratio: 1;
  min-width: 0;
  overflow: hidden;
  border: 0;
  background: #d1d1d6;
}
.gallery-tile img,
.gallery-tile video {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}
.gallery-video-badge {
  position: absolute;
  right: 7px;
  bottom: 7px;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #0009;
  color: #fff;
}
.gallery-load-trigger {
  height: 1px;
  grid-column: 1 / -1;
}
.gallery-state {
  min-height: 430px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 36px;
  color: #8e8e93;
  text-align: center;
}
.gallery-empty strong {
  color: currentColor;
  font-size: 20px;
}
.gallery-error {
  color: #ff3b30;
}
.gallery-detail-stage {
  height: calc(100cqh - 174px);
  overflow: hidden;
  background: #000;
  display: grid;
  place-items: center;
  touch-action: none;
}
.gallery-detail-stage img,
.gallery-detail-stage video {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  transform-origin: center;
  user-select: none;
}
.gallery-detail-stage img {
  transition: transform 0.12s ease-out;
}
.gallery-zoom-controls {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 30px;
  border-bottom: 1px solid #8e8e9333;
}
.gallery-detail-date {
  padding: 12px 18px;
  color: #8e8e93;
  text-align: center;
  font-size: 12px;
}
</style>
