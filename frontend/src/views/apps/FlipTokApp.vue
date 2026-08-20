<script setup lang="ts">
import {
  Bell,
  Bookmark,
  Camera,
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Compass,
  Heart,
  Home,
  ImagePlus,
  Link2,
  MessageCircle,
  MoreHorizontal,
  Music2,
  Pencil,
  Play,
  Plus,
  Reply,
  Search,
  Send,
  Share2,
  TriangleAlert,
  Trash2,
  UserRound,
  UsersRound,
  Video,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import flipTokIcon from '@/assets/img/app-icons/fliptok.webp'
import { useFlipTokStore } from '@/stores/fliptok'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import {
  loadYouTubeApi,
  type YouTubeApi,
  type YouTubePlayer,
} from '@/stores/music'
import { usePhoneStore } from '@/stores/phone'
import type {
  FlipTokComment,
  FlipTokProfile,
  FlipTokVideo,
} from '@/types/fliptok'
import type { PhoneMedia } from '@/types/media'
import {
  SkyAppPage,
  SkyBlock,
  SkyBlockTitle,
  SkyButton,
  SkyChip,
  SkyDialog,
  SkyDialogButton,
  SkyDropdown,
  SkyField,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyListButton,
  SkyListItem,
  SkyMessagebar,
  SkyNavbar,
  SkyPillNavigation,
  SkyRange,
  SkyScrollArea,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkySpinner,
  SkyNotification,
  SkyToggle,
} from '@/ui'
import { nuiCall } from '@/utils/nui'

type Tab = 'feed' | 'discover' | 'create' | 'activity' | 'profile'
type AuthMode = 'login' | 'register'
type ConnectionMode = 'followers' | 'following'
type ProfileMediaContext = {
  draft: {
    accountType: string
    avatarMediaId: number
    bio: string
    displayName: string
    handle: string
  }
  selectedPhoto: PhoneMedia | null
}

const phone = usePhoneStore()
const store = useFlipTokStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const authMode = ref<AuthMode>('login')
const authHandle = ref('')
const authDisplayName = ref('')
const authPassword = ref('')
const authConfirmPassword = ref('')
const authSubmitting = ref(false)
const logoutDialogOpen = ref(false)
const logoutSubmitting = ref(false)
const deleteDialogOpen = ref(false)
const deleteSubmitting = ref(false)
const tab = ref<Tab>('feed')
const selectedVideo = ref<FlipTokVideo | null>(null)
const selectedMedia = ref<PhoneMedia | null>(null)
const selectedMediaItems = ref<PhoneMedia[]>([])
const commentsOpen = ref(false)
const actionsOpen = ref(false)
const visibilityMenuOpen = ref(false)
const visibilityMenuTarget = ref<HTMLElement | null>(null)
const accountTypeSheetOpen = ref(false)
const profilePhotoSheetOpen = ref(false)
const composeOpen = ref(false)
const profileEditOpen = ref(false)
const musicSheetOpen = ref(false)
const reportSheetOpen = ref(false)
const connectionsOpen = ref(false)
const connectionsMode = ref<ConnectionMode>('followers')
const search = ref('')
const commentBody = ref('')
const replyingTo = ref<FlipTokComment | null>(null)
const expandedCommentThreads = ref(new Set<string>())
const caption = ref('')
const visibility = ref<'public' | 'followers' | 'private'>('public')
const commentsEnabled = ref(true)
const trimStartMs = ref(0)
const trimEndMs = ref(0)
const coverTimeMs = ref(0)
const originalVolume = ref(100)
const musicVolume = ref(35)
const musicTrack = ref('')
const customMusicUrl = ref('')
const customMusicDraftUrl = ref('')
const customMusicTitle = ref('')
const customMusicArtist = ref('')
const customMusicVideoId = ref('')
const customMusicResolving = ref(false)
const customMusicLoadFailed = ref(false)
const videoDurationMs = ref(0)
const previewVideo = ref<HTMLVideoElement | null>(null)
const composerMusic = ref<HTMLAudioElement | null>(null)
const reportReason = ref<
  'spam' | 'harassment' | 'dangerous' | 'illegal' | 'other'
>('spam')
const reportDetails = ref('')
const reportSubmitting = ref(false)
const publishing = ref(false)
const profileSaving = ref(false)
const profileFollowPending = ref(false)
const feedback = ref('')
const likedPulseId = ref<string | null>(null)
const commentLikePulseId = ref<string | null>(null)
const reactionPulse = ref<{ id: string; kind: 'like' | 'save' } | null>(null)
const playbackFailedIds = ref(new Set<string>())
const followFeedbackIds = ref(new Set<string>())
const followPendingIds = ref(new Set<string>())
const feedBeforePreview = ref<FlipTokVideo[] | null>(null)
const photoSlideIndexes = ref<Record<string, number>>({})
const composerPhotoIndex = ref(0)
const profileDraft = ref({
  accountType: 'person',
  avatarMediaId: 0,
  bio: '',
  displayName: '',
  handle: '',
})
const selectedProfilePhoto = ref<PhoneMedia | null>(null)
const feedCards = new Map<string, HTMLElement>()
const videoElements = new Map<string, HTMLVideoElement>()
const musicElements = new Map<string, HTMLAudioElement>()
const photoSlideElements = new Map<string, HTMLElement>()
const photoSlideAnimations = new Map<HTMLElement, Animation>()
let photoSlideDrag: {
  currentX: number
  element: HTMLElement
  frame: number | null
  lastMoveAt: number
  lastX: number
  pointerId: number
  startIndex: number
  startTranslateX: number
  startX: number
  track: HTMLElement
  velocity: number
} | null = null
let flipTokYoutubePlayer: YouTubePlayer | null = null
let flipTokYoutubeApi: YouTubeApi | null = null
let flipTokYoutubeOwner = ''
let flipTokYoutubeVideoId = ''
let observer: IntersectionObserver | null = null
let videoClickTimer: number | null = null
let likePulseTimer: number | null = null
let commentLikePulseTimer: number | null = null
let reactionPulseTimer: number | null = null
let feedbackTimer: number | null = null
let searchTimer: number | null = null
const followFeedbackTimers = new Map<string, number>()
const visibilityOptions = ['public', 'followers', 'private'] as const
const accountTypeOptions = [
  'person',
  'business',
  'organization',
  'media',
  'event',
] as const
const reportReasonOptions = [
  'spam',
  'harassment',
  'dangerous',
  'illegal',
  'other',
] as const
const discoveryTags = [
  { labelKey: 'trendLosSantos', value: '#LosSantos' },
  { labelKey: 'trendRoleplay', value: '#Roleplay' },
  { labelKey: 'trendTrending', value: '#Trending' },
] as const

const currentProfile = computed(() => store.viewedProfile ?? store.profile)
const selectedMusic = computed(() =>
  store.musicTracks.find((track) => track.id === musicTrack.value),
)
const composerMusicUrl = computed(
  () =>
    selectedMusic.value?.url ??
    (customMusicVideoId.value ? '' : customMusicUrl.value.trim()),
)
const hasMusic = computed(() =>
  Boolean(selectedMusic.value || customMusicUrl.value.trim()),
)
const customMusicDraftError = computed(() => {
  const value = customMusicDraftUrl.value.trim()
  return value && !validCustomMusicUrl(value) ? t('invalidCustomSoundLink') : ''
})
const canPublish = computed(
  () =>
    Boolean(selectedMedia.value) &&
    caption.value.length <= 500 &&
    !customMusicLoadFailed.value,
)
const selectedMediaType = computed(() => selectedMedia.value?.mediaType ?? null)
const selectedComposerPhoto = computed(
  () =>
    selectedMediaItems.value[composerPhotoIndex.value] ?? selectedMedia.value,
)
const visibilityMenuItems = computed(() =>
  visibilityOptions.map((option) => ({
    checked: visibility.value === option,
    id: option,
    label:
      option === 'public'
        ? t('public')
        : option === 'followers'
          ? t('followersOnly')
          : t('private'),
  })),
)
const tabIndex = computed(() =>
  ['feed', 'discover', 'create', 'activity', 'profile'].indexOf(tab.value),
)
const commentThreads = computed(() => {
  const roots = store.comments.filter((comment) => !comment.parent_id)
  return roots.map((comment) => ({
    comment,
    replies: store.comments.filter((reply) => reply.parent_id === comment.id),
  }))
})

function t(key: string, values?: Record<string, string>): string {
  return phone.t(`Apps.fliptok.${key}`, values)
}

function initials(name: string): string {
  return name.trim().slice(0, 2).toUpperCase() || 'FT'
}

function compactCount(value: number): string {
  return new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 1,
    notation: 'compact',
  }).format(value)
}

function videoMedia(video: FlipTokVideo) {
  return video.media?.length
    ? video.media
    : [{ id: 0, mediaType: video.media_type ?? 'video', url: video.url }]
}

function photoSlideIndex(videoId: string): number {
  return photoSlideIndexes.value[videoId] ?? 0
}

function setPhotoSlideElement(videoId: string, element: unknown): void {
  if (element instanceof HTMLElement) {
    photoSlideElements.set(videoId, element)
    const track = element.firstElementChild
    if (track instanceof HTMLElement) {
      track.style.transform = `translate3d(-${photoSlideIndex(videoId) * 100}%, 0, 0)`
    }
    return
  }
  const previous = photoSlideElements.get(videoId)
  if (previous) cancelPhotoSlideAnimation(previous)
  photoSlideElements.delete(videoId)
}

function updatePhotoSlideIndex(videoId: string, index: number): void {
  const normalizedIndex = Math.max(0, index)
  if (photoSlideIndexes.value[videoId] === normalizedIndex) return
  photoSlideIndexes.value = {
    ...photoSlideIndexes.value,
    [videoId]: normalizedIndex,
  }
}

function photoSlideTranslateX(track: HTMLElement): number {
  const transform = window.getComputedStyle(track).transform
  if (!transform || transform === 'none') return 0
  try {
    return new DOMMatrixReadOnly(transform).m41
  } catch {
    return 0
  }
}

function beginPhotoSlideDrag(videoId: string, event: PointerEvent): void {
  if (event.pointerType === 'mouse' && event.button !== 0) return
  const element = photoSlideElements.get(videoId)
  const track = element?.firstElementChild
  if (!element || !(track instanceof HTMLElement)) return
  const currentTransform = window.getComputedStyle(track).transform
  cancelPhotoSlideAnimation(element)
  track.style.transform =
    currentTransform && currentTransform !== 'none'
      ? currentTransform
      : `translate3d(-${photoSlideIndex(videoId) * 100}%, 0, 0)`
  const startTranslateX = photoSlideTranslateX(track)
  const now = performance.now()
  photoSlideDrag = {
    currentX: event.clientX,
    element,
    frame: null,
    lastMoveAt: now,
    lastX: event.clientX,
    pointerId: event.pointerId,
    startIndex: photoSlideIndex(videoId),
    startTranslateX,
    startX: event.clientX,
    track,
    velocity: 0,
  }
  element.classList.add('photo-slideshow--dragging')
  element.setPointerCapture(event.pointerId)
}

function renderPhotoSlideDrag(drag: NonNullable<typeof photoSlideDrag>): void {
  drag.frame = null
  if (photoSlideDrag !== drag) return
  const translateX = drag.startTranslateX + (drag.currentX - drag.startX)
  drag.track.style.transform = `translate3d(${translateX}px, 0, 0)`
}

function updatePhotoSlideDrag(event: PointerEvent): void {
  if (!photoSlideDrag || photoSlideDrag.pointerId !== event.pointerId) return
  event.preventDefault()
  const samples = event.getCoalescedEvents?.() ?? [event]
  const sample = samples.at(-1) ?? event
  const now = performance.now()
  const elapsed = Math.max(1, now - photoSlideDrag.lastMoveAt)
  const instantVelocity = (photoSlideDrag.lastX - sample.clientX) / elapsed
  photoSlideDrag.velocity =
    photoSlideDrag.velocity * 0.68 + instantVelocity * 0.32
  photoSlideDrag.currentX = sample.clientX
  photoSlideDrag.lastX = sample.clientX
  photoSlideDrag.lastMoveAt = now
  if (photoSlideDrag.frame === null) {
    const drag = photoSlideDrag
    drag.frame = window.requestAnimationFrame(() => renderPhotoSlideDrag(drag))
  }
}

function endPhotoSlideDrag(video: FlipTokVideo, event: PointerEvent): void {
  if (!photoSlideDrag || photoSlideDrag.pointerId !== event.pointerId) return
  const drag = photoSlideDrag
  const { element, pointerId } = drag
  drag.currentX = event.clientX
  if (drag.frame !== null) window.cancelAnimationFrame(drag.frame)
  renderPhotoSlideDrag(drag)
  const lastIndex = videoMedia(video).length - 1
  const distance = drag.startX - drag.currentX
  const shouldAdvance =
    Math.abs(distance) > element.clientWidth * 0.12 ||
    Math.abs(drag.velocity) > 0.35
  const direction = Math.sign(distance || drag.velocity)
  const nextIndex = Math.max(
    0,
    Math.min(
      lastIndex,
      shouldAdvance ? drag.startIndex + direction : drag.startIndex,
    ),
  )
  if (element.hasPointerCapture(pointerId))
    element.releasePointerCapture(pointerId)
  element.classList.remove('photo-slideshow--dragging')
  photoSlideDrag = null
  settlePhotoSlide(video.id, element, nextIndex)
}

function cancelPhotoSlideAnimation(element: HTMLElement): void {
  const animation = photoSlideAnimations.get(element)
  animation?.cancel()
  photoSlideAnimations.delete(element)
  element.classList.remove('photo-slideshow--settling')
}

function settlePhotoSlide(
  videoId: string,
  element: HTMLElement,
  index: number,
): void {
  cancelPhotoSlideAnimation(element)
  const track = element.firstElementChild
  if (!(track instanceof HTMLElement)) return
  const startTransform = window.getComputedStyle(track).transform
  const targetTransform = `translate3d(-${index * 100}%, 0, 0)`
  const animationTarget = `translate3d(${-index * element.clientWidth}px, 0, 0)`
  updatePhotoSlideIndex(videoId, index)
  element.classList.add('photo-slideshow--settling')
  const animation = track.animate(
    [
      {
        transform:
          startTransform === 'none' ? track.style.transform : startTransform,
      },
      { transform: animationTarget },
    ],
    {
      duration: 420,
      easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
      fill: 'forwards',
    },
  )
  photoSlideAnimations.set(element, animation)
  animation.onfinish = () => {
    track.style.transform = targetTransform
    animation.cancel()
    photoSlideAnimations.delete(element)
    element.classList.remove('photo-slideshow--settling')
  }
}

function moveComposerPhoto(direction: -1 | 1): void {
  composerPhotoIndex.value = Math.max(
    0,
    Math.min(
      selectedMediaItems.value.length - 1,
      composerPhotoIndex.value + direction,
    ),
  )
}

function parseYoutubeVideoId(value: string): string {
  const trimmed = value.trim()
  if (!trimmed || trimmed.length > 500) return ''
  try {
    const url = new URL(trimmed)
    if (url.protocol !== 'https:' || url.username || url.password || url.port) {
      return ''
    }
    const host = url.hostname.toLowerCase()
    let videoId = ''
    if (host === 'youtu.be' || host === 'www.youtu.be') {
      videoId = url.pathname.split('/')[1] ?? ''
    } else if (
      [
        'youtube.com',
        'www.youtube.com',
        'm.youtube.com',
        'music.youtube.com',
        'youtube-nocookie.com',
        'www.youtube-nocookie.com',
      ].includes(host)
    ) {
      videoId =
        url.searchParams.get('v') ??
        url.pathname.match(/^\/(?:shorts|embed|live)\/([a-z0-9_-]+)/i)?.[1] ??
        ''
    }
    return /^[a-z0-9_-]{11}$/i.test(videoId) ? videoId : ''
  } catch {
    return ''
  }
}

function validCustomMusicUrl(value: string): boolean {
  const audioExtensions = new Set([
    'aac',
    'm4a',
    'mp3',
    'oga',
    'ogg',
    'opus',
    'wav',
    'webm',
  ])
  const trimmed = value.trim()
  if (parseYoutubeVideoId(trimmed)) return true
  if (
    !trimmed ||
    trimmed.length > 2048 ||
    /[\s\u0000-\u001f\u007f]/.test(trimmed)
  )
    return false

  try {
    const url = new URL(trimmed)
    const host = url.hostname.toLowerCase()
    const extension = url.pathname.match(/\.([a-z0-9]+)$/i)?.[1]?.toLowerCase()
    const labels = host.split('.')
    return (
      url.protocol === 'https:' &&
      !url.username &&
      !url.password &&
      !url.port &&
      host.includes('.') &&
      host !== 'localhost' &&
      !host.endsWith('.localhost') &&
      !host.endsWith('.local') &&
      !host.endsWith('.internal') &&
      !/^\d{1,3}(?:\.\d{1,3}){3}$/.test(host) &&
      /^[a-z0-9.-]+$/.test(host) &&
      labels.every(
        (label) =>
          label.length > 0 &&
          label.length <= 63 &&
          !label.startsWith('-') &&
          !label.endsWith('-'),
      ) &&
      Boolean(extension && audioExtensions.has(extension))
    )
  } catch {
    return false
  }
}

function formatTimestamp(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return ''
  const timestamp = new Date(value)
  const now = new Date()
  const sameDay =
    timestamp.getFullYear() === now.getFullYear() &&
    timestamp.getMonth() === now.getMonth() &&
    timestamp.getDate() === now.getDate()
  return new Intl.DateTimeFormat(phone.lang, {
    ...(sameDay ? {} : { day: '2-digit', month: 'short' }),
    hour: '2-digit',
    minute: '2-digit',
  }).format(timestamp)
}

function notify(message: string): void {
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  feedback.value = message
  feedbackTimer = window.setTimeout(() => {
    feedback.value = ''
    feedbackTimer = null
  }, 2400)
}

function inputValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

async function submitAuth(): Promise<void> {
  if (
    authMode.value === 'register' &&
    authPassword.value !== authConfirmPassword.value
  ) {
    notify(t('passwordsMismatch'))
    return
  }
  authSubmitting.value = true
  const response =
    authMode.value === 'login'
      ? await store.login(authHandle.value, authPassword.value)
      : await store.register(
          authDisplayName.value,
          authHandle.value,
          authPassword.value,
        )
  authSubmitting.value = false
  if (!response.success) notify(t(`errors.${response.error ?? 'default'}`))
}

async function confirmLogout(): Promise<void> {
  logoutSubmitting.value = true
  const response = await store.logout()
  logoutSubmitting.value = false
  if (!response.success) {
    notify(t(`errors.${response.error ?? 'default'}`))
    return
  }
  logoutDialogOpen.value = false
  profileEditOpen.value = false
  tab.value = 'feed'
  authHandle.value = ''
  authPassword.value = ''
  authConfirmPassword.value = ''
}

