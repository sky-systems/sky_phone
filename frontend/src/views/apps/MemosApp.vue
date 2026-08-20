<script setup lang="ts">
import {
  Ellipsis,
  Mic,
  MicOff,
  Pause,
  Play,
  RotateCcw,
  RotateCw,
  Trash2,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import { useMemosStore } from '@/stores/memos'
import { useNotificationsStore } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import type { MemoDto, MemoRecorderState } from '@/types/memos'
import {
  SkyActionButton,
  SkyActionGroup,
  SkyActionSheet,
  SkyAppPage,
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyFab,
  SkyField,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyListItem,
  SkyNavbar,
  SkyRange,
  SkyScrollArea,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySpinner,
} from '@/ui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type MemoView = 'detail' | 'list' | 'recording'

const phone = usePhoneStore()
const memos = useMemosStore()
const notifications = useNotificationsStore()
const view = ref<MemoView>('list')
const searchQuery = ref('')
const selectedId = ref<string | null>(null)
const draftTitle = ref('')
const draftNote = ref('')
const recorderState = ref<MemoRecorderState>({
  elapsedMs: 0,
  levels: Array(32).fill(0.08),
  state: 'idle',
})
const audio = ref<HTMLAudioElement | null>(null)
const activeAudioId = ref<string | null>(null)
const audioCurrentTime = ref(0)
const audioPlaying = ref(false)
const playbackRate = ref(1)
const deleteDialogOpened = ref(false)
const discardDialogOpened = ref(false)
const menuOpened = ref(false)
let playbackRequest = 0

const selectedMemo = computed(() =>
  selectedId.value
    ? memos.memos.find((memo) => memo.id === selectedId.value)
    : undefined,
)
const activeAudioMemo = computed(() =>
  activeAudioId.value
    ? memos.memos.find((memo) => memo.id === activeAudioId.value)
    : undefined,
)
const visibleMemos = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase(phone.lang)
  return [...memos.memos]
    .filter(
      (memo) =>
        !query ||
        `${memo.title}\n${memo.note}`
          .toLocaleLowerCase(phone.lang)
          .includes(query),
    )
    .sort((left, right) => right.updatedAt - left.updatedAt)
})
const recordingBusy = computed(() =>
  ['starting', 'stopping', 'uploading'].includes(recorderState.value.state),
)
const recordingActive = computed(() =>
  ['recording', 'paused', 'starting', 'stopping', 'uploading'].includes(
    recorderState.value.state,
  ),
)
const recordingControllable = computed(() =>
  ['paused', 'recording'].includes(recorderState.value.state),
)
const recorderWaveform = computed(() => {
  const levels = recorderState.value.levels.length
    ? recorderState.value.levels
    : Array(32).fill(0.08)
  return Array.from({ length: 64 }, (_, index) => levels[index % levels.length])
})
const activeAudioProgress = computed(() => {
  const duration = (activeAudioMemo.value?.durationMs ?? 0) / 1000
  return duration > 0 ? Math.min(1, audioCurrentTime.value / duration) : 0
})
function defaultRecordingTitle(): string {
  const date = new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date())
  return phone.t('Apps.memos.newMemoWithDate', { date })
}

