<script setup lang="ts">
import {
  SkyBlock,
  SkyDialog,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyNavbarBackLink,
  SkyAppPage,
  SkySpinner,
  SkyNotification,
} from '@/ui'
import {
  ChevronLeft,
  ChevronRight,
  Download,
  Globe2,
  Heart,
  Image,
  Images,
  Link2,
  ListFilter,
  Play,
  Share2,
  Trash2,
  Video,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import { useEasyShareStore } from '@/stores/easyshare'
import {
  SkyButton,
  SkyDropdown,
  SkyNavbar,
  SkyTabBar,
  SkyTabButton,
  SkyToolbar,
  SkyToolbarPane,
} from '@/ui'
import type {
  DeleteManyResult,
  DeleteResult,
  FavoriteResult,
  GalleryCounts,
  GalleryFilter,
  GallerySortOrder,
  MediaImportSource,
  MediaImportSources,
  MediaType,
  PhoneMedia,
} from '@/types/media'
import {
  bottomRightGridPosition,
  hasNextMediaPage,
  MEDIA_PAGE_SIZE,
  mediaErrorKey,
  mergeMedia,
  orderMedia,
} from '@/utils/media'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

const isDevelopment = import.meta.env.DEV
const developmentParameters = isDevelopment
  ? new URLSearchParams(window.location.search)
  : null
const developmentApiEnabled = Boolean(developmentParameters?.has('apiPort'))
const developmentGalleryState =
  developmentParameters?.get('galleryMock') ?? null
const phone = usePhoneStore()
const easyShare = useEasyShareStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const requestedMessageMedia = computed<MediaType | null>(() => {
  const value = route.query.mediaAttachment ?? route.query.messageAttachment
  return value === 'photo' || value === 'video' ? value : null
})
const multipleSelection = computed(
  () =>
    requestedMessageMedia.value !== null &&
    (messageMedia.request?.maxSelection ?? 1) > 1,
)
const selectedMediaIds = ref<number[]>([])
const selectionMode = ref(false)
const media = ref<PhoneMedia[]>([])
const counts = ref<GalleryCounts>({
  all: 0,
  favoritePhotos: 0,
  favorites: 0,
  favoriteVideos: 0,
  photos: 0,
  videos: 0,
})
const filter = ref<GalleryFilter>(requestedMessageMedia.value ?? 'all')
const favoritesOnly = ref(false)
const sortOrder = ref<GallerySortOrder>('newest')
const sortMenuOpened = ref(false)
const sortMenuTarget = ref<HTMLElement | null>(null)
const loading = ref(true)
const fetching = ref(false)
const hasMore = ref(true)
const loadError = ref('')
const selected = ref<PhoneMedia | null>(null)
const importMode = ref<'form' | 'gallery' | 'sources'>('gallery')
const importSources = ref<MediaImportSource[]>([])
const importSource = ref<MediaImportSource | null>(null)
const importUrl = ref('')
const importError = ref('')
const importing = ref(false)
const deleteDialogOpened = ref(false)
const deleteManyDialogOpened = ref(false)
const deleting = ref(false)
const deletingMany = ref(false)
const favoriting = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
const loadTrigger = ref<HTMLElement | null>(null)
const galleryContent = ref<HTMLElement | null>(null)
const imageZoom = ref(1)
const imagePan = ref({ x: 0, y: 0 })
const dragging = ref(false)
const videoPlaybackError = ref(false)
const dragStart = ref({ panX: 0, panY: 0, x: 0, y: 0 })
let observer: IntersectionObserver | null = null
let galleryReturnScrollTop = 0
let toastTimer: number | undefined
let pendingDeleteCorrelation = ''
let pendingDeleteManyCorrelation = ''
let dragTarget: HTMLElement | null = null
let dragPointerId: number | null = null

const imageStyle = computed(() => ({
  cursor:
    imageZoom.value > 1 ? (dragging.value ? 'grabbing' : 'grab') : 'zoom-in',
  transform: `translate3d(${imagePan.value.x}px, ${imagePan.value.y}px, 0) scale(${imageZoom.value})`,
}))
const orderedMedia = computed(() => orderMedia(media.value, sortOrder.value))
const sortMenuItems = computed(() => [
  {
    checked: sortOrder.value === 'newest',
    group: 'sort',
    groupLabel: phone.t('Apps.photos.sorting.title'),
    id: 'sort-newest',
    label: phone.t('Apps.photos.sorting.newestFirst'),
  },
  {
    checked: sortOrder.value === 'oldest',
    group: 'sort',
    groupLabel: phone.t('Apps.photos.sorting.title'),
    id: 'sort-oldest',
    label: phone.t('Apps.photos.sorting.oldestFirst'),
  },
  {
    checked: !favoritesOnly.value,
    group: 'show',
    groupLabel: phone.t('Apps.photos.sorting.show'),
    id: 'show-all',
    label: phone.t('Apps.photos.sorting.allItems'),
    separatorBefore: true,
  },
  {
    checked: favoritesOnly.value,
    group: 'show',
    groupLabel: phone.t('Apps.photos.sorting.show'),
    id: 'show-favorites',
    label: phone.t('Apps.photos.sorting.favorites'),
  },
])
const countText = computed(() => {
  if (favoritesOnly.value) {
    const favoriteCount =
      filter.value === 'photo'
        ? counts.value.favoritePhotos
        : filter.value === 'video'
          ? counts.value.favoriteVideos
          : counts.value.favorites
    return phone.t(
      `Apps.photos.counts.${favoriteCount === 1 ? 'favorite' : 'favorites'}`,
      { count: new Intl.NumberFormat(phone.lang).format(favoriteCount) },
    )
  }
  const countKey = filter.value === 'all' ? 'all' : `${filter.value}s`
  const count = counts.value[countKey as keyof GalleryCounts]
  const translationKey =
    count === 1 ? (filter.value === 'all' ? 'allOne' : filter.value) : countKey
  return phone.t(`Apps.photos.counts.${translationKey}`, {
    count: new Intl.NumberFormat(phone.lang).format(count),
  })
})
const selectedMedia = computed(() =>
  selectedMediaIds.value.flatMap((id) => {
    const entry = media.value.find((item) => item.id === id)
    return entry ? [entry] : []
  }),
)
const selectedCountText = computed(() =>
  phone.t('Apps.photos.selection.selected', {
    count: new Intl.NumberFormat(phone.lang).format(
      selectedMediaIds.value.length,
    ),
  }),
)
const selectedCaptureDay = computed(() => {
  if (!selected.value) return ''
  const captured = new Date(selected.value.createdAt)
  const today = new Date()
  const capturedDay = new Date(
    captured.getFullYear(),
    captured.getMonth(),
    captured.getDate(),
  ).getTime()
  const todayStart = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  ).getTime()
  const difference = Math.round((capturedDay - todayStart) / 86_400_000)
  if (difference === 0) return phone.t('Apps.photos.today')
  if (difference === -1) return phone.t('Apps.photos.yesterday')
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
  }).format(captured)
})
const selectedCaptureTime = computed(() =>
  selected.value
    ? new Intl.DateTimeFormat(phone.lang, {
        hour: '2-digit',
        minute: '2-digit',
      }).format(new Date(selected.value.createdAt))
    : '',
)