function setVideoElement(id: string, element: unknown): void {
  if (element instanceof HTMLVideoElement) {
    videoElements.set(id, element)
    return
  }
  videoElements.delete(id)
  setPlaybackFailed(id, false)
}

function setFeedCard(id: string, element: unknown): void {
  if (element instanceof HTMLElement) {
    element.dataset.id = id
    feedCards.set(id, element)
    return
  }
  feedCards.delete(id)
}

function setMusicElement(id: string, element: unknown): void {
  if (element instanceof HTMLAudioElement) {
    musicElements.set(id, element)
    return
  }
  musicElements.delete(id)
}

function setPlaybackFailed(id: string, failed: boolean): void {
  const next = new Set(playbackFailedIds.value)
  if (failed) next.add(id)
  else next.delete(id)
  playbackFailedIds.value = next
}

async function playFeedVideo(
  video: FlipTokVideo,
  element: HTMLVideoElement,
  showNotice = false,
): Promise<boolean> {
  const id = video.id
  setPlaybackFailed(id, false)
  try {
    await element.play()
  } catch (error) {
    setPlaybackFailed(id, true)
    console.error(`[FlipTok] Could not play video ${id}.`, error)
    if (showNotice) notify(t('errors.video_not_found'))
    return false
  }

  if (video.music_source === 'youtube' && video.music_video_id) {
    await playFlipTokYoutube(
      id,
      video.music_video_id,
      video.music_volume,
      element.currentTime - video.trim_start_ms / 1000,
    )
  } else {
    pauseFlipTokYoutube()
    const music = musicElements.get(id)
    if (!music) return true
    try {
      await music.play()
    } catch (error) {
      console.error(`[FlipTok] Could not play music for video ${id}.`, error)
    }
  }
  return true
}

function handleFeedVideoError(id: string, event: Event): void {
  setPlaybackFailed(id, true)
  const code = (event.currentTarget as HTMLVideoElement).error?.code
  console.error(
    `[FlipTok] Video ${id} could not be decoded or loaded${code ? ` (media error ${code})` : ''}.`,
  )
}

function retryPlayback(video: FlipTokVideo): void {
  const element = videoElements.get(video.id)
  if (element) void playFeedVideo(video, element, true)
}

function clearCustomMusicDetails(): void {
  customMusicTitle.value = ''
  customMusicArtist.value = ''
  customMusicVideoId.value = ''
}

function chooseMusicTrack(trackId: string): void {
  musicTrack.value = trackId
  customMusicUrl.value = ''
  customMusicDraftUrl.value = ''
  clearCustomMusicDetails()
  customMusicLoadFailed.value = false
  musicSheetOpen.value = false
}

function openMusicSheet(): void {
  customMusicDraftUrl.value = customMusicUrl.value
  musicSheetOpen.value = true
}

async function chooseCustomMusic(): Promise<void> {
  const value = customMusicDraftUrl.value.trim()
  if (!validCustomMusicUrl(value)) return
  const youtubeVideoId = parseYoutubeVideoId(value)
  if (youtubeVideoId) {
    customMusicResolving.value = true
    const response = await nuiCall<{
      artist: string
      title: string
      url: string
      videoId: string
    }>('fliptok:music-metadata', { url: value })
    customMusicResolving.value = false
    if (!response.success || !response.data) {
      notify(t(`errors.${response.error ?? 'invalid_music_url'}`))
      return
    }
    customMusicUrl.value = response.data.url
    customMusicTitle.value = response.data.title
    customMusicArtist.value = response.data.artist
    customMusicVideoId.value = response.data.videoId
  } else {
    customMusicUrl.value = value
    clearCustomMusicDetails()
  }
  musicTrack.value = ''
  customMusicLoadFailed.value = false
  musicSheetOpen.value = false
}

function markComposerMusicReady(): void {
  customMusicLoadFailed.value = false
}

function markComposerMusicFailed(): void {
  if (customMusicUrl.value) customMusicLoadFailed.value = true
}

function destroyFlipTokYoutube(): void {
  try {
    flipTokYoutubePlayer?.destroy()
  } catch (error) {
    console.error('[FlipTok] YouTube player cleanup failed.', error)
  }
  flipTokYoutubePlayer = null
  flipTokYoutubeApi = null
  flipTokYoutubeOwner = ''
  flipTokYoutubeVideoId = ''
  document.getElementById('sky-phone-fliptok-youtube-player')?.remove()
}

function pauseFlipTokYoutube(owner?: string): void {
  if (owner && flipTokYoutubeOwner !== owner) return
  flipTokYoutubePlayer?.pauseVideo()
}

function seekFlipTokYoutube(owner: string, seconds: number): void {
  if (flipTokYoutubeOwner !== owner) return
  flipTokYoutubePlayer?.seekTo(Math.max(0, seconds), true)
}

async function playFlipTokYoutube(
  owner: string,
  videoId: string,
  volume: number,
  seconds = 0,
): Promise<void> {
  flipTokYoutubeOwner = owner
  try {
    const api = await loadYouTubeApi()
    flipTokYoutubeApi = api
    if (flipTokYoutubePlayer) {
      if (flipTokYoutubeVideoId !== videoId) {
        flipTokYoutubeVideoId = videoId
        flipTokYoutubePlayer.loadVideoById(videoId)
      }
      flipTokYoutubePlayer.setVolume(volume)
      flipTokYoutubePlayer.seekTo(Math.max(0, seconds), true)
      flipTokYoutubePlayer.playVideo()
      if (owner === 'composer') customMusicLoadFailed.value = false
      return
    }

    const host = document.createElement('div')
    host.id = 'sky-phone-fliptok-youtube-player'
    host.style.position = 'fixed'
    host.style.left = '-10000px'
    host.style.top = '0'
    host.style.width = '200px'
    host.style.height = '200px'
    host.style.pointerEvents = 'none'
    document.body.append(host)
    flipTokYoutubeVideoId = videoId

    await new Promise<void>((resolve, reject) => {
      flipTokYoutubePlayer = new api.Player(host, {
        height: '200',
        width: '200',
        videoId,
        playerVars: {
          autoplay: 1,
          controls: 0,
          disablekb: 1,
          fs: 0,
          origin: window.location.origin,
          playsinline: 1,
          rel: 0,
        },
        events: {
          onError: () => {
            if (flipTokYoutubeOwner === 'composer')
              customMusicLoadFailed.value = true
            destroyFlipTokYoutube()
            reject(new Error('YouTube rejected the selected sound.'))
          },
          onReady: (event) => {
            flipTokYoutubePlayer = event.target
            event.target.setVolume(volume)
            event.target.seekTo(Math.max(0, seconds), true)
            event.target.playVideo()
            if (owner === 'composer') customMusicLoadFailed.value = false
            resolve()
          },
          onStateChange: (event) => {
            if (
              event.data === flipTokYoutubeApi?.PlayerState.ENDED &&
              flipTokYoutubePlayer
            ) {
              flipTokYoutubePlayer.seekTo(0, true)
              flipTokYoutubePlayer.playVideo()
            }
          },
        },
      })
    })
  } catch (error) {
    if (owner === 'composer') customMusicLoadFailed.value = true
    console.error('[FlipTok] YouTube sound playback failed.', error)
  }
}

function textParts(
  value: string,
): Array<{ kind: 'text' | 'hashtag' | 'mention'; value: string }> {
  return value
    .split(/([#@][A-Za-z0-9._]+)/g)
    .filter(Boolean)
    .map((part) => ({
      kind: part.startsWith('#')
        ? 'hashtag'
        : part.startsWith('@')
          ? 'mention'
          : 'text',
      value: part,
    }))
}

async function openTextLink(part: {
  kind: string
  value: string
}): Promise<void> {
  if (part.kind === 'hashtag') {
    search.value = part.value
    tab.value = 'discover'
    await runSearch()
  } else if (part.kind === 'mention') {
    await openProfile(undefined, part.value.slice(1))
  }
}

function observeVideos(): void {
  observer?.disconnect()
  observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        const card = entry.target as HTMLElement
        const id = card.dataset.id ?? ''
        const video = videoElements.get(id)
        if (entry.isIntersecting && entry.intersectionRatio > 0.72) {
          videoElements.forEach((item) => {
            if (item !== video) {
              item.pause()
              const otherId = item.dataset.id ?? ''
              const otherAudio = musicElements.get(otherId)
              otherAudio?.pause()
              pauseFlipTokYoutube(otherId)
            }
          })
          musicElements.forEach((audio, audioId) => {
            if (audioId !== id) audio.pause()
          })
          const item = id
            ? [
                ...store.feed,
                ...store.searchResults,
                ...store.profileVideos,
              ].find((candidate) => candidate.id === id)
            : undefined
          if (item && video) void playFeedVideo(item, video)
          else if (item?.music_source === 'youtube' && item.music_video_id) {
            void playFlipTokYoutube(
              id,
              item.music_video_id,
              item.music_volume,
              0,
            )
          } else if (item) {
            const music = musicElements.get(id)
            if (music) void music.play().catch(() => undefined)
          }
          if (id) void nuiCall('fliptok:view', { id })
        } else {
          video?.pause()
          if (id) {
            musicElements.get(id)?.pause()
            pauseFlipTokYoutube(id)
          }
        }
      })
    },
    { threshold: [0.72] },
  )
  feedCards.forEach((card) => observer?.observe(card))
}

function togglePlayback(video: FlipTokVideo): void {
  const element = videoElements.get(video.id)
  if (!element) return
  const music = musicElements.get(video.id)
  if (element.paused) {
    void playFeedVideo(video, element, true)
  } else {
    element.pause()
    music?.pause()
    pauseFlipTokYoutube(video.id)
  }
}

function prepareFeedVideo(
  video: FlipTokVideo,
  element: HTMLVideoElement,
): void {
  setPlaybackFailed(video.id, false)
  element.volume = (Number(video.original_volume) || 0) / 100
  const start = Math.min(
    (Number(video.trim_start_ms) || 0) / 1000,
    element.duration || 0,
  )
  if (element.currentTime < start) element.currentTime = start
}

function enforceVideoTrim(
  video: FlipTokVideo,
  element: HTMLVideoElement,
): void {
  const end = (video.trim_end_ms ?? Math.round(element.duration * 1000)) / 1000
  if (
    element.currentTime < video.trim_start_ms / 1000 ||
    element.currentTime >= end
  ) {
    element.currentTime = video.trim_start_ms / 1000
    const music = musicElements.get(video.id)
    if (music) music.currentTime = 0
    seekFlipTokYoutube(video.id, 0)
  } else {
    const music = musicElements.get(video.id)
    if (music?.duration) {
      const expected =
        (element.currentTime - video.trim_start_ms / 1000) % music.duration
      if (Math.abs(music.currentTime - expected) > 0.65)
        music.currentTime = expected
    }
    if (
      flipTokYoutubeOwner === video.id &&
      flipTokYoutubePlayer &&
      Math.abs(
        flipTokYoutubePlayer.getCurrentTime() -
          (element.currentTime - video.trim_start_ms / 1000),
      ) > 0.65
    ) {
      seekFlipTokYoutube(
        video.id,
        element.currentTime - video.trim_start_ms / 1000,
      )
    }
  }
}

function prepareMusic(video: FlipTokVideo, element: HTMLAudioElement): void {
  element.volume = video.music_volume / 100
}

function handleVideoClick(video: FlipTokVideo): void {
  if (videoClickTimer !== null) window.clearTimeout(videoClickTimer)
  videoClickTimer = window.setTimeout(() => {
    videoClickTimer = null
    togglePlayback(video)
  }, 230)
}

async function handleVideoDoubleClick(video: FlipTokVideo): Promise<void> {
  if (videoClickTimer !== null) {
    window.clearTimeout(videoClickTimer)
    videoClickTimer = null
  }
  if (!video.is_liked) await store.react(video, 'like')
  likedPulseId.value = video.id
  if (likePulseTimer !== null) window.clearTimeout(likePulseTimer)
  likePulseTimer = window.setTimeout(() => {
    likedPulseId.value = null
    likePulseTimer = null
  }, 650)
}

async function reactWithPulse(
  video: FlipTokVideo,
  kind: 'like' | 'save',
): Promise<void> {
  reactionPulse.value = null
  await nextTick()
  reactionPulse.value = { id: video.id, kind }
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  reactionPulseTimer = window.setTimeout(() => {
    reactionPulse.value = null
    reactionPulseTimer = null
  }, 480)
  await store.react(video, kind)
}

async function reactCommentWithPulse(comment: FlipTokComment): Promise<void> {
  const shouldPulse = !comment.is_liked
  const request = store.reactComment(comment)

  if (shouldPulse) {
    commentLikePulseId.value = null
    await nextTick()
    commentLikePulseId.value = comment.id
    if (commentLikePulseTimer !== null)
      window.clearTimeout(commentLikePulseTimer)
    commentLikePulseTimer = window.setTimeout(() => {
      commentLikePulseId.value = null
      commentLikePulseTimer = null
    }, 420)
  }

  await request
}

async function followFromFeed(video: FlipTokVideo): Promise<void> {
  if (video.is_following || followPendingIds.value.has(video.id)) return

  const pending = new Set(followPendingIds.value)
  pending.add(video.id)
  followPendingIds.value = pending
  const followed = await store.follow(video)
  const settled = new Set(followPendingIds.value)
  settled.delete(video.id)
  followPendingIds.value = settled
  if (!followed) {
    notify(t('errors.default'))
    return
  }
  if (!video.is_following) return

  const visible = new Set(followFeedbackIds.value)
  visible.add(video.id)
  followFeedbackIds.value = visible
  const previousTimer = followFeedbackTimers.get(video.id)
  if (previousTimer !== undefined) window.clearTimeout(previousTimer)
  followFeedbackTimers.set(
    video.id,
    window.setTimeout(() => {
      const next = new Set(followFeedbackIds.value)
      next.delete(video.id)
      followFeedbackIds.value = next
      followFeedbackTimers.delete(video.id)
    }, 950),
  )
}

async function changeMode(mode: 'for-you' | 'following'): Promise<void> {
  if (!(await store.loadFeed(mode))) {
    notify(t('errors.default'))
    return
  }
  feedBeforePreview.value = null
  await nextTick()
  observeVideos()
}

async function openComments(video: FlipTokVideo): Promise<void> {
  selectedVideo.value = video
  replyingTo.value = null
  expandedCommentThreads.value = new Set()
  if (!(await store.loadComments(video.id))) {
    notify(t('errors.video_not_found'))
    return
  }
  commentsOpen.value = true
}

function toggleReplies(commentId: string): void {
  const next = new Set(expandedCommentThreads.value)
  if (next.has(commentId)) next.delete(commentId)
  else next.add(commentId)
  expandedCommentThreads.value = next
}

function startReply(comment: FlipTokComment): void {
  replyingTo.value = comment
}

function cancelReply(): void {
  replyingTo.value = null
}

async function submitComment(): Promise<void> {
  if (!selectedVideo.value || !commentBody.value.trim()) return
  const response = await store.comment(
    selectedVideo.value.id,
    commentBody.value.trim(),
    replyingTo.value?.id,
  )
  if (!response.success)
    return notify(t(`errors.${response.error ?? 'default'}`))
  commentBody.value = ''
  replyingTo.value = null
  selectedVideo.value.comment_count += 1
  await store.loadComments(selectedVideo.value.id)
}

function chooseMedia(
  source: 'camera' | 'photos',
  mediaType: 'photo' | 'video',
): void {
  messageMedia.begin(
    'fliptok:compose',
    mediaType,
    '/apps/fliptok?compose=1',
    mediaType === 'photo' ? 10 : 1,
    {
      caption: caption.value,
      commentsEnabled: commentsEnabled.value,
      visibility: visibility.value,
      trimStartMs: trimStartMs.value,
      trimEndMs: trimEndMs.value,
      coverTimeMs: coverTimeMs.value,
      originalVolume: originalVolume.value,
      musicVolume: musicVolume.value,
      musicTrack: musicTrack.value,
      customMusicUrl: customMusicUrl.value,
      customMusicTitle: customMusicTitle.value,
      customMusicArtist: customMusicArtist.value,
      customMusicVideoId: customMusicVideoId.value,
      selectedMediaItems: selectedMediaItems.value,
    },
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: mediaType },
  })
}

function chooseVideo(source: 'camera' | 'photos' = 'photos'): void {
  chooseMedia(source, 'video')
}

function choosePhotoSlideshow(source: 'camera' | 'photos' = 'photos'): void {
  chooseMedia(source, 'photo')
}

async function publish(draft = false): Promise<void> {
  if (!selectedMedia.value || publishing.value) return
  const mediaIds = (
    selectedMediaItems.value.length
      ? selectedMediaItems.value
      : [selectedMedia.value]
  ).map((media) => media.id)
  publishing.value = true
  const response = await nuiCall('fliptok:publish', {
    caption: caption.value,
    commentsEnabled: commentsEnabled.value,
    draft,
    mediaId: selectedMedia.value.id,
    mediaIds,
    mediaType: selectedMediaType.value,
    trimStartMs: trimStartMs.value,
    trimEndMs: trimEndMs.value || null,
    coverTimeMs: coverTimeMs.value,
    originalVolume: originalVolume.value,
    musicVolume: hasMusic.value ? musicVolume.value : 0,
    musicTrack: musicTrack.value,
    customMusicUrl: musicTrack.value ? '' : customMusicUrl.value,
    visibility: visibility.value,
  })
  publishing.value = false
  if (!response.success)
    return notify(t(`errors.${response.error ?? 'default'}`))
  resetComposer()
  composeOpen.value = false
  tab.value = 'feed'
  feedBeforePreview.value = null
  await store.loadFeed('for-you')
  await nextTick()
  observeVideos()
  notify(t(draft ? 'draftSaved' : 'published'))
}

function resetComposer(): void {
  selectedMedia.value = null
  selectedMediaItems.value = []
  composerPhotoIndex.value = 0
  caption.value = ''
  visibility.value = 'public'
  commentsEnabled.value = true
  trimStartMs.value = 0
  trimEndMs.value = 0
  coverTimeMs.value = 0
  originalVolume.value = 100
  musicVolume.value = 35
  musicTrack.value = ''
  customMusicUrl.value = ''
  customMusicDraftUrl.value = ''
  clearCustomMusicDetails()
  customMusicLoadFailed.value = false
  pauseFlipTokYoutube('composer')
  videoDurationMs.value = 0
}

function rangeNumber(value: unknown): number {
  if (typeof value === 'number') return value
  if (value instanceof Event)
    return Number((value.target as HTMLInputElement).value)
  return Number(value) || 0
}

