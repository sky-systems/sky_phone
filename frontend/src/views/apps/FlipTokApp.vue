<script setup lang="ts">
import {
  ArrowLeft,
  Bell,
  Bookmark,
  Check,
  ChevronDown,
  Compass,
  Heart,
  Home,
  MapPin,
  MessageCircle,
  MoreHorizontal,
  Music2,
  Play,
  Plus,
  Search,
  ShieldAlert,
  Send,
  Share2,
  UserRound,
  Video,
  X,
} from 'lucide-vue-next'
import {
  kButton,
  kGlass,
  kLink,
  kList,
  kListItem,
  kNavbar,
  kPage,
  kPreloader,
  kRange,
  kSearchbar,
  kSheet,
  kTabbar,
  kTabbarLink,
  kToggle,
} from 'konsta/vue'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import { useFlipTokStore } from '@/stores/fliptok'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type {
  FlipTokProfile,
  FlipTokReport,
  FlipTokVideo,
} from '@/types/fliptok'
import type { PhoneMedia } from '@/types/media'
import { nuiCall } from '@/utils/nui'

type Tab = 'feed' | 'discover' | 'create' | 'activity' | 'profile'

const phone = usePhoneStore()
const store = useFlipTokStore()
const messageMedia = useMessageMediaStore()
const router = useRouter()
const tab = ref<Tab>('feed')
const selectedVideo = ref<FlipTokVideo | null>(null)
const selectedMedia = ref<PhoneMedia | null>(null)
const commentsOpen = ref(false)
const actionsOpen = ref(false)
const visibilitySheetOpen = ref(false)
const accountTypeSheetOpen = ref(false)
const composeOpen = ref(false)
const profileEditOpen = ref(false)
const moderationOpen = ref(false)
const musicSheetOpen = ref(false)
const reportSheetOpen = ref(false)
const search = ref('')
const commentBody = ref('')
const caption = ref('')
const location = ref('')
const visibility = ref<'public' | 'followers' | 'private'>('public')
const commentsEnabled = ref(true)
const trimStartMs = ref(0)
const trimEndMs = ref(0)
const coverTimeMs = ref(0)
const originalVolume = ref(100)
const musicVolume = ref(35)
const musicTrack = ref('')
const videoDurationMs = ref(0)
const previewVideo = ref<HTMLVideoElement | null>(null)
const composerMusic = ref<HTMLAudioElement | null>(null)
const reportReason = ref<'spam' | 'harassment' | 'dangerous' | 'illegal' | 'other'>('spam')
const reportDetails = ref('')
const publishing = ref(false)
const feedback = ref('')
const likedPulseId = ref<string | null>(null)
const reactionPulse = ref<{ id: string; kind: 'like' | 'save' } | null>(null)
const profileDraft = ref({
  accountType: 'person',
  bio: '',
  displayName: '',
  handle: '',
})
const videoElements = new Map<string, HTMLVideoElement>()
const musicElements = new Map<string, HTMLAudioElement>()
let observer: IntersectionObserver | null = null
let videoClickTimer: number | null = null
let likePulseTimer: number | null = null
let reactionPulseTimer: number | null = null
const darkNavbarColors = { bgIos: 'bg-black', textIos: 'text-white' }
const darkSheetColors = { bgIos: 'bg-[#151517]' }
const draftButtonColors = {
  tonalBgIos: 'bg-[#1c1c1e] active:bg-[#2c2c2e]',
  tonalTextIos: 'text-[#64a8ff]',
}
const reportRemoveButtonColors = {
  fillBgIos: 'bg-[#ff453a] active:bg-[#d93832]',
  fillTextIos: 'text-white',
}
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

const currentProfile = computed(() => store.viewedProfile ?? store.profile)
const selectedMusic = computed(() =>
  store.musicTracks.find((track) => track.id === musicTrack.value),
)
const canPublish = computed(
  () => Boolean(selectedMedia.value) && caption.value.length <= 500,
)

function t(key: string, values?: Record<string, string>): string {
  return phone.t(`Apps.fliptok.${key}`, values)
}

function initials(name: string): string {
  return name.trim().slice(0, 2).toUpperCase() || 'FT'
}

function compactCount(value: number): string {
  return new Intl.NumberFormat('en', {
    maximumFractionDigits: 1,
    notation: 'compact',
  }).format(value)
}

function notify(message: string): void {
  feedback.value = message
  window.setTimeout(() => {
    feedback.value = ''
  }, 2400)
}

function setVideoElement(id: string, element: unknown): void {
  if (element instanceof HTMLVideoElement) videoElements.set(id, element)
}

function setMusicElement(id: string, element: unknown): void {
  if (element instanceof HTMLAudioElement) musicElements.set(id, element)
}

function textParts(value: string): Array<{ kind: 'text' | 'hashtag' | 'mention'; value: string }> {
  return value.split(/([#@][A-Za-z0-9._]+)/g).filter(Boolean).map((part) => ({
    kind: part.startsWith('#') ? 'hashtag' : part.startsWith('@') ? 'mention' : 'text',
    value: part,
  }))
}

