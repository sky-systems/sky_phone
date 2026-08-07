<script setup lang="ts">
import {
  ArrowUpCircle,
  Bell,
  BellOff,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Copy,
  ImagePlay,
  Images,
  LockKeyhole,
  MessageCirclePlus,
  Mic,
  Plus,
  QrCode,
  Reply,
  Search,
  ShieldCheck,
  ShieldOff,
  Trash2,
  UserMinus,
  UserPlus,
  Video,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import DarkChatVoiceMessage from '@/components/DarkChatVoiceMessage.vue'
import DarkChatSelect, {
  type DarkChatSelectOption,
} from '@/components/DarkChatSelect.vue'
import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import { useAccountStore } from '@/stores/account'
import { useDarkChatStore } from '@/stores/darkchat'
import { useMessagesStore } from '@/stores/messages'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type { DarkChatConversationSummary, DarkChatMessage, DarkChatNotificationMode } from '@/types/darkchat'
import type { GifSearchResult } from '@/types/messages'
import type { MediaType, PhoneMedia } from '@/types/media'
import { copyText } from '@/utils/clipboard'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'

const VOICE_MAX_DURATION_MS = 60_000
const VOICE_MAX_BYTES = 270_000
const WAVEFORM_SAMPLES = 48

const account = useAccountStore()
const darkchat = useDarkChatStore()
const sms = useMessagesStore()
const messageMedia = useMessageMediaStore()
const phone = usePhoneStore()
const router = useRouter()
const screen = ref<'inbox' | 'new' | 'thread' | 'contact' | 'profile'>('inbox')
const search = ref('')
const identifier = ref('')
const pendingIdentifier = ref('')
const safetyOpen = ref(false)
const draft = ref('')
const aliasDraft = ref('')
const contactAliasDraft = ref('')
const notificationMode = ref<DarkChatNotificationMode>('private')
const activityVisible = ref(false)
const attachmentOpen = ref(false)
const emojiOpen = ref(false)
const gifOpen = ref(false)
const gifQuery = ref('')
const gifResults = ref<GifSearchResult[]>([])
const gifOffset = ref(0)
const gifHasMore = ref(true)
const gifLoading = ref(false)
const selectedMessage = ref<DarkChatMessage | null>(null)
const replyTo = ref<DarkChatMessage | null>(null)
const reportOpen = ref(false)
const reportReason = ref('spam')
const reportDetails = ref('')
const toast = ref('')
const sending = ref(false)
const recording = ref(false)
const recordingElapsedMs = ref(0)
const recordingLevels = ref<number[]>(Array(32).fill(0.16))
let toastTimer: ReturnType<typeof setTimeout> | undefined
let gifTimer: ReturnType<typeof setTimeout> | undefined
let recordingTimer: ReturnType<typeof setInterval> | undefined
let mediaRecorder: MediaRecorder | undefined
let mediaStream: MediaStream | undefined
let audioContext: AudioContext | undefined
let analyser: AnalyserNode | undefined
let recordingStartedAt = 0
let recordingChunks: Blob[] = []
let recordingSamples: number[] = []
let recordingBytes = 0
let discardRecording = false

const signedIn = computed(() => Boolean(account.email))
const filteredConversations = computed(() => {
  const needle = search.value.trim().toLocaleLowerCase(phone.lang)
  if (!needle) return darkchat.conversations
  return darkchat.conversations.filter((item) =>
    `${item.peer.alias} ${item.peer.darkId} ${preview(item)}`.toLocaleLowerCase(phone.lang).includes(needle),
  )
})
const active = computed(() => darkchat.activeConversation)
const attachmentPanelOpen = computed(() => emojiOpen.value || gifOpen.value)
const timerOptions = [0, -1, 60, 300, 3600, 86400, 604800]

function t(key: string, params?: Record<string, string>): string {
  return phone.t(`Apps.darkchat.${key}`, params)
}

function showToast(value: string): void {
  if (toastTimer) clearTimeout(toastTimer)
  toast.value = value
  toastTimer = setTimeout(() => (toast.value = ''), 2800)
}

function errorText(error?: string): string {
  return t(`errors.${error ?? 'default'}`)
}

function avatarGradient(seed: number): string {
  const hue = Math.abs(seed || 1) % 360
  return `linear-gradient(145deg,hsl(${hue} 72% 62%),hsl(${(hue + 54) % 360} 70% 35%))`
}

function avatarGlyph(seed: number): string {
  const glyphs = ['◉', '◇', '△', '⬡', '✦', '◎', '◈', '⬢']
  return glyphs[Math.abs(seed || 0) % glyphs.length]
}

function preview(conversation: DarkChatConversationSummary): string {
  if (conversation.lastMessage === 'message_deleted') return t('messageDeleted')
  if (conversation.lastMessageType === 'voice') return `🎙 ${t('voiceMessage')}`
  if (conversation.lastMessageType === 'gif') return `GIF · ${t('gif')}`
  if (conversation.lastMessageType === 'image') return `📷 ${t('photo')}`
  if (conversation.lastMessageType === 'video') return `▶ ${t('video')}`
  if (conversation.lastMessageType === 'system') return t('securityUpdate')
  return conversation.lastMessage
}

function formatDate(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return ''
  const today = new Date()
  if (date.toDateString() === today.toDateString()) {
    return new Intl.DateTimeFormat(phone.lang, { hour: '2-digit', minute: '2-digit' }).format(date)
  }
  return new Intl.DateTimeFormat(phone.lang, { day: '2-digit', month: '2-digit' }).format(date)
}

function dayLabel(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(phone.lang, { day: 'numeric', month: 'long' }).format(date)
}

function timerLabel(seconds: number): string {
  const keys: Record<number, string> = {
    0: 'timerOff',
    [-1]: 'timerAfterRead',
    60: 'timerMinute',
    300: 'timerFiveMinutes',
    3600: 'timerHour',
    86400: 'timerDay',
    604800: 'timerWeek',
  }
  return t(keys[seconds] ?? 'timerOff')
}

const disappearingOptions = computed<DarkChatSelectOption[]>(() =>
  timerOptions.map((value) => ({ label: timerLabel(value), value })),
)
const notificationOptions = computed<DarkChatSelectOption[]>(() => [
  { label: t('notificationFull'), value: 'full' },
  { label: t('notificationPrivate'), value: 'private' },
  { label: t('notificationHidden'), value: 'hidden' },
])
const reportOptions = computed<DarkChatSelectOption[]>(() => [
  { label: t('reportSpam'), value: 'spam' },
  { label: t('reportHarassment'), value: 'harassment' },
  { label: t('reportThreats'), value: 'threats' },
  { label: t('reportIllegal'), value: 'illegal' },
  { label: t('reportOther'), value: 'other' },
])

function systemText(body: string): string {
  if (body === 'message_deleted') return t('messageDeleted')
  if (body.startsWith('timer_changed:')) return t('timerChanged', { timer: timerLabel(Number(body.split(':')[1])) })
  return t('securityUpdate')
}

async function scrollBottom(animate = true): Promise<void> {
  await nextTick()
  const area = document.querySelector<HTMLElement>('.darkchat-thread__messages')
  area?.scrollTo({ behavior: animate ? 'smooth' : 'auto', top: area.scrollHeight })
}

async function openConversation(conversationId: string): Promise<void> {
  if (!(await darkchat.openThread(conversationId))) {
    showToast(errorText(darkchat.lastError ?? undefined))
    return
  }
  screen.value = 'thread'
  resetPanels()
  await scrollBottom(false)
}

function back(): void {
  if (screen.value === 'contact') {
    screen.value = 'thread'
    return
  }
  if (screen.value === 'thread') darkchat.closeThread()
  screen.value = 'inbox'
  resetPanels()
}

function resetPanels(): void {
  attachmentOpen.value = false
  emojiOpen.value = false
  gifOpen.value = false
  selectedMessage.value = null
  replyTo.value = null
  safetyOpen.value = false
  reportOpen.value = false
}

function requestStart(value = identifier.value): void {
  const clean = value.trim()
  if (!clean) return
  pendingIdentifier.value = clean
  safetyOpen.value = true
}

async function confirmStart(): Promise<void> {
  const response = await darkchat.start(pendingIdentifier.value)
  safetyOpen.value = false
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  identifier.value = ''
  await openConversation(response.data.conversationId)
}

async function sendText(): Promise<void> {
  const body = draft.value.trim()
  if (!body || sending.value) return
  draft.value = ''
  const outgoingReply = replyTo.value?.id
  replyTo.value = null
  resetPanels()
  sending.value = true
  const response = await darkchat.send({ body, messageType: 'text', replyToId: outgoingReply })
  sending.value = false
  if (!response.success) showToast(errorText(response.error))
  await scrollBottom()
}

function appendEmoji(emoji: string): void {
  draft.value += emoji
}

async function loadGifs(reset = false): Promise<void> {
  if (gifLoading.value || (!reset && !gifHasMore.value)) return
  gifLoading.value = true
  const response = await sms.searchGifs(gifQuery.value, reset ? 0 : gifOffset.value)
  gifLoading.value = false
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  const ids = new Set(reset ? [] : gifResults.value.map((gif) => gif.id))
  const unique = response.data.results.filter((gif) => !ids.has(gif.id) && Boolean(ids.add(gif.id)))
  gifResults.value = reset ? unique : [...gifResults.value, ...unique]
  gifOffset.value = response.data.nextOffset
  gifHasMore.value = response.data.hasMore
}

function queueGifSearch(): void {
  if (gifTimer) clearTimeout(gifTimer)
  gifTimer = setTimeout(() => void loadGifs(true), 320)
}

async function sendGif(gif: GifSearchResult): Promise<void> {
  gifOpen.value = false
  sending.value = true
  const response = await darkchat.send({ messageType: 'gif', mediaPayload: gif.url, replyToId: replyTo.value?.id })
  sending.value = false
  replyTo.value = null
  if (!response.success) showToast(errorText(response.error))
  await scrollBottom()
}

function openMediaApp(app: 'camera' | 'photos', mediaType: MediaType): void {
  if (!active.value) {
    console.error('[DarkChat] Cannot attach media without an active conversation.')
    return
  }
  attachmentOpen.value = false
  emojiOpen.value = false
  gifOpen.value = false
  messageMedia.begin(`darkchat:${active.value.id}`, mediaType, '/apps/darkchat')
  void router.push({
    path: `/apps/${app}`,
    query: { messageAttachment: mediaType },
  })
}

async function sendAttachment(media: PhoneMedia): Promise<void> {
  if (!active.value || sending.value) return
  sending.value = true
  const response = await darkchat.send({
    mediaAssetId: import.meta.env.DEV ? media.url : String(media.id),
    mediaPreviewUrl: media.url,
    messageType: media.mediaType === 'photo' ? 'image' : 'video',
  })
  sending.value = false
  if (!response.success) showToast(errorText(response.error))
  await scrollBottom()
}

function copyMessage(message: DarkChatMessage): void {
  selectedMessage.value = null
  showToast(copyText(message.body) ? t('copied') : errorText())
}

async function react(message: DarkChatMessage, reaction: string): Promise<void> {
  await darkchat.mutate('react', { messageId: message.id, reaction })
  selectedMessage.value = null
  if (active.value) await darkchat.openThread(active.value.id)
}

async function messageAction(message: DarkChatMessage, action: 'delete_me' | 'delete_all'): Promise<void> {
  const success = await darkchat.mutate('message-action', { messageId: message.id, action })
  selectedMessage.value = null
  if (!success) showToast(errorText())
  else if (active.value) await darkchat.openThread(active.value.id)
}

function beginReply(message: DarkChatMessage): void {
  replyTo.value = message
  selectedMessage.value = null
}

function beginReport(message?: DarkChatMessage): void {
  if (message) selectedMessage.value = message
  reportReason.value = 'spam'
  reportDetails.value = ''
  reportOpen.value = true
}

async function submitReport(): Promise<void> {
  if (!active.value) return
  const success = await darkchat.mutate('report', {
    conversationId: active.value.id,
    details: reportDetails.value,
    messageId: selectedMessage.value?.id,
    reason: reportReason.value,
  })
  reportOpen.value = false
  selectedMessage.value = null
  showToast(success ? t('reported') : errorText())
}

function openContact(): void {
  if (!active.value) return
  contactAliasDraft.value = active.value.peer.alias
  screen.value = 'contact'
}

async function updateConversation(): Promise<void> {
  if (!active.value) return
  const success = await darkchat.mutate('update-conversation', {
    conversationId: active.value.id,
    disappearingSeconds: active.value.disappearingSeconds,
    notificationsEnabled: active.value.notificationsEnabled,
    readReceipts: active.value.readReceipts,
  })
  if (!success) showToast(errorText())
  else await darkchat.openThread(active.value.id)
}

async function saveContact(): Promise<void> {
  if (!active.value) return
  const endpoint = active.value.peer.isContact ? 'add-contact' : 'add-contact'
  const success = await darkchat.mutate(endpoint, {
    alias: contactAliasDraft.value,
    conversationId: active.value.id,
  })
  showToast(success ? t('contactSaved') : errorText())
  if (success) await darkchat.openThread(active.value.id)
}

async function removeContact(): Promise<void> {
  if (!active.value) return
  const success = await darkchat.mutate('remove-contact', { conversationId: active.value.id })
  if (success) await darkchat.openThread(active.value.id)
}

async function toggleBlock(): Promise<void> {
  if (!active.value) return
  const blocked = !active.value.peer.blocked
  const success = await darkchat.mutate('block', { blocked, conversationId: active.value.id })
  if (success) await darkchat.openThread(active.value.id)
}

async function clearChat(): Promise<void> {
  if (!active.value) return
  if (await darkchat.mutate('clear', { conversationId: active.value.id })) {
    await darkchat.openThread(active.value.id)
    showToast(t('chatCleared'))
  }
}

function openProfile(): void {
  if (!darkchat.profile) return
  aliasDraft.value = darkchat.profile.alias
  notificationMode.value = darkchat.profile.notificationMode
  activityVisible.value = darkchat.profile.activityVisible
  screen.value = 'profile'
}

async function saveProfile(): Promise<void> {
  const response = await darkchat.mutate('update-profile', {
    activityVisible: activityVisible.value,
    alias: aliasDraft.value,
    notificationMode: notificationMode.value,
  })
  if (!response) showToast(errorText('invalid_profile'))
  else {
    await darkchat.refreshInbox()
    screen.value = 'inbox'
  }
}

function selectDisappearing(value: number | string): void {
  if (!active.value) {
    console.error('[DarkChat] Cannot update the timer without an active conversation.')
    return
  }
  active.value.disappearingSeconds = Number(value)
  void updateConversation()
}

function selectNotificationMode(value: number | string): void {
  notificationMode.value = value as DarkChatNotificationMode
}

function selectReportReason(value: number | string): void {
  reportReason.value = String(value)
}

function copyIdentity(value: string): void {
  showToast(copyText(value) ? t('copied') : errorText())
}

function recordingMime(): string | null {
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) return 'audio/webm;codecs=opus'
  if (MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm'
  return null
}

function sampleMicrophone(): void {
  if (!analyser) return
  const values = new Uint8Array(analyser.fftSize)
  analyser.getByteTimeDomainData(values)
  let total = 0
  for (const value of values) total += Math.abs(value - 128) / 128
  const level = Math.max(0.08, Math.min(1, (total / values.length) * 4.5))
  recordingSamples.push(level)
  recordingLevels.value = [...recordingLevels.value.slice(1), level]
  recordingElapsedMs.value = performance.now() - recordingStartedAt
  if (recordingElapsedMs.value >= VOICE_MAX_DURATION_MS) stopRecording()
}

async function startRecording(): Promise<void> {
  resetPanels()
  if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
    showToast(t('microphoneUnavailable'))
    return
  }
  const mime = recordingMime()
  if (!mime) {
    showToast(t('microphoneUnavailable'))
    return
  }
  try {
    mediaStream = await navigator.mediaDevices.getUserMedia({
      audio: { autoGainControl: true, echoCancellation: true, noiseSuppression: true },
    })
    recordingChunks = []
    recordingSamples = []
    recordingBytes = 0
    discardRecording = false
    mediaRecorder = new MediaRecorder(mediaStream, { audioBitsPerSecond: 32_000, mimeType: mime })
    mediaRecorder.addEventListener('dataavailable', (event) => {
      if (!event.data.size) return
      recordingChunks.push(event.data)
      recordingBytes += event.data.size
      if (recordingBytes > VOICE_MAX_BYTES) stopRecording()
    })
    mediaRecorder.addEventListener('stop', () => void finishRecording())
    audioContext = new AudioContext()
    analyser = audioContext.createAnalyser()
    analyser.fftSize = 128
    audioContext.createMediaStreamSource(mediaStream).connect(analyser)
    recordingStartedAt = performance.now()
    recordingElapsedMs.value = 0
    recordingLevels.value = Array(32).fill(0.16)
    recording.value = true
    mediaRecorder.start(250)
    recordingTimer = setInterval(sampleMicrophone, 100)
  }
  catch (error) {
    console.error('[DarkChat] Could not start audio recording:', error)
    cleanupRecording()
    showToast(t('microphoneUnavailable'))
  }
}