function loadComposerVideo(event: Event): void {
  const element = event.target as HTMLVideoElement
  videoDurationMs.value = Math.max(1000, Math.floor(element.duration * 1000))
  if (!trimEndMs.value || trimEndMs.value > videoDurationMs.value)
    trimEndMs.value = videoDurationMs.value
  coverTimeMs.value = Math.min(
    Math.max(coverTimeMs.value, trimStartMs.value),
    trimEndMs.value,
  )
  element.currentTime = coverTimeMs.value / 1000
  element.volume = originalVolume.value / 100
}

function handleComposerPlayback(playing: boolean): void {
  if (customMusicVideoId.value) {
    if (playing) {
      void playFlipTokYoutube(
        'composer',
        customMusicVideoId.value,
        musicVolume.value,
        ((previewVideo.value?.currentTime ?? 0) * 1000 - trimStartMs.value) /
          1000,
      )
    } else {
      pauseFlipTokYoutube('composer')
    }
    return
  }
  pauseFlipTokYoutube('composer')
  if (!composerMusic.value) return
  if (playing) void composerMusic.value.play().catch(() => undefined)
  else composerMusic.value.pause()
}

function enforceComposerTrim(event: Event): void {
  const element = event.target as HTMLVideoElement
  if (trimEndMs.value && element.currentTime * 1000 >= trimEndMs.value) {
    element.currentTime = trimStartMs.value / 1000
    if (composerMusic.value) composerMusic.value.currentTime = 0
    seekFlipTokYoutube('composer', 0)
  }
}

function updateTrimStart(value: unknown): void {
  trimStartMs.value = Math.min(
    rangeNumber(value),
    Math.max(0, trimEndMs.value - 500),
  )
  coverTimeMs.value = Math.max(coverTimeMs.value, trimStartMs.value)
}

function updateTrimEnd(value: unknown): void {
  trimEndMs.value = Math.max(rangeNumber(value), trimStartMs.value + 500)
  coverTimeMs.value = Math.min(coverTimeMs.value, trimEndMs.value)
}

function updateCover(value: unknown): void {
  coverTimeMs.value = rangeNumber(value)
  if (previewVideo.value)
    previewVideo.value.currentTime = coverTimeMs.value / 1000
}

