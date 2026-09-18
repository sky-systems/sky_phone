<script setup lang="ts">
import {
  SkyBlock,
  SkyBlockTitle,
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyDropdown,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyNavbar,
  SkyAppPage,
  SkyPillNavigation,
  SkySegmented,
  SkySegmentedButton,
  SkySpinner,
  SkyRange,
  SkySearchbar,
  SkySheet,
  SkyNotification,
} from '@/ui'
import {
  Check,
  CirclePlus,
  Ellipsis,
  ExternalLink,
  Library,
  ListMusic,
  Music2,
  Pause,
  Play,
  Plus,
  Search,
  Share2,
  SkipBack,
  SkipForward,
  Volume1,
  Volume2,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import playlistPlaceholder from '@/assets/img/music/playlist-placeholder.jpg'
import { useMusicStore } from '@/stores/music'
import { useEasyShareStore } from '@/stores/easyshare'
import { usePhoneStore } from '@/stores/phone'
import type { MusicPlaylist, MusicTrack } from '@/types/music'
import { easyShareMusicTarget } from '@/utils/easyshare'
import { consumeEscape, handleEnterAction } from '@/utils/keyboard'
import { musicEscapeLayer } from '@/utils/musicEscape'

type MusicTab = 'library' | 'playlists' | 'search'
type MusicSheet =
  | 'playlist'
  | 'playlist-picker'
  | 'rename'
  | 'track-picker'
  | 'youtube'
type MusicMenuAction =
  | 'add-songs'
  | 'add-to-playlist'
  | 'add-youtube'
  | 'delete-playlist'
  | 'new-playlist'
  | 'remove-from-library'
  | 'remove-from-playlist'
  | 'rename-playlist'
  | 'share-playlist'
  | 'share-track'
type MusicMenuItem = {
  destructive?: boolean
  id: MusicMenuAction
  label: string
  separatorBefore?: boolean
}
type PlaylistArtworkTrack = MusicTrack & { artwork: string }

const MUSIC_SHEET_TRANSITION_MS = 420

const music = useMusicStore()
const easyShare = useEasyShareStore()
const phone = usePhoneStore()
const route = useRoute()
const activeTab = ref<MusicTab>('library')
const tabs = [
  { id: 'library', icon: Library },
  { id: 'playlists', icon: ListMusic },
  { id: 'search', icon: Search },
] as const
const activeTabIndex = computed(() =>
  tabs.findIndex((item) => item.id === activeTab.value),
)
const activePlaylist = ref<MusicPlaylist | null>(null)
const sharedTracks = ref<MusicTrack[]>([])
const sharedPlaylist = ref(false)
function readSharedMusic(): { title: string; tracks: MusicTrack[] } | null {
  if (
    typeof route.query.sharedMusic !== 'string' ||
    route.query.sharedMusic.length > 65536
  )
    return null
  try {
    const data = JSON.parse(route.query.sharedMusic)
    if (!Array.isArray(data.songs) || typeof data.title !== 'string')
      return null
    const tracks: MusicTrack[] = data.songs
      .slice(0, 250)
      .flatMap((item: unknown) => {
        if (!item || typeof item !== 'object') return []
        const song = item as Record<string, unknown>
        if (song.source === 'server')
          return music.serverTracks.filter((track) => track.id === song.song_id)
        if (
          song.source !== 'youtube' ||
          typeof song.video_id !== 'string' ||
          !/^[a-zA-Z0-9_-]{11}$/.test(song.video_id) ||
          typeof song.song_id !== 'string' ||
          typeof song.title !== 'string' ||
          typeof song.artist !== 'string'
        )
          return []
        return [
          {
            id: song.song_id,
            source: 'youtube' as const,
            videoId: song.video_id,
            title: song.title,
            artist: song.artist,
            artwork: `https://i.ytimg.com/vi/${song.video_id}/hqdefault.jpg`,
          },
        ]
      })
    return { title: data.title, tracks }
  } catch {
    return null
  }
}

const addMenuOpened = ref(false)
const actionMenuOpened = ref(false)
const actionTrack = ref<MusicTrack | null>(null)
const menuTarget = ref<HTMLElement | null>(null)
const activeSheet = ref<MusicSheet | null>(null)
const playerOpened = ref(false)
const youtubeUrl = ref('')
const youtubeTitle = ref('')
const youtubeArtist = ref('')
const playlistName = ref('')
const playlistCreationTrack = ref<MusicTrack | null>(null)
const searchQuery = ref('')
const toastText = ref('')
const confirmRemoveTrack = ref(false)
const confirmDeletePlaylist = ref(false)
const scrollEl = ref<HTMLElement | null>(null)
let playerPickerTimer: number | null = null

const allTracks = computed(() => music.allTracks)
const normalizedSearch = computed(() => searchQuery.value.trim().toLowerCase())
const searchResults = computed(() => {
  if (!normalizedSearch.value) return allTracks.value
  return allTracks.value.filter((track) =>
    `${track.title} ${track.artist}`
      .toLowerCase()
      .includes(normalizedSearch.value),
  )
})
const playlistTracks = computed(() =>
  sharedPlaylist.value
    ? sharedTracks.value
    : activePlaylist.value
      ? music.tracksForPlaylist(activePlaylist.value)
      : [],
)
const availablePlaylistTracks = computed(() => {
  const playlist = activePlaylist.value
  if (!playlist) return []
  return allTracks.value.filter((track) => !playlistHasTrack(playlist, track))
})
const recentTracks = computed(() => allTracks.value.slice(0, 6))
const featuredTrack = computed(() => allTracks.value[0] ?? null)
const sheetTitle = computed(() => {
  if (activeSheet.value === 'youtube') return phone.t('Apps.music.addYouTube')
  if (activeSheet.value === 'playlist-picker')
    return phone.t('Apps.music.choosePlaylist')
  if (activeSheet.value === 'track-picker')
    return phone.t('Apps.music.addSongs')
  if (activeSheet.value === 'rename')
    return phone.t('Apps.music.renamePlaylist')
  return phone.t('Apps.music.newPlaylist')
})
const pageTitle = computed(() => {
  if (activePlaylist.value) return activePlaylist.value.name
  return phone.t(`Apps.music.tabs.${activeTab.value}`)
})
const menuLabel = computed(() => {
  if (addMenuOpened.value && activePlaylist.value) {
    return phone.t('Apps.music.playlistActions')
  }
  return phone.t(
    addMenuOpened.value ? 'Apps.music.addMusic' : 'Apps.music.songActions',
  )
})
const menuItems = computed<MusicMenuItem[]>(() => {
  if (addMenuOpened.value) {
    if (activePlaylist.value) {
      return [
        {
          id: 'share-playlist',
          label: phone.t('Apps.easyShare.name'),
        },
        { id: 'add-songs', label: phone.t('Apps.music.addSongs') },
        {
          id: 'rename-playlist',
          label: phone.t('Apps.music.renamePlaylist'),
        },
        {
          destructive: true,
          id: 'delete-playlist',
          label: phone.t('Apps.music.deletePlaylist'),
          separatorBefore: true,
        },
      ]
    }

    return [
      { id: 'add-youtube', label: phone.t('Apps.music.addYouTube') },
      { id: 'new-playlist', label: phone.t('Apps.music.newPlaylist') },
    ]
  }

  if (!actionMenuOpened.value) return []

  const items: MusicMenuItem[] = [
    { id: 'share-track', label: phone.t('Apps.easyShare.name') },
    {
      id: 'add-to-playlist',
      label: phone.t('Apps.music.addToPlaylist'),
    },
  ]
  if (activePlaylist.value) {
    items.push({
      destructive: true,
      id: 'remove-from-playlist',
      label: phone.t('Apps.music.removeFromPlaylist'),
      separatorBefore: true,
    })
  }
  if (actionTrack.value?.source === 'youtube') {
    items.push({
      destructive: true,
      id: 'remove-from-library',
      label: phone.t('Apps.music.removeFromLibrary'),
      separatorBefore: !activePlaylist.value,
    })
  }
  return items
})

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement | null)?.value ?? ''
}

