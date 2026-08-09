<script setup lang="ts">
import {
  kBlock,
  kGlass,
  kLink,
  kList,
  kListInput,
  kListItem,
  kMessage,
  kMessagebar,
  kMessages,
  kMessagesTitle,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPreloader,
  kSearchbar,
  kToast,
  kToolbarPane,
} from 'konsta/vue'
import {
  ArrowUpCircle,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  ImagePlay,
  Images,
  ListFilter,
  MessageCircle,
  Mic,
  Pencil,
  Phone as PhoneIcon,
  Plus,
  Search,
  SquarePen,
  Trash2,
  UserPlus,
  Video,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import MessageAttachmentBubble from '@/components/MessageAttachmentBubble.vue'
import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import VoiceMessageBubble from '@/components/VoiceMessageBubble.vue'
import { useCallsStore } from '@/stores/calls'
import { useMessagesStore } from '@/stores/messages'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'
import type {
  GifSearchResult,
  SmsAttachmentType,
  SmsConversation,
  SmsMessage,
} from '@/types/messages'

const VOICE_MAX_DURATION_MS = 30_000
const VOICE_MAX_BYTES = 135_000
const WAVEFORM_SAMPLES = 48

const phone = usePhoneStore()
const calls = useCallsStore()
const messages = useMessagesStore()
const messageMedia = useMessageMediaStore()
const router = useRouter()
const search = ref('')
const showUnreadOnly = ref(false)
const editingList = ref(false)
const selectedNumbers = ref<string[]>([])
const composerNumber = ref('')
const draft = ref('')
const composing = ref(false)
const sending = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
const emojiOpen = ref(false)
const attachmentMenuOpen = ref(false)
const attachmentPicker = ref<'gifs' | null>(null)
const contactDetailsOpen = ref(false)
const contactEditing = ref(false)
const contactNameDraft = ref('')
const contactNumberDraft = ref('')
const gifQuery = ref('')
const gifResults = ref<GifSearchResult[]>([])
const gifLoading = ref(false)
const gifError = ref<string | null>(null)
const gifHasMore = ref(true)
const gifNextOffset = ref(0)
const recording = ref(false)
const recordingElapsedMs = ref(0)
const recordingLevels = ref<number[]>(Array(32).fill(0.16))
let toastTimer: ReturnType<typeof setTimeout> | undefined
let gifSearchTimer: ReturnType<typeof setTimeout> | undefined
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

const hasSim = computed(() => Boolean(phone.device?.sim))
const filteredConversations = computed(() => {
  const query = search.value.trim().toLocaleLowerCase(phone.lang)
  return messages.conversations.filter((conversation) => {
    if (showUnreadOnly.value && conversation.unread === 0) return false
    if (!query) return true
    return `${contactName(conversation.phoneNumber)} ${conversation.phoneNumber} ${conversationPreview(conversation)}`
      .toLocaleLowerCase(phone.lang)
      .includes(query)
  })
})
const knownContactNumbers = computed(
  () => new Set(calls.contacts.map((contact) => contact.phone_number)),
)
const contactSuggestions = computed(() => {
  const query = composerNumber.value.trim().toLocaleLowerCase(phone.lang)
  if (!query) return calls.contacts.slice(0, 8)
  return calls.contacts
    .filter((contact) =>
      `${contact.name} ${contact.phone_number}`
        .toLocaleLowerCase(phone.lang)
        .includes(query),
    )
    .slice(0, 8)
})
const activeTitle = computed(() =>
  messages.activeNumber ? contactName(messages.activeNumber) : '',
)
const activeContact = computed(() =>
  calls.contacts.find(
    (contact) => contact.phone_number === messages.activeNumber,
  ),
)
const attachmentPanelOpen = computed(
  () => emojiOpen.value || attachmentPicker.value !== null,
)
function contactName(number: string): string {
  return (
    calls.contacts.find((contact) => contact.phone_number === number)?.name ??
    number
  )
}

function conversationPreview(conversation: SmsConversation): string {
  if (conversation.lastMessageType === 'image') {
    return `📷 ${phone.t('Apps.messages.photo')}`
  }
  if (conversation.lastMessageType === 'gif') {
    return `GIF ${phone.t('Apps.messages.gif')}`
  }
  if (conversation.lastMessageType === 'video') {
    return `▶️ ${phone.t('Apps.messages.video')}`
  }
  return conversation.lastMessageType === 'voice'
    ? `🎙️ ${phone.t('Apps.messages.voiceMessage')}`
    : conversation.lastMessage
}

function avatarStyle(number: string): { background: string } {
  let hash = 0
  for (const character of number) {
    hash = (hash * 31 + character.charCodeAt(0)) % 360
  }
  return {
    background: `linear-gradient(145deg, hsl(${hash} 72% 62%), hsl(${(hash + 35) % 360} 68% 48%))`,
  }
}

function avatarGlyph(number: string): string {
  const glyphs = ['👩🏻', '🧔🏻', '👩🏽', '👨🏼', '👩🏼', '🧑🏾', '👨🏽', '👩🏾']
  let hash = 0
  for (const character of number) hash += character.charCodeAt(0)
  return glyphs[hash % glyphs.length]
}

function formatConversationDate(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return String(value)
  const today = new Date()
  if (date.toDateString() === today.toDateString()) {
    return new Intl.DateTimeFormat(phone.lang, {
      hour: '2-digit',
      hourCycle: 'h23',
      minute: '2-digit',
    }).format(date)
  }
  const yesterday = new Date(today)
  yesterday.setDate(today.getDate() - 1)
  if (date.toDateString() === yesterday.toDateString()) {
    return phone.t('Apps.messages.yesterday')
  }
  const daysAgo = Math.floor((today.getTime() - date.getTime()) / 86_400_000)
  if (daysAgo < 7) {
    return new Intl.DateTimeFormat(phone.lang, { weekday: 'long' }).format(date)
  }
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'numeric',
  }).format(date)
}