function formatDuration(value: number): string {
  const seconds = Math.max(0, Math.round(value / 1000))
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

function chooseVisibility(value: (typeof visibilityOptions)[number]): void {
  visibility.value = value
  visibilityMenuOpen.value = false
}

function openVisibilityMenu(event: MouseEvent): void {
  if (!(event.currentTarget instanceof HTMLElement)) return
  visibilityMenuTarget.value = event.currentTarget
  visibilityMenuOpen.value = true
}

function selectVisibility(id: string): void {
  if (visibilityOptions.includes(id as (typeof visibilityOptions)[number])) {
    chooseVisibility(id as (typeof visibilityOptions)[number])
  }
}

function chooseAccountType(value: (typeof accountTypeOptions)[number]): void {
  profileDraft.value.accountType = value
  accountTypeSheetOpen.value = false
}

async function runSearch(): Promise<void> {
  await store.discover(search.value)
}

function openDiscoveredVideo(video: FlipTokVideo): void {
  if (!feedBeforePreview.value) feedBeforePreview.value = [...store.feed]
  store.feed = [video]
  tab.value = 'feed'
}

async function openFeedTab(): Promise<void> {
  if (feedBeforePreview.value) {
    store.feed = feedBeforePreview.value
    feedBeforePreview.value = null
  }
  tab.value = 'feed'
  await nextTick()
  observeVideos()
}

async function openProfile(profileId?: number, handle?: string): Promise<void> {
  const loaded = await store.loadProfile(handle ? { handle } : { profileId })
  if (loaded) {
    commentsOpen.value = false
    actionsOpen.value = false
    tab.value = 'profile'
    return
  }
  notify(t('errors.profile_not_found'))
}

async function openOwnProfile(): Promise<void> {
  if (store.profile) {
    if (!(await store.loadProfile({ profileId: store.profile.id }))) {
      notify(t('errors.profile_not_found'))
      return
    }
    store.viewedProfile = null
  } else store.showOwnProfile()
  tab.value = 'profile'
}

async function openConnections(mode: ConnectionMode): Promise<void> {
  const profile = currentProfile.value
  if (!profile) return
  connectionsMode.value = mode
  if (!(await store.loadConnections(profile.id, mode))) {
    notify(t('errors.default'))
    return
  }
  connectionsOpen.value = true
}

async function openConnectionProfile(profile: FlipTokProfile): Promise<void> {
  connectionsOpen.value = false
  await openProfile(profile.id)
}

async function followConnection(profile: FlipTokProfile): Promise<void> {
  if (profile.is_owner || connectionIsFollowing(profile)) return
  if (!(await store.followProfile(profile))) notify(t('errors.default'))
}

function connectionIsFollowing(profile: FlipTokProfile): boolean {
  return (
    profile.is_following ||
    (connectionsMode.value === 'following' &&
      currentProfile.value?.is_owner === true)
  )
}

function openActions(video: FlipTokVideo): void {
  selectedVideo.value = video
  actionsOpen.value = true
}

async function shareVideo(video: FlipTokVideo): Promise<void> {
  const response = await nuiCall('fliptok:share', { id: video.id })
  if (!response.success) {
    notify(t(`errors.${response.error ?? 'default'}`))
    return
  }
  video.share_count += 1
  useEasyShareStore().open({
    appId: 'fliptok',
    copyText: `@${video.handle}: ${video.caption}`,
    id: video.id,
    imageUrl: video.url,
    kind: 'post',
    link: `skyphone://fliptok/video/${video.id}`,
    subtitle: `@${video.handle}`,
    title: video.caption || video.display_name,
  })
}

function shareCurrentProfile(): void {
  const profile = currentProfile.value
  if (!profile) return
  useEasyShareStore().open({
    appId: 'fliptok',
    copyText: `@${profile.handle}`,
    id: profile.id,
    kind: 'profile',
    link: `skyphone://fliptok/profile/${profile.id}`,
    subtitle: `@${profile.handle}`,
    title: profile.display_name,
  })
}

async function reportVideo(): Promise<void> {
  if (!selectedVideo.value || reportSubmitting.value) return
  reportSubmitting.value = true
  const response = await nuiCall('fliptok:report', {
    details: reportDetails.value.trim(),
    id: selectedVideo.value.id,
    reason: reportReason.value,
  })
  reportSubmitting.value = false
  if (!response.success)
    return notify(t(`errors.${response.error ?? 'default'}`))
  actionsOpen.value = false
  reportSheetOpen.value = false
  reportDetails.value = ''
  notify(t('reported'))
}

function openReport(): void {
  actionsOpen.value = false
  reportSheetOpen.value = true
}

async function blockCreator(): Promise<void> {
  if (!selectedVideo.value) return
  const blocked = await store.blockProfile(selectedVideo.value.profile_id)
  if (!blocked) return notify(t('errors.default'))
  actionsOpen.value = false
  notify(t('blocked'))
}

async function blockCurrentProfile(): Promise<void> {
  if (!currentProfile.value || currentProfile.value.is_owner) return
  if (await store.blockProfile(currentProfile.value.id)) {
    await openOwnProfile()
    notify(t('blocked'))
  }
}

function editProfile(): void {
  if (!store.profile) return
  profileDraft.value = {
    accountType: store.profile.account_type,
    avatarMediaId: store.profile.avatar_media_id ?? 0,
    bio: store.profile.bio,
    displayName: store.profile.display_name,
    handle: store.profile.handle,
  }
  selectedProfilePhoto.value = null
  profileEditOpen.value = true
}

function openProfileMedia(app: 'camera' | 'photos'): void {
  profilePhotoSheetOpen.value = false
  messageMedia.begin(
    'fliptok:profile-avatar',
    'photo',
    '/apps/fliptok?profileEdit=1',
    1,
    {
      draft: { ...profileDraft.value },
      selectedPhoto: selectedProfilePhoto.value,
    } satisfies ProfileMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeProfilePhoto(): void {
  selectedProfilePhoto.value = null
  profileDraft.value.avatarMediaId = 0
  profilePhotoSheetOpen.value = false
}

async function saveProfile(): Promise<void> {
  if (profileSaving.value) return
  profileSaving.value = true
  const response = await nuiCall<FlipTokProfile>('fliptok:update-profile', {
    ...profileDraft.value,
    avatarMediaId:
      selectedProfilePhoto.value?.id ?? profileDraft.value.avatarMediaId,
  })
  profileSaving.value = false
  if (!response.success || !response.data)
    return notify(t(`errors.${response.error ?? 'default'}`))
  store.profile = response.data
  store.viewedProfile = null
  selectedProfilePhoto.value = null
  profileEditOpen.value = false
}

async function followCurrentProfile(): Promise<void> {
  const profile = currentProfile.value
  if (!profile || profile.is_owner || profileFollowPending.value) return
  profileFollowPending.value = true
  const success = await store.followProfile(profile)
  profileFollowPending.value = false
  if (!success) notify(t('errors.default'))
}

function requestDeleteVideo(): void {
  if (!selectedVideo.value?.is_owner) return
  actionsOpen.value = false
  deleteDialogOpen.value = true
}

async function confirmDeleteVideo(): Promise<void> {
  if (!selectedVideo.value || deleteSubmitting.value) return
  deleteSubmitting.value = true
  const deleted = await store.deleteVideo(selectedVideo.value.id)
  deleteSubmitting.value = false
  if (!deleted) {
    notify(t('errors.video_not_found'))
    return
  }
  deleteDialogOpen.value = false
  selectedVideo.value = null
  notify(t('videoDeleted'))
}

watch(tab, async (value) => {
  videoElements.forEach((video) => video.pause())
  musicElements.forEach((audio) => audio.pause())
  pauseFlipTokYoutube()
  if (value === 'activity' && !(await store.loadActivities()))
    notify(t('errors.default'))
  if (value === 'discover' && store.searchResults.length === 0)
    await runSearch()
  if (value === 'feed') {
    await nextTick()
    observeVideos()
  }
})

watch(commentsOpen, (opened) => {
  if (opened) return
  expandedCommentThreads.value = new Set()
  replyingTo.value = null
})

watch(
  () => selectedMediaItems.value.length,
  (length) => {
    composerPhotoIndex.value = Math.max(
      0,
      Math.min(composerPhotoIndex.value, length - 1),
    )
  },
)

watch(
  () => store.authenticated,
  async (authenticated) => {
    if (!authenticated) return
    await nextTick()
    observeVideos()
  },
)

watch(search, () => {
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  searchTimer = window.setTimeout(() => {
    searchTimer = null
    void runSearch()
  }, 250)
})

watch(originalVolume, (value) => {
  if (previewVideo.value) previewVideo.value.volume = value / 100
})

watch(musicVolume, (value) => {
  if (composerMusic.value) composerMusic.value.volume = value / 100
  if (flipTokYoutubeOwner === 'composer') flipTokYoutubePlayer?.setVolume(value)
})

watch(
  [composerMusicUrl, customMusicVideoId],
  async ([value, youtubeVideoId]) => {
    customMusicLoadFailed.value = false
    await nextTick()
    if (youtubeVideoId) {
      if (previewVideo.value && !previewVideo.value.paused)
        void playFlipTokYoutube(
          'composer',
          youtubeVideoId,
          musicVolume.value,
          (previewVideo.value.currentTime * 1000 - trimStartMs.value) / 1000,
        )
      return
    }
    pauseFlipTokYoutube('composer')
    if (!value || !composerMusic.value) return
    composerMusic.value.volume = musicVolume.value / 100
    composerMusic.value.currentTime = 0
    if (previewVideo.value && !previewVideo.value.paused)
      void composerMusic.value.play().catch(() => undefined)
  },
)

onMounted(async () => {
  const profileSelection = messageMedia.consumeMany<ProfileMediaContext>(
    'fliptok:profile-avatar',
  )
  if (profileSelection?.context) {
    profileDraft.value = profileSelection.context.draft
    selectedProfilePhoto.value = profileSelection.context.selectedPhoto
  }
  if (profileSelection?.media[0]) {
    selectedProfilePhoto.value = profileSelection.media[0]
    profileDraft.value.avatarMediaId = profileSelection.media[0].id
  }
  if (profileSelection) {
    tab.value = 'profile'
    profileEditOpen.value = true
  }
  const selection = messageMedia.consumeMany<{
    caption?: string
    commentsEnabled?: boolean
    visibility?: 'public' | 'followers' | 'private'
    trimStartMs?: number
    trimEndMs?: number
    coverTimeMs?: number
    originalVolume?: number
    musicVolume?: number
    musicTrack?: string
    customMusicUrl?: string
    customMusicTitle?: string
    customMusicArtist?: string
    customMusicVideoId?: string
    selectedMediaItems?: PhoneMedia[]
  }>('fliptok:compose')
  if (selection) {
    const restoredMedia = selection.media.length
      ? selection.media
      : (selection.context?.selectedMediaItems ?? [])
    selectedMedia.value = restoredMedia[0] ?? null
    selectedMediaItems.value = restoredMedia
    composerPhotoIndex.value = 0
    caption.value = selection.context?.caption ?? ''
    commentsEnabled.value = selection.context?.commentsEnabled ?? true
    visibility.value = selection.context?.visibility ?? 'public'
    trimStartMs.value = selection.context?.trimStartMs ?? 0
    trimEndMs.value = selection.context?.trimEndMs ?? 0
    coverTimeMs.value = selection.context?.coverTimeMs ?? 0
    originalVolume.value = selection.context?.originalVolume ?? 100
    musicVolume.value = selection.context?.musicVolume ?? 35
    musicTrack.value = selection.context?.musicTrack ?? ''
    customMusicUrl.value = selection.context?.customMusicUrl ?? ''
    customMusicTitle.value = selection.context?.customMusicTitle ?? ''
    customMusicArtist.value = selection.context?.customMusicArtist ?? ''
    customMusicVideoId.value =
      selection.context?.customMusicVideoId ??
      parseYoutubeVideoId(customMusicUrl.value)
    customMusicLoadFailed.value = false
    composeOpen.value = true
  }
  await store.bootstrap()
  if (route.query.compose === '1' && store.authenticated)
    composeOpen.value = true
  const easyShareId = String(route.query.easyShareId ?? '')
  if (easyShareId && route.query.easyShareKind === 'profile') {
    const profileId = Number(easyShareId)
    if (Number.isInteger(profileId) && profileId > 0)
      await openProfile(profileId)
  } else if (easyShareId && route.query.easyShareKind === 'post') {
    const video = await store.loadVideo(easyShareId)
    if (video) {
      store.feed = [video]
      tab.value = 'feed'
    }
  }
  await nextTick()
  observeVideos()
})

onBeforeUnmount(() => {
  observer?.disconnect()
  if (videoClickTimer !== null) window.clearTimeout(videoClickTimer)
  if (likePulseTimer !== null) window.clearTimeout(likePulseTimer)
  if (commentLikePulseTimer !== null) window.clearTimeout(commentLikePulseTimer)
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  followFeedbackTimers.forEach((timer) => window.clearTimeout(timer))
  followFeedbackTimers.clear()
  if (photoSlideDrag) {
    if (photoSlideDrag.frame !== null) {
      window.cancelAnimationFrame(photoSlideDrag.frame)
    }
    if (photoSlideDrag.element.hasPointerCapture(photoSlideDrag.pointerId)) {
      photoSlideDrag.element.releasePointerCapture(photoSlideDrag.pointerId)
    }
    photoSlideDrag.element.classList.remove('photo-slideshow--dragging')
    photoSlideDrag = null
  }
  Array.from(photoSlideAnimations.keys()).forEach(cancelPhotoSlideAnimation)
  feedCards.clear()
  photoSlideElements.clear()
  videoElements.forEach((video) => video.pause())
  destroyFlipTokYoutube()
})
</script>

<template>
  <SkyAppPage
    class="fliptok-page"
    :dark="phone.isDarkMode"
    :label="t('name')"
    accent="#ff2d55"
    accent-soft="rgba(255, 45, 85, 0.18)"
  >
    <div v-if="store.loading && !store.feed.length" class="state">
      <SkySpinner :label="t('loading')" /><span>{{ t('loading') }}</span>
    </div>

    <section
      v-else-if="!store.authenticated"
      class="fliptok-auth"
      :class="{ 'fliptok-auth--dark': phone.isDarkMode }"
    >
      <SkyNavbar
        class="fliptok-auth__navbar"
        :aria-label="t(authMode === 'login' ? 'login' : 'register')"
        :scroll-el="null"
        variant="medium"
      />
      <div class="fliptok-auth__body">
        <SkyGlass class="fliptok-auth__glass">
          <header class="fliptok-auth__hero">
            <img :src="flipTokIcon" alt="" />
            <div>
              <h1>{{ t('authTitle') }}</h1>
              <p>
                {{ t(authMode === 'login' ? 'loginBody' : 'registerBody') }}
              </p>
            </div>
          </header>

          <SkySegmented
            class="fliptok-auth__segment"
            :active-index="authMode === 'login' ? 0 : 1"
            :item-count="2"
            raised
            strong
            rounded
          >
            <SkySegmentedButton
              :active="authMode === 'login'"
              @click="authMode = 'login'"
            >
              {{ t('login') }}
            </SkySegmentedButton>
            <SkySegmentedButton
              :active="authMode === 'register'"
              @click="authMode = 'register'"
            >
              {{ t('register') }}
            </SkySegmentedButton>
          </SkySegmented>

          <form class="fliptok-auth__form" @submit.prevent="submitAuth">
            <SkyBlockTitle>{{ t('accountDetails') }}</SkyBlockTitle>
            <SkyList inset strong>
              <SkyField
                v-if="authMode === 'register'"
                id="fliptok-display-name"
                :label="t('displayName')"
                :placeholder="t('displayNamePlaceholder')"
                :value="authDisplayName"
                maxlength="40"
                clear-button
                @input="authDisplayName = inputValue($event)"
              />
              <SkyField
                id="fliptok-handle"
                :label="t('username')"
                :placeholder="t('usernamePlaceholder')"
                :value="authHandle"
                maxlength="24"
                autocapitalize="none"
                autocomplete="username"
                clear-button
                @input="authHandle = inputValue($event)"
              />
              <SkyField
                id="fliptok-password"
                type="password"
                :label="t('password')"
                :placeholder="t('passwordPlaceholder')"
                :value="authPassword"
                :autocomplete="
                  authMode === 'login' ? 'current-password' : 'new-password'
                "
                maxlength="72"
                @input="authPassword = inputValue($event)"
              />
              <SkyField
                v-if="authMode === 'register'"
                id="fliptok-confirm-password"
                type="password"
                :label="t('confirmPassword')"
                :placeholder="t('confirmPasswordPlaceholder')"
                :value="authConfirmPassword"
                autocomplete="new-password"
                maxlength="72"
                @input="authConfirmPassword = inputValue($event)"
              />
            </SkyList>
            <SkyButton large rounded type="submit" :disabled="authSubmitting">
              <SkySpinner v-if="authSubmitting" :label="t('loading')" />
              <template v-else>{{
                t(authMode === 'login' ? 'login' : 'createAccount')
              }}</template>
            </SkyButton>
            <SkyBlock v-if="authMode === 'register'" class="fliptok-auth__hint">
              {{ t('registrationHint') }}
            </SkyBlock>
          </form>
        </SkyGlass>
      </div>
    </section>

    <template v-else-if="tab === 'feed'">
      <header class="feed-header">
        <button
          :class="{ active: store.mode === 'following' }"
          @click="changeMode('following')"
        >
          {{ t('following') }}
        </button>
        <button
          :class="{ active: store.mode === 'for-you' }"
          @click="changeMode('for-you')"
        >
          {{ t('forYou') }}
        </button>
      </header>
      <SkyLink
        component="button"
        icon-only
        class="feed-search"
        :aria-label="t('discover')"
        @click="tab = 'discover'"
      >
        <Search />
      </SkyLink>
      <main class="video-feed">
        <article
          v-for="video in store.feed"
          :key="video.id"
          :ref="(el) => setFeedCard(video.id, el)"
          class="video-card"
          :class="{ 'video-card--photo': video.media_type === 'photo' }"
        >
          <div
            v-if="video.media_type === 'photo'"
            :ref="(el) => setPhotoSlideElement(video.id, el)"
            class="photo-slideshow"
            @pointerdown="beginPhotoSlideDrag(video.id, $event)"
            @pointermove="updatePhotoSlideDrag"
            @pointerup="endPhotoSlideDrag(video, $event)"
            @pointercancel="endPhotoSlideDrag(video, $event)"
          >
            <div class="photo-slideshow__track">
              <img
                v-for="media in videoMedia(video)"
                :key="media.id || media.url"
                :src="media.url"
                alt=""
              />
            </div>
          </div>
          <span
            v-if="video.media_type === 'photo' && videoMedia(video).length > 1"
            class="photo-slideshow__count"
          >
            {{ photoSlideIndex(video.id) + 1 }} /
            {{ videoMedia(video).length }}
          </span>
          <video
            v-else
            :ref="(el) => setVideoElement(video.id, el)"
            :data-id="video.id"
            :src="video.url"
            loop
            playsinline
            preload="metadata"
            @loadedmetadata="
              prepareFeedVideo(video, $event.target as HTMLVideoElement)
            "
            @timeupdate="
              enforceVideoTrim(video, $event.target as HTMLVideoElement)
            "
            @error="handleFeedVideoError(video.id, $event)"
          />
          <audio
            v-if="video.music_url && video.music_source !== 'youtube'"
            :ref="(el) => setMusicElement(video.id, el)"
            :src="video.music_url"
            loop
            preload="metadata"
            @loadedmetadata="
              prepareMusic(video, $event.target as HTMLAudioElement)
            "
          />
          <div
            class="video-shade"
            :class="{
              'video-shade--passive': video.media_type === 'photo',
            }"
            @click="video.media_type !== 'photo' && handleVideoClick(video)"
            @dblclick.prevent="
              video.media_type !== 'photo' && handleVideoDoubleClick(video)
            "
          />
          <button
            v-if="playbackFailedIds.has(video.id)"
            type="button"
            class="video-playback-fallback"
            :aria-label="`${t('errors.video_not_found')} ${phone.t('Common.start')}`"
            @click.stop="retryPlayback(video)"
          >
            <TriangleAlert />
            <strong>{{ t('errors.video_not_found') }}</strong>
            <span>{{ phone.t('Common.start') }}</span>
          </button>
          <Transition name="double-like">
            <Heart
              v-if="likedPulseId === video.id"
              class="double-like-heart"
              fill="currentColor"
            />
          </Transition>
          <section class="video-copy">
            <div class="creator-line">
              <button
                class="creator-link"
                @click="openProfile(video.profile_id)"
              >
                <strong>@{{ video.handle }}</strong></button
              ><Check
                v-if="video.verified"
                class="verified"
                :aria-label="t('verified')"
              />
            </div>
            <p>
              <template
                v-for="(part, index) in textParts(video.caption)"
                :key="`${video.id}-${index}`"
              >
                <button
                  v-if="part.kind !== 'text'"
                  class="caption-link"
                  @click="openTextLink(part)"
                >
                  {{ part.value }}
                </button>
                <template v-else>{{ part.value }}</template>
              </template>
            </p>
            <div class="sound">
              <Music2 />{{
                video.music_title ||
                (video.music_url && !video.music_track
                  ? t('customSound')
                  : video.display_name)
              }}
              ·
              {{
                video.music_artist ||
                (video.music_url && !video.music_track
                  ? video.display_name
                  : t('originalSound'))
              }}
            </div>
          </section>
          <aside class="video-actions">
            <div class="video-profile-action">
              <button
                class="avatar"
                :aria-label="video.display_name"
                @click="openProfile(video.profile_id)"
              >
                <img v-if="video.avatar_url" :src="video.avatar_url" alt="" />
                <template v-else>{{ initials(video.display_name) }}</template>
              </button>
              <button
                v-if="
                  !video.is_owner &&
                  (!video.is_following || followFeedbackIds.has(video.id))
                "
                type="button"
                class="follow-dot"
                :class="{
                  'follow-dot--confirmed': video.is_following,
                  'follow-dot--pending': followPendingIds.has(video.id),
                }"
                :aria-label="video.is_following ? t('unfollow') : t('follow')"
                :disabled="video.is_following || followPendingIds.has(video.id)"
                @click.stop="followFromFeed(video)"
              >
                <Check v-if="video.is_following" /><Plus v-else />
              </button>
            </div>
            <button
              :class="{
                liked: video.is_liked,
                'reaction-pop':
                  reactionPulse?.id === video.id &&
                  reactionPulse.kind === 'like',
                'reaction-pop--like':
                  reactionPulse?.id === video.id &&
                  reactionPulse.kind === 'like',
              }"
              @click="reactWithPulse(video, 'like')"
            >
              <Heart fill="currentColor" /><span>{{
                compactCount(video.like_count)
              }}</span>
            </button>
            <button @click="openComments(video)">
              <MessageCircle fill="currentColor" /><span>{{
                compactCount(video.comment_count)
              }}</span>
            </button>
            <button
              :class="{
                saved: video.is_saved,
                'reaction-pop':
                  reactionPulse?.id === video.id &&
                  reactionPulse.kind === 'save',
                'reaction-pop--save':
                  reactionPulse?.id === video.id &&
                  reactionPulse.kind === 'save',
              }"
              @click="reactWithPulse(video, 'save')"
            >
              <Bookmark fill="currentColor" /><span>{{ t('save') }}</span>
            </button>
            <button @click="shareVideo(video)">
              <Share2 /><span>{{ compactCount(video.share_count) }}</span>
            </button>
            <button :aria-label="t('more')" @click="openActions(video)">
              <MoreHorizontal />
            </button>
          </aside>
        </article>
        <div v-if="!store.feed.length" class="empty-feed">
          <Video /><strong>{{ t('emptyFeed') }}</strong
          ><span>{{ t('emptyFeedBody') }}</span>
        </div>
      </main>
    </template>

    <template v-else-if="tab === 'discover'">
      <SkyNavbar
        class="fliptok-navbar fliptok-discover-navbar"
        :title="t('discover')"
        variant="medium"
      >
        <template #subnavbar>
          <SkySearchbar
            v-model="search"
            class="discover-search"
            :label="t('searchPlaceholder')"
            :clear-label="t('clearSearch')"
            :placeholder="t('searchPlaceholder')"
          />
        </template>
      </SkyNavbar>
      <SkyScrollArea padded with-tabbar class="light-screen discover-screen">
        <div class="trend-pills">
          <SkyChip
            v-for="trend in discoveryTags"
            :key="trend.value"
            component="button"
            type="button"
            @click="search = trend.value"
          >
            {{ t(trend.labelKey) }}
          </SkyChip>
        </div>
        <div class="video-grid">
          <button
            v-for="video in store.searchResults"
            :key="video.id"
            @click="openDiscoveredVideo(video)"
          >
            <img v-if="video.media_type === 'photo'" :src="video.url" alt="" />
            <video
              v-else
              :src="video.url"
              preload="metadata"
              muted
              @loadedmetadata="
                ($event.target as HTMLVideoElement).currentTime =
                  video.cover_time_ms / 1000
              "
            /><span><Play />{{ compactCount(video.view_count) }}</span>
          </button>
        </div>
      </SkyScrollArea>
    </template>

    <template v-else-if="tab === 'activity'">
      <SkyNavbar
        class="fliptok-navbar"
        :title="t('activity')"
        variant="large"
      />
      <SkyScrollArea padded with-tabbar class="light-screen activity-list">
        <article
          v-for="activity in store.activities"
          :key="activity.id"
          @click="openProfile(activity.profile_id)"
        >
          <div class="activity-avatar">
            <img v-if="activity.avatar_url" :src="activity.avatar_url" alt="" />
            <template v-else>{{ initials(activity.display_name) }}</template>
          </div>
          <p>
            <strong
              >{{ activity.display_name }}
              <Check v-if="activity.verified" class="verified" /></strong
            ><span>{{ t(`activityKinds.${activity.kind}`) }}</span>
          </p>
        </article>
        <div v-if="!store.activities.length" class="light-empty">
          <Bell /><strong>{{ t('noActivity') }}</strong>
        </div>
      </SkyScrollArea>
    </template>

    <template v-else-if="tab === 'profile'">
      <SkyNavbar
        class="fliptok-navbar fliptok-profile-navbar"
        title=""
        :show-back="Boolean(store.viewedProfile)"
        :back-label="phone.t('Common.back')"
        back-appearance="surface"
        variant="medium"
        @back="openOwnProfile"
      >
        <template v-if="currentProfile" #right>
          <div class="profile-navbar-actions">
            <SkyLink
              v-if="currentProfile.is_owner"
              component="button"
              icon-only
              :aria-label="t('editProfile')"
              @click="editProfile"
            >
              <Pencil />
            </SkyLink>
            <SkyLink
              component="button"
              icon-only
              :aria-label="phone.t('Apps.easyShare.shareProfile')"
              @click="shareCurrentProfile"
            >
              <Share2 />
            </SkyLink>
          </div>
        </template>
      </SkyNavbar>
      <SkyScrollArea
        v-if="currentProfile"
        padded
        with-tabbar
        class="light-screen profile-screen"
      >
        <div class="profile-avatar">
          <img
            v-if="currentProfile.avatar_url"
            :src="currentProfile.avatar_url"
            alt=""
          />
          <template v-else>{{
            initials(currentProfile.display_name)
          }}</template>
        </div>
        <h1>
          {{ currentProfile.display_name }}
          <Check v-if="currentProfile.verified" class="verified" />
        </h1>
        <p class="handle">@{{ currentProfile.handle }}</p>
        <div class="profile-stats">
          <button type="button" @click="openConnections('following')">
            <strong>{{ currentProfile.following }}</strong
            ><span>{{ t('following') }}</span>
          </button>
          <button type="button" @click="openConnections('followers')">
            <strong>{{ currentProfile.followers }}</strong
            ><span>{{ t('followers') }}</span>
          </button>
          <div>
            <strong>{{ currentProfile.video_count }}</strong
            ><span>{{ t('videos') }}</span>
          </div>
        </div>
        <p class="bio">{{ currentProfile.bio || t('emptyBio') }}</p>
        <div v-if="!currentProfile.is_owner" class="profile-actions">
          <template>
            <SkyButton
              rounded
              :disabled="profileFollowPending"
              @click="followCurrentProfile"
            >
              {{ currentProfile.is_following ? t('unfollow') : t('follow') }}
            </SkyButton>
            <SkyButton
              rounded
              tonal
              class="danger-button"
              @click="blockCurrentProfile"
              >{{ t('block') }}</SkyButton
            >
          </template>
        </div>
        <div class="profile-video-grid">
          <button
            v-for="video in store.profileVideos"
            :key="video.id"
            @click="openDiscoveredVideo(video)"
          >
            <img v-if="video.media_type === 'photo'" :src="video.url" alt="" />
            <video
              v-else
              :src="video.url"
              muted
              playsinline
              preload="metadata"
              @loadedmetadata="
                ($event.target as HTMLVideoElement).currentTime =
                  video.cover_time_ms / 1000
              "
            />
            <span><Play />{{ compactCount(video.view_count) }}</span>
          </button>
        </div>
      </SkyScrollArea>
    </template>

    <SkyPillNavigation
      v-if="
        store.authenticated &&
        !composeOpen &&
        !profileEditOpen &&
        !connectionsOpen
      "
      class="main-tabs"
      :label="t('navigation')"
      layout="full"
    >
      <SkySegmented
        class="main-tabs__segments"
        :active-index="tabIndex"
        :item-count="5"
        :aria-label="t('navigation')"
        navigation
      >
        <SkySegmentedButton
          :active="tab === 'feed'"
          class="main-tab"
          @click="openFeedTab"
        >
          <Home /><small>{{ t('home') }}</small>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="tab === 'discover'"
          class="main-tab"
          @click="tab = 'discover'"
        >
          <Compass /><small>{{ t('discover') }}</small>
        </SkySegmentedButton>
        <SkySegmentedButton
          class="main-tab main-tab--create"
          @click="composeOpen = true"
        >
          <span class="create-icon" aria-hidden="true"><Plus /></span
          ><small>{{ t('create') }}</small>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="tab === 'activity'"
          class="main-tab"
          @click="tab = 'activity'"
        >
          <Bell /><small>{{ t('activity') }}</small>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="tab === 'profile'"
          class="main-tab"
          @click="openOwnProfile"
        >
          <UserRound /><small>{{ t('profile') }}</small>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>

    <section v-if="composeOpen" class="overlay-screen compose-screen">
      <SkyNavbar
        :title="t('newVideo')"
        :show-back="true"
        :back-label="t('cancel')"
        back-appearance="surface"
        @back="composeOpen = false"
      />
      <SkyScrollArea padded class="compose-body">
        <header class="compose-intro">
          <span><Video /></span>
          <div>
            <strong>{{ t('createTitle') }}</strong>
            <p>{{ t('createBody') }}</p>
          </div>
        </header>
        <SkyGlass v-if="!selectedMedia" class="media-picker">
          <header>
            <ImagePlus /><strong>{{ t('chooseMedia') }}</strong>
            <span>{{ t('chooseMediaHint') }}</span>
          </header>
          <div class="media-source-grid">
            <button type="button" @click="chooseVideo('camera')">
              <Camera /><strong>{{ t('recordVideo') }}</strong>
            </button>
            <button type="button" @click="chooseVideo('photos')">
              <Video /><strong>{{ t('chooseVideo') }}</strong>
            </button>
            <button type="button" @click="choosePhotoSlideshow('photos')">
              <ImagePlus /><strong>{{ t('photoSlideshow') }}</strong>
            </button>
          </div>
        </SkyGlass>
        <SkyGlass v-else class="media-preview">
          <video
            v-if="selectedMediaType === 'video'"
            ref="previewVideo"
            :src="selectedMedia.url"
            controls
            playsinline
            @loadedmetadata="loadComposerVideo"
            @play="handleComposerPlayback(true)"
            @pause="handleComposerPlayback(false)"
            @timeupdate="enforceComposerTrim"
          />
          <div v-else class="compose-photo-preview">
            <img
              v-if="selectedComposerPhoto"
              :key="selectedComposerPhoto.id"
              :src="selectedComposerPhoto.url"
              alt=""
            />
            <template v-if="selectedMediaItems.length > 1">
              <SkyButton
                glass
                icon-only
                rounded
                type="button"
                class="compose-photo-preview__arrow compose-photo-preview__arrow--previous"
                :disabled="composerPhotoIndex === 0"
                :aria-label="t('previousPhoto')"
                @click="moveComposerPhoto(-1)"
              >
                <ChevronLeft />
              </SkyButton>
              <SkyButton
                glass
                icon-only
                rounded
                type="button"
                class="compose-photo-preview__arrow compose-photo-preview__arrow--next"
                :disabled="composerPhotoIndex === selectedMediaItems.length - 1"
                :aria-label="t('nextPhoto')"
                @click="moveComposerPhoto(1)"
              >
                <ChevronRight />
              </SkyButton>
              <span class="compose-photo-preview__count">
                {{ composerPhotoIndex + 1 }} / {{ selectedMediaItems.length }}
              </span>
              <div class="compose-photo-preview__dots" aria-hidden="true">
                <span
                  v-for="media in selectedMediaItems"
                  :key="media.id"
                  :class="{
                    active:
                      selectedMediaItems[composerPhotoIndex]?.id === media.id,
                  }"
                />
              </div>
            </template>
          </div>
          <div class="media-preview__actions">
            <SkyButton
              small
              rounded
              tonal
              @click="
                selectedMediaType === 'photo'
                  ? choosePhotoSlideshow('photos')
                  : chooseVideo('photos')
              "
            >
              {{ t('changeMedia') }}
            </SkyButton>
            <SkyButton
              small
              rounded
              tonal
              @click="
                selectedMediaType === 'photo'
                  ? choosePhotoSlideshow('camera')
                  : chooseVideo('camera')
              "
            >
              <Camera />{{ t('camera') }}
            </SkyButton>
          </div>
          <audio
            v-if="composerMusicUrl"
            ref="composerMusic"
            :src="composerMusicUrl"
            loop
            preload="metadata"
            @loadedmetadata="markComposerMusicReady"
            @error="markComposerMusicFailed"
          />
        </SkyGlass>
        <SkyGlass
          v-if="selectedMediaType === 'video' && videoDurationMs"
          class="editor-card"
        >
          <h3>{{ t('trimAndCover') }}</h3>
          <label>
            <span
              >{{ t('trimStart') }}
              <strong>{{ formatDuration(trimStartMs) }}</strong></span
            >
            <SkyRange
              :value="trimStartMs"
              :min="0"
              :max="Math.max(0, trimEndMs - 500)"
              :step="100"
              @input="updateTrimStart"
            />
          </label>
          <label>
            <span
              >{{ t('trimEnd') }}
              <strong>{{ formatDuration(trimEndMs) }}</strong></span
            >
            <SkyRange
              :value="trimEndMs"
              :min="Math.min(videoDurationMs, trimStartMs + 500)"
              :max="videoDurationMs"
              :step="100"
              @input="updateTrimEnd"
            />
          </label>
          <label>
            <span
              >{{ t('coverFrame') }}
              <strong>{{ formatDuration(coverTimeMs) }}</strong></span
            >
            <SkyRange
              :value="coverTimeMs"
              :min="trimStartMs"
              :max="trimEndMs"
              :step="100"
              @input="updateCover"
            />
          </label>
        </SkyGlass>
        <SkyGlass v-if="selectedMedia" class="editor-card">
          <button class="sound-picker" type="button" @click="openMusicSheet">
            <span><Music2 />{{ t('sounds') }}</span>
            <strong>{{
              selectedMusic
                ? `${selectedMusic.title} · ${selectedMusic.artist}`
                : customMusicTitle
                  ? `${customMusicTitle} · ${customMusicArtist}`
                  : customMusicUrl
                    ? t('customSound')
                    : t('originalOnly')
            }}</strong>
            <ChevronDown />
          </button>
          <label>
            <span
              >{{ t('originalVolume') }}
              <strong>{{ originalVolume }}%</strong></span
            >
            <SkyRange
              :value="originalVolume"
              :min="0"
              :max="100"
              :step="1"
              @input="originalVolume = rangeNumber($event)"
            />
          </label>
          <label :class="{ disabled: !hasMusic }">
            <span
              >{{ t('musicVolume') }}
              <strong>{{ hasMusic ? `${musicVolume}%` : '—' }}</strong></span
            >
            <SkyRange
              :value="musicVolume"
              :min="0"
              :max="100"
              :step="1"
              :disabled="!hasMusic"
              @input="musicVolume = rangeNumber($event)"
            />
          </label>
          <p v-if="customMusicLoadFailed" class="custom-sound-error">
            {{ t('customSoundLoadFailed') }}
          </p>
        </SkyGlass>
        <SkyList inset strong class="compose-form-list">
          <SkyField
            type="textarea"
            :label="t('caption')"
            :placeholder="t('captionPlaceholder')"
            :value="caption"
            maxlength="500"
            @input="caption = inputValue($event)"
          />
          <SkyListItem
            link
            link-component="button"
            content-class="w-full"
            :title="t('whoCanWatch')"
            :after="
              visibility === 'public'
                ? t('public')
                : visibility === 'followers'
                  ? t('followersOnly')
                  : t('private')
            "
            @click="openVisibilityMenu"
          />
          <SkyListItem :title="t('allowComments')">
            <template #after>
              <SkyToggle
                v-model="commentsEnabled"
                :aria-label="t('allowComments')"
              />
            </template>
          </SkyListItem>
        </SkyList>
        <div class="compose-actions">
          <SkyButton
            tonal
            rounded
            :disabled="!canPublish"
            @click="publish(true)"
            >{{ t('saveDraft') }}</SkyButton
          ><SkyButton
            rounded
            :disabled="!canPublish || publishing"
            @click="publish(false)"
            >{{ publishing ? t('publishing') : t('post') }}</SkyButton
          >
        </div>
      </SkyScrollArea>
    </section>

    <section v-if="profileEditOpen" class="overlay-screen profile-edit">
      <SkyNavbar
        :title="t('editProfile')"
        :show-back="true"
        :back-label="t('backToProfile')"
        back-appearance="surface"
        @back="profileEditOpen = false"
      >
        <template #right>
          <SkyButton
            small
            rounded
            class="done-button"
            :disabled="profileSaving"
            @click="saveProfile"
          >
            {{ profileSaving ? t('savingProfile') : t('done') }}
          </SkyButton>
        </template>
      </SkyNavbar>
      <SkyScrollArea padded class="profile-edit__body">
        <section class="profile-photo-editor">
          <button
            class="profile-photo-trigger"
            type="button"
            :aria-label="t('changePhoto')"
            @click="profilePhotoSheetOpen = true"
          >
            <span class="profile-avatar profile-avatar--editor">
              <img
                v-if="selectedProfilePhoto?.url || store.profile?.avatar_url"
                :src="
                  selectedProfilePhoto?.url ?? store.profile?.avatar_url ?? ''
                "
                alt=""
              />
              <template v-else>{{
                initials(profileDraft.displayName)
              }}</template>
            </span>
            <span class="profile-photo-trigger__badge" aria-hidden="true">
              <Camera />
            </span>
          </button>
          <SkyLink
            class="profile-photo-change"
            @click="profilePhotoSheetOpen = true"
          >
            {{ t('changePhoto') }}
          </SkyLink>
        </section>
        <SkyBlockTitle>{{ t('profileDetails') }}</SkyBlockTitle>
        <SkyList strong class="profile-form-list">
          <SkyField
            id="fliptok-profile-display-name"
            :label="t('displayName')"
            :value="profileDraft.displayName"
            maxlength="40"
            clear-button
            @input="profileDraft.displayName = inputValue($event)"
          />
          <SkyField
            id="fliptok-profile-handle"
            :label="t('username')"
            :value="profileDraft.handle"
            maxlength="24"
            autocapitalize="none"
            clear-button
            @input="profileDraft.handle = inputValue($event)"
          />
          <SkyField
            id="fliptok-profile-bio"
            type="textarea"
            :label="t('bio')"
            :value="profileDraft.bio"
            maxlength="160"
            :spellcheck="false"
            @input="profileDraft.bio = inputValue($event)"
          />
          <SkyListItem
            link
            link-component="button"
            :title="t('accountType')"
            :after="t(`accountTypes.${profileDraft.accountType}`)"
            @click="accountTypeSheetOpen = true"
          />
        </SkyList>

        <SkyBlockTitle>{{ t('account') }}</SkyBlockTitle>
        <SkyList inset strong class="profile-account-list">
          <SkyListButton
            class="logout-button"
            variant="danger"
            @click="logoutDialogOpen = true"
          >
            {{ t('logout') }}
          </SkyListButton>
        </SkyList>
      </SkyScrollArea>
    </section>

    <div v-if="commentsOpen" class="fliptok-sheet">
      <SkySheet
        :opened="commentsOpen"
        :aria-label="t('comments')"
        grabber-clickable
        swipe-to-close
        @backdropclick="commentsOpen = false"
        @escape="commentsOpen = false"
        @grabberclick="commentsOpen = false"
        @swipeclose="commentsOpen = false"
      >
        <div class="comments-sheet">
          <header>
            <strong>
              {{ t('comments') }} ·
              {{ compactCount(selectedVideo?.comment_count ?? 0) }}
            </strong>
          </header>
          <div class="comments-list">
            <div
              v-for="thread in commentThreads"
              :key="thread.comment.id"
              class="comment-thread"
            >
              <article class="comment-row">
                <button
                  class="comment-avatar"
                  type="button"
                  @click="openProfile(thread.comment.profile_id)"
                >
                  <img
                    v-if="thread.comment.avatar_url"
                    :src="thread.comment.avatar_url"
                    alt=""
                  />
                  <template v-else>{{
                    initials(thread.comment.display_name)
                  }}</template>
                </button>
                <div class="comment-content">
                  <header>
                    <button
                      type="button"
                      @click="openProfile(thread.comment.profile_id)"
                    >
                      {{ thread.comment.display_name }}
                      <Check v-if="thread.comment.verified" class="verified" />
                    </button>
                    <time
                      :datetime="
                        new Date(thread.comment.created_at).toISOString()
                      "
                    >
                      {{ formatTimestamp(thread.comment.created_at) }}
                    </time>
                  </header>
                  <p>
                    <template
                      v-for="(part, index) in textParts(thread.comment.body)"
                      :key="`${thread.comment.id}-${index}`"
                    >
                      <button
                        v-if="part.kind !== 'text'"
                        class="caption-link"
                        type="button"
                        @click="openTextLink(part)"
                      >
                        {{ part.value }}
                      </button>
                      <template v-else>{{ part.value }}</template>
                    </template>
                  </p>
                  <footer>
                    <button type="button" @click="startReply(thread.comment)">
                      <Reply />{{ t('reply') }}
                    </button>
                    <button
                      type="button"
                      :class="{
                        liked: thread.comment.is_liked,
                        'comment-like-pulse':
                          commentLikePulseId === thread.comment.id,
                      }"
                      @click="reactCommentWithPulse(thread.comment)"
                    >
                      <Heart
                        :fill="
                          thread.comment.is_liked ? 'currentColor' : 'none'
                        "
                      />
                      {{ compactCount(thread.comment.like_count) }}
                    </button>
                  </footer>
                </div>
              </article>
              <button
                v-if="thread.replies.length"
                type="button"
                class="replies-toggle"
                @click="toggleReplies(thread.comment.id)"
              >
                <span></span>
                {{
                  expandedCommentThreads.has(thread.comment.id)
                    ? t('hideReplies', {
                        count: String(thread.replies.length),
                      })
                    : t('showReplies', {
                        count: String(thread.replies.length),
                      })
                }}
              </button>
              <article
                v-for="reply in thread.replies"
                v-show="expandedCommentThreads.has(thread.comment.id)"
                :key="reply.id"
                class="comment-row comment-row--reply"
              >
                <button
                  class="comment-avatar"
                  type="button"
                  @click="openProfile(reply.profile_id)"
                >
                  <img v-if="reply.avatar_url" :src="reply.avatar_url" alt="" />
                  <template v-else>{{ initials(reply.display_name) }}</template>
                </button>
                <div class="comment-content">
                  <header>
                    <button
                      type="button"
                      @click="openProfile(reply.profile_id)"
                    >
                      {{ reply.display_name }}
                      <Check v-if="reply.verified" class="verified" />
                    </button>
                    <time :datetime="new Date(reply.created_at).toISOString()">
                      {{ formatTimestamp(reply.created_at) }}
                    </time>
                  </header>
                  <p>
                    <span v-if="reply.reply_to_handle" class="reply-handle"
                      >@{{ reply.reply_to_handle }}</span
                    >
                    {{ reply.body }}
                  </p>
                  <footer>
                    <button type="button" @click="startReply(thread.comment)">
                      <Reply />{{ t('reply') }}
                    </button>
                    <button
                      type="button"
                      :class="{
                        liked: reply.is_liked,
                        'comment-like-pulse': commentLikePulseId === reply.id,
                      }"
                      @click="reactCommentWithPulse(reply)"
                    >
                      <Heart
                        :fill="reply.is_liked ? 'currentColor' : 'none'"
                      />{{ compactCount(reply.like_count) }}
                    </button>
                  </footer>
                </div>
              </article>
            </div>
            <div v-if="!store.comments.length" class="light-empty">
              {{ t('noComments') }}
            </div>
          </div>
          <form
            v-if="selectedVideo?.comments_enabled"
            class="comments-composer"
            @submit.prevent="submitComment"
          >
            <div v-if="replyingTo" class="replying-to">
              <span>{{
                t('replyingTo', { handle: `@${replyingTo.handle}` })
              }}</span>
              <button
                type="button"
                :aria-label="t('cancelReply')"
                @click="cancelReply"
              >
                <X />
              </button>
            </div>
            <SkyMessagebar
              v-model="commentBody"
              class="comments-messagebar"
              embedded
              :outline="false"
              :aria-label="t('addComment')"
              :placeholder="
                replyingTo ? t('replyPlaceholder') : t('addComment')
              "
            >
              <template #right>
                <SkyLink
                  component="button"
                  icon-only
                  type="submit"
                  :aria-label="phone.t('Common.send')"
                >
                  <Send />
                </SkyLink>
              </template>
            </SkyMessagebar>
          </form>
          <p v-else class="comments-disabled">
            {{ t('errors.comments_disabled') }}
          </p>
        </div>
      </SkySheet>
    </div>

    <div v-if="actionsOpen" class="fliptok-sheet">
      <SkySheet
        :opened="actionsOpen"
        grabber-clickable
        swipe-to-close
        @backdropclick="actionsOpen = false"
        @grabberclick="actionsOpen = false"
        @swipeclose="actionsOpen = false"
      >
        <div class="action-sheet">
          <SkyList inset strong
            ><SkyListItem
              v-if="selectedVideo?.is_owner"
              link
              link-component="button"
              content-class="w-full"
              class="danger"
              :title="t('removeVideo')"
              @click="requestDeleteVideo" /><SkyListItem
              v-if="!selectedVideo?.is_owner"
              link
              link-component="button"
              content-class="w-full"
              :title="t('report')"
              @click="openReport" /><SkyListItem
              v-if="!selectedVideo?.is_owner"
              link
              link-component="button"
              content-class="w-full"
              class="danger"
              :title="t('block')"
              @click="blockCreator" /></SkyList
          ><SkyButton large rounded tonal @click="actionsOpen = false">{{
            t('cancel')
          }}</SkyButton>
        </div>
      </SkySheet>
    </div>
    <div v-if="reportSheetOpen" class="fliptok-sheet">
      <SkySheet
        :opened="reportSheetOpen"
        grabber-clickable
        swipe-to-close
        @backdropclick="reportSheetOpen = false"
        @grabberclick="reportSheetOpen = false"
        @swipeclose="reportSheetOpen = false"
      >
        <div class="selection-sheet report-sheet">
          <h3>{{ t('report') }}</h3>
          <p class="report-sheet__note">{{ t('reportDiscordNote') }}</p>
          <SkyList inset strong>
            <SkyListItem
              v-for="reason in reportReasonOptions"
              :key="reason"
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              :title="t(`reportReasons.${reason}`)"
              @click="reportReason = reason"
            >
              <template #after
                ><Check v-if="reportReason === reason" class="selection-check"
              /></template>
            </SkyListItem>
          </SkyList>
          <SkyList inset strong>
            <SkyField
              type="textarea"
              :label="t('reportDetails')"
              :placeholder="t('reportDetails')"
              :value="reportDetails"
              maxlength="500"
              @input="reportDetails = inputValue($event)"
            />
          </SkyList>
          <div class="report-sheet__actions">
            <SkyButton
              rounded
              :disabled="reportSubmitting"
              @click="reportVideo"
              >{{ t('submitReport') }}</SkyButton
            >
            <SkyButton
              rounded
              tonal
              :disabled="reportSubmitting"
              @click="reportSheetOpen = false"
              >{{ t('cancel') }}</SkyButton
            >
          </div>
        </div>
      </SkySheet>
    </div>
    <div v-if="musicSheetOpen" class="fliptok-sheet">
      <SkySheet
        :opened="musicSheetOpen"
        grabber-clickable
        swipe-to-close
        @backdropclick="musicSheetOpen = false"
        @grabberclick="musicSheetOpen = false"
        @swipeclose="musicSheetOpen = false"
      >
        <div class="selection-sheet music-selection-sheet">
          <h3>{{ t('chooseSound') }}</h3>
          <SkyList inset strong>
            <SkyListItem
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              :title="t('originalOnly')"
              @click="chooseMusicTrack('')"
            >
              <template #after
                ><Check
                  v-if="!musicTrack && !customMusicUrl"
                  class="selection-check"
              /></template>
            </SkyListItem>
            <SkyListItem
              v-for="track in store.musicTracks"
              :key="track.id"
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              :title="track.title"
              :after="track.artist"
              @click="chooseMusicTrack(track.id)"
            >
              <template #after
                ><Check
                  v-if="musicTrack === track.id"
                  class="selection-check"
                /><span v-else>{{ track.artist }}</span></template
              >
            </SkyListItem>
          </SkyList>
          <p v-if="!store.musicTracks.length" class="sheet-note">
            {{ t('noMusic') }}
          </p>
          <section class="custom-sound-editor">
            <header>
              <span><Link2 /></span>
              <div>
                <strong>{{ t('customSound') }}</strong>
                <p>{{ t('customSoundHint') }}</p>
              </div>
              <Check
                v-if="customMusicUrl && !musicTrack"
                class="selection-check"
              />
            </header>
            <SkyList inset strong>
              <SkyField
                id="fliptok-custom-sound-url"
                type="url"
                input-mode="url"
                :label="t('customSoundLink')"
                :placeholder="t('customSoundPlaceholder')"
                :value="customMusicDraftUrl"
                maxlength="2048"
                :help="t('customSoundFormats')"
                :error="customMusicDraftError"
                clear-button
                :clear-label="phone.t('Common.clear')"
                @input="customMusicDraftUrl = inputValue($event)"
              />
            </SkyList>
            <audio
              v-if="
                validCustomMusicUrl(customMusicDraftUrl) &&
                !parseYoutubeVideoId(customMusicDraftUrl)
              "
              :src="customMusicDraftUrl.trim()"
              controls
              preload="metadata"
            />
            <p
              v-if="customMusicTitle && customMusicDraftUrl === customMusicUrl"
              class="custom-sound-metadata"
            >
              <strong>{{ customMusicTitle }}</strong>
              <span>{{ customMusicArtist }}</span>
            </p>
            <SkyButton
              rounded
              :disabled="
                customMusicResolving ||
                !validCustomMusicUrl(customMusicDraftUrl)
              "
              @click="chooseCustomMusic"
            >
              <SkySpinner
                v-if="customMusicResolving"
                :label="t('loadingSound')"
              />
              <template v-else>{{ t('useCustomSound') }}</template>
            </SkyButton>
          </section>
          <SkyButton large rounded tonal @click="musicSheetOpen = false">{{
            t('cancel')
          }}</SkyButton>
        </div>
      </SkySheet>
    </div>
    <SkyDropdown
      :items="visibilityMenuItems"
      :label="t('whoCanWatch')"
      :opened="visibilityMenuOpen"
      placement="auto"
      :target="visibilityMenuTarget"
      @backdropclick="visibilityMenuOpen = false"
      @escape="visibilityMenuOpen = false"
      @positionerror="visibilityMenuOpen = false"
      @select="selectVisibility"
    />
    <div v-if="profilePhotoSheetOpen" class="fliptok-sheet">
      <SkySheet
        :opened="profilePhotoSheetOpen"
        :aria-label="t('profilePhoto')"
        grabber-clickable
        swipe-to-close
        @backdropclick="profilePhotoSheetOpen = false"
        @escape="profilePhotoSheetOpen = false"
        @grabberclick="profilePhotoSheetOpen = false"
        @swipeclose="profilePhotoSheetOpen = false"
      >
        <div class="selection-sheet profile-photo-sheet">
          <h3>{{ t('profilePhoto') }}</h3>
          <SkyList inset strong>
            <SkyListItem
              link
              link-component="button"
              content-class="w-full"
              :title="t('chooseFromGallery')"
              @click="openProfileMedia('photos')"
            >
              <template #media><ImagePlus /></template>
            </SkyListItem>
            <SkyListItem
              link
              link-component="button"
              content-class="w-full"
              :title="t('takePhoto')"
              @click="openProfileMedia('camera')"
            >
              <template #media><Camera /></template>
            </SkyListItem>
            <SkyListItem
              v-if="selectedProfilePhoto || profileDraft.avatarMediaId"
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              class="danger"
              :title="t('removePhoto')"
              @click="removeProfilePhoto"
            >
              <template #media><Trash2 /></template>
            </SkyListItem>
          </SkyList>
          <SkyButton large rounded tonal @click="profilePhotoSheetOpen = false">
            {{ t('cancel') }}
          </SkyButton>
        </div>
      </SkySheet>
    </div>
    <div v-if="accountTypeSheetOpen" class="fliptok-sheet">
      <SkySheet
        :opened="accountTypeSheetOpen"
        grabber-clickable
        swipe-to-close
        @backdropclick="accountTypeSheetOpen = false"
        @grabberclick="accountTypeSheetOpen = false"
        @swipeclose="accountTypeSheetOpen = false"
      >
        <div class="selection-sheet">
          <h3>{{ t('accountType') }}</h3>
          <SkyList inset strong
            ><SkyListItem
              v-for="option in accountTypeOptions"
              :key="option"
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              :title="t(`accountTypes.${option}`)"
              @click="chooseAccountType(option)"
              ><template #after
                ><Check
                  v-if="profileDraft.accountType === option"
                  class="selection-check" /></template></SkyListItem></SkyList
          ><SkyButton
            large
            rounded
            tonal
            @click="accountTypeSheetOpen = false"
            >{{ t('cancel') }}</SkyButton
          >
        </div></SkySheet
      >
    </div>
    <section v-if="connectionsOpen" class="overlay-screen connections-screen">
      <SkyNavbar
        :title="t(connectionsMode)"
        :show-back="true"
        :back-label="phone.t('Common.back')"
        back-appearance="surface"
        @back="connectionsOpen = false"
      />
      <SkyScrollArea padded class="connections-body">
        <SkySegmented
          class="connections-tabs"
          :active-index="connectionsMode === 'followers' ? 0 : 1"
          :item-count="2"
          raised
          strong
          rounded
        >
          <SkySegmentedButton
            :active="connectionsMode === 'followers'"
            @click="openConnections('followers')"
            >{{ t('followers') }}</SkySegmentedButton
          >
          <SkySegmentedButton
            :active="connectionsMode === 'following'"
            @click="openConnections('following')"
            >{{ t('following') }}</SkySegmentedButton
          >
        </SkySegmented>
        <SkyList
          v-if="store.connections.length"
          inset
          strong
          class="connections-list"
        >
          <SkyListItem
            v-for="profile in store.connections"
            :key="profile.id"
            :title="profile.display_name"
            :text="`@${profile.handle}`"
          >
            <template #media>
              <button
                type="button"
                class="connection-profile"
                :aria-label="profile.display_name"
                @click="openConnectionProfile(profile)"
              >
                <span class="connection-avatar">
                  <img
                    v-if="profile.avatar_url"
                    :src="profile.avatar_url"
                    alt=""
                  />
                  <span v-else class="connection-avatar__fallback">
                    {{ initials(profile.display_name) }}
                  </span>
                </span>
              </button>
            </template>
            <template #after>
              <SkyButton
                v-if="!profile.is_owner"
                small
                rounded
                :tonal="connectionIsFollowing(profile)"
                :disabled="connectionIsFollowing(profile)"
                @click="followConnection(profile)"
                >{{
                  connectionIsFollowing(profile) ? t('unfollow') : t('follow')
                }}</SkyButton
              >
            </template>
          </SkyListItem>
        </SkyList>
        <div v-else class="light-empty connections-empty">
          <UsersRound /><strong>{{ t('noConnections') }}</strong>
        </div>
      </SkyScrollArea>
    </section>
    <SkyDialog
      :opened="logoutDialogOpen"
      @backdropclick="!logoutSubmitting && (logoutDialogOpen = false)"
    >
      <template #title>{{ t('signOutTitle') }}</template>
      <p>{{ t('signOutBody') }}</p>
      <template #buttons>
        <SkyDialogButton
          :disabled="logoutSubmitting"
          @click="logoutDialogOpen = false"
        >
          {{ t('cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          class="logout-dialog-button"
          :disabled="logoutSubmitting"
          @click="confirmLogout"
        >
          {{ logoutSubmitting ? t('signingOut') : t('logout') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>
    <SkyDialog
      :opened="deleteDialogOpen"
      @backdropclick="!deleteSubmitting && (deleteDialogOpen = false)"
    >
      <template #title>{{ t('deleteVideoTitle') }}</template>
      <p>{{ t('deleteVideoBody') }}</p>
      <template #buttons>
        <SkyDialogButton
          :disabled="deleteSubmitting"
          @click="deleteDialogOpen = false"
        >
          {{ t('cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          class="logout-dialog-button"
          :disabled="deleteSubmitting"
          @click="confirmDeleteVideo"
        >
          {{ deleteSubmitting ? t('deletingVideo') : t('removeVideo') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>
    <SkyNotification
      :opened="Boolean(feedback)"
      :text="feedback"
      @click="feedback = ''"
    />
  </SkyAppPage>
</template>

<style scoped>
.fliptok-page {
  height: 100%;
  overflow: hidden;
  background: #000;
  color: #fff;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
}
.state,
.light-empty,
.empty-feed {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  height: 100%;
  text-align: center;
}
.feed-header {
  position: absolute;
  z-index: 20;
  top: 15px;
  left: 50%;
  display: flex;
  gap: 18px;
  transform: translateX(-50%);
}
.feed-header button {
  border: 0;
  background: none;
  color: #aaa;
  font-size: 13px;
  font-weight: 650;
  padding: 6px 0;
}
.feed-header button.active {
  color: #fff;
  border-bottom: 2px solid #fff;
}
.feed-search {
  position: absolute;
  z-index: 20;
  top: 49px;
  right: 14px;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(20, 20, 22, 0.56);
  color: #fff !important;
  backdrop-filter: blur(12px);
}
.feed-search svg {
  width: 18px;
  height: 18px;
}
.video-feed {
  height: 100%;
  overflow-y: auto;
  scroll-snap-type: y mandatory;
  scrollbar-width: none;
}
.video-card {
  position: relative;
  height: 100%;
  scroll-snap-align: start;
  background: #111;
}
.video-card video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.video-shade {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    180deg,
    rgba(0, 0, 0, 0.18),
    transparent 36%,
    rgba(0, 0, 0, 0.74)
  );
}
.video-playback-fallback {
  position: absolute;
  z-index: 10;
  top: 50%;
  left: 50%;
  width: min(230px, 72%);
  display: grid;
  justify-items: center;
  gap: 7px;
  border: 1px solid rgb(255 255 255 / 24%);
  border-radius: 18px;
  padding: 16px;
  background: rgb(18 18 20 / 88%);
  color: #fff;
  text-align: center;
  transform: translate(-50%, -50%);
}
.video-playback-fallback svg {
  width: 28px;
  height: 28px;
  color: #ff9f0a;
}
.video-playback-fallback strong {
  font-size: 12px;
}
.video-playback-fallback span {
  color: #64a8ff;
  font-size: 11px;
  font-weight: 700;
}
.video-copy {
  position: absolute;
  left: 13px;
  right: 65px;
  bottom: 76px;
  text-shadow: 0 1px 3px #000;
}
.video-copy p {
  margin: 2px 0;
  font-size: 12px;
  line-height: 1.35;
}
.creator-line {
  display: flex;
  align-items: center;
  gap: 4px;
}
.verified {
  display: inline-block;
  width: 14px;
  height: 14px;
  stroke-width: 3;
  color: #0a84ff;
  fill: #0a84ff;
  stroke: #fff;
}
.location,
.sound {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  margin-top: 1px;
}
.location svg,
.sound svg {
  width: 12px;
}
.video-actions {
  position: absolute;
  right: 8px;
  bottom: 70px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.video-actions button {
  display: flex;
  flex-direction: column;
  align-items: center;
  border: 0;
  background: none;
  color: #fff;
  font-size: 9px;
  text-shadow: 0 1px 3px #000;
}
.video-actions svg {
  width: 25px;
  height: 25px;
  filter: drop-shadow(0 1px 2px #000);
}
.video-actions .avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  justify-content: center;
  background: #fff;
  color: #111;
  font-weight: 800;
  text-shadow: none;
}
.follow-dot {
  width: 18px;
  height: 18px !important;
  border-radius: 50% !important;
  background: #ff2d55 !important;
  margin-top: -19px;
}
.follow-dot svg {
  width: 12px !important;
}
.follow-dot--pending {
  opacity: 0.65;
}
.follow-dot--confirmed {
  animation: follow-confirmed-fade 950ms cubic-bezier(0.22, 1, 0.36, 1) forwards;
}
@keyframes follow-confirmed-fade {
  0%,
  48% {
    opacity: 1;
    transform: scale(1);
  }
  100% {
    opacity: 0;
    transform: scale(0.72);
  }
}
.liked svg {
  color: #ff2d55 !important;
}
.saved svg {
  color: #ffd60a !important;
}
.video-actions button span {
  color: #fff;
}
.main-tabs {
  z-index: 30 !important;
  background: rgba(8, 8, 8, 0.94) !important;
  color: #fff !important;
}
.main-tabs svg {
  width: 20px;
}
.create-icon {
  position: relative;
  display: block;
  width: 32px;
  height: 24px;
  color: #fff;
}
.create-icon::before,
.create-icon::after {
  position: absolute;
  content: '';
  border: 1px solid rgba(255, 255, 255, 0.28);
}
.create-icon::before {
  top: 4px;
  left: 2px;
  width: 23px;
  height: 17px;
  border-radius: 6px;
  background: #44417f;
  transform: rotate(-8deg);
}
.create-icon::after {
  top: 2px;
  left: 7px;
  width: 24px;
  height: 19px;
  border-radius: 7px;
  background: #625fca;
}
.create-icon svg {
  position: absolute;
  z-index: 1;
  top: 7px;
  left: 15px;
  width: 9px !important;
  height: 9px !important;
  fill: currentColor;
  stroke-width: 2.4;
}
.light-screen,
.overlay-screen {
  position: absolute;
  inset: 0 0 50px;
  background: #f2f2f7;
  color: #111;
  overflow-y: auto;
  padding-top: 48px;
}
.discover-screen {
  padding: 56px 10px 60px;
}
.trend-pills {
  display: flex;
  gap: 6px;
  overflow: auto;
  padding: 8px 2px;
}
.trend-pills button {
  border: 0;
  border-radius: 18px;
  background: #fff;
  padding: 7px 10px;
  font-size: 10px;
  white-space: nowrap;
}
.video-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}
.video-grid button {
  position: relative;
  aspect-ratio: 3/4;
  border: 0;
  padding: 0;
  background: #ddd;
  overflow: hidden;
}
.video-grid video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.video-grid span {
  position: absolute;
  left: 4px;
  bottom: 4px;
  display: flex;
  color: #fff;
  font-size: 9px;
}
.video-grid svg {
  width: 10px;
}
.activity-list {
  padding: 54px 12px;
}
.activity-list article,
.comments-list article {
  display: flex;
  gap: 10px;
  padding: 10px 2px;
  border-bottom: 1px solid #ddd;
}
.activity-avatar,
.comment-avatar {
  display: grid;
  place-items: center;
  flex: 0 0 34px;
  height: 34px;
  border-radius: 50%;
  background: #111;
  color: #fff;
  font-size: 10px;
  font-weight: 700;
}
.activity-list p,
.comments-list p {
  display: flex;
  flex-direction: column;
  margin: 0;
  font-size: 11px;
}
.activity-list strong,
.comments-list strong {
  display: flex;
  align-items: center;
  gap: 3px;
}
.activity-list p span {
  color: #666;
  margin-top: 2px;
}
.profile-screen {
  padding: 72px 20px;
  text-align: center;
}
.profile-avatar {
  display: grid;
  place-items: center;
  width: 76px;
  height: 76px;
  margin: auto;
  border-radius: 50%;
  background: #111;
  color: #fff;
  font-weight: 800;
  font-size: 22px;
}
.profile-screen h1 {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 4px;
  margin: 10px 0 2px;
  font-size: 18px;
}
.handle {
  color: #777;
  font-size: 11px;
}
.profile-stats {
  display: flex;
  justify-content: center;
  gap: 28px;
  margin: 18px 0;
}
.profile-stats div {
  display: flex;
  flex-direction: column;
}
.profile-stats span {
  font-size: 10px;
  color: #777;
}
.bio {
  font-size: 11px;
  min-height: 20px;
}
.overlay-screen {
  z-index: 40;
  inset: 0;
}
.compose-body {
  padding: 16px;
}
.media-picker {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 190px;
  border: 1px dashed #aaa;
  border-radius: 18px;
  background: #fff;
  color: #111;
}
.media-picker svg {
  width: 38px;
  height: 38px;
  margin-bottom: 8px;
}
.media-picker span {
  font-size: 10px;
  color: #777;
}
.media-preview {
  position: relative;
  height: 220px;
  border-radius: 18px;
  overflow: hidden;
  background: #000;
}
.media-preview video {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.media-preview button {
  position: absolute;
  right: 8px;
  bottom: 8px;
  border: 0;
  border-radius: 15px;
  padding: 6px 10px;
}
.compose-body textarea {
  box-sizing: border-box;
  width: 100%;
  min-height: 82px;
  margin-top: 10px;
  border: 0;
  border-radius: 14px;
  background: #fff;
  padding: 12px;
  font: inherit;
}
.field,
.toggle-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 10px;
  border-radius: 14px;
  background: #fff;
  padding: 11px;
  font-size: 11px;
}
.field svg {
  width: 16px;
}
.field input,
.field select,
.toggle-row select {
  flex: 1;
  border: 0;
  outline: 0;
  background: transparent;
}
.field span {
  flex: 1;
}
.compose-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 15px;
}
.nav-button,
.done-button {
  border: 0;
  background: none;
  color: #0a84ff;
}
.nav-button svg {
  width: 19px;
  height: 19px;
}
.profile-edit {
  padding-top: 54px;
}
.sheet-handle {
  width: 34px;
  height: 4px;
  border-radius: 2px;
  background: #aaa;
  margin: 7px auto;
}
.comments-sheet {
  height: min(62vh, 430px);
  display: flex;
  flex-direction: column;
  padding: 0 12px 12px;
  color: #111;
}
.comments-sheet > header {
  display: flex;
  justify-content: center;
  position: relative;
  padding: 7px;
}
.comments-sheet > header button {
  position: absolute;
  right: 0;
  border: 0;
  background: #ddd;
  border-radius: 50%;
  width: 25px;
  height: 25px;
}
.comments-sheet > header svg {
  width: 14px;
}
.comments-list {
  flex: 1;
  overflow: auto;
}
.action-sheet {
  display: flex;
  flex-direction: column;
  padding: 8px 12px 18px;
}
.action-sheet button {
  border: 0;
  border-bottom: 1px solid #ddd;
  background: #fff;
  padding: 13px;
  color: #0a84ff;
}
.action-sheet .danger {
  color: #ff3b30;
}
.empty-feed {
  padding: 30px;
}
.empty-feed svg {
  width: 42px;
}
.empty-feed span {
  font-size: 11px;
  color: #aaa;
}
.fliptok-page {
  position: relative;
}
.feed-header {
  top: 34px;
}
.main-tabs {
  position: absolute !important;
  right: 0;
  bottom: 0;
  left: 0;
  height: 52px;
}
.main-tabs :deep(.gap-4) {
  gap: 0 !important;
  width: 100% !important;
}
.main-tabs :deep(a) {
  flex: 1 1 0 !important;
  width: auto !important;
  min-width: 0 !important;
}
.verified {
  box-sizing: border-box;
  padding: 2px;
  border-radius: 50%;
  background: #0a84ff;
  color: #fff;
  fill: none;
  stroke: #fff;
}
.feed-header {
  top: 48px;
}
.video-copy {
  bottom: 72px;
}
.video-actions {
  bottom: 70px;
}
.main-tabs {
  bottom: 0;
  height: 68px;
  padding: 0 8px 22px !important;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(0, 0, 0, 0.92) !important;
  backdrop-filter: blur(20px);
}
.main-tabs :deep(.gap-4) {
  height: 46px !important;
}
.main-tabs :deep(a) {
  overflow: hidden;
  font-size: 9px !important;
}
.main-tabs :deep(svg) {
  width: 19px;
  height: 19px;
}
.light-screen,
.overlay-screen {
  background: #000;
  color: #f5f5f7;
}
.discover-screen {
  padding-top: 66px;
}
.discover-screen :deep(input) {
  color: #f5f5f7 !important;
  background: #1c1c1e !important;
}
.discover-screen :deep(input::placeholder) {
  color: #8e8e93 !important;
}
.trend-pills button {
  border: 1px solid #2c2c2e;
  background: #1c1c1e;
  color: #f5f5f7;
}
.video-grid button {
  background: #1c1c1e;
}
.activity-list {
  padding-top: 66px;
}
.activity-list article,
.comments-list article {
  border-color: #2c2c2e;
}
.activity-list p span {
  color: #a1a1a6;
}
.light-empty {
  color: #8e8e93;
}
.profile-screen {
  padding-top: 84px;
}
.profile-screen .handle,
.profile-stats span {
  color: #a1a1a6;
}
.profile-avatar,
.activity-avatar,
.comment-avatar {
  background: #2c2c2e;
  color: #fff;
}
.profile-screen :deep(button) {
  border: 1px solid #3a3a3c;
  background: #1c1c1e;
  color: #f5f5f7;
}
.compose-screen,
.profile-edit {
  padding-top: 54px;
}
.compose-body {
  padding: 18px 14px 36px;
}
.media-picker {
  border-color: #48484a;
  background: #1c1c1e;
  color: #f5f5f7;
}
.media-picker span {
  color: #a1a1a6;
}
.media-preview {
  border: 1px solid #3a3a3c;
}
.media-preview button {
  color: #fff;
  background: rgba(28, 28, 30, 0.9);
}
.compose-body textarea {
  border: 1px solid #3a3a3c;
  background: #1c1c1e;
  color: #f5f5f7;
  outline: none;
}
.compose-body textarea::placeholder,
.field input::placeholder {
  color: #8e8e93;
}
.compose-body textarea:focus,
.field:focus-within {
  border-color: #0a84ff;
}
.field,
.toggle-row {
  box-sizing: border-box;
  width: 100%;
  min-height: 50px;
  border: 1px solid transparent;
  background: #1c1c1e;
  color: #f5f5f7;
}
.field input {
  color: #f5f5f7;
}
.visibility-row {
  justify-content: flex-start;
  text-align: left;
}
.visibility-row span {
  flex: 1;
}
.visibility-row strong {
  font-size: 11px;
  font-weight: 500;
  color: #a1a1a6;
}
.visibility-row svg {
  width: 15px;
  color: #8e8e93;
}
.toggle-row {
  justify-content: space-between;
}
.toggle-row :deep(input) {
  cursor: pointer;
}
.compose-actions :deep(button) {
  min-height: 42px;
}
.compose-actions :deep(button:disabled) {
  color: #8e8e93 !important;
  background: #1c1c1e !important;
  opacity: 0.62;
}
.moderation-button {
  width: 44px;
  height: 44px;
  padding: 0;
  display: grid;
  place-items: center;
  color: var(--sky-app-accent);
}

.moderation-button__surface {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: var(--sky-surface-variant);
  box-shadow: inset 0 0 0 1px var(--sky-hairline);
}

.moderation-button__surface svg {
  width: 17px;
  height: 17px;
}
.done-button {
  font-weight: 650;
}
.fliptok-sheet :deep(.sky-sheet__panel) {
  color: #f5f5f7;
}
.sheet-handle {
  background: rgba(255, 255, 255, 0.28);
}
.comments-sheet {
  box-sizing: border-box;
  height: min(66vh, 460px);
  color: #f5f5f7;
}
.comments-sheet > header button {
  display: grid;
  place-items: center;
  color: #f5f5f7;
  background: #2c2c2e;
}
.comments-list p span {
  margin-top: 3px;
  color: #d1d1d6;
}
.action-sheet,
.selection-sheet {
  box-sizing: border-box;
  padding: 0 12px 28px;
  color: #f5f5f7;
  background: #151517;
}
.action-sheet :deep(ul),
.selection-sheet :deep(ul) {
  background: #1c1c1e;
}
.action-sheet :deep([class*='title']),
.selection-sheet :deep([class*='title']) {
  color: #f5f5f7;
}
.action-sheet .danger :deep([class*='title']) {
  color: #ff453a;
}
.action-sheet :deep(.sky-button),
.selection-sheet :deep(.sky-button) {
  margin-top: 10px;
  color: #0a84ff;
  background: #1c1c1e;
}
.selection-sheet h3 {
  margin: 4px 0 12px;
  text-align: center;
  font-size: 16px;
}
.selection-check {
  width: 18px;
  color: #0a84ff;
}
.fliptok-navbar {
  transform: translateY(24px);
}
.media-picker strong {
  font-size: 14px;
}
.media-picker span {
  font-size: 11px;
}
.compose-body textarea {
  font-size: 13px;
}
.field,
.toggle-row {
  font-size: 12px;
}
.discover-screen {
  padding-top: 100px;
}
.activity-list {
  padding-top: 100px;
}
.profile-screen {
  padding-top: 110px;
}
.video-shade {
  cursor: pointer;
  touch-action: manipulation;
}
.double-like-heart {
  position: absolute;
  z-index: 8;
  top: 50%;
  left: 50%;
  width: 76px;
  height: 76px;
  color: #fff;
  pointer-events: none;
  filter: drop-shadow(0 3px 12px rgba(0, 0, 0, 0.45));
  transform: translate(-50%, -50%) rotate(-9deg);
}
.double-like-enter-active,
.double-like-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.28s cubic-bezier(0.2, 0.85, 0.35, 1.25);
}
.double-like-enter-from,
.double-like-leave-to {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.35) rotate(-18deg);
}
.video-actions button {
  position: relative;
}
.reaction-pop--like svg {
  color: #ff2d55 !important;
}
.reaction-pop--save svg {
  color: #ffd60a !important;
}
.reaction-pop svg {
  animation: reaction-button-pop 0.46s cubic-bezier(0.2, 0.9, 0.25, 1.3);
}
@keyframes reaction-button-pop {
  0% {
    filter: drop-shadow(0 0 0 currentColor);
    transform: scale(1);
  }
  38% {
    filter: drop-shadow(0 0 5px currentColor);
    transform: scale(1.48) rotate(-9deg);
  }
  68% {
    filter: drop-shadow(0 0 2px currentColor);
    transform: scale(0.9) rotate(3deg);
  }
  100% {
    filter: drop-shadow(0 0 0 currentColor);
    transform: scale(1);
  }
}

.fliptok-auth {
  --fliptok-auth-bg: #e9ebf1;
  --fliptok-auth-text: #111;
  --fliptok-auth-secondary: #6e6e73;
  position: absolute;
  inset: 0;
  box-sizing: border-box;
  background: var(--fliptok-auth-bg);
  color: var(--fliptok-auth-text);
  overflow-y: auto;
}
.fliptok-auth--dark {
  --fliptok-auth-bg: #08080a;
  --fliptok-auth-text: #f5f5f7;
  --fliptok-auth-secondary: #98989d;
}
.fliptok-auth::before {
  position: absolute;
  top: 88px;
  left: 50%;
  width: 240px;
  height: 240px;
  border-radius: 50%;
  background: rgba(86, 72, 205, 0.2);
  content: '';
  filter: blur(58px);
  pointer-events: none;
  transform: translateX(-50%);
}
.fliptok-auth__navbar {
  position: sticky !important;
  z-index: 2;
  top: 0;
}
.fliptok-auth__body {
  position: relative;
  z-index: 1;
  display: flex;
  min-height: calc(100% - 58px);
  align-items: center;
  box-sizing: border-box;
  padding: 18px 14px 34px;
}
.fliptok-auth__glass {
  box-sizing: border-box;
  width: 100%;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: 26px !important;
  padding: 18px 0 16px;
  overflow: hidden;
}
.fliptok-auth:not(.fliptok-auth--dark) .fliptok-auth__glass {
  border-color: rgba(255, 255, 255, 0.7);
}
.fliptok-auth__hero {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 2px 20px 18px;
}
.fliptok-auth__hero img {
  width: 58px;
  height: 58px;
  flex: 0 0 58px;
  border-radius: 15px;
  box-shadow: 0 8px 24px rgba(45, 36, 135, 0.24);
}
.fliptok-auth__hero h1 {
  margin: 0;
  font-size: 20px;
  letter-spacing: -0.35px;
}
.fliptok-auth__hero p {
  margin: 4px 0 0;
  color: var(--fliptok-auth-secondary);
  font-size: 11px;
  line-height: 1.3;
}
.fliptok-auth__segment {
  box-sizing: border-box;
  width: calc(100% - 32px);
  margin: 0 16px 10px;
  overflow: hidden;
}
.fliptok-auth__form :deep(.sky-block-title) {
  margin-top: 12px;
  margin-bottom: 5px;
}
.fliptok-auth__form :deep(.sky-list) {
  margin-top: 0;
  margin-bottom: 12px;
}
.fliptok-auth__form :deep(input),
.fliptok-auth__form :deep(textarea) {
  color: var(--fliptok-auth-text) !important;
}
.fliptok-auth__form > .sky-button {
  box-sizing: border-box;
  width: calc(100% - 32px);
  margin: 0 16px;
}
.fliptok-auth__hint {
  margin: 9px 24px 0 !important;
  padding: 0 !important;
  color: var(--fliptok-auth-secondary);
  font-size: 10px;
  line-height: 1.35;
  text-align: center;
}
.logout-button {
  color: #ff3b30 !important;
}
.logout-dialog-button {
  color: #fff !important;
  background: #ff3b30 !important;
}
.logout-dialog-button:active {
  background: #d70015 !important;
}
.profile-form-list :deep(textarea) {
  min-height: 70px;
}
.creator-link,
.caption-link {
  display: inline;
  border: 0;
  padding: 0;
  background: none;
  color: inherit;
  font: inherit;
}
.caption-link {
  color: #8fc5ff;
  font-weight: 650;
}
.profile-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
}
.danger-button {
  color: #ff453a !important;
}
.profile-video-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
  margin: 22px -20px 0;
}
.profile-video-grid button {
  position: relative;
  aspect-ratio: 3 / 4;
  overflow: hidden;
  border: 0;
  padding: 0;
  background: #1c1c1e;
}
.profile-video-grid video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.profile-video-grid span {
  position: absolute;
  bottom: 5px;
  left: 5px;
  display: flex;
  align-items: center;
  gap: 2px;
  color: #fff;
  font-size: 9px;
}
.profile-video-grid svg {
  width: 10px;
}
.editor-card {
  margin-top: 10px;
  border: 1px solid #3a3a3c;
  border-radius: 15px;
  background: #1c1c1e;
  padding: 12px;
}
.editor-card h3 {
  margin: 0 0 9px;
  font-size: 13px;
}
.editor-card label {
  display: block;
  padding: 6px 0;
}
.editor-card label > span {
  display: flex;
  justify-content: space-between;
  color: #d1d1d6;
  font-size: 10px;
}
.editor-card label.disabled {
  opacity: 0.45;
}
.sound-picker {
  display: grid;
  grid-template-columns: 1fr auto;
  width: 100%;
  border: 0;
  border-bottom: 1px solid #3a3a3c;
  padding: 0 0 10px;
  background: none;
  color: #fff;
  text-align: left;
}
.sound-picker span {
  display: flex;
  align-items: center;
  gap: 5px;
  grid-column: 1;
  font-size: 10px;
  color: #a1a1a6;
}
.sound-picker strong {
  grid-column: 1;
  margin-top: 3px;
  font-size: 12px;
}
.sound-picker svg {
  width: 14px;
}
.sound-picker > svg {
  grid-column: 2;
  grid-row: 1 / 3;
  align-self: center;
}
.report-sheet textarea {
  box-sizing: border-box;
  width: 100%;
  min-height: 74px;
  margin: 0 0 10px;
  border: 1px solid #3a3a3c;
  border-radius: 12px;
  background: #1c1c1e;
  color: #fff;
  padding: 10px;
}
.report-sheet {
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-3));
}
.report-sheet__actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-2);
  margin-top: var(--sky-space-3);
}
.report-sheet__actions :deep(.sky-button) {
  width: 100%;
  min-width: 0;
  min-height: 44px;
  margin: 0;
  padding-inline: 10px;
  font-size: 13px;
}
.report-sheet__actions :deep(.sky-button:first-child) {
  color: #fff;
  background: var(--sky-app-accent);
}
.sheet-note {
  color: #a1a1a6;
  padding: 0 12px;
  font-size: 11px;
}
.moderation-screen {
  z-index: 45;
  padding-top: 78px;
}
.moderation-body {
  padding: 12px;
}
.moderation-body h2 {
  margin: 8px 2px 12px;
  font-size: 20px;
}
.report-card {
  display: grid;
  grid-template-columns: 86px 1fr;
  gap: 10px;
  margin-bottom: 10px;
  border-radius: 15px;
  background: #1c1c1e;
  padding: 9px;
}
.report-card video {
  width: 86px;
  height: 116px;
  border-radius: 10px;
  object-fit: cover;
  background: #000;
}
.report-card small,
.report-card p {
  display: block;
  margin: 4px 0;
  color: #a1a1a6;
  font-size: 10px;
}
.report-actions {
  display: flex;
  flex-direction: column;
  gap: 5px;
  margin-top: 7px;
}
.report-actions :deep(button) {
  width: 100%;
  min-height: 28px;
  font-size: 10px;
  white-space: nowrap;
}

