<script setup lang="ts">
import {
  kButton,
  kCard,
  kDialog,
  kDialogButton,
  kGlass,
  kLink,
  kList,
  kListInput,
  kListItem,
  kMessagebar,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPreloader,
  kSearchbar,
  kSheet,
  kToast,
  kToggle,
} from 'konsta/vue'
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
import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import { useAccountStore } from '@/stores/account'
import { useDarkChatStore } from '@/stores/darkchat'
import { useMessagesStore } from '@/stores/messages'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type {
  DarkChatConversationSummary,
  DarkChatMessage,
  DarkChatNotificationMode,
} from '@/types/darkchat'
import type { GifSearchResult } from '@/types/messages'
import type { MediaType, PhoneMedia } from '@/types/media'
import { copyText } from '@/utils/clipboard'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'

const VOICE_MAX_DURATION_MS = 60_000
const VOICE_MAX_BYTES = 270_000
const WAVEFORM_SAMPLES = 48
type DarkChatSelectOption = {
  label: string
  value: number | string
}
type SelectionSheet = 'disappearing' | 'notification' | 'report'
const darkNavbarColors = {
  bgIos: 'bg-black',
  textIos: 'text-white',
}
const darkInputColors = {
  bgIos: 'bg-transparent',
  labelTextFocusIos: 'text-[#0a84ff]',
  labelTextIos: 'text-[#b8b8bd]',
}
const darkMessagebarColors = {
  bgIos: 'bg-black',
  inputBgIos: 'bg-[#1c1c1e]',
  placeholderIos: 'placeholder-[#8e8e93]',
  toolbarIconIos: 'fill-[#0a84ff]',
}
const darkSheetColors = {
  bgIos: 'bg-[#111113]',
}
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
const selectionSheet = ref<SelectionSheet | null>(null)
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
    `${item.peer.alias} ${item.peer.darkId} ${preview(item)}`
      .toLocaleLowerCase(phone.lang)
      .includes(needle),
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
  return `hsl(${hue} 45% 45%)`
}

function avatarGlyph(seed: number): string {
  const glyphs = ['◉', '◇', '△', '⬡', '✦', '◎', '◈', '⬢']
  return glyphs[Math.abs(seed || 0) % glyphs.length]
}

function inputValue(event: Event): string {
  return (event.target as HTMLInputElement | HTMLTextAreaElement).value
}

function setSearch(event: Event): void {
  search.value = inputValue(event)
}

function setIdentifier(event: Event): void {
  identifier.value = inputValue(event)
}

function setDraft(event: Event): void {
  draft.value = inputValue(event)
}

function setAliasDraft(event: Event): void {
  aliasDraft.value = inputValue(event)
}

function setContactAliasDraft(event: Event): void {
  contactAliasDraft.value = inputValue(event)
}

function setReportDetails(event: Event): void {
  reportDetails.value = inputValue(event)
}

function setConversationNotifications(event: Event): void {
  if (!active.value) return
  active.value.notificationsEnabled = (event.target as HTMLInputElement).checked
  void updateConversation()
}

function setReadReceipts(event: Event): void {
  if (!active.value) return
  active.value.readReceipts = (event.target as HTMLInputElement).checked
  void updateConversation()
}

function setActivityVisible(event: Event): void {
  activityVisible.value = (event.target as HTMLInputElement).checked
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
    return new Intl.DateTimeFormat(phone.lang, {
      hour: '2-digit',
      hourCycle: 'h23',
      minute: '2-digit',
    }).format(date)
  }
  return new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    month: '2-digit',
  }).format(date)
}

function dayLabel(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
  }).format(date)
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
const selectionOptions = computed<DarkChatSelectOption[]>(() => {
  if (selectionSheet.value === 'disappearing') return disappearingOptions.value
  if (selectionSheet.value === 'notification') return notificationOptions.value
  if (selectionSheet.value === 'report') return reportOptions.value
  return []
})
const selectionTitle = computed(() => {
  if (selectionSheet.value === 'disappearing') return t('disappearing')
  if (selectionSheet.value === 'notification') return t('notificationPrivacy')
  return t('reportUser')
})
const selectionValue = computed<number | string>(() => {
  if (selectionSheet.value === 'disappearing')
    return active.value?.disappearingSeconds ?? 0
  if (selectionSheet.value === 'notification') return notificationMode.value
  return reportReason.value
})

function systemText(body: string): string {
  if (body === 'message_deleted') return t('messageDeleted')
  if (body.startsWith('timer_changed:'))
    return t('timerChanged', { timer: timerLabel(Number(body.split(':')[1])) })
  return t('securityUpdate')
}