function mockGalleryImage(
  title: string,
  sky: string,
  landscape: string,
  accent: string,
): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1200"><defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${sky}"/><stop offset="1" stop-color="${accent}"/></linearGradient><linearGradient id="land" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${landscape}"/><stop offset="1" stop-color="#101114"/></linearGradient></defs><rect width="900" height="1200" fill="url(#sky)"/><circle cx="690" cy="260" r="105" fill="#fff" opacity=".72"/><path d="M0 690 210 440 390 650 585 360 900 720V1200H0Z" fill="${landscape}" opacity=".84"/><path d="M0 790 230 620 410 765 650 525 900 770V1200H0Z" fill="url(#land)"/><path d="M360 1200 475 690 560 690 690 1200Z" fill="${accent}" opacity=".48"/><text x="54" y="1100" fill="#fff" font-family="system-ui,sans-serif" font-size="62" font-weight="700">${title}</text><text x="57" y="1160" fill="#fff" opacity=".72" font-family="system-ui,sans-serif" font-size="30">Sky Phone test media</text></svg>`
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`
}

function mockMedia(): PhoneMedia[] {
  const media: PhoneMedia[] = [
    {
      createdAt: Date.now() - 4 * 60_000,
      favorite: false,
      id: 1,
      mediaType: 'photo',
      url: mockGalleryImage('City Night', '#172554', '#111827', '#7c3aed'),
    },
    {
      createdAt: Date.now() - 18 * 60_000,
      favorite: true,
      id: 2,
      mediaType: 'video',
      thumbnailUrl: mockGalleryImage(
        'Flower Video',
        '#7f1d1d',
        '#365314',
        '#fb7185',
      ),
      url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    },
    {
      createdAt: Date.now() - 47 * 60_000,
      favorite: true,
      id: 3,
      mediaType: 'photo',
      url: mockGalleryImage('Beach Drive', '#0369a1', '#164e63', '#fbbf24'),
    },
    {
      createdAt: Date.now() - 2 * 60 * 60_000,
      favorite: false,
      id: 4,
      mediaType: 'photo',
      url: mockGalleryImage('Mountain Road', '#475569', '#334155', '#e2e8f0'),
    },
    {
      createdAt: Date.now() - 5 * 60 * 60_000,
      favorite: false,
      id: 5,
      mediaType: 'photo',
      url: mockGalleryImage('Downtown', '#312e81', '#1e293b', '#f472b6'),
    },
    {
      createdAt: Date.now() - 8 * 60 * 60_000,
      favorite: false,
      id: 6,
      mediaType: 'video',
      thumbnailUrl: mockGalleryImage(
        'Sintel Video',
        '#9a3412',
        '#431407',
        '#fdba74',
      ),
      url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
    },
    {
      createdAt: Date.now() - 12 * 60 * 60_000,
      favorite: false,
      id: 7,
      mediaType: 'photo',
      url: mockGalleryImage('Palm Sunset', '#c2410c', '#422006', '#facc15'),
    },
    {
      createdAt: Date.now() - 26 * 60 * 60_000,
      favorite: true,
      id: 8,
      mediaType: 'photo',
      url: mockGalleryImage('Sports Car', '#1f2937', '#111827', '#ef4444'),
    },
    {
      createdAt: Date.now() - 31 * 60 * 60_000,
      favorite: false,
      id: 9,
      mediaType: 'photo',
      url: mockGalleryImage('Boardwalk', '#0e7490', '#713f12', '#67e8f9'),
    },
    {
      createdAt: Date.now() - 46 * 60 * 60_000,
      favorite: false,
      id: 10,
      mediaType: 'video',
      thumbnailUrl: mockGalleryImage(
        'Bunny Video',
        '#166534',
        '#14532d',
        '#86efac',
      ),
      url: 'https://www.w3schools.com/html/mov_bbb.mp4',
    },
    {
      createdAt: Date.now() - 3 * 86_400_000,
      favorite: false,
      id: 11,
      mediaType: 'photo',
      url: mockGalleryImage('Vinewood', '#1d4ed8', '#166534', '#f8fafc'),
    },
    {
      createdAt: Date.now() - 5 * 86_400_000,
      favorite: true,
      id: 12,
      mediaType: 'photo',
      url: mockGalleryImage('Friends', '#7e22ce', '#4c1d95', '#f0abfc'),
    },
  ]

  const additionalPhotos = [
    ['Airport Lights', '#172554', '#1e3a8a', '#38bdf8'],
    ['Desert Route', '#fb923c', '#7c2d12', '#fde047'],
    ['Harbor Morning', '#0e7490', '#164e63', '#a5f3fc'],
    ['Forest Trail', '#166534', '#14532d', '#bef264'],
    ['Neon Alley', '#581c87', '#1e1b4b', '#f472b6'],
    ['Lake House', '#0369a1', '#3f6212', '#fef08a'],
    ['Snow Pass', '#94a3b8', '#334155', '#f8fafc'],
    ['Night Drive', '#111827', '#312e81', '#22d3ee'],
    ['Canyon View', '#b45309', '#78350f', '#fdba74'],
    ['Green Hills', '#15803d', '#365314', '#86efac'],
    ['Purple Sky', '#6b21a8', '#312e81', '#e879f9'],
    ['Ocean Road', '#0284c7', '#0f766e', '#67e8f9'],
    ['City Park', '#4d7c0f', '#14532d', '#facc15'],
    ['Sunrise Pier', '#ea580c', '#7c2d12', '#fef3c7'],
    ['Rainy Street', '#334155', '#0f172a', '#60a5fa'],
    ['Golden Fields', '#ca8a04', '#713f12', '#fef08a'],
    ['Metro Station', '#1f2937', '#374151', '#f43f5e'],
    ['Island Bay', '#0891b2', '#115e59', '#f0fdfa'],
    ['Cliff Road', '#7c3aed', '#3f3f46', '#c4b5fd'],
    ['Old Town', '#9a3412', '#451a03', '#fed7aa'],
    ['Racing Night', '#991b1b', '#111827', '#fb7185'],
    ['Quiet Beach', '#0ea5e9', '#155e75', '#fde68a'],
    ['Hilltop', '#65a30d', '#3f6212', '#d9f99d'],
    ['Downtown Rain', '#3730a3', '#1e293b', '#93c5fd'],
    ['Coastal Sunset', '#be123c', '#7c2d12', '#fbbf24'],
    ['Country Road', '#854d0e', '#365314', '#fde047'],
    ['Blue Mountains', '#1d4ed8', '#334155', '#bfdbfe'],
    ['Palm Beach', '#0d9488', '#166534', '#fcd34d'],
    ['Skyline', '#4338ca', '#111827', '#a78bfa'],
    ['Campfire', '#c2410c', '#431407', '#fef08a'],
  ] as const

  return [
    ...media,
    ...additionalPhotos.map(([title, sky, landscape, accent], index) => ({
      createdAt: Date.now() - (6 + index) * 86_400_000,
      favorite: index % 7 === 0,
      id: 13 + index,
      mediaType: 'photo' as const,
      url: mockGalleryImage(title, sky, landscape, accent),
    })),
  ]
}

const developmentMedia = isDevelopment ? mockMedia() : []

function showToast(text: string): void {
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  toastText.value = text
  toastOpened.value = true
  toastTimer = window.setTimeout(() => {
    toastOpened.value = false
  }, 3000)
}

async function loadImportSources(): Promise<void> {
  if (isDevelopment && !developmentApiEnabled) return
  const response = await nuiCall<MediaImportSources>('media:import:sources')
  if (!response.success || !response.data) return
  const requestedType = requestedMessageMedia.value
  importSources.value = requestedType
    ? response.data.sources.filter((source) =>
        source.mediaTypes.includes(requestedType),
      )
    : response.data.sources
  if (
    route.query.wallpaperUpload === '1' &&
    requestedType === 'photo' &&
    importSources.value.length > 0
  ) {
    openImport()
  }
}

function selectImportSource(source: MediaImportSource): void {
  importSource.value = source
  importMode.value = 'form'
  importUrl.value = ''
  importError.value = ''
}

function openImport(): void {
  if (importSources.value.length === 1) {
    selectImportSource(importSources.value[0])
    return
  }
  importMode.value = 'sources'
}

function closeImport(): void {
  importMode.value = 'gallery'
  importSource.value = null
  importUrl.value = ''
  importError.value = ''
}

function backFromImportForm(): void {
  if (importSources.value.length > 1) {
    importMode.value = 'sources'
    importSource.value = null
    importUrl.value = ''
    importError.value = ''
    return
  }
  closeImport()
}

function updateImportUrl(event: Event): void {
  importUrl.value = (event.target as HTMLInputElement).value
  importError.value = ''
}

async function commitUrlImport(): Promise<void> {
  const url = importUrl.value.trim()
  if (!importSource.value || !url || importing.value) return
  importing.value = true
  importError.value = ''
  const response = await nuiCall<PhoneMedia>('media:import:url', {
    sourceId: importSource.value.id,
    url,
  })
  importing.value = false
  if (!response.success || !response.data) {
    importError.value = phone.t(
      `Apps.photos.errors.${mediaErrorKey(response.error)}`,
    )
    return
  }
  media.value = mergeMedia(media.value, [response.data])
  await fetchCounts()
  if (
    route.query.wallpaperUpload === '1' &&
    requestedMessageMedia.value === 'photo'
  ) {
    const returnPath = messageMedia.complete(response.data)
    if (returnPath) {
      await router.push(returnPath)
      return
    }
  }
  closeImport()
  showToast(phone.t('Apps.photos.import.linkCompleted'))
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
  if (isDevelopment && !developmentApiEnabled) {
    media.value = developmentMedia.filter(
      (entry) =>
        (filter.value === 'all' || entry.mediaType === filter.value) &&
        (!favoritesOnly.value || entry.favorite),
    )
    hasMore.value = false
    fetching.value = false
    return
  }
  const previousScrollHeight = galleryContent.value?.scrollHeight ?? 0
  const previousScrollTop = galleryContent.value?.scrollTop ?? 0
  const response = await nuiCall<PhoneMedia[]>('gallery:list', {
    limit: MEDIA_PAGE_SIZE,
    favoriteOnly: favoritesOnly.value || undefined,
    mediaType: filter.value === 'all' ? undefined : filter.value,
    mockState: developmentGalleryState ?? undefined,
    offset,
  })
  if (response.success && Array.isArray(response.data)) {
    media.value = mergeMedia(media.value, response.data)
    hasMore.value = hasNextMediaPage(response.data.length)
    if (offset > 0) {
      await nextTick()
      if (galleryContent.value) {
        galleryContent.value.scrollTop =
          previousScrollTop +
          galleryContent.value.scrollHeight -
          previousScrollHeight
      }
    }
  } else if (
    isDevelopment &&
    developmentGalleryState !== 'error' &&
    offset === 0
  ) {
    const mock = developmentMedia.filter(
      (entry) =>
        (filter.value === 'all' || entry.mediaType === filter.value) &&
        (!favoritesOnly.value || entry.favorite),
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

async function fetchCounts(): Promise<void> {
  if (isDevelopment && !developmentApiEnabled) {
    counts.value = {
      all: developmentMedia.length,
      favoritePhotos: developmentMedia.filter(
        (entry) => entry.mediaType === 'photo' && entry.favorite,
      ).length,
      favorites: developmentMedia.filter((entry) => entry.favorite).length,
      favoriteVideos: developmentMedia.filter(
        (entry) => entry.mediaType === 'video' && entry.favorite,
      ).length,
      photos: developmentMedia.filter((entry) => entry.mediaType === 'photo')
        .length,
      videos: developmentMedia.filter((entry) => entry.mediaType === 'video')
        .length,
    }
    return
  }
  const response = await nuiCall<GalleryCounts>('gallery:counts')
  if (response.success && response.data) {
    counts.value = response.data
    return
  }
  if (isDevelopment && developmentGalleryState !== 'error') {
    counts.value = {
      all: developmentMedia.length,
      favoritePhotos: developmentMedia.filter(
        (entry) => entry.mediaType === 'photo' && entry.favorite,
      ).length,
      favorites: developmentMedia.filter((entry) => entry.favorite).length,
      favoriteVideos: developmentMedia.filter(
        (entry) => entry.mediaType === 'video' && entry.favorite,
      ).length,
      photos: developmentMedia.filter((entry) => entry.mediaType === 'photo')
        .length,
      videos: developmentMedia.filter((entry) => entry.mediaType === 'video')
        .length,
    }
    return
  }
  loadError.value = phone.t(
    `Apps.photos.errors.${mediaErrorKey(response.error)}`,
  )
}

async function loadGallery(): Promise<void> {
  media.value = []
  hasMore.value = true
  loadError.value = ''
  loading.value = true
  await Promise.all([fetchMore(), fetchCounts()])
  loading.value = false
  await nextTick()
  if (galleryContent.value) {
    galleryContent.value.scrollTop = galleryContent.value.scrollHeight
  }
  observeMore()
}

async function selectSortOrder(value: GallerySortOrder): Promise<void> {
  sortOrder.value = value
  sortMenuOpened.value = false
  await nextTick()
  if (galleryContent.value) {
    galleryContent.value.scrollTop = galleryContent.value.scrollHeight
  }
  observeMore()
}

function openSortMenu(event: MouseEvent): void {
  if (!(event.currentTarget instanceof HTMLElement)) return
  sortMenuTarget.value = event.currentTarget
  sortMenuOpened.value = true
}

function selectSortMenuItem(id: string): void {
  if (id === 'sort-newest') {
    void selectSortOrder('newest')
  } else if (id === 'sort-oldest') {
    void selectSortOrder('oldest')
  } else if (id === 'show-all') {
    void selectFavoritesOnly(false)
  } else if (id === 'show-favorites') {
    void selectFavoritesOnly(true)
  }
}

async function selectFavoritesOnly(value: boolean): Promise<void> {
  favoritesOnly.value = value
  sortMenuOpened.value = false
  await loadGallery()
}

function observeMore(): void {
  observer?.disconnect()
  observer = null
  if (!hasMore.value || !loadTrigger.value) return
  observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) void fetchMore()
    },
    { root: galleryContent.value, rootMargin: '180px 0px 0px' },
  )
  observer.observe(loadTrigger.value)
}

function enterSelectionMode(): void {
  selectedMediaIds.value = []
  selectionMode.value = true
}

function exitSelectionMode(): void {
  selectedMediaIds.value = []
  selectionMode.value = false
  deleteManyDialogOpened.value = false
}

function toggleMediaSelection(entry: PhoneMedia, maximum = 50): void {
  const index = selectedMediaIds.value.indexOf(entry.id)
  if (index >= 0) {
    selectedMediaIds.value.splice(index, 1)
    return
  }
  if (selectedMediaIds.value.length >= maximum) {
    showToast(phone.t('Apps.photos.selection.limit'))
    return
  }
  selectedMediaIds.value.push(entry.id)
}

function openMedia(entry: PhoneMedia): void {
  if (selectionMode.value) {
    toggleMediaSelection(entry)
    return
  }
  if (requestedMessageMedia.value) {
    if (multipleSelection.value) {
      toggleMediaSelection(entry, messageMedia.request?.maxSelection ?? 1)
      return
    }
  }
  galleryReturnScrollTop = galleryContent.value?.scrollTop ?? 0
  observer?.disconnect()
  observer = null
  phone.setCameraLandscape(false)
  selected.value = entry
  videoPlaybackError.value = false
  imageZoom.value = 1
  imagePan.value = { x: 0, y: 0 }
}

function completeSingleSelection(): void {
  if (!selected.value) return
  const returnPath = messageMedia.complete(selected.value)
  if (returnPath) void router.replace(returnPath)
}

function completeMultipleSelection(): void {
  const selectedMedia = selectedMediaIds.value.flatMap((id) => {
    const entry = media.value.find((item) => item.id === id)
    return entry ? [entry] : []
  })
  const returnPath = messageMedia.completeMany(selectedMedia)
  if (returnPath) void router.replace(returnPath)
}

function cancelMessageSelection(): void {
  void router.replace(messageMedia.cancel())
}

async function closeMedia(): Promise<void> {
  phone.setCameraLandscape(false)
  selected.value = null
  videoPlaybackError.value = false
  deleteDialogOpened.value = false
  stopDragging()
  await nextTick()
  if (galleryContent.value) {
    galleryContent.value.scrollTop = galleryReturnScrollTop
  }
  observeMore()
}

function shareSelected(): void {
  if (!selected.value) return
  const mediaKind = selected.value.mediaType
  easyShare.open({
    appId: 'photos',
    copyText: selected.value.url,
    id: selected.value.id,
    imageUrl: selected.value.url,
    kind: mediaKind,
    link: `skyphone://media/${selected.value.id}`,
    subtitle: formatDate(selected.value.createdAt),
    title: phone.t(
      mediaKind === 'video' ? 'Apps.photos.video' : 'Apps.photos.photo',
    ),
  })
}