/* FlipTok layout follows SkyUI's page, navbar, scroll and pill contracts. */
.fliptok-page {
  background: var(--sky-bg);
  color: var(--sky-text);
  font-family: var(--sky-font-family);
}

.fliptok-auth,
.fliptok-auth--dark {
  --fliptok-auth-bg: var(--sky-bg);
  --fliptok-auth-text: var(--sky-text);
  --fliptok-auth-secondary: var(--sky-muted);
}

.fliptok-auth__glass,
.media-picker,
.media-preview,
.editor-card {
  border-color: var(--sky-hairline);
  background: var(--sky-surface);
  color: var(--sky-text);
  box-shadow: var(--sky-shadow-glass);
}

.fliptok-navbar {
  transform: none;
}

.light-screen {
  position: relative;
  inset: auto;
  min-height: 0;
  padding-top: var(--sky-page-space);
  flex: 1 1 auto;
  background: var(--sky-bg);
  color: var(--sky-text);
}

.overlay-screen {
  position: absolute;
  z-index: 40;
  inset: 0;
  min-height: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: var(--sky-bg);
  color: var(--sky-text);
}

.discover-screen,
.activity-list,
.profile-screen {
  padding-top: var(--sky-space-2);
}

.discover-search {
  width: 100%;
  min-width: 0;
}