function dayLabel(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return String(value)
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(today.getDate() - 1)
  if (date.toDateString() === today.toDateString()) {
    return phone.t('Apps.messages.today')
  }
  if (date.toDateString() === yesterday.toDateString()) {
    return phone.t('Apps.messages.yesterday')
  }
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    year: date.getFullYear() === today.getFullYear() ? undefined : 'numeric',
  }).format(date)
}

function timeLabel(value: DatabaseDateValue): string {
  const date = parseDatabaseDate(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  }).format(date)
}

function formatRecordingTime(milliseconds: number): string {
  const seconds = Math.floor(milliseconds / 1000)
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

function startsDay(message: SmsMessage, index: number): boolean {
  if (index === 0) return true
  return (
    parseDatabaseDate(
      messages.messages[index - 1].created_at,
    ).toDateString() !== parseDatabaseDate(message.created_at).toDateString()
  )
}

function messageFooter(message: SmsMessage, index: number): string | undefined {
  if (message.direction !== 'sent' || index !== messages.messages.length - 1) {
    return undefined
  }
  if (message.delivery_status === 'sending') {
    return phone.t('Apps.messages.sending')
  }
  if (message.delivery_status === 'failed') {
    return phone.t('Apps.messages.notDelivered')
  }
  return phone.t('Apps.messages.delivered')
}

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function showToast(message: string): void {
  if (toastTimer) clearTimeout(toastTimer)
  toastText.value = message
  toastOpened.value = true
  toastTimer = setTimeout(() => (toastOpened.value = false), 2800)
}

function errorText(error?: string): string {
  const known = [
    'invalid_number',
    'invalid_message',
    'invalid_voice',
    'invalid_attachment',
    'media_provider_unconfigured',
    'capture_provider_unavailable',
    'capture_failed',
    'gif_provider_unconfigured',
    'gif_provider_unauthorized',
    'gif_provider_rate_limited',
    'gif_provider_failed',
    'self_message',
    'recipient_not_found',
    'no_sim',
    'rate_limited',
    'request_failed',
  ]
  return phone.t(
    `Apps.messages.errors.${error && known.includes(error) ? error : 'default'}`,
  )
}

async function scrollToBottom(animate = true): Promise<void> {
  await nextTick()
  const page = document.querySelector<HTMLElement>('.messages-thread-page')
  if (!page) return
  page.scrollTo({
    behavior: animate ? 'smooth' : 'auto',
    top: page.scrollHeight,
  })
}

async function openConversation(conversation: SmsConversation): Promise<void> {
  if (editingList.value) {
    const index = selectedNumbers.value.indexOf(conversation.phoneNumber)
    if (index >= 0) selectedNumbers.value.splice(index, 1)
    else selectedNumbers.value.push(conversation.phoneNumber)
    return
  }
  if (!(await messages.openThread(conversation.phoneNumber))) {
    showToast(errorText())
    return
  }
  composing.value = false
  draft.value = ''
  await scrollToBottom(false)
}

function toggleListEditing(): void {
  editingList.value = !editingList.value
  selectedNumbers.value = []
  showUnreadOnly.value = false
}

async function deleteSelectedConversations(): Promise<void> {
  if (!selectedNumbers.value.length) return
  const deleted = await messages.deleteConversations(selectedNumbers.value)
  if (!deleted) {
    showToast(errorText())
    return
  }
  editingList.value = false
  selectedNumbers.value = []
}

function beginCompose(): void {
  messages.closeThread()
  composing.value = true
  composerNumber.value = ''
  draft.value = ''
}

async function chooseRecipient(number: string): Promise<void> {
  composerNumber.value = number
  if (!(await messages.openThread(number))) {
    showToast(errorText('invalid_number'))
    return
  }
  composing.value = false
  await scrollToBottom(false)
}

function goBack(): void {
  if (contactDetailsOpen.value) {
    contactDetailsOpen.value = false
    contactEditing.value = false
    return
  }
  cancelVoiceRecording()
  if (messages.activeNumber) messages.closeThread()
  composing.value = false
  composerNumber.value = ''
  draft.value = ''
  emojiOpen.value = false
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
}

function appendEmoji(emoji: string): void {
  draft.value += emoji
}

function openContactDetails(): void {
  if (!messages.activeNumber) return
  contactNameDraft.value = activeContact.value?.name ?? ''
  contactNumberDraft.value = messages.activeNumber
  contactEditing.value = false
  contactDetailsOpen.value = true
}

async function saveContactDetails(): Promise<void> {
  if (!contactNameDraft.value.trim() || !contactNumberDraft.value.trim()) return
  const response = await calls.saveContact({
    id: activeContact.value?.id,
    name: contactNameDraft.value.trim(),
    phoneNumber: contactNumberDraft.value,
  })
  if (!response.success) {
    showToast(phone.t('Apps.messages.contactSaveFailed'))
    return
  }
  contactEditing.value = false
  contactNumberDraft.value =
    response.data?.phone_number ?? contactNumberDraft.value
}

async function deleteActiveContact(): Promise<void> {
  if (!activeContact.value) return
  if (!(await calls.deleteContact(activeContact.value.id))) {
    showToast(phone.t('Apps.messages.contactDeleteFailed'))
    return
  }
  contactDetailsOpen.value = false
  contactEditing.value = false
}

async function callActiveContact(): Promise<void> {
  if (!messages.activeNumber) return
  const response = await calls.dial(messages.activeNumber)
  if (!response.success) showToast(phone.t('Apps.messages.callFailed'))
}

function toggleAttachmentMenu(): void {
  attachmentMenuOpen.value = !attachmentMenuOpen.value
  emojiOpen.value = false
  attachmentPicker.value = null
}

function openGifPicker(): void {
  attachmentMenuOpen.value = false
  attachmentPicker.value = 'gifs'
  emojiOpen.value = false
  if (!gifResults.value.length) void loadGifs(true)
}

function openEmojiPicker(): void {
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  emojiOpen.value = true
}

function openMediaApp(
  app: 'camera' | 'photos',
  mediaType: 'photo' | 'video',
): void {
  if (!messages.activeNumber) return
  attachmentMenuOpen.value = false
  messageMedia.begin(messages.activeNumber, mediaType)
  void router.push({
    path: `/apps/${app}`,
    query: { messageAttachment: mediaType },
  })
}

async function sendAttachment(
  messageType: SmsAttachmentType,
  mediaAssetId: string,
  mediaDurationMs?: number,
): Promise<void> {
  if (!messages.activeNumber || sending.value) return
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  sending.value = true
  const response = await messages.send({
    mediaAssetId,
    mediaDurationMs,
    messageType,
  })
  sending.value = false
  if (!response.success) showToast(errorText(response.error))
  await scrollToBottom()
}

async function loadGifs(reset = false): Promise<void> {
  if (gifLoading.value || (!reset && !gifHasMore.value)) return
  gifError.value = null
  gifLoading.value = true
  const response = await messages.searchGifs(
    gifQuery.value,
    reset ? 0 : gifNextOffset.value,
  )
  gifLoading.value = false
  if (!response.success || !response.data) {
    if (reset) gifResults.value = []
    gifError.value = response.error ?? 'gif_provider_failed'
    showToast(errorText(response.error))
    return
  }
  const existingIds = new Set(
    reset ? [] : gifResults.value.map((result) => result.id),
  )
  const uniqueResults = response.data.results.filter((result) => {
    if (existingIds.has(result.id)) return false
    existingIds.add(result.id)
    return true
  })
  gifResults.value = reset
    ? uniqueResults
    : [...gifResults.value, ...uniqueResults]
  gifHasMore.value = response.data.hasMore
  gifNextOffset.value = response.data.nextOffset
}

function queueGifSearch(): void {
  if (gifSearchTimer) clearTimeout(gifSearchTimer)
  gifSearchTimer = setTimeout(() => void loadGifs(true), 320)
}

async function sendTextMessage(): Promise<void> {
  if (!messages.activeNumber || !draft.value.trim() || sending.value) return
  const body = draft.value
  draft.value = ''
  emojiOpen.value = false
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  sending.value = true
  await scrollToBottom()
  const response = await messages.send({ body, messageType: 'text' })
  sending.value = false
  if (!response.success) showToast(errorText(response.error))
  await scrollToBottom()
}

function recordingMime(): string | null {
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
    return 'audio/webm;codecs=opus'
  }
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
  if (recordingElapsedMs.value >= VOICE_MAX_DURATION_MS) {
    stopVoiceRecording()
  }
}