async function toggleFavorite(): Promise<void> {
  if (!selected.value || favoriting.value) return
  favoriting.value = true
  const nextFavorite = !selected.value.favorite
  if (isDevelopment && !developmentApiEnabled) {
    selected.value.favorite = nextFavorite
    const developmentItem = developmentMedia.find(
      (entry) => entry.id === selected.value?.id,
    )
    if (developmentItem) developmentItem.favorite = nextFavorite
    if (favoritesOnly.value && !nextFavorite) {
      media.value = media.value.filter(
        (entry) => entry.id !== selected.value?.id,
      )
    }
    favoriting.value = false
    await fetchCounts()
    return
  }
  const response = await nuiCall<FavoriteResult>('gallery:favorite', {
    favorite: nextFavorite,
    id: selected.value.id,
  })
  favoriting.value = false
  if (!response.success || !response.data) {
    if (isDevelopment && developmentGalleryState !== 'error') {
      selected.value.favorite = nextFavorite
      const developmentItem = developmentMedia.find(
        (entry) => entry.id === selected.value?.id,
      )
      if (developmentItem) developmentItem.favorite = nextFavorite
      if (favoritesOnly.value && !nextFavorite) {
        media.value = media.value.filter(
          (entry) => entry.id !== selected.value?.id,
        )
      }
      await fetchCounts()
      return
    }
    showToast(phone.t(`Apps.photos.errors.${mediaErrorKey(response.error)}`))
    return
  }
  selected.value.favorite = response.data.favorite
  const item = media.value.find((entry) => entry.id === response.data?.id)
  if (item) item.favorite = response.data.favorite
  if (favoritesOnly.value && !response.data.favorite) {
    media.value = media.value.filter((entry) => entry.id !== response.data?.id)
  }
  await fetchCounts()
}

