<script setup lang="ts">
import {
  ArrowUpCircle,
  Bell,
  BellOff,
  Camera,
  Check,
  Clock3,
  Copy,
  ImagePlay,
  Images,
  LockKeyhole,
  LogOut,
  MessageCirclePlus,
  Mic,
  Plus,
  QrCode,
  Reply,
  Share2,
  ShieldCheck,
  ShieldOff,
  Smile,
  SquarePen,
  Trash2,
  UserRound,
  UserMinus,
  UserPlus,
  Video,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import DarkChatVoiceMessage from '@/components/DarkChatVoiceMessage.vue'
import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import SharedContentCard from '@/components/SharedContentCard.vue'
import { useAccountStore } from '@/stores/account'
import { useDarkChatStore } from '@/stores/darkchat'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessagesStore } from '@/stores/messages'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type {
  DarkChatConversationSummary,
  DarkChatMessage,
  DarkChatNotificationMode,
} from '@/types/darkchat'
import type { GifSearchResult } from '@/types/messages'
import type { EasySharePayload } from '@/types/easyshare'
import type { MediaType, PhoneMedia } from '@/types/media'
import { copyText } from '@/utils/clipboard'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'
import { easyShareDarkChatInviteCode } from '@/utils/easyshare'
import { handleEnterAction } from '@/utils/keyboard'
import {
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyField,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyListItem,
  SkyMessagebar,
  SkyNavbar,
  SkyScrollArea,
  SkySearchbar,
  SkySettingsGroup,
  SkySettingsRow,
  SkySheet,
  SkySpinner,
  SkyNotification,
} from '@/ui'

const VOICE_MAX_DURATION_MS = 60_000
const VOICE_MAX_BYTES = 270_000
const WAVEFORM_SAMPLES = 48
type DarkChatSelectOption = {
  label: string
  value: number | string
}
type SelectionSheet = 'disappearing' | 'notification' | 'report'
const account = useAccountStore()
const darkchat = useDarkChatStore()
const easyShare = useEasyShareStore()
const sms = useMessagesStore()
const messageMedia = useMessageMediaStore()
const phone = usePhoneStore()
const route = useRoute()
const router = useRouter()
const screen = ref<'inbox' | 'new' | 'thread' | 'contact' | 'profile'>('inbox')
const search = ref('')
const identifier = ref('')
const pendingIdentifier = ref('')
const safetyOpen = ref(false)
const draft = ref('')
const queuedSharePayload = ref<EasySharePayload | null>(null)
const shareDraft = ref<EasySharePayload | null>(null)
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
const signOutOpen = ref(false)
const deleteProfileOpen = ref(false)
const profileActionPending = ref(false)
const messagesArea = ref<HTMLElement | null>(null)
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
const contactSuggestions = computed(() => {
  const needle = identifier.value.trim().toLocaleLowerCase(phone.lang)
  if (!needle) return darkchat.contacts.slice(0, 8)
  return darkchat.contacts
    .filter((contact) =>
      `${contact.alias} ${contact.darkId}`
        .toLocaleLowerCase(phone.lang)
        .includes(needle),
    )
    .slice(0, 8)
})
const sharedInviteCode = ref(
  easyShareDarkChatInviteCode(
    route.query.easyShareKind,
    route.query.easyShareLink,
  ),
)
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

function setConversationNotifications(value: boolean): void {
  if (!active.value) return
  active.value.notificationsEnabled = value
  void updateConversation()
}

function setReadReceipts(value: boolean): void {
  if (!active.value) return
  active.value.readReceipts = value
  void updateConversation()
}

function setActivityVisible(value: boolean): void {
  activityVisible.value = value
}

function preview(conversation: DarkChatConversationSummary): string {
  if (conversation.lastMessage === 'message_deleted') return t('messageDeleted')
  if (conversation.lastMessageType === 'voice') return `🎙 ${t('voiceMessage')}`
  if (conversation.lastMessageType === 'gif') return `GIF · ${t('gif')}`
  if (conversation.lastMessageType === 'image') return `📷 ${t('photo')}`
  if (conversation.lastMessageType === 'video') return `▶ ${t('video')}`
  if (conversation.lastMessageType === 'share')
    return `🔗 ${conversation.lastMessage}`
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
  const area = messagesArea.value
  if (!area) return
  if (!animate) {
    area.scrollTop = area.scrollHeight
    return
  }
  area.scrollTo({ behavior: 'smooth', top: area.scrollHeight })
}

async function openConversation(conversationId: string): Promise<void> {
  if (!(await darkchat.openThread(conversationId))) {
    showToast(errorText(darkchat.lastError ?? undefined))
    return
  }
  screen.value = 'thread'
  resetPanels()
  if (queuedSharePayload.value) {
    shareDraft.value = queuedSharePayload.value
    queuedSharePayload.value = null
  }
  await scrollBottom(false)
}

function back(): void {
  if (screen.value === 'contact') {
    screen.value = 'thread'
    return
  }
  if (screen.value === 'thread') darkchat.closeThread()
  screen.value = 'inbox'
  shareDraft.value = null
  resetPanels()
}

function beginNewChat(): void {
  identifier.value = ''
  screen.value = 'new'
  resetPanels()
}