.trend-pills {
  margin: 0 calc(0px - var(--sky-space-1)) var(--sky-space-2);
  padding: var(--sky-space-1);
}

.trend-pills button {
  border: 0;
  background: var(--sky-surface);
  color: var(--sky-text);
}

.activity-list article {
  min-height: var(--sky-touch-target);
  align-items: center;
  border-color: var(--sky-hairline);
}

.activity-list p span,
.profile-screen .handle,
.profile-stats span,
.media-picker span,
.compose-intro p,
.connection-profile small,
.comment-content time {
  color: var(--sky-muted);
}

.avatar,
.profile-avatar,
.activity-avatar,
.comment-avatar,
.connection-avatar {
  overflow: hidden;
}

.avatar img,
.profile-avatar img,
.activity-avatar img,
.comment-avatar img,
.connection-avatar img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.profile-screen {
  padding-right: var(--sky-page-gutter);
  padding-left: var(--sky-page-gutter);
}

.profile-avatar {
  background: var(--sky-surface-variant);
  color: var(--sky-text);
}

.profile-stats {
  gap: var(--sky-space-2);
}

.profile-stats button,
.profile-stats div {
  min-width: 78px;
  min-height: 58px;
  padding: var(--sky-space-2);
  display: flex;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
  border: 0;
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
  color: var(--sky-text);
  font: inherit;
}