async function startVoiceRecording(): Promise<void> {
  emojiOpen.value = false
  if (
    !navigator.mediaDevices?.getUserMedia ||
    typeof MediaRecorder === 'undefined'
  ) {
    showToast(phone.t('Apps.messages.microphoneUnavailable'))
    return
  }
  const mime = recordingMime()
  if (!mime) {
    showToast(phone.t('Apps.messages.microphoneUnavailable'))
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
      audioBitsPerSecond: 24_000,
      mimeType: mime,
    })
    mediaRecorder.addEventListener('dataavailable', (event) => {
      if (!event.data.size) return
      recordingChunks.push(event.data)
      recordingBytes += event.data.size
      if (recordingBytes > VOICE_MAX_BYTES) stopVoiceRecording()
    })
    mediaRecorder.addEventListener('stop', () => void finishVoiceRecording())
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
    console.error('[Messages] Could not start audio recording:', error)
    cleanupRecorder()
    showToast(phone.t('Apps.messages.microphoneUnavailable'))
  }
}

function stopVoiceRecording(): void {
  if (!mediaRecorder || mediaRecorder.state === 'inactive') return
  mediaRecorder.stop()
}

function cancelVoiceRecording(): void {
  discardRecording = true
  if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop()
  else cleanupRecorder()
}