function openSharedInvite(): void {
  if (!sharedInviteCode.value || !darkchat.profile) return
  identifier.value = sharedInviteCode.value
  sharedInviteCode.value = null
  screen.value = 'new'
  resetPanels()
  const query = { ...route.query }
  delete query.easyShareId
  delete query.easyShareKind
  delete query.easyShareLink
  void router.replace({ path: route.path, query })
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
  const ownIdentifiers = [
    darkchat.profile?.darkId,
    darkchat.profile?.inviteCode,
  ]
  if (
    ownIdentifiers.some(
      (ownIdentifier) =>
        ownIdentifier?.toLocaleLowerCase(phone.lang) ===
        clean.toLocaleLowerCase(phone.lang),
    )
  ) {
    showToast(errorText('self_chat'))
    return
  }
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
  if ((!body && !shareDraft.value) || sending.value) return
  const shared = shareDraft.value
  draft.value = ''
  shareDraft.value = null
  const outgoingReply = replyTo.value?.id
  replyTo.value = null
  resetPanels()
  sending.value = true
  const response = await darkchat.send({
    body,
    messageType: shared ? 'share' : 'text',
    replyToId: outgoingReply,
    sharePayload: shared ?? undefined,
  })
  sending.value = false
  if (!response.success) {
    draft.value = body
    shareDraft.value = shared
    showToast(errorText(response.error))
  }
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

async function openEasyShareDraft(): Promise<boolean> {
  const shared = easyShare.consumeChatDraft('darkchat')
  if (!shared) return false
  if (!shared.targetId) {
    darkchat.closeThread()
    screen.value = 'inbox'
    resetPanels()
    queuedSharePayload.value = shared.payload
    draft.value = ''
    return true
  }
  if (!(await darkchat.openThread(shared.targetId))) {
    showToast(errorText(darkchat.lastError ?? undefined))
    return true
  }
  screen.value = 'thread'
  resetPanels()
  queuedSharePayload.value = null
  shareDraft.value = shared.payload
  draft.value = ''
  await scrollBottom(false)
  return true
}

function shareMessage(message: DarkChatMessage): void {
  selectedMessage.value = null
  useEasyShareStore().open({
    appId: 'darkchat',
    copyText: message.body || message.messageType,
    id: message.id,
    imageUrl:
      message.messageType === 'image' || message.messageType === 'video'
        ? message.mediaPayload
        : undefined,
    kind: 'text',
    subtitle: active.value?.peer.alias,
    title: message.body || message.messageType,
  })
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

async function signOut(): Promise<void> {
  if (profileActionPending.value) return
  profileActionPending.value = true
  const success = await account.logout()
  profileActionPending.value = false
  if (!success) {
    showToast(t('errors.sign_out_failed'))
    return
  }
  signOutOpen.value = false
  darkchat.reset()
  screen.value = 'inbox'
}

async function deleteProfile(): Promise<void> {
  if (profileActionPending.value) return
  profileActionPending.value = true
  const success = await darkchat.deleteProfile()
  profileActionPending.value = false
  if (!success) {
    showToast(errorText(darkchat.lastError ?? undefined))
    return
  }
  deleteProfileOpen.value = false
  screen.value = 'inbox'
}

async function createProfile(): Promise<void> {
  if (profileActionPending.value) return
  profileActionPending.value = true
  const success = await darkchat.createProfile()
  profileActionPending.value = false
  if (!success) showToast(errorText(darkchat.lastError ?? undefined))
  else openSharedInvite()
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

function sharePrivateInvite(): void {
  const profile = darkchat.profile
  if (!profile) return
  easyShare.open({
    appId: 'darkchat',
    copyText: `${profile.alias}\n${profile.darkId}\n${profile.inviteCode}`,
    id: profile.id,
    kind: 'profile',
    link: `skyphone://darkchat/invite/${profile.inviteCode}`,
    subtitle: profile.darkId,
    title: profile.alias,
  })
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
  if (await openEasyShareDraft()) return
  openSharedInvite()
  if (!active.value) return
  screen.value = 'thread'
  const media = messageMedia.consume(`darkchat:${active.value.id}`)
  if (media) await sendAttachment(media)
})

watch(
  () => easyShare.chatDraft,
  (shared) => {
    if (shared?.appId === 'darkchat') void openEasyShareDraft()
  },
)

watch(
  () => darkchat.messages.length,
  () => {
    if (screen.value === 'thread') void scrollBottom(false)
  },
)

onBeforeUnmount(() => {
  discardRecording = true
  cleanupRecording()
  if (toastTimer) clearTimeout(toastTimer)
  if (gifTimer) clearTimeout(gifTimer)
})
</script>

<style scoped>
.dc-ios {
  --dc-accent: var(--sky-app-accent);
  --dc-surface: var(--sky-surface);
  --dc-surface-raised: var(--sky-surface-muted);
  --dc-border: var(--sky-hairline);
  --dc-label: var(--sky-text);
  --dc-secondary: var(--sky-muted);
  --dc-tertiary: var(--sky-muted-2);
}

.dc-ios button,
.dc-ios input,
.dc-ios textarea {
  font: inherit;
}

.dc-screen,
.dc-inbox,
.dc-thread,
.dc-gate {
  width: 100%;
  height: 100%;
  min-height: 0;
}

.dc-screen,
.dc-inbox,
.dc-thread {
  position: relative;
  display: flex;
  flex-direction: column;
}

.dc-gate {
  display: grid;
  padding: 22px;
  place-items: center;
  text-align: center;
}

.dc-gate-card {
  width: 100%;
  margin: 0;
  border-radius: 24px;
}

.dc-gate-card :deep(.sky-card__content) {
  padding: 26px 20px;
}

.dc-gate h1,
.dc-hero h2,
.dc-profile-hero h2 {
  margin: 12px 0 5px;
  color: var(--dc-label);
  font-size: 21px;
  font-weight: 700;
  letter-spacing: -0.35px;
}

.dc-gate p,
.dc-hero p {
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
  border-radius: 17px;
  color: var(--dc-accent);
  background: var(--sky-app-accent-soft);
}

.dc-preloader {
  color: var(--dc-accent);
}

.dc-navbar-action {
  width: 42px;
  height: 42px;
  display: grid;
  padding: 0;
  border: 1px solid var(--dc-border);
  border-radius: 50%;
  color: var(--dc-label);
  place-items: center;
}

.dc-inbox-content,
.dc-scroll-content {
  min-height: 0;
  flex: 1;
}

.dc-inbox-content {
  padding-top: 12px;
}

.dc-inbox-navbar :deep(.sky-navbar__title-container > div) {
  transform: translateY(-14px);
}

.dc-scroll-content {
  padding-top: 14px;
}

.dc-search {
  width: 100%;
  margin: 0;
}

.dc-search :deep(.sky-searchbar__control),
.dc-search :deep(.sky-searchbar__input) {
  height: 38px;
  min-height: 38px;
}

.dc-search :deep(.sky-searchbar__input) {
  font-size: 15px;
}

.dc-search :deep(.sky-searchbar__clear) {
  width: 38px;
  height: 38px;
}

.dc-search :deep(.sky-searchbar__clear::before) {
  position: absolute;
  inset: -3px;
  content: '';
}

.dc-security {
  width: 100%;
  min-height: 58px;
  display: flex;
  margin-bottom: 12px;
  padding: 9px 13px;
  align-items: center;
  gap: 11px;
  border: 1px solid var(--dc-border);
  border-radius: 18px;
  color: var(--dc-label);
  text-align: left;
}

.dc-security > span {
  min-width: 0;
  display: flex;
  flex: 1;
  flex-direction: column;
}

.dc-security strong {
  font-size: 13px;
  font-weight: 650;
}

.dc-security small {
  margin-top: 2px;
  overflow: hidden;
  color: var(--dc-secondary);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-security > svg {
  flex: 0 0 auto;
  color: var(--dc-accent);
}

.dc-conversation-list,
.dc-form-list,
.dc-action-list {
  margin: 0 0 16px;
}

.dc-conversation-list :deep(.sky-list-item__row) {
  min-height: 76px;
}

.dc-conversation-list :deep(.sky-list-item__after) {
  color: var(--dc-tertiary);
  font-size: 11px;
  font-weight: 500;
}

.dc-conversation--unread :deep(.sky-list-item__title) {
  font-weight: 760;
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
  width: 48px;
  height: 48px;
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  font-size: 20px;
  font-style: normal;
  font-weight: 700;
  box-shadow: 0 0 0 1px rgb(255 255 255 / 10%) inset;
}

.dc-avatar i {
  position: absolute;
  top: 0;
  right: 0;
  width: 11px;
  height: 11px;
  border: 2px solid var(--dc-surface);
  border-radius: 50%;
  background: var(--dc-accent);
}

.dc-avatar--small {
  width: 42px;
  height: 42px;
  font-size: 17px;
}

.dc-avatar--profile {
  width: 78px;
  height: 78px;
  font-size: 30px;
}

.dc-empty {
  min-height: 270px;
}

.dc-hero,
.dc-qr-card {
  margin: 0 0 16px;
  border-radius: 22px;
}

.dc-hero {
  text-align: center;
}

.dc-primary {
  margin: 0 2px 22px;
}

.dc-new-chat-scroll {
  padding-top: 2px;
}

.dc-new-chat-intro {
  margin: 2px 2px 12px;
  color: var(--dc-muted);
  font-size: 13px;
  line-height: 18px;
}

.dc-recipient-field,
.dc-new-chat-contacts {
  margin: 0 calc(var(--sky-page-gutter) * -1) 12px;
  border-top: 1px solid var(--dc-border);
  border-bottom: 1px solid var(--dc-border);
  background: transparent;
}

.dc-recipient-field :deep(.sky-field) {
  min-height: 52px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  background: transparent;
}

.dc-recipient-field :deep(.sky-field__inner) {
  min-width: 0;
  padding: 0;
  display: flex;
  flex: 1;
  align-items: center;
  gap: 10px;
}

.dc-recipient-field :deep(.sky-field__label) {
  margin: 0;
  flex: none;
  color: var(--dc-secondary);
  font-size: 14px;
  line-height: 20px;
}

.dc-recipient-field :deep(.sky-field__control),
.dc-recipient-field :deep(.sky-field__input) {
  min-height: 52px;
}

.dc-recipient-field :deep(.sky-field__control) {
  flex: 1;
  margin: 0;
}

.dc-recipient-field :deep(.sky-field__input) {
  font-size: 15px;
}

.dc-new-chat-contacts :deep(.sky-list-item__row) {
  background: transparent;
}

.dc-identifier-action {
  margin: 0;
}

.dc-contacts-group {
  margin-bottom: 18px;
}

.dc-contact-badge {
  display: inline-flex;
  padding: 4px 7px;
  align-items: center;
  gap: 3px;
  border-radius: 999px;
  color: var(--dc-accent);
  background: var(--sky-app-accent-soft);
  font-size: 10px;
  font-weight: 650;
}

.dc-contacts-empty {
  min-height: 78px;
  display: flex;
  padding: 16px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--dc-secondary);
  font-size: 13px;
  list-style: none;
}

.dc-qr-card {
  display: grid;
  padding: 14px;
  grid-template-columns: 72px 1fr;
  align-items: center;
  gap: 13px;
}

.dc-faux-qr {
  width: 72px;
  height: 72px;
  display: grid;
  border-radius: 16px;
  color: #050505;
  background: #f5f5f7;
  place-items: center;
}

.dc-qr-card > div:nth-child(2) {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.dc-qr-card strong {
  overflow: hidden;
  font-size: 15px;
  text-overflow: ellipsis;
}

.dc-qr-card small {
  margin-top: 4px;
  color: var(--dc-secondary);
  font-size: 11px;
  line-height: 1.35;
}

.dc-qr-card :deep(.sky-button) {
  grid-column: 1 / -1;
}

.dc-invite-actions {
  min-width: 0;
  display: grid;
  grid-column: 1 / -1;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.dc-invite-actions :deep(.sky-button) {
  min-width: 0;
  grid-column: auto;
}

.dc-thread-meta {
  min-height: 28px;
  display: flex;
  padding: 5px 12px;
  align-items: center;
  justify-content: center;
  gap: 4px;
  flex: 0 0 auto;
  border-bottom: 1px solid var(--dc-border);
  color: var(--dc-secondary);
  background: var(--sky-surface);
  font-size: 10px;
}

.dc-thread-meta span {
  color: var(--dc-tertiary);
}

.dc-messages {
  min-height: 0;
  display: flex;
  padding: 12px 10px 10px;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 7px;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.dc-messages::-webkit-scrollbar {
  display: none;
}

.dc-day {
  align-self: center;
  margin: auto 0 8px;
  padding: 5px 9px;
  border-radius: 10px;
  color: var(--dc-secondary);
  background: var(--dc-surface-raised);
  font-size: 10px;
  font-weight: 600;
}

.dc-system {
  display: inline-flex;
  margin: 4px auto;
  padding: 5px 9px;
  align-items: center;
  gap: 5px;
  border-radius: 10px;
  color: var(--dc-secondary);
  background: rgb(44 44 46 / 82%);
  font-size: 10px;
  text-align: center;
}

.dc-message {
  position: relative;
  max-width: 82%;
  display: flex;
  padding: 9px 13px 7px;
  flex: 0 0 auto;
  flex-direction: column;
  border: 0;
  color: var(--dc-label);
  text-align: left;
  overflow-wrap: anywhere;
}

.dc-message--received {
  align-self: flex-start;
  border-radius: 20px 20px 20px 5px;
  background: var(--dc-surface-raised);
}

.dc-message--sent {
  align-self: flex-end;
  border-radius: 20px 20px 5px;
  background: var(--dc-accent);
}

.dc-message--failed {
  box-shadow: 0 0 0 1px #ff453a inset;
}

.dc-message-body {
  font-size: 15px;
  line-height: 1.28;
  white-space: pre-wrap;
}

.dc-message > img,
.dc-message > video {
  width: 100%;
  max-height: 220px;
  margin-bottom: 4px;
  border-radius: 12px;
  object-fit: cover;
}

.dc-message > small {
  margin-top: 3px;
  align-self: flex-end;
  color: rgb(255 255 255 / 68%);
  font-size: 9px;
}

.dc-reply-preview {
  width: 100%;
  display: flex;
  margin-bottom: 5px;
  padding: 5px 7px;
  align-items: center;
  gap: 5px;
  overflow: hidden;
  border-left: 2px solid currentColor;
  border-radius: 5px;
  background: rgb(0 0 0 / 14%);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-reactions {
  position: absolute;
  right: 4px;
  bottom: -12px;
  padding: 1px 5px;
  border: 1px solid var(--dc-border);
  border-radius: 9px;
  background: var(--dc-surface-raised);
  font-size: 11px;
}

.dc-replying {
  display: flex;
  padding: 8px 12px;
  align-items: center;
  gap: 9px;
  border-top: 1px solid var(--dc-border);
  background: var(--dc-surface);
}

.dc-replying > span {
  min-width: 0;
  display: flex;
  flex: 1;
  flex-direction: column;
}

.dc-replying small {
  color: var(--dc-accent);
  font-size: 10px;
}

.dc-replying strong {
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-attachments {
  position: absolute;
  z-index: 48;
  bottom: calc(var(--sky-safe-area-bottom) + 78px);
  left: calc(var(--sky-safe-area-left) + var(--sky-page-gutter));
  display: flex;
  align-items: flex-start;
  flex-direction: column;
  gap: 7px;
}

.dc-attachment-action {
  width: auto;
  min-height: 42px;
  display: flex;
  padding: 4px 14px 4px 5px;
  align-items: center;
  gap: 9px;
  border-radius: var(--sky-radius-pill);
  color: var(--dc-label);
  font-size: 12px;
  font-weight: 650;
}

.dc-attachment-action > span {
  width: 32px;
  height: 32px;
  display: grid;
  flex: 0 0 32px;
  border-radius: 50%;
  color: var(--dc-accent);
  background: var(--sky-app-accent-soft);
  place-items: center;
}

.dc-attachment-action > small {
  width: auto;
  color: inherit;
  font-size: inherit;
  font-weight: inherit;
  line-height: 1;
  white-space: nowrap;
}

.dc-gif-panel {
  max-height: 260px;
  margin: 0 8px 8px;
  overflow: auto;
  flex: 0 1 auto;
}

.dc-gif-panel header {
  display: flex;
  margin-bottom: 8px;
  align-items: center;
  justify-content: space-between;
}

.dc-gif-grid {
  display: grid;
  margin-top: 8px;
  grid-template-columns: repeat(3, 1fr);
  gap: 5px;
}

.dc-gif-grid button {
  overflow: hidden;
  border: 0;
  border-radius: 7px;
  aspect-ratio: 1;
  background: var(--dc-surface-raised);
}

.dc-gif-grid img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.dc-recorder {
  min-height: 56px;
  display: flex;
  padding: 6px 8px;
  align-items: center;
  gap: 9px;
}

.dc-recorder > i {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #ff453a;
}

.dc-recorder time {
  color: var(--dc-label);
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}

.dc-recorder > span {
  min-width: 0;
  height: 25px;
  display: flex;
  flex: 1;
  align-items: center;
  gap: 1px;
}

.dc-recorder b {
  min-width: 1px;
  flex: 1;
  border-radius: 1px;
  background: var(--dc-accent);
}

.dc-composer-pill {
  box-sizing: border-box;
  min-width: 0;
  margin: var(--sky-space-2)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-right))
    calc(var(--sky-safe-area-bottom) + 10px)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
  overflow: hidden;
  flex: 0 0 auto;
  border-radius: var(--sky-radius-pill);
}

.dc-composer-row {
  display: flex;
  margin: var(--sky-space-2)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-right))
    calc(var(--sky-safe-area-bottom) + 10px)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
  align-items: center;
  gap: var(--sky-space-2);
  flex: 0 0 auto;
}

.dc-composer-row .dc-composer-pill {
  width: 100%;
  min-height: 56px;
  display: flex;
  margin: 0;
  padding: 5px 7px;
  align-items: center;
  gap: 6px;
  flex: 1 1 auto;
}

.dc-composer-action {
  box-sizing: border-box;
  width: 46px;
  height: 46px;
  display: grid;
  padding: 0;
  overflow: hidden;
  flex: 0 0 46px;
  border-radius: 50%;
  color: var(--dc-accent);
  place-items: center;
  transition:
    color 180ms ease,
    transform 180ms ease;
}

.dc-composer-action.active {
  color: #fff;
  background: var(--dc-accent);
  transform: rotate(45deg);
}

.dc-composer {
  min-width: 0;
  padding: 0;
  flex: 1;
  gap: 4px;
  background: transparent;
}

.dc-composer :deep(textarea) {
  min-height: var(--sky-touch-target);
  border-radius: var(--sky-radius-pill);
  padding: 12px 14px;
}

.dc-composer :deep(.sky-messagebar__right) {
  margin-right: 0;
}

.dc-profile-hero {
  display: flex;
  padding: 18px 14px 22px;
  align-items: center;
  flex-direction: column;
  text-align: center;
}

.dc-profile-hero h2 {
  margin-bottom: 1px;
}

.dc-profile-hero :deep(.sky-button) {
  min-height: 34px;
  padding: 5px 10px;
  font-size: 13px;
}

.dc-profile-hero > small {
  color: var(--dc-tertiary);
  font-size: 11px;
}

.dc-setting-value {
  max-width: 120px;
  display: block;
  overflow: hidden;
  color: var(--dc-tertiary);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dc-danger-row :deep(.sky-list-item__title),
.dc-danger-row :deep(svg) {
  color: var(--sky-danger);
}

.sky-dialog-button.dc-danger-text:not(:disabled) {
  background: var(--sky-danger);
  color: #ffffff;
}

.sky-dialog-button.dc-danger-text:active:not(:disabled) {
  filter: brightness(0.86);
}

.dc-privacy-note {
  display: flex;
  margin: 4px 16px 22px;
  align-items: flex-start;
  gap: 8px;
  color: var(--dc-tertiary);
  font-size: 11px;
  line-height: 1.4;
}

.dc-privacy-note svg {
  flex: 0 0 auto;
}

.dc-dialog p {
  margin: 8px 0;
  color: var(--dc-secondary);
  font-size: 13px;
  line-height: 1.45;
}

.dc-dialog-icon {
  width: 48px;
  height: 48px;
  display: grid;
  margin: 4px auto 10px;
  border-radius: 50%;
  color: var(--dc-accent);
  background: var(--sky-app-accent-soft);
  place-items: center;
}

.dc-dialog-icon--danger {
  color: var(--sky-danger);
  background: rgb(255 69 58 / 14%);
}

.dc-dialog-id {
  display: block;
  margin-top: 10px;
  padding: 8px;
  border-radius: 9px;
  color: var(--dc-accent);
  background: var(--dc-surface-raised);
  font-size: 13px;
  text-align: center;
}

.dc-action-sheet :deep(.sky-sheet__panel) {
  padding: 6px 0 calc(var(--sky-safe-area-bottom) + 12px);
}

.dc-selection-sheet :deep(.sky-sheet__panel) {
  max-height: 72%;
}

.dc-selection-sheet h3 {
  margin: 5px 16px 11px;
  color: var(--dc-label);
  font-size: 17px;
  text-align: center;
}

.dc-sheet-handle {
  width: 36px;
  height: 5px;
  margin: 6px auto 10px;
  border-radius: 3px;
  background: rgb(255 255 255 / 24%);
}

.dc-reaction-row {
  display: flex;
  padding: 3px 11px 10px;
  justify-content: space-between;
}

.dc-reaction-row button {
  width: 42px;
  height: 42px;
  border: 1px solid var(--dc-border);
  border-radius: 50%;
  background: var(--dc-surface-raised);
  font-size: 20px;
}

.dc-sheet-cancel {
  width: calc(100% - 24px);
  margin: 2px 12px 0;
}

.dc-report-reason {
  margin: 12px 0 8px;
}

.dc-notification {
  z-index: 150;
}

.dc-message :deep(.darkchat-voice) {
  color: #fff;
}

.dc-message :deep(.darkchat-voice__time),
.dc-message :deep(.darkchat-voice__speed) {
  color: rgb(255 255 255 / 72%);
}

@media (max-width: 360px) {
  .dc-message {
    max-width: 86%;
  }

  .dc-attachments :deep(.sky-button) {
    padding-inline: 8px;
    font-size: 10px;
  }
}
</style>

<template>
  <SkyAppPage
    class="darkchat-page dc-ios"
    :label="t('name')"
    :dark="phone.isDarkMode"
    accent="#0a84ff"
    accent-soft="rgb(10 132 255 / 18%)"
  >
    <section v-if="!signedIn" class="dc-gate">
      <SkyCard class="dc-gate-card" outline>
        <span class="dc-icon-tile"><LockKeyhole :size="28" /></span>
        <h1>{{ t('name') }}</h1>
        <p>{{ t('signInBody') }}</p>
        <small>{{ t('signInHint') }}</small>
      </SkyCard>
    </section>

    <section v-else-if="darkchat.loading && !darkchat.profile" class="dc-gate">
      <SkySpinner class="dc-preloader" />
      <p>{{ phone.t('Common.loading') }}</p>
    </section>

    <section v-else-if="!darkchat.profile" class="dc-gate">
      <SkyEmptyState
        :title="t('createIdentity')"
        :body="t('createIdentityBody')"
      >
        <template #icon><ShieldCheck :size="30" /></template>
        <template #actions>
          <SkyButton
            large
            rounded
            :disabled="profileActionPending"
            @click="createProfile"
          >
            {{
              profileActionPending
                ? phone.t('Common.loading')
                : t('createIdentity')
            }}
          </SkyButton>
        </template>
      </SkyEmptyState>
    </section>

    <template v-else>
      <section v-if="screen === 'inbox'" class="dc-screen dc-inbox">
        <SkyNavbar
          class="dc-inbox-navbar"
          :title="t('name')"
          :subtitle="t('privateNetwork')"
          variant="large"
        >
          <template #left>
            <SkyLink
              icon-only
              :aria-label="t('myIdentity')"
              @click="openProfile"
            >
              <UserRound :size="20" />
            </SkyLink>
          </template>
          <template #right>
            <SkyLink icon-only :aria-label="t('newChat')" @click="beginNewChat">
              <SquarePen :size="21" />
            </SkyLink>
          </template>
          <template #subnavbar>
            <SkySearchbar
              v-model="search"
              class="dc-search"
              :label="phone.t('Common.search')"
              :placeholder="phone.t('Common.search')"
              :clear-label="phone.t('Common.clear')"
            />
          </template>
        </SkyNavbar>

        <SkyScrollArea padded class="dc-inbox-content">
          <SkyGlass
            component="button"
            class="dc-security"
            @click="copyIdentity(darkchat.profile.darkId)"
          >
            <LockKeyhole :size="17" />
            <span>
              <strong>{{ t('privateNetwork') }}</strong>
              <small>{{ darkchat.profile.darkId }}</small>
            </span>
            <Copy :size="16" />
          </SkyGlass>

          <SkyList
            v-if="filteredConversations.length"
            inset
            strong
            class="dc-conversation-list"
          >
            <SkyListItem
              v-for="conversation in filteredConversations"
              :key="conversation.id"
              link
              link-component="button"
              strong-title="auto"
              :title="conversation.peer.alias"
              :subtitle="preview(conversation)"
              :class="{ 'dc-conversation--unread': conversation.unread }"
              @click="openConversation(conversation.id)"
            >
              <template #media>
                <span
                  class="dc-avatar"
                  :style="{
                    background: avatarGradient(conversation.peer.avatarSeed),
                  }"
                >
                  {{ avatarGlyph(conversation.peer.avatarSeed) }}
                  <i v-if="conversation.unread" />
                </span>
              </template>
              <template #after>
                <time>{{ formatDate(conversation.lastMessageAt) }}</time>
              </template>
              <template v-if="conversation.disappearingSeconds !== 0" #footer>
                <span class="dc-timer">
                  <Clock3 :size="11" />
                  {{ timerLabel(conversation.disappearingSeconds) }}
                </span>
              </template>
            </SkyListItem>
          </SkyList>

          <SkyEmptyState
            v-else
            class="dc-empty"
            :title="search ? t('noResults') : t('noChats')"
            :body="search ? t('noResultsBody') : t('noChatsBody')"
          >
            <template #icon><ShieldCheck :size="27" /></template>
          </SkyEmptyState>
        </SkyScrollArea>
      </section>

      <section v-else-if="screen === 'new'" class="dc-screen">
        <SkyNavbar :title="t('newChat')">
          <template #right>
            <SkyLink @click="back">{{ phone.t('Common.cancel') }}</SkyLink>
          </template>
        </SkyNavbar>
        <SkyScrollArea padded class="dc-new-chat-scroll">
          <p class="dc-new-chat-intro">{{ t('newChatBody') }}</p>
          <SkyList class="dc-recipient-field" density="compact" flush>
            <SkyField
              :label="t('to')"
              layout="inline"
              :value="identifier"
              autocomplete="off"
              :placeholder="t('darkIdOrInvite')"
              clear-button
              :clear-label="phone.t('Common.clear')"
              @input="setIdentifier"
              @clear="identifier = ''"
              @keyup.enter="requestStart()"
            />
          </SkyList>
          <SkyList
            v-if="contactSuggestions.length"
            class="dc-new-chat-contacts"
            flush
          >
            <SkyListItem
              v-for="contact in contactSuggestions"
              :key="contact.id"
              link
              link-component="button"
              contacts
              strong-title="auto"
              :title="contact.alias"
              :subtitle="contact.darkId"
              @click="requestStart(contact.darkId)"
            >
              <template #media>
                <span
                  class="dc-avatar dc-avatar--small"
                  :style="{ background: avatarGradient(contact.avatarSeed) }"
                >
                  {{ avatarGlyph(contact.avatarSeed) }}
                </span>
              </template>
              <template #after>
                <span class="dc-contact-badge">
                  <LockKeyhole :size="11" />{{ t('private') }}
                </span>
              </template>
            </SkyListItem>
          </SkyList>
          <SkyButton
            v-else-if="identifier.trim()"
            rounded
            tonal
            class="dc-identifier-action"
            @click="requestStart()"
          >
            <MessageCirclePlus :size="17" />
            {{ identifier }}
          </SkyButton>
        </SkyScrollArea>
      </section>

      <section
        v-else-if="screen === 'thread' && active"
        class="dc-screen dc-thread"
        :class="{ 'dc-thread--panel': attachmentPanelOpen }"
      >
        <SkyNavbar
          :title="active.peer.alias"
          :subtitle="active.peer.activityVisible ? t('activeNow') : ''"
          show-back
          back-appearance="surface"
          :back-label="phone.t('Common.back')"
          @back="back"
        >
          <template #right>
            <SkyGlass
              component="button"
              class="dc-navbar-action"
              :aria-label="t('contactSecurity')"
              @click="openContact"
            >
              <UserRound :size="19" />
            </SkyGlass>
          </template>
        </SkyNavbar>
        <div class="dc-thread-meta">
          <LockKeyhole :size="13" />{{ t('serverPrivate') }}
          <span v-if="active.disappearingSeconds !== 0">
            · {{ timerLabel(active.disappearingSeconds) }}
          </span>
        </div>
        <div ref="messagesArea" class="darkchat-thread__messages dc-messages">
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
              <span v-if="message.replyBody" class="dc-reply-preview">
                <Reply :size="12" />{{ message.replyBody }}
              </span>
              <img
                v-if="
                  message.messageType === 'gif' ||
                  message.messageType === 'image'
                "
                :src="message.mediaPayload || undefined"
                :alt="message.messageType === 'gif' ? 'GIF' : t('photo')"
                @load="scrollBottom(false)"
              />
              <video
                v-else-if="message.messageType === 'video'"
                :src="message.mediaPayload || undefined"
                controls
                playsinline
                preload="metadata"
                @loadedmetadata="scrollBottom(false)"
              />
              <DarkChatVoiceMessage
                v-else-if="message.messageType === 'voice'"
                :message="message"
              />
              <SharedContentCard
                v-else-if="
                  message.messageType === 'share' && message.sharePayload
                "
                :payload="message.sharePayload"
                variant="darkchat"
              />
              <span v-else class="dc-message-body">{{ message.body }}</span>
              <span
                v-if="Object.keys(message.reactions).length"
                class="dc-reactions"
              >
                {{ Object.values(message.reactions).join(' ') }}
              </span>
              <small>
                {{ formatDate(message.createdAt) }}
                <template v-if="message.direction === 'sent'">
                  ·
                  {{
                    message.deliveryStatus === 'sending'
                      ? t('sending')
                      : message.deliveryStatus === 'failed'
                        ? t('failed')
                        : message.readAt
                          ? t('read')
                          : t('delivered')
                  }}
                </template>
              </small>
            </button>
          </template>
        </div>

        <div v-if="replyTo" class="dc-replying">
          <Reply :size="15" />
          <span>
            <small>{{ t('replying') }}</small>
            <strong>{{ replyTo.body || t(replyTo.messageType) }}</strong>
          </span>
          <SkyLink icon-only @click="replyTo = null"><X :size="17" /></SkyLink>
        </div>
        <div v-if="attachmentOpen" class="dc-attachments">
          <SkyGlass
            component="button"
            class="dc-attachment-action"
            @click="openMediaApp('photos', 'photo')"
          >
            <span><Images :size="19" /></span>
            <small>{{ t('photo') }}</small>
          </SkyGlass>
          <SkyGlass
            component="button"
            class="dc-attachment-action"
            @click="openMediaApp('camera', 'photo')"
          >
            <span><Camera :size="19" /></span>
            <small>{{ t('takePhoto') }}</small>
          </SkyGlass>
          <SkyGlass
            component="button"
            class="dc-attachment-action"
            @click="openEmojiPanel"
          >
            <span><Smile :size="19" /></span>
            <small>{{ t('emoji') }}</small>
          </SkyGlass>
          <SkyGlass
            component="button"
            class="dc-attachment-action"
            @click="openGifPanel"
          >
            <span><ImagePlay :size="19" /></span>
            <small>{{ t('gif') }}</small>
          </SkyGlass>
          <SkyGlass
            component="button"
            class="dc-attachment-action"
            @click="openMediaApp('photos', 'video')"
          >
            <span><Video :size="19" /></span>
            <small>{{ t('video') }}</small>
          </SkyGlass>
        </div>
        <SkyCard v-if="gifOpen" class="dc-gif-panel" outline>
          <header>
            <strong>{{ t('gifs') }}</strong>
            <SkyLink @click="gifOpen = false">{{
              phone.t('Common.done')
            }}</SkyLink>
          </header>
          <SkySearchbar
            :value="gifQuery"
            :label="t('searchGifs')"
            :placeholder="t('searchGifs')"
            :clear-label="phone.t('Common.clear')"
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
          <SkyButton v-if="gifHasMore && !gifLoading" clear @click="loadGifs()">
            {{ t('loadMore') }}
          </SkyButton>
          <SkySpinner v-if="gifLoading" class="dc-preloader" />
        </SkyCard>
        <FullEmojiPicker
          v-if="emojiOpen"
          @close="emojiOpen = false"
          @pick="appendEmoji"
        />
        <div
          v-if="shareDraft"
          class="shared-composer-preview shared-composer-preview--dark"
        >
          <SharedContentCard compact :payload="shareDraft" variant="darkchat" />
          <button
            type="button"
            :aria-label="phone.t('Common.close')"
            @click="shareDraft = null"
          >
            <X :size="15" />
          </button>
        </div>
        <SkyGlass v-if="recording" class="dc-composer-pill dc-recorder">
          <SkyLink icon-only @click="cancelRecording"><X :size="19" /></SkyLink>
          <i />
          <time>{{ recordingTime() }}</time>
          <span>
            <b
              v-for="(level, index) in recordingLevels"
              :key="index"
              :style="{ height: `${Math.max(3, level * 23)}px` }"
            />
          </span>
          <SkyLink icon-only @click="stopRecording">
            <ArrowUpCircle :size="29" />
          </SkyLink>
        </SkyGlass>
        <div v-else class="dc-composer-row">
          <SkyGlass component="div" :highlight="false" class="dc-composer-pill">
            <SkyGlass
              component="button"
              class="dc-composer-action"
              :class="{ active: attachmentOpen || attachmentPanelOpen }"
              :aria-label="phone.t('Common.add')"
              @click="toggleAttachmentPanel"
            >
              <Plus :size="23" />
            </SkyGlass>
            <SkyMessagebar
              class="dc-composer"
              embedded
              :outline="false"
              :value="draft"
              :placeholder="t('message')"
              @input="setDraft"
              @keydown.enter.exact="handleEnterAction($event, sendText)"
            >
              <template #right>
                <SkyLink
                  v-if="draft.trim() || shareDraft"
                  icon-only
                  @click="sendText"
                >
                  <ArrowUpCircle :size="27" />
                </SkyLink>
                <SkyLink v-else icon-only @click="startRecording">
                  <Mic :size="20" />
                </SkyLink>
              </template>
            </SkyMessagebar>
          </SkyGlass>
        </div>
      </section>

      <section v-else-if="screen === 'contact' && active" class="dc-screen">
        <SkyNavbar
          :title="t('contactSecurity')"
          show-back
          back-appearance="surface"
          :back-label="phone.t('Common.back')"
          @back="back"
        />
        <SkyScrollArea padded class="dc-scroll-content">
          <div class="dc-profile-hero">
            <span
              class="dc-avatar dc-avatar--profile"
              :style="{ background: avatarGradient(active.peer.avatarSeed) }"
            >
              {{ avatarGlyph(active.peer.avatarSeed) }}
            </span>
            <h2>{{ active.peer.alias }}</h2>
            <SkyButton clear rounded @click="copyIdentity(active.peer.darkId)">
              {{ active.peer.darkId }}<Copy :size="14" />
            </SkyButton>
            <small>{{
              t('chatSince', { date: dayLabel(active.createdAt) })
            }}</small>
          </div>

          <SkySettingsGroup :title="t('chatSettings')">
            <SkySettingsRow
              kind="toggle"
              :title="t('notifications')"
              :model-value="active.notificationsEnabled"
              @update:model-value="setConversationNotifications"
            >
              <template #leading><Bell :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="toggle"
              :title="t('readReceipts')"
              :model-value="active.readReceipts"
              @update:model-value="setReadReceipts"
            >
              <template #leading><Check :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="navigation"
              :title="t('disappearing')"
              :value="timerLabel(active.disappearingSeconds)"
              @activate="selectionSheet = 'disappearing'"
            >
              <template #leading><Clock3 :size="20" /></template>
            </SkySettingsRow>
          </SkySettingsGroup>

          <SkyList inset strong class="dc-form-list">
            <SkyField
              :label="t('contactAlias')"
              :value="contactAliasDraft"
              maxlength="32"
              @input="setContactAliasDraft"
            />
          </SkyList>
          <SkyButton
            large
            rounded
            block
            class="dc-primary"
            @click="saveContact"
          >
            <UserPlus :size="18" />
            {{ active.peer.isContact ? t('saveContact') : t('addContact') }}
          </SkyButton>

          <SkySettingsGroup :title="t('contactActions')">
            <SkySettingsRow
              v-if="active.peer.isContact"
              kind="action"
              :title="t('removeContact')"
              @activate="removeContact"
            >
              <template #leading><UserMinus :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="action"
              tone="danger"
              :title="active.peer.blocked ? t('unblock') : t('block')"
              @activate="toggleBlock"
            >
              <template #leading><ShieldOff :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="action"
              tone="danger"
              :title="t('report')"
              @activate="beginReport()"
            >
              <template #leading><BellOff :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="action"
              tone="danger"
              :title="t('clearChat')"
              @activate="clearChat"
            >
              <template #leading><Trash2 :size="20" /></template>
            </SkySettingsRow>
          </SkySettingsGroup>
        </SkyScrollArea>
      </section>

      <section v-else-if="screen === 'profile'" class="dc-screen">
        <SkyNavbar
          :title="t('myIdentity')"
          show-back
          back-appearance="surface"
          :back-label="phone.t('Common.back')"
          @back="back"
        >
          <template #right>
            <SkyLink @click="saveProfile">{{ phone.t('Common.done') }}</SkyLink>
          </template>
        </SkyNavbar>
        <SkyScrollArea padded class="dc-scroll-content">
          <div class="dc-profile-hero">
            <span
              class="dc-avatar dc-avatar--profile"
              :style="{
                background: avatarGradient(darkchat.profile.avatarSeed),
              }"
            >
              {{ avatarGlyph(darkchat.profile.avatarSeed) }}
            </span>
            <h2>{{ darkchat.profile.alias }}</h2>
            <SkyButton
              clear
              rounded
              @click="copyIdentity(darkchat.profile.darkId)"
            >
              {{ darkchat.profile.darkId }}<Copy :size="14" />
            </SkyButton>
          </div>

          <SkyList inset strong class="dc-form-list">
            <SkyField
              :label="t('alias')"
              :value="aliasDraft"
              maxlength="32"
              @input="setAliasDraft"
            />
          </SkyList>

          <SkySettingsGroup :title="t('privacySettings')">
            <SkySettingsRow
              kind="navigation"
              :title="t('notificationPrivacy')"
              :value="
                notificationOptions.find(
                  (option) => option.value === notificationMode,
                )?.label
              "
              @activate="selectionSheet = 'notification'"
            >
              <template #leading><Bell :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="toggle"
              :title="t('shareActivity')"
              :model-value="activityVisible"
              @update:model-value="setActivityVisible"
            >
              <template #leading><ShieldCheck :size="20" /></template>
            </SkySettingsRow>
          </SkySettingsGroup>

          <SkyCard class="dc-qr-card" outline :content-wrap="false">
            <div class="dc-faux-qr"><QrCode :size="58" /></div>
            <div>
              <strong>{{ darkchat.profile.inviteCode }}</strong>
              <small>{{ t('inviteCode') }}</small>
            </div>
            <div class="dc-invite-actions">
              <SkyButton
                clear
                rounded
                @click="copyIdentity(darkchat.profile.inviteCode)"
              >
                <Copy :size="16" />{{ t('copyInvite') }}
              </SkyButton>
              <SkyButton tonal rounded @click="sharePrivateInvite">
                <Share2 :size="16" />{{ t('shareInvite') }}
              </SkyButton>
            </div>
          </SkyCard>
          <p class="dc-privacy-note">
            <LockKeyhole :size="17" />{{ t('privacyDisclaimer') }}
          </p>

          <SkySettingsGroup
            :title="t('profileActions')"
            :footer="t('signOutHint')"
          >
            <SkySettingsRow
              kind="action"
              :title="t('signOut')"
              @activate="signOutOpen = true"
            >
              <template #leading><LogOut :size="20" /></template>
            </SkySettingsRow>
            <SkySettingsRow
              kind="action"
              tone="danger"
              :title="t('deleteProfile')"
              @activate="deleteProfileOpen = true"
            >
              <template #leading><Trash2 :size="20" /></template>
            </SkySettingsRow>
          </SkySettingsGroup>
        </SkyScrollArea>
      </section>
    </template>

    <SkyDialog
      :opened="safetyOpen"
      class="dc-dialog"
      @backdropclick="safetyOpen = false"
      @escape="safetyOpen = false"
    >
      <template #title>{{ t('unknownIdentity') }}</template>
      <span class="dc-dialog-icon"><ShieldCheck :size="25" /></span>
      <p>{{ t('unknownIdentityBody') }}</p>
      <strong class="dc-dialog-id">{{ pendingIdentifier }}</strong>
      <template #buttons>
        <SkyDialogButton @click="safetyOpen = false">
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton strong @click="confirmStart">
          {{ t('openSecureChat') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkySheet
      :opened="Boolean(selectedMessage)"
      :aria-label="t('messageActions')"
      class="dc-action-sheet"
      @backdropclick="selectedMessage = null"
      @escape="selectedMessage = null"
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
        <SkyList inset strong class="dc-action-list">
          <SkyListItem
            link
            link-component="button"
            :title="phone.t('Apps.easyShare.name')"
            @click="shareMessage(selectedMessage)"
          >
            <template #media><Share2 :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            link
            link-component="button"
            :title="t('reply')"
            @click="beginReply(selectedMessage)"
          >
            <template #media><Reply :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            v-if="
              selectedMessage.messageType === 'text' ||
              selectedMessage.messageType === 'emoji'
            "
            link
            link-component="button"
            :title="t('copy')"
            @click="copyMessage(selectedMessage)"
          >
            <template #media><Copy :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            link
            link-component="button"
            :title="t('deleteForMe')"
            @click="messageAction(selectedMessage, 'delete_me')"
          >
            <template #media><Trash2 :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            v-if="selectedMessage.direction === 'sent'"
            link
            link-component="button"
            class="dc-danger-row"
            :title="t('deleteForBoth')"
            @click="messageAction(selectedMessage, 'delete_all')"
          >
            <template #media><Trash2 :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            v-if="selectedMessage.direction === 'received'"
            link
            link-component="button"
            class="dc-danger-row"
            :title="t('report')"
            @click="beginReport(selectedMessage)"
          >
            <template #media><ShieldOff :size="20" /></template>
          </SkyListItem>
        </SkyList>
        <SkyButton
          large
          rounded
          block
          variant="secondary"
          class="dc-sheet-cancel"
          @click="selectedMessage = null"
        >
          {{ phone.t('Common.cancel') }}
        </SkyButton>
      </template>
    </SkySheet>

    <SkyDialog
      :opened="reportOpen"
      class="dc-dialog dc-report-dialog"
      @backdropclick="closeReport"
      @escape="closeReport"
    >
      <template #title>{{ t('reportUser') }}</template>
      <span class="dc-dialog-icon dc-dialog-icon--danger">
        <ShieldOff :size="25" />
      </span>
      <SkyList inset strong class="dc-action-list dc-report-reason">
        <SkyListItem
          link
          link-component="button"
          :title="t('reportUser')"
          @click="selectionSheet = 'report'"
        >
          <template #after>
            <span class="dc-setting-value">
              {{
                reportOptions.find((option) => option.value === reportReason)
                  ?.label
              }}
            </span>
          </template>
        </SkyListItem>
      </SkyList>
      <SkyList inset strong class="dc-form-list">
        <SkyField
          type="textarea"
          :value="reportDetails"
          maxlength="500"
          :placeholder="t('reportDetails')"
          @input="setReportDetails"
        />
      </SkyList>
      <template #buttons>
        <SkyDialogButton @click="closeReport">
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton strong class="dc-danger-text" @click="submitReport">
          {{ t('submitReport') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkySheet
      :opened="selectionSheet !== null"
      :aria-label="selectionTitle"
      class="dc-action-sheet dc-selection-sheet"
      @backdropclick="selectionSheet = null"
      @escape="selectionSheet = null"
    >
      <div class="dc-sheet-handle" />
      <h3>{{ selectionTitle }}</h3>
      <SkyList inset strong class="dc-action-list dc-selection-list">
        <SkyListItem
          v-for="option in selectionOptions"
          :key="option.value"
          link
          link-component="button"
          :chevron="false"
          :title="option.label"
          @click="chooseSelection(option.value)"
        >
          <template
            v-if="String(option.value) === String(selectionValue)"
            #after
          >
            <Check :size="20" />
          </template>
        </SkyListItem>
      </SkyList>
      <SkyButton
        large
        rounded
        block
        variant="secondary"
        class="dc-sheet-cancel"
        @click="selectionSheet = null"
      >
        {{ phone.t('Common.cancel') }}
      </SkyButton>
    </SkySheet>

    <SkyDialog
      :opened="signOutOpen"
      :title="t('signOutTitle')"
      :content="t('signOutBody')"
      @backdropclick="signOutOpen = false"
      @escape="signOutOpen = false"
    >
      <template #buttons>
        <SkyDialogButton
          :disabled="profileActionPending"
          @click="signOutOpen = false"
        >
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          :disabled="profileActionPending"
          @click="signOut"
        >
          {{ profileActionPending ? t('signingOut') : t('signOut') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyDialog
      :opened="deleteProfileOpen"
      :title="t('deleteProfileTitle')"
      :content="t('deleteProfileBody')"
      @backdropclick="deleteProfileOpen = false"
      @escape="deleteProfileOpen = false"
    >
      <template #buttons>
        <SkyDialogButton
          :disabled="profileActionPending"
          @click="deleteProfileOpen = false"
        >
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          class="dc-danger-text"
          :disabled="profileActionPending"
          @click="deleteProfile"
        >
          {{
            profileActionPending
              ? t('deletingProfile')
              : phone.t('Common.delete')
          }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyNotification
      :opened="Boolean(toast)"
      :text="toast"
      class="dc-notification"
    />
  </SkyAppPage>
</template>