function shareSelection(): void {
  if (!selectedMedia.value.length) return
  const count = String(selectedMedia.value.length)
  easyShare.open({
    appId: 'photos',
    copyText: phone.t('Apps.photos.selection.shareCopy', { count }),
    imageUrl: selectedMedia.value[0].url,
    kind: 'media',
    meta: { mediaIds: selectedMedia.value.map((entry) => entry.id) },
    subtitle: selectedCountText.value,
    title: phone.t('Apps.photos.selection.shareTitle', { count }),
  })
}

async function deleteSelection(): Promise<void> {
  if (!selectedMediaIds.value.length || deletingMany.value) return
  deletingMany.value = true
  deleteManyDialogOpened.value = false
  pendingDeleteManyCorrelation = `${Date.now()}-${crypto.randomUUID()}`
  const ids = [...selectedMediaIds.value]
  if (isDevelopment) {
    if (!developmentApiEnabled) {
      for (const id of ids) {
        const index = developmentMedia.findIndex((entry) => entry.id === id)
        if (index >= 0) developmentMedia.splice(index, 1)
      }
      window.dispatchEvent(
        new MessageEvent('message', {
          data: {
            data: {
              correlationId: pendingDeleteManyCorrelation,
              deletedIds: ids,
              success: true,
            },
            type: 'media:deleteManyResult',
          },
        }),
      )
      return
    }
    const response = await nuiCall<DeleteManyResult>('gallery:delete-many', {
      correlationId: pendingDeleteManyCorrelation,
      ids,
    })
    const fallbackDeletedIds =
      !response.success && developmentGalleryState !== 'error'
        ? ids.filter((id) => developmentMedia.some((entry) => entry.id === id))
        : []
    for (const id of fallbackDeletedIds) {
      const index = developmentMedia.findIndex((entry) => entry.id === id)
      if (index >= 0) developmentMedia.splice(index, 1)
    }
    window.dispatchEvent(
      new MessageEvent('message', {
        data: {
          data: response.data ?? {
            correlationId: pendingDeleteManyCorrelation,
            deletedIds: fallbackDeletedIds,
            error: fallbackDeletedIds.length ? undefined : response.error,
            success: fallbackDeletedIds.length > 0,
          },
          type: 'media:deleteManyResult',
        },
      }),
    )
    return
  }
  await nuiCall('gallery:delete-many', {
    correlationId: pendingDeleteManyCorrelation,
    ids,
  })
}