function showToast(path: string): void {
  toastText.value = phone.t(path)
  window.setTimeout(() => {
    if (toastText.value === phone.t(path)) toastText.value = ''
  }, 2200)
}

function errorText(): string {
  return phone.t(`Apps.music.errors.${music.error || 'default'}`)
}

function closeMenus(): void {
  addMenuOpened.value = false
  actionMenuOpened.value = false
}

function dismissMenus(): void {
  closeMenus()
  actionTrack.value = null
}

function openAddMenu(event: MouseEvent): void {
  menuTarget.value = event.currentTarget as HTMLElement
  actionTrack.value = null
  actionMenuOpened.value = false
  addMenuOpened.value = true
}

function openSheet(sheet: MusicSheet): void {
  closeMenus()
  activeSheet.value = sheet
  music.error = ''
  if (sheet === 'youtube') {
    youtubeUrl.value = ''
    youtubeTitle.value = ''
    youtubeArtist.value = ''
  }
  if (sheet === 'playlist') playlistName.value = ''
  if (sheet === 'rename') playlistName.value = activePlaylist.value?.name ?? ''
}

function closeSheet(): void {
  if (music.isLoading) return
  activeSheet.value = null
  music.error = ''
  actionTrack.value = null
  playlistCreationTrack.value = null
}

function openNewPlaylist(track: MusicTrack | null = null): void {
  if (music.isLoading) return
  playlistCreationTrack.value = track
  openSheet('playlist')
}

function openPlaylistPicker(track: MusicTrack | null): void {
  if (!track) return
  actionTrack.value = track
  openSheet('playlist-picker')
}

function openActivePlaylistTrackPicker(): void {
  if (!activePlaylist.value) return
  actionTrack.value = null
  openSheet('track-picker')
}

function openCurrentTrackPlaylistPicker(): void {
  const track = music.currentTrack
  if (!track) return
  playerOpened.value = false
  if (playerPickerTimer !== null) window.clearTimeout(playerPickerTimer)
  playerPickerTimer = window.setTimeout(() => {
    playerPickerTimer = null
    if (!playerOpened.value) openPlaylistPicker(track)
  }, MUSIC_SHEET_TRANSITION_MS)
}

function requestDeletePlaylist(): void {
  closeMenus()
  confirmDeletePlaylist.value = true
}

function requestRemoveTrack(): void {
  closeMenus()
  confirmRemoveTrack.value = true
}

function cancelRemoveTrack(): void {
  confirmRemoveTrack.value = false
  actionTrack.value = null
}

function openTrackMenu(event: MouseEvent, track: MusicTrack): void {
  event.stopPropagation()
  menuTarget.value = event.currentTarget as HTMLElement
  actionTrack.value = track
  addMenuOpened.value = false
  actionMenuOpened.value = true
}

function selectMenuItem(id: string): void {
  switch (id as MusicMenuAction) {
    case 'share-playlist':
      shareActivePlaylist()
      break
    case 'add-songs':
      openActivePlaylistTrackPicker()
      break
    case 'rename-playlist':
      openSheet('rename')
      break
    case 'delete-playlist':
      requestDeletePlaylist()
      break
    case 'add-youtube':
      openSheet('youtube')
      break
    case 'new-playlist':
      openNewPlaylist()
      break
    case 'share-track':
      shareTrack()
      break
    case 'add-to-playlist':
      openPlaylistPicker(actionTrack.value)
      break
    case 'remove-from-playlist':
      void removeFromActivePlaylist()
      break
    case 'remove-from-library':
      requestRemoveTrack()
      break
  }
}

function shareTrack(
  selectedTrack: MusicTrack | null = actionTrack.value,
): void {
  const track = selectedTrack
  if (!track) return
  closeMenus()
  playerOpened.value = false
  easyShare.open({
    appId: 'music',
    copyText: `${track.title} — ${track.artist}`,
    id: track.id,
    imageUrl: track.artwork,
    kind: 'track',
    link: `skyphone://music/${track.source}/${track.id}`,
    meta: { source: track.source },
    subtitle: track.artist,
    title: track.title,
  })
}

function shareActivePlaylist(): void {
  const playlist = activePlaylist.value
  if (!playlist) return
  closeMenus()
  easyShare.open({
    appId: 'music',
    copyText: `${playlist.name} · ${playlist.entries.length}`,
    id: playlist.id,
    imageUrl: playlistArtwork(playlist)[0]?.artwork || playlistPlaceholder,
    kind: 'playlist',
    link: `skyphone://music/playlist/${playlist.id}`,
    subtitle: phone.t('Apps.music.songCount', {
      count: String(playlist.entries.length),
    }),
    title: playlist.name,
  })
}

function openPlaylist(playlist: MusicPlaylist): void {
  activePlaylist.value = playlist
  activeTab.value = 'playlists'
  scrollToTop()
}

function closePlaylist(): void {
  sharedPlaylist.value = false
  sharedTracks.value = []
  activePlaylist.value = null
  scrollToTop()
}

function scrollToTop(): void {
  void nextTick(() => {
    if (scrollEl.value) scrollEl.value.scrollTop = 0
  })
}

function selectTab(tab: MusicTab): void {
  activeTab.value = tab
  activePlaylist.value = null
  scrollToTop()
}

async function playTrack(
  track: MusicTrack,
  queue = allTracks.value,
): Promise<void> {
  await music.play(track, queue)
  if (music.playbackError) showToast('Apps.music.errors.playback_failed')
}

async function playFeatured(): Promise<void> {
  if (featuredTrack.value) await playTrack(featuredTrack.value)
}

async function submitYouTube(): Promise<void> {
  if (!youtubeUrl.value.trim()) return
  if (
    await music.addYouTube(
      youtubeUrl.value.trim(),
      youtubeTitle.value.trim(),
      youtubeArtist.value.trim(),
    )
  ) {
    activeSheet.value = null
    showToast('Apps.music.songAdded')
  }
}