.profile-stats button:active {
  background: var(--sky-pressed);
}

.profile-actions {
  max-width: 286px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px;
}

.profile-actions :deep(.sky-button) {
  width: 100%;
  min-height: 44px;
  min-width: 0;
  padding-inline: 12px;
  font-size: 12px;
}

.profile-actions :deep(.sky-button svg) {
  width: 14px;
  height: 14px;
}

.profile-actions :deep(.sky-button:last-child:nth-child(odd)) {
  grid-column: 1 / -1;
}

.main-tabs {
  position: absolute !important;
  right: calc(var(--sky-safe-area-right) + var(--sky-page-gutter));
  bottom: calc(var(--sky-safe-area-bottom) + 10px);
  left: calc(var(--sky-safe-area-left) + var(--sky-page-gutter));
  height: auto;
  min-height: 56px;
  padding: 0 !important;
  border: 0;
  background: transparent !important;
  color: var(--sky-text) !important;
  backdrop-filter: none;
}

.main-tabs__segments {
  width: 100%;
}

.main-tab {
  min-width: 0;
  padding-inline: var(--sky-space-1) !important;
}

.main-tab svg {
  width: 19px;
  height: 19px;
}

.main-tab small {
  max-width: 100%;
  overflow: hidden;
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.video-copy {
  right: 58px;
  bottom: calc(var(--sky-safe-area-bottom) + 78px);
}

.video-actions {
  right: 10px;
  bottom: calc(var(--sky-safe-area-bottom) + 78px);
  gap: 4px;
}

.video-actions button {
  min-height: 31px;
  font-size: 8px;
}

.video-actions svg {
  width: 22px;
  height: 22px;
}

.video-actions .avatar {
  width: 34px;
  height: 34px;
}

.follow-dot {
  width: 16px;
  height: 16px !important;
  margin-top: -17px;
}

.follow-dot svg {
  width: 10px !important;
  height: 10px !important;
}

.create-icon::before {
  border-color: var(--sky-hairline);
  background: var(--sky-app-accent-soft);
}

.create-icon::after {
  border-color: var(--sky-app-accent-tint);
  background: var(--sky-app-accent);
}

.compose-screen,
.profile-edit,
.moderation-screen {
  padding-top: 0;
}

.compose-body,
.profile-edit__body {
  min-height: 0;
  flex: 1 1 auto;
}

.profile-edit__body {
  padding-right: var(--sky-page-gutter);
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-6));
  padding-left: var(--sky-page-gutter);
}

.compose-intro {
  margin-bottom: var(--sky-space-3);
  padding: var(--sky-space-3);
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  border-radius: var(--sky-radius-card);
  background: var(--sky-app-accent-soft);
}

.compose-intro > span {
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  display: grid;
  flex: 0 0 var(--sky-touch-target);
  place-items: center;
  border-radius: 50%;
  background: var(--sky-app-accent);
  color: #fff;
}

.compose-intro svg {
  width: 21px;
  height: 21px;
}

.compose-intro strong {
  display: block;
  font-size: 15px;
}

.compose-intro p {
  margin: 3px 0 0;
  font-size: 11px;
  line-height: 1.35;
}

.media-picker {
  min-height: 188px;
  height: auto;
  border: 1px dashed var(--sky-hairline);
}

.media-picker:active {
  background: var(--sky-pressed);
}

.editor-card {
  border-color: var(--sky-hairline);
  background: var(--sky-surface);
}

.editor-card label > span,
.sound-picker span {
  color: var(--sky-muted);
}

.sound-picker {
  border-color: var(--sky-hairline);
  color: var(--sky-text);
}

.custom-sound-error {
  margin: var(--sky-space-2) 0 0;
  color: var(--sky-danger);
  font-size: 11px;
  line-height: 1.35;
}

.music-selection-sheet {
  max-height: min(76vh, 620px);
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-3));
  overflow-y: auto;
}

.custom-sound-editor {
  margin-top: var(--sky-space-3);
  padding: var(--sky-space-3);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface-variant);
}

.custom-sound-editor > header {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: var(--sky-space-2);
}

.custom-sound-editor > header > span {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: var(--sky-app-accent-soft);
  color: var(--sky-app-accent);
}

.custom-sound-editor > header svg {
  width: 17px;
  height: 17px;
}

.custom-sound-editor > header strong {
  display: block;
  font-size: 13px;
}

.custom-sound-editor > header p {
  margin: 2px 0 0;
  color: var(--sky-muted);
  font-size: 10px;
  line-height: 1.35;
}

.custom-sound-editor :deep(.sky-list) {
  margin: var(--sky-space-3) 0 0;
}

.custom-sound-editor audio {
  width: 100%;
  height: 34px;
  margin-top: var(--sky-space-2);
}

.custom-sound-metadata {
  margin: var(--sky-space-2) 0 0;
  padding: var(--sky-space-2) var(--sky-space-3);
  display: flex;
  flex-direction: column;
  gap: 2px;
  border-radius: var(--sky-radius-control);
  background: var(--sky-app-accent-soft);
}

.custom-sound-metadata strong {
  font-size: 12px;
}

.custom-sound-metadata span {
  color: var(--sky-muted);
  font-size: 10px;
}

.custom-sound-editor :deep(.sky-button) {
  width: 100%;
}