function setZoom(value: number): void {
  imageZoom.value = Math.min(4, Math.max(1, value))
  if (imageZoom.value === 1) imagePan.value = { x: 0, y: 0 }
}

function zoomImageWithWheel(event: WheelEvent): void {
  if (event.deltaY === 0) return
  const nextZoom = Math.min(
    4,
    Math.max(1, imageZoom.value + (event.deltaY < 0 ? 0.25 : -0.25)),
  )
  if (nextZoom === imageZoom.value) return

  const media = (event.currentTarget as HTMLImageElement)
    .parentElement as HTMLElement
  const bounds = media.getBoundingClientRect()
  const pointerX =
    (event.clientX - bounds.left - bounds.width / 2) *
    (media.clientWidth / bounds.width)
  const pointerY =
    (event.clientY - bounds.top - bounds.height / 2) *
    (media.clientHeight / bounds.height)
  const zoomRatio = nextZoom / imageZoom.value

  if (nextZoom > 1) {
    imagePan.value = {
      x: pointerX - (pointerX - imagePan.value.x) * zoomRatio,
      y: pointerY - (pointerY - imagePan.value.y) * zoomRatio,
    }
  }
  setZoom(nextZoom)
}

function startDragging(event: PointerEvent): void {
  if (imageZoom.value === 1) {
    setZoom(2)
    return
  }
  dragTarget = event.currentTarget as HTMLElement
  dragPointerId = event.pointerId
  dragTarget.setPointerCapture(event.pointerId)
  dragging.value = true
  dragStart.value = {
    panX: imagePan.value.x,
    panY: imagePan.value.y,
    x: event.clientX,
    y: event.clientY,
  }
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
  if (
    dragTarget &&
    dragPointerId !== null &&
    dragTarget.hasPointerCapture(dragPointerId)
  ) {
    dragTarget.releasePointerCapture(dragPointerId)
  }
  dragTarget = null
  dragPointerId = null
}

function moveImageWithKeyboard(event: KeyboardEvent): void {
  if (imageZoom.value <= 1) return
  const step = event.shiftKey ? 48 : 24
  const offsets: Partial<Record<string, { x: number; y: number }>> = {
    ArrowDown: { x: 0, y: -step },
    ArrowLeft: { x: step, y: 0 },
    ArrowRight: { x: -step, y: 0 },
    ArrowUp: { x: 0, y: step },
  }
  const offset = offsets[event.key]
  if (!offset) return
  event.preventDefault()
  event.stopPropagation()
  imagePan.value = {
    x: imagePan.value.x + offset.x,
    y: imagePan.value.y + offset.y,
  }
}

async function initializeVideo(event: Event): Promise<void> {
  videoPlaybackError.value = false
  try {
    await (event.currentTarget as HTMLVideoElement).play()
  } catch {
    // The native controls remain visible when embedded CEF blocks autoplay.
  }
}

async function deleteSelected(): Promise<void> {
  if (!selected.value || deleting.value) return
  const selectedId = selected.value.id
  deleting.value = true
  deleteDialogOpened.value = false
  pendingDeleteCorrelation = `${Date.now()}-${crypto.randomUUID()}`
  if (isDevelopment && !developmentApiEnabled) {
    const developmentIndex = developmentMedia.findIndex(
      (entry) => entry.id === selectedId,
    )
    if (developmentIndex >= 0) developmentMedia.splice(developmentIndex, 1)
    window.setTimeout(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          data: {
            data: {
              correlationId: pendingDeleteCorrelation,
              id: selectedId,
              success: true,
            },
            type: 'media:deleteResult',
          },
        }),
      )
    }, 500)
    return
  }
  const response = await nuiCall('gallery:delete', {
    correlationId: pendingDeleteCorrelation,
    id: selectedId,
  })
  if (isDevelopment && developmentApiEnabled) {
    window.dispatchEvent(
      new MessageEvent('message', {
        data: {
          data: {
            correlationId: pendingDeleteCorrelation,
            error: response.error,
            id: selectedId,
            success: response.success,
          },
          type: 'media:deleteResult',
        },
      }),
    )
  }
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as {
    data?: DeleteManyResult | DeleteResult
    type?: string
  }
  if (message.type === 'gallery:changed') {
    void loadGallery()
    return
  }
  if (message.type === 'media:deleteManyResult') {
    const result = message.data as DeleteManyResult | undefined
    if (result?.correlationId !== pendingDeleteManyCorrelation) return
    deletingMany.value = false
    const deletedIds = result.deletedIds ?? []
    if (deletedIds.length) {
      const deleted = new Set(deletedIds)
      media.value = media.value.filter((entry) => !deleted.has(entry.id))
      void fetchCounts()
    }
    if (result.success) {
      showToast(
        phone.t('Apps.photos.selection.deleted', {
          count: String(deletedIds.length),
        }),
      )
      exitSelectionMode()
    } else {
      selectedMediaIds.value = selectedMediaIds.value.filter(
        (id) => !deletedIds.includes(id),
      )
      showToast(phone.t(`Apps.photos.errors.${mediaErrorKey(result.error)}`))
    }
    return
  }
  if (
    message.type !== 'media:deleteResult' ||
    message.data?.correlationId !== pendingDeleteCorrelation
  ) {
    return
  }
  const result = message.data as DeleteResult
  deleting.value = false
  if (result.success && result.id) {
    media.value = media.value.filter((entry) => entry.id !== result.id)
    void fetchCounts()
    closeMedia()
    showToast(phone.t('Apps.photos.deleted'))
  } else {
    showToast(phone.t(`Apps.photos.errors.${mediaErrorKey(result.error)}`))
  }
}

watch(filter, () => void loadGallery())
watch(hasMore, () => void nextTick().then(observeMore))

onMounted(() => {
  window.addEventListener('message', onMessage)
  void loadGallery()
  void loadImportSources()
})

onBeforeUnmount(() => {
  phone.setCameraLandscape(false)
  sortMenuTarget.value = null
  observer?.disconnect()
  stopDragging()
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  window.removeEventListener('message', onMessage)
})
</script>

