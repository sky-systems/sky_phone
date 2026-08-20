<script setup lang="ts">
import {
  Gauge,
  Mic,
  Pause,
  Phone,
  PhoneCall,
  PhoneOff,
  Play,
  RotateCcw,
  SkipBack,
  SkipForward,
  Square,
  Timer,
  X,
} from 'lucide-vue-next'
import {
  computed,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
  type CSSProperties,
} from 'vue'
import { useRouter } from 'vue-router'

import { useCallsStore } from '@/stores/calls'
import { useClockStore } from '@/stores/clock'
import { useMusicStore } from '@/stores/music'
import { usePhoneStore } from '@/stores/phone'
import type { DynamicIslandActivity } from '@/types/dynamicIsland'
import type { MemoRecorderState } from '@/types/memos'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
} from '@/utils/clock'
import { formatPhoneNumber } from '@/utils/phone'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

const props = withDefaults(
  defineProps<{
    preview?: boolean
    previewActivity?: DynamicIslandActivity
    previewExpanded?: boolean
    previewEyebrow?: string
    previewProgress?: number
    previewSubtitle?: string
    previewTitle?: string
    previewValue?: string
  }>(),
  {
    preview: false,
    previewExpanded: false,
    previewProgress: 0,
  },
)
const emit = defineEmits<{
  'expanded-change': [expanded: boolean]
  'live-activity-change': [activity: DynamicIslandActivity | null]
}>()
const router = useRouter()
const calls = useCallsStore()
const clock = useClockStore()
const music = useMusicStore()
const phone = usePhoneStore()
const expanded = ref(false)
const islandElement = ref<HTMLElement | null>(null)
const now = ref(Date.now())
const recorderState = ref<MemoRecorderState>({
  elapsedMs: 0,
  levels: Array(32).fill(0.08),
  state: 'idle',
})
let collapseTimer: number | undefined
let ticker: number | undefined

const activeAppId = computed(() => {
  const currentRoute = router.currentRoute.value
  return currentRoute.name === 'app' &&
    typeof currentRoute.params.appId === 'string'
    ? currentRoute.params.appId
    : ''
})