function cleanupRecorder(): void {
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

function compressedWaveform(): number[] {
  if (!recordingSamples.length) return Array(16).fill(0.12)
  const result: number[] = []
  const bucketSize = recordingSamples.length / WAVEFORM_SAMPLES
  const count = Math.min(WAVEFORM_SAMPLES, recordingSamples.length)
  for (let index = 0; index < count; index += 1) {
    const start = Math.floor(index * bucketSize)
    const end = Math.max(start + 1, Math.floor((index + 1) * bucketSize))
    const bucket = recordingSamples.slice(start, end)
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
  const buffer = await blob.arrayBuffer()
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  }
  return btoa(binary)
}

async function finishVoiceRecording(): Promise<void> {
  const duration = Math.min(
    VOICE_MAX_DURATION_MS,
    Math.max(300, performance.now() - recordingStartedAt),
  )
  const mime = mediaRecorder?.mimeType ?? 'audio/webm'
  const chunks = recordingChunks
  const waveform = compressedWaveform()
  const shouldDiscard = discardRecording
  cleanupRecorder()
  if (shouldDiscard) return
  const blob = new Blob(chunks, { type: mime })
  if (!blob.size || blob.size > VOICE_MAX_BYTES) {
    showToast(phone.t('Apps.messages.recordingTooLarge'))
    return
  }
  const payload = await blobBase64(blob)
  sending.value = true
  const response = await messages.send({
    mediaDurationMs: Math.floor(duration),
    mediaMime: mime,
    mediaPayload: payload,
    mediaWaveform: waveform,
    messageType: 'voice',
  })
  sending.value = false
  if (!response.success) showToast(errorText(response.error))
  await scrollToBottom()
}

onMounted(() => {
  void messages.loadConversations()
  void calls.loadContacts()
  if (messages.activeNumber) {
    const media = messageMedia.consume(messages.activeNumber)
    if (media) {
      void sendAttachment(
        media.mediaType === 'photo' ? 'image' : 'video',
        import.meta.env.DEV ? media.url : String(media.id),
      )
    }
  }
})

onBeforeUnmount(() => {
  discardRecording = true
  cleanupRecorder()
  if (toastTimer) clearTimeout(toastTimer)
  if (gifSearchTimer) clearTimeout(gifSearchTimer)
})
</script>

<template>
  <k-page
    v-if="!hasSim"
    class="messages-page !pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.messages.name')"
  >
    <k-navbar large transparent :title="phone.t('Apps.messages.name')" />
    <div class="messages-empty-state">
      <span class="messages-empty-state__icon"
        ><MessageCircle :size="35"
      /></span>
      <h2>{{ phone.t('Apps.messages.noSim') }}</h2>
      <p>{{ phone.t('Apps.messages.noSimBody') }}</p>
    </div>
  </k-page>

  <k-page
    v-else-if="!messages.activeNumber && !composing"
    class="messages-page messages-inbox-page"
    :aria-label="phone.t('Apps.messages.name')"
  >
    <header class="messages-inbox-header">
      <k-glass
        component="button"
        type="button"
        class="messages-inbox-header__edit"
        @click="toggleListEditing"
      >
        <span>{{ phone.t(editingList ? 'Common.done' : 'Common.edit') }}</span>
      </k-glass>
      <strong>
        {{
          editingList
            ? phone.t('Apps.messages.selectedCount', {
                count: String(selectedNumbers.length),
              })
            : phone.t('Apps.messages.name')
        }}
      </strong>
      <k-glass
        v-if="!editingList"
        component="button"
        type="button"
        :class="{ active: showUnreadOnly }"
        :aria-label="phone.t('Apps.messages.filterUnread')"
        @click="showUnreadOnly = !showUnreadOnly"
      >
        <ListFilter :size="24" :stroke-width="2.25" />
      </k-glass>
      <k-glass
        v-else
        component="button"
        type="button"
        class="messages-inbox-header__delete"
        :disabled="!selectedNumbers.length"
        :aria-label="phone.t('Apps.messages.deleteSelected')"
        @click="deleteSelectedConversations"
      >
        <Trash2 :size="18" />
      </k-glass>
    </header>

    <div v-if="filteredConversations.length" class="messages-conversation-list">
      <button
        v-for="conversation in filteredConversations"
        :key="conversation.phoneNumber"
        type="button"
        class="messages-conversation"
        :class="{
          'messages-conversation--unread': conversation.unread > 0,
          'messages-conversation--selected': selectedNumbers.includes(
            conversation.phoneNumber,
          ),
        }"
        @click="openConversation(conversation)"
      >
        <span v-if="editingList" class="messages-conversation__selection">
          <Check
            v-if="selectedNumbers.includes(conversation.phoneNumber)"
            :size="14"
          />
        </span>
        <span
          v-else-if="conversation.unread"
          class="messages-conversation__dot"
        />
        <span
          class="messages-avatar"
          :class="{
            'messages-avatar--unknown': !knownContactNumbers.has(
              conversation.phoneNumber,
            ),
          }"
          :style="avatarStyle(conversation.phoneNumber)"
          aria-hidden="true"
        >
          <span
            v-if="knownContactNumbers.has(conversation.phoneNumber)"
            class="messages-avatar__glyph"
          >
            {{ avatarGlyph(conversation.phoneNumber) }}
          </span>
          <span v-else class="messages-avatar__placeholder">
            <i />
            <b />
          </span>
        </span>
        <span class="messages-conversation__body">
          <span class="messages-conversation__headline">
            <strong>{{ contactName(conversation.phoneNumber) }}</strong>
            <time>{{
              formatConversationDate(conversation.lastMessageAt)
            }}</time>
            <ChevronRight :size="13" />
          </span>
          <span class="messages-conversation__preview">
            {{ conversationPreview(conversation) }}
          </span>
        </span>
      </button>
    </div>

    <div v-else class="messages-empty-state messages-empty-state--list">
      <span class="messages-empty-state__icon"
        ><MessageCircle :size="35"
      /></span>
      <h2>
        {{
          phone.t(
            search ? 'Apps.messages.noResults' : 'Apps.messages.noMessages',
          )
        }}
      </h2>
      <p v-if="!search">{{ phone.t('Apps.messages.noMessagesBody') }}</p>
      <button v-if="!search" type="button" @click="beginCompose">
        {{ phone.t('Apps.messages.compose') }}
      </button>
    </div>

    <footer v-if="!editingList" class="messages-inbox-toolbar">
      <div class="messages-inbox-search">
        <k-searchbar
          :value="search"
          :placeholder="phone.t('Apps.messages.search')"
          :colors="{
            inputBgIos: 'bg-transparent',
            placeholderIos: 'placeholder-[#8e8e93]',
          }"
          :clear-button="false"
          :input-style="{
            color: phone.isDarkMode ? '#f5f5f7' : '#111',
            paddingRight: '48px',
          }"
          @input="search = eventValue($event)"
          @clear="search = ''"
        />
        <k-link
          component="button"
          icon-only
          class="messages-inbox-search__voice"
          :aria-label="phone.t('Apps.messages.search')"
        >
          <Mic :size="20" />
        </k-link>
      </div>
      <k-glass
        component="button"
        type="button"
        :aria-label="phone.t('Apps.messages.compose')"
        @click="beginCompose"
      >
        <SquarePen :size="20" />
      </k-glass>
    </footer>
    <footer v-else class="messages-edit-toolbar">
      <span>{{
        phone.t('Apps.messages.selectedCount', {
          count: String(selectedNumbers.length),
        })
      }}</span>
      <button
        type="button"
        :disabled="!selectedNumbers.length"
        @click="deleteSelectedConversations"
      >
        <Trash2 :size="18" />
        {{ phone.t('Apps.messages.deleteSelected') }}
      </button>
    </footer>
  </k-page>

  <k-page
    v-else-if="composing"
    class="messages-page messages-compose-page !pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.messages.compose')"
  >
    <k-navbar :title="phone.t('Apps.messages.compose')">
      <template #left>
        <k-navbar-back-link
          component="button"
          :text="phone.t('Common.cancel')"
          @click="goBack"
        />
      </template>
    </k-navbar>
    <k-list class="messages-recipient-field" strong>
      <k-list-input
        :value="composerNumber"
        :label="phone.t('Apps.messages.to')"
        inputmode="tel"
        autofocus
        clear-button
        @input="composerNumber = eventValue($event)"
        @clear="composerNumber = ''"
        @keyup.enter="chooseRecipient(composerNumber)"
      />
    </k-list>
    <k-list
      v-if="contactSuggestions.length"
      class="messages-contact-list"
      strong
    >
      <k-list-item
        v-for="contact in contactSuggestions"
        :key="contact.id"
        link
        :title="contact.name"
        :subtitle="contact.phone_number"
        @click="chooseRecipient(contact.phone_number)"
      >
        <template #media>
          <span
            class="messages-avatar messages-avatar--small"
            :style="avatarStyle(contact.phone_number)"
          >
            <span class="messages-avatar__glyph">{{
              avatarGlyph(contact.phone_number)
            }}</span>
          </span>
        </template>
      </k-list-item>
    </k-list>
    <k-block v-else-if="messages.loading"><k-preloader /></k-block>
    <button
      v-else-if="composerNumber.trim()"
      class="messages-number-action"
      type="button"
      @click="chooseRecipient(composerNumber)"
    >
      <MessageCircle :size="17" />
      {{ composerNumber }}
    </button>
  </k-page>

  <k-page
    v-else
    class="messages-page messages-thread-page"
    :class="{ 'messages-thread-page--emoji': attachmentPanelOpen }"
    :aria-label="activeTitle"
  >
    <header class="messages-chat-header">
      <k-link
        component="button"
        icon-only
        type="button"
        class="messages-chat-header__back"
        :aria-label="phone.t('Apps.messages.name')"
        @click="goBack"
      >
        <ChevronLeft :size="28" :stroke-width="2.35" />
      </k-link>
      <div class="messages-chat-header__contact">
        <span
          class="messages-avatar messages-avatar--header"
          :class="{ 'messages-avatar--unknown': !activeContact }"
          :style="avatarStyle(messages.activeNumber ?? '')"
        >
          <span v-if="activeContact" class="messages-avatar__glyph">{{
            avatarGlyph(messages.activeNumber ?? '')
          }}</span>
          <span v-else class="messages-avatar__placeholder" aria-hidden="true">
            <i />
            <b />
          </span>
        </span>
        <k-link
          component="button"
          type="button"
          class="messages-chat-header__name"
          :aria-label="phone.t('Apps.messages.contactDetails')"
          @click="openContactDetails"
        >
          <strong>{{ activeTitle }}</strong>
          <ChevronRight :size="13" />
        </k-link>
      </div>
    </header>

    <section v-if="contactDetailsOpen" class="messages-contact-details">
      <header>
        <button
          type="button"
          :aria-label="phone.t('Common.back')"
          @click="contactDetailsOpen = false"
        >
          <ChevronLeft :size="24" :stroke-width="2.35" />
        </button>
        <strong>{{ phone.t('Apps.messages.contactDetails') }}</strong>
        <button
          type="button"
          @click="
            contactEditing ? saveContactDetails() : (contactEditing = true)
          "
        >
          <Check v-if="contactEditing" :size="19" />
          <Pencil v-else :size="18" />
        </button>
      </header>
      <div class="messages-contact-details__hero">
        <span
          class="messages-avatar messages-avatar--contact"
          :class="{ 'messages-avatar--unknown': !activeContact }"
          :style="avatarStyle(messages.activeNumber ?? '')"
        >
          <span v-if="activeContact" class="messages-avatar__glyph">{{
            avatarGlyph(messages.activeNumber ?? '')
          }}</span>
          <span v-else class="messages-avatar__placeholder" aria-hidden="true">
            <i />
            <b />
          </span>
        </span>
        <h2>{{ activeTitle }}</h2>
        <small>{{ messages.activeNumber }}</small>
      </div>
      <div class="messages-contact-details__actions">
        <button type="button" @click="callActiveContact">
          <PhoneIcon :size="20" />
          <span>{{ phone.t('Apps.messages.call') }}</span>
        </button>
        <button type="button" @click="contactDetailsOpen = false">
          <MessageCircle :size="20" />
          <span>{{ phone.t('Apps.messages.messageAction') }}</span>
        </button>
      </div>
      <div class="messages-contact-details__fields">
        <label>
          <span>{{ phone.t('Apps.messages.contactName') }}</span>
          <input
            v-model="contactNameDraft"
            :readonly="!contactEditing"
            :placeholder="phone.t('Apps.messages.contactName')"
          />
        </label>
        <label>
          <span>{{ phone.t('Apps.messages.phoneNumber') }}</span>
          <input
            v-model="contactNumberDraft"
            :readonly="!contactEditing"
            inputmode="tel"
          />
        </label>
      </div>
      <button
        v-if="!activeContact"
        type="button"
        class="messages-contact-details__primary"
        @click="contactEditing = true"
      >
        <UserPlus :size="18" />
        {{ phone.t('Apps.messages.addContact') }}
      </button>
      <button
        v-else
        type="button"
        class="messages-contact-details__delete"
        @click="deleteActiveContact"
      >
        <Trash2 :size="18" />
        {{ phone.t('Apps.messages.deleteContact') }}
      </button>
    </section>

    <k-messages class="messages-bubbles">
      <template
        v-for="(message, index) in messages.messages"
        :key="message.client_id ?? message.id"
      >
        <k-messages-title v-if="startsDay(message, index)">
          <span class="messages-thread-timestamp">
            <span>{{ phone.t('Apps.messages.smsLabel') }}</span>
            <b
              >{{ dayLabel(message.created_at) }},
              {{ timeLabel(message.created_at) }}</b
            >
          </span>
        </k-messages-title>
        <k-message
          :class="{
            'messages-message--sending': message.delivery_status === 'sending',
            'messages-message--failed': message.delivery_status === 'failed',
          }"
          :type="message.direction"
          :text="message.message_type === 'text' ? message.body : undefined"
          :text-footer="messageFooter(message, index)"
        >
          <template v-if="message.message_type !== 'text'" #text>
            <VoiceMessageBubble
              v-if="message.message_type === 'voice'"
              :message="message"
            />
            <MessageAttachmentBubble v-else :message="message" />
          </template>
        </k-message>
      </template>
    </k-messages>

    <section v-if="attachmentMenuOpen" class="messages-attachment-menu">
      <button type="button" @click="openMediaApp('photos', 'photo')">
        <span><Images :size="20" /></span>
        {{ phone.t('Apps.messages.attachPhoto') }}
      </button>
      <button type="button" @click="openMediaApp('camera', 'photo')">
        <span><Camera :size="20" /></span>
        {{ phone.t('Apps.messages.takePhoto') }}
      </button>
      <button type="button" @click="openEmojiPicker">
        <span class="messages-action-emoji">😀</span>
        {{ phone.t('Apps.messages.emoji') }}
      </button>
      <button type="button" @click="openGifPicker">
        <span><ImagePlay :size="20" /></span>
        {{ phone.t('Apps.messages.attachGif') }}
      </button>
      <button type="button" @click="openMediaApp('photos', 'video')">
        <span><Video :size="20" /></span>
        {{ phone.t('Apps.messages.attachVideo') }}
      </button>
    </section>

    <section v-if="attachmentPicker" class="messages-media-picker">
      <header>
        <strong>
          {{ phone.t('Apps.messages.gifs') }}
        </strong>
        <button type="button" @click="attachmentPicker = null">
          {{ phone.t('Common.done') }}
        </button>
      </header>
      <div class="messages-media-picker__gifs">
        <label class="messages-gif-search">
          <Search :size="15" />
          <input
            v-model="gifQuery"
            type="search"
            :placeholder="phone.t('Apps.messages.searchGifs')"
            @input="queueGifSearch"
          />
        </label>
        <button
          v-for="gif in gifResults"
          :key="gif.id"
          type="button"
          :aria-label="gif.title"
          @click="sendAttachment('gif', gif.url)"
        >
          <img :src="gif.previewUrl" :alt="gif.title" loading="lazy" />
        </button>
        <button
          v-if="gifResults.length && gifHasMore && !gifLoading"
          type="button"
          class="messages-gif-more"
          @click="loadGifs()"
        >
          {{ phone.t('Apps.messages.loadMore') }}
        </button>
        <div v-if="gifError && !gifLoading" class="messages-gif-error">
          <ImagePlay :size="24" />
          <strong>{{ errorText(gifError) }}</strong>
          <button type="button" @click="loadGifs(true)">
            {{ phone.t('Apps.messages.retryGifs') }}
          </button>
        </div>
        <k-preloader v-if="gifLoading" class="messages-gif-loading" />
      </div>
    </section>

    <FullEmojiPicker
      v-if="emojiOpen"
      @close="emojiOpen = false"
      @pick="appendEmoji"
    />

    <section v-if="recording" class="messages-recorder">
      <button
        type="button"
        class="messages-recorder__cancel"
        :aria-label="phone.t('Apps.messages.cancelRecording')"
        @click="cancelVoiceRecording"
      >
        <X :size="20" />
      </button>
      <span class="messages-recorder__dot" />
      <time>{{ formatRecordingTime(recordingElapsedMs) }}</time>
      <div class="messages-recorder__wave" aria-hidden="true">
        <i
          v-for="(level, index) in recordingLevels"
          :key="index"
          :style="{ height: `${Math.max(3, level * 24)}px` }"
        />
      </div>
      <button
        type="button"
        class="messages-recorder__send"
        :aria-label="phone.t('Apps.messages.stopAndSend')"
        @click="stopVoiceRecording"
      >
        <ArrowUpCircle :size="29" fill="currentColor" />
      </button>
    </section>

    <k-messagebar
      v-else
      class="messages-messagebar"
      :placeholder="phone.t('Apps.messages.message')"
      :value="draft"
      :disabled="sending"
      @input="draft = eventValue($event)"
      @keydown.enter.exact.prevent="sendTextMessage"
    >
      <template #left>
        <k-toolbar-pane class="ios:h-10 messages-messagebar__tools">
          <k-link
            component="button"
            icon-only
            :aria-label="phone.t('Apps.messages.moreActions')"
            :class="{ active: attachmentMenuOpen || attachmentPanelOpen }"
            @click="toggleAttachmentMenu"
          >
            <Plus :size="25" />
          </k-link>
        </k-toolbar-pane>
      </template>
      <template #right>
        <k-toolbar-pane class="ios:h-10">
          <k-link
            v-if="draft.trim()"
            component="button"
            icon-only
            :disabled="sending"
            :aria-label="phone.t('Apps.messages.send')"
            @click="sendTextMessage"
          >
            <ArrowUpCircle :size="29" :stroke-width="2.4" />
          </k-link>
          <k-link
            v-else
            component="button"
            icon-only
            :disabled="sending"
            :aria-label="phone.t('Apps.messages.recordVoice')"
            @click="startVoiceRecording"
          >
            <Mic :size="21" :stroke-width="2.3" />
          </k-link>
        </k-toolbar-pane>
      </template>
    </k-messagebar>
  </k-page>

  <k-toast :opened="toastOpened" position="center" @click="toastOpened = false">
    {{ toastText }}
  </k-toast>
</template>