async function submitPlaylist(): Promise<void> {
  if (music.isLoading) return
  const name = playlistName.value.trim()
  if (!name) return
  if (activeSheet.value === 'rename' && activePlaylist.value) {
    if (!(await music.renamePlaylist(activePlaylist.value.id, name))) return
    activePlaylist.value =
      music.playlists.find(
        (playlist) => playlist.id === activePlaylist.value?.id,
      ) ?? null
    showToast('Apps.music.playlistRenamed')
    activeSheet.value = null
    return
  }

  const previousIds = new Set(music.playlists.map((playlist) => playlist.id))
  const pendingTrack = playlistCreationTrack.value
  if (!(await music.createPlaylist(name))) return

  const createdPlaylist = music.playlists.find(
    (playlist) => !previousIds.has(playlist.id),
  )
  if (pendingTrack) {
    playlistCreationTrack.value = null
    if (!createdPlaylist) {
      music.error = 'request_failed'
      activeSheet.value = 'playlist-picker'
      return
    }
    if (!(await music.addToPlaylist(createdPlaylist.id, pendingTrack))) {
      activeSheet.value = 'playlist-picker'
      return
    }
    showToast('Apps.music.playlistCreatedWithSong')
    actionTrack.value = null
  } else {
    showToast('Apps.music.playlistCreated')
  }
  playlistCreationTrack.value = null
  activeSheet.value = null
}

async function addTrackToPlaylist(playlist: MusicPlaylist): Promise<void> {
  const track = actionTrack.value
  if (music.isLoading || !track || playlistHasTrack(playlist, track)) return
  if (await music.addToPlaylist(playlist.id, track)) {
    activeSheet.value = null
    actionTrack.value = null
    showToast('Apps.music.addedToPlaylist')
  }
}

async function addTrackToActivePlaylist(track: MusicTrack): Promise<void> {
  const playlist = activePlaylist.value
  if (music.isLoading || !playlist || playlistHasTrack(playlist, track)) return
  if (await music.addToPlaylist(playlist.id, track)) {
    activePlaylist.value =
      music.playlists.find((candidate) => candidate.id === playlist.id) ?? null
    showToast('Apps.music.addedToPlaylist')
  }
}

async function removeFromActivePlaylist(): Promise<void> {
  if (!activePlaylist.value || !actionTrack.value) return
  const playlistId = activePlaylist.value.id
  if (await music.removeFromPlaylist(playlistId, actionTrack.value)) {
    activePlaylist.value =
      music.playlists.find((playlist) => playlist.id === playlistId) ?? null
    actionMenuOpened.value = false
    actionTrack.value = null
    showToast('Apps.music.removedFromPlaylist')
  }
}

async function removePersonalTrack(): Promise<void> {
  if (!actionTrack.value || actionTrack.value.source !== 'youtube') return
  if (await music.removeYouTube(actionTrack.value.id)) {
    confirmRemoveTrack.value = false
    actionMenuOpened.value = false
    actionTrack.value = null
    showToast('Apps.music.songRemoved')
  }
}

async function deleteActivePlaylist(): Promise<void> {
  if (!activePlaylist.value) return
  if (await music.deletePlaylist(activePlaylist.value.id)) {
    confirmDeletePlaylist.value = false
    activePlaylist.value = null
    showToast('Apps.music.playlistDeleted')
  }
}

function hasPlaylistArtwork(track: MusicTrack): track is PlaylistArtworkTrack {
  return typeof track.artwork === 'string' && track.artwork.trim().length > 0
}

function playlistArtwork(playlist: MusicPlaylist): PlaylistArtworkTrack[] {
  return music
    .tracksForPlaylist(playlist)
    .filter(hasPlaylistArtwork)
    .slice(0, 4)
}

function playlistHasTrack(playlist: MusicPlaylist, track: MusicTrack): boolean {
  return playlist.entries.some(
    (entry) => entry.source === track.source && entry.songId === track.id,
  )
}

function actionTrackIsInPlaylist(playlist: MusicPlaylist): boolean {
  return Boolean(
    actionTrack.value && playlistHasTrack(playlist, actionTrack.value),
  )
}

function fallbackArtwork(
  track: Pick<MusicTrack, 'id'>,
): Record<string, string> {
  let hash = 0
  for (const character of track.id)
    hash = (hash * 31 + character.charCodeAt(0)) | 0
  const hue = Math.abs(hash) % 360
  return {
    background: `linear-gradient(145deg, hsl(${hue} 78% 62%), hsl(${(hue + 58) % 360} 72% 38%))`,
  }
}

function hideBrokenArtwork(event: Event): void {
  const image = event.currentTarget as HTMLImageElement
  image.style.display = 'none'
}

function usePlaylistPlaceholder(event: Event): void {
  const image = event.currentTarget as HTMLImageElement
  if (image.dataset.playlistFallback === 'true') {
    image.style.display = 'none'
    return
  }
  image.dataset.playlistFallback = 'true'
  image.src = playlistPlaceholder
}

function formatTime(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '0:00'
  const minutes = Math.floor(seconds / 60)
  return `${minutes}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`
}

function updateSeek(event: Event): void {
  music.seek(Number(eventValue(event)))
}

function updateVolume(event: Event): void {
  music.setVolume(Number(eventValue(event)) / 100)
}

function onKeydown(event: KeyboardEvent): void {
  const layer = musicEscapeLayer({
    actionMenuOpened: actionMenuOpened.value,
    activeSheet: Boolean(activeSheet.value),
    addMenuOpened: addMenuOpened.value,
    confirmDeletePlaylist: confirmDeletePlaylist.value,
    confirmRemoveTrack: confirmRemoveTrack.value,
    playerOpened: playerOpened.value,
  })
  if (!layer) return
  if (!consumeEscape(event)) return

  if (layer === 'remove-track-confirmation') {
    cancelRemoveTrack()
  } else if (layer === 'delete-playlist-confirmation') {
    confirmDeletePlaylist.value = false
  } else if (layer === 'sheet') {
    closeSheet()
  } else if (layer === 'menu') {
    dismissMenus()
  } else if (layer === 'player') {
    playerOpened.value = false
  }
}

watch(
  () => music.playlists,
  () => {
    if (!activePlaylist.value || sharedPlaylist.value) return
    activePlaylist.value =
      music.playlists.find(
        (playlist) => playlist.id === activePlaylist.value?.id,
      ) ?? null
  },
)

onMounted(async () => {
  window.addEventListener('keydown', onKeydown, true)
  await music.load()
  const target = easyShareMusicTarget(
    route.query.easyShareKind,
    route.query.easyShareLink,
  )
  if (!target) return
  if (target.kind === 'playlist') {
    const playlist = music.playlists.find((entry) => entry.id === target.id)
    if (playlist) openPlaylist(playlist)
    else {
      const shared = readSharedMusic()
      if (shared) {
        sharedTracks.value = shared.tracks
        sharedPlaylist.value = true
        openPlaylist({
          id: target.id,
          name: shared.title,
          createdAt: 0,
          entries: shared.tracks.map((track) => ({
            source: track.source,
            songId: track.id,
          })),
        })
      }
    }
    return
  }
  const track =
    music.allTracks.find(
      (entry) => entry.id === target.id && entry.source === target.source,
    ) ??
    readSharedMusic()?.tracks.find(
      (entry) => entry.id === target.id && entry.source === target.source,
    )
  if (!track) return
  await playTrack(track, [track])
  playerOpened.value = true
})

onBeforeUnmount(() => {
  if (playerPickerTimer !== null) window.clearTimeout(playerPickerTimer)
  window.removeEventListener('keydown', onKeydown, true)
})
</script>