const recordingActive = computed(() =>
  ['paused', 'recording', 'starting', 'stopping', 'uploading'].includes(
    recorderState.value.state,
  ),
)
const pausedTimerActive = computed(
  () =>
    clock.timerDuration > 0 &&
    clock.timerRemainingAtStart > 0 &&
    clock.timerRemainingAtStart < clock.timerDuration,
)
const timerActive = computed(
  () => clock.timerStartedAt !== null || pausedTimerActive.value,
)
const stopwatchActive = computed(
  () => clock.stopwatchStartedAt !== null || clock.stopwatchAccumulated > 0,
)
const liveActivity = computed<DynamicIslandActivity | null>(() => {
  const call = calls.activeCall
  if (call?.direction === 'incoming' && call.state === 'ringing') {
    return 'incoming-call'
  }
  if (call) return 'call'
  if (recordingActive.value) return 'recording'
  if (timerActive.value) return 'timer'
  if (stopwatchActive.value) return 'stopwatch'
  if (music.isPlaying && music.currentTrack) return 'music'
  return null
})
const runtimeActivity = computed<DynamicIslandActivity | null>(() => {
  const currentActivity = liveActivity.value
  if (!currentActivity || !phone.isOpen) return currentActivity
  if (
    (currentActivity === 'incoming-call' || currentActivity === 'call') &&
    activeAppId.value === 'phone'
  ) {
    return null
  }
  if (currentActivity === 'recording' && activeAppId.value === 'memos') {
    return null
  }
  if (
    (currentActivity === 'timer' || currentActivity === 'stopwatch') &&
    activeAppId.value === 'clock'
  ) {
    return null
  }
  if (currentActivity === 'music' && activeAppId.value === 'music') return null
  return currentActivity
})
const activity = computed<DynamicIslandActivity | null>(() =>
  props.preview ? (props.previewActivity ?? null) : runtimeActivity.value,
)
const activityKey = computed(() => {
  if (activity.value === 'incoming-call' || activity.value === 'call') {
    return `${activity.value}:${calls.activeCall?.id ?? ''}`
  }
  if (activity.value === 'music') {
    return `music:${music.currentTrack?.source ?? ''}:${music.currentTrack?.id ?? ''}`
  }
  return activity.value
})
const isExpanded = computed(() =>
  props.preview
    ? props.previewExpanded
    : Boolean(
        activity.value &&
          (!phone.isOpen ||
            activity.value === 'incoming-call' ||
            expanded.value),
      ),
)
const callContact = computed(() => {
  const number = calls.activeCall?.otherNumber
  return number
    ? (calls.contacts.find((contact) => contact.phone_number === number) ??
        null)
    : null
})
const callName = computed(() => {
  const number = calls.activeCall?.otherNumber ?? ''
  return (
    props.previewTitle ?? callContact.value?.name ?? formatPhoneNumber(number)
  )
})
const callInitials = computed(() =>
  (
    props.previewTitle ??
    callContact.value?.name ??
    calls.activeCall?.otherNumber ??
    ''
  )
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase())
    .filter(Boolean)
    .slice(0, 2)
    .join(''),
)
const callDuration = computed(() => {
  const call = calls.activeCall
  if (!call || call.state !== 'connected') return ''
  return formatDuration(now.value - (call.answeredAt ?? call.startedAt))
})
const callStatus = computed(() => {
  if (props.previewSubtitle !== undefined) return props.previewSubtitle
  const call = calls.activeCall
  if (!call) return ''
  if (call.state === 'connected') return callDuration.value
  if (call.state === 'ringing') {
    return phone.t(
      call.direction === 'incoming'
        ? 'Apps.phone.incoming'
        : 'Apps.phone.calling',
    )
  }
  const state = call.state === 'no_answer' ? 'noAnswer' : call.state
  return phone.t(`Apps.phone.${state}`)
})
const timerValue = computed(() =>
  remainingMilliseconds(
    clock.timerRemainingAtStart,
    clock.timerStartedAt,
    now.value,
  ),
)
const stopwatchValue = computed(() =>
  elapsedMilliseconds(
    clock.stopwatchAccumulated,
    clock.stopwatchStartedAt,
    now.value,
  ),
)
const stopwatchLapLabel = computed(() =>
  props.preview
    ? 'LAP 1'
    : `${phone.t('Apps.clock.lap').toLocaleUpperCase(phone.lang)} ${clock.laps.length + 1}`,
)
const stopwatchLapValue = computed(() => {
  if (props.preview) return '00:02'
  const latestCompletedLap = clock.laps[0] ?? 0
  return formatLapTime(stopwatchValue.value - latestCompletedLap)
})
const stopwatchTotalDisplay = computed(() => {
  if (props.preview) return '00:11,48'
  const decimalSeparator =
    new Intl.NumberFormat(phone.lang)
      .formatToParts(1.1)
      .find((part) => part.type === 'decimal')?.value ?? '.'
  return formatStopwatch(stopwatchValue.value).replace('.', decimalSeparator)
})
const musicProgress = computed(() =>
  props.preview
    ? props.previewProgress
    : music.duration > 0
      ? Math.max(0, Math.min(1, music.currentTime / music.duration))
      : 0,
)
const progressStyle = computed<CSSProperties>(() => ({
  '--dynamic-island-progress': `${musicProgress.value * 100}%`,
}))
const musicElapsedLabel = computed(() =>
  props.preview ? '1:20' : formatPlaybackTime(music.currentTime),
)
const musicRemainingLabel = computed(() =>
  props.preview
    ? '-2:15'
    : `-${formatPlaybackTime(Math.max(0, music.duration - music.currentTime))}`,
)
const activityTitle = computed(() => {
  if (props.previewTitle !== undefined) return props.previewTitle
  switch (activity.value) {
    case 'incoming-call':
      return phone.t('Apps.phone.incoming')
    case 'call':
      return callName.value
    case 'recording':
      return recordingStatus.value
    case 'timer':
      return phone.t('Apps.clock.tabs.timer')
    case 'stopwatch':
      return phone.t('Apps.clock.tabs.stopwatch')
    case 'music':
      return music.currentTrack?.title ?? phone.t('Apps.music.name')
    default:
      return ''
  }
})
const recordingStatus = computed(() => {
  switch (recorderState.value.state) {
    case 'paused':
      return phone.t('Apps.memos.paused')
    case 'starting':
      return phone.t('Apps.memos.preparing')
    case 'stopping':
    case 'uploading':
      return phone.t('Apps.memos.saving')
    default:
      return phone.t('Apps.memos.recording')
  }
})
const compactValue = computed(() => {
  if (props.previewValue !== undefined) return props.previewValue
  switch (activity.value) {
    case 'call':
      return callDuration.value || callStatus.value
    case 'recording':
      return formatDuration(recorderState.value.elapsedMs)
    case 'timer':
      return formatTimer(timerValue.value)
    case 'stopwatch':
      return formatStopwatch(stopwatchValue.value)
    case 'music':
      return music.currentTrack?.title ?? ''
    default:
      return ''
  }
})
const visibleLevels = computed(() => {
  const levels = props.preview
    ? [0.24, 0.48, 0.82, 0.38, 0.64, 0.92, 0.56, 0.76, 0.34, 0.68, 0.44, 0.86]
    : recorderState.value.levels.slice(-12)
  return levels.map((level) => Math.max(0.12, Math.min(1, Number(level) || 0)))
})
const expandedEyebrow = computed(() => {
  if (props.previewEyebrow !== undefined) return props.previewEyebrow
  if (activity.value === 'incoming-call') return phone.t('Apps.phone.incoming')
  if (activity.value === 'recording') return recordingStatus.value
  if (activity.value === 'music') return phone.t('Apps.music.nowPlaying')
  if (activity.value === 'timer') return phone.t('Apps.clock.tabs.timer')
  if (activity.value === 'stopwatch') {
    return phone.t('Apps.clock.tabs.stopwatch')
  }
  return phone.t('Apps.phone.connected')
})
const expandedTitle = computed(() => {
  if (props.previewTitle !== undefined) return props.previewTitle
  if (activity.value === 'call' || activity.value === 'incoming-call') {
    return callName.value
  }
  if (activity.value === 'music') return music.currentTrack?.title ?? ''
  if (activity.value === 'recording') {
    return formatDuration(recorderState.value.elapsedMs)
  }
  if (activity.value === 'timer') return formatTimer(timerValue.value)
  return formatStopwatch(stopwatchValue.value)
})
const expandedSubtitle = computed(() => {
  if (props.previewSubtitle !== undefined) return props.previewSubtitle
  if (activity.value === 'call' || activity.value === 'incoming-call') {
    return callStatus.value
  }
  if (activity.value === 'music') return music.currentTrack?.artist ?? ''
  if (activity.value === 'timer') return clock.timerNote
  if (activity.value === 'recording') return recordingStatus.value
  return phone.t(
    clock.stopwatchStartedAt === null ? 'Common.start' : 'Common.stop',
  )
})