<template>
  <sky-app-page
    v-if="importMode === 'sources'"
    class="gallery-import-page !pt-[44px]"
    :aria-label="phone.t('Apps.photos.import.chooseSource')"
  >
    <sky-navbar :title="phone.t('Apps.photos.import.title')">
      <template #left>
        <sky-navbar-back-link
          component="button"
          :text="phone.t('Common.back')"
          @click="closeImport"
        />
      </template>
    </sky-navbar>
    <sky-block class="gallery-import-intro">
      {{ phone.t('Apps.photos.import.chooseSource') }}
    </sky-block>
    <sky-list inset strong>
      <sky-list-item
        v-for="source in importSources"
        :key="source.id"
        link
        :chevron="false"
        :title="source.label"
        :subtitle="
          source.mediaTypes
            .map((type) =>
              phone.t(
                type === 'photo'
                  ? 'Apps.photos.filters.photos'
                  : 'Apps.photos.filters.videos',
              ),
            )
            .join(' · ')
        "
        @click="selectImportSource(source)"
      >
        <template #media><Globe2 :size="22" /></template>
        <template #after><ChevronRight :size="18" /></template>
      </sky-list-item>
    </sky-list>
  </sky-app-page>

  <sky-app-page
    v-else-if="importMode === 'form' && importSource"
    class="gallery-import-page !pt-[44px]"
    :aria-label="phone.t('Apps.photos.import.title')"
  >
    <sky-navbar :title="importSource.label">
      <template #left>
        <sky-navbar-back-link
          component="button"
          :text="phone.t('Common.back')"
          @click="backFromImportForm"
        />
      </template>
    </sky-navbar>

    <div class="gallery-import-form">
      <div class="gallery-import-form-icon"><Link2 :size="34" /></div>
      <h2>{{ phone.t('Apps.photos.import.linkTitle') }}</h2>
      <p>{{ phone.t('Apps.photos.import.linkBody') }}</p>
      <sky-list inset strong class="gallery-import-url-list">
        <sky-field
          outline
          input-id="gallery-import-url"
          inputmode="url"
          maxlength="2048"
          :error="importError || undefined"
          :label="phone.t('Apps.photos.import.linkLabel')"
          :placeholder="phone.t('Apps.photos.import.linkPlaceholder')"
          type="url"
          :value="importUrl"
          @input="updateImportUrl"
          @keyup.enter="commitUrlImport"
        />
      </sky-list>
      <sky-button
        class="gallery-import-submit"
        large
        rounded
        :disabled="!importUrl.trim() || importing"
        @click="commitUrlImport"
      >
        <sky-spinner v-if="importing" class="mr-2" />
        {{ phone.t('Apps.photos.import.action') }}
      </sky-button>
    </div>
  </sky-app-page>

  <sky-app-page
    v-else-if="!selected"
    class="gallery-page"
    :class="{ '!pt-[44px]': requestedMessageMedia }"
    :aria-label="phone.t('Apps.photos.name')"
  >
    <sky-navbar
      v-if="requestedMessageMedia"
      :title="phone.t('Apps.photos.name')"
    >
      <template #left>
        <sky-navbar-back-link
          component="button"
          :text="phone.t('Common.back')"
          @click="cancelMessageSelection"
        />
      </template>
      <template v-if="multipleSelection" #right>
        <sky-link
          component="button"
          :disabled="!selectedMediaIds.length"
          @click="completeMultipleSelection"
        >
          {{ phone.t('Common.done') }}
        </sky-link>
      </template>
    </sky-navbar>
    <SkyNavbar
      v-else
      class="gallery-library-navbar"
      :scroll-el="null"
      :subtitle="countText"
      :title="phone.t('Apps.photos.library')"
      transparent
      variant="large"
    >
      <template #right>
        <div
          v-if="selectionMode"
          class="gallery-header-actions sky-ui-provider sky-ui-provider--dark"
        >
          <SkyToolbarPane class="gallery-header-tool gallery-header-tool--text">
            <SkyButton
              clear
              class="gallery-header-action"
              @click="exitSelectionMode"
            >
              {{ phone.t('Common.cancel') }}
            </SkyButton>
          </SkyToolbarPane>
        </div>
        <div
          v-else
          class="gallery-header-actions sky-ui-provider sky-ui-provider--dark"
        >
          <SkyToolbarPane class="gallery-header-tool gallery-header-tool--icon">
            <SkyButton
              clear
              icon-only
              rounded
              class="gallery-header-action"
              :aria-label="phone.t('Apps.photos.sorting.action')"
              :aria-expanded="sortMenuOpened"
              aria-haspopup="menu"
              :title="phone.t('Apps.photos.sorting.action')"
              @click="openSortMenu"
            >
              <ListFilter :size="21" aria-hidden="true" />
            </SkyButton>
          </SkyToolbarPane>
          <SkyToolbarPane
            v-if="importSources.length"
            class="gallery-header-tool gallery-header-tool--icon"
          >
            <SkyButton
              clear
              icon-only
              rounded
              class="gallery-header-action"
              :aria-label="phone.t('Apps.photos.import.action')"
              :title="phone.t('Apps.photos.import.action')"
              @click="openImport"
            >
              <Download :size="21" aria-hidden="true" />
            </SkyButton>
          </SkyToolbarPane>
          <SkyToolbarPane class="gallery-header-tool gallery-header-tool--text">
            <SkyButton
              clear
              class="gallery-header-action"
              @click="enterSelectionMode"
            >
              {{ phone.t('Apps.photos.selection.action') }}
            </SkyButton>
          </SkyToolbarPane>
        </div>
      </template>
    </SkyNavbar>

    <div ref="galleryContent" class="gallery-content">
      <div v-if="loading" class="gallery-state">
        <sky-spinner />
        <span>{{ phone.t('Apps.photos.loading') }}</span>
      </div>
      <sky-block v-else-if="loadError" strong inset class="gallery-error">
        {{ loadError }}
      </sky-block>
      <div v-else-if="!media.length" class="gallery-state gallery-empty">
        <strong>{{ phone.t('Apps.photos.emptyTitle') }}</strong>
        <span>{{ phone.t('Apps.photos.emptyBody') }}</span>
      </div>
      <div
        v-else
        class="gallery-grid"
        :class="{ 'gallery-grid--fill': media.length >= 13 }"
      >
        <span
          v-if="hasMore"
          ref="loadTrigger"
          class="gallery-load-trigger"
        ></span>
        <button
          v-for="(entry, index) in orderedMedia"
          :key="entry.id"
          class="gallery-tile"
          :class="{
            'gallery-tile--selected': selectedMediaIds.includes(entry.id),
          }"
          :style="{
            gridColumnStart: bottomRightGridPosition(index, orderedMedia.length)
              .column,
            gridRowStart: bottomRightGridPosition(index, orderedMedia.length)
              .row,
          }"
          type="button"
          :aria-pressed="
            selectionMode || multipleSelection
              ? selectedMediaIds.includes(entry.id)
              : undefined
          "
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
            :poster="entry.thumbnailUrl"
            muted
            playsinline
            preload="metadata"
          ></video>
          <span v-if="entry.mediaType === 'video'" class="gallery-video-badge">
            <Play :size="16" fill="currentColor" />
          </span>
          <span
            v-if="
              (selectionMode || multipleSelection) &&
              selectedMediaIds.includes(entry.id)
            "
            class="gallery-selection-badge"
          >
            {{ selectedMediaIds.indexOf(entry.id) + 1 }}
          </span>
        </button>
      </div>
    </div>

    <SkyTabBar
      v-if="!requestedMessageMedia && !selectionMode"
      icons
      labels
      class="gallery-filter-tabbar"
      :label="phone.t('Apps.photos.name')"
    >
      <SkyTabButton
        :active="filter === 'all'"
        :label="phone.t('Apps.photos.filters.all')"
        @click="filter = 'all'"
      >
        <template #icon><Images :size="21" /></template>
      </SkyTabButton>
      <SkyTabButton
        :active="filter === 'photo'"
        :label="phone.t('Apps.photos.filters.photos')"
        @click="filter = 'photo'"
      >
        <template #icon><Image :size="21" /></template>
      </SkyTabButton>
      <SkyTabButton
        :active="filter === 'video'"
        :label="phone.t('Apps.photos.filters.videos')"
        @click="filter = 'video'"
      >
        <template #icon><Video :size="21" /></template>
      </SkyTabButton>
    </SkyTabBar>

    <SkyToolbar
      v-if="selectionMode"
      :aria-label="phone.t('Apps.photos.selection.action')"
      class="gallery-selection-toolbar sky-ui-provider"
      :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
      component="nav"
    >
      <SkyToolbarPane class="gallery-selection-count">
        {{ selectedCountText }}
      </SkyToolbarPane>
      <div class="gallery-selection-actions">
        <SkyToolbarPane class="gallery-selection-action">
          <SkyButton
            icon-only
            rounded
            clear
            :aria-label="phone.t('Apps.photos.selection.share')"
            :disabled="!selectedMediaIds.length"
            @click="shareSelection"
          >
            <Share2 :size="20" aria-hidden="true" />
          </SkyButton>
        </SkyToolbarPane>
        <SkyToolbarPane class="gallery-selection-action">
          <SkyButton
            icon-only
            rounded
            clear
            variant="danger"
            :aria-label="phone.t('Apps.photos.selection.delete')"
            :disabled="!selectedMediaIds.length || deletingMany"
            @click="deleteManyDialogOpened = true"
          >
            <Trash2 :size="20" aria-hidden="true" />
          </SkyButton>
        </SkyToolbarPane>
      </div>
    </SkyToolbar>
  </sky-app-page>

  <sky-app-page
    v-else
    class="gallery-detail sky-ui-provider sky-ui-provider--dark"
  >
    <SkyNavbar
      class="gallery-detail-navbar"
      :scroll-el="null"
      :subtitle="selectedCaptureTime"
      :title="selectedCaptureDay"
    >
      <template #left>
        <SkyButton
          icon-only
          rounded
          clear
          class="gallery-detail-back"
          :aria-label="phone.t('Common.back')"
          @click="closeMedia"
        >
          <ChevronLeft :size="24" aria-hidden="true" />
        </SkyButton>
      </template>
      <template #right>
        <SkyButton
          v-if="requestedMessageMedia"
          rounded
          tonal
          @click="completeSingleSelection"
        >
          {{ phone.t('Common.use') }}
        </SkyButton>
      </template>
    </SkyNavbar>

    <div class="gallery-detail-stage">
      <div class="gallery-detail-media">
        <img
          v-if="selected.mediaType === 'photo'"
          :src="selected.url"
          :alt="phone.t('Apps.photos.photoAlt')"
          :style="imageStyle"
          draggable="false"
          tabindex="0"
          @pointerdown="startDragging"
          @pointermove="moveImage"
          @pointerup="stopDragging"
          @pointercancel="stopDragging"
          @lostpointercapture="stopDragging"
          @keydown="moveImageWithKeyboard"
          @dblclick="setZoom(imageZoom === 1 ? 2 : 1)"
          @wheel.prevent="zoomImageWithWheel"
        />
        <video
          v-else
          :src="selected.url"
          :poster="selected.thumbnailUrl"
          controls
          playsinline
          @loadedmetadata="initializeVideo"
          @error="videoPlaybackError = true"
        ></video>
        <sky-block
          v-if="selected.mediaType === 'video' && videoPlaybackError"
          strong
          inset
          class="gallery-error"
          role="alert"
        >
          {{ phone.t('Apps.photos.errors.unsupported') }}
        </sky-block>
      </div>
    </div>

    <SkyToolbar
      v-if="!requestedMessageMedia"
      :aria-label="phone.t('Apps.photos.name')"
      class="gallery-detail-toolbar"
      component="nav"
    >
      <SkyToolbarPane class="gallery-detail-action">
        <SkyButton
          icon-only
          rounded
          clear
          :aria-label="phone.t('Apps.easyShare.name')"
          @click="shareSelected"
        >
          <Share2 :size="21" aria-hidden="true" />
        </SkyButton>
      </SkyToolbarPane>
      <SkyToolbarPane class="gallery-detail-tools">
        <SkyButton
          icon-only
          rounded
          clear
          :aria-label="
            phone.t(
              selected.favorite
                ? 'Apps.photos.removeFavorite'
                : 'Apps.photos.addFavorite',
            )
          "
          :disabled="favoriting"
          @click="toggleFavorite"
        >
          <Heart
            :size="20"
            :fill="selected.favorite ? 'currentColor' : 'none'"
            aria-hidden="true"
          />
        </SkyButton>
      </SkyToolbarPane>
      <SkyToolbarPane class="gallery-detail-action">
        <SkyButton
          icon-only
          rounded
          clear
          variant="danger"
          :aria-label="phone.t('Apps.photos.delete')"
          :disabled="deleting"
          @click="deleteDialogOpened = true"
        >
          <Trash2 :size="21" aria-hidden="true" />
        </SkyButton>
      </SkyToolbarPane>
    </SkyToolbar>
  </sky-app-page>

  <SkyDropdown
    class="gallery-sort-dropdown sky-ui-provider"
    :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
    :items="sortMenuItems"
    :label="phone.t('Apps.photos.sorting.title')"
    :opened="sortMenuOpened"
    :target="sortMenuTarget"
    @backdropclick="sortMenuOpened = false"
    @escape="sortMenuOpened = false"
    @select="selectSortMenuItem"
  />

  <sky-dialog
    :opened="deleteManyDialogOpened"
    @backdropclick="deleteManyDialogOpened = false"
  >
    <template #title>
      {{ phone.t('Apps.photos.selection.deleteTitle') }}
    </template>
    <p>{{ phone.t('Apps.photos.selection.deleteBody') }}</p>
    <template #buttons>
      <sky-button
        large
        rounded
        variant="secondary"
        @click="deleteManyDialogOpened = false"
      >
        {{ phone.t('Common.cancel') }}
      </sky-button>
      <sky-button large rounded variant="danger" @click="deleteSelection">
        {{ phone.t('Common.delete') }}
      </sky-button>
    </template>
  </sky-dialog>

  <sky-dialog
    :opened="deleteDialogOpened"
    @backdropclick="deleteDialogOpened = false"
  >
    <template #title>{{ phone.t('Apps.photos.deleteTitle') }}</template>
    <p>{{ phone.t('Apps.photos.deleteBody') }}</p>
    <template #buttons>
      <sky-button
        large
        rounded
        variant="secondary"
        @click="deleteDialogOpened = false"
      >
        {{ phone.t('Common.cancel') }}
      </sky-button>
      <sky-button large rounded variant="danger" @click="deleteSelected">
        {{ phone.t('Common.delete') }}
      </sky-button>
    </template>
  </sky-dialog>

  <sky-notification
    :opened="toastOpened"
    :text="toastText"
    @click="toastOpened = false"
  />