<template>
  <sky-app-page
    component="main"
    class="music-app sky-ui-provider"
    :class="{
      'music-app--playlist': activePlaylist,
      'music-app--playing': music.currentTrack,
      'sky-ui-provider--dark': phone.isDarkMode,
    }"
  >
    <sky-navbar
      component="nav"
      class="music-navbar"
      title-class="music-navbar-title"
      :title="activePlaylist ? activePlaylist.name : phone.t('Apps.music.name')"
      :show-back="Boolean(activePlaylist)"
      back-appearance="surface"
      :back-label="phone.t('Apps.music.tabs.playlists')"
      @back="closePlaylist"
    >
      <template #right>
        <sky-link
          v-if="activePlaylist && !sharedPlaylist"
          component="button"
          icon-only
          :aria-label="phone.t('Apps.music.playlistActions')"
          aria-haspopup="menu"
          :aria-expanded="addMenuOpened"
          @click="openAddMenu"
        >
          <Ellipsis :size="22" />
        </sky-link>
        <sky-link
          v-else-if="!sharedPlaylist"
          component="button"
          icon-only
          :aria-label="phone.t('Apps.music.addMusic')"
          aria-haspopup="menu"
          :aria-expanded="addMenuOpened"
          @click="openAddMenu"
        >
          <Plus :size="24" />
        </sky-link>
      </template>
    </sky-navbar>

    <div ref="scrollEl" class="music-scroll">
      <div
        v-if="music.isLoading && !allTracks.length && !music.playlists.length"
        class="music-loading"
      >
        <sky-spinner />
        <span>{{ phone.t('Apps.music.loading') }}</span>
      </div>

      <template v-else-if="activePlaylist">
        <section class="music-playlist-hero">
          <div class="music-playlist-art">
            <template v-if="playlistArtwork(activePlaylist).length">
              <div
                v-for="track in playlistArtwork(activePlaylist)"
                :key="`${track.source}:${track.id}`"
                :style="fallbackArtwork(track)"
              >
                <img
                  :src="track.artwork"
                  alt=""
                  @error="usePlaylistPlaceholder"
                />
              </div>
            </template>
            <span v-else class="music-playlist-placeholder">
              <img :src="playlistPlaceholder" alt="" />
            </span>
          </div>
          <h1>{{ activePlaylist.name }}</h1>
          <p>
            {{
              phone.t('Apps.music.songCount', {
                count: String(playlistTracks.length),
              })
            }}
          </p>
          <div class="music-playlist-actions">
            <sky-button
              large
              rounded
              :disabled="!playlistTracks.length"
              @click="
                playlistTracks[0] &&
                playTrack(playlistTracks[0], playlistTracks)
              "
            >
              <Play :size="18" fill="currentColor" />
              {{ phone.t('Apps.music.play') }}
            </sky-button>
            <sky-button
              large
              rounded
              tonal
              v-if="!sharedPlaylist"
              @click="openActivePlaylistTrackPicker"
            >
              <CirclePlus :size="18" />
              {{ phone.t('Apps.music.addSongs') }}
            </sky-button>
          </div>
        </section>

        <sky-list v-if="playlistTracks.length" nested class="music-track-list">
          <sky-list-item
            v-for="track in playlistTracks"
            :key="`${track.source}:${track.id}`"
            link
            :chevron="false"
            :title="track.title"
            :subtitle="track.artist"
            @click="playTrack(track, playlistTracks)"
          >
            <template #media>
              <span class="music-row-art" :style="fallbackArtwork(track)">
                <img
                  v-if="track.artwork"
                  :src="track.artwork"
                  alt=""
                  @error="hideBrokenArtwork"
                />
                <Music2 v-else :size="20" />
              </span>
            </template>
            <template #after>
              <sky-link
                v-if="!sharedPlaylist"
                component="button"
                icon-only
                :aria-label="phone.t('Apps.music.songActions')"
                aria-haspopup="menu"
                :aria-expanded="
                  actionMenuOpened &&
                  actionTrack?.id === track.id &&
                  actionTrack?.source === track.source
                "
                @click="openTrackMenu($event, track)"
              >
                <Ellipsis :size="20" />
              </sky-link>
            </template>
          </sky-list-item>
        </sky-list>
        <sky-block v-else class="music-empty" inset>
          <ListMusic :size="43" />
          <strong>{{ phone.t('Apps.music.emptyPlaylist') }}</strong>
          <span>{{ phone.t('Apps.music.emptyPlaylistBody') }}</span>
        </sky-block>
      </template>

      <template v-else-if="activeTab === 'library'">
        <header class="music-large-title">
          <h1>{{ pageTitle }}</h1>
          <p>{{ phone.t('Apps.music.librarySubtitle') }}</p>
        </header>

        <sky-glass
          v-if="featuredTrack"
          class="music-featured"
          :highlight="false"
        >
          <button type="button" @click="playFeatured">
            <div class="music-featured-copy">
              <small>{{ phone.t('Apps.music.featured') }}</small>
              <h2>{{ featuredTrack.title }}</h2>
              <p>{{ featuredTrack.artist }}</p>
              <span
                ><Play :size="16" fill="currentColor" />
                {{ phone.t('Apps.music.play') }}</span
              >
            </div>
            <div
              class="music-featured-art"
              :style="fallbackArtwork(featuredTrack)"
            >
              <img
                v-if="featuredTrack.artwork"
                :src="featuredTrack.artwork"
                alt=""
                @error="hideBrokenArtwork"
              />
              <Music2 v-else :size="52" />
            </div>
          </button>
        </sky-glass>

        <template v-if="recentTracks.length">
          <sky-block-title class="music-section-title">{{
            phone.t('Apps.music.recentlyAdded')
          }}</sky-block-title>
          <section class="music-album-grid">
            <button
              v-for="track in recentTracks"
              :key="`${track.source}:${track.id}`"
              type="button"
              @click="playTrack(track)"
            >
              <span class="music-album-art" :style="fallbackArtwork(track)">
                <img
                  v-if="track.artwork"
                  :src="track.artwork"
                  alt=""
                  @error="hideBrokenArtwork"
                />
                <Music2 v-else :size="40" />
              </span>
              <strong>{{ track.title }}</strong>
              <small>{{ track.artist }}</small>
            </button>
          </section>

          <sky-block-title class="music-section-title">{{
            phone.t('Apps.music.songs')
          }}</sky-block-title>
          <sky-list nested class="music-track-list">
            <sky-list-item
              v-for="track in allTracks"
              :key="`${track.source}:${track.id}`"
              link
              :chevron="false"
              :title="track.title"
              :subtitle="track.artist"
              @click="playTrack(track)"
            >
              <template #media>
                <span class="music-row-art" :style="fallbackArtwork(track)">
                  <img
                    v-if="track.artwork"
                    :src="track.artwork"
                    alt=""
                    @error="hideBrokenArtwork"
                  />
                  <Music2 v-else :size="20" />
                </span>
              </template>
              <template #after>
                <sky-link
                  component="button"
                  icon-only
                  :aria-label="phone.t('Apps.music.songActions')"
                  aria-haspopup="menu"
                  :aria-expanded="
                    actionMenuOpened &&
                    actionTrack?.id === track.id &&
                    actionTrack?.source === track.source
                  "
                  @click="openTrackMenu($event, track)"
                >
                  <Ellipsis :size="20" />
                </sky-link>
              </template>
            </sky-list-item>
          </sky-list>
        </template>
        <sky-block v-else class="music-empty music-empty--library" inset>
          <Music2 :size="48" />
          <strong>{{ phone.t('Apps.music.emptyLibrary') }}</strong>
          <span>{{ phone.t('Apps.music.emptyLibraryBody') }}</span>
          <sky-button rounded @click="openSheet('youtube')">
            <ExternalLink :size="17" />
            {{ phone.t('Apps.music.addYouTube') }}
          </sky-button>
        </sky-block>
      </template>

      <template v-else-if="activeTab === 'playlists'">
        <header class="music-large-title">
          <h1>{{ pageTitle }}</h1>
          <p>{{ phone.t('Apps.music.playlistsSubtitle') }}</p>
        </header>
        <section v-if="music.playlists.length" class="music-playlist-grid">
          <button
            v-for="playlist in music.playlists"
            :key="playlist.id"
            type="button"
            @click="openPlaylist(playlist)"
          >
            <span class="music-playlist-tile">
              <template v-if="playlistArtwork(playlist).length">
                <i
                  v-for="track in playlistArtwork(playlist)"
                  :key="`${track.source}:${track.id}`"
                  :style="fallbackArtwork(track)"
                >
                  <img
                    :src="track.artwork"
                    alt=""
                    @error="usePlaylistPlaceholder"
                  />
                </i>
              </template>
              <span v-else class="music-playlist-placeholder">
                <img :src="playlistPlaceholder" alt="" />
              </span>
            </span>
            <strong>{{ playlist.name }}</strong>
            <small>
              {{
                phone.t('Apps.music.songCount', {
                  count: String(playlist.entries.length),
                })
              }}
            </small>
          </button>
        </section>
        <sky-block v-else class="music-empty music-empty--library" inset>
          <ListMusic :size="48" />
          <strong>{{ phone.t('Apps.music.noPlaylists') }}</strong>
          <span>{{ phone.t('Apps.music.noPlaylistsBody') }}</span>
          <sky-button rounded @click="openNewPlaylist()">
            <Plus :size="17" />
            {{ phone.t('Apps.music.newPlaylist') }}
          </sky-button>
        </sky-block>
      </template>

      <template v-else>
        <header class="music-large-title music-large-title--search">
          <h1>{{ pageTitle }}</h1>
        </header>
        <sky-searchbar
          class="music-searchbar"
          :value="searchQuery"
          :placeholder="phone.t('Apps.music.searchPlaceholder')"
          @input="searchQuery = eventValue($event)"
          @clear="searchQuery = ''"
        />
        <sky-list v-if="searchResults.length" nested class="music-track-list">
          <sky-list-item
            v-for="track in searchResults"
            :key="`${track.source}:${track.id}`"
            link
            :chevron="false"
            :title="track.title"
            :subtitle="track.artist"
            @click="playTrack(track, searchResults)"
          >
            <template #media>
              <span class="music-row-art" :style="fallbackArtwork(track)">
                <img
                  v-if="track.artwork"
                  :src="track.artwork"
                  alt=""
                  @error="hideBrokenArtwork"
                />
                <Music2 v-else :size="20" />
              </span>
            </template>
            <template #after>
              <sky-link
                component="button"
                icon-only
                :aria-label="phone.t('Apps.music.songActions')"
                aria-haspopup="menu"
                :aria-expanded="
                  actionMenuOpened &&
                  actionTrack?.id === track.id &&
                  actionTrack?.source === track.source
                "
                @click="openTrackMenu($event, track)"
              >
                <Ellipsis :size="20" />
              </sky-link>
            </template>
          </sky-list-item>
        </sky-list>
        <sky-block v-else class="music-empty" inset>
          <Search :size="42" />
          <strong>{{ phone.t('Apps.music.noResults') }}</strong>
          <span>{{ phone.t('Apps.music.noResultsBody') }}</span>
        </sky-block>
      </template>
    </div>

    <sky-glass
      v-if="music.currentTrack"
      class="music-mini-player"
      :highlight="false"
      @click="playerOpened = true"
    >
      <span class="music-mini-art" :style="fallbackArtwork(music.currentTrack)">
        <img
          v-if="music.currentTrack.artwork"
          :src="music.currentTrack.artwork"
          alt=""
          @error="hideBrokenArtwork"
        />
        <Music2 v-else :size="19" />
      </span>
      <span class="music-mini-copy">
        <strong>{{ music.currentTrack.title }}</strong>
        <small>{{ music.currentTrack.artist }}</small>
      </span>
      <button
        type="button"
        :aria-label="
          phone.t(music.isPlaying ? 'Common.pause' : 'Apps.music.play')
        "
        @click.stop="music.toggle"
      >
        <Pause v-if="music.isPlaying" :size="23" fill="currentColor" />
        <Play v-else :size="23" fill="currentColor" />
      </button>
      <button
        type="button"
        :aria-label="phone.t('Apps.music.next')"
        @click.stop="music.next"
      >
        <SkipForward :size="23" fill="currentColor" />
      </button>
    </sky-glass>

    <SkyPillNavigation
      v-if="!activePlaylist"
      class="music-navigation"
      layout="full"
      :label="phone.t('Apps.music.navigation')"
    >
      <SkySegmented
        strong
        rounded
        navigation
        :active-index="activeTabIndex"
        :aria-label="phone.t('Apps.music.navigation')"
        :data-active-tab="activeTab"
        :item-count="tabs.length"
      >
        <SkySegmentedButton
          v-for="item in tabs"
          :key="item.id"
          :active="activeTab === item.id"
          :aria-label="phone.t(`Apps.music.tabs.${item.id}`)"
          type="button"
          @click="selectTab(item.id)"
        >
          <span class="music-navigation__item">
            <component
              :is="item.icon"
              :size="20"
              :stroke-width="2"
              aria-hidden="true"
            />
            <span>{{ phone.t(`Apps.music.tabs.${item.id}`) }}</span>
          </span>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>

    <SkyDropdown
      :items="menuItems"
      :label="menuLabel"
      :opened="addMenuOpened || actionMenuOpened"
      :target="menuTarget"
      @backdropclick="dismissMenus"
      @escape="dismissMenus"
      @positionerror="dismissMenus"
      @select="selectMenuItem"
    />

    <div class="music-form-sheet">
      <sky-sheet :opened="Boolean(activeSheet)" @backdropclick="closeSheet">
        <section class="music-sheet-content">
          <header>
            <sky-link component="button" @click="closeSheet">{{
              phone.t(
                activeSheet === 'track-picker'
                  ? 'Common.done'
                  : 'Common.cancel',
              )
            }}</sky-link>
            <strong>{{ sheetTitle }}</strong>
            <span />
          </header>

          <template v-if="activeSheet === 'youtube'">
            <div class="music-sheet-icon"><ExternalLink :size="28" /></div>
            <p>{{ phone.t('Apps.music.youtubeBody') }}</p>
            <sky-list inset strong>
              <sky-field
                :label="phone.t('Apps.music.youtubeUrl')"
                input-id="music-youtube-url"
                inputmode="url"
                :placeholder="phone.t('Apps.music.youtubePlaceholder')"
                type="url"
                :value="youtubeUrl"
                @input="youtubeUrl = eventValue($event)"
                @keydown.enter="handleEnterAction($event, submitYouTube)"
              />
              <sky-field
                :label="phone.t('Apps.music.youtubeTitle')"
                input-id="music-youtube-title"
                maxlength="160"
                :placeholder="phone.t('Apps.music.youtubeTitlePlaceholder')"
                :value="youtubeTitle"
                @input="youtubeTitle = eventValue($event)"
                @keydown.enter="handleEnterAction($event, submitYouTube)"
              />
              <sky-field
                :label="phone.t('Apps.music.youtubeArtist')"
                input-id="music-youtube-artist"
                maxlength="120"
                :placeholder="phone.t('Apps.music.youtubeArtistPlaceholder')"
                :value="youtubeArtist"
                @input="youtubeArtist = eventValue($event)"
                @keydown.enter="handleEnterAction($event, submitYouTube)"
              />
            </sky-list>
            <p v-if="music.error" class="music-form-error" role="alert">
              {{ errorText() }}
            </p>
            <sky-button
              large
              rounded
              :disabled="music.isLoading || !youtubeUrl.trim()"
              @click="submitYouTube"
            >
              <sky-spinner v-if="music.isLoading" />
              <template v-else>{{
                phone.t('Apps.music.addToLibrary')
              }}</template>
            </sky-button>
          </template>

          <template v-else-if="activeSheet === 'playlist-picker'">
            <sky-list
              v-if="music.playlists.length"
              inset
              strong
              class="music-picker-list"
            >
              <sky-list-item
                v-for="playlist in music.playlists"
                :key="playlist.id"
                :link="!actionTrackIsInPlaylist(playlist)"
                link-component="button"
                :chevron="false"
                :link-props="{
                  type: 'button',
                  disabled:
                    music.isLoading || actionTrackIsInPlaylist(playlist),
                }"
                :title="playlist.name"
                :subtitle="
                  phone.t('Apps.music.songCount', {
                    count: String(playlist.entries.length),
                  })
                "
                @click="addTrackToPlaylist(playlist)"
              >
                <template #media><ListMusic :size="22" /></template>
                <template #after>
                  <span
                    v-if="actionTrackIsInPlaylist(playlist)"
                    class="music-picker-added"
                  >
                    <Check :size="16" />
                    {{ phone.t('Apps.music.alreadyAdded') }}
                  </span>
                  <CirclePlus v-else :size="19" />
                </template>
              </sky-list-item>
            </sky-list>
            <sky-button
              v-if="music.playlists.length"
              rounded
              tonal
              class="music-picker-create"
              :disabled="music.isLoading"
              @click="openNewPlaylist(actionTrack)"
            >
              <Plus :size="17" /> {{ phone.t('Apps.music.newPlaylist') }}
            </sky-button>
            <sky-block v-else class="music-empty" inset>
              <ListMusic :size="42" />
              <strong>{{ phone.t('Apps.music.noPlaylists') }}</strong>
              <span>{{ phone.t('Apps.music.createPlaylistFirst') }}</span>
              <sky-button
                rounded
                :disabled="music.isLoading"
                @click="openNewPlaylist(actionTrack)"
                >{{ phone.t('Apps.music.newPlaylist') }}</sky-button
              >
            </sky-block>
            <p v-if="music.error" class="music-form-error" role="alert">
              {{ errorText() }}
            </p>
          </template>

          <template v-else-if="activeSheet === 'track-picker'">
            <p>{{ phone.t('Apps.music.addSongsBody') }}</p>
            <sky-list
              v-if="availablePlaylistTracks.length"
              inset
              strong
              class="music-picker-list"
            >
              <sky-list-item
                v-for="track in availablePlaylistTracks"
                :key="`${track.source}:${track.id}`"
                link
                link-component="button"
                :chevron="false"
                :link-props="{ type: 'button', disabled: music.isLoading }"
                :title="track.title"
                :subtitle="track.artist"
                @click="addTrackToActivePlaylist(track)"
              >
                <template #media>
                  <span class="music-row-art" :style="fallbackArtwork(track)">
                    <img
                      v-if="track.artwork"
                      :src="track.artwork"
                      alt=""
                      @error="hideBrokenArtwork"
                    />
                    <Music2 v-else :size="20" />
                  </span>
                </template>
                <template #after><CirclePlus :size="20" /></template>
              </sky-list-item>
            </sky-list>
            <sky-block v-else class="music-empty" inset>
              <Check v-if="allTracks.length" :size="42" />
              <Music2 v-else :size="42" />
              <strong>{{
                phone.t(
                  allTracks.length
                    ? 'Apps.music.allSongsAdded'
                    : 'Apps.music.emptyLibrary',
                )
              }}</strong>
              <span>{{
                phone.t(
                  allTracks.length
                    ? 'Apps.music.allSongsAddedBody'
                    : 'Apps.music.emptyLibraryBody',
                )
              }}</span>
            </sky-block>
            <p v-if="music.error" class="music-form-error" role="alert">
              {{ errorText() }}
            </p>
          </template>

          <template v-else>
            <div class="music-sheet-icon"><ListMusic :size="29" /></div>
            <p>{{ phone.t('Apps.music.playlistBody') }}</p>
            <sky-list inset strong>
              <sky-field
                :label="phone.t('Apps.music.playlistName')"
                input-id="music-playlist-name"
                maxlength="80"
                :disabled="music.isLoading"
                :placeholder="phone.t('Apps.music.playlistPlaceholder')"
                :value="playlistName"
                @input="playlistName = eventValue($event)"
                @keydown.enter="handleEnterAction($event, submitPlaylist)"
              />
            </sky-list>
            <p v-if="music.error" class="music-form-error" role="alert">
              {{ errorText() }}
            </p>
            <sky-button
              large
              rounded
              :disabled="music.isLoading || !playlistName.trim()"
              @click="submitPlaylist"
            >
              <sky-spinner v-if="music.isLoading" />
              <template v-else>{{ phone.t('Common.save') }}</template>
            </sky-button>
          </template>
        </section>
      </sky-sheet>
    </div>

    <div class="music-player-sheet">
      <sky-sheet :opened="playerOpened" @backdropclick="playerOpened = false">
        <section v-if="music.currentTrack" class="music-player">
          <header>
            <sky-link
              component="button"
              icon-only
              :aria-label="phone.t('Common.close')"
              @click="playerOpened = false"
            >
              <X :size="20" />
            </sky-link>
            <span>{{ phone.t('Apps.music.nowPlaying') }}</span>
            <div class="music-player-header-actions">
              <sky-link
                component="button"
                icon-only
                :aria-label="phone.t('Apps.easyShare.share')"
                @click="shareTrack(music.currentTrack)"
              >
                <Share2 :size="20" />
              </sky-link>
              <sky-link
                component="button"
                icon-only
                :aria-label="phone.t('Apps.music.addToPlaylist')"
                @click="openCurrentTrackPlaylistPicker"
              >
                <CirclePlus :size="21" />
              </sky-link>
            </div>
          </header>
          <div
            class="music-player-art"
            :style="fallbackArtwork(music.currentTrack)"
          >
            <img
              v-if="music.currentTrack.artwork"
              :src="music.currentTrack.artwork"
              :alt="music.currentTrack.title"
              @error="hideBrokenArtwork"
            />
            <Music2 v-else :size="86" />
          </div>
          <div class="music-player-copy">
            <strong>{{ music.currentTrack.title }}</strong>
            <span>{{ music.currentTrack.artist }}</span>
          </div>
          <div class="music-progress">
            <sky-range
              :value="music.currentTime"
              :min="0"
              :max="Math.max(1, music.duration)"
              :aria-label="phone.t('Apps.music.progress')"
              @input="updateSeek"
            />
            <div>
              <span>{{ formatTime(music.currentTime) }}</span
              ><span
                >-{{
                  formatTime(Math.max(0, music.duration - music.currentTime))
                }}</span
              >
            </div>
          </div>
          <div class="music-player-controls">
            <button
              type="button"
              :aria-label="phone.t('Apps.music.previous')"
              @click="music.previous"
            >
              <SkipBack :size="38" fill="currentColor" />
            </button>
            <button
              type="button"
              :aria-label="
                phone.t(music.isPlaying ? 'Common.pause' : 'Apps.music.play')
              "
              @click="music.toggle"
            >
              <Pause v-if="music.isPlaying" :size="50" fill="currentColor" />
              <Play v-else :size="50" fill="currentColor" />
            </button>
            <button
              type="button"
              :aria-label="phone.t('Apps.music.next')"
              @click="music.next"
            >
              <SkipForward :size="38" fill="currentColor" />
            </button>
          </div>
          <div class="music-volume">
            <Volume1 :size="18" />
            <sky-range
              :value="Math.round(music.volume * 100)"
              :min="0"
              :max="100"
              :aria-label="phone.t('Apps.music.volume')"
              @input="updateVolume"
            />
            <Volume2 :size="20" />
          </div>
          <p v-if="music.playbackError" class="music-player-error">
            {{ phone.t('Apps.music.errors.playback_failed') }}
          </p>
        </section>
      </sky-sheet>
    </div>

    <sky-dialog
      :opened="confirmRemoveTrack"
      :title="phone.t('Apps.music.removeSongTitle')"
      :content="phone.t('Apps.music.removeSongBody')"
      @backdropclick="cancelRemoveTrack"
    >
      <template #buttons>
        <sky-dialog-button @click="cancelRemoveTrack">{{
          phone.t('Common.cancel')
        }}</sky-dialog-button>
        <sky-dialog-button strong @click="removePersonalTrack">{{
          phone.t('Common.delete')
        }}</sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-dialog
      :opened="confirmDeletePlaylist"
      :title="phone.t('Apps.music.deletePlaylistTitle')"
      :content="phone.t('Apps.music.deletePlaylistBody')"
      @backdropclick="confirmDeletePlaylist = false"
    >
      <template #buttons>
        <sky-dialog-button @click="confirmDeletePlaylist = false">{{
          phone.t('Common.cancel')
        }}</sky-dialog-button>
        <sky-dialog-button strong @click="deleteActivePlaylist">{{
          phone.t('Common.delete')
        }}</sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-notification :opened="Boolean(toastText)" :text="toastText" />
  </sky-app-page>