watch(activityKey, (nextActivity) => {
  if (props.preview) return
  window.clearTimeout(collapseTimer)
  if (!nextActivity) {
    expanded.value = false
    return
  }
  expanded.value = true
  if (activity.value !== 'incoming-call') {
    collapseTimer = window.setTimeout(() => {
      expanded.value = false
    }, 3200)
  }
})

watch(
  liveActivity,
  (nextActivity) => {
    if (!props.preview) emit('live-activity-change', nextActivity)
  },
  { immediate: true },
)

watch(
  [isExpanded, activity],
  ([nextExpanded, nextActivity]) => {
    if (props.preview) return
    emit('expanded-change', Boolean(nextActivity && nextExpanded))
  },
  { immediate: true },
)

function formatDuration(milliseconds: number): string {
  const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = String(totalSeconds % 60).padStart(2, '0')
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, '0')}:${seconds}`
    : `${String(minutes).padStart(2, '0')}:${seconds}`
}

function formatPlaybackTime(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds))
  return `${Math.floor(safeSeconds / 60)}:${String(safeSeconds % 60).padStart(2, '0')}`
}

function formatLapTime(milliseconds: number): string {
  const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000))
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

function toggleExpanded(): void {
  if (props.preview) return
  if (activity.value === 'incoming-call') return
  window.clearTimeout(collapseTimer)
  expanded.value = !expanded.value
}

function collapseExpanded(): void {
  if (!expanded.value) return
  window.clearTimeout(collapseTimer)
  expanded.value = false
}

function onOutsidePointerDown(event: PointerEvent): void {
  if (
    event.target instanceof Node &&
    islandElement.value?.contains(event.target)
  ) {
    return
  }
  collapseExpanded()
}

function openActivity(): void {
  const currentActivity = activity.value
  if (!currentActivity) return
  const target = {
    call: '/apps/phone',
    'incoming-call': '/apps/phone',
    music: '/apps/music',
    recording: '/apps/memos',
    stopwatch: '/apps/clock?section=stopwatch',
    timer: '/apps/clock?section=timer',
  }[currentActivity]
  if (target) void router.push(target)
}

function endCall(): void {
  const call = calls.activeCall
  if (!call) return
  if (call.direction === 'incoming' && call.state === 'ringing') {
    void calls.decline()
    return
  }
  void calls.hangup()
}

function postRecorderCommand(type: string): void {
  window.postMessage({ data: {}, type }, '*')
}

function pauseOrResumeRecording(): void {
  postRecorderCommand(
    recorderState.value.state === 'paused'
      ? 'memo:recordResume'
      : 'memo:recordPause',
  )
}

function toggleTimer(): void {
  if (clock.timerStartedAt === null) clock.startTimer(Date.now())
  else clock.pauseTimer(Date.now())
}

function toggleStopwatch(): void {
  if (clock.stopwatchStartedAt === null) clock.startStopwatch(Date.now())
  else clock.pauseStopwatch(Date.now())
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as { data?: unknown; type?: string }
  if (message.type !== 'memo:recordState') return
  const state = message.data as MemoRecorderState
  if (
    !state ||
    typeof state.elapsedMs !== 'number' ||
    !Array.isArray(state.levels) ||
    typeof state.state !== 'string'
  ) {
    return
  }
  recorderState.value = state
}

onMounted(() => {
  if (props.preview) return
  window.addEventListener('message', onMessage)
  document.addEventListener('pointerdown', onOutsidePointerDown, true)
  document.addEventListener('scroll', collapseExpanded, true)
  ticker = window.setInterval(() => {
    now.value = Date.now()
  }, 250)
  postRecorderCommand('memo:recordStateRequest')
})

onBeforeUnmount(() => {
  if (!props.preview) {
    emit('expanded-change', false)
    emit('live-activity-change', null)
  }
  window.removeEventListener('message', onMessage)
  document.removeEventListener('pointerdown', onOutsidePointerDown, true)
  document.removeEventListener('scroll', collapseExpanded, true)
  window.clearInterval(ticker)
  window.clearTimeout(collapseTimer)
})
</script>

<template>
  <Transition name="phone-dynamic-island">
    <section
      v-if="activity"
      ref="islandElement"
      class="phone-dynamic-island"
      :class="`phone-dynamic-island--${activity}`"
      :data-expanded="isExpanded"
      :data-preview="props.preview ? 'true' : undefined"
      :aria-label="activityTitle"
      :aria-hidden="props.preview || undefined"
      :role="
        !props.preview && activity === 'incoming-call' ? 'alert' : undefined
      "
      :aria-atomic="
        !props.preview && activity === 'incoming-call' ? 'true' : undefined
      "
    >
      <Transition name="phone-dynamic-island-content" mode="out-in">
        <button
          v-if="!isExpanded"
          :key="`compact-${activity}`"
          type="button"
          class="phone-dynamic-island__compact"
          :aria-label="activityTitle"
          @click.stop="toggleExpanded"
        >
          <PhoneCall
            v-if="activity === 'call'"
            class="phone-dynamic-island__compact-icon phone-dynamic-island__compact-icon--call"
            aria-hidden="true"
          />
          <Mic
            v-else-if="activity === 'recording'"
            class="phone-dynamic-island__compact-icon phone-dynamic-island__compact-icon--recording"
            aria-hidden="true"
          />
          <Timer
            v-else-if="activity === 'timer'"
            class="phone-dynamic-island__compact-icon phone-dynamic-island__compact-icon--timer"
            aria-hidden="true"
          />
          <Gauge
            v-else-if="activity === 'stopwatch'"
            class="phone-dynamic-island__compact-icon phone-dynamic-island__compact-icon--timer"
            aria-hidden="true"
          />
          <img
            v-else-if="music.currentTrack?.artwork && !props.preview"
            class="phone-dynamic-island__compact-artwork"
            :src="music.currentTrack.artwork"
            alt=""
          />
          <span
            v-else
            class="phone-dynamic-island__compact-artwork phone-dynamic-island__compact-artwork--fallback"
            aria-hidden="true"
          ></span>
          <span class="phone-dynamic-island__compact-value">{{
            compactValue
          }}</span>
          <span
            v-if="activity === 'recording'"
            class="phone-dynamic-island__recording-dot"
            aria-hidden="true"
          ></span>
          <span
            v-else-if="activity === 'music'"
            class="phone-dynamic-island__music-bars"
            :class="{
              'phone-dynamic-island__music-bars--paused': !music.isPlaying,
            }"
            aria-hidden="true"
          >
            <i></i><i></i><i></i>
          </span>
        </button>

        <div
          v-else
          :key="`expanded-${activity}`"
          class="phone-dynamic-island__expanded"
        >
          <button
            type="button"
            class="phone-dynamic-island__summary"
            :aria-label="activityTitle"
            @click.stop="openActivity"
          >
            <span class="phone-dynamic-island__leading" aria-hidden="true">
              <img
                v-if="
                  (activity === 'call' || activity === 'incoming-call') &&
                  callContact?.avatar_url
                "
                :src="callContact.avatar_url"
                alt=""
              />
              <span
                v-else-if="activity === 'call' || activity === 'incoming-call'"
                class="phone-dynamic-island__avatar"
                >{{ callInitials }}</span
              >
              <img
                v-else-if="
                  activity === 'music' &&
                  music.currentTrack?.artwork &&
                  !props.preview
                "
                :src="music.currentTrack.artwork"
                alt=""
              />
              <span
                v-else-if="activity === 'music'"
                class="phone-dynamic-island__symbol phone-dynamic-island__symbol--music"
                ><Play
              /></span>
              <span
                v-else-if="activity === 'recording'"
                class="phone-dynamic-island__symbol phone-dynamic-island__symbol--recording"
                ><Mic
              /></span>
              <span
                v-else
                class="phone-dynamic-island__symbol phone-dynamic-island__symbol--timer"
              >
                <Timer v-if="activity === 'timer'" />
                <Gauge v-else />
              </span>
            </span>
            <span
              v-if="activity === 'stopwatch'"
              class="phone-dynamic-island__stopwatch-copy"
            >
              <span class="phone-dynamic-island__stopwatch-meta">
                <span>{{ stopwatchLapLabel }}</span>
                <strong>{{ stopwatchLapValue }}</strong>
              </span>
              <strong class="phone-dynamic-island__stopwatch-total">
                {{ stopwatchTotalDisplay }}
              </strong>
            </span>
            <span v-else class="phone-dynamic-island__copy">
              <span class="phone-dynamic-island__eyebrow">
                {{ expandedEyebrow }}
              </span>
              <strong class="phone-dynamic-island__title">
                {{ expandedTitle }}
              </strong>
              <span class="phone-dynamic-island__subtitle">
                {{ expandedSubtitle }}
              </span>
            </span>
            <span
              v-if="activity === 'music'"
              class="phone-dynamic-island__music-equalizer"
              aria-hidden="true"
            >
              <i></i><i></i><i></i><i></i>
            </span>
          </button>

          <div
            v-if="activity === 'recording'"
            class="phone-dynamic-island__waveform"
            aria-hidden="true"
          >
            <i
              v-for="(level, index) in visibleLevels"
              :key="index"
              :style="{ height: `${Math.round(level * 22)}px` }"
            ></i>
          </div>
          <div
            v-else-if="activity === 'music'"
            class="phone-dynamic-island__progress"
            :style="progressStyle"
            aria-hidden="true"
          >
            <span>{{ musicElapsedLabel }}</span>
            <i class="phone-dynamic-island__progress-track"></i>
            <span>{{ musicRemainingLabel }}</span>
          </div>

          <div
            v-if="activity === 'incoming-call'"
            class="phone-dynamic-island__actions phone-dynamic-island__actions--incoming"
          >
            <button
              type="button"
              class="phone-dynamic-island__call-action phone-dynamic-island__call-action--decline"
              :aria-label="phone.t('Apps.phone.decline')"
              @click.stop="endCall"
            >
              <PhoneOff aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__call-action phone-dynamic-island__call-action--answer"
              :aria-label="phone.t('Apps.phone.answer')"
              @click.stop="calls.answer()"
            >
              <Phone aria-hidden="true" />
            </button>
          </div>
          <div
            v-else-if="activity === 'call'"
            class="phone-dynamic-island__actions"
          >
            <button
              type="button"
              class="phone-dynamic-island__action"
              :aria-label="phone.t('Apps.phone.returnToCall')"
              @click.stop="openActivity"
            >
              <PhoneCall aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action phone-dynamic-island__action--danger"
              :aria-label="phone.t('Apps.phone.hangup')"
              @click.stop="endCall"
            >
              <PhoneOff aria-hidden="true" />
            </button>
          </div>
          <div
            v-else-if="activity === 'music'"
            class="phone-dynamic-island__actions phone-dynamic-island__actions--media"
          >
            <button
              type="button"
              class="phone-dynamic-island__action"
              :aria-label="phone.t('Apps.music.previous')"
              @click.stop="music.previous()"
            >
              <SkipBack aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action phone-dynamic-island__action--primary"
              :aria-label="
                phone.t(music.isPlaying ? 'Common.pause' : 'ControlCenter.play')
              "
              @click.stop="music.toggle()"
            >
              <Pause
                v-if="props.preview || music.isPlaying"
                aria-hidden="true"
              />
              <Play v-else aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action"
              :aria-label="phone.t('Apps.music.next')"
              @click.stop="music.next()"
            >
              <SkipForward aria-hidden="true" />
            </button>
          </div>
          <div
            v-else-if="activity === 'recording'"
            class="phone-dynamic-island__actions"
          >
            <button
              type="button"
              class="phone-dynamic-island__action"
              :disabled="
                !props.preview &&
                !['paused', 'recording'].includes(recorderState.state)
              "
              :aria-label="
                phone.t(
                  recorderState.state === 'paused'
                    ? 'Apps.memos.resume'
                    : 'Apps.memos.pause',
                )
              "
              @click.stop="pauseOrResumeRecording"
            >
              <Play
                v-if="recorderState.state === 'paused'"
                aria-hidden="true"
              />
              <Pause v-else aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action phone-dynamic-island__action--recording"
              :disabled="
                !props.preview &&
                !['paused', 'recording'].includes(recorderState.state)
              "
              :aria-label="phone.t('Apps.memos.stop')"
              @click.stop="postRecorderCommand('memo:recordStop')"
            >
              <Square aria-hidden="true" />
            </button>
          </div>
          <div
            v-else-if="activity === 'timer'"
            class="phone-dynamic-island__actions"
          >
            <button
              type="button"
              class="phone-dynamic-island__action"
              :aria-label="phone.t('Common.reset')"
              @click.stop="clock.resetTimer()"
            >
              <X aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action phone-dynamic-island__action--timer"
              :aria-label="
                phone.t(
                  clock.timerStartedAt === null
                    ? 'Common.start'
                    : 'Common.pause',
                )
              "
              @click.stop="toggleTimer"
            >
              <Play
                v-if="!props.preview && clock.timerStartedAt === null"
                aria-hidden="true"
              />
              <Pause v-else aria-hidden="true" />
            </button>
          </div>
          <div v-else class="phone-dynamic-island__actions">
            <button
              type="button"
              class="phone-dynamic-island__action"
              :aria-label="
                phone.t(
                  clock.stopwatchStartedAt === null
                    ? 'Common.reset'
                    : 'Apps.clock.lap',
                )
              "
              @click.stop="
                clock.stopwatchStartedAt === null
                  ? clock.resetStopwatch()
                  : clock.addLap(Date.now())
              "
            >
              <RotateCcw aria-hidden="true" />
            </button>
            <button
              type="button"
              class="phone-dynamic-island__action phone-dynamic-island__action--timer"
              :aria-label="
                phone.t(
                  clock.stopwatchStartedAt === null
                    ? 'Common.start'
                    : 'Common.pause',
                )
              "
              @click.stop="toggleStopwatch"
            >
              <Play
                v-if="!props.preview && clock.stopwatchStartedAt === null"
                aria-hidden="true"
              />
              <Pause v-else aria-hidden="true" />
            </button>
          </div>
        </div>
      </Transition>
    </section>
  </Transition>
</template>

<style scoped>
.phone-dynamic-island {
  position: absolute;
  z-index: 102;
  top: 30px;
  left: 50%;
  width: 126px;
  max-width: calc(100% - 24px);
  height: 38px;
  overflow: hidden;
  border-radius: 999px;
  color: #fff;
  background: #000;
  box-shadow: 0 5px 18px rgb(0 0 0 / 22%);
  transform: translateX(-50%);
  transform-origin: 50% 0;
  transition:
    width 420ms cubic-bezier(0.2, 0.9, 0.2, 1),
    height 420ms cubic-bezier(0.2, 0.9, 0.2, 1),
    border-radius 360ms ease,
    box-shadow 360ms ease;
}

.phone-dynamic-island--call:not([data-expanded='true']) {
  width: 138px;
}

.phone-dynamic-island--music:not([data-expanded='true']) {
  width: 172px;
}

.phone-dynamic-island--recording:not([data-expanded='true']) {
  width: 148px;
}

.phone-dynamic-island--timer:not([data-expanded='true']) {
  width: 144px;
}

.phone-dynamic-island--stopwatch:not([data-expanded='true']) {
  width: 156px;
}

.phone-dynamic-island[data-preview='true'] {
  pointer-events: none;
}

.phone-dynamic-island[data-expanded='true'] {
  width: 318px;
  height: 74px;
  border-radius: 999px;
  box-shadow: 0 12px 32px rgb(0 0 0 / 32%);
}

.phone-dynamic-island--incoming-call[data-expanded='true'] {
  height: 68px;
}

.phone-dynamic-island--music[data-expanded='true'] {
  width: 316px;
  height: 150px;
  border-radius: 32px;
}

.phone-dynamic-island--recording[data-expanded='true'] {
  height: 92px;
}

.phone-dynamic-island--timer[data-expanded='true'] {
  height: 70px;
}

.phone-dynamic-island--stopwatch[data-expanded='true'] {
  height: 70px;
}

.phone-dynamic-island__compact,
.phone-dynamic-island__summary,
.phone-dynamic-island__action,
.phone-dynamic-island__call-action {
  border: 0;
  color: inherit;
  font: inherit;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.phone-dynamic-island__compact {
  display: flex;
  width: 100%;
  height: 38px;
  padding: 0 9px;
  align-items: center;
  gap: 7px;
  background: transparent;
}

.phone-dynamic-island__compact-icon {
  width: 16px;
  height: 16px;
  flex: 0 0 auto;
  stroke-width: 2.4;
}

.phone-dynamic-island__compact-icon--call {
  color: #30d158;
}

.phone-dynamic-island__compact-icon--recording {
  color: #ff453a;
}

.phone-dynamic-island__compact-icon--timer {
  color: #ff9f0a;
}

.phone-dynamic-island__compact-icon--music {
  color: #bf5af2;
}

.phone-dynamic-island__compact-artwork {
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  border-radius: 7px;
  object-fit: cover;
}

.phone-dynamic-island__compact-artwork--fallback,
.phone-dynamic-island__symbol--music {
  background: linear-gradient(180deg, #ff9f43 0%, #e6538d 52%, #8b5cf6 100%);
}

.phone-dynamic-island__compact-value {
  min-width: 0;
  overflow: hidden;
  flex: 1 1 auto;
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  font-weight: 650;
  letter-spacing: -0.15px;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-dynamic-island__recording-dot {
  width: 7px;
  height: 7px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: #ff453a;
  animation: dynamic-island-recording-pulse 1.25s ease-in-out infinite;
}

.phone-dynamic-island__music-bars {
  display: flex;
  height: 16px;
  align-items: center;
  gap: 2px;
}

.phone-dynamic-island__music-bars i {
  width: 2px;
  border-radius: 2px;
  background: #bf5af2;
  animation: dynamic-island-music-bar 0.8s ease-in-out infinite alternate;
}

.phone-dynamic-island__music-bars i:nth-child(1) {
  height: 7px;
}

.phone-dynamic-island__music-bars i:nth-child(2) {
  height: 13px;
  animation-delay: -0.35s;
}

.phone-dynamic-island__music-bars i:nth-child(3) {
  height: 9px;
  animation-delay: -0.55s;
}

.phone-dynamic-island__music-bars--paused i {
  animation-play-state: paused;
}

.phone-dynamic-island__expanded {
  position: relative;
  display: grid;
  box-sizing: border-box;
  height: 100%;
  padding: 8px 10px;
  grid-template-columns: minmax(0, 1fr) auto;
  grid-template-rows: minmax(0, 1fr) auto;
  column-gap: 10px;
}

.phone-dynamic-island--music .phone-dynamic-island__expanded {
  padding: 10px 12px;
  grid-template-columns: minmax(0, 1fr);
  grid-template-rows: 48px 18px minmax(0, 1fr);
  row-gap: 4px;
}

.phone-dynamic-island--music .phone-dynamic-island__summary {
  grid-column: 1;
  grid-row: 1;
}

.phone-dynamic-island--timer .phone-dynamic-island__expanded,
.phone-dynamic-island--stopwatch .phone-dynamic-island__expanded {
  padding: 8px 16px 8px 10px;
  grid-template-columns: auto minmax(0, 1fr);
  grid-template-rows: 1fr;
  column-gap: 8px;
}

.phone-dynamic-island--timer .phone-dynamic-island__summary,
.phone-dynamic-island--stopwatch .phone-dynamic-island__summary {
  justify-content: flex-end;
  grid-column: 2;
  grid-row: 1;
}

.phone-dynamic-island--timer .phone-dynamic-island__leading,
.phone-dynamic-island--stopwatch .phone-dynamic-island__leading {
  display: none;
}

.phone-dynamic-island--timer .phone-dynamic-island__copy {
  align-items: baseline;
  flex-direction: row;
  justify-content: flex-end;
  gap: 7px;
}

.phone-dynamic-island__summary {
  display: flex;
  min-width: 0;
  padding: 0;
  align-items: center;
  gap: 9px;
  background: transparent;
  text-align: left;
}

.phone-dynamic-island__leading,
.phone-dynamic-island__leading img,
.phone-dynamic-island__avatar,
.phone-dynamic-island__symbol {
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  border-radius: 14px;
}

.phone-dynamic-island--music .phone-dynamic-island__leading,
.phone-dynamic-island--music .phone-dynamic-island__leading img,
.phone-dynamic-island--music .phone-dynamic-island__symbol {
  border-radius: 11px;
}

.phone-dynamic-island__leading img {
  display: block;
  object-fit: cover;
}

.phone-dynamic-island__avatar,
.phone-dynamic-island__symbol {
  display: grid;
  place-items: center;
}

.phone-dynamic-island__avatar {
  color: #b8f7ca;
  background: #183d24;
  font-size: 15px;
  font-weight: 750;
}

.phone-dynamic-island__symbol svg {
  width: 21px;
  height: 21px;
}

.phone-dynamic-island__symbol--music {
  color: transparent;
}

.phone-dynamic-island__symbol--music svg {
  display: none;
}

.phone-dynamic-island__symbol--recording {
  color: #ffb4ae;
  background: #4b1717;
}

.phone-dynamic-island__symbol--timer {
  color: #ffd19a;
  background: #4a2d0b;
}

.phone-dynamic-island__copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.phone-dynamic-island__eyebrow {
  overflow: hidden;
  color: #a1a1aa;
  font-size: 10px;
  font-weight: 650;
  letter-spacing: 0.25px;
  line-height: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-dynamic-island--incoming-call .phone-dynamic-island__eyebrow,
.phone-dynamic-island--call .phone-dynamic-island__eyebrow {
  color: #58df7c;
}

.phone-dynamic-island--recording .phone-dynamic-island__eyebrow {
  color: #ff6961;
}

.phone-dynamic-island--timer .phone-dynamic-island__eyebrow,
.phone-dynamic-island--stopwatch .phone-dynamic-island__eyebrow {
  color: #ffad33;
}

.phone-dynamic-island--music .phone-dynamic-island__eyebrow {
  display: none;
}

.phone-dynamic-island__title,
.phone-dynamic-island__subtitle {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-dynamic-island--timer .phone-dynamic-island__eyebrow,
.phone-dynamic-island--stopwatch .phone-dynamic-island__eyebrow {
  color: #ffad33;
  font-size: 10px;
  line-height: 1;
}

.phone-dynamic-island--timer .phone-dynamic-island__title,
.phone-dynamic-island--stopwatch .phone-dynamic-island__title {
  color: #ffb340;
  font-size: 27px;
  font-weight: 450;
  letter-spacing: -1.2px;
  line-height: 1;
}

.phone-dynamic-island--timer .phone-dynamic-island__subtitle,
.phone-dynamic-island--stopwatch .phone-dynamic-island__subtitle {
  display: none;
}

.phone-dynamic-island--stopwatch .phone-dynamic-island__title {
  font-size: 22px;
  letter-spacing: -0.8px;
}

.phone-dynamic-island__stopwatch-copy {
  display: flex;
  min-width: 0;
  align-items: flex-end;
  flex-direction: column;
  justify-content: center;
  gap: 1px;
  font-variant-numeric: tabular-nums;
}

.phone-dynamic-island__stopwatch-meta {
  display: flex;
  align-items: baseline;
  justify-content: flex-end;
  gap: 8px;
  color: #62310e;
  font-size: 10px;
  font-weight: 750;
  letter-spacing: 0.3px;
  line-height: 1;
  white-space: nowrap;
}

.phone-dynamic-island__stopwatch-meta strong {
  color: #ff9f43;
  font-size: 12px;
  font-weight: 650;
}

.phone-dynamic-island__stopwatch-total {
  color: #ff9f43;
  font-size: 31px;
  font-weight: 350;
  letter-spacing: -1.4px;
  line-height: 1;
  white-space: nowrap;
}

.phone-dynamic-island__music-equalizer {
  display: flex;
  height: 24px;
  margin-left: auto;
  align-items: center;
  gap: 2px;
  color: #d28cff;
}

.phone-dynamic-island__music-equalizer i {
  width: 2px;
  border-radius: 2px;
  background: currentcolor;
}

.phone-dynamic-island__music-equalizer i:nth-child(1) {
  height: 10px;
}

.phone-dynamic-island__music-equalizer i:nth-child(2) {
  height: 18px;
}

.phone-dynamic-island__music-equalizer i:nth-child(3) {
  height: 14px;
}

.phone-dynamic-island__music-equalizer i:nth-child(4) {
  height: 8px;
}

.phone-dynamic-island__title {
  font-size: 14px;
  font-variant-numeric: tabular-nums;
  font-weight: 720;
  letter-spacing: -0.25px;
  line-height: 17px;
}

.phone-dynamic-island__subtitle {
  color: #a1a1aa;
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  line-height: 13px;
}

.phone-dynamic-island__waveform {
  position: absolute;
  right: 118px;
  bottom: 9px;
  left: 62px;
  display: flex;
  height: 24px;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  pointer-events: none;
}

.phone-dynamic-island__waveform i {
  width: 3px;
  min-height: 3px;
  border-radius: 3px;
  background: #ff453a;
  transition: height 120ms ease;
}

.phone-dynamic-island__progress {
  display: grid;
  align-items: center;
  gap: 6px;
  grid-column: 1;
  grid-row: 2;
  grid-template-columns: auto minmax(0, 1fr) auto;
  color: #8e8e93;
  font-size: 9px;
  font-variant-numeric: tabular-nums;
}

.phone-dynamic-island__progress-track {
  position: relative;
  height: 3px;
  overflow: hidden;
  border-radius: 999px;
  background: #343438;
}

.phone-dynamic-island__progress-track::after {
  display: block;
  width: var(--dynamic-island-progress);
  height: 100%;
  border-radius: inherit;
  background: #a1a1aa;
  content: '';
  transition: width 250ms linear;
}

.phone-dynamic-island__actions {
  display: flex;
  min-width: 98px;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  grid-column: 2;
  grid-row: 1 / 3;
}

.phone-dynamic-island__actions--media {
  min-width: 142px;
  gap: 5px;
}

.phone-dynamic-island--music .phone-dynamic-island__actions--media {
  min-width: 0;
  justify-content: center;
  gap: 34px;
  grid-column: 1;
  grid-row: 3;
}

.phone-dynamic-island--music .phone-dynamic-island__action {
  color: #fff;
  background: transparent;
}

.phone-dynamic-island--music .phone-dynamic-island__action svg {
  width: 22px;
  height: 22px;
}

.phone-dynamic-island--music .phone-dynamic-island__action--primary svg {
  width: 26px;
  height: 26px;
}

.phone-dynamic-island__actions--incoming {
  min-width: 98px;
  gap: 10px;
}

.phone-dynamic-island--timer .phone-dynamic-island__actions,
.phone-dynamic-island--stopwatch .phone-dynamic-island__actions {
  min-width: 94px;
  justify-content: flex-start;
  gap: 6px;
  grid-column: 1;
  grid-row: 1;
}

.phone-dynamic-island--timer .phone-dynamic-island__action,
.phone-dynamic-island--stopwatch .phone-dynamic-island__action {
  width: 44px;
  height: 44px;
}

.phone-dynamic-island--timer .phone-dynamic-island__action--timer,
.phone-dynamic-island--stopwatch .phone-dynamic-island__action--timer {
  order: -1;
  color: #ff9f0a;
  background: #4a2d0b;
}

.phone-dynamic-island__action {
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border-radius: 50%;
  background: #242427;
  transition:
    background 140ms ease,
    transform 140ms ease;
}

.phone-dynamic-island__action svg {
  width: 19px;
  height: 19px;
}

.phone-dynamic-island__action--primary {
  color: #000;
  background: #fff;
}

.phone-dynamic-island__action--danger,
.phone-dynamic-island__action--recording {
  background: #ff453a;
}

.phone-dynamic-island__action--timer {
  color: #000;
  background: #ff9f0a;
}

.phone-dynamic-island__action:disabled {
  opacity: 0.45;
  cursor: default;
}

.phone-dynamic-island__action:not(:disabled):active,
.phone-dynamic-island__call-action:active {
  transform: scale(0.91);
}

.phone-dynamic-island__call-action {
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border-radius: 50%;
  background: transparent;
}

.phone-dynamic-island__call-action svg {
  width: 44px;
  height: 44px;
  padding: 12px;
  border-radius: 50%;
}

.phone-dynamic-island__call-action--decline svg {
  background: #ff453a;
}

.phone-dynamic-island__call-action--answer svg {
  background: #30d158;
}

.phone-dynamic-island-enter-active,
.phone-dynamic-island-leave-active {
  transition:
    opacity 220ms ease,
    transform 360ms cubic-bezier(0.2, 0.9, 0.2, 1);
}

.phone-dynamic-island-enter-from,
.phone-dynamic-island-leave-to {
  opacity: 0;
  transform: translateX(-50%) scale(0.72, 0.55);
}

.phone-dynamic-island-content-enter-active,
.phone-dynamic-island-content-leave-active {
  transition:
    opacity 150ms ease,
    transform 220ms ease;
}

.phone-dynamic-island-content-enter-from {
  opacity: 0;
  transform: scale(0.94);
}

.phone-dynamic-island-content-leave-to {
  opacity: 0;
  transform: scale(1.03);
}

@keyframes dynamic-island-recording-pulse {
  50% {
    opacity: 0.35;
    transform: scale(0.76);
  }
}

@keyframes dynamic-island-music-bar {
  to {
    transform: scaleY(0.45);
  }
}

@media (prefers-reduced-motion: reduce) {
  .phone-dynamic-island,
  .phone-dynamic-island-enter-active,
  .phone-dynamic-island-leave-active,
  .phone-dynamic-island-content-enter-active,
  .phone-dynamic-island-content-leave-active,
  .phone-dynamic-island__action,
  .phone-dynamic-island__waveform i,
  .phone-dynamic-island__progress::after {
    transition: none;
  }

  .phone-dynamic-island__recording-dot,
  .phone-dynamic-island__music-bars i {
    animation: none;
  }
}
</style>