async function scrollBottom(animate = true): Promise<void> {
  await nextTick()
  const area = document.querySelector<HTMLElement>('.darkchat-thread__messages')
  area?.scrollTo({
    behavior: animate ? 'smooth' : 'auto',
    top: area.scrollHeight,
  })
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

function openEmojiPanel(): void {
  attachmentOpen.value = false
  gifOpen.value = false
  emojiOpen.value = true
}

function openGifPanel(): void {
  attachmentOpen.value = false
  emojiOpen.value = false
  gifOpen.value = true
  void loadGifs(true)
}

function updateGifSearch(event: Event): void {
  gifQuery.value = inputValue(event)
  queueGifSearch()
}

function clearGifSearch(): void {
  gifQuery.value = ''
  queueGifSearch()
}

function toggleAttachmentPanel(): void {
  attachmentOpen.value = !attachmentOpen.value
  emojiOpen.value = false
  gifOpen.value = false
}

function closeReport(): void {
  reportOpen.value = false
  selectedMessage.value = null
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
  const response = await darkchat.send({
    body,
    messageType: 'text',
    replyToId: outgoingReply,
  })
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
  const response = await sms.searchGifs(
    gifQuery.value,
    reset ? 0 : gifOffset.value,
  )
  gifLoading.value = false
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  const ids = new Set(reset ? [] : gifResults.value.map((gif) => gif.id))
  const unique = response.data.results.filter(
    (gif) => !ids.has(gif.id) && Boolean(ids.add(gif.id)),
  )
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
  const response = await darkchat.send({
    messageType: 'gif',
    mediaPayload: gif.url,
    replyToId: replyTo.value?.id,
  })
  sending.value = false
  replyTo.value = null
  if (!response.success) showToast(errorText(response.error))
  await scrollBottom()
}

function openMediaApp(app: 'camera' | 'photos', mediaType: MediaType): void {
  if (!active.value) {
    console.error(
      '[DarkChat] Cannot attach media without an active conversation.',
    )
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

async function react(
  message: DarkChatMessage,
  reaction: string,
): Promise<void> {
  await darkchat.mutate('react', { messageId: message.id, reaction })
  selectedMessage.value = null
  if (active.value) await darkchat.openThread(active.value.id)
}

async function messageAction(
  message: DarkChatMessage,
  action: 'delete_me' | 'delete_all',
): Promise<void> {
  const success = await darkchat.mutate('message-action', {
    messageId: message.id,
    action,
  })
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
  const success = await darkchat.mutate('remove-contact', {
    conversationId: active.value.id,
  })
  if (success) await darkchat.openThread(active.value.id)
}

async function toggleBlock(): Promise<void> {
  if (!active.value) return
  const blocked = !active.value.peer.blocked
  const success = await darkchat.mutate('block', {
    blocked,
    conversationId: active.value.id,
  })
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
    console.error(
      '[DarkChat] Cannot update the timer without an active conversation.',
    )
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

function chooseSelection(value: number | string): void {
  if (selectionSheet.value === 'disappearing') selectDisappearing(value)
  else if (selectionSheet.value === 'notification')
    selectNotificationMode(value)
  else if (selectionSheet.value === 'report') selectReportReason(value)
  selectionSheet.value = null
}

function copyIdentity(value: string): void {
  showToast(copyText(value) ? t('copied') : errorText())
}

function recordingMime(): string | null {
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus'))
    return 'audio/webm;codecs=opus'
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
  if (
    !navigator.mediaDevices?.getUserMedia ||
    typeof MediaRecorder === 'undefined'
  ) {
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
      audio: {
        autoGainControl: true,
        echoCancellation: true,
        noiseSuppression: true,
      },
    })
    recordingChunks = []
    recordingSamples = []
    recordingBytes = 0
    discardRecording = false
    mediaRecorder = new MediaRecorder(mediaStream, {
      audioBitsPerSecond: 32_000,
      mimeType: mime,
    })
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
  } catch (error) {
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
    const bucket = recordingSamples.slice(
      Math.floor(index * bucketSize),
      Math.max(1, Math.floor((index + 1) * bucketSize)),
    )
    result.push(
      Math.max(
        0.08,
        Math.min(
          1,
          bucket.reduce((sum, value) => sum + value, 0) / bucket.length,
        ),
      ),
    )
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
  const duration = Math.min(
    VOICE_MAX_DURATION_MS,
    Math.max(300, performance.now() - recordingStartedAt),
  )
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

<style scoped>
.dc-ios {
  --dc-accent: #0a84ff;
  --dc-surface: #1c1c1e;
  --dc-surface-raised: #2c2c2e;
  --dc-border: rgb(255 255 255 / 14%);
  --dc-label: #fff;
  --dc-secondary: #b8b8bd;
  --dc-tertiary: #8e8e93;
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 0;
  padding: 44px 0 0;
  overflow: hidden;
  color: var(--dc-label);
  color-scheme: dark;
  background: #000;
  font-family:
    -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif;
}

.dc-ios button,
.dc-ios input,
.dc-ios textarea {
  font: inherit;
}

.dc-ios :deep(.bg-ios-light-glass) {
  background: rgb(44 44 46 / 88%) !important;
  box-shadow: 0 0 0 0.5px rgb(255 255 255 / 12%) inset !important;
}

.dc-screen,
.dc-gate {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow-x: hidden;
}

.dc-navbar {
  z-index: 20;
  flex: 0 0 auto;
  border-bottom: 0.5px solid var(--dc-border);
  color: var(--dc-label) !important;
  background: #000;
}

.dc-navbar > div:nth-child(2) {
  background-image: linear-gradient(
    to bottom,
    #1c1c1e 0%,
    #000 100%
  ) !important;
}

.dc-navbar :deep(button),
.dc-navbar :deep(a) {
  color: var(--dc-accent);
  font-size: 15px;
}

.dc-navbar :deep([class*='title']) {
  letter-spacing: -0.2px;
}

.dc-gate {
  display: grid;
  place-items: center;
  padding: 22px;
  text-align: center;
}

.dc-gate-card {
  width: 100%;
  margin: 0;
  padding: 24px 18px;
  border-color: var(--dc-border);
  border-radius: 20px;
  background: var(--dc-surface);
}

.dc-gate h1,
.dc-hero h2,
.dc-empty h2,
.dc-profile-hero h2 {
  margin: 12px 0 5px;
  color: var(--dc-label);
  font-size: 21px;
  font-weight: 700;
  letter-spacing: -0.35px;
}

.dc-gate p,
.dc-hero p,
.dc-empty p {
  margin: 0;
  color: var(--dc-secondary);
  font-size: 14px;
  line-height: 1.45;
}

.dc-gate small {
  display: block;
  margin-top: 12px;
  color: var(--dc-tertiary);
  font-size: 12px;
  line-height: 1.4;
}

.dc-icon-tile {
  display: inline-flex;
  width: 54px;
  height: 54px;
  align-items: center;
  justify-content: center;
  border-radius: 15px;
  color: var(--dc-accent);
  background: rgb(10 132 255 / 14%);
}

.dc-preloader {
  color: var(--dc-accent);
}

.dc-inbox,
.dc-thread,
.dc-scroll-screen {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.dc-inbox-content,
.dc-scroll-content {
  min-height: 0;
  overflow: auto;
  scrollbar-width: none;
}

.dc-inbox-content::-webkit-scrollbar,
.dc-scroll-content::-webkit-scrollbar,
.dc-messages::-webkit-scrollbar {
  display: none;
}

.dc-inbox-content {
  flex: 1;
  padding: 10px 0 84px;
}

.dc-security {
  display: flex;
  width: calc(100% - 24px);
  min-height: 52px;
  margin: 0 12px 10px;
  padding: 8px 12px;
  align-items: center;
  gap: 10px;
  border: 0.5px solid var(--dc-border);
  border-radius: 14px;
  color: var(--dc-label);
  text-align: left;
  background: rgb(28 28 30 / 88%);
}

.dc-security > span {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.dc-security strong {
  font-size: 13px;
  font-weight: 600;
}

.dc-security small {
  margin-top: 2px;
  overflow: hidden;
  color: var(--dc-secondary);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-security > svg:first-child,
.dc-security > svg:last-child {
  flex: 0 0 auto;
  color: var(--dc-accent);
}

.dc-search {
  margin: 0 7px 8px;
}

.dc-search :deep(input) {
  color: var(--dc-label);
  font-size: 15px;
}

.dc-search :deep(input::placeholder) {
  color: var(--dc-tertiary);
  opacity: 1;
}

.dc-conversation-list,
.dc-contact-list,
.dc-settings-list,
.dc-form-list,
.dc-danger-list,
.dc-action-list {
  margin-top: 8px;
  margin-bottom: 16px;
}

.dc-conversation-list :deep(ul),
.dc-contact-list :deep(ul),
.dc-settings-list :deep(ul),
.dc-form-list :deep(ul),
.dc-danger-list :deep(ul),
.dc-action-list :deep(ul) {
  background: var(--dc-surface);
}

.dc-conversation :deep(button) {
  min-height: 72px;
  width: 100%;
  text-align: left;
}

.dc-conversation :deep([class*='title']),
.dc-contact-list :deep([class*='title']),
.dc-settings-list :deep([class*='title']),
.dc-danger-list :deep([class*='title']),
.dc-action-list :deep([class*='title']) {
  color: var(--dc-label);
  font-size: 16px;
}

.dc-conversation :deep([class*='subtitle']),
.dc-contact-list :deep([class*='subtitle']) {
  color: var(--dc-secondary);
  font-size: 13px;
  line-height: 1.3;
}

.dc-conversation time {
  color: var(--dc-tertiary);
  font-size: 12px;
  font-weight: 400;
}

.dc-preview {
  display: block;
  max-width: 190px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-timer {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--dc-tertiary);
  font-size: 11px;
}

.dc-avatar {
  position: relative;
  display: inline-flex;
  width: 48px;
  height: 48px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  font-size: 20px;
  font-style: normal;
  font-weight: 700;
}

.dc-avatar i {
  position: absolute;
  top: 0;
  right: 0;
  width: 10px;
  height: 10px;
  border: 2px solid var(--dc-surface);
  border-radius: 50%;
  background: var(--dc-accent);
}

.dc-avatar--small {
  width: 40px;
  height: 40px;
  font-size: 17px;
}

.dc-avatar--header {
  width: 34px;
  height: 34px;
  font-size: 14px;
}

.dc-avatar--profile {
  width: 76px;
  height: 76px;
  font-size: 30px;
}

.dc-empty {
  display: flex;
  min-height: 270px;
  padding: 36px 30px;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  text-align: center;
}

.dc-new-chat {
  position: absolute;
  z-index: 22;
  right: 16px;
  bottom: 23px;
  width: 54px;
  height: 54px;
  border-radius: 50%;
  background: var(--dc-accent);
  box-shadow: 0 5px 18px rgb(0 0 0 / 38%);
}

.dc-scroll-content {
  flex: 1;
  padding: 14px 0 36px;
}

.dc-hero,
.dc-qr-card {
  margin: 0 12px 16px;
  border-color: var(--dc-border);
  border-radius: 18px;
  color: var(--dc-label);
  background: var(--dc-surface);
  text-align: center;
}

.dc-hero {
  padding: 18px 12px;
}

.dc-primary {
  width: calc(100% - 32px);
  min-height: 47px;
  margin: 8px 16px 18px;
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  background: var(--dc-accent);
}

.dc-primary:disabled {
  opacity: 0.42;
}

.dc-section-title {
  margin: 18px 18px 7px;
  color: var(--dc-secondary);
  font-size: 13px;
  font-weight: 500;
  text-transform: uppercase;
}

.dc-form-list :deep(input) {
  color: var(--dc-label);
  font-size: 16px;
}

.dc-form-list :deep(label),
.dc-form-list :deep([class*='label']) {
  color: var(--dc-secondary);
  font-size: 12px;
}

.dc-form-list :deep(.text-black),
.dc-settings-list :deep(.text-black) {
  color: var(--dc-label) !important;
}

.dc-qr-card {
  display: flex;
  width: calc(100% - 24px);
  min-height: 226px;
  padding: 18px;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  gap: 12px;
}

.dc-faux-qr {
  display: grid;
  width: 82px;
  height: 82px;
  place-items: center;
  border-radius: 16px;
  color: #111;
  background: #fff;
}

.dc-qr-card > div:nth-child(2) {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.dc-qr-card strong {
  color: var(--dc-label);
  font-size: 15px;
}

.dc-qr-card small {
  color: var(--dc-secondary);
  font-size: 12px;
}

.dc-qr-card :deep(button) {
  gap: 7px;
  font-size: 14px;
}

.dc-thread-navbar :deep([class*='title']) {
  overflow: visible;
}

.dc-thread-identity {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 8px;
  color: var(--dc-label) !important;
  text-align: left;
}

.dc-thread-identity > span:last-child {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.dc-thread-identity strong {
  max-width: 130px;
  overflow: hidden;
  font-size: 15px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-thread-identity small {
  color: var(--dc-secondary);
  font-size: 11px;
  font-weight: 400;
}

.dc-thread-meta {
  display: flex;
  min-height: 29px;
  padding: 5px 12px;
  align-items: center;
  justify-content: center;
  gap: 5px;
  border-bottom: 0.5px solid var(--dc-border);
  color: var(--dc-secondary);
  font-size: 12px;
}

.dc-thread-meta span {
  display: inline-flex;
  gap: 4px;
}

.dc-messages {
  display: flex;
  min-height: 0;
  flex: 1;
  padding: 12px 10px 10px;
  overflow-y: auto;
  flex-direction: column;
  gap: 7px;
  scrollbar-width: none;
}

.dc-day {
  align-self: center;
  margin: 3px 0 8px;
  padding: 4px 9px;
  border-radius: 999px;
  color: var(--dc-secondary);
  font-size: 12px;
  background: var(--dc-surface);
}

.dc-system {
  display: inline-flex;
  align-self: center;
  max-width: 88%;
  margin: 4px 0;
  align-items: center;
  gap: 5px;
  color: var(--dc-secondary);
  font-size: 12px;
  line-height: 1.35;
  text-align: center;
}

.dc-message {
  position: relative;
  display: flex;
  max-width: 79%;
  min-width: 64px;
  padding: 8px 11px 6px;
  flex-direction: column;
  gap: 3px;
  border: 0;
  color: var(--dc-label);
  text-align: left;
  overflow-wrap: anywhere;
}

.dc-message--received {
  align-self: flex-start;
  border-radius: 18px 18px 18px 5px;
  background: var(--dc-surface-raised);
}

.dc-message--sent {
  align-self: flex-end;
  border-radius: 18px 18px 5px;
  background: var(--dc-accent);
}

.dc-message--failed {
  outline: 1px solid #ff453a;
}

.dc-message-body {
  font-size: 16px;
  line-height: 1.28;
  white-space: pre-wrap;
}

.dc-message > img,
.dc-message > video {
  width: min(100%, 220px);
  max-height: 230px;
  border-radius: 12px;
  object-fit: cover;
}

.dc-message > small {
  align-self: flex-end;
  color: rgb(255 255 255 / 72%);
  font-size: 10.5px;
  line-height: 1.2;
}

.dc-reply-preview {
  display: flex;
  max-width: 100%;
  padding: 5px 7px;
  align-items: center;
  gap: 5px;
  overflow: hidden;
  border-left: 2px solid currentColor;
  border-radius: 6px;
  color: rgb(255 255 255 / 82%);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: rgb(0 0 0 / 16%);
}

.dc-reactions {
  align-self: flex-end;
  font-size: 13px;
}

.dc-replying {
  display: flex;
  min-height: 48px;
  padding: 7px 12px;
  align-items: center;
  gap: 9px;
  border-top: 0.5px solid var(--dc-border);
  background: var(--dc-surface);
}

.dc-replying > span {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.dc-replying small {
  color: var(--dc-accent);
  font-size: 11px;
}

.dc-replying strong {
  overflow: hidden;
  color: var(--dc-label);
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-attachments {
  display: grid;
  padding: 10px 12px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  border-top: 0.5px solid var(--dc-border);
  background: #000;
}

.dc-attachments :deep(button) {
  min-height: 42px;
  gap: 6px;
  justify-content: flex-start;
  font-size: 13px;
}

.dc-gif-panel {
  max-height: 300px;
  margin: 0;
  padding: 10px;
  overflow-y: auto;
  border-color: var(--dc-border);
  border-radius: 16px 16px 0 0;
  background: var(--dc-surface);
}

.dc-gif-panel header {
  display: flex;
  padding: 3px 4px 9px;
  align-items: center;
  justify-content: space-between;
  font-size: 16px;
}

.dc-gif-grid {
  display: grid;
  margin-top: 7px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 5px;
}

.dc-gif-grid button {
  padding: 0;
  overflow: hidden;
  border: 0;
  border-radius: 9px;
  background: var(--dc-surface-raised);
}

.dc-gif-grid img {
  display: block;
  width: 100%;
  height: 86px;
  object-fit: cover;
}

.dc-recorder {
  display: flex;
  min-height: 58px;
  padding: 8px 10px;
  align-items: center;
  gap: 8px;
  border-top: 0.5px solid var(--dc-border);
  background: var(--dc-surface);
}

.dc-recorder > i {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #ff453a;
}

.dc-recorder time {
  color: var(--dc-label);
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}

.dc-recorder > span {
  display: flex;
  height: 28px;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 1px;
  overflow: hidden;
}

.dc-recorder b {
  width: 2px;
  flex: 0 0 auto;
  border-radius: 2px;
  background: var(--dc-accent);
}

.dc-composer {
  flex: 0 0 auto;
  padding-bottom: 2px;
  border-top: 0.5px solid var(--dc-border);
  background: #000;
}

.dc-composer :deep(.k-toolbar) {
  border: 0 !important;
  background: #000 !important;
}

.dc-composer :deep(.k-glass) {
  border: 0.5px solid #38383a;
  background: var(--dc-surface) !important;
  box-shadow: none !important;
}

.dc-composer :deep(textarea) {
  min-height: 36px;
  max-height: 90px;
  color: var(--dc-label);
  font-size: 16px;
  line-height: 1.3;
}

.dc-composer :deep(textarea::placeholder) {
  color: var(--dc-tertiary);
  opacity: 1;
}

.dc-composer :deep(button) {
  color: var(--dc-accent);
}

.dc-composer :deep(button.active) {
  color: #fff;
  background: var(--dc-accent);
}

.dc-profile-hero {
  display: flex;
  padding: 12px 20px 18px;
  align-items: center;
  flex-direction: column;
  text-align: center;
}

.dc-profile-hero h2 {
  font-size: 22px;
}

.dc-profile-hero :deep(button) {
  gap: 6px;
  font-size: 14px;
}

.dc-profile-hero > small {
  color: var(--dc-secondary);
  font-size: 12px;
}

.dc-settings-list :deep(li),
.dc-danger-list :deep(li) {
  min-height: 50px;
}

.dc-settings-list :deep(svg),
.dc-danger-list :deep(svg) {
  color: var(--dc-accent);
}

.dc-setting-value {
  display: block;
  max-width: 132px;
  overflow: hidden;
  color: var(--dc-secondary);
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-select-row :deep([class*='inner']) {
  min-width: 0;
}

.dc-select-row :deep(.darkchat-select-control) {
  margin-top: 8px;
}

.dc-danger-list :deep([class*='title']),
.dc-danger-list :deep(svg),
.dc-danger-row :deep([class*='title']),
.dc-danger-row :deep(svg),
.dc-danger-text {
  color: #ff453a !important;
}

.dc-privacy-note {
  display: flex;
  margin: 0 20px;
  align-items: flex-start;
  gap: 8px;
  color: var(--dc-secondary);
  font-size: 13px;
  line-height: 1.4;
}

.dc-privacy-note svg {
  flex: 0 0 auto;
  margin-top: 1px;
  color: var(--dc-accent);
}

.dc-dialog :deep([class*='contentWrap']) {
  color: var(--dc-label);
}

.dc-dialog :deep([class*='title']) {
  color: var(--dc-label);
  font-size: 18px;
}

.dc-dialog p {
  margin: 8px 0 12px;
  color: var(--dc-secondary);
  font-size: 14px;
  line-height: 1.4;
}

.dc-dialog-icon {
  display: grid;
  width: 48px;
  height: 48px;
  margin: 2px auto 8px;
  place-items: center;
  border-radius: 14px;
  color: var(--dc-accent);
  background: rgb(10 132 255 / 14%);
}

.dc-dialog-icon--danger {
  color: #ff453a;
  background: rgb(255 69 58 / 14%);
}

.dc-dialog-id {
  display: block;
  padding: 9px;
  border-radius: 9px;
  color: var(--dc-label);
  font-size: 14px;
  background: rgb(255 255 255 / 8%);
}

.dc-report-dialog textarea {
  width: 100%;
  min-height: 82px;
  margin-top: 10px;
  padding: 10px;
  resize: none;
  border: 0.5px solid var(--dc-border);
  border-radius: 10px;
  outline: none;
  color: var(--dc-label);
  font-size: 14px;
  background: var(--dc-surface-raised);
}

.dc-action-sheet {
  max-height: 72%;
  padding: 7px 0 32px;
  overflow-y: auto;
  border-radius: 20px 20px 0 0;
  color: var(--dc-label);
  background: #111113;
}

.dc-selection-sheet {
  z-index: 1300;
  padding-top: 9px;
}

.dc-selection-sheet h3 {
  margin: 2px 20px 10px;
  color: var(--dc-label);
  font-size: 17px;
  font-weight: 650;
  letter-spacing: -0.2px;
  text-align: center;
}

.dc-selection-list {
  max-height: 330px;
  overflow-y: auto;
}

.dc-selection-list :deep(svg) {
  color: var(--dc-accent);
}

.dc-report-reason {
  margin: 8px 0 0;
}

.dc-sheet-handle {
  width: 36px;
  height: 5px;
  margin: 0 auto 10px;
  border-radius: 999px;
  background: rgb(255 255 255 / 28%);
}

.dc-reaction-row {
  display: grid;
  margin: 0 12px 10px;
  grid-template-columns: repeat(6, 1fr);
  gap: 5px;
}

.dc-reaction-row button {
  display: grid;
  min-width: 0;
  aspect-ratio: 1;
  place-items: center;
  border: 0;
  border-radius: 50%;
  font-size: 20px;
  background: var(--dc-surface-raised);
}

.dc-sheet-cancel {
  width: calc(100% - 32px);
  margin: 0 16px 8px;
  color: var(--dc-accent);
  background: var(--dc-surface);
}

.dc-toast {
  color: var(--dc-label);
  font-size: 14px;
  line-height: 1.35;
}

.dc-message :deep(.darkchat-voice) {
  min-width: 180px;
}

.dc-message :deep(.darkchat-voice__time),
.dc-message :deep(.darkchat-voice__speed) {
  color: rgb(255 255 255 / 80%);
  font-size: 11px;
}

@media (max-height: 650px) {
  .dc-ios {
    padding-top: 42px;
  }

  .dc-security {
    min-height: 46px;
  }

  .dc-conversation :deep(button) {
    min-height: 66px;
  }

  .dc-avatar {
    width: 44px;
    height: 44px;
  }

  .dc-avatar--header {
    width: 32px;
    height: 32px;
  }
}

/* DarkChat follows the native Messages layout and only keeps privacy-specific accents. */
.dc-inbox {
  position: relative;
  padding-bottom: 74px;
}

.dc-sms-inbox-header {
  z-index: 30;
  display: grid;
  height: 52px;
  padding: 0 14px;
  flex: 0 0 auto;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  border-bottom: 0.5px solid var(--dc-border);
  background: rgb(0 0 0 / 92%);
  backdrop-filter: saturate(180%) blur(22px);
}

.dc-sms-inbox-header > strong {
  color: var(--dc-label);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.35px;
}

.dc-sms-inbox-header > button {
  display: grid;
  width: 36px;
  height: 36px;
  margin-left: auto;
  place-items: center;
  border-radius: 50%;
  color: var(--dc-accent);
}

.dc-sms-inbox-header .dc-sms-edit {
  width: auto;
  min-width: 44px;
  margin: 0;
  padding: 0 10px;
  justify-self: start;
  border-radius: 18px;
  font-size: 14px;
}

.dc-sms-security {
  display: grid;
  width: 100%;
  min-height: 46px;
  padding: 7px 16px;
  flex: 0 0 auto;
  align-items: center;
  grid-template-columns: 17px minmax(0, 1fr);
  column-gap: 7px;
  border: 0;
  border-bottom: 0.5px solid var(--dc-border);
  color: #f5f5f7;
  background: #000;
}

.dc-sms-security > svg {
  grid-row: 1 / 3;
  color: var(--dc-accent);
}

.dc-sms-security span {
  align-self: end;
  font-size: 13px;
  font-weight: 550;
  line-height: 1.2;
}

.dc-sms-security small {
  max-width: 100%;
  align-self: start;
  overflow: hidden;
  color: #b8b8bd;
  font-size: 11.5px;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-inbox .dc-inbox-content {
  padding: 0 14px 12px;
}

.dc-sms-conversation {
  position: relative;
  display: flex;
  width: 100%;
  min-height: 72px;
  padding: 8px 0 8px 7px;
  align-items: center;
  gap: 11px;
  border: 0;
  color: var(--dc-label);
  text-align: left;
  background: transparent;
}

.dc-sms-conversation::after {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 66px;
  height: 0.5px;
  background: var(--dc-border);
  content: '';
}

.dc-sms-conversation:active {
  border-radius: 13px;
  background: var(--dc-surface);
  transform: scale(0.985);
}

.dc-sms-unread {
  position: absolute;
  left: -7px;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--dc-accent);
}

.dc-sms-conversation-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}

.dc-sms-conversation-body > span {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto 14px;
  align-items: center;
  gap: 4px;
}

.dc-sms-conversation-body strong {
  overflow: hidden;
  font-size: 15px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-sms-conversation--unread strong {
  font-weight: 750;
}

.dc-sms-conversation-body time,
.dc-sms-conversation-body svg {
  color: var(--dc-tertiary);
}

.dc-sms-conversation-body time {
  font-size: 11px;
}

.dc-sms-conversation-body > small {
  min-height: 17px;
  overflow: hidden;
  color: var(--dc-secondary);
  font-size: 13px;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-sms-conversation-body em {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--dc-tertiary);
  font-size: 11.5px;
  font-style: normal;
}

.dc-sms-inbox-toolbar {
  position: absolute;
  z-index: 35;
  right: 12px;
  bottom: 26px;
  left: 12px;
  display: flex;
  height: 44px;
  align-items: center;
  gap: 9px;
}

.dc-sms-inbox-toolbar label {
  display: flex;
  height: 40px;
  min-width: 0;
  padding: 0 12px;
  flex: 1;
  align-items: center;
  gap: 7px;
  border: 0.5px solid var(--dc-border);
  border-radius: 22px;
  color: var(--dc-tertiary);
  background: rgb(28 28 30 / 94%);
}

.dc-sms-inbox-toolbar input {
  min-width: 0;
  flex: 1;
  border: 0;
  outline: 0;
  color: var(--dc-label);
  font-size: 14px;
  background: transparent;
}

.dc-sms-inbox-toolbar input::placeholder {
  color: var(--dc-tertiary);
  opacity: 1;
}

.dc-sms-inbox-toolbar > button {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 50%;
  color: var(--dc-accent);
}

.dc-sms-chat-header {
  position: relative;
  height: 122px;
  flex: 0 0 auto;
  border-bottom: 0.5px solid var(--dc-border);
  background: #000;
}

.dc-sms-back {
  position: absolute;
  z-index: 2;
  top: 13px;
  left: 14px;
  display: grid;
  width: 44px;
  height: 44px;
  place-items: center;
  border-radius: 50%;
  color: var(--dc-accent);
}

.dc-sms-chat-contact {
  position: absolute;
  top: 5px;
  left: 50%;
  display: flex;
  width: 170px;
  margin-left: -85px;
  align-items: center;
  flex-direction: column;
  color: var(--dc-label);
  background: transparent;
  transform: none;
  transform-origin: center;
}

.dc-sms-chat-contact:active {
  transform: scale(0.97);
}

.dc-avatar--chat {
  width: 58px;
  height: 58px;
  margin-bottom: 6px;
  border: 2px solid #000;
  font-size: 23px;
}

.dc-sms-chat-contact > span:nth-child(2) {
  display: flex;
  min-width: 0;
  min-height: 23px;
  padding: 3px 11px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  border: 0.5px solid var(--dc-border);
  border-radius: 16px;
  background: var(--dc-surface);
}

.dc-sms-chat-contact strong {
  max-width: 150px;
  overflow: hidden;
  font-size: 14px;
  line-height: 1.05;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-sms-chat-contact small {
  color: var(--dc-secondary);
  font-size: 9.5px;
  line-height: 1.05;
}

.dc-sms-chat-contact > svg {
  position: absolute;
  right: 2px;
  bottom: 9px;
  color: var(--dc-tertiary);
}

.dc-thread .dc-message--received {
  border-radius: 20px 20px 20px 5px;
  background: #29292c;
}

.dc-thread .dc-message--sent {
  border-radius: 20px 20px 5px;
  background: var(--dc-accent);
}

.dc-thread .dc-message {
  padding: 9px 13px 7px;
}
</style>

<template>
  <k-page component="main" class="darkchat-page dc-ios dark">
    <section v-if="!signedIn" class="dc-gate">
      <k-card class="dc-gate-card" outline>
        <span class="dc-icon-tile"><LockKeyhole :size="28" /></span>
        <h1>{{ t('name') }}</h1>
        <p>{{ t('signInBody') }}</p>
        <small>{{ t('signInHint') }}</small>
      </k-card>
    </section>

    <section v-else-if="darkchat.loading && !darkchat.profile" class="dc-gate">
      <k-preloader class="dc-preloader" />
      <p>{{ phone.t('Common.loading') }}</p>
    </section>

    <template v-else-if="darkchat.profile">
      <section v-if="screen === 'inbox'" class="dc-screen dc-inbox">
        <header class="dc-sms-inbox-header">
          <k-glass
            component="button"
            type="button"
            class="dc-sms-edit"
            @click="openProfile"
            >{{ phone.t('Common.edit') }}</k-glass
          >
          <strong>{{ t('name') }}</strong>
          <k-glass
            component="button"
            type="button"
            :aria-label="t('security')"
            @click="openProfile"
            ><ShieldCheck :size="21"
          /></k-glass>
        </header>
        <button
          type="button"
          class="dc-sms-security"
          @click="copyIdentity(darkchat.profile.darkId)"
        >
          <LockKeyhole :size="12" /><span>{{ t('privateNetwork') }}</span
          ><small>{{ darkchat.profile.darkId }}</small>
        </button>
        <div class="dc-inbox-content">
          <div
            v-if="filteredConversations.length"
            class="dc-sms-conversation-list"
          >
            <button
              v-for="conversation in filteredConversations"
              :key="conversation.id"
              type="button"
              class="dc-sms-conversation"
              :class="{ 'dc-sms-conversation--unread': conversation.unread }"
              @click="openConversation(conversation.id)"
            >
              <i v-if="conversation.unread" class="dc-sms-unread" />
              <span
                class="dc-avatar"
                :style="{
                  background: avatarGradient(conversation.peer.avatarSeed),
                }"
                >{{ avatarGlyph(conversation.peer.avatarSeed) }}</span
              >
              <span class="dc-sms-conversation-body"
                ><span
                  ><strong>{{ conversation.peer.alias }}</strong
                  ><time>{{ formatDate(conversation.lastMessageAt) }}</time
                  ><ChevronRight :size="14" /></span
                ><small>{{ preview(conversation) }}</small
                ><em v-if="conversation.disappearingSeconds !== 0"
                  ><Clock3 :size="11" />{{
                    timerLabel(conversation.disappearingSeconds)
                  }}</em
                ></span
              >
            </button>
          </div>
          <div v-else class="dc-empty">
            <span class="dc-icon-tile"><ShieldCheck :size="27" /></span>
            <h2>{{ search ? t('noResults') : t('noChats') }}</h2>
            <p>{{ search ? t('noResultsBody') : t('noChatsBody') }}</p>
          </div>
        </div>
        <footer class="dc-sms-inbox-toolbar">
          <label
            ><Search :size="17" /><input
              :value="search"
              type="search"
              :placeholder="phone.t('Common.search')"
              @input="setSearch" /></label
          ><k-glass
            component="button"
            type="button"
            :aria-label="t('newChat')"
            @click="screen = 'new'"
            ><MessageCirclePlus :size="21"
          /></k-glass>
        </footer>
      </section>

      <section v-else-if="screen === 'new'" class="dc-screen dc-scroll-screen">
        <k-navbar
          :title="t('newChat')"
          class="dc-navbar"
          :colors="darkNavbarColors"
          ><template #left
            ><k-navbar-back-link
              :text="phone.t('Common.back')"
              @click="back" /></template
        ></k-navbar>
        <div class="dc-scroll-content">
          <k-card class="dc-hero" outline>
            <span class="dc-icon-tile"><QrCode :size="27" /></span>
            <h2>{{ t('connectPrivately') }}</h2>
            <p>{{ t('newChatBody') }}</p>
          </k-card>
          <k-list inset strong class="dc-form-list"
            ><k-list-input
              :label="t('darkIdOrInvite')"
              :value="identifier"
              :colors="darkInputColors"
              autocomplete="off"
              placeholder="dark:7X4K-P92D"
              clear-button
              @input="setIdentifier"
              @clear="identifier = ''"
              @keydown.enter.prevent="requestStart()"
          /></k-list>
          <k-button
            large
            rounded
            class="dc-primary"
            :disabled="!identifier.trim()"
            @click="requestStart()"
            >{{ t('continue') }}</k-button
          >

          <h3 class="dc-section-title">{{ t('contacts') }}</h3>
          <k-list
            v-if="darkchat.contacts.length"
            inset
            strong
            class="dc-contact-list"
          >
            <k-list-item
              v-for="contact in darkchat.contacts"
              :key="contact.id"
              link
              link-component="button"
              :title="contact.alias"
              :subtitle="contact.darkId"
              @click="requestStart(contact.darkId)"
            >
              <template #media
                ><span
                  class="dc-avatar dc-avatar--small"
                  :style="{ background: avatarGradient(contact.avatarSeed) }"
                  >{{ avatarGlyph(contact.avatarSeed) }}</span
                ></template
              >
            </k-list-item>
          </k-list>
          <k-card class="dc-qr-card" outline :content-wrap="false">
            <div class="dc-faux-qr"><QrCode :size="58" /></div>
            <div>
              <strong>{{ darkchat.profile.darkId }}</strong
              ><small>{{ t('shareIdentity') }}</small>
            </div>
            <k-button
              tonal
              rounded
              @click="copyIdentity(darkchat.profile.inviteCode)"
              ><Copy :size="16" />{{ darkchat.profile.inviteCode }}</k-button
            >
          </k-card>
        </div>
      </section>

      <section
        v-else-if="screen === 'thread' && active"
        class="dc-screen dc-thread"
        :class="{ 'dc-thread--panel': attachmentPanelOpen }"
      >
        <header class="dc-sms-chat-header">
          <k-glass
            component="button"
            type="button"
            class="dc-sms-back"
            :aria-label="phone.t('Common.back')"
            @click="back"
            ><ChevronLeft :size="28" :stroke-width="2.35"
          /></k-glass>
          <button
            type="button"
            class="dc-sms-chat-contact"
            @click="openContact"
          >
            <span
              class="dc-avatar dc-avatar--chat"
              :style="{ background: avatarGradient(active.peer.avatarSeed) }"
              >{{ avatarGlyph(active.peer.avatarSeed) }}</span
            ><span
              ><strong>{{ active.peer.alias }}</strong
              ><small v-if="active.peer.activityVisible">{{
                t('activeNow')
              }}</small></span
            ><ChevronRight :size="13" />
          </button>
        </header>
        <div class="dc-thread-meta">
          <LockKeyhole :size="13" />{{ t('serverPrivate')
          }}<span v-if="active.disappearingSeconds !== 0"
            >· {{ timerLabel(active.disappearingSeconds) }}</span
          >
        </div>
        <div class="darkchat-thread__messages dc-messages">
          <div class="dc-day">{{ dayLabel(active.createdAt) }}</div>
          <template
            v-for="message in darkchat.messages"
            :key="message.clientId ?? message.id"
          >
            <div v-if="message.messageType === 'system'" class="dc-system">
              <ShieldCheck :size="13" />{{ systemText(message.body) }}
            </div>
            <button
              v-else
              type="button"
              class="dc-message"
              :class="[
                `dc-message--${message.direction}`,
                { 'dc-message--failed': message.deliveryStatus === 'failed' },
              ]"
              @click="selectedMessage = message"
            >
              <span v-if="message.replyBody" class="dc-reply-preview"
                ><Reply :size="12" />{{ message.replyBody }}</span
              >
              <img
                v-if="
                  message.messageType === 'gif' ||
                  message.messageType === 'image'
                "
                :src="message.mediaPayload || undefined"
                :alt="message.messageType === 'gif' ? 'GIF' : t('photo')"
              />
              <video
                v-else-if="message.messageType === 'video'"
                :src="message.mediaPayload || undefined"
                controls
                playsinline
                preload="metadata"
              />
              <DarkChatVoiceMessage
                v-else-if="message.messageType === 'voice'"
                :message="message"
              />
              <span v-else class="dc-message-body">{{ message.body }}</span>
              <span
                v-if="Object.keys(message.reactions).length"
                class="dc-reactions"
                >{{ Object.values(message.reactions).join(' ') }}</span
              >
              <small
                >{{ formatDate(message.createdAt)
                }}<template v-if="message.direction === 'sent'">
                  ·
                  {{
                    message.deliveryStatus === 'sending'
                      ? t('sending')
                      : message.deliveryStatus === 'failed'
                        ? t('failed')
                        : message.readAt
                          ? t('read')
                          : t('delivered')
                  }}</template
                ></small
              >
            </button>
          </template>
        </div>

        <div v-if="replyTo" class="dc-replying">
          <Reply :size="15" /><span
            ><small>{{ t('replying') }}</small
            ><strong>{{ replyTo.body || t(replyTo.messageType) }}</strong></span
          ><k-link
            component="button"
            type="button"
            icon-only
            @click="replyTo = null"
            ><X :size="17"
          /></k-link>
        </div>
        <div v-if="attachmentOpen" class="dc-attachments">
          <k-button tonal rounded @click="openMediaApp('photos', 'photo')"
            ><Images :size="19" />{{ t('attachPhoto') }}</k-button
          >
          <k-button tonal rounded @click="openMediaApp('camera', 'photo')"
            ><Camera :size="19" />{{ t('takePhoto') }}</k-button
          >
          <k-button tonal rounded @click="openEmojiPanel"
            ><span>😀</span>{{ t('emoji') }}</k-button
          >
          <k-button tonal rounded @click="openGifPanel"
            ><ImagePlay :size="19" />{{ t('attachGif') }}</k-button
          >
          <k-button tonal rounded @click="openMediaApp('photos', 'video')"
            ><Video :size="19" />{{ t('attachVideo') }}</k-button
          >
        </div>
        <k-card v-if="gifOpen" class="dc-gif-panel" outline>
          <header>
            <strong>{{ t('gifs') }}</strong
            ><k-link
              component="button"
              type="button"
              @click="gifOpen = false"
              >{{ phone.t('Common.done') }}</k-link
            >
          </header>
          <k-searchbar
            :value="gifQuery"
            :placeholder="t('searchGifs')"
            @input="updateGifSearch"
            @clear="clearGifSearch"
          />
          <div class="dc-gif-grid">
            <button
              v-for="gif in gifResults"
              :key="gif.id"
              type="button"
              @click="sendGif(gif)"
            >
              <img :src="gif.previewUrl" :alt="gif.title" />
            </button>
          </div>
          <k-button
            v-if="gifHasMore && !gifLoading"
            clear
            @click="loadGifs()"
            >{{ t('loadMore') }}</k-button
          ><k-preloader v-if="gifLoading" class="dc-preloader" />
        </k-card>
        <FullEmojiPicker
          v-if="emojiOpen"
          @close="emojiOpen = false"
          @pick="appendEmoji"
        />
        <div v-if="recording" class="dc-recorder">
          <k-link
            component="button"
            type="button"
            icon-only
            @click="cancelRecording"
            ><X :size="19" /></k-link
          ><i /><time>{{ recordingTime() }}</time
          ><span
            ><b
              v-for="(level, index) in recordingLevels"
              :key="index"
              :style="{ height: `${Math.max(3, level * 23)}px` }" /></span
          ><k-link
            component="button"
            type="button"
            icon-only
            @click="stopRecording"
            ><ArrowUpCircle :size="29"
          /></k-link>
        </div>
        <k-messagebar
          v-else
          class="dc-composer"
          :value="draft"
          :placeholder="t('message')"
          :colors="darkMessagebarColors"
          @input="setDraft"
          @keydown.enter.exact.prevent="sendText"
        >
          <template #left
            ><k-link
              component="button"
              type="button"
              icon-only
              :class="{ active: attachmentOpen || attachmentPanelOpen }"
              @click="toggleAttachmentPanel"
              ><Plus :size="23" /></k-link
          ></template>
          <template #right
            ><k-link
              v-if="draft.trim()"
              component="button"
              type="button"
              icon-only
              @click="sendText"
              ><ArrowUpCircle :size="27" /></k-link
            ><k-link
              v-else
              component="button"
              type="button"
              icon-only
              @click="startRecording"
              ><Mic :size="20" /></k-link
          ></template>
        </k-messagebar>
      </section>

      <section
        v-else-if="screen === 'contact' && active"
        class="dc-screen dc-scroll-screen"
      >
        <k-navbar
          :title="t('contactSecurity')"
          class="dc-navbar"
          :colors="darkNavbarColors"
          ><template #left
            ><k-navbar-back-link
              :text="phone.t('Common.back')"
              @click="back" /></template
        ></k-navbar>
        <div class="dc-scroll-content">
          <div class="dc-profile-hero">
            <span
              class="dc-avatar dc-avatar--profile"
              :style="{ background: avatarGradient(active.peer.avatarSeed) }"
              >{{ avatarGlyph(active.peer.avatarSeed) }}</span
            >
            <h2>{{ active.peer.alias }}</h2>
            <k-button clear rounded @click="copyIdentity(active.peer.darkId)"
              >{{ active.peer.darkId }}<Copy :size="14" /></k-button
            ><small>{{
              t('chatSince', { date: dayLabel(active.createdAt) })
            }}</small>
          </div>
          <k-list inset strong class="dc-settings-list">
            <k-list-item :title="t('notifications')"
              ><template #media><Bell :size="20" /></template
              ><template #after
                ><k-toggle
                  :checked="active.notificationsEnabled"
                  @change="setConversationNotifications" /></template
            ></k-list-item>
            <k-list-item :title="t('readReceipts')"
              ><template #media><Check :size="20" /></template
              ><template #after
                ><k-toggle
                  :checked="active.readReceipts"
                  @change="setReadReceipts" /></template
            ></k-list-item>
            <k-list-item
              link
              link-component="button"
              :title="t('disappearing')"
              @click="selectionSheet = 'disappearing'"
            >
              <template #media><Clock3 :size="20" /></template>
              <template #after
                ><span class="dc-setting-value">{{
                  timerLabel(active.disappearingSeconds)
                }}</span></template
              >
            </k-list-item>
          </k-list>
          <k-list inset strong class="dc-form-list"
            ><k-list-input
              :label="t('contactAlias')"
              :value="contactAliasDraft"
              :colors="darkInputColors"
              maxlength="32"
              @input="setContactAliasDraft"
          /></k-list>
          <k-button large rounded class="dc-primary" @click="saveContact"
            ><UserPlus :size="18" />{{
              active.peer.isContact ? t('saveContact') : t('addContact')
            }}</k-button
          >
          <k-list inset strong class="dc-danger-list">
            <k-list-item
              v-if="active.peer.isContact"
              link
              link-component="button"
              :title="t('removeContact')"
              @click="removeContact"
              ><template #media><UserMinus :size="20" /></template
            ></k-list-item>
            <k-list-item
              link
              link-component="button"
              :title="active.peer.blocked ? t('unblock') : t('block')"
              @click="toggleBlock"
              ><template #media><ShieldOff :size="20" /></template
            ></k-list-item>
            <k-list-item
              link
              link-component="button"
              :title="t('report')"
              @click="beginReport()"
              ><template #media><BellOff :size="20" /></template
            ></k-list-item>
            <k-list-item
              link
              link-component="button"
              :title="t('clearChat')"
              @click="clearChat"
              ><template #media><Trash2 :size="20" /></template
            ></k-list-item>
          </k-list>
        </div>
      </section>

      <section
        v-else-if="screen === 'profile'"
        class="dc-screen dc-scroll-screen"
      >
        <k-navbar
          :title="t('myIdentity')"
          class="dc-navbar"
          :colors="darkNavbarColors"
          ><template #left
            ><k-navbar-back-link
              :text="phone.t('Common.back')"
              @click="back" /></template
          ><template #right
            ><k-link component="button" type="button" @click="saveProfile">{{
              phone.t('Common.done')
            }}</k-link></template
          ></k-navbar
        >
        <div class="dc-scroll-content">
          <div class="dc-profile-hero">
            <span
              class="dc-avatar dc-avatar--profile"
              :style="{
                background: avatarGradient(darkchat.profile.avatarSeed),
              }"
              >{{ avatarGlyph(darkchat.profile.avatarSeed) }}</span
            >
            <h2>{{ darkchat.profile.alias }}</h2>
            <k-button
              clear
              rounded
              @click="copyIdentity(darkchat.profile.darkId)"
              >{{ darkchat.profile.darkId }}<Copy :size="14"
            /></k-button>
          </div>
          <k-list inset strong class="dc-form-list"
            ><k-list-input
              :label="t('alias')"
              :value="aliasDraft"
              :colors="darkInputColors"
              maxlength="32"
              @input="setAliasDraft"
          /></k-list>
          <k-list inset strong class="dc-settings-list">
            <k-list-item
              link
              link-component="button"
              :title="t('notificationPrivacy')"
              @click="selectionSheet = 'notification'"
            >
              <template #media><Bell :size="20" /></template>
              <template #after
                ><span class="dc-setting-value">{{
                  notificationOptions.find(
                    (option) => option.value === notificationMode,
                  )?.label
                }}</span></template
              >
            </k-list-item>
            <k-list-item :title="t('shareActivity')"
              ><template #media><ShieldCheck :size="20" /></template
              ><template #after
                ><k-toggle
                  :checked="activityVisible"
                  @change="setActivityVisible" /></template
            ></k-list-item>
          </k-list>
          <k-card class="dc-qr-card" outline :content-wrap="false"
            ><div class="dc-faux-qr"><QrCode :size="58" /></div>
            <div>
              <strong>{{ darkchat.profile.inviteCode }}</strong
              ><small>{{ t('inviteCode') }}</small>
            </div>
            <k-button
              tonal
              rounded
              @click="copyIdentity(darkchat.profile.inviteCode)"
              ><Copy :size="16" />{{ t('copyInvite') }}</k-button
            ></k-card
          >
          <p class="dc-privacy-note">
            <LockKeyhole :size="17" />{{ t('privacyDisclaimer') }}
          </p>
        </div>
      </section>
    </template>

    <k-dialog
      :opened="safetyOpen"
      class="dc-dialog"
      @backdropclick="safetyOpen = false"
    >
      <template #title>{{ t('unknownIdentity') }}</template
      ><span class="dc-dialog-icon"><ShieldCheck :size="25" /></span>
      <p>{{ t('unknownIdentityBody') }}</p>
      <strong class="dc-dialog-id">{{ pendingIdentifier }}</strong>
      <template #buttons
        ><k-dialog-button @click="safetyOpen = false">{{
          phone.t('Common.cancel')
        }}</k-dialog-button
        ><k-dialog-button strong @click="confirmStart">{{
          t('openSecureChat')
        }}</k-dialog-button></template
      >
    </k-dialog>

    <k-sheet
      :opened="Boolean(selectedMessage)"
      class="dc-action-sheet"
      :colors="darkSheetColors"
      @backdropclick="selectedMessage = null"
    >
      <template v-if="selectedMessage">
        <div class="dc-sheet-handle" />
        <div class="dc-reaction-row">
          <button
            v-for="reaction in ['❤️', '👍', '👎', '😂', '‼️', '❓']"
            :key="reaction"
            type="button"
            @click="react(selectedMessage, reaction)"
          >
            {{ reaction }}
          </button>
        </div>
        <k-list inset strong class="dc-action-list">
          <k-list-item
            link
            link-component="button"
            :title="t('reply')"
            @click="beginReply(selectedMessage)"
            ><template #media><Reply :size="20" /></template
          ></k-list-item>
          <k-list-item
            v-if="
              selectedMessage.messageType === 'text' ||
              selectedMessage.messageType === 'emoji'
            "
            link
            link-component="button"
            :title="t('copy')"
            @click="copyMessage(selectedMessage)"
            ><template #media><Copy :size="20" /></template
          ></k-list-item>
          <k-list-item
            link
            link-component="button"
            :title="t('deleteForMe')"
            @click="messageAction(selectedMessage, 'delete_me')"
            ><template #media><Trash2 :size="20" /></template
          ></k-list-item>
          <k-list-item
            v-if="selectedMessage.direction === 'sent'"
            link
            link-component="button"
            class="dc-danger-row"
            :title="t('deleteForBoth')"
            @click="messageAction(selectedMessage, 'delete_all')"
            ><template #media><Trash2 :size="20" /></template
          ></k-list-item>
          <k-list-item
            v-if="selectedMessage.direction === 'received'"
            link
            link-component="button"
            class="dc-danger-row"
            :title="t('report')"
            @click="beginReport(selectedMessage)"
            ><template #media><ShieldOff :size="20" /></template
          ></k-list-item> </k-list
        ><k-button
          large
          rounded
          class="dc-sheet-cancel"
          @click="selectedMessage = null"
          >{{ phone.t('Common.cancel') }}</k-button
        >
      </template>
    </k-sheet>

    <k-dialog
      :opened="reportOpen"
      class="dc-dialog dc-report-dialog"
      @backdropclick="closeReport"
    >
      <template #title>{{ t('reportUser') }}</template
      ><span class="dc-dialog-icon dc-dialog-icon--danger"
        ><ShieldOff :size="25" /></span
      ><k-list inset strong class="dc-action-list dc-report-reason">
        <k-list-item
          link
          link-component="button"
          :title="t('reportUser')"
          @click="selectionSheet = 'report'"
        >
          <template #after
            ><span class="dc-setting-value">{{
              reportOptions.find((option) => option.value === reportReason)
                ?.label
            }}</span></template
          >
        </k-list-item>
      </k-list>
      <textarea
        :value="reportDetails"
        maxlength="500"
        :placeholder="t('reportDetails')"
        @input="setReportDetails"
      />
      <template #buttons
        ><k-dialog-button @click="closeReport">{{
          phone.t('Common.cancel')
        }}</k-dialog-button
        ><k-dialog-button strong class="dc-danger-text" @click="submitReport">{{
          t('submitReport')
        }}</k-dialog-button></template
      >
    </k-dialog>

    <k-sheet
      :opened="selectionSheet !== null"
      class="dc-action-sheet dc-selection-sheet"
      :colors="darkSheetColors"
      @backdropclick="selectionSheet = null"
    >
      <div class="dc-sheet-handle" />
      <h3>{{ selectionTitle }}</h3>
      <k-list inset strong class="dc-action-list dc-selection-list">
        <k-list-item
          v-for="option in selectionOptions"
          :key="option.value"
          link
          link-component="button"
          :title="option.label"
          @click="chooseSelection(option.value)"
        >
          <template
            v-if="String(option.value) === String(selectionValue)"
            #after
            ><Check :size="20"
          /></template>
        </k-list-item>
      </k-list>
      <k-button
        large
        rounded
        class="dc-sheet-cancel"
        @click="selectionSheet = null"
        >{{ phone.t('Common.cancel') }}</k-button
      >
    </k-sheet>
    <k-toast :opened="Boolean(toast)" position="center" class="dc-toast">{{
      toast
    }}</k-toast>
  </k-page>
</template>