</template>

<style scoped>
.gallery-page {
  position: relative;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.gallery-import-page {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.gallery-import-intro {
  margin-bottom: 0;
  color: #8e8e93;
}
.gallery-import-form {
  min-height: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48px 16px 24px;
  text-align: center;
}
.gallery-import-form-icon {
  width: 72px;
  height: 72px;
  display: grid;
  place-items: center;
  border-radius: 22px;
  background: #0a84ff;
  color: #fff;
  box-shadow: 0 10px 28px #0a84ff4d;
}
.gallery-import-form h2 {
  margin: 20px 0 7px;
  font-size: 21px;
  font-weight: 700;
}
.gallery-import-form p {
  max-width: 280px;
  margin: 0;
  color: #8e8e93;
  font-size: 13px;
  line-height: 1.45;
}
.gallery-import-url-list {
  width: 100%;
  margin-top: 26px;
}
.gallery-import-submit {
  width: calc(100% - 32px);
  margin-top: 14px;
}
.gallery-content {
  min-height: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
}
.gallery-grid {
  position: relative;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
  margin-top: auto;
  padding: 8px 2px 98px;
}
.gallery-library-navbar {
  min-height: calc(
    var(--sky-safe-area-top) + var(--sky-navbar-height) +
      var(--sky-navbar-large-title-height) - 30px
  );
}
.gallery-library-navbar :deep(.sky-navbar__right) {
  z-index: 2;
  overflow: visible;
  background: transparent;
  box-shadow: none;
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
  transform: translateY(calc(var(--sky-navbar-height) - 30px));
}
.gallery-library-navbar :deep(.sky-navbar__inner) {
  grid-template-columns: minmax(0, 1fr) 0 max-content;
  margin-bottom: 0;
}
.gallery-library-navbar :deep(.sky-navbar__title-container) {
  padding-right: calc(200px + var(--sky-safe-area-right));
  transform: translateY(calc(0px - var(--sky-navbar-collapse-offset) - 30px));
}
.gallery-header-actions {
  width: max-content;
  flex: none;
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
}
.gallery-header-tool {
  flex: none;
  height: var(--sky-touch-target);
}
.gallery-header-tool--icon {
  width: var(--sky-touch-target);
  justify-content: center;
}
.gallery-header-action {
  color: var(--sky-text);
  font-size: 14px;
  font-weight: 600;
}
.gallery-selection-toolbar {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
}
.gallery-selection-toolbar :deep(.sky-toolbar__inner) {
  width: 100%;
  gap: var(--sky-space-2);
}
.gallery-selection-count {
  padding: 0 14px;
  color: var(--sky-muted);
  font-size: 14px;
  font-weight: 600;
}
.gallery-selection-actions {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
}
.gallery-selection-action {
  width: 48px;
  flex: 0 0 48px;
  justify-content: center;
}
.gallery-selection-action :deep(.sky-button) {
  color: #fff;
}
.gallery-grid--fill {
  flex: 1;
  grid-auto-rows: minmax(min-content, 1fr);
}
.gallery-tile {
  position: relative;
  aspect-ratio: 1;
  min-width: 0;
  overflow: hidden;
  border: 0;
  background: #d1d1d6;
}
.gallery-tile--selected::after {
  content: '';
  position: absolute;
  inset: 0;
  border: 3px solid #0a84ff;
  pointer-events: none;
}
.gallery-selection-badge {
  position: absolute;
  top: 7px;
  right: 7px;
  width: 24px;
  height: 24px;
  display: grid;
  place-items: center;
  border: 2px solid #fff;
  border-radius: 50%;
  background: #0a84ff;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  box-shadow: 0 2px 6px #0006;
}
.gallery-grid--fill .gallery-tile {
  height: 100%;
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
  position: absolute;
  top: 0;
  right: 0;
  left: 0;
  height: 1px;
  pointer-events: none;
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
.gallery-detail {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #000;
  color: #fff;
}
.gallery-detail-navbar {
  flex: 0 0 auto;
}
.gallery-detail-navbar :deep(.sky-navbar__title) {
  color: #fff;
  font-size: 17px;
}
.gallery-detail-navbar :deep(.sky-navbar__subtitle) {
  color: #fff;
  font-size: 13px;
  font-weight: 600;
}
.gallery-detail-navbar :deep(.gallery-detail-back) {
  color: #fff;
}
.gallery-detail-navbar :deep(.gallery-detail-back svg) {
  transition: transform var(--sky-transition-fast, 100ms) ease;
}
@media (hover: hover) {
  .gallery-detail-navbar :deep(.gallery-detail-back:hover:not(:disabled)) {
    background: rgba(255, 255, 255, 0.16);
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.08);
  }
  .gallery-detail-navbar :deep(.gallery-detail-back:hover:not(:disabled) svg) {
    transform: translateX(-2px);
  }
}
.gallery-detail-navbar :deep(.gallery-detail-back:active:not(:disabled)) {
  background: rgba(255, 255, 255, 0.22);
}
.gallery-detail-stage {
  position: relative;
  min-height: 0;
  flex: 1;
  overflow: hidden;
  background: #000;
  display: grid;
  place-items: center;
  touch-action: none;
}
.gallery-detail-media {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  transform-origin: center;
  transition: transform 0.25s ease;
}
.gallery-detail-media img,
.gallery-detail-media video {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  transform-origin: center;
  user-select: none;
}
.gallery-detail-media img {
  transition: transform 0.12s ease-out;
}
.gallery-detail-toolbar {
  flex: 0 0 auto;
}
.gallery-detail-toolbar :deep(.sky-toolbar__inner) {
  width: 100%;
  gap: 8px;
}
.gallery-detail-toolbar :deep(.sky-toolbar__background) {
  background: linear-gradient(to top, #000 72%, transparent);
}
.gallery-detail-toolbar :deep(.sky-button) {
  color: #fff;
}
.gallery-detail-toolbar :deep(.sky-button:active:not(:disabled)) {
  background: rgba(255, 255, 255, 0.14);
}
.gallery-detail-tools {
  flex: 1;
  justify-content: center;
  gap: 0;
  padding: 0 2px;
}
.gallery-detail-action {
  width: 48px;
  flex: 0 0 48px;
  justify-content: center;
}
</style>