</template>

<style scoped>
.music-app {
  --music-accent: #fa2d48;
  --music-mini-player-bottom: calc(
    var(--sky-safe-area-bottom) + var(--sky-tabbar-height) + var(--sky-space-2)
  );
  --music-mini-player-height: 58px;
  --sky-app-accent: var(--music-accent);
  --music-bg: #f7f7fa;
  --music-card: rgb(255 255 255 / 88%);
  --music-label: #111114;
  --music-muted: #74747c;
  --music-line: rgb(18 18 23 / 9%);
  position: relative;
  display: flex !important;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  isolation: isolate;
  background: var(--music-bg);
  color: var(--music-label);
}

:global(.dark .music-app) {
  --music-bg: #09090b;
  --music-card: rgb(31 31 35 / 88%);
  --music-label: #f7f7f8;
  --music-muted: #9b9ba2;
  --music-line: rgb(255 255 255 / 10%);
}

.music-navbar {
  z-index: 30;
  flex: 0 0 auto;
}

.music-navbar :deep(.music-navbar-title) {
  max-width: 150px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.music-scroll {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
  padding: 8px 0
    calc(
      var(--sky-safe-area-bottom) + var(--sky-tabbar-height) +
        var(--sky-space-3)
    );
  overflow-y: auto;
  overflow-x: hidden;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.music-app--playing .music-scroll {
  padding-bottom: calc(
    var(--music-mini-player-bottom) + var(--music-mini-player-height) +
      var(--sky-space-3)
  );
}

.music-app--playlist .music-scroll {
  padding-bottom: 42px;
}

.music-app--playlist.music-app--playing .music-scroll {
  padding-bottom: 100px;
}

.music-scroll::-webkit-scrollbar {
  display: none;
}

.music-loading,
.music-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--music-muted);
  text-align: center;
}