function stopRecording(): void {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop()
}

function cancelRecording(): void {
  discardRecording = true
  if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop()
  else cleanupRecording()
}

function cleanupRecording(): void {
  if (recordingTimer) clearInterval(recordingTimer)
  recordingTimer = undefined
  mediaStream?.getTracks().forEach((track) => track.stop())
  void audioContext?.close()
  mediaRecorder = undefined
  mediaStream = undefined
  audioContext = undefined
  analyser = undefined
  recording.value = false
}

function waveform(): number[] {
  if (!recordingSamples.length) return Array(16).fill(0.12)
  const result: number[] = []
  const count = Math.min(WAVEFORM_SAMPLES, recordingSamples.length)
  const bucketSize = recordingSamples.length / count
  for (let index = 0; index < count; index += 1) {
    const bucket = recordingSamples.slice(Math.floor(index * bucketSize), Math.max(1, Math.floor((index + 1) * bucketSize)))
    result.push(Math.max(0.08, Math.min(1, bucket.reduce((sum, value) => sum + value, 0) / bucket.length)))
  }
  return result
}

async function blobBase64(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer())
  let binary = ''
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  }
  return btoa(binary)
}

async function finishRecording(): Promise<void> {
  const duration = Math.min(VOICE_MAX_DURATION_MS, Math.max(300, performance.now() - recordingStartedAt))
  const mime = mediaRecorder?.mimeType ?? 'audio/webm'
  const chunks = recordingChunks
  const levels = waveform()
  const discard = discardRecording
  cleanupRecording()
  if (discard) return
  const blob = new Blob(chunks, { type: mime })
  if (!blob.size || blob.size > VOICE_MAX_BYTES) {
    showToast(t('recordingTooLarge'))
    return
  }
  sending.value = true
  const response = await darkchat.send({
    mediaDurationMs: Math.floor(duration),
    mediaMime: mime,
    mediaPayload: await blobBase64(blob),
    mediaWaveform: levels,
    messageType: 'voice',
    replyToId: replyTo.value?.id,
  })
  sending.value = false
  replyTo.value = null
  if (!response.success) showToast(errorText(response.error))
  await scrollBottom()
}