function formatDuration(milliseconds: number, precise = false): string {
  const safe = Math.max(0, milliseconds)
  const totalSeconds = Math.floor(safe / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  if (!precise) return `${minutes}:${String(seconds).padStart(2, '0')}`
  const tenths = Math.floor((safe % 1000) / 100)
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}.${tenths}`
}

function memoDate(timestamp: number): string {
  const date = new Date(timestamp)
  const now = new Date()
  const sameDay = date.toDateString() === now.toDateString()
  return new Intl.DateTimeFormat(phone.lang, {
    ...(sameDay
      ? { hour: '2-digit', minute: '2-digit' }
      : {
          day: '2-digit',
          month: '2-digit',
          ...(date.getFullYear() === now.getFullYear()
            ? {}
            : { year: 'numeric' }),
        }),
  }).format(date)
}

function memoSubtitle(memo: MemoDto): string {
  return `${memoDate(memo.updatedAt)} · ${formatDuration(memo.durationMs)}`
}

function waveformProgress(memo: MemoDto): number {
  return activeAudioId.value === memo.id ? activeAudioProgress.value : 0
}

function showNotification(message: string): void {
  notifications.show({
    appId: 'memos',
    route: '/apps/memos',
    text: message,
    title: phone.t('Apps.memos.name'),
  })
}

function recorderError(error?: string): string {
  if (error === 'microphone_unavailable') {
    return phone.t('Apps.memos.microphoneUnavailable')
  }
  if (error === 'recording_too_large') {
    return phone.t('Apps.memos.recordingTooLarge')
  }
  const known = new Set([
    'conflict',
    'invalid_memo',
    'invalid_request',
    'invalid_upload',
    'invalid_upload_token',
    'memo_limit',
    'memo_not_found',
    'media_provider_failed',
    'media_provider_rate_limited',
    'media_provider_unauthorized',
    'missing_config',
    'operation_in_progress',
    'owner_changed',
    'rate_limited',
    'recording_failed',
    'request_timeout',
    'upload_failed',
    'upload_timeout',
  ])
  return phone.t(
    `Apps.memos.errors.${known.has(error ?? '') ? error : 'request_failed'}`,
  )
}

function postRecorderCommand(
  type: string,
  data: Record<string, unknown> = {},
): void {
  window.postMessage({ data, type }, '*')
}

function startRecording(): void {
  stopPlayback()
  draftTitle.value = defaultRecordingTitle()
  draftNote.value = ''
  recorderState.value = {
    elapsedMs: 0,
    levels: Array(32).fill(0.08),
    state: 'starting',
  }
  view.value = 'recording'
  postRecorderCommand('memo:recordStart', {
    note: '',
    pinned: false,
    title: draftTitle.value,
  })
}

function stopRecording(): void {
  postRecorderCommand('memo:recordStop', {
    note: draftNote.value.trim(),
    pinned: false,
    title: draftTitle.value.trim() || defaultRecordingTitle(),
  })
}

function pauseOrResumeRecording(): void {
  postRecorderCommand(
    recorderState.value.state === 'paused'
      ? 'memo:recordResume'
      : 'memo:recordPause',
  )
}

function requestCancelRecording(): void {
  if (!recordingActive.value) {
    view.value = 'list'
    return
  }
  discardDialogOpened.value = true
}

function discardRecording(): void {
  discardDialogOpened.value = false
  postRecorderCommand('memo:recordCancel')
  view.value = 'list'
}

async function ensureAudio(memo: MemoDto): Promise<HTMLAudioElement | null> {
  if (activeAudioId.value !== memo.id) {
    audio.value?.pause()
    audioPlaying.value = false
    activeAudioId.value = memo.id
    audioCurrentTime.value = 0
    await nextTick()
    audio.value?.load()
  }
  if (audio.value) audio.value.playbackRate = playbackRate.value
  return audio.value
}

async function togglePlayback(memo: MemoDto): Promise<void> {
  const request = ++playbackRequest
  const player = await ensureAudio(memo)
  if (!player || request !== playbackRequest || activeAudioId.value !== memo.id)
    return
  if (audioPlaying.value && activeAudioId.value === memo.id) {
    player.pause()
    return
  }
  if (player.ended) {
    player.currentTime = 0
    audioCurrentTime.value = 0
  }
  try {
    await player.play()
  } catch (error) {
    if (request !== playbackRequest) return
    console.error(`[Memos] Could not play memo ${memo.id}.`, error)
    showNotification(phone.t('Apps.memos.errors.request_failed'))
  }
}

function stopPlayback(): void {
  playbackRequest += 1
  audio.value?.pause()
  audioPlaying.value = false
  audioCurrentTime.value = 0
  if (audio.value) audio.value.currentTime = 0
}

function updateAudioProgress(): void {
  audioCurrentTime.value = audio.value?.currentTime ?? 0
}

function finishPlayback(): void {
  audioPlaying.value = false
  audioCurrentTime.value = 0
  if (audio.value) audio.value.currentTime = 0
}

function failPlayback(): void {
  audioPlaying.value = false
  showNotification(phone.t('Apps.memos.errors.request_failed'))
}

function skipPlayback(seconds: number): void {
  if (!audio.value || !activeAudioMemo.value) return
  const duration = activeAudioMemo.value.durationMs / 1000
  audio.value.currentTime = Math.min(
    duration,
    Math.max(0, audio.value.currentTime + seconds),
  )
  updateAudioProgress()
}

function seekPlayback(event: Event): void {
  if (!audio.value || !selectedMemo.value) return
  const value = Number((event.target as HTMLInputElement).value)
  if (!Number.isFinite(value)) return
  audio.value.currentTime = value
  audioCurrentTime.value = value
}

function setPlaybackRate(rate: number): void {
  playbackRate.value = rate
  if (audio.value) audio.value.playbackRate = rate
}

function openMemo(memo: MemoDto): void {
  stopPlayback()
  selectedId.value = memo.id
  draftTitle.value = memo.title
  draftNote.value = memo.note
  playbackRate.value = 1
  activeAudioId.value = memo.id
  view.value = 'detail'
}

async function persistSelected(): Promise<boolean> {
  const memo = selectedMemo.value
  if (!memo) return false
  const title = draftTitle.value.trim() || memo.title
  const note = draftNote.value.trim()
  const unchanged = title === memo.title && note === memo.note
  if (unchanged) return true
  const response = await memos.update(memo.id, {
    note,
    pinned: memo.pinned,
    revision: memo.revision,
    title,
  })
  if (!response.success) {
    if (response.error === 'conflict') {
      await memos.load()
      const current = selectedMemo.value
      if (current) {
        draftTitle.value = current.title
        draftNote.value = current.note
      }
    }
    showNotification(recorderError(response.error))
    return false
  }
  draftTitle.value = response.data?.title ?? title
  draftNote.value = response.data?.note ?? note
  return true
}

async function closeDetail(): Promise<void> {
  menuOpened.value = false
  if (!(await persistSelected())) return
  stopPlayback()
  selectedId.value = null
  activeAudioId.value = null
  view.value = 'list'
}

async function openMenu(): Promise<void> {
  if (!(await persistSelected())) return
  menuOpened.value = true
}

function requestDelete(): void {
  menuOpened.value = false
  deleteDialogOpened.value = true
}

async function deleteSelected(): Promise<void> {
  const memo = selectedMemo.value
  if (!memo) return
  const response = await memos.deleteMemo(memo.id)
  deleteDialogOpened.value = false
  if (!response.success) {
    showNotification(recorderError(response.error))
    return
  }
  stopPlayback()
  selectedId.value = null
  activeAudioId.value = null
  view.value = 'list'
  showNotification(phone.t('Apps.memos.deleted'))
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as { data?: unknown; type?: string }
  if (message.type === 'memo:recordState') {
    const state = message.data as MemoRecorderState
    if (!state || !Array.isArray(state.levels)) return
    recorderState.value = state
    if (
      ['paused', 'recording', 'starting', 'stopping', 'uploading'].includes(
        state.state,
      )
    ) {
      view.value = 'recording'
    }
    if (state.error) showNotification(recorderError(state.error))
  } else if (message.type === 'memo:saved') {
    const memo = message.data as MemoDto
    selectedId.value = memo.id
    draftTitle.value = memo.title
    draftNote.value = memo.note
    activeAudioId.value = memo.id
    view.value = 'detail'
  }
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  postRecorderCommand('memo:recordStateRequest')
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  stopPlayback()
  if (view.value === 'detail') void persistSelected()
})
</script>

<template>
  <SkyAppPage
    v-if="view !== 'detail'"
    class="memos-page"
    :dark="phone.isDarkMode"
    accent="#ff3b30"
    accent-soft="rgb(255 59 48 / 15%)"
    :label="phone.t('Apps.memos.name')"
  >
    <SkyNavbar
      variant="large"
      transparent
      :title="phone.t('Apps.memos.name')"
    />

    <SkyScrollArea padded class="memos-page__content">
      <div v-if="memos.loading" class="memos-loading">
        <SkySpinner :label="phone.t('Common.loading')" :size="24" />
      </div>

      <SkyGlass
        v-else-if="visibleMemos.length"
        class="memos-list-glass"
        :highlight="false"
      >
        <SkyList nested class="memos-list">
          <SkyListItem
            v-for="memo in visibleMemos"
            :key="memo.id"
            link
            link-component="button"
            :title="memo.title"
            :subtitle="memoSubtitle(memo)"
            :chevron="false"
            strong-title="auto"
            class="memo-row"
            @click="openMemo(memo)"
          >
            <template #media>
              <SkyLink
                icon-only
                class="memo-row__play"
                :aria-label="
                  phone.t(
                    audioPlaying && activeAudioId === memo.id
                      ? 'Apps.memos.pausePlayback'
                      : 'Apps.memos.play',
                  )
                "
                @click.stop="togglePlayback(memo)"
              >
                <Pause
                  v-if="audioPlaying && activeAudioId === memo.id"
                  :size="17"
                  fill="currentColor"
                />
                <Play v-else :size="17" fill="currentColor" />
              </SkyLink>
            </template>
            <template #text>
              <div class="memo-row__waveform" aria-hidden="true">
                <i
                  v-for="(sample, index) in memo.waveform.slice(0, 48)"
                  :key="index"
                  :class="{
                    active:
                      index /
                        Math.max(1, memo.waveform.slice(0, 48).length - 1) <=
                      waveformProgress(memo),
                  }"
                  :style="{ height: `${Math.max(3, sample * 20)}px` }"
                />
              </div>
            </template>
          </SkyListItem>
        </SkyList>
      </SkyGlass>

      <SkyEmptyState
        v-else
        class="memos-empty"
        :title="
          phone.t(
            searchQuery ? 'Apps.memos.noResults' : 'Apps.memos.emptyTitle',
          )
        "
        :body="
          phone.t(
            searchQuery ? 'Apps.memos.noResultsBody' : 'Apps.memos.emptyBody',
          )
        "
      >
        <template #icon><MicOff :size="24" aria-hidden="true" /></template>
      </SkyEmptyState>
    </SkyScrollArea>

    <footer class="memos-composer">
      <SkySearchbar
        v-model="searchQuery"
        class="memos-search"
        :clear-label="phone.t('Common.clear')"
        :label="phone.t('Apps.memos.searchPlaceholder')"
        :placeholder="phone.t('Apps.memos.searchPlaceholder')"
      />
      <SkyFab
        class="memos-record-fab"
        :aria-label="phone.t('Apps.memos.newMemo')"
        @click="startRecording"
      >
        <template #icon><Mic :size="23" aria-hidden="true" /></template>
      </SkyFab>
    </footer>
  </SkyAppPage>

  <SkyAppPage
    v-else-if="selectedMemo"
    class="memo-detail-page"
    :dark="phone.isDarkMode"
    accent="#ff3b30"
    accent-soft="rgb(255 59 48 / 15%)"
    :label="selectedMemo.title"
  >
    <SkyNavbar
      show-back
      :back-label="phone.t('Apps.memos.back')"
      :title="phone.t('Apps.memos.memo')"
      @back="closeDetail"
    >
      <template #right>
        <SkyLink
          icon-only
          :aria-label="phone.t('Apps.memos.actions')"
          @click="openMenu"
        >
          <Ellipsis :size="22" aria-hidden="true" />
        </SkyLink>
      </template>
    </SkyNavbar>

    <SkyScrollArea padded class="memo-detail-scroll">
      <SkyGlass class="memo-fields-glass" :highlight="false">
        <SkyList nested :dividers="false">
          <SkyField
            v-model="draftTitle"
            :label="phone.t('Apps.memos.title')"
            :placeholder="phone.t('Apps.memos.titlePlaceholder')"
            :maxlength="120"
          />
          <SkyField
            v-model="draftNote"
            type="textarea"
            :label="phone.t('Apps.memos.note')"
            :placeholder="phone.t('Apps.memos.notePlaceholder')"
            :maxlength="2000"
            :rows="3"
          />
        </SkyList>
      </SkyGlass>

      <SkyGlass component="section" class="memo-player" :highlight="false">
        <div class="memo-player__meta">
          <span>{{ memoDate(selectedMemo.createdAt) }}</span>
          <span>{{ formatDuration(selectedMemo.durationMs) }}</span>
        </div>
        <div class="memo-player__waveform" aria-hidden="true">
          <i
            v-for="(sample, index) in selectedMemo.waveform"
            :key="index"
            :class="{
              active:
                index / Math.max(1, selectedMemo.waveform.length - 1) <=
                activeAudioProgress,
            }"
            :style="{ height: `${Math.max(4, sample * 96)}px` }"
          />
        </div>
        <SkyRange
          class="memo-player__range"
          :value="audioCurrentTime"
          :min="0"
          :max="selectedMemo.durationMs / 1000"
          :step="0.1"
          :aria-label="phone.t('Apps.memos.play')"
          @input="seekPlayback"
        />
        <div class="memo-player__times">
          <span>{{ formatDuration(audioCurrentTime * 1000) }}</span>
          <span
            >-{{
              formatDuration(
                Math.max(0, selectedMemo.durationMs - audioCurrentTime * 1000),
              )
            }}</span
          >
        </div>
      </SkyGlass>

      <SkyGlass class="memo-player-controls" :highlight="false">
        <SkyButton
          rounded
          icon-only
          variant="secondary"
          class="memo-player-control"
          :aria-label="phone.t('Apps.memos.skipBack')"
          @click="skipPlayback(-15)"
        >
          <span class="memo-skip-icon" aria-hidden="true">
            <RotateCcw :size="24" />
            <small>15</small>
          </span>
        </SkyButton>
        <SkyButton
          rounded
          icon-only
          class="memo-player-control memo-player-control--main"
          :aria-label="
            phone.t(
              audioPlaying ? 'Apps.memos.pausePlayback' : 'Apps.memos.play',
            )
          "
          @click="togglePlayback(selectedMemo)"
        >
          <Pause
            v-if="audioPlaying"
            :size="28"
            fill="currentColor"
            aria-hidden="true"
          />
          <Play v-else :size="28" fill="currentColor" aria-hidden="true" />
        </SkyButton>
        <SkyButton
          rounded
          icon-only
          variant="secondary"
          class="memo-player-control"
          :aria-label="phone.t('Apps.memos.skipForward')"
          @click="skipPlayback(15)"
        >
          <span class="memo-skip-icon" aria-hidden="true">
            <RotateCw :size="24" />
            <small>15</small>
          </span>
        </SkyButton>
      </SkyGlass>

      <h2 class="memo-section-title">
        {{ phone.t('Apps.memos.playbackSpeed') }}
      </h2>
      <SkyGlass class="memo-speed-block" :highlight="false">
        <SkySegmented
          strong
          rounded
          :item-count="4"
          :active-index="[0.75, 1, 1.25, 1.5].indexOf(playbackRate)"
        >
          <SkySegmentedButton
            v-for="rate in [0.75, 1, 1.25, 1.5]"
            :key="rate"
            :active="playbackRate === rate"
            @click="setPlaybackRate(rate)"
          >
            <span class="memo-speed-label">{{ rate }}×</span>
          </SkySegmentedButton>
        </SkySegmented>
      </SkyGlass>
    </SkyScrollArea>
  </SkyAppPage>

  <SkyActionSheet
    class="memos-overlay-theme sky-ui-provider"
    :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
    :opened="menuOpened"
    :aria-label="phone.t('Apps.memos.actions')"
    @backdropclick="menuOpened = false"
    @escape="menuOpened = false"
  >
    <SkyActionGroup>
      <SkyActionButton class="memo-delete-action" @click="requestDelete">
        <Trash2 :size="18" aria-hidden="true" />
        <span>{{ phone.t('Apps.memos.delete') }}</span>
      </SkyActionButton>
    </SkyActionGroup>
  </SkyActionSheet>

  <audio
    ref="audio"
    :src="activeAudioMemo?.url"
    preload="metadata"
    @play="audioPlaying = true"
    @pause="audioPlaying = false"
    @timeupdate="updateAudioProgress"
    @ended="finishPlayback"
    @error="failPlayback"
  />

  <SkyDialog
    class="memo-recording-dialog memos-overlay-theme sky-ui-provider"
    :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
    :opened="view === 'recording' && !discardDialogOpened"
    :title="phone.t('Apps.memos.newMemo')"
    @backdropclick="requestCancelRecording"
    @escape="requestCancelRecording"
  >
    <SkyList class="memo-recording-fields" nested :dividers="false">
      <SkyField
        v-model="draftTitle"
        :aria-label="phone.t('Apps.memos.title')"
        :placeholder="phone.t('Apps.memos.titlePlaceholder')"
        :maxlength="120"
        :disabled="recordingBusy"
      />
    </SkyList>

    <section class="memo-recorder-stage">
      <div class="memo-recorder-stage__status">
        <span
          v-if="recorderState.state === 'recording'"
          class="memo-recording-dot"
          aria-hidden="true"
        />
        <span v-if="recorderState.state === 'error'">
          {{ recorderError(recorderState.error) }}
        </span>
        <span v-else>{{
          phone.t(
            recorderState.state === 'paused'
              ? 'Apps.memos.paused'
              : recorderState.state === 'uploading' ||
                  recorderState.state === 'stopping'
                ? 'Apps.memos.saving'
                : recorderState.state === 'starting'
                  ? 'Apps.memos.preparing'
                  : 'Apps.memos.recording',
          )
        }}</span>
      </div>
      <div class="memo-recorder-waveform" aria-hidden="true">
        <i
          v-for="(level, index) in recorderWaveform"
          :key="index"
          :style="{ height: `${Math.max(4, level * 54)}px` }"
        />
      </div>
      <strong class="memo-recorder-time">{{
        formatDuration(recorderState.elapsedMs, true)
      }}</strong>

      <div class="memo-recorder-controls">
        <SkySpinner
          v-if="recordingBusy"
          :label="phone.t('Apps.memos.saving')"
          :size="24"
        />
        <SkyButton
          v-else-if="recordingControllable"
          rounded
          icon-only
          variant="secondary"
          class="memo-control-button"
          :aria-label="
            phone.t(
              recorderState.state === 'paused'
                ? 'Apps.memos.resume'
                : 'Apps.memos.pause',
            )
          "
          @click="pauseOrResumeRecording"
        >
          <Play
            v-if="recorderState.state === 'paused'"
            :size="20"
            fill="currentColor"
            aria-hidden="true"
          />
          <Pause v-else :size="20" fill="currentColor" aria-hidden="true" />
        </SkyButton>
        <SkyButton
          v-else
          rounded
          tonal
          class="memo-retry-button"
          @click="startRecording"
        >
          <Mic :size="17" aria-hidden="true" />
          <span>{{ phone.t('Apps.memos.newMemo') }}</span>
        </SkyButton>
      </div>
    </section>

    <template #buttons>
      <SkyDialogButton @click="requestCancelRecording">
        {{ phone.t('Apps.memos.cancel') }}
      </SkyDialogButton>
      <SkyDialogButton
        strong
        :disabled="recordingBusy || !recordingControllable"
        @click="stopRecording"
      >
        {{ phone.t('Apps.memos.done') }}
      </SkyDialogButton>
    </template>
  </SkyDialog>

  <SkyDialog
    class="memos-overlay-theme sky-ui-provider"
    :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
    :opened="discardDialogOpened"
    :title="phone.t('Apps.memos.discardTitle')"
    :content="phone.t('Apps.memos.discardBody')"
    role="alertdialog"
    @backdropclick="discardDialogOpened = false"
    @escape="discardDialogOpened = false"
  >
    <template #buttons>
      <SkyDialogButton @click="discardDialogOpened = false">
        {{ phone.t('Apps.memos.keepRecording') }}
      </SkyDialogButton>
      <SkyDialogButton strong class="memo-danger" @click="discardRecording">
        {{ phone.t('Apps.memos.discard') }}
      </SkyDialogButton>
    </template>
  </SkyDialog>

  <SkyDialog
    class="memos-overlay-theme sky-ui-provider"
    :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
    :opened="deleteDialogOpened"
    :title="phone.t('Apps.memos.deleteTitle')"
    :content="phone.t('Apps.memos.deleteBody')"
    role="alertdialog"
    @backdropclick="deleteDialogOpened = false"
    @escape="deleteDialogOpened = false"
  >
    <template #buttons>
      <SkyDialogButton @click="deleteDialogOpened = false">
        {{ phone.t('Common.cancel') }}
      </SkyDialogButton>
      <SkyDialogButton strong class="memo-danger" @click="deleteSelected">
        {{ phone.t('Common.delete') }}
      </SkyDialogButton>
    </template>
  </SkyDialog>
</template>

<style scoped>
.memos-page,
.memo-detail-page,
.memos-overlay-theme {
  --sky-app-accent: #ff3b30;
  --sky-app-accent-soft: rgb(255 59 48 / 15%);
}

.memos-page__content {
  padding-top: 4px;
  padding-bottom: calc(var(--sky-safe-area-bottom) + 86px);
}

.memos-loading {
  min-height: 180px;
  display: grid;
  place-items: center;
  color: var(--sky-app-accent);
}

.memos-list-glass,
.memo-fields-glass,
.memo-player,
.memo-player-controls,
.memo-speed-block {
  overflow: hidden;
  border-radius: var(--sky-radius-card);
}

.memos-list-glass {
  margin-top: 4px;
}

.memos-list {
  margin: 0;
}

.memos-empty {
  min-height: 290px;
  justify-content: center;
}

.memos-empty :deep(.sky-empty-state__icon) {
  color: var(--sky-app-accent);
  background: var(--sky-app-accent-soft);
}

.memos-composer {
  position: absolute;
  z-index: 20;
  right: 0;
  bottom: 0;
  left: 0;
  min-width: 0;
  padding: 8px calc(var(--sky-page-gutter) + var(--sky-safe-area-right))
    calc(var(--sky-safe-area-bottom) + 8px)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
  display: grid;
  grid-template-columns: minmax(0, 1fr) var(--sky-touch-target);
  align-items: center;
  gap: 10px;
  background: linear-gradient(to top, var(--sky-bg) 72%, transparent);
}

.memos-search {
  min-width: 0;
}

.memos-record-fab {
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
}

.memo-row :deep(.sky-list-item__media) {
  align-self: center;
}

.memo-row__play {
  width: 38px;
  height: 38px;
  display: grid;
  border-radius: 50%;
  color: var(--sky-app-accent);
  background: var(--sky-app-accent-soft);
  place-items: center;
}

.memo-row__waveform {
  width: 100%;
  height: 24px;
  display: flex;
  align-items: center;
  gap: 1.5px;
  margin-top: 5px;
  overflow: hidden;
}

.memo-row__waveform i,
.memo-player__waveform i,
.memo-recorder-waveform i {
  display: block;
  min-width: 2px;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-subtle);
  transition:
    height 90ms linear,
    background-color var(--sky-transition-normal) ease;
}

.memo-row__waveform i {
  flex: 1 1 2px;
}

.memo-row__waveform i.active,
.memo-player__waveform i.active {
  background: var(--sky-app-accent);
}

.memo-detail-scroll {
  display: grid;
  grid-auto-rows: max-content;
  align-content: start;
  gap: 12px;
}

.memo-fields-glass :deep(.sky-list) {
  margin: 0;
}

.memo-fields-glass :deep(.sky-field__textarea) {
  min-height: 76px;
  resize: none;
}

.memo-player {
  padding: 17px 16px 11px;
}

.memo-player__meta,
.memo-player__times {
  display: flex;
  justify-content: space-between;
  color: var(--sky-muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}

.memo-player__waveform {
  height: 110px;
  display: flex;
  align-items: center;
  gap: 1.5px;
  margin: 8px 0 3px;
  overflow: hidden;
}

.memo-player__waveform i {
  min-width: 1.5px;
  flex: 1 1 2px;
}

.memo-player__range {
  margin-top: -2px;
}

.memo-player-controls {
  min-height: 86px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 34px;
}

.memo-player-control {
  position: relative;
  width: 48px;
  height: 48px;
  padding: 0;
}

.memo-skip-icon {
  position: relative;
  width: 24px;
  height: 24px;
  display: grid;
  flex: none;
  place-items: center;
}

.memo-skip-icon small {
  position: absolute;
  inset: 0;
  display: grid;
  padding-top: 1px;
  font-size: 7px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  line-height: 1;
  place-items: center;
}

.memo-player-control--main {
  width: 62px;
  height: 62px;
  box-shadow: 0 8px 22px rgb(255 59 48 / 28%);
}

.memo-section-title {
  margin: 2px 8px -4px;
  color: var(--sky-muted);
  font-size: 13px;
  font-weight: 650;
}

.memo-speed-block {
  margin-bottom: 12px;
  padding: 4px;
}

.memo-speed-block :deep(.sky-segmented) {
  background: transparent;
}

.memo-speed-label {
  transform: translateY(1px);
}

.memo-delete-action {
  min-height: 48px;
  gap: 8px;
  color: var(--sky-danger);
}

.memo-recording-fields {
  margin: 0 0 14px;
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface-muted);
}

.memo-recording-fields :deep(.sky-field) {
  min-height: 44px;
}

.memo-recorder-stage {
  display: grid;
  justify-items: center;
}

.memo-recorder-stage__status {
  min-height: 20px;
  display: flex;
  align-items: center;
  gap: 7px;
  color: var(--sky-muted);
  font-size: 12px;
  font-weight: 650;
  text-align: center;
}

.memo-recording-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--sky-app-accent);
  animation: memo-pulse 1.2s ease-in-out infinite;
}

.memo-recorder-waveform {
  width: 100%;
  height: 62px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1px;
  margin: 10px 0 4px;
  overflow: hidden;
}

.memo-recorder-waveform i {
  max-width: 3px;
  flex: 1 1 2px;
  background: var(--sky-app-accent);
}

.memo-recorder-time {
  color: var(--sky-text);
  font-size: 28px;
  font-variant-numeric: tabular-nums;
  letter-spacing: -1px;
}

.memo-recorder-controls {
  min-height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 8px;
}

.memo-control-button {
  width: 48px;
  height: 48px;
  padding: 0;
}

.memo-retry-button {
  min-width: 150px;
  gap: 7px;
}

.memo-danger {
  color: var(--sky-danger);
  background: var(--sky-danger-soft);
}

audio {
  display: none;
}

@keyframes memo-pulse {
  0%,
  100% {
    opacity: 0.45;
    transform: scale(0.82);
  }
  50% {
    opacity: 1;
    transform: scale(1.12);
  }
}

@media (prefers-reduced-motion: reduce) {
  .memo-recording-dot {
    animation: none;
  }

  .memo-row__waveform i,
  .memo-player__waveform i,
  .memo-recorder-waveform i {
    transition: none;
  }
}
</style>