.music-loading {
  min-height: 330px;
  font-size: 13px;
}

.music-empty {
  min-height: 230px;
  padding: 28px;
}

.music-empty--library {
  min-height: 410px;
}

.music-empty strong {
  color: var(--music-label);
  font-size: 18px;
}

.music-empty span {
  max-width: 260px;
  font-size: 13px;
  line-height: 1.45;
}

.music-empty :deep(button) {
  margin-top: 8px;
}

.music-large-title {
  padding: 10px 18px 16px;
}

.music-large-title h1 {
  margin: 0;
  font-size: 34px;
  font-weight: 780;
  letter-spacing: -1.2px;
}

.music-large-title p {
  margin: 4px 0 0;
  color: var(--music-muted);
  font-size: 13px;
}

.music-section-title {
  min-height: 24px;
  margin: 28px 14px 12px !important;
  padding: 0 !important;
  line-height: 24px;
}

.music-featured {
  margin: 0 14px 6px;
  border-radius: 24px;
  overflow: hidden;
}

.music-featured > button {
  width: 100%;
  min-height: 174px;
  padding: 18px;
  display: grid;
  grid-template-columns: minmax(0, 1fr) 132px;
  align-items: center;
  gap: 13px;
  background: transparent;
  color: inherit;
  text-align: left;
}