.compose-form-list {
  margin-right: 0;
  margin-left: 0;
}

.compose-actions {
  margin-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-2));
}

.profile-photo-editor {
  margin: var(--sky-space-3) 0 var(--sky-space-4);
  padding: var(--sky-space-5) var(--sky-space-3);
  display: grid;
  justify-items: center;
  gap: var(--sky-space-2);
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background:
    radial-gradient(
      circle at 50% 20%,
      var(--sky-app-accent-soft),
      transparent 62%
    ),
    var(--sky-surface);
  box-shadow: var(--sky-shadow-thumb);
}

.profile-photo-trigger {
  position: relative;
  width: 90px;
  height: 90px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--sky-text);
  box-shadow:
    0 0 0 4px var(--sky-surface),
    0 0 0 6px var(--sky-app-accent-tint),
    var(--sky-shadow-thumb);
}

.profile-avatar--editor {
  width: 90px;
  height: 90px;
  margin: 0;
  display: grid;
  place-items: center;
  font-size: 22px;
}

.profile-photo-trigger__badge {
  position: absolute;
  right: -1px;
  bottom: 2px;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border: 3px solid var(--sky-bg);
  border-radius: 50%;
  background: var(--sky-app-accent);
  color: #fff;
}

.profile-photo-trigger__badge svg {
  width: 14px;
  height: 14px;
}

.profile-photo-change {
  min-height: 30px;
  font-size: 12px;
  font-weight: 650;
}

.profile-form-list {
  margin-right: 0;
  margin-left: 0;
}

.profile-form-list,
.profile-account-list {
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
  box-shadow: var(--sky-shadow-thumb);
}

.profile-account-list {
  margin-right: 0;
  margin-bottom: var(--sky-space-4);
  margin-left: 0;
}

.profile-edit__body :deep(.sky-block-title) {
  margin-right: var(--sky-space-1);
  margin-left: var(--sky-space-1);
}

.done-button {
  min-width: 58px;
  color: #fff;
  background: var(--sky-app-accent);
  box-shadow: 0 6px 16px var(--sky-app-accent-soft);
}

.profile-photo-sheet :deep(.sky-list-item__media svg) {
  width: 20px;
  height: 20px;
}

.profile-photo-sheet :deep(.danger .sky-list-item__row) {
  color: var(--sky-danger);
}

.fliptok-sheet :deep(.sky-sheet__panel),
.fliptok-connections-sheet :deep(.sky-sheet__panel) {
  overflow: hidden;
  background: var(--sky-surface);
  color: var(--sky-text);
}

.comments-sheet {
  height: min(68vh, 500px);
  padding: 0 var(--sky-space-3)
    calc(var(--sky-safe-area-bottom) + var(--sky-space-2));
  color: var(--sky-text);
}

.comments-sheet > header {
  min-height: var(--sky-touch-target);
  padding: 0;
  align-items: center;
}

.comments-sheet > header button,
.connections-sheet > header > button {
  width: 32px;
  height: 32px;
  min-width: 32px;
  min-height: 32px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: var(--sky-surface-variant);
  color: var(--sky-text);
}

.comments-list {
  padding: 0 var(--sky-space-1);
}

.comment-thread {
  padding: var(--sky-space-2) 0;
  border-bottom: 1px solid var(--sky-hairline);
}

.comments-list .comment-row {
  padding: var(--sky-space-2) 0;
  align-items: flex-start;
  border: 0;
}

.comments-list .comment-row--reply {
  margin-left: 38px;
}

.comment-row--reply .comment-avatar {
  flex-basis: 28px;
  width: 28px;
  height: 28px;
}

.comment-content {
  min-width: 0;
  flex: 1;
}

.comment-content header {
  min-height: 18px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-2);
}

.comment-content header button {
  position: static;
  width: auto;
  height: auto;
  min-width: 0;
  min-height: 0;
  padding: 0;
  display: flex;
  align-items: center;
  gap: 3px;
  border: 0;
  border-radius: 0;
  background: transparent;
  color: var(--sky-text);
  font: inherit;
  font-weight: 650;
}

.comment-content time {
  flex: none;
  font-size: 9px;
}

.comments-list .comment-content p {
  margin: 3px 0 5px;
  display: block;
  color: var(--sky-text);
  font-size: 11px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}

.comment-content footer {
  display: flex;
  align-items: center;
  gap: var(--sky-space-4);
}

.comment-content footer button {
  min-height: 24px;
  padding: 0;
  display: inline-flex;
  align-items: center;
  gap: var(--sky-space-1);
  border: 0;
  background: transparent;
  color: var(--sky-muted);
  font: inherit;
  font-size: 10px;
  font-weight: 650;
}

.comment-content footer svg {
  width: 13px;
  height: 13px;
}

.comment-content footer .liked {
  color: var(--sky-app-accent);
}

.comment-like-pulse svg {
  transform-origin: center;
  animation: comment-heart-pop 420ms cubic-bezier(0.22, 1, 0.36, 1);
}

@keyframes comment-heart-pop {
  0% {
    transform: scale(1);
  }
  38% {
    transform: scale(1.32) rotate(-7deg);
    filter: drop-shadow(0 0 3px var(--sky-app-accent));
  }
  72% {
    transform: scale(0.94) rotate(3deg);
  }
  100% {
    transform: scale(1);
  }
}

.reply-handle {
  margin-right: 3px;
  color: var(--sky-app-accent);
  font-weight: 650;
}

.comments-sheet form.comments-composer {
  display: block;
  padding: var(--sky-space-1) 0 0;
  border-top: 1px solid var(--sky-hairline);
}

.comments-messagebar {
  width: 100%;
  padding: var(--sky-space-1) 0 var(--sky-space-2);
  background: transparent;
}

.comments-disabled {
  margin: 0;
  padding: var(--sky-space-3) var(--sky-space-2)
    calc(var(--sky-safe-area-bottom) + var(--sky-space-3));
  border-top: 1px solid var(--sky-hairline);
  color: var(--sky-muted);
  font-size: 10px;
  text-align: center;
}

.replying-to {
  min-height: 20px;
  padding: 0 var(--sky-space-2) 2px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-2);
  color: var(--sky-muted);
  font-size: 9px;
  line-height: 1.2;
}

.replying-to span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.comments-sheet form .replying-to button {
  width: 20px;
  height: 20px;
  min-width: 20px;
  min-height: 20px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: var(--sky-pressed);
  color: var(--sky-text);
}

.comments-sheet form .replying-to svg {
  width: 11px;
  height: 11px;
}

@media (prefers-reduced-motion: reduce) {
  .follow-dot--confirmed,
  .comment-like-pulse svg {
    animation-duration: 1ms;
  }
}

/* FlipTok's media viewport is bound to the phone app, never the browser. */
.fliptok-page {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.video-feed {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  min-height: 0;
}

.video-card {
  width: 100%;
  height: 100%;
  min-height: 100%;
  max-height: 100%;
  overflow: hidden;
}

.photo-slideshow,
.compose-photo-preview {
  width: 100%;
  height: 100%;
}

.photo-slideshow {
  overflow: hidden;
}

.photo-slideshow__track,
.compose-photo-preview {
  display: flex;
}

.photo-slideshow__track {
  width: 100%;
  height: 100%;
  backface-visibility: hidden;
  transform: translate3d(0, 0, 0);
  will-change: transform;
}

.compose-photo-preview {
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
}

.compose-photo-preview::-webkit-scrollbar {
  display: none;
}

.photo-slideshow__track img,
.compose-photo-preview img {
  width: 100%;
  height: 100%;
  flex: 0 0 100%;
  object-fit: cover;
  scroll-snap-align: center;
}

.photo-slideshow__track img {
  backface-visibility: hidden;
  pointer-events: none;
  transform: translateZ(0);
  -webkit-user-drag: none;
}

.photo-slideshow__count {
  position: absolute;
  top: calc(var(--sky-safe-area-top) + 58px);
  right: 12px;
  padding: 4px 7px;
  border-radius: 999px;
  background: rgb(0 0 0 / 55%);
  color: #fff;
  font-size: 9px;
}

.video-profile-action {
  position: relative;
  width: 44px;
  min-height: 48px;
  display: grid;
  justify-items: center;
}

.video-actions .follow-dot {
  position: absolute;
  z-index: 2;
  bottom: 0;
  left: 50%;
  margin: 0;
  display: grid;
  place-items: center;
  transform: translateX(-50%);
}

.video-actions .follow-dot--confirmed {
  animation-name: follow-confirmed-fade-centered;
}

@keyframes follow-confirmed-fade-centered {
  0%,
  48% {
    opacity: 1;
    transform: translateX(-50%) scale(1);
  }
  100% {
    opacity: 0;
    transform: translateX(-50%) scale(0.72);
  }
}

.video-actions button {
  width: 44px;
  min-width: 44px;
  min-height: 44px;
  gap: 2px;
}

.video-actions button > span {
  min-width: 26px;
  text-align: center;
  line-height: 1.1;
}

.discover-screen {
  padding-top: 0;
}

.video-grid span,
.profile-video-grid span {
  display: inline-flex;
  flex-direction: row;
  align-items: center;
  gap: 3px;
  white-space: nowrap;
}

.video-grid img,
.profile-video-grid img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.fliptok-auth__body {
  min-height: calc(100% - 48px);
  justify-content: center;
  padding-top: 10px;
  padding-bottom: calc(var(--sky-safe-area-bottom) + 18px);
}

.fliptok-auth__glass {
  max-width: 350px;
  margin: auto;
}

.profile-navbar-actions {
  display: flex;
  align-items: center;
  gap: 2px;
}

.profile-navbar-actions svg {
  width: 18px;
  height: 18px;
}

.profile-stats button,
.profile-stats div,
.profile-screen :deep(.profile-stats button) {
  min-width: 70px;
  min-height: 48px;
  padding: 4px;
  border: 0;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
}

.profile-stats button:active {
  background: var(--sky-pressed);
}

.comment-content header button {
  max-width: 150px;
  overflow: hidden;
  font-size: 10px;
  line-height: 1.15;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.replies-toggle {
  min-height: 28px;
  margin: 0 0 2px 42px;
  padding: 0;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
  font-size: 10px;
  font-weight: 650;
}

.replies-toggle span {
  width: 24px;
  height: 1px;
  background: var(--sky-hairline);
}

.report-sheet {
  box-sizing: border-box;
  min-height: min(72vh, 560px);
  max-height: min(82vh, 650px);
  overflow-y: auto;
}

.report-sheet__note {
  margin: -4px 4px 10px;
  color: var(--sky-muted);
  font-size: 10px;
  line-height: 1.35;
}

.media-picker {
  padding: var(--sky-space-4);
  align-items: stretch;
  justify-content: flex-start;
  gap: var(--sky-space-3);
}

.media-picker > header {
  display: grid;
  justify-items: center;
  gap: 3px;
  text-align: center;
}

.media-picker > header svg {
  width: 28px;
  height: 28px;
  color: var(--sky-app-accent);
}

.media-picker > header strong,
.media-picker > header span {
  max-width: 100%;
  overflow-wrap: anywhere;
}

.media-picker > header strong {
  font-size: 13px;
  line-height: 1.25;
}

.media-picker > header span {
  color: var(--sky-muted);
  font-size: 10px;
  line-height: 1.35;
}

.media-source-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
}

.media-source-grid button {
  min-width: 0;
  min-height: 78px;
  padding: 8px 4px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface-variant);
  color: var(--sky-text);
  font: inherit;
  font-size: 9px;
  line-height: 1.2;
  text-align: center;
}

.media-source-grid button strong {
  width: 100%;
  overflow-wrap: anywhere;
}

.media-source-grid svg {
  width: 20px;
  height: 20px;
  color: var(--sky-app-accent);
}

.media-preview__actions {
  display: flex;
  gap: 6px;
}

.media-preview__actions :deep(.sky-button) {
  flex: 1 1 0;
}

.compose-photo-preview {
  height: 300px;
  border-radius: var(--sky-radius-control);
}

.connections-screen {
  z-index: 46;
}

.connections-body {
  min-height: 0;
  flex: 1 1 auto;
}

.connections-tabs {
  width: 100%;
  margin-bottom: 11px;
}

.connections-list {
  margin: 0;
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
}

.connections-list :deep(.sky-list-item__content) {
  min-height: 62px;
}

.connections-list :deep(.sky-list-item__title) {
  max-width: 112px;
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.connections-list :deep(.sky-list-item__text) {
  color: var(--sky-muted);
  font-size: 9px;
}

.connections-empty {
  min-height: 180px;
}

.connections-sheet {
  box-sizing: border-box;
  min-height: 300px;
  max-height: min(70vh, 520px);
  padding: 0 var(--sky-space-3)
    calc(var(--sky-safe-area-bottom) + var(--sky-space-3));
  display: flex;
  flex-direction: column;
}

.connections-sheet > header {
  min-height: var(--sky-touch-target);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.connections-sheet > header > div {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
}

.connections-sheet > header svg {
  width: 18px;
  height: 18px;
}

.connections-list {
  min-height: 0;
  flex: 1 1 auto;
  overflow-y: auto;
}

.connection-row {
  min-height: 60px;
  padding: var(--sky-space-2) 0;
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  border-top: 1px solid var(--sky-hairline);
}

.connection-profile {
  min-width: 0;
  padding: 0;
  display: flex;
  align-items: center;
  flex: 1;
  gap: var(--sky-space-3);
  border: 0;
  background: transparent;
  color: var(--sky-text);
  text-align: left;
}

.connection-avatar {
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  display: grid;
  flex: 0 0 var(--sky-touch-target);
  place-items: center;
  border-radius: 50%;
  background: var(--sky-surface-variant);
  font-size: 12px;
  font-weight: 700;
}

.connection-profile > span:last-child {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.connection-profile strong {
  display: flex;
  align-items: center;
  gap: 3px;
}

.moderation-body {
  min-height: 0;
  flex: 1 1 auto;
  overflow-y: auto;
}

.creator-line .verified,
.comment-content .verified,
.profile-screen .verified {
  flex: 0 0 auto;
  align-self: center;
  vertical-align: middle;
}

.connections-list .connection-profile {
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  flex: 0 0 var(--sky-touch-target);
}

/* Feed interaction and photo posts stay inside the phone viewport. */
.video-feed {
  overscroll-behavior-y: contain;
  contain: layout paint;
}

.video-card {
  block-size: 100%;
  inline-size: 100%;
}

.video-shade--passive {
  pointer-events: none;
}

.photo-slideshow {
  position: absolute;
  inset: 0;
  overscroll-behavior-inline: contain;
  cursor: grab;
  touch-action: pan-y;
  user-select: none;
  contain: layout paint;
}

.compose-photo-preview__arrow {
  width: 44px;
  height: 44px;
  min-width: 44px;
  min-height: 44px;
  padding: 0;
  display: grid;
  place-items: center;
  color: #fff;
  pointer-events: auto;
}

.photo-slideshow--dragging,
.photo-slideshow--settling {
  cursor: grabbing;
}

.compose-photo-preview__arrow svg {
  width: 17px;
  height: 17px;
}

.compose-photo-preview__arrow:disabled {
  opacity: 0;
  pointer-events: none;
}

.photo-slideshow__count {
  top: calc(var(--sky-safe-area-top) + 58px);
  right: 12px;
  z-index: 1;
  pointer-events: none;
}

/* The avatar follow control must not inherit the generic action height. */
.video-actions .follow-dot {
  bottom: -2px;
  width: 20px !important;
  height: 20px !important;
  min-width: 20px !important;
  min-height: 20px !important;
  padding: 0 !important;
  display: grid;
  place-items: center;
  border: 2px solid #111;
  border-radius: 50% !important;
  background: var(--sky-app-accent) !important;
  line-height: 0;
}

.video-actions .follow-dot svg {
  width: 11px !important;
  height: 11px !important;
  margin: 0;
  stroke-width: 3;
}

.video-actions .follow-dot:disabled {
  opacity: 1;
}

/* No unused action row is reserved above Discover. */
.fliptok-discover-navbar.sky-navbar--no-navigation {
  padding-top: calc(var(--sky-navbar-safe-area-top) + var(--sky-space-2));
}

.compose-photo-preview {
  position: relative;
  display: block;
  overflow: hidden;
  background: #111;
}

.compose-photo-preview img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: contain;
}

.compose-photo-preview__arrow {
  position: absolute;
  z-index: 2;
  top: 50%;
  transform: translateY(-50%);
}

.compose-photo-preview__arrow--previous {
  left: 10px;
}

.compose-photo-preview__arrow--next {
  right: 10px;
}

.compose-photo-preview__count {
  position: absolute;
  z-index: 2;
  top: 10px;
  right: 10px;
  padding: 4px 8px;
  border-radius: var(--sky-radius-pill);
  background: rgb(14 14 16 / 58%);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  backdrop-filter: blur(10px);
}

.compose-photo-preview__dots {
  position: absolute;
  z-index: 2;
  right: 42px;
  bottom: 10px;
  left: 42px;
  display: flex;
  justify-content: center;
  gap: 4px;
}

.compose-photo-preview__dots span {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: rgb(255 255 255 / 48%);
  box-shadow: 0 1px 3px rgb(0 0 0 / 36%);
}

.compose-photo-preview__dots span.active {
  width: 13px;
  border-radius: var(--sky-radius-pill);
  background: #fff;
}

/* Login and register center in the remaining phone area and still scroll. */
.fliptok-auth {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.fliptok-auth__navbar {
  flex: 0 0 auto;
}

.fliptok-auth__body {
  min-height: 0;
  padding-top: var(--sky-space-3);
  flex: 1 1 auto;
  overflow-y: auto;
}

.fliptok-auth__glass {
  margin-block: auto;
}

/* Profile actions are separate icon surfaces instead of one shared pill. */
.fliptok-profile-navbar :deep(.sky-navbar__right) {
  overflow: visible;
  background: transparent;
  box-shadow: none;
}

.profile-navbar-actions {
  gap: 6px;
}

.profile-navbar-actions :deep(.sky-link) {
  width: 38px;
  height: 38px;
  min-width: 38px;
  min-height: 38px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
  color: var(--sky-text);
  box-shadow: var(--sky-shadow-thumb);
}

.connections-list :deep(.sky-list-item__media) {
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  display: grid;
  place-items: center;
}

.connections-list .connection-profile {
  height: var(--sky-touch-target);
  padding: 0;
  display: grid;
  place-items: center;
}

.connections-list .connection-profile > .connection-avatar {
  position: relative;
  display: grid;
  place-items: center;
  line-height: 1;
  text-align: center;
}

.connections-list .connection-avatar__fallback {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  line-height: 1;
  text-align: center;
}

.connections-list :deep(.sky-button:disabled) {
  opacity: 0.72;
}
</style>