async function openTextLink(part: { kind: string; value: string }): Promise<void> {
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
        const video = entry.target as HTMLVideoElement
        if (entry.isIntersecting && entry.intersectionRatio > 0.72) {
          videoElements.forEach((item) => {
            if (item !== video) {
              item.pause()
              const otherAudio = musicElements.get(item.dataset.id ?? '')
              otherAudio?.pause()
            }
          })
          void video.play().catch(() => undefined)
          const id = video.dataset.id
          const music = id ? musicElements.get(id) : undefined
          if (music) void music.play().catch(() => undefined)
          if (id) void nuiCall('fliptok:view', { id })
        } else {
          video.pause()
          const id = video.dataset.id
          if (id) musicElements.get(id)?.pause()
        }
      })
    },
    { threshold: [0.72] },
  )
  videoElements.forEach((video) => observer?.observe(video))
}

function togglePlayback(video: FlipTokVideo): void {
  const element = videoElements.get(video.id)
  if (!element) return
  const music = musicElements.get(video.id)
  if (element.paused) {
    void element.play()
    if (music) void music.play().catch(() => undefined)
  } else {
    element.pause()
    music?.pause()
  }
}

function prepareFeedVideo(video: FlipTokVideo, element: HTMLVideoElement): void {
  element.volume = (Number(video.original_volume) || 0) / 100
  const start = Math.min((Number(video.trim_start_ms) || 0) / 1000, element.duration || 0)
  if (element.currentTime < start) element.currentTime = start
}