.music-featured-copy {
  min-width: 0;
}

.music-featured-copy small {
  color: var(--music-accent);
  font-size: 10px;
  font-weight: 750;
  letter-spacing: 0.65px;
  text-transform: uppercase;
}

.music-featured-copy h2 {
  margin: 7px 0 2px;
  display: -webkit-box;
  overflow: hidden;
  font-size: 24px;
  line-height: 1.05;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.music-featured-copy p {
  margin: 0;
  overflow: hidden;
  color: var(--music-muted);
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-featured-copy span {
  margin-top: 18px;
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--music-accent);
  font-size: 13px;
  font-weight: 700;
}

.music-featured-art,
.music-album-art,
.music-row-art,
.music-mini-art,
.music-player-art {
  position: relative;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: rgb(255 255 255 / 90%);
  box-shadow: 0 12px 28px rgb(0 0 0 / 22%);
}

.music-featured-art {
  width: 132px;
  aspect-ratio: 1;
  border-radius: 18px;
}

.music-featured-art img,
.music-album-art img,
.music-row-art img,
.music-mini-art img,
.music-player-art img,
.music-playlist-tile img,
.music-playlist-art img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.music-album-grid,
.music-playlist-grid {
  padding: 0 14px 12px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px 12px;
}

.music-album-grid button,
.music-playlist-grid > button {
  min-width: 0;
  padding: 0;
  background: transparent;
  color: inherit;
  text-align: left;
}

.music-album-art,
.music-playlist-tile {
  width: 100%;
  aspect-ratio: 1;
  margin-bottom: 8px;
  border-radius: 14px;
}

.music-album-art {
  display: grid;
  place-items: center;
}

.music-album-grid strong,
.music-album-grid small,
.music-playlist-grid strong,
.music-playlist-grid small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-album-grid strong,
.music-playlist-grid strong {
  font-size: 14px;
  font-weight: 650;
}

.music-album-grid small,
.music-playlist-grid small {
  margin-top: 2px;
  color: var(--music-muted);
  font-size: 12px;
}

.music-track-list {
  margin-top: 0;
}

.music-track-list :deep(li) {
  min-height: 61px;
}

.music-track-list :deep(.text-sm) {
  color: var(--music-muted);
}

.music-row-art {
  width: 43px;
  height: 43px;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgb(0 0 0 / 18%);
}

.music-track-list :deep(button) {
  color: var(--music-accent);
}

.music-searchbar {
  width: calc(100% - 24px);
  margin: 0 12px 10px;
}

.music-playlist-tile,
.music-playlist-art {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  overflow: hidden;
  background: linear-gradient(145deg, #ff5877, #9b1caf);
  color: #fff;
  box-shadow: 0 12px 25px rgb(0 0 0 / 16%);
}

.music-playlist-tile i,
.music-playlist-art > div {
  position: relative;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
}

.music-playlist-placeholder {
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  position: relative;
  grid-column: 1 / -1;
  grid-row: 1 / -1;
  overflow: hidden;
}

.music-playlist-tile > svg,
.music-playlist-art > svg {
  grid-column: 1 / -1;
  align-self: center;
  justify-self: center;
}

.music-playlist-hero {
  padding: 14px 26px 22px;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.music-playlist-art {
  width: min(214px, 72%);
  aspect-ratio: 1;
  grid-template-rows: repeat(2, minmax(0, 1fr));
  border-radius: 22px;
}

.music-playlist-hero h1 {
  max-width: 100%;
  margin: 19px 0 2px;
  overflow: hidden;
  font-size: 26px;
  letter-spacing: -0.7px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-playlist-hero p {
  margin: 0 0 16px;
  color: var(--music-muted);
  font-size: 13px;
}

.music-playlist-hero :deep(button) {
  width: 100%;
}

.music-playlist-actions {
  width: 100%;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 9px;
}

.music-playlist-actions :deep(button) {
  min-width: 0;
  padding-inline: 10px;
}

.music-mini-player {
  position: absolute;
  z-index: 32;
  right: calc(var(--sky-safe-area-right) + var(--sky-space-4));
  bottom: var(--music-mini-player-bottom);
  left: calc(var(--sky-safe-area-left) + var(--sky-space-4));
  height: var(--music-mini-player-height);
  padding: 6px 10px 6px 7px;
  border-radius: 17px;
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr) 36px 36px;
  align-items: center;
  gap: 7px;
  overflow: hidden;
}

.music-app--playlist .music-mini-player {
  bottom: 29px;
}

.music-mini-art {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  box-shadow: 0 3px 9px rgb(0 0 0 / 20%);
}

.music-mini-copy {
  min-width: 0;
}

.music-mini-copy strong,
.music-mini-copy small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-mini-copy strong {
  font-size: 13px;
}

.music-mini-copy small {
  color: var(--music-muted);
  font-size: 11px;
}

.music-mini-player > button,
.music-player-controls button {
  display: grid;
  place-items: center;
  padding: 0;
  background: transparent;
  color: var(--music-label);
}

.music-navigation {
  z-index: 31;
}

.music-navigation__item {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  line-height: 1;
}

.music-navigation__item > span:last-child {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-form-sheet,
.music-player-sheet {
  --music-accent: #fa2d48;
  display: contents;
  color: var(--music-label);
}

.music-sheet-content {
  min-height: 390px;
  max-height: 690px;
  padding: 0 15px 34px;
  overflow-y: auto;
}

.music-sheet-content > header,
.music-player > header {
  height: 54px;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
}

.music-sheet-content > header strong,
.music-player > header span {
  font-size: 14px;
  font-weight: 700;
}

.music-sheet-icon {
  width: 62px;
  height: 62px;
  margin: 15px auto 9px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #ff5877, #d5117b);
  color: #fff;
  box-shadow: 0 10px 25px rgb(213 17 123 / 24%);
}

.music-sheet-content > p {
  margin: 0 auto 18px;
  max-width: 290px;
  color: var(--music-muted);
  font-size: 13px;
  line-height: 1.45;
  text-align: center;
}

.music-sheet-content > :deep(button) {
  margin-top: 15px;
}

.music-sheet-content .music-form-error {
  margin: 10px 6px 0;
  color: var(--music-accent);
  text-align: left;
}

.music-picker-list {
  margin-top: 12px;
}

.music-picker-added {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--music-muted);
  font-size: 11px;
}

.music-picker-create {
  width: calc(100% - 32px);
  margin: 14px 16px 0 !important;
}

.music-player-sheet :deep(.sky-sheet__panel) {
  background: rgb(22 22 25 / 96%) !important;
}

.music-player {
  min-height: 740px;
  padding: 0 27px 28px;
  color: #fff;
  background:
    radial-gradient(circle at 50% 25%, rgb(250 45 72 / 18%), transparent 42%),
    #151518;
}

.music-player > header {
  color: rgb(255 255 255 / 68%);
}

.music-player > header :deep(button) {
  justify-self: start;
  color: #fff;
}

.music-player-header-actions {
  justify-self: end;
  display: flex;
  align-items: center;
  gap: 5px;
}

.music-player-art {
  width: 100%;
  aspect-ratio: 1;
  margin-top: 25px;
  border-radius: 24px;
  box-shadow: 0 30px 65px rgb(0 0 0 / 42%);
}

.music-player-copy {
  margin-top: 30px;
  min-width: 0;
}

.music-player-copy strong,
.music-player-copy span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.music-player-copy strong {
  font-size: 21px;
}

.music-player-copy span {
  margin-top: 3px;
  color: rgb(255 255 255 / 60%);
  font-size: 18px;
}

.music-progress {
  margin-top: 19px;
}

.music-progress > div {
  margin-top: -2px;
  display: flex;
  justify-content: space-between;
  color: rgb(255 255 255 / 48%);
  font-size: 10px;
  font-variant-numeric: tabular-nums;
}

.music-player-controls {
  height: 104px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  align-items: center;
}

.music-player-controls button {
  color: #fff;
}

.music-player-controls button:active,
.music-mini-player > button:active {
  transform: scale(0.9);
}

.music-volume {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 9px;
  color: rgb(255 255 255 / 58%);
}

.music-player-error {
  color: #ff6b76;
  font-size: 12px;
  text-align: center;
}

@media (prefers-reduced-motion: reduce) {
  .music-player-controls button,
  .music-mini-player > button {
    transition: none;
  }
}
</style>