function recordingTime(): string {
  const seconds = Math.floor(recordingElapsedMs.value / 1000)
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

onMounted(async () => {
  if (signedIn.value) await darkchat.bootstrap()
  if (!active.value) return
  screen.value = 'thread'
  const media = messageMedia.consume(`darkchat:${active.value.id}`)
  if (media) await sendAttachment(media)
})

onBeforeUnmount(() => {
  discardRecording = true
  cleanupRecording()
  if (toastTimer) clearTimeout(toastTimer)
  if (gifTimer) clearTimeout(gifTimer)
})
</script>

<template>
  <main class="darkchat-page">
    <section v-if="!signedIn" class="darkchat-gate">
      <span><LockKeyhole :size="31" /></span>
      <h1>{{ t('name') }}</h1>
      <p>{{ t('signInBody') }}</p>
      <small>{{ t('signInHint') }}</small>
    </section>

    <section v-else-if="darkchat.loading && !darkchat.profile" class="darkchat-gate">
      <span class="darkchat-loader" />
      <p>{{ phone.t('Common.loading') }}</p>
    </section>

    <template v-else-if="darkchat.profile">
      <section v-if="screen === 'inbox'" class="darkchat-inbox">
        <header class="darkchat-inbox__header">
          <button type="button" class="darkchat-pill" @click="openProfile">{{ phone.t('Common.edit') }}</button>
          <strong>{{ t('name') }}</strong>
          <button type="button" class="darkchat-round" :aria-label="t('security')" @click="openProfile">
            <ShieldCheck :size="19" />
          </button>
        </header>
        <div class="darkchat-security-strip">
          <LockKeyhole :size="12" />
          <span>{{ t('privateNetwork') }}</span>
          <button type="button" @click="copyIdentity(darkchat.profile.darkId)">{{ darkchat.profile.darkId }}</button>
        </div>
        <div v-if="filteredConversations.length" class="darkchat-conversations">
          <button
            v-for="conversation in filteredConversations"
            :key="conversation.id"
            type="button"
            class="darkchat-conversation"
            @click="openConversation(conversation.id)"
          >
            <i v-if="conversation.unread" class="darkchat-unread" />
            <span class="darkchat-avatar" :style="{ background: avatarGradient(conversation.peer.avatarSeed) }">
              {{ avatarGlyph(conversation.peer.avatarSeed) }}
            </span>
            <span class="darkchat-conversation__body">
              <span><strong>{{ conversation.peer.alias }}</strong><time>{{ formatDate(conversation.lastMessageAt) }}</time><ChevronRight :size="14" /></span>
              <small>{{ preview(conversation) }}</small>
            </span>
            <Clock3 v-if="conversation.disappearingSeconds !== 0" class="darkchat-timer-icon" :size="12" />
          </button>
        </div>
        <div v-else class="darkchat-empty">
          <span><ShieldCheck :size="28" /></span>
          <h2>{{ search ? t('noResults') : t('noChats') }}</h2>
          <p>{{ search ? t('noResultsBody') : t('noChatsBody') }}</p>
        </div>
        <footer class="darkchat-inbox__toolbar">
          <label><Search :size="18" /><input v-model="search" type="search" :placeholder="phone.t('Common.search')" /></label>
          <button type="button" class="darkchat-round darkchat-round--large" :aria-label="t('newChat')" @click="screen = 'new'">
            <MessageCirclePlus :size="20" />
          </button>
        </footer>
      </section>

      <section v-else-if="screen === 'new'" class="darkchat-sheet-page">
        <header><button type="button" class="darkchat-round darkchat-back" :aria-label="phone.t('Common.back')" @click="back"><ChevronLeft :size="28" :stroke-width="2.35" /></button><strong>{{ t('newChat') }}</strong><i /></header>
        <div class="darkchat-new-hero">
          <span><QrCode :size="28" /></span>
          <h2>{{ t('connectPrivately') }}</h2>
          <p>{{ t('newChatBody') }}</p>
        </div>
        <label class="darkchat-input"><span>{{ t('darkIdOrInvite') }}</span><input v-model="identifier" autocomplete="off" placeholder="dark:7X4K-P92D" @keydown.enter.prevent="requestStart()" /></label>
        <button type="button" class="darkchat-primary" :disabled="!identifier.trim()" @click="requestStart()">{{ t('continue') }}</button>
        <h3>{{ t('contacts') }}</h3>
        <button v-for="contact in darkchat.contacts" :key="contact.id" type="button" class="darkchat-contact-row" @click="requestStart(contact.darkId)">
          <span class="darkchat-avatar darkchat-avatar--small" :style="{ background: avatarGradient(contact.avatarSeed) }">{{ avatarGlyph(contact.avatarSeed) }}</span>
          <span><strong>{{ contact.alias }}</strong><small>{{ contact.darkId }}</small></span><ChevronRight :size="15" />
        </button>
        <div class="darkchat-qr-card">
          <div class="darkchat-faux-qr"><QrCode :size="62" /></div>
          <span><strong>{{ darkchat.profile.darkId }}</strong><small>{{ t('shareIdentity') }}</small></span>
          <button type="button" @click="copyIdentity(darkchat.profile.inviteCode)"><Copy :size="16" /> {{ darkchat.profile.inviteCode }}</button>
        </div>
      </section>

      <section v-else-if="screen === 'thread' && active" class="darkchat-thread" :class="{ 'darkchat-thread--panel': attachmentPanelOpen }">
        <header class="darkchat-thread__header">
          <button type="button" class="darkchat-round darkchat-back" :aria-label="phone.t('Common.back')" @click="back"><ChevronLeft :size="28" :stroke-width="2.35" /></button>
          <button type="button" class="darkchat-thread__identity" @click="openContact">
            <span class="darkchat-avatar darkchat-avatar--header" :style="{ background: avatarGradient(active.peer.avatarSeed) }">{{ avatarGlyph(active.peer.avatarSeed) }}</span>
            <span><strong>{{ active.peer.alias }}</strong><small>{{ active.peer.activityVisible ? t('activeNow') : t('encryptedSession') }}</small></span>
            <ChevronRight :size="13" />
          </button>
        </header>
        <div class="darkchat-thread__meta"><LockKeyhole :size="11" /> {{ t('serverPrivate') }}<span v-if="active.disappearingSeconds !== 0"> · {{ timerLabel(active.disappearingSeconds) }}</span></div>
        <div class="darkchat-thread__messages">
          <div class="darkchat-day">{{ dayLabel(active.createdAt) }}</div>
          <template v-for="message in darkchat.messages" :key="message.clientId ?? message.id">
            <div v-if="message.messageType === 'system'" class="darkchat-system"><ShieldCheck :size="12" />{{ systemText(message.body) }}</div>
            <button
              v-else
              type="button"
              class="darkchat-message"
              :class="[`darkchat-message--${message.direction}`, { 'darkchat-message--failed': message.deliveryStatus === 'failed' }]"
              @click="selectedMessage = message"
            >
              <span v-if="message.replyBody" class="darkchat-reply-preview"><Reply :size="10" />{{ message.replyBody }}</span>
              <img v-if="message.messageType === 'gif' || message.messageType === 'image'" :src="message.mediaPayload || undefined" :alt="message.messageType === 'gif' ? 'GIF' : t('photo')" />
              <video v-else-if="message.messageType === 'video'" :src="message.mediaPayload || undefined" controls playsinline preload="metadata" />
              <DarkChatVoiceMessage v-else-if="message.messageType === 'voice'" :message="message" />
              <span v-else>{{ message.body }}</span>
              <span v-if="Object.keys(message.reactions).length" class="darkchat-reactions">{{ Object.values(message.reactions).join(' ') }}</span>
              <small>{{ formatDate(message.createdAt) }}<template v-if="message.direction === 'sent'"> · {{ message.deliveryStatus === 'sending' ? t('sending') : message.deliveryStatus === 'failed' ? t('failed') : message.readAt ? t('read') : t('delivered') }}</template></small>
            </button>
          </template>
        </div>

        <div v-if="replyTo" class="darkchat-replying"><Reply :size="14" /><span><small>{{ t('replying') }}</small><strong>{{ replyTo.body || t(replyTo.messageType) }}</strong></span><button type="button" @click="replyTo = null"><X :size="15" /></button></div>
        <div v-if="attachmentOpen" class="darkchat-actions-bubbles">
          <button type="button" @click="openMediaApp('photos', 'photo')"><span><Images :size="18" /></span>{{ t('attachPhoto') }}</button>
          <button type="button" @click="openMediaApp('camera', 'photo')"><span><Camera :size="18" /></span>{{ t('takePhoto') }}</button>
          <button type="button" @click="attachmentOpen = false; emojiOpen = true"><span>😀</span>{{ t('emoji') }}</button>
          <button type="button" @click="attachmentOpen = false; gifOpen = true; loadGifs(true)"><span><ImagePlay :size="18" /></span>{{ t('attachGif') }}</button>
          <button type="button" @click="openMediaApp('photos', 'video')"><span><Video :size="18" /></span>{{ t('attachVideo') }}</button>
        </div>
        <div v-if="gifOpen" class="darkchat-gif-panel">
          <header><strong>{{ t('gifs') }}</strong><button type="button" @click="gifOpen = false">{{ phone.t('Common.done') }}</button></header>
          <label><Search :size="14" /><input v-model="gifQuery" type="search" :placeholder="t('searchGifs')" @input="queueGifSearch" /></label>
          <div><button v-for="gif in gifResults" :key="gif.id" type="button" @click="sendGif(gif)"><img :src="gif.previewUrl" :alt="gif.title" /></button></div>
          <button v-if="gifHasMore && !gifLoading" type="button" class="darkchat-load-more" @click="loadGifs()">{{ t('loadMore') }}</button>
          <span v-if="gifLoading" class="darkchat-loader darkchat-loader--small" />
        </div>
        <FullEmojiPicker v-if="emojiOpen" @close="emojiOpen = false" @pick="appendEmoji" />
        <div v-if="recording" class="darkchat-recorder">
          <button type="button" @click="cancelRecording"><X :size="18" /></button><i /><time>{{ recordingTime() }}</time>
          <span><b v-for="(level, index) in recordingLevels" :key="index" :style="{ height: `${Math.max(3, level * 23)}px` }" /></span>
          <button type="button" @click="stopRecording"><ArrowUpCircle :size="27" /></button>
        </div>
        <footer v-else class="darkchat-composer">
          <button type="button" class="darkchat-round" :class="{ active: attachmentOpen || attachmentPanelOpen }" @click="attachmentOpen = !attachmentOpen; emojiOpen = false; gifOpen = false"><Plus :size="22" /></button>
          <label><textarea v-model="draft" rows="1" :placeholder="t('message')" @keydown.enter.exact.prevent="sendText" /><button v-if="draft.trim()" type="button" @click="sendText"><ArrowUpCircle :size="25" /></button><button v-else type="button" @click="startRecording"><Mic :size="19" /></button></label>
        </footer>
      </section>

      <section v-else-if="screen === 'contact' && active" class="darkchat-sheet-page darkchat-contact-settings">
        <header><button type="button" class="darkchat-round darkchat-back" :aria-label="phone.t('Common.back')" @click="back"><ChevronLeft :size="28" :stroke-width="2.35" /></button><strong>{{ t('contactSecurity') }}</strong><i /></header>
        <div class="darkchat-profile-hero">
          <span class="darkchat-avatar" :style="{ background: avatarGradient(active.peer.avatarSeed) }">{{ avatarGlyph(active.peer.avatarSeed) }}</span>
          <h2>{{ active.peer.alias }}</h2><button type="button" @click="copyIdentity(active.peer.darkId)">{{ active.peer.darkId }} <Copy :size="12" /></button>
          <small>{{ t('chatSince', { date: dayLabel(active.createdAt) }) }}</small>
        </div>
        <div class="darkchat-settings-group">
          <label><span><Bell :size="17" />{{ t('notifications') }}</span><input v-model="active.notificationsEnabled" type="checkbox" @change="updateConversation" /></label>
          <label><span><Check :size="17" />{{ t('readReceipts') }}</span><input v-model="active.readReceipts" type="checkbox" @change="updateConversation" /></label>
          <div class="darkchat-select"><span><Clock3 :size="17" />{{ t('disappearing') }}</span><DarkChatSelect :model-value="active.disappearingSeconds" :options="disappearingOptions" :label="t('disappearing')" @update:model-value="selectDisappearing" /></div>
        </div>
        <label class="darkchat-input"><span>{{ t('contactAlias') }}</span><input v-model="contactAliasDraft" maxlength="32" /></label>
        <button type="button" class="darkchat-primary" @click="saveContact"><UserPlus :size="16" />{{ active.peer.isContact ? t('saveContact') : t('addContact') }}</button>
        <div class="darkchat-danger-group">
          <button v-if="active.peer.isContact" type="button" @click="removeContact"><UserMinus :size="17" />{{ t('removeContact') }}</button>
          <button type="button" @click="toggleBlock"><ShieldOff :size="17" />{{ active.peer.blocked ? t('unblock') : t('block') }}</button>
          <button type="button" @click="beginReport()"><BellOff :size="17" />{{ t('report') }}</button>
          <button type="button" @click="clearChat"><Trash2 :size="17" />{{ t('clearChat') }}</button>
        </div>
      </section>

      <section v-else-if="screen === 'profile'" class="darkchat-sheet-page darkchat-profile-settings">
        <header><button type="button" class="darkchat-round darkchat-back" :aria-label="phone.t('Common.back')" @click="back"><ChevronLeft :size="28" :stroke-width="2.35" /></button><strong>{{ t('myIdentity') }}</strong><button type="button" class="darkchat-save" @click="saveProfile">{{ phone.t('Common.done') }}</button></header>
        <div class="darkchat-profile-hero">
          <span class="darkchat-avatar" :style="{ background: avatarGradient(darkchat.profile.avatarSeed) }">{{ avatarGlyph(darkchat.profile.avatarSeed) }}</span>
          <h2>{{ darkchat.profile.alias }}</h2><button type="button" @click="copyIdentity(darkchat.profile.darkId)">{{ darkchat.profile.darkId }} <Copy :size="12" /></button>
        </div>
        <label class="darkchat-input"><span>{{ t('alias') }}</span><input v-model="aliasDraft" maxlength="32" /></label>
        <div class="darkchat-settings-group">
          <div class="darkchat-select"><span><Bell :size="17" />{{ t('notificationPrivacy') }}</span><DarkChatSelect :model-value="notificationMode" :options="notificationOptions" :label="t('notificationPrivacy')" @update:model-value="selectNotificationMode" /></div>
          <label><span><ShieldCheck :size="17" />{{ t('shareActivity') }}</span><input v-model="activityVisible" type="checkbox" /></label>
        </div>
        <div class="darkchat-qr-card">
          <div class="darkchat-faux-qr"><QrCode :size="62" /></div>
          <span><strong>{{ darkchat.profile.inviteCode }}</strong><small>{{ t('inviteCode') }}</small></span>
          <button type="button" @click="copyIdentity(darkchat.profile.inviteCode)"><Copy :size="16" />{{ t('copyInvite') }}</button>
        </div>
        <p class="darkchat-privacy-note"><LockKeyhole :size="15" />{{ t('privacyDisclaimer') }}</p>
      </section>
    </template>

    <div v-if="safetyOpen" class="darkchat-modal-backdrop">
      <section class="darkchat-modal"><span class="darkchat-modal__icon"><ShieldCheck :size="25" /></span><h2>{{ t('unknownIdentity') }}</h2><p>{{ t('unknownIdentityBody') }}</p><strong>{{ pendingIdentifier }}</strong><button type="button" class="darkchat-primary" @click="confirmStart">{{ t('openSecureChat') }}</button><button type="button" @click="safetyOpen = false">{{ phone.t('Common.cancel') }}</button></section>
    </div>

    <div v-if="selectedMessage" class="darkchat-modal-backdrop" @click.self="selectedMessage = null">
      <section class="darkchat-message-menu">
        <div class="darkchat-reaction-row"><button v-for="reaction in ['❤️','👍','👎','😂','‼️','❓']" :key="reaction" type="button" @click="react(selectedMessage!, reaction)">{{ reaction }}</button></div>
        <button type="button" @click="beginReply(selectedMessage)"><Reply :size="17" />{{ t('reply') }}</button>
        <button v-if="selectedMessage.messageType === 'text' || selectedMessage.messageType === 'emoji'" type="button" @click="copyMessage(selectedMessage)"><Copy :size="17" />{{ t('copy') }}</button>
        <button type="button" @click="messageAction(selectedMessage, 'delete_me')"><Trash2 :size="17" />{{ t('deleteForMe') }}</button>
        <button v-if="selectedMessage.direction === 'sent'" type="button" class="danger" @click="messageAction(selectedMessage, 'delete_all')"><Trash2 :size="17" />{{ t('deleteForBoth') }}</button>
        <button v-if="selectedMessage.direction === 'received'" type="button" class="danger" @click="beginReport(selectedMessage)"><ShieldOff :size="17" />{{ t('report') }}</button>
        <button type="button" @click="selectedMessage = null">{{ phone.t('Common.cancel') }}</button>
      </section>
    </div>

    <div v-if="reportOpen" class="darkchat-modal-backdrop">
      <section class="darkchat-modal"><span class="darkchat-modal__icon darkchat-modal__icon--danger"><ShieldOff :size="25" /></span><h2>{{ t('reportUser') }}</h2><DarkChatSelect class="darkchat-report-select" :model-value="reportReason" :options="reportOptions" :label="t('reportUser')" @update:model-value="selectReportReason" /><textarea v-model="reportDetails" maxlength="500" :placeholder="t('reportDetails')" /><button type="button" class="darkchat-danger" @click="submitReport">{{ t('submitReport') }}</button><button type="button" @click="reportOpen = false; selectedMessage = null">{{ phone.t('Common.cancel') }}</button></section>
    </div>

    <Transition name="darkchat-toast"><div v-if="toast" class="darkchat-toast">{{ toast }}</div></Transition>
  </main>
</template>