function enforceVideoTrim(video: FlipTokVideo, element: HTMLVideoElement): void {
  const end = (video.trim_end_ms ?? Math.round(element.duration * 1000)) / 1000
  if (element.currentTime < video.trim_start_ms / 1000 || element.currentTime >= end) {
    element.currentTime = video.trim_start_ms / 1000
    const music = musicElements.get(video.id)
    if (music) music.currentTime = 0
  } else {
    const music = musicElements.get(video.id)
    if (music?.duration) {
      const expected = (element.currentTime - video.trim_start_ms / 1000) % music.duration
      if (Math.abs(music.currentTime - expected) > 0.65) music.currentTime = expected
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
  reactionPulseTimer = window.setTimeout(() => {
    reactionPulse.value = null
    reactionPulseTimer = null
  }, 480)
  await store.react(video, kind)
}

async function changeMode(mode: 'for-you' | 'following'): Promise<void> {
  await store.loadFeed(mode)
  await nextTick()
  observeVideos()
}

async function openComments(video: FlipTokVideo): Promise<void> {
  selectedVideo.value = video
  await store.loadComments(video.id)
  commentsOpen.value = true
}

async function submitComment(): Promise<void> {
  if (!selectedVideo.value || !commentBody.value.trim()) return
  const response = await store.comment(
    selectedVideo.value.id,
    commentBody.value.trim(),
  )
  if (!response.success)
    return notify(t(`errors.${response.error ?? 'default'}`))
  commentBody.value = ''
  selectedVideo.value.comment_count += 1
  await store.loadComments(selectedVideo.value.id)
}

function chooseVideo(): void {
  messageMedia.begin('fliptok:compose', 'video', '/apps/fliptok?compose=1', 1, {
    caption: caption.value,
    commentsEnabled: commentsEnabled.value,
    location: location.value,
    visibility: visibility.value,
    trimStartMs: trimStartMs.value,
    trimEndMs: trimEndMs.value,
    coverTimeMs: coverTimeMs.value,
    originalVolume: originalVolume.value,
    musicVolume: musicVolume.value,
    musicTrack: musicTrack.value,
  })
  void router.push({
    path: '/apps/photos',
    query: { mediaAttachment: 'video' },
  })
}

async function publish(draft = false): Promise<void> {
  if (!selectedMedia.value || publishing.value) return
  publishing.value = true
  const response = await nuiCall('fliptok:publish', {
    caption: caption.value,
    commentsEnabled: commentsEnabled.value,
    draft,
    location: location.value,
    mediaId: selectedMedia.value.id,
    trimStartMs: trimStartMs.value,
    trimEndMs: trimEndMs.value || null,
    coverTimeMs: coverTimeMs.value,
    originalVolume: originalVolume.value,
    musicVolume: musicTrack.value ? musicVolume.value : 0,
    musicTrack: musicTrack.value,
    visibility: visibility.value,
  })
  publishing.value = false
  if (!response.success)
    return notify(t(`errors.${response.error ?? 'default'}`))
  resetComposer()
  composeOpen.value = false
  tab.value = 'feed'
  await store.loadFeed('for-you')
  await nextTick()
  observeVideos()
  notify(t(draft ? 'draftSaved' : 'published'))
}

function resetComposer(): void {
  selectedMedia.value = null
  caption.value = ''
  location.value = ''
  visibility.value = 'public'
  commentsEnabled.value = true
  trimStartMs.value = 0
  trimEndMs.value = 0
  coverTimeMs.value = 0
  originalVolume.value = 100
  musicVolume.value = 35
  musicTrack.value = ''
  videoDurationMs.value = 0
}

function rangeNumber(value: unknown): number {
  if (typeof value === 'number') return value
  if (value instanceof Event) return Number((value.target as HTMLInputElement).value)
  return Number(value) || 0
}

function loadComposerVideo(event: Event): void {
  const element = event.target as HTMLVideoElement
  videoDurationMs.value = Math.max(1000, Math.floor(element.duration * 1000))
  if (!trimEndMs.value || trimEndMs.value > videoDurationMs.value)
    trimEndMs.value = videoDurationMs.value
  coverTimeMs.value = Math.min(Math.max(coverTimeMs.value, trimStartMs.value), trimEndMs.value)
  element.currentTime = coverTimeMs.value / 1000
  element.volume = originalVolume.value / 100
}

function handleComposerPlayback(playing: boolean): void {
  if (!composerMusic.value) return
  if (playing) void composerMusic.value.play().catch(() => undefined)
  else composerMusic.value.pause()
}

function enforceComposerTrim(event: Event): void {
  const element = event.target as HTMLVideoElement
  if (trimEndMs.value && element.currentTime * 1000 >= trimEndMs.value) {
    element.currentTime = trimStartMs.value / 1000
    if (composerMusic.value) composerMusic.value.currentTime = 0
  }
}

function updateTrimStart(value: unknown): void {
  trimStartMs.value = Math.min(rangeNumber(value), Math.max(0, trimEndMs.value - 500))
  coverTimeMs.value = Math.max(coverTimeMs.value, trimStartMs.value)
}

function updateTrimEnd(value: unknown): void {
  trimEndMs.value = Math.max(rangeNumber(value), trimStartMs.value + 500)
  coverTimeMs.value = Math.min(coverTimeMs.value, trimEndMs.value)
}

function updateCover(value: unknown): void {
  coverTimeMs.value = rangeNumber(value)
  if (previewVideo.value) previewVideo.value.currentTime = coverTimeMs.value / 1000
}

function formatDuration(value: number): string {
  const seconds = Math.max(0, Math.round(value / 1000))
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

function setCommentsEnabled(event: Event): void {
  commentsEnabled.value = (event.target as HTMLInputElement).checked
}

function chooseVisibility(value: (typeof visibilityOptions)[number]): void {
  visibility.value = value
  visibilitySheetOpen.value = false
}

function chooseAccountType(value: (typeof accountTypeOptions)[number]): void {
  profileDraft.value.accountType = value
  accountTypeSheetOpen.value = false
}

async function runSearch(): Promise<void> {
  await store.discover(search.value)
}

function openDiscoveredVideo(video: FlipTokVideo): void {
  store.feed = [video]
  tab.value = 'feed'
}

async function openProfile(profileId?: number, handle?: string): Promise<void> {
  const loaded = await store.loadProfile(handle ? { handle } : { profileId })
  if (loaded) {
    commentsOpen.value = false
    actionsOpen.value = false
    tab.value = 'profile'
  }
}

async function openOwnProfile(): Promise<void> {
  if (store.profile) {
    await store.loadProfile({ profileId: store.profile.id })
    store.viewedProfile = null
  } else store.showOwnProfile()
  tab.value = 'profile'
}

function openActions(video: FlipTokVideo): void {
  selectedVideo.value = video
  actionsOpen.value = true
}

async function shareVideo(video: FlipTokVideo): Promise<void> {
  const response = await nuiCall('fliptok:share', { id: video.id })
  if (response.success) video.share_count += 1
  await navigator.clipboard?.writeText(`fliptok://video/${video.id}`)
  notify(t('linkCopied'))
}

async function reportVideo(): Promise<void> {
  if (!selectedVideo.value) return
  const response = await nuiCall('fliptok:report', {
    details: reportDetails.value.trim(),
    id: selectedVideo.value.id,
    reason: reportReason.value,
  })
  if (!response.success) return notify(t(`errors.${response.error ?? 'default'}`))
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
    openOwnProfile()
    notify(t('blocked'))
  }
}

async function openModeration(): Promise<void> {
  if (!(await store.loadReports())) return notify(t('errors.not_authorized'))
  moderationOpen.value = true
}

async function resolveReport(report: FlipTokReport, action: 'dismiss' | 'remove'): Promise<void> {
  if (!(await store.resolveReport(report.id, action)))
    notify(t('errors.default'))
}

function editProfile(): void {
  if (!store.profile) return
  profileDraft.value = {
    accountType: store.profile.account_type,
    bio: store.profile.bio,
    displayName: store.profile.display_name,
    handle: store.profile.handle,
  }
  profileEditOpen.value = true
}

async function saveProfile(): Promise<void> {
  const response = await nuiCall<FlipTokProfile>(
    'fliptok:update-profile',
    profileDraft.value,
  )
  if (!response.success || !response.data)
    return notify(t(`errors.${response.error ?? 'default'}`))
  store.profile = response.data
  profileEditOpen.value = false
}

watch(tab, async (value) => {
  videoElements.forEach((video) => video.pause())
  musicElements.forEach((audio) => audio.pause())
  if (value === 'activity') await store.loadActivities()
  if (value === 'discover' && store.searchResults.length === 0)
    await runSearch()
  if (value === 'feed') {
    await nextTick()
    observeVideos()
  }
})

watch(search, () => {
  window.clearTimeout((runSearch as unknown as { timer?: number }).timer)
  ;(runSearch as unknown as { timer?: number }).timer = window.setTimeout(
    runSearch,
    250,
  )
})

watch(originalVolume, (value) => {
  if (previewVideo.value) previewVideo.value.volume = value / 100
})

watch(musicVolume, (value) => {
  if (composerMusic.value) composerMusic.value.volume = value / 100
})

watch(musicTrack, async () => {
  await nextTick()
  if (!composerMusic.value) return
  composerMusic.value.volume = musicVolume.value / 100
  composerMusic.value.currentTime = 0
  if (previewVideo.value && !previewVideo.value.paused)
    void composerMusic.value.play().catch(() => undefined)
})

onMounted(async () => {
  const selection = messageMedia.consumeMany<{
    caption?: string
    commentsEnabled?: boolean
    location?: string
    visibility?: 'public' | 'followers' | 'private'
    trimStartMs?: number
    trimEndMs?: number
    coverTimeMs?: number
    originalVolume?: number
    musicVolume?: number
    musicTrack?: string
  }>('fliptok:compose')
  if (selection?.media[0]) {
    selectedMedia.value = selection.media[0]
    caption.value = selection.context?.caption ?? ''
    commentsEnabled.value = selection.context?.commentsEnabled ?? true
    location.value = selection.context?.location ?? ''
    visibility.value = selection.context?.visibility ?? 'public'
    trimStartMs.value = selection.context?.trimStartMs ?? 0
    trimEndMs.value = selection.context?.trimEndMs ?? 0
    coverTimeMs.value = selection.context?.coverTimeMs ?? 0
    originalVolume.value = selection.context?.originalVolume ?? 100
    musicVolume.value = selection.context?.musicVolume ?? 35
    musicTrack.value = selection.context?.musicTrack ?? ''
    composeOpen.value = true
  }
  await store.bootstrap()
  await nextTick()
  observeVideos()
})

onBeforeUnmount(() => {
  observer?.disconnect()
  if (videoClickTimer !== null) window.clearTimeout(videoClickTimer)
  if (likePulseTimer !== null) window.clearTimeout(likePulseTimer)
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
  videoElements.forEach((video) => video.pause())
})
</script>

<template>
  <k-page class="fliptok-page">
    <div v-if="store.loading && !store.feed.length" class="state">
      <k-preloader /><span>{{ t('loading') }}</span>
    </div>

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
      <k-link
        component="button"
        icon-only
        class="feed-search"
        :link-props="{ type: 'button' }"
        :aria-label="t('discover')"
        @click="tab = 'discover'"
      >
        <Search />
      </k-link>
      <main class="video-feed">
        <article v-for="video in store.feed" :key="video.id" class="video-card">
          <video
            :ref="(el) => setVideoElement(video.id, el)"
            :data-id="video.id"
            :src="video.url"
            loop
            playsinline
            preload="metadata"
            @loadedmetadata="prepareFeedVideo(video, $event.target as HTMLVideoElement)"
            @timeupdate="enforceVideoTrim(video, $event.target as HTMLVideoElement)"
          />
          <audio
            v-if="video.music_url"
            :ref="(el) => setMusicElement(video.id, el)"
            :src="video.music_url"
            loop
            preload="metadata"
            @loadedmetadata="prepareMusic(video, $event.target as HTMLAudioElement)"
          />
          <div
            class="video-shade"
            @click="handleVideoClick(video)"
            @dblclick.prevent="handleVideoDoubleClick(video)"
          />
          <Transition name="double-like">
            <Heart
              v-if="likedPulseId === video.id"
              class="double-like-heart"
              fill="currentColor"
            />
          </Transition>
          <section class="video-copy">
            <div class="creator-line">
              <button class="creator-link" @click="openProfile(video.profile_id)">
                <strong>@{{ video.handle }}</strong>
              </button
              ><Check
                v-if="video.verified"
                class="verified"
                :aria-label="t('verified')"
              />
            </div>
            <p>
              <template v-for="(part, index) in textParts(video.caption)" :key="`${video.id}-${index}`">
                <button v-if="part.kind !== 'text'" class="caption-link" @click="openTextLink(part)">{{ part.value }}</button>
                <template v-else>{{ part.value }}</template>
              </template>
            </p>
            <div v-if="video.location" class="location">
              <MapPin />{{ video.location }}
            </div>
            <div class="sound">
              <Music2 />{{ video.music_title || video.display_name }} ·
              {{ video.music_artist || t('originalSound') }}
            </div>
          </section>
          <aside class="video-actions">
            <button class="avatar" @click="openProfile(video.profile_id)">
              {{ initials(video.display_name) }}
            </button>
            <button
              v-if="!video.is_owner"
              class="follow-dot"
              @click="store.follow(video)"
            >
              <Check v-if="video.is_following" /><Plus v-else />
            </button>
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
            <button @click="openActions(video)"><MoreHorizontal /></button>
          </aside>
        </article>
        <div v-if="!store.feed.length" class="empty-feed">
          <Video /><strong>{{ t('emptyFeed') }}</strong
          ><span>{{ t('emptyFeedBody') }}</span>
        </div>
      </main>
    </template>

    <template v-else-if="tab === 'discover'">
      <k-navbar
        class="fliptok-navbar"
        :title="t('discover')"
        :colors="darkNavbarColors"
      />
      <div class="light-screen discover-screen">
        <k-searchbar v-model="search" :placeholder="t('searchPlaceholder')" />
        <div class="trend-pills">
          <button># LosSantos</button><button># Roleplay</button
          ><button># Trending</button>
        </div>
        <div class="video-grid">
          <button
            v-for="video in store.searchResults"
            :key="video.id"
            @click="openDiscoveredVideo(video)"
          >
            <video
              :src="video.url"
              preload="metadata"
              muted
              @loadedmetadata="($event.target as HTMLVideoElement).currentTime = video.cover_time_ms / 1000"
            /><span
              ><Play />{{ compactCount(video.view_count) }}</span
            >
          </button>
        </div>
      </div>
    </template>

    <template v-else-if="tab === 'activity'">
      <k-navbar
        class="fliptok-navbar"
        :title="t('activity')"
        :colors="darkNavbarColors"
      >
        <template v-if="store.isAdmin" #right>
          <button class="nav-button" :aria-label="t('moderation')" @click="openModeration">
            <ShieldAlert />
          </button>
        </template>
      </k-navbar>
      <div class="light-screen activity-list">
        <article v-for="activity in store.activities" :key="activity.id" @click="openProfile(activity.profile_id)">
          <div class="activity-avatar">
            {{ initials(activity.display_name) }}
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
      </div>
    </template>

    <template v-else-if="tab === 'profile'">
      <k-navbar
        class="fliptok-navbar"
        :title="currentProfile ? `@${currentProfile.handle}` : t('profile')"
        :colors="darkNavbarColors"
      >
        <template v-if="store.viewedProfile" #left>
          <button class="nav-button" @click="openOwnProfile"><ArrowLeft /></button>
        </template>
      </k-navbar>
      <div class="light-screen profile-screen" v-if="currentProfile">
        <div class="profile-avatar">
          {{ initials(currentProfile.display_name) }}
        </div>
        <h1>
          {{ currentProfile.display_name }}
          <Check v-if="currentProfile.verified" class="verified" />
        </h1>
        <p class="handle">@{{ currentProfile.handle }}</p>
        <div class="profile-stats">
          <div>
            <strong>{{ currentProfile.following }}</strong
            ><span>{{ t('following') }}</span>
          </div>
          <div>
            <strong>{{ currentProfile.followers }}</strong
            ><span>{{ t('followers') }}</span>
          </div>
          <div>
            <strong>{{ currentProfile.video_count }}</strong
            ><span>{{ t('videos') }}</span>
          </div>
        </div>
        <p class="bio">{{ currentProfile.bio || t('emptyBio') }}</p>
        <div class="profile-actions">
          <k-button v-if="currentProfile.is_owner" rounded @click="editProfile">{{ t('editProfile') }}</k-button>
          <template v-else>
            <k-button rounded @click="store.followProfile(currentProfile)">
              {{ currentProfile.is_following ? t('unfollow') : t('follow') }}
            </k-button>
            <k-button rounded tonal class="danger-button" @click="blockCurrentProfile">{{ t('block') }}</k-button>
          </template>
        </div>
        <div class="profile-video-grid">
          <button v-for="video in store.profileVideos" :key="video.id" @click="openDiscoveredVideo(video)">
            <video
              :src="video.url"
              muted
              playsinline
              preload="metadata"
              @loadedmetadata="($event.target as HTMLVideoElement).currentTime = video.cover_time_ms / 1000"
            />
            <span><Play />{{ compactCount(video.view_count) }}</span>
          </button>
        </div>
      </div>
    </template>

    <k-tabbar
      v-if="!composeOpen && !profileEditOpen && !moderationOpen"
      class="main-tabs"
      labels
      icons
    >
      <k-tabbar-link
        :active="tab === 'feed'"
        :label="t('home')"
        @click="tab = 'feed'"
        ><template #icon><Home /></template
      ></k-tabbar-link>
      <k-tabbar-link
        :active="tab === 'discover'"
        :label="t('discover')"
        @click="tab = 'discover'"
        ><template #icon><Compass /></template
      ></k-tabbar-link>
      <k-tabbar-link
        :active="false"
        :label="t('create')"
        @click="composeOpen = true"
        ><template #icon
          ><span class="create-icon" aria-hidden="true"><Play /></span></template
      ></k-tabbar-link>
      <k-tabbar-link
        :active="tab === 'activity'"
        :label="t('activity')"
        @click="tab = 'activity'"
        ><template #icon><Bell /></template
      ></k-tabbar-link>
      <k-tabbar-link
        :active="tab === 'profile'"
        :label="t('profile')"
        @click="openOwnProfile"
        ><template #icon><UserRound /></template
      ></k-tabbar-link>
    </k-tabbar>

    <div v-if="composeOpen" class="overlay-screen compose-screen">
      <k-navbar :title="t('newVideo')" :colors="darkNavbarColors"
        ><template #left
          ><button
            class="nav-button"
            :aria-label="t('cancel')"
            @click="composeOpen = false"
          >
            <X /></button></template
      ></k-navbar>
      <div class="compose-body">
        <button v-if="!selectedMedia" class="media-picker" @click="chooseVideo">
          <Video /><strong>{{ t('chooseVideo') }}</strong
          ><span>{{ t('chooseVideoHint') }}</span>
        </button>
        <div v-else class="media-preview">
          <video
            ref="previewVideo"
            :src="selectedMedia.url"
            controls
            playsinline
            @loadedmetadata="loadComposerVideo"
            @play="handleComposerPlayback(true)"
            @pause="handleComposerPlayback(false)"
            @timeupdate="enforceComposerTrim"
          /><button
            @click="chooseVideo"
          >
            {{ t('changeVideo') }}
          </button>
          <audio
            v-if="selectedMusic"
            ref="composerMusic"
            :src="selectedMusic.url"
            loop
            preload="metadata"
          />
        </div>
        <section v-if="selectedMedia && videoDurationMs" class="editor-card">
          <h3>{{ t('trimAndCover') }}</h3>
          <label>
            <span>{{ t('trimStart') }} <strong>{{ formatDuration(trimStartMs) }}</strong></span>
            <k-range :value="trimStartMs" :min="0" :max="Math.max(0, trimEndMs - 500)" :step="100" @input="updateTrimStart" />
          </label>
          <label>
            <span>{{ t('trimEnd') }} <strong>{{ formatDuration(trimEndMs) }}</strong></span>
            <k-range :value="trimEndMs" :min="Math.min(videoDurationMs, trimStartMs + 500)" :max="videoDurationMs" :step="100" @input="updateTrimEnd" />
          </label>
          <label>
            <span>{{ t('coverFrame') }} <strong>{{ formatDuration(coverTimeMs) }}</strong></span>
            <k-range :value="coverTimeMs" :min="trimStartMs" :max="trimEndMs" :step="100" @input="updateCover" />
          </label>
        </section>
        <section v-if="selectedMedia" class="editor-card">
          <button class="sound-picker" type="button" @click="musicSheetOpen = true">
            <span><Music2 />{{ t('sounds') }}</span>
            <strong>{{ selectedMusic ? `${selectedMusic.title} · ${selectedMusic.artist}` : t('originalOnly') }}</strong>
            <ChevronDown />
          </button>
          <label>
            <span>{{ t('originalVolume') }} <strong>{{ originalVolume }}%</strong></span>
            <k-range :value="originalVolume" :min="0" :max="100" :step="1" @input="originalVolume = rangeNumber($event)" />
          </label>
          <label :class="{ disabled: !musicTrack }">
            <span>{{ t('musicVolume') }} <strong>{{ musicTrack ? `${musicVolume}%` : '—' }}</strong></span>
            <k-range :value="musicVolume" :min="0" :max="100" :step="1" :disabled="!musicTrack" @input="musicVolume = rangeNumber($event)" />
          </label>
        </section>
        <textarea
          v-model="caption"
          :placeholder="t('captionPlaceholder')"
          maxlength="500"
        />
        <label class="field"
          ><MapPin /><input
            v-model="location"
            :placeholder="t('location')"
            maxlength="80"
        /></label>
        <button
          class="field visibility-row"
          type="button"
          @click="visibilitySheetOpen = true"
        >
          <span>{{ t('whoCanWatch') }}</span
          ><strong>{{
            visibility === 'public'
              ? t('public')
              : visibility === 'followers'
                ? t('followersOnly')
                : t('private')
          }}</strong
          ><ChevronDown />
        </button>
        <label class="toggle-row"
          ><span>{{ t('allowComments') }}</span
          ><k-toggle :checked="commentsEnabled" @change="setCommentsEnabled"
        /></label>
        <div class="compose-actions">
          <k-button
            tonal
            rounded
            :colors="draftButtonColors"
            :disabled="!canPublish"
            @click="publish(true)"
            >{{ t('saveDraft') }}</k-button
          ><k-button
            rounded
            :disabled="!canPublish || publishing"
            @click="publish(false)"
            >{{ publishing ? t('publishing') : t('post') }}</k-button
          >
        </div>
      </div>
    </div>

    <div v-if="profileEditOpen" class="overlay-screen profile-edit">
      <k-navbar :title="t('editProfile')" :colors="darkNavbarColors"
        ><template #left
          ><button class="nav-button" @click="profileEditOpen = false">
            <ArrowLeft /></button></template
        ><template #right
          ><button class="done-button" @click="saveProfile">
            {{ t('done') }}
          </button></template
        ></k-navbar
      >
      <div class="form-card">
        <label
          >{{ t('displayName')
          }}<input v-model="profileDraft.displayName" maxlength="40" /></label
        ><label
          >{{ t('username') }}
          <div class="handle-field">
            <span>@</span
            ><input v-model="profileDraft.handle" maxlength="24" /></div></label
        ><label
          >{{ t('bio')
          }}<textarea
            v-model="profileDraft.bio"
            maxlength="160"
            spellcheck="false"
          /></label
        ><button
          class="profile-select"
          type="button"
          @click="accountTypeSheetOpen = true"
        >
          <span
            ><small>{{ t('accountType') }}</small
            ><strong>{{
              t(`accountTypes.${profileDraft.accountType}`)
            }}</strong></span
          ><ChevronDown />
        </button>
      </div>
    </div>

    <div v-if="moderationOpen" class="overlay-screen moderation-screen">
      <k-navbar :title="t('moderation')" :colors="darkNavbarColors">
        <template #left>
          <button class="nav-button" @click="moderationOpen = false"><ArrowLeft /></button>
        </template>
      </k-navbar>
      <div class="moderation-body">
        <h2>{{ t('reports') }}</h2>
        <article v-for="report in store.reports" :key="report.id" class="report-card">
          <video :src="report.url" muted playsinline preload="metadata" />
          <div>
            <strong>@{{ report.creator_handle }}</strong>
            <small>{{ t(`reportReasons.${report.reason}`) }} · @{{ report.reporter_handle }}</small>
            <p>{{ report.details || report.caption }}</p>
            <div class="report-actions">
              <k-button small rounded tonal @click="resolveReport(report, 'dismiss')">{{ t('dismissReport') }}</k-button>
              <k-button
                small
                rounded
                :colors="reportRemoveButtonColors"
                @click="resolveReport(report, 'remove')"
              >{{ t('removeVideo') }}</k-button>
            </div>
          </div>
        </article>
        <div v-if="!store.reports.length" class="light-empty"><ShieldAlert /><strong>{{ t('noReports') }}</strong></div>
      </div>
    </div>

    <k-sheet
      v-if="commentsOpen"
      :opened="commentsOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="commentsOpen = false"
    >
      <div class="sheet-handle" />
      <div class="comments-sheet">
        <header>
          <strong>{{ t('comments') }}</strong
          ><button @click="commentsOpen = false"><X /></button>
        </header>
        <div class="comments-list">
          <article v-for="comment in store.comments" :key="comment.id" @click="openProfile(comment.profile_id)">
            <div class="comment-avatar">
              {{ initials(comment.display_name) }}
            </div>
            <p>
              <strong
                >{{ comment.display_name }}
                <Check v-if="comment.verified" class="verified" /></strong
              ><span>
                <template v-for="(part, index) in textParts(comment.body)" :key="`${comment.id}-${index}`">
                  <button v-if="part.kind !== 'text'" class="caption-link" @click.stop="openTextLink(part)">{{ part.value }}</button>
                  <template v-else>{{ part.value }}</template>
                </template>
              </span>
            </p>
          </article>
          <div v-if="!store.comments.length" class="light-empty">
            {{ t('noComments') }}
          </div>
        </div>
        <form @submit.prevent="submitComment">
          <input
            v-model="commentBody"
            :placeholder="t('addComment')"
            maxlength="300"
          /><button><Send /></button>
        </form>
      </div>
    </k-sheet>

    <k-sheet
      v-if="actionsOpen"
      :opened="actionsOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="actionsOpen = false"
      ><div class="sheet-handle" />
      <div class="action-sheet">
        <k-list inset strong
          ><k-list-item
            link
            link-component="button"
            :title="t('report')"
            @click="openReport" /><k-list-item
            link
            link-component="button"
            class="danger"
            :title="t('block')"
            @click="blockCreator" /></k-list
        ><k-button large rounded tonal @click="actionsOpen = false">{{
          t('cancel')
        }}</k-button>
      </div></k-sheet
    >
    <k-sheet
      v-if="reportSheetOpen"
      :opened="reportSheetOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="reportSheetOpen = false"
    >
      <div class="sheet-handle" />
      <div class="selection-sheet report-sheet">
        <h3>{{ t('report') }}</h3>
        <k-list inset strong>
          <k-list-item
            v-for="reason in reportReasonOptions"
            :key="reason"
            link
            link-component="button"
            :title="t(`reportReasons.${reason}`)"
            @click="reportReason = reason"
          >
            <template #after><Check v-if="reportReason === reason" class="selection-check" /></template>
          </k-list-item>
        </k-list>
        <textarea v-model="reportDetails" :placeholder="t('reportDetails')" maxlength="500" />
        <k-button large rounded @click="reportVideo">{{ t('submitReport') }}</k-button>
        <k-button large rounded tonal @click="reportSheetOpen = false">{{ t('cancel') }}</k-button>
      </div>
    </k-sheet>
    <k-sheet
      v-if="musicSheetOpen"
      :opened="musicSheetOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="musicSheetOpen = false"
    >
      <div class="sheet-handle" />
      <div class="selection-sheet">
        <h3>{{ t('chooseSound') }}</h3>
        <k-list inset strong>
          <k-list-item link link-component="button" :title="t('originalOnly')" @click="musicTrack = ''; musicSheetOpen = false">
            <template #after><Check v-if="!musicTrack" class="selection-check" /></template>
          </k-list-item>
          <k-list-item
            v-for="track in store.musicTracks"
            :key="track.id"
            link
            link-component="button"
            :title="track.title"
            :after="track.artist"
            @click="musicTrack = track.id; musicSheetOpen = false"
          >
            <template #after><Check v-if="musicTrack === track.id" class="selection-check" /><span v-else>{{ track.artist }}</span></template>
          </k-list-item>
        </k-list>
        <p v-if="!store.musicTracks.length" class="sheet-note">{{ t('noMusic') }}</p>
        <k-button large rounded tonal @click="musicSheetOpen = false">{{ t('cancel') }}</k-button>
      </div>
    </k-sheet>
    <k-sheet
      v-if="visibilitySheetOpen"
      :opened="visibilitySheetOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="visibilitySheetOpen = false"
      ><div class="sheet-handle" />
      <div class="selection-sheet">
        <h3>{{ t('whoCanWatch') }}</h3>
        <k-list inset strong
          ><k-list-item
            v-for="option in visibilityOptions"
            :key="option"
            link
            link-component="button"
            :title="
              option === 'public'
                ? t('public')
                : option === 'followers'
                  ? t('followersOnly')
                  : t('private')
            "
            @click="chooseVisibility(option)"
            ><template #after
              ><Check
                v-if="visibility === option"
                class="selection-check" /></template></k-list-item></k-list
        ><k-button large rounded tonal @click="visibilitySheetOpen = false">{{
          t('cancel')
        }}</k-button>
      </div></k-sheet
    >
    <k-sheet
      v-if="accountTypeSheetOpen"
      :opened="accountTypeSheetOpen"
      class="fliptok-sheet"
      :colors="darkSheetColors"
      @backdropclick="accountTypeSheetOpen = false"
      ><div class="sheet-handle" />
      <div class="selection-sheet">
        <h3>{{ t('accountType') }}</h3>
        <k-list inset strong
          ><k-list-item
            v-for="option in accountTypeOptions"
            :key="option"
            link
            link-component="button"
            :title="t(`accountTypes.${option}`)"
            @click="chooseAccountType(option)"
            ><template #after
              ><Check
                v-if="profileDraft.accountType === option"
                class="selection-check" /></template></k-list-item></k-list
        ><k-button large rounded tonal @click="accountTypeSheetOpen = false">{{
          t('cancel')
        }}</k-button>
      </div></k-sheet
    >
    <k-glass v-if="feedback" class="feedback">{{ feedback }}</k-glass>
  </k-page>
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
.liked {
  color: #ff2d55 !important;
}
.saved {
  color: #ffd60a !important;
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
.compose-body textarea,
.form-card textarea {
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
  width: 20px;
}
.profile-edit {
  padding-top: 54px;
}
.form-card {
  margin: 12px;
  border-radius: 15px;
  background: #fff;
  overflow: hidden;
}
.form-card label {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 11px;
  border-bottom: 1px solid #ddd;
  color: #777;
  font-size: 10px;
}
.form-card input,
.form-card select {
  border: 0;
  outline: 0;
  background: transparent;
  color: #111;
  font-size: 13px;
}
.form-card textarea {
  margin: 0;
  padding: 0;
  min-height: 60px;
}
.handle-field {
  display: flex;
  color: #111;
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
.comments-sheet header {
  display: flex;
  justify-content: center;
  position: relative;
  padding: 7px;
}
.comments-sheet header button {
  position: absolute;
  right: 0;
  border: 0;
  background: #ddd;
  border-radius: 50%;
  width: 25px;
  height: 25px;
}
.comments-sheet header svg {
  width: 14px;
}
.comments-list {
  flex: 1;
  overflow: auto;
}
.comments-sheet form {
  display: flex;
  gap: 7px;
}
.comments-sheet form input {
  flex: 1;
  border: 0;
  border-radius: 20px;
  background: #eee;
  padding: 10px;
}
.comments-sheet form button {
  border: 0;
  border-radius: 50%;
  background: #0a84ff;
  color: #fff;
  width: 36px;
}
.comments-sheet form svg {
  width: 16px;
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
.feedback {
  position: absolute !important;
  z-index: 90;
  left: 50%;
  bottom: 65px;
  transform: translateX(-50%);
  padding: 8px 13px !important;
  border-radius: 18px !important;
  white-space: nowrap;
  font-size: 10px;
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
.compose-body textarea,
.form-card textarea {
  border: 1px solid #3a3a3c;
  background: #1c1c1e;
  color: #f5f5f7;
  outline: none;
}
.compose-body textarea::placeholder,
.form-card textarea::placeholder,
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
.form-card {
  border: 1px solid #2c2c2e;
  background: #1c1c1e;
}
.form-card label {
  border-color: #2c2c2e;
  color: #a1a1a6;
}
.form-card input,
.form-card select,
.form-card textarea {
  color: #f5f5f7;
  background: transparent;
}
.nav-button {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: #0a84ff;
  background: #1c1c1e;
}
.done-button {
  font-weight: 650;
}
.fliptok-sheet {
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
.comments-sheet header button {
  display: grid;
  place-items: center;
  color: #f5f5f7;
  background: #2c2c2e;
}
.comments-list p span {
  margin-top: 3px;
  color: #d1d1d6;
}
.comments-sheet form {
  padding-bottom: 4px;
}
.comments-sheet form input {
  border: 1px solid #3a3a3c;
  color: #f5f5f7;
  background: #2c2c2e;
  outline: none;
}
.comments-sheet form input::placeholder {
  color: #8e8e93;
}
.comments-sheet form button {
  display: grid;
  place-items: center;
  background: #0a84ff;
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
.action-sheet :deep(.k-button),
.selection-sheet :deep(.k-button) {
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
.feedback {
  color: #fff !important;
  background: rgba(44, 44, 46, 0.94) !important;
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
.profile-select {
  display: flex;
  align-items: center;
  box-sizing: border-box;
  width: 100%;
  min-height: 58px;
  padding: 10px 11px;
  border: 0;
  border-bottom: 1px solid #2c2c2e;
  color: #f5f5f7;
  background: #1c1c1e;
  text-align: left;
}
.profile-select span {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4px;
}
.profile-select small {
  color: #a1a1a6;
  font-size: 10px;
}
.profile-select strong {
  font-size: 13px;
  font-weight: 500;
}
.profile-select svg {
  width: 16px;
  color: #8e8e93;
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
.reaction-pop--like {
  color: #ff2d55 !important;
}
.reaction-pop--save {
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
</style>
