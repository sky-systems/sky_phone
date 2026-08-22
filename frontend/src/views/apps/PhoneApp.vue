<script setup lang="ts">
import {
  SkyBlock,
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyGlass,
  SkyList,
  SkyField,
  SkyAppPage,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkyTabBar,
  SkyTabButton,
} from '@/ui'
import {
  Camera,
  Check,
  ChevronRight,
  ChevronLeft,
  Clock3,
  ContactRound,
  Delete,
  Info,
  Images,
  Grid3X3,
  Mail,
  MessageCircle,
  MicOff,
  MoreHorizontal,
  Phone,
  PhoneIncoming,
  PhoneOff,
  PhoneOutgoing,
  Plus,
  Search,
  Smartphone,
  Star,
  UserRound,
  Video,
  Volume2,
  X,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useCallsStore } from '@/stores/calls'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type { EasySharePayload } from '@/types/easyshare'
import type { PhoneContact, RecentCall } from '@/types/phone'
import { nuiCall } from '@/utils/nui'
import { formatPhoneNumber, normalizePhoneNumber } from '@/utils/phone'

type PhoneTab = 'recents' | 'contacts' | 'keypad'
type RecentFilter = 'all' | 'missed'
type ContactProfileAction = 'message' | 'call' | 'video' | 'mail'
type ContactPhotoContext = {
  avatarMediaId: number | null
  avatarUrl: string
  contactId?: string
  email: string
  firstName: string
  lastName: string
  notes: string
  organization: string
  phoneNumber: string
}

const phone = usePhoneStore()
const calls = useCallsStore()
const easyShare = useEasyShareStore()
const mediaPicker = useMessageMediaStore()
const messages = useMessagesStore()
const route = useRoute()
const router = useRouter()
const tab = ref<PhoneTab>('recents')
const query = ref('')
const recentQuery = ref('')
const recentFilter = ref<RecentFilter>('all')
const selectedNumber = ref('')
const viewingOwnCard = ref(false)
const phoneContent = ref<HTMLElement | null>(null)
const keypad = ref('')
const editorOpened = ref(false)
const editingContact = ref<PhoneContact | null>(null)
const contactFirstName = ref('')
const contactLastName = ref('')
const contactOrganization = ref('')
const contactEmail = ref('')
const contactNotes = ref('')
const contactNumber = ref('')
const contactAvatarMediaId = ref<number | null>(null)
const contactAvatarUrl = ref('')
const error = ref('')
const callMoreOpened = ref(false)
const callKeypadOpened = ref(false)
const inCallKeypad = ref('')
const blockDialogOpened = ref(false)
const blockTargetNumber = ref('')
const callSpeakerPending = ref(false)
const callMutePending = ref(false)
const callElapsedSeconds = ref(0)
let callClock: number | null = null
const tabs = [
  { id: 'recents', icon: Clock3 },
  { id: 'contacts', icon: ContactRound },
  { id: 'keypad', icon: Phone },
] as const
const keypadKeys = [
  { digit: '1', letters: '' },
  { digit: '2', letters: 'ABC' },
  { digit: '3', letters: 'DEF' },
  { digit: '4', letters: 'GHI' },
  { digit: '5', letters: 'JKL' },
  { digit: '6', letters: 'MNO' },
  { digit: '7', letters: 'PQRS' },
  { digit: '8', letters: 'TUV' },
  { digit: '9', letters: 'WXYZ' },
  { digit: '*', letters: '' },
  { digit: '0', letters: '+' },
  { digit: '#', letters: '' },
] as const
const contactProfileActions = [
  { id: 'message', icon: MessageCircle },
  { id: 'call', icon: Phone },
  { id: 'video', icon: Video },
  { id: 'mail', icon: Mail },
] as const
const contactAlphabet = [...'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '#']
const visibleContacts = computed(() => {
  const needle = query.value.trim().toLowerCase()
  if (!needle) return calls.contacts
  return calls.contacts.filter(
    (contact) =>
      contact.name.toLowerCase().includes(needle) ||
      contact.phone_number.includes(needle.replace(/\D/g, '')),
  )
})
const contactsByNumber = computed(
  () =>
    new Map(calls.contacts.map((contact) => [contact.phone_number, contact])),
)
const groupedContacts = computed(() => {
  const groups = new Map<string, PhoneContact[]>()
  const sorted = [...visibleContacts.value].sort((left, right) =>
    left.name.localeCompare(right.name, phone.lang, { sensitivity: 'base' }),
  )
  for (const contact of sorted) {
    const firstCharacter = contact.name.trim().charAt(0).toUpperCase()
    const letter = /^[A-Z]$/.test(firstCharacter) ? firstCharacter : '#'
    const group = groups.get(letter) ?? []
    group.push(contact)
    groups.set(letter, group)
  }
  return contactAlphabet
    .filter((letter) => groups.has(letter))
    .map((letter) => ({ contacts: groups.get(letter) ?? [], letter }))
})
const favoriteContacts = computed(() =>
  calls.contacts
    .filter((contact) => Boolean(contact.favorite))
    .sort((left, right) =>
      left.name.localeCompare(right.name, phone.lang, { sensitivity: 'base' }),
    ),
)
const visibleRecents = computed(() => {
  const needle = recentQuery.value.trim().toLowerCase()
  return calls.recents.filter((recent) => {
    const contact = calls.contacts.find(
      (entry) => entry.phone_number === recent.other_number,
    )
    const matchesFilter =
      recentFilter.value === 'all' ||
      ['missed', 'no_answer'].includes(recent.status)
    const matchesQuery =
      !needle ||
      recent.other_number.includes(needle.replace(/\D/g, '')) ||
      contact?.name.toLowerCase().includes(needle)
    return matchesFilter && matchesQuery
  })
})
const selectedContact = computed(
  () =>
    calls.contacts.find(
      (contact) => contact.phone_number === selectedNumber.value,
    ) ?? null,
)
const selectedHistory = computed(() =>
  calls.recents.filter(
    (recent) => recent.other_number === selectedNumber.value,
  ),
)
const selectedDisplayName = computed(() => {
  if (viewingOwnCard.value) return phone.t('Apps.phone.myCard')
  return selectedContact.value?.name ?? formatPhoneNumber(selectedNumber.value)
})
const keypadDisplay = computed(() => {
  if (!keypad.value) return ''
  return /[*#]/.test(keypad.value)
    ? keypad.value
    : formatPhoneNumber(keypad.value)
})
const keypadSuggestions = computed(() => {
  const enteredDigits = keypad.value.replace(/\D/g, '')
  if (enteredDigits.length < 2 || /[*#]/.test(keypad.value)) return []
  return calls.contacts
    .filter((contact) =>
      contact.phone_number.replace(/\D/g, '').startsWith(enteredDigits),
    )
    .sort((left, right) => {
      const leftExact = left.phone_number.replace(/\D/g, '') === enteredDigits
      const rightExact = right.phone_number.replace(/\D/g, '') === enteredDigits
      if (leftExact !== rightExact) return leftExact ? -1 : 1
      return left.name.localeCompare(right.name, phone.lang, {
        sensitivity: 'base',
      })
    })
})
const activeCallLabel = computed(() => {
  const call = calls.activeCall
  if (!call) return ''
  if (call.state === 'ringing') {
    return phone.t(
      call.direction === 'incoming'
        ? 'Apps.phone.incoming'
        : 'Apps.phone.calling',
    )
  }
  const key = call.state === 'no_answer' ? 'noAnswer' : call.state
  return phone.t(`Apps.phone.${key}`)
})
const activeCallStatus = computed(() => {
  if (calls.activeCall?.state !== 'connected') return activeCallLabel.value
  const minutes = Math.floor(callElapsedSeconds.value / 60)
  const seconds = String(callElapsedSeconds.value % 60).padStart(2, '0')
  return `${String(minutes).padStart(2, '0')}:${seconds}`
})
const activeCallContact = computed(
  () =>
    calls.contacts.find(
      (contact) => contact.phone_number === calls.activeCall?.otherNumber,
    ) ?? null,
)
const contactEditorInitials = computed(() =>
  contactFirstName.value.trim().charAt(0).toUpperCase(),
)

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function contactNameFor(number: string): string {
  return contactsByNumber.value.get(number)?.name ?? formatPhoneNumber(number)
}

function openContact(contact?: PhoneContact, number = ''): void {
  editingContact.value = contact ?? null
  const nameParts = contact?.name.trim().split(/\s+/) ?? []
  contactFirstName.value = nameParts.shift() ?? ''
  contactLastName.value = nameParts.join(' ')
  contactOrganization.value = contact?.organization ?? ''
  contactEmail.value = contact?.email ?? ''
  contactNotes.value = contact?.notes ?? ''
  contactNumber.value = contact?.phone_number ?? number
  contactAvatarMediaId.value = contact?.avatar_media_id ?? null
  contactAvatarUrl.value = contact?.avatar_url ?? ''
  error.value = ''
  editorOpened.value = true
}

function openContactPhotoPicker(source: 'camera' | 'photos'): void {
  mediaPicker.begin('phone:contact-photo', 'photo', '/apps/phone', 1, {
    avatarMediaId: contactAvatarMediaId.value,
    avatarUrl: contactAvatarUrl.value,
    contactId: editingContact.value?.id,
    email: contactEmail.value,
    firstName: contactFirstName.value,
    lastName: contactLastName.value,
    notes: contactNotes.value,
    organization: contactOrganization.value,
    phoneNumber: contactNumber.value,
  } satisfies ContactPhotoContext)
  editorOpened.value = false
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeContactPhoto(): void {
  contactAvatarMediaId.value = null
  contactAvatarUrl.value = ''
}

function openRecentDetail(number: string): void {
  viewingOwnCard.value = false
  selectedNumber.value = number
  error.value = ''
  void nextTick(() => phoneContent.value?.scrollTo({ top: 0 }))
}

function openMyCard(): void {
  if (!phone.device?.sim) return
  viewingOwnCard.value = true
  selectedNumber.value = phone.device.sim.number
  error.value = ''
  void nextTick(() => phoneContent.value?.scrollTo({ top: 0 }))
}

function closeRecentDetail(): void {
  viewingOwnCard.value = false
  selectedNumber.value = ''
}

function selectTab(nextTab: PhoneTab): void {
  viewingOwnCard.value = false
  selectedNumber.value = ''
  tab.value = nextTab
}

function scrollToContactGroup(letter: string): void {
  const scroller = phoneContent.value
  if (letter === 'favorites') {
    const target = document.getElementById('phone-contact-group-favorites')
    if (!scroller || !target) return
    const scrollTop =
      scroller.scrollTop +
      target.getBoundingClientRect().top -
      scroller.getBoundingClientRect().top -
      8
    scroller.scrollTo({ behavior: 'smooth', top: scrollTop })
    return
  }
  const availableLetters = new Set(
    groupedContacts.value.map((group) => group.letter),
  )
  let targetLetter = letter
  if (!availableLetters.has(targetLetter)) {
    const requestedIndex = contactAlphabet.indexOf(letter)
    for (let distance = 1; distance < contactAlphabet.length; distance += 1) {
      const nextLetter = contactAlphabet[requestedIndex + distance]
      if (nextLetter && availableLetters.has(nextLetter)) {
        targetLetter = nextLetter
        break
      }
      const previousLetter = contactAlphabet[requestedIndex - distance]
      if (previousLetter && availableLetters.has(previousLetter)) {
        targetLetter = previousLetter
        break
      }
    }
  }
  const suffix = targetLetter === '#' ? 'other' : targetLetter.toLowerCase()
  const target = document.getElementById(`phone-contact-group-${suffix}`)
  if (!scroller || !target) return
  const scrollTop =
    scroller.scrollTop +
    target.getBoundingClientRect().top -
    scroller.getBoundingClientRect().top -
    8
  scroller.scrollTo({ behavior: 'smooth', top: scrollTop })
}

async function toggleSelectedFavorite(): Promise<void> {
  const contact = selectedContact.value
  if (!contact) return
  const response = await calls.setContactFavorite(
    contact.id,
    !Boolean(contact.favorite),
  )
  if (!response.success) {
    error.value = phone.t('Apps.phone.errors.contact_favorite_failed')
  }
}

async function saveContact(): Promise<void> {
  if (editingContact.value?.readonly) {
    error.value = phone.t('Apps.phone.errors.readonly_contact')
    return
  }
  const number = normalizePhoneNumber(contactNumber.value)
  const name = [contactFirstName.value, contactLastName.value]
    .map((part) => part.trim())
    .filter(Boolean)
    .join(' ')
  if (!name || !number) {
    error.value = phone.t('Apps.phone.errors.invalid_contact')
    return
  }
  const response = await calls.saveContact({
    avatarMediaId: contactAvatarMediaId.value,
    email: contactEmail.value.trim(),
    id: editingContact.value?.id,
    name,
    notes: contactNotes.value.trim(),
    organization: contactOrganization.value.trim(),
    phoneNumber: number,
  })
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
    return
  }
  editorOpened.value = false
  viewingOwnCard.value = false
  selectedNumber.value = number
  void nextTick(() => phoneContent.value?.scrollTo({ top: 0 }))
}

async function openMessage(number: string): Promise<void> {
  error.value = ''
  if (await messages.openThread(number)) {
    void router.push('/apps/messages')
    return
  }
  error.value = phone.t('Apps.phone.errors.message_unavailable')
}

function triggerContactAction(action: ContactProfileAction): void {
  if (action === 'call') {
    if (selectedContact.value?.canCall === false) return
    void startCall(selectedNumber.value)
    return
  }
  if (action === 'message' && selectedContact.value?.canMessage !== false) {
    void openMessage(selectedNumber.value)
  }
}

async function startCall(number: string): Promise<void> {
  error.value = ''
  const response = await calls.dial(number)
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
  }
}

async function answerCall(): Promise<void> {
  error.value = ''
  const response = await calls.answer()
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
  }
}

async function toggleCallSpeaker(): Promise<void> {
  const call = calls.activeCall
  if (
    !call ||
    call.state !== 'connected' ||
    !call.speakerSupported ||
    callSpeakerPending.value
  ) {
    return
  }

  error.value = ''
  callSpeakerPending.value = true
  const response = await calls.setSpeaker(!call.speakerEnabled)
  callSpeakerPending.value = false
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
  }
}

async function toggleCallMute(): Promise<void> {
  const call = calls.activeCall
  if (
    !call ||
    call.state !== 'connected' ||
    !call.muteSupported ||
    callMutePending.value
  ) {
    return
  }

  error.value = ''
  callMutePending.value = true
  const response = await calls.setMuted(!call.muted)
  callMutePending.value = false
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
  }
}

function updateCallElapsed(): void {
  const call = calls.activeCall
  if (!call || call.state !== 'connected') {
    callElapsedSeconds.value = 0
    return
  }
  const timestamp = call.answeredAt ?? call.startedAt
  const startedAt = timestamp < 1_000_000_000_000 ? timestamp * 1000 : timestamp
  callElapsedSeconds.value = Math.max(
    0,
    Math.floor((Date.now() - startedAt) / 1000),
  )
}

function openCallContact(): void {
  const call = calls.activeCall
  if (!call) return
  callMoreOpened.value = false
  openContact(activeCallContact.value ?? undefined, call.otherNumber)
}

function shareSelectedContact(): void {
  const contact = selectedContact.value
  if (!contact) return
  easyShare.open({
    appId: 'phone',
    copyText: `${contact.name}\n${contact.phone_number}`,
    id: contact.id,
    imageUrl: contact.avatar_url,
    kind: 'contact',
    subtitle: formatPhoneNumber(contact.phone_number),
    title: contact.name,
  })
}

async function shareOwnProfile(): Promise<void> {
  const response = await nuiCall<EasySharePayload>('easyshare:own-contact')
  if (!response.success || !response.data) {
    error.value = phone.t(
      `Apps.easyShare.errors.${response.error ?? 'request_failed'}`,
    )
    return
  }
  error.value = ''
  easyShare.open(response.data)
}

function messageActiveCaller(): void {
  const number = calls.activeCall?.otherNumber
  callMoreOpened.value = false
  if (number) void openMessage(number)
}

async function removeActiveCallerContact(): Promise<void> {
  const contact = activeCallContact.value
  if (!contact) return
  if (await calls.deleteContact(contact.id)) {
    callMoreOpened.value = false
    return
  }
  error.value = phone.t('Apps.phone.errors.contact_remove_failed')
}

function confirmBlockNumber(number: string): void {
  callMoreOpened.value = false
  blockTargetNumber.value = number
  blockDialogOpened.value = true
}

async function blockNumber(): Promise<void> {
  const number = blockTargetNumber.value
  blockDialogOpened.value = false
  error.value = ''
  const response = await calls.blockNumber(number)
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
  }
}

function openCallKeypad(): void {
  callMoreOpened.value = false
  inCallKeypad.value = ''
  callKeypadOpened.value = true
}

function addInCallDigit(digit: string): void {
  if (inCallKeypad.value.length < 24) inCallKeypad.value += digit
}

async function deleteEditedContact(): Promise<void> {
  if (!editingContact.value) return
  if (editingContact.value.readonly) {
    error.value = phone.t('Apps.phone.errors.readonly_contact')
    return
  }
  if (await calls.deleteContact(editingContact.value.id)) {
    editorOpened.value = false
  }
}

function addDigit(digit: string): void {
  if (keypad.value.length < 10) keypad.value += digit
}

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false
  return (
    target.isContentEditable ||
    target instanceof HTMLInputElement ||
    target instanceof HTMLSelectElement ||
    target instanceof HTMLTextAreaElement
  )
}

function handleKeypadKeyboard(event: KeyboardEvent): void {
  if (
    tab.value !== 'keypad' ||
    selectedNumber.value ||
    event.defaultPrevented ||
    event.isComposing ||
    event.altKey ||
    event.ctrlKey ||
    event.metaKey ||
    isEditableTarget(event.target)
  ) {
    return
  }

  if (/^[0-9*#]$/.test(event.key)) {
    event.preventDefault()
    addDigit(event.key)
    return
  }

  if (event.key === 'Backspace' || event.key === 'Delete') {
    event.preventDefault()
    keypad.value = keypad.value.slice(0, -1)
    return
  }

  if (event.key === 'Enter' && keypad.value && !event.repeat) {
    event.preventDefault()
    void startCall(keypad.value)
  }
}

function chooseKeypadSuggestion(contact: PhoneContact): void {
  keypad.value = contact.phone_number.replace(/\D/g, '').slice(0, 10)
}

function recentStatus(recent: RecentCall): string {
  const key = recent.status === 'no_answer' ? 'noAnswer' : recent.status
  return phone.t(`Apps.phone.${key}`)
}

function recentSubtitle(recent: RecentCall): string {
  const status = recentStatus(recent)
  const direction = phone.t(
    `Apps.phone.${recent.direction === 'incoming' ? 'incomingDirection' : 'outgoingDirection'}`,
  )
  if (!recent.duration_seconds) return `${direction} · ${status}`
  const minutes = Math.floor(recent.duration_seconds / 60)
  const seconds = String(recent.duration_seconds % 60).padStart(2, '0')
  return `${direction} · ${status} · ${minutes}:${seconds}`
}

function contactInitials(number: string): string {
  const contact = calls.contacts.find((entry) => entry.phone_number === number)
  if (!contact) return ''
  return contact.name.trim().charAt(0).toUpperCase()
}

function formatRecentDate(value: string): string {
  const date = new Date(value)
  const now = new Date()
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  if (sameDay) {
    return new Intl.DateTimeFormat(phone.lang, {
      hour: '2-digit',
      minute: '2-digit',
    }).format(date)
  }
  const daysAgo = Math.floor(
    (new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() -
      new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()) /
      86_400_000,
  )
  if (daysAgo < 7) {
    return new Intl.DateTimeFormat(phone.lang, { weekday: 'long' }).format(date)
  }
  return new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
  }).format(date)
}

onMounted(async () => {
  window.addEventListener('keydown', handleKeypadKeyboard)
  await calls.bootstrap()
  const photoSelection = mediaPicker.consumeMany<ContactPhotoContext>(
    'phone:contact-photo',
  )
  if (photoSelection) {
    const context = photoSelection.context
    editingContact.value = context?.contactId
      ? (calls.contacts.find((contact) => contact.id === context.contactId) ??
        null)
      : null
    contactFirstName.value = context?.firstName ?? ''
    contactLastName.value = context?.lastName ?? ''
    contactEmail.value = context?.email ?? ''
    contactNotes.value = context?.notes ?? ''
    contactOrganization.value = context?.organization ?? ''
    contactNumber.value = context?.phoneNumber ?? ''
    contactAvatarMediaId.value = context?.avatarMediaId ?? null
    contactAvatarUrl.value = context?.avatarUrl ?? ''
    if (photoSelection.media[0]) {
      contactAvatarMediaId.value = photoSelection.media[0].id
      contactAvatarUrl.value = photoSelection.media[0].url
    }
    tab.value = 'contacts'
    editorOpened.value = true
  } else if (typeof route.query.contactId === 'string') {
    const requestedContact = calls.contacts.find(
      (contact) => contact.id === route.query.contactId,
    )
    if (requestedContact) {
      tab.value = 'contacts'
      openRecentDetail(requestedContact.phone_number)
    }
    await router.replace('/apps/phone')
  } else if (typeof route.query.newContactNumber === 'string') {
    tab.value = 'contacts'
    openContact(undefined, route.query.newContactNumber)
    await router.replace('/apps/phone')
  }
  callClock = window.setInterval(updateCallElapsed, 500)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeypadKeyboard)
  if (callClock !== null) window.clearInterval(callClock)
})
</script>

<template>
  <sky-app-page
    class="native-app phone-calls-app"
    :class="{
      'phone-app--light': !phone.isDarkMode,
      'phone-calls-app--profile': Boolean(selectedNumber),
    }"
  >
    <template v-if="calls.activeCall">
      <section
        class="phone-active-call"
        :class="{ 'phone-active-call--more': callMoreOpened }"
      >
        <header class="phone-active-call__identity">
          <div class="phone-active-call__status">
            <span>P</span>
            {{ activeCallStatus }}
          </div>
          <h1>
            {{ contactNameFor(calls.activeCall.otherNumber) }}
          </h1>
          <p v-if="error" class="phone-active-call__error">{{ error }}</p>
        </header>

        <Transition name="call-panel" mode="out-in">
          <div
            v-if="callKeypadOpened"
            key="keypad"
            class="phone-in-call-keypad"
          >
            <div class="phone-in-call-keypad__grid">
              <sky-glass
                v-for="key in keypadKeys"
                :key="key.digit"
                component="button"
                type="button"
                @click="addInCallDigit(key.digit)"
              >
                <span>{{ key.digit }}</span>
                <small>{{ key.letters }}</small>
              </sky-glass>
            </div>
            <div class="phone-in-call-keypad__footer">
              <sky-button
                glass
                rounded
                class="phone-in-call-keypad__end"
                variant="danger"
                @click="calls.hangup()"
              >
                <PhoneOff />
              </sky-button>
              <sky-button
                glass
                clear
                class="phone-in-call-keypad__hide"
                @click="callKeypadOpened = false"
                >{{ phone.t('Apps.phone.hideKeypad') }}</sky-button
              >
            </div>
          </div>

          <div
            v-else-if="callMoreOpened"
            key="more"
            class="phone-call-more"
            @click.self="callMoreOpened = false"
          >
            <div class="phone-call-more__list">
              <sky-button
                glass
                class="phone-call-more__item phone-call-more__contact-card"
                @click="openCallContact"
              >
                <span class="phone-call-more__avatar">
                  <span v-if="contactInitials(calls.activeCall.otherNumber)">
                    {{ contactInitials(calls.activeCall.otherNumber) }}
                  </span>
                  <UserRound v-else />
                </span>
                <strong>{{
                  phone.t(
                    activeCallContact
                      ? 'Apps.phone.contactCard'
                      : 'Apps.phone.addToContacts',
                  )
                }}</strong>
              </sky-button>

              <sky-button
                glass
                class="phone-call-more__item"
                @click="messageActiveCaller"
              >
                <MessageCircle />
                <strong>{{ phone.t('Apps.phone.sendMessage') }}</strong>
              </sky-button>

              <sky-button
                glass
                v-if="activeCallContact"
                class="phone-call-more__item phone-call-more__item--danger"
                @click="removeActiveCallerContact"
              >
                <Delete />
                <strong>{{ phone.t('Apps.phone.removeContact') }}</strong>
              </sky-button>

              <sky-button
                glass
                class="phone-call-more__item phone-call-more__item--danger"
                @click="confirmBlockNumber(calls.activeCall.otherNumber)"
              >
                <PhoneOff />
                <strong>{{ phone.t('Apps.phone.blockCaller') }}</strong>
              </sky-button>
            </div>
          </div>

          <div v-else key="actions" class="phone-active-call__actions">
            <sky-button
              glass
              rounded
              class="phone-call-action"
              :class="{
                'is-active': calls.activeCall.speakerEnabled,
                'is-disabled':
                  calls.activeCall.state !== 'connected' ||
                  !calls.activeCall.speakerSupported,
              }"
              :disabled="
                calls.activeCall.state !== 'connected' ||
                !calls.activeCall.speakerSupported ||
                callSpeakerPending
              "
              :aria-pressed="calls.activeCall.speakerEnabled === true"
              @click="toggleCallSpeaker"
            >
              <Volume2 />
              <span>{{ phone.t('Apps.phone.speaker') }}</span>
            </sky-button>
            <sky-button
              glass
              rounded
              class="phone-call-action is-disabled"
              disabled
            >
              <Video />
              <span>{{ phone.t('Apps.phone.faceTime') }}</span>
            </sky-button>
            <sky-button
              glass
              rounded
              class="phone-call-action"
              :class="{
                'is-active': calls.activeCall.muted,
                'is-disabled':
                  calls.activeCall.state !== 'connected' ||
                  !calls.activeCall.muteSupported,
              }"
              :disabled="
                calls.activeCall.state !== 'connected' ||
                !calls.activeCall.muteSupported ||
                callMutePending
              "
              :aria-busy="callMutePending || undefined"
              :aria-pressed="calls.activeCall.muted === true"
              @click="toggleCallMute"
            >
              <MicOff />
              <span>{{ phone.t('Apps.phone.mute') }}</span>
            </sky-button>

            <div class="phone-call-action-anchor">
              <sky-button
                glass
                rounded
                class="phone-call-action"
                @click="callMoreOpened = !callMoreOpened"
              >
                <MoreHorizontal />
                <span>{{ phone.t('Apps.phone.more') }}</span>
              </sky-button>
            </div>
            <sky-button
              glass
              rounded
              class="phone-call-action phone-call-action--end"
              variant="danger"
              @click="
                calls.activeCall.direction === 'incoming' &&
                calls.activeCall.state === 'ringing'
                  ? calls.decline()
                  : calls.hangup()
              "
            >
              <PhoneOff />
              <span>{{
                phone.t(
                  calls.activeCall.direction === 'incoming' &&
                    calls.activeCall.state === 'ringing'
                    ? 'Apps.phone.decline'
                    : 'Apps.phone.hangup',
                )
              }}</span>
            </sky-button>
            <sky-button
              glass
              v-if="
                calls.activeCall.direction === 'incoming' &&
                calls.activeCall.state === 'ringing'
              "
              rounded
              class="phone-call-action phone-call-action--answer"
              @click="answerCall"
            >
              <Phone />
              <span>{{ phone.t('Apps.phone.answer') }}</span>
            </sky-button>
            <sky-button
              glass
              v-else
              rounded
              class="phone-call-action"
              @click="openCallKeypad"
            >
              <Grid3X3 />
              <span>{{ phone.t('Apps.phone.keypad') }}</span>
            </sky-button>
          </div>
        </Transition>
      </section>
    </template>

    <template v-else>
      <div
        ref="phoneContent"
        class="phone-call-content"
        :class="{ 'phone-call-content--profile': selectedNumber }"
      >
        <sky-block v-if="!phone.device?.sim" class="text-center">
          <h2>{{ phone.t('Apps.phone.noSim') }}</h2>
          <p class="text-[#8e8e93]">{{ phone.t('Apps.phone.noSimBody') }}</p>
        </sky-block>

        <template v-else-if="selectedNumber">
          <section class="phone-contact-detail">
            <header class="phone-detail-header">
              <sky-button
                glass
                rounded
                class="phone-detail-header-button phone-detail-back"
                :aria-label="phone.t('Common.back')"
                @click="closeRecentDetail"
              >
                <ChevronLeft :size="29" :stroke-width="2.4" />
              </sky-button>

              <span class="phone-detail-header-spacer" />

              <sky-button
                glass
                v-if="!viewingOwnCard"
                rounded
                class="phone-detail-edit"
                @click="
                  openContact(selectedContact ?? undefined, selectedNumber)
                "
              >
                {{
                  phone.t(
                    selectedContact ? 'Common.edit' : 'Apps.phone.addContact',
                  )
                }}
              </sky-button>
              <span v-else class="phone-detail-edit-spacer" />
            </header>

            <div class="phone-contact-hero">
              <div class="phone-contact-avatar phone-contact-avatar--large">
                <img
                  v-if="selectedContact?.avatar_url"
                  :src="selectedContact.avatar_url"
                  alt=""
                />
                <span v-else-if="contactInitials(selectedNumber)">{{
                  contactInitials(selectedNumber)
                }}</span>
                <UserRound v-else :size="48" :stroke-width="1.8" />
              </div>
              <h2>{{ selectedDisplayName }}</h2>
              <p
                v-if="selectedContact?.organization"
                class="phone-contact-organization"
              >
                {{ selectedContact.organization }}
              </p>
              <p v-if="!selectedContact && !viewingOwnCard">
                {{ phone.t('Apps.phone.unknownCaller') }}
              </p>

              <div class="phone-contact-actions">
                <sky-button
                  glass
                  v-for="action in contactProfileActions"
                  :key="action.id"
                  icon-only
                  rounded
                  class="phone-profile-action"
                  :disabled="
                    viewingOwnCard ||
                    ['video', 'mail'].includes(action.id) ||
                    (action.id === 'call' &&
                      selectedContact?.canCall === false) ||
                    (action.id === 'message' &&
                      selectedContact?.canMessage === false)
                  "
                  :aria-label="phone.t(`Apps.phone.${action.id}`)"
                  @click="triggerContactAction(action.id)"
                >
                  <component :is="action.icon" :size="23" fill="currentColor" />
                </sky-button>
              </div>
            </div>

            <section v-if="viewingOwnCard" class="phone-profile-content">
              <sky-glass class="phone-own-profile-card">
                <div>
                  <span><Phone :size="19" /></span>
                  <p>
                    <small>{{ phone.t('Apps.phone.myNumber') }}</small>
                    <strong>{{ formatPhoneNumber(selectedNumber) }}</strong>
                  </p>
                </div>
                <div>
                  <span><Smartphone :size="19" /></span>
                  <p>
                    <small>{{ phone.t('Apps.phone.device') }}</small>
                    <strong>{{ phone.device?.name }}</strong>
                  </p>
                </div>
              </sky-glass>
              <sky-glass class="phone-profile-card phone-profile-single-option">
                <button type="button" @click="shareOwnProfile">
                  <span>{{ phone.t('Apps.easyShare.shareProfile') }}</span>
                </button>
              </sky-glass>
            </section>

            <section v-else class="phone-profile-content">
              <sky-glass class="phone-profile-card phone-profile-info-card">
                <button
                  type="button"
                  :disabled="selectedContact?.canCall === false"
                  @click="startCall(selectedNumber)"
                >
                  <span>
                    <small>{{ phone.t('Apps.phone.mobile') }}</small>
                    <strong>{{ formatPhoneNumber(selectedNumber) }}</strong>
                  </span>
                  <Phone :size="21" fill="currentColor" />
                </button>
                <button
                  type="button"
                  :disabled="selectedContact?.canMessage === false"
                  @click="openMessage(selectedNumber)"
                >
                  <span>
                    <small>{{ phone.t('Apps.phone.messagesProfile') }}</small>
                    <strong>{{ selectedDisplayName }}</strong>
                  </span>
                  <ChevronRight :size="23" />
                </button>
                <div class="phone-profile-notes">
                  <span>{{ phone.t('Apps.phone.notes') }}</span>
                  <p v-if="selectedContact?.notes">
                    {{ selectedContact.notes }}
                  </p>
                </div>
              </sky-glass>

              <sky-glass class="phone-profile-card phone-profile-options-card">
                <button
                  type="button"
                  :disabled="selectedContact?.canMessage === false"
                  @click="openMessage(selectedNumber)"
                >
                  <span>{{ phone.t('Apps.phone.sendMessage') }}</span>
                </button>
                <button
                  type="button"
                  :disabled="!selectedContact"
                  @click="shareSelectedContact"
                >
                  <span>{{ phone.t('Apps.phone.shareContact') }}</span>
                </button>
                <button
                  type="button"
                  :disabled="!selectedContact"
                  @click="toggleSelectedFavorite"
                >
                  <span>{{
                    phone.t(
                      selectedContact?.favorite
                        ? 'Apps.phone.removeFavorite'
                        : 'Apps.phone.addFavorite',
                    )
                  }}</span>
                </button>
              </sky-glass>

              <sky-glass class="phone-profile-card phone-profile-single-option">
                <button
                  type="button"
                  @click="confirmBlockNumber(selectedNumber)"
                >
                  <span>{{ phone.t('Apps.phone.blockContact') }}</span>
                </button>
              </sky-glass>

              <sky-glass class="phone-history-card">
                <h3>{{ phone.t('Apps.phone.callHistory') }}</h3>
                <div
                  v-for="recent in selectedHistory"
                  :key="recent.id"
                  class="phone-history-row"
                >
                  <span
                    class="phone-history-direction"
                    :class="{
                      'phone-history-direction--missed': [
                        'missed',
                        'no_answer',
                      ].includes(recent.status),
                    }"
                  >
                    <PhoneIncoming
                      v-if="recent.direction === 'incoming'"
                      :size="17"
                    />
                    <PhoneOutgoing v-else :size="17" />
                  </span>
                  <span class="phone-history-copy">
                    <strong>{{ recentStatus(recent) }}</strong>
                    <small>{{ recentSubtitle(recent) }}</small>
                  </span>
                  <time>{{ formatRecentDate(recent.created_at) }}</time>
                </div>
                <p v-if="!selectedHistory.length" class="phone-history-empty">
                  {{ phone.t('Apps.phone.noCallHistory') }}
                </p>
              </sky-glass>
            </section>
          </section>
        </template>

        <template v-else-if="tab === 'recents'">
          <section class="phone-recents">
            <header class="phone-recents-header">
              <sky-segmented
                :active-index="recentFilter === 'all' ? 0 : 1"
                :aria-label="phone.t('Apps.phone.recents')"
                class="phone-recents-filter"
                compact
                :item-count="2"
                navigation
                rounded
                strong
              >
                <sky-segmented-button
                  :active="recentFilter === 'all'"
                  @click="recentFilter = 'all'"
                >
                  {{ phone.t('Apps.phone.allCalls') }}
                </sky-segmented-button>
                <sky-segmented-button
                  :active="recentFilter === 'missed'"
                  @click="recentFilter = 'missed'"
                >
                  {{ phone.t('Apps.phone.missedCalls') }}
                </sky-segmented-button>
              </sky-segmented>
              <h1>{{ phone.t('Apps.phone.recents') }}</h1>
              <sky-glass
                component="label"
                :highlight="false"
                class="phone-recents-search"
              >
                <Search :size="21" />
                <input
                  :value="recentQuery"
                  :placeholder="phone.t('Apps.phone.searchRecents')"
                  type="search"
                  @input="recentQuery = eventValue($event)"
                />
              </sky-glass>
            </header>

            <div v-if="visibleRecents.length" class="phone-recents-list">
              <article
                v-for="recent in visibleRecents"
                :key="recent.id"
                class="phone-recent-row"
              >
                <div class="phone-contact-avatar">
                  <img
                    v-if="contactsByNumber.get(recent.other_number)?.avatar_url"
                    :src="
                      contactsByNumber.get(recent.other_number)?.avatar_url ??
                      ''
                    "
                    alt=""
                  />
                  <span v-else-if="contactInitials(recent.other_number)">{{
                    contactInitials(recent.other_number)
                  }}</span>
                  <UserRound v-else :size="30" :stroke-width="1.8" />
                </div>
                <button
                  class="phone-recent-call"
                  type="button"
                  @click="startCall(recent.other_number)"
                >
                  <span
                    class="phone-recent-name"
                    :class="{
                      'phone-recent-name--missed': [
                        'missed',
                        'no_answer',
                      ].includes(recent.status),
                    }"
                  >
                    {{ contactNameFor(recent.other_number) }}
                  </span>
                  <span class="phone-recent-meta">
                    <PhoneIncoming
                      v-if="recent.direction === 'incoming'"
                      :size="14"
                    />
                    <PhoneOutgoing v-else :size="14" />
                    {{ recentStatus(recent) }}
                  </span>
                </button>
                <time class="phone-recent-date">{{
                  formatRecentDate(recent.created_at)
                }}</time>
                <sky-glass
                  component="button"
                  class="phone-recent-info"
                  type="button"
                  :aria-label="phone.t('Apps.phone.contactDetails')"
                  @click="openRecentDetail(recent.other_number)"
                >
                  <Info :size="21" />
                </sky-glass>
              </article>
            </div>
            <sky-block v-else class="text-center text-[#8e8e93]">{{
              phone.t('Apps.phone.noRecents')
            }}</sky-block>
          </section>
        </template>

        <template v-else-if="tab === 'contacts'">
          <section class="phone-contacts">
            <header class="phone-contacts-header">
              <div class="phone-contacts-toolbar">
                <span aria-hidden="true" />
                <h1>{{ phone.t('Apps.phone.contacts') }}</h1>
                <sky-glass
                  component="button"
                  class="phone-contacts-add"
                  type="button"
                  :aria-label="phone.t('Apps.phone.addContact')"
                  @click="openContact()"
                >
                  <Plus :size="28" />
                </sky-glass>
              </div>

              <sky-glass
                component="label"
                :highlight="false"
                class="phone-contacts-search"
              >
                <Search :size="21" />
                <input
                  :value="query"
                  :placeholder="phone.t('Common.search')"
                  type="search"
                  @input="query = eventValue($event)"
                />
              </sky-glass>
            </header>

            <button class="phone-my-card" type="button" @click="openMyCard">
              <div class="phone-contact-avatar">
                <UserRound :size="30" :stroke-width="1.8" />
              </div>
              <span>
                <strong>{{ phone.t('Apps.phone.myCard') }}</strong>
                <small v-if="phone.device?.sim">{{
                  formatPhoneNumber(phone.device.sim.number)
                }}</small>
              </span>
            </button>

            <div v-if="groupedContacts.length" class="phone-contact-groups">
              <section
                v-if="!query && favoriteContacts.length"
                id="phone-contact-group-favorites"
                class="phone-contact-group phone-contact-group--favorites"
              >
                <h2>
                  <Star :size="13" fill="currentColor" />
                  {{ phone.t('Apps.phone.favorites') }}
                </h2>
                <button
                  v-for="contact in favoriteContacts"
                  :key="`favorite-${contact.id}`"
                  class="phone-contact-row"
                  type="button"
                  @click="openRecentDetail(contact.phone_number)"
                >
                  <span class="phone-contact-avatar">
                    <img
                      v-if="contact.avatar_url"
                      :src="contact.avatar_url"
                      alt=""
                    />
                    <template v-else>{{
                      contactInitials(contact.phone_number)
                    }}</template>
                  </span>
                  <span class="phone-contact-name">
                    {{ contact.name }}
                    <small v-if="contact.readonly">{{
                      phone.t('Apps.phone.officialContact')
                    }}</small>
                  </span>
                </button>
              </section>
              <section
                v-for="group in groupedContacts"
                :id="`phone-contact-group-${
                  group.letter === '#' ? 'other' : group.letter.toLowerCase()
                }`"
                :key="group.letter"
                class="phone-contact-group"
              >
                <h2>{{ group.letter }}</h2>
                <button
                  v-for="contact in group.contacts"
                  :key="contact.id"
                  class="phone-contact-row"
                  type="button"
                  @click="openRecentDetail(contact.phone_number)"
                >
                  <span class="phone-contact-avatar">
                    <img
                      v-if="contact.avatar_url"
                      :src="contact.avatar_url"
                      alt=""
                    />
                    <template v-else>{{
                      contactInitials(contact.phone_number)
                    }}</template>
                  </span>
                  <span class="phone-contact-name">
                    {{ contact.name }}
                    <small v-if="contact.readonly">{{
                      phone.t('Apps.phone.officialContact')
                    }}</small>
                  </span>
                </button>
              </section>
            </div>
            <sky-block v-else class="text-center text-[#8e8e93]">{{
              phone.t('Apps.phone.noContacts')
            }}</sky-block>

            <nav
              v-if="!query"
              class="phone-contact-index"
              :aria-label="phone.t('Apps.phone.contactIndex')"
            >
              <button
                v-if="favoriteContacts.length"
                type="button"
                :aria-label="phone.t('Apps.phone.favorites')"
                @click="scrollToContactGroup('favorites')"
              >
                <Star :size="9" fill="currentColor" />
              </button>
              <button
                v-for="letter in contactAlphabet"
                :key="letter"
                type="button"
                @click="scrollToContactGroup(letter)"
              >
                {{ letter }}
              </button>
            </nav>
          </section>
        </template>

        <template v-else>
          <section class="phone-keypad">
            <Transition name="keypad-suggestions">
              <div
                v-if="keypadSuggestions.length"
                class="phone-keypad-suggestions"
                aria-live="polite"
              >
                <sky-glass
                  v-for="contact in keypadSuggestions"
                  :key="contact.id"
                  component="button"
                  class="phone-keypad-suggestion"
                  type="button"
                  @click="chooseKeypadSuggestion(contact)"
                >
                  <span class="phone-keypad-suggestion__avatar">
                    <img
                      v-if="contact.avatar_url"
                      :src="contact.avatar_url"
                      alt=""
                    />
                    <template v-else>{{
                      contactInitials(contact.phone_number)
                    }}</template>
                  </span>
                  <span class="phone-keypad-suggestion__copy">
                    <strong>{{ contact.name }}</strong>
                    <small>{{ formatPhoneNumber(contact.phone_number) }}</small>
                  </span>
                </sky-glass>
              </div>
            </Transition>
            <div class="phone-keypad-number" aria-live="polite">
              {{ keypadDisplay }}
            </div>
            <div class="phone-keypad-grid">
              <sky-glass
                v-for="key in keypadKeys"
                :key="key.digit"
                component="button"
                class="phone-keypad-key"
                type="button"
                @click="addDigit(key.digit)"
              >
                <span>{{ key.digit }}</span>
                <small :class="{ 'phone-keypad-plus': key.digit === '0' }">
                  {{ key.letters }}
                </small>
              </sky-glass>
            </div>
            <div class="phone-keypad-actions">
              <sky-glass
                component="button"
                class="phone-keypad-call"
                type="button"
                @click="startCall(keypad)"
              >
                <Phone :size="31" fill="currentColor" />
              </sky-glass>
              <sky-glass
                v-if="keypad"
                component="button"
                class="phone-keypad-delete"
                type="button"
                :aria-label="phone.t('Common.delete')"
                @click="keypad = keypad.slice(0, -1)"
              >
                <Delete :size="27" />
              </sky-glass>
            </div>
          </section>
        </template>

        <p v-if="error" class="px-5 text-center text-sm text-[#ff3b30]">
          {{ error }}
        </p>
      </div>
      <sky-tab-bar
        icons
        labels
        class="phone-bottom-tabbar"
        :aria-label="phone.t('Apps.phone.name')"
      >
        <sky-tab-button
          v-for="item in tabs"
          :key="item.id"
          :active="tab === item.id"
          :aria-label="phone.t(`Apps.phone.${item.id}`)"
          @click="selectTab(item.id)"
        >
          <template #icon>
            <component :is="item.icon" aria-hidden="true" />
          </template>
          <template #label>{{ phone.t(`Apps.phone.${item.id}`) }}</template>
        </sky-tab-button>
      </sky-tab-bar>
    </template>
  </sky-app-page>

  <div class="phone-contact-editor-sheet">
    <sky-sheet :opened="editorOpened" @backdropclick="editorOpened = false">
      <section
        class="phone-contact-editor"
        :class="{ 'phone-contact-editor--light': !phone.isDarkMode }"
        role="dialog"
        aria-modal="true"
        :aria-label="
          phone.t(
            editingContact?.readonly
              ? 'Apps.phone.officialContact'
              : editingContact
                ? 'Apps.phone.editContact'
                : 'Apps.phone.addContact',
          )
        "
      >
        <header class="phone-contact-editor__header">
          <sky-button
            glass
            rounded
            class="phone-contact-editor__header-button"
            :aria-label="phone.t('Common.cancel')"
            @click="editorOpened = false"
          >
            <X :size="27" />
          </sky-button>
          <h2>
            {{
              phone.t(
                editingContact?.readonly
                  ? 'Apps.phone.officialContact'
                  : editingContact
                    ? 'Apps.phone.editContact'
                    : 'Apps.phone.newContact',
              )
            }}
          </h2>
          <sky-button
            glass
            v-if="!editingContact?.readonly"
            rounded
            class="phone-contact-editor__header-button"
            :aria-label="phone.t('Common.save')"
            @click="saveContact"
          >
            <Check :size="28" :stroke-width="2.2" />
          </sky-button>
        </header>

        <div class="phone-contact-editor__scroll">
          <div class="phone-contact-editor__photo">
            <div
              class="phone-contact-editor__avatar-wrap"
              :class="{
                'phone-contact-editor__avatar-wrap--has-photo':
                  contactAvatarUrl,
              }"
            >
              <sky-glass
                component="button"
                class="phone-contact-editor__avatar"
                type="button"
                :aria-label="phone.t('Apps.phone.choosePhoto')"
                :disabled="editingContact?.readonly"
                @click="openContactPhotoPicker('photos')"
              >
                <img v-if="contactAvatarUrl" :src="contactAvatarUrl" alt="" />
                <span v-else-if="contactEditorInitials">{{
                  contactEditorInitials
                }}</span>
                <UserRound v-else :size="72" :stroke-width="1.35" />
              </sky-glass>
              <sky-button
                glass
                v-if="contactAvatarUrl && !editingContact?.readonly"
                rounded
                class="phone-contact-editor__remove-photo"
                :aria-label="phone.t('Apps.phone.removePhoto')"
                @click="removeContactPhoto"
              >
                <Delete :size="25" />
                <span>{{ phone.t('Apps.phone.removePhoto') }}</span>
              </sky-button>
            </div>
            <div
              v-if="!editingContact?.readonly"
              class="phone-contact-editor__photo-actions"
            >
              <sky-button
                glass
                small
                rounded
                tonal
                @click="openContactPhotoPicker('photos')"
              >
                <Images :size="18" />
                {{ phone.t('Apps.phone.chooseGallery') }}
              </sky-button>
              <sky-button
                glass
                small
                rounded
                tonal
                @click="openContactPhotoPicker('camera')"
              >
                <Camera :size="18" />
                {{ phone.t('Apps.phone.takePhoto') }}
              </sky-button>
            </div>
          </div>

          <sky-list strong inset class="phone-contact-editor__name-list">
            <sky-field
              :value="contactFirstName"
              :placeholder="phone.t('Apps.phone.firstName')"
              autocomplete="given-name"
              :readonly="editingContact?.readonly"
              @input="contactFirstName = eventValue($event)"
            />
            <sky-field
              :value="contactLastName"
              :placeholder="phone.t('Apps.phone.lastName')"
              autocomplete="family-name"
              :readonly="editingContact?.readonly"
              @input="contactLastName = eventValue($event)"
            />
            <sky-field
              :value="contactOrganization"
              :placeholder="phone.t('Apps.phone.companyOrGroup')"
              autocomplete="organization"
              :readonly="editingContact?.readonly"
              @input="contactOrganization = eventValue($event)"
            />
            <sky-field
              :value="contactEmail"
              type="email"
              :placeholder="phone.t('Apps.phone.mail')"
              autocomplete="email"
              :readonly="editingContact?.readonly"
              @input="contactEmail = eventValue($event)"
            />
          </sky-list>

          <sky-list strong inset class="phone-contact-editor__number-list">
            <sky-field
              :value="contactNumber"
              :label="phone.t('Apps.phone.mobile')"
              :placeholder="phone.t('Apps.phone.phoneNumber')"
              inputmode="tel"
              autocomplete="tel"
              :readonly="editingContact?.readonly"
              @input="contactNumber = eventValue($event)"
            >
              <template #media>
                <span class="phone-contact-editor__add-icon"
                  ><Plus :size="19"
                /></span>
              </template>
            </sky-field>
          </sky-list>

          <sky-list strong inset class="phone-contact-editor__notes-list">
            <sky-field
              :value="contactNotes"
              type="textarea"
              :placeholder="phone.t('Apps.phone.notes')"
              :maxlength="500"
              autocapitalize="sentences"
              :readonly="editingContact?.readonly"
              @input="contactNotes = eventValue($event)"
            />
          </sky-list>

          <p v-if="error" class="phone-contact-editor__error">{{ error }}</p>

          <sky-button
            glass
            v-if="editingContact && !editingContact.readonly"
            class="phone-contact-editor__delete"
            @click="deleteEditedContact"
          >
            {{ phone.t('Apps.phone.deleteContact') }}
          </sky-button>
        </div>
      </section>
    </sky-sheet>
  </div>

  <sky-dialog
    :opened="blockDialogOpened"
    @backdropclick="blockDialogOpened = false"
  >
    <template #title>{{ phone.t('Apps.phone.blockCallerTitle') }}</template>
    <p>
      {{
        phone.t('Apps.phone.blockCallerBody', {
          number: contactNameFor(blockTargetNumber),
        })
      }}
    </p>
    <template #buttons>
      <sky-dialog-button @click="blockDialogOpened = false">{{
        phone.t('Common.cancel')
      }}</sky-dialog-button>
      <sky-dialog-button strong @click="blockNumber">{{
        phone.t('Apps.phone.block')
      }}</sky-dialog-button>
    </template>
  </sky-dialog>
</template>

<style scoped>
.phone-active-call {
  position: absolute;
  z-index: 30;
  inset: 0;
  display: flex;
  min-height: 0;
  flex-direction: column;
  overflow: hidden;
  background: linear-gradient(180deg, #3a3a3c 0%, #1c1c1e 44%, #090909 100%);
  color: white;
  text-align: center;
}

.phone-active-call::before {
  position: absolute;
  z-index: 0;
  inset: 0;
  background: rgba(0, 0, 0, 0.48);
  content: '';
  opacity: 0;
  pointer-events: none;
  transition: opacity 260ms cubic-bezier(0.22, 1, 0.36, 1);
}

.phone-active-call > * {
  position: relative;
  z-index: 1;
}

.phone-active-call--more::before {
  opacity: 1;
}

.phone-active-call--more .phone-active-call__identity {
  opacity: 0.48;
}

.phone-active-call__identity {
  padding: 112px 24px 0;
  transition: opacity 240ms cubic-bezier(0.22, 1, 0.36, 1);
}

.call-panel-enter-active {
  transition:
    opacity 240ms ease-out,
    transform 320ms cubic-bezier(0.22, 1, 0.36, 1);
  will-change: opacity, transform;
}

.call-panel-leave-active {
  transition:
    opacity 150ms ease-in,
    transform 190ms cubic-bezier(0.4, 0, 1, 1);
  will-change: opacity, transform;
}

.call-panel-enter-from,
.call-panel-leave-to {
  opacity: 0;
}

.phone-active-call__actions.call-panel-enter-from,
.phone-active-call__actions.call-panel-leave-to {
  transform: translateY(18px) scale(0.985);
}

.phone-call-more.call-panel-enter-from,
.phone-call-more.call-panel-leave-to {
  transform: translateY(38px);
}

.phone-in-call-keypad.call-panel-enter-from,
.phone-in-call-keypad.call-panel-leave-to {
  transform: translateY(24px) scale(0.97);
}

@media (prefers-reduced-motion: reduce) {
  .phone-active-call::before,
  .phone-active-call__identity,
  .call-panel-enter-active,
  .call-panel-leave-active {
    transition-duration: 1ms !important;
  }
}

.phone-active-call__status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  color: rgba(255, 255, 255, 0.6);
  font-size: 25px;
  font-variant-numeric: tabular-nums;
  font-weight: 500;
  line-height: 28px;
}

.phone-active-call__status span {
  display: grid;
  width: 16px;
  height: 16px;
  place-items: center;
  border-radius: 3px;
  background: white;
  color: #2c2c2e;
  font-size: 10px;
  font-weight: 800;
  line-height: 1;
}

.phone-active-call__identity h1 {
  max-width: 100%;
  margin: 9px 0 0;
  overflow: hidden;
  font-size: 32px;
  font-weight: 700;
  letter-spacing: -0.8px;
  line-height: 1.08;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-active-call__error {
  margin: 10px 0 0;
  color: #ffb4ae;
  font-size: 12px;
}

.phone-active-call__actions {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 11px 19px;
  width: 100%;
  margin-top: auto;
  padding: 0 28px 48px;
}

.phone-call-action {
  position: relative;
  display: flex !important;
  width: 100% !important;
  height: 108px !important;
  flex-direction: column !important;
  align-items: center !important;
  justify-content: flex-start !important;
  gap: 13px !important;
  padding: 24px 0 0 !important;
  border: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  color: white !important;
  overflow: visible !important;
  font-size: 14px !important;
  font-weight: 400 !important;
  line-height: 17px !important;
  white-space: nowrap;
}

.phone-call-action-anchor {
  min-width: 0;
  height: 108px;
}

.phone-call-action::before {
  position: absolute;
  z-index: 0;
  top: 0;
  left: 50%;
  width: 80px;
  height: 80px;
  border: 1px solid var(--sky-hairline);
  border-radius: 50%;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  content: '';
  transform: translateX(-50%);
  transition:
    background-color 140ms ease,
    transform 140ms ease;
}

.phone-call-action:active::before {
  transform: translateX(-50%) scale(0.94);
}

.phone-call-action > svg,
.phone-call-action > span {
  position: relative;
  z-index: 1;
}

.phone-call-action.sky-glass::after {
  top: 1px;
  right: auto;
  bottom: auto;
  left: 50%;
  width: 78px;
  height: 78px;
  border-radius: 50%;
  transform: translateX(-50%);
}

.phone-call-action > svg {
  width: 32px;
  height: 32px;
  flex: none;
  stroke-width: 2.2;
}

.phone-call-action > span {
  position: absolute;
  top: 89px;
  display: block;
  width: 112px;
  overflow: hidden;
  color: #fff;
  line-height: 18px;
  text-overflow: ellipsis;
  transition: none;
}

.phone-call-action.is-active {
  color: #fff !important;
}

.phone-call-action.is-active::before {
  background: rgba(255, 255, 255, 0.24);
}

.phone-call-action.is-disabled {
  color: rgba(255, 255, 255, 0.38) !important;
  opacity: 1 !important;
}

.phone-call-action.is-disabled > span {
  color: rgba(255, 255, 255, 0.38);
}

.phone-call-action--end::before {
  border-color: rgba(255, 186, 181, 0.72);
  background: #d92d22;
}

.phone-call-action--answer::before {
  border-color: rgba(190, 255, 198, 0.72);
  background: #34a853;
}

.phone-call-more {
  display: flex;
  min-height: 0;
  flex: 1;
  align-items: flex-end;
  padding: 0 34px 34px;
}

.phone-call-more__list {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 9px;
}

.phone-call-more__item {
  display: flex !important;
  width: 100% !important;
  height: 58px !important;
  align-items: center !important;
  justify-content: flex-start !important;
  gap: 13px !important;
  padding: 0 27px !important;
  border: 1px solid var(--sky-hairline) !important;
  border-radius: 30px !important;
  background: var(--sky-glass) !important;
  color: white !important;
  box-shadow: var(--sky-shadow-glass) !important;
  text-transform: none !important;
}

.phone-call-more__item:active {
  background: var(--sky-glass) !important;
}

.phone-call-more__contact-card {
  height: 72px !important;
  padding: 0 33px !important;
  border-radius: 38px !important;
}

.phone-call-more__item > svg {
  width: 24px;
  height: 24px;
  flex: none;
}

.phone-call-more__item--danger {
  color: #ff6961 !important;
}

.phone-call-more__avatar {
  display: grid;
  width: 45px;
  height: 45px;
  flex: none;
  place-items: center;
  border-radius: 50%;
  background: linear-gradient(145deg, #636366, #2c2c2e);
  font-size: 17px;
  font-weight: 700;
}

.phone-call-more__avatar svg {
  width: 24px;
  height: 24px;
}

.phone-call-more__item strong {
  overflow: hidden;
  font-size: 16px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-in-call-keypad {
  display: flex;
  min-height: 0;
  flex: 1;
  flex-direction: column;
  padding: 0 28px 42px;
}

.phone-in-call-keypad__grid {
  display: grid;
  grid-template-columns: repeat(3, 74px);
  justify-content: center;
  gap: 18px 40px;
  margin-top: auto;
}

.phone-in-call-keypad__grid button {
  display: flex;
  width: 74px;
  height: 74px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--sky-hairline);
  border-radius: 50%;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  backdrop-filter: blur(18px) saturate(145%);
  -webkit-backdrop-filter: blur(18px) saturate(145%);
  color: white;
  transition:
    background-color 120ms ease,
    border-color 120ms ease,
    box-shadow 120ms ease,
    transform 120ms ease;
}

.phone-in-call-keypad__grid button:active {
  background: rgba(255, 255, 255, 0.24);
  transform: scale(0.95);
}

.phone-in-call-keypad__grid span {
  font-size: 32px;
  line-height: 31px;
}

.phone-in-call-keypad__grid small {
  min-height: 10px;
  margin-top: 2px;
  font-size: 8px;
  font-weight: 800;
  letter-spacing: 1.5px;
}

.phone-in-call-keypad__footer {
  display: grid;
  grid-template-columns: repeat(3, 74px);
  align-items: center;
  justify-content: center;
  gap: 40px;
  margin-top: 42px;
}

.phone-in-call-keypad__end {
  grid-column: 2;
  width: 74px !important;
  height: 74px !important;
  padding: 0 !important;
  border: 1px solid rgba(255, 178, 172, 0.78) !important;
  border-radius: 50% !important;
  background: #cf3027 !important;
  color: white !important;
}

.phone-in-call-keypad__end svg {
  width: 30px;
  height: 30px;
}

.phone-in-call-keypad__hide {
  grid-column: 3;
  width: 96px !important;
  margin-left: -11px;
  padding: 0 !important;
  color: white !important;
  font-size: 14px !important;
  font-weight: 400 !important;
  line-height: 18px !important;
  text-align: left;
  white-space: normal !important;
}

@media (max-height: 700px) {
  .phone-active-call__identity {
    padding-top: 86px;
  }

  .phone-active-call__actions {
    gap: 4px 15px;
    padding-bottom: 28px;
  }

  .phone-call-action {
    height: 97px !important;
    padding-top: 20px !important;
  }

  .phone-call-action-anchor {
    height: 97px;
  }

  .phone-call-action::before {
    width: 70px;
    height: 70px;
  }

  .phone-call-action > svg {
    width: 29px;
    height: 29px;
  }

  .phone-call-action > span {
    top: 79px;
  }

  .phone-in-call-keypad {
    padding-bottom: 24px;
  }

  .phone-in-call-keypad__grid {
    grid-template-columns: repeat(3, 64px);
    gap: 10px 34px;
  }

  .phone-in-call-keypad__grid button {
    width: 64px;
    height: 64px;
  }

  .phone-in-call-keypad__footer {
    grid-template-columns: repeat(3, 64px);
    gap: 34px;
    margin-top: 20px;
  }

  .phone-in-call-keypad__end {
    width: 64px !important;
    height: 64px !important;
  }
}

.phone-call-content {
  min-height: 0;
}

.phone-bottom-tabbar {
  --sky-app-accent: #ffffff;
}

.phone-recents,
.phone-contacts,
.phone-contact-detail {
  min-height: 100%;
  padding: 8px 15px
    calc(var(--sky-tabbar-height) + var(--sky-safe-area-bottom) + 16px);
}

.phone-contacts {
  position: relative;
  padding-top: 6px;
  padding-right: 24px;
}

.phone-contacts-header {
  padding-bottom: 16px;
}

.phone-contacts-toolbar {
  display: grid;
  grid-template-columns: 42px 1fr 42px;
  align-items: center;
  margin-bottom: 13px;
}

.phone-contacts-toolbar h1 {
  margin: 0;
  font-size: 17px;
  text-align: center;
}

.phone-contacts-add {
  display: flex;
  width: 42px;
  height: 42px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--sky-hairline);
  border-radius: 50%;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  color: inherit;
}

.phone-contacts-search {
  display: flex;
  min-height: 42px;
  align-items: center;
  gap: 9px;
  padding: 0 14px;
  border-radius: 16px;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  color: #8e8e93;
}

.phone-contacts-search input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  font-size: 16px;
}

.phone-my-card {
  display: flex;
  width: 100%;
  min-height: 72px;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
}

.phone-my-card > span {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.phone-my-card strong {
  font-size: 16px;
}

.phone-my-card small {
  margin-top: 2px;
  color: #8e8e93;
  font-size: 12px;
}

.phone-contact-group {
  scroll-margin-top: 10px;
}

.phone-contact-group h2 {
  height: 28px;
  margin: 0;
  padding-top: 4px;
  border-bottom: 1px solid rgba(142, 142, 147, 0.23);
  color: #8e8e93;
  font-size: 13px;
  font-weight: 500;
}

.phone-contact-group--favorites h2 {
  display: flex;
  align-items: flex-start;
  gap: 5px;
  color: #d1d1d6;
}

.phone-contact-row {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr);
  width: 100%;
  min-height: 68px;
  align-items: center;
  gap: 10px;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
}

.phone-contact-row:not(:last-child) .phone-contact-name {
  border-bottom: 1px solid rgba(142, 142, 147, 0.2);
}

.phone-contact-name {
  display: flex;
  min-width: 0;
  min-height: 68px;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  gap: 2px;
  overflow: hidden;
  font-size: 16px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-contact-name small {
  color: #8e8e93;
  font-size: 10px;
  font-weight: 500;
}

.phone-contact-index {
  position: fixed;
  z-index: 40;
  top: 50%;
  right: 5px;
  display: flex;
  flex-direction: column;
  pointer-events: auto;
  transform: translateY(-42%);
}

.phone-contact-index button {
  width: 24px;
  height: 14px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #d1d1d6;
  font: inherit;
  font-size: 9px;
  font-weight: 700;
  line-height: 14px;
  cursor: pointer;
  touch-action: manipulation;
}

.phone-contact-index button svg {
  display: block;
  margin: auto;
}

.phone-contact-index button:active {
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.12);
}

.phone-keypad {
  position: relative;
  display: flex;
  min-height: 100%;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  padding: 56px 24px
    calc(var(--sky-tabbar-height) + var(--sky-safe-area-bottom) + 16px);
}

.phone-keypad-number {
  display: flex;
  width: 100%;
  min-height: 50px;
  align-items: center;
  justify-content: center;
  margin-bottom: 14px;
  overflow: hidden;
  font-size: 25px;
  font-weight: 500;
  letter-spacing: 0.4px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-keypad-suggestions {
  position: absolute;
  z-index: 5;
  top: 18px;
  right: 24px;
  left: 24px;
  display: grid;
  width: auto;
  max-height: 132px;
  gap: 6px;
  margin: 0 auto;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
  touch-action: pan-y;
  -webkit-overflow-scrolling: touch;
}

.phone-keypad-suggestions::-webkit-scrollbar {
  display: none;
}

.phone-keypad-suggestion {
  display: grid;
  min-height: 46px;
  grid-template-columns: 36px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  padding: 5px 12px 5px 6px;
  border: 1px solid var(--sky-hairline);
  border-radius: 18px;
  color: #fff;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  font: inherit;
  text-align: left;
  backdrop-filter: blur(16px) saturate(140%);
  -webkit-backdrop-filter: blur(16px) saturate(140%);
  transition:
    background-color 160ms ease-out,
    border-color 160ms ease-out,
    transform 160ms ease-out;
}

.phone-keypad-suggestion__avatar {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 50%;
  background: linear-gradient(145deg, #636366, #2c2c2e);
  font-size: 12px;
  font-weight: 700;
}

.phone-keypad-suggestion__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.phone-keypad-suggestion__copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.phone-keypad-suggestion__copy strong,
.phone-keypad-suggestion__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-keypad-suggestion__copy strong {
  font-size: 14px;
  font-weight: 600;
  transition: color 160ms ease-out;
}

.phone-keypad-suggestion__copy small {
  margin-top: 1px;
  color: #a5a5aa;
  font-size: 11px;
}

.keypad-suggestions-enter-active,
.keypad-suggestions-leave-active {
  transition:
    opacity 180ms ease,
    transform 220ms cubic-bezier(0.22, 1, 0.36, 1);
}

.keypad-suggestions-enter-from,
.keypad-suggestions-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

.phone-keypad-grid {
  display: grid;
  grid-template-columns: repeat(3, 78px);
  gap: 18px 22px;
}

.phone-keypad-key {
  display: flex;
  width: 78px;
  height: 78px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0;
  border: 1px solid var(--sky-hairline);
  border-radius: 50%;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  backdrop-filter: blur(18px) saturate(145%);
  -webkit-backdrop-filter: blur(18px) saturate(145%);
  color: white;
  font: inherit;
  transition:
    background-color 120ms ease,
    border-color 120ms ease,
    box-shadow 120ms ease,
    transform 120ms ease;
}

.phone-keypad-key:active {
  background: #3a3a3c;
  transform: scale(0.96);
}

.phone-keypad-key > span {
  font-size: 36px;
  font-weight: 400;
  line-height: 34px;
}

.phone-keypad-key > small {
  min-height: 13px;
  margin-top: 3px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 2.4px;
  line-height: 10px;
}

.phone-keypad-key > small.phone-keypad-plus {
  font-size: 15px;
  letter-spacing: 0;
}

.phone-keypad-actions {
  position: relative;
  display: flex;
  width: 100%;
  min-height: 82px;
  align-items: center;
  justify-content: center;
  margin-top: 20px;
}

.phone-keypad-call,
.phone-keypad-delete {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  border: 0;
  border-radius: 50%;
  color: white;
}

.phone-keypad-call {
  width: 78px;
  height: 78px;
  border: 1px solid rgba(133, 235, 143, 0.78);
  background: linear-gradient(180deg, #3e9a49, #2f7d39);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.2),
    0 5px 14px rgba(23, 101, 35, 0.3);
}

.phone-keypad-call:active {
  background: #2d7336;
  transform: scale(0.96);
}

.phone-keypad-delete {
  position: absolute;
  left: calc(50% + 62px);
  width: 48px;
  height: 48px;
  border: 1px solid var(--sky-hairline);
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  backdrop-filter: blur(18px) saturate(145%);
  -webkit-backdrop-filter: blur(18px) saturate(145%);
  color: #d1d1d6;
}

.phone-keypad-delete:active {
  background: #3a3a3c;
  transform: scale(0.96);
}

@media (max-height: 690px) {
  .phone-keypad {
    padding-top: 20px;
    padding-bottom: calc(
      var(--sky-tabbar-height) + var(--sky-safe-area-bottom) + 8px
    );
  }

  .phone-keypad-suggestions {
    top: 6px;
    max-height: 104px;
  }

  .phone-keypad-grid {
    grid-template-columns: repeat(3, 70px);
    gap: 12px 18px;
  }

  .phone-keypad-key {
    width: 70px;
    height: 70px;
  }

  .phone-keypad-actions {
    min-height: 70px;
    margin-top: 14px;
  }

  .phone-keypad-suggestion:nth-child(n + 2) {
    display: none;
  }

  .phone-keypad-call {
    width: 68px;
    height: 68px;
  }
}

.phone-recents-header {
  padding: 4px 0 14px;
}

.phone-recents-filter {
  width: 174px;
  margin: 0 auto 14px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
}

.phone-recents-filter :deep(.sky-segmented-button) {
  border-radius: var(--sky-radius-pill);
  color: #8e8e93;
  font-size: 13px;
  font-weight: 600;
  line-height: 1;
}

.phone-recents-filter :deep(.sky-segmented-button--active) {
  color: var(--sky-text);
}

.phone-recents-filter :deep(.sky-segmented__highlight) {
  top: 4px;
  bottom: 4px;
  background: var(--sky-tabbar-highlight-background);
  box-shadow: none;
}

.phone-recents-header h1 {
  margin: 0 0 13px;
  font-size: 30px;
  line-height: 1.06;
  letter-spacing: -0.8px;
}

.phone-recents-search {
  display: flex;
  align-items: center;
  gap: 9px;
  min-height: 42px;
  padding: 0 14px;
  border-radius: 16px;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  color: #8e8e93;
}

.phone-recents-search input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  font-size: 16px;
}

.phone-recents-list {
  overflow: hidden;
}

.phone-recent-row {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr) auto 44px;
  align-items: center;
  min-height: 76px;
  column-gap: 10px;
}

.phone-recent-row:not(:last-child) {
  border-bottom: 1px solid rgba(142, 142, 147, 0.2);
}

.phone-contact-avatar {
  display: flex;
  width: 52px;
  height: 52px;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  border-radius: 50%;
  background: linear-gradient(145deg, #636366, #2c2c2e);
  color: white;
  font-size: 19px;
  font-weight: 700;
  letter-spacing: -0.4px;
  overflow: hidden;
}

.phone-contact-avatar img,
.phone-contact-editor__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.phone-recent-call {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  align-self: stretch;
  border: 0;
  background: transparent;
  color: inherit;
  text-align: left;
}

.phone-recent-name {
  overflow: hidden;
  max-width: 100%;
  font-size: 16px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-recent-name--missed {
  color: #ff453a;
}

.phone-recent-meta {
  display: flex;
  align-items: center;
  gap: 3px;
  overflow: hidden;
  max-width: 100%;
  margin-top: 2px;
  color: #8e8e93;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-recent-date {
  color: #8e8e93;
  font-size: 12px;
  white-space: nowrap;
}

.phone-recent-info {
  display: flex;
  width: 44px;
  height: 44px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 50%;
  background: rgba(118, 118, 128, 0.14);
  color: #d1d1d6;
}

.phone-detail-header {
  display: flex;
  min-height: 38px;
  align-items: center;
}

.phone-detail-back {
  display: flex;
  align-items: center;
  padding: 0;
  border: 0;
  background: transparent;
  color: #fff;
  font: inherit;
  font-size: 15px;
}

.phone-contact-hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 6px 0 22px;
  text-align: center;
}

.phone-contact-avatar--large {
  width: 92px;
  height: 92px;
  font-size: 32px;
}

.phone-contact-hero h2 {
  max-width: 100%;
  margin: 12px 0 2px;
  overflow: hidden;
  font-size: 24px;
  letter-spacing: -0.45px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-contact-hero p {
  margin: 0;
  color: #8e8e93;
  font-size: 14px;
}

.phone-contact-hero .phone-contact-organization {
  margin-top: 2px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 15px;
  font-weight: 500;
}

.phone-contact-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  width: 100%;
  margin-top: 20px;
}

.phone-contact-actions button {
  display: flex;
  min-width: 0;
  min-height: 70px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  border: 0;
  border-radius: 14px;
  background: rgba(118, 118, 128, 0.15);
  color: #fff;
  font: inherit;
  font-size: 12px;
}

.phone-contact-actions button > span {
  display: flex;
  min-height: 25px;
  align-items: center;
}

.phone-own-profile-card {
  overflow: hidden;
  border-radius: 16px;
  background: rgba(118, 118, 128, 0.12);
}

.phone-own-profile-card > div {
  display: grid;
  grid-template-columns: 32px minmax(0, 1fr);
  min-height: 62px;
  align-items: center;
  gap: 8px;
  margin-left: 14px;
  padding-right: 14px;
}

.phone-own-profile-card > div:not(:last-child) {
  border-bottom: 1px solid rgba(142, 142, 147, 0.2);
}

.phone-own-profile-card > div > span {
  display: flex;
  width: 30px;
  height: 30px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.14);
  color: white;
}

.phone-own-profile-card p {
  display: flex;
  min-width: 0;
  flex-direction: column;
  margin: 0;
}

.phone-own-profile-card small {
  color: #8e8e93;
  font-size: 11px;
}

.phone-own-profile-card strong {
  overflow: hidden;
  margin-top: 2px;
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-history-card {
  overflow: hidden;
  border-radius: 16px;
  background: rgba(118, 118, 128, 0.12);
}

.phone-history-card h3 {
  margin: 0;
  padding: 13px 14px 10px;
  font-size: 15px;
}

.phone-history-row {
  display: grid;
  grid-template-columns: 26px minmax(0, 1fr) auto;
  align-items: center;
  min-height: 58px;
  gap: 8px;
  margin-left: 14px;
  padding-right: 14px;
  border-top: 1px solid rgba(142, 142, 147, 0.2);
}

.phone-history-direction {
  color: #d1d1d6;
}

.phone-history-direction--missed {
  color: #ff453a;
}

.phone-history-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.phone-history-copy strong {
  font-size: 14px;
}

.phone-history-copy small,
.phone-history-row time,
.phone-history-empty {
  color: #8e8e93;
  font-size: 11px;
}

.phone-history-row time {
  white-space: nowrap;
}

.phone-history-empty {
  margin: 0;
  padding: 18px 14px;
  text-align: center;
}

.phone-call-content--profile {
  background: transparent;
  color: #fff;
  scroll-behavior: smooth;
}

.phone-calls-app--profile {
  background: linear-gradient(
    180deg,
    #6e6e73 0,
    #3a3a3c 18%,
    #1c1c1e 55%,
    #000000 100%
  ) !important;
  color: #fff;
}

.phone-contact-detail {
  position: relative;
  padding: 0 15px 112px;
}

.phone-detail-header {
  position: sticky;
  z-index: 12;
  top: 0;
  display: grid;
  height: 58px;
  grid-template-columns: 48px minmax(0, 1fr) minmax(48px, auto);
  align-items: start;
  gap: 8px;
  margin: 0 -15px;
  padding: 7px 15px;
  overflow: visible;
}

.phone-detail-header-button,
.phone-detail-edit {
  min-width: 0;
  height: 44px;
  padding: 0;
  border: 1px solid var(--sky-hairline);
  color: #fff;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
}

.phone-detail-header-button {
  width: 44px;
}

.phone-detail-edit {
  justify-self: end;
  width: auto;
  min-width: 86px;
  padding: 0 17px;
  font-size: 16px;
  font-weight: 500;
}

.phone-detail-edit-spacer {
  width: 44px;
}

.phone-detail-header-spacer {
  min-width: 0;
}

.phone-contact-hero {
  padding: 31px 0 19px;
}

.phone-contact-avatar--large {
  width: 148px;
  height: 148px;
  border: 1px solid rgba(255, 255, 255, 0.28);
  background: linear-gradient(
    155deg,
    rgba(174, 174, 178, 0.72),
    rgba(72, 72, 74, 0.72)
  );
  box-shadow:
    inset 0 1px 2px rgba(255, 255, 255, 0.38),
    0 2px 3px rgba(0, 0, 0, 0.28);
  font-size: 64px;
  font-weight: 400;
}

.phone-contact-hero h2 {
  margin: 14px 0 0;
  color: #fff;
  font-size: 29px;
  font-weight: 700;
  letter-spacing: -0.65px;
}

.phone-contact-actions {
  display: grid;
  width: 100%;
  grid-template-columns: repeat(4, 62px);
  justify-content: center;
  gap: 12px;
  margin-top: 22px;
}

.phone-profile-action {
  --phone-profile-action-size: 62px;
  box-sizing: border-box !important;
  width: var(--phone-profile-action-size) !important;
  min-width: var(--phone-profile-action-size) !important;
  max-width: var(--phone-profile-action-size) !important;
  height: var(--phone-profile-action-size) !important;
  min-height: var(--phone-profile-action-size) !important;
  max-height: var(--phone-profile-action-size) !important;
  aspect-ratio: 1 / 1;
  flex: 0 0 var(--phone-profile-action-size) !important;
  align-self: center;
  justify-self: center;
  padding: 0;
  border: 1px solid var(--sky-hairline);
  border-radius: 50% !important;
  overflow: hidden;
  color: #fff !important;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
}

.phone-profile-action :deep(svg) {
  color: inherit;
}

.phone-profile-action:disabled {
  color: rgba(255, 255, 255, 0.32) !important;
  opacity: 1;
}

.phone-profile-content {
  display: grid;
  gap: 12px;
}

.phone-profile-card,
.phone-own-profile-card,
.phone-history-card {
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.035);
  border-radius: 24px;
  color: #fff;
  background: rgba(28, 28, 30, 0.8);
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.18);
  backdrop-filter: blur(20px) saturate(125%);
  -webkit-backdrop-filter: blur(20px) saturate(125%);
}

.phone-profile-info-card > button,
.phone-profile-options-card > button,
.phone-profile-single-option > button {
  display: flex;
  width: calc(100% - 30px);
  min-height: 66px;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin: 0 15px;
  padding: 0;
  border: 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.17);
  color: inherit;
  background: transparent;
  font: inherit;
  text-align: left;
}

.phone-profile-info-card > button:last-of-type,
.phone-profile-options-card > button:last-child,
.phone-profile-single-option > button:last-child {
  border-bottom: 0;
}

.phone-profile-info-card > button > span {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.phone-profile-info-card small {
  color: #a7a7ac;
  font-size: 13px;
}

.phone-profile-info-card strong {
  margin-top: 2px;
  overflow: hidden;
  font-size: 15px;
  font-weight: 400;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.phone-profile-info-card > button > svg {
  flex: none;
  color: #fff;
  transition:
    color 160ms ease-out,
    filter 160ms ease-out,
    transform 160ms ease-out;
}

.phone-profile-notes {
  min-height: 105px;
  margin: 0 15px;
  padding: 17px 0;
  border-top: 1px solid rgba(255, 255, 255, 0.17);
  font-size: 15px;
}

.phone-profile-notes > span {
  display: block;
  color: #fff;
}

.phone-profile-notes > p {
  margin: 8px 0 0;
  color: rgba(255, 255, 255, 0.72);
  line-height: 1.4;
  overflow-wrap: anywhere;
  white-space: pre-wrap;
}

.phone-profile-options-card > button,
.phone-profile-single-option > button {
  min-height: 54px;
  font-size: 15px;
}

.phone-profile-options-card > button > span,
.phone-profile-single-option > button > span {
  transition:
    color 160ms ease-out,
    transform 160ms ease-out;
}

.phone-profile-options-card > button:disabled,
.phone-profile-single-option > button:disabled {
  color: inherit;
  opacity: 1;
}

.phone-history-card h3 {
  padding: 15px 16px 11px;
  color: #fff;
}

.phone-history-row {
  margin-left: 15px;
  padding-right: 15px;
  border-top-color: rgba(255, 255, 255, 0.17);
}

.phone-history-copy small,
.phone-history-row time,
.phone-history-empty {
  color: rgba(255, 255, 255, 0.62);
}

.phone-contact-editor-sheet :deep(.sky-sheet__panel) {
  width: 100%;
  height: calc(100% - 52px);
  max-height: calc(100% - 52px);
  border-radius: 30px 30px 0 0;
  background: #3a3a3c;
  box-shadow: 0 -10px 35px rgba(0, 0, 0, 0.28);
}

.phone-contact-editor {
  position: relative;
  display: flex;
  height: 100%;
  min-height: 0;
  flex-direction: column;
  overflow: hidden;
  border-radius: inherit;
  color: #fff;
  background: #3a3a3c;
}

.phone-contact-editor::before {
  position: absolute;
  z-index: 3;
  top: 7px;
  left: 50%;
  width: 44px;
  height: 5px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.38);
  content: '';
  transform: translateX(-50%);
}

.phone-contact-editor__header {
  position: relative;
  z-index: 2;
  display: grid;
  height: 78px;
  padding: 18px 18px 6px;
  grid-template-columns: 52px 1fr 52px;
  align-items: center;
  flex: 0 0 78px;
  background: linear-gradient(180deg, #3a3a3c 72%, rgba(58, 58, 60, 0));
}

.phone-contact-editor__header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  text-align: center;
}

.phone-contact-editor__header-button {
  width: 46px;
  min-width: 46px;
  height: 46px;
  min-height: 46px;
  padding: 0;
  border: 1px solid var(--sky-hairline);
  color: #fff;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
}

.phone-contact-editor__header-button:last-child {
  justify-self: end;
  background: var(--sky-glass);
}

.phone-contact-editor__scroll {
  min-height: 0;
  flex: 1;
  padding: 2px 14px 42px;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
  touch-action: pan-y;
  -webkit-overflow-scrolling: touch;
}

.phone-contact-editor__scroll::-webkit-scrollbar {
  display: none;
}

.phone-contact-editor__avatar {
  display: grid;
  width: 154px;
  height: 154px;
  margin: 0;
  padding: 0;
  place-items: center;
  border: 1px solid rgba(255, 255, 255, 0.11);
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(155deg, #636366 0%, #2c2c2e 100%);
  box-shadow:
    inset 0 1px 1px rgba(255, 255, 255, 0.16),
    0 8px 18px rgba(0, 0, 0, 0.28);
  cursor: pointer;
  overflow: hidden;
}

.phone-contact-editor__avatar-wrap {
  position: relative;
  width: 154px;
  height: 154px;
  margin: 4px auto 12px;
  border-radius: 50%;
}

.phone-contact-editor__remove-photo {
  position: absolute !important;
  z-index: 2;
  inset: 0;
  display: flex !important;
  width: 100% !important;
  height: 100% !important;
  flex-direction: column !important;
  gap: 7px !important;
  padding: 0 !important;
  border: 0 !important;
  border-radius: 50% !important;
  color: #fff !important;
  background: rgba(28, 28, 30, 0.78) !important;
  opacity: 0;
  pointer-events: none;
  transform: scale(0.96);
  transition:
    opacity 170ms ease,
    transform 170ms ease !important;
}

.phone-contact-editor__remove-photo > span {
  font-size: 13px;
  font-weight: 600;
}

.phone-contact-editor__avatar-wrap--has-photo:hover
  .phone-contact-editor__remove-photo,
.phone-contact-editor__remove-photo:focus-visible {
  opacity: 1;
  pointer-events: auto;
  transform: scale(1);
}

.phone-contact-editor__avatar img {
  transition:
    filter 170ms ease,
    transform 170ms ease;
}

.phone-contact-editor__avatar-wrap--has-photo:hover
  .phone-contact-editor__avatar
  img {
  filter: brightness(0.58);
  transform: scale(1.015);
}

.phone-contact-editor__avatar span {
  font-size: 53px;
  font-weight: 600;
  letter-spacing: -2px;
}

.phone-contact-editor__photo {
  margin-bottom: 22px;
  text-align: center;
}

.phone-contact-editor__photo-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
}

.phone-contact-editor__photo-actions :deep(button) {
  display: flex;
  align-items: center;
  gap: 6px;
  min-height: 34px;
  padding-inline: 16px;
  color: #d1d1d6;
}

.phone-contact-editor__name-list,
.phone-contact-editor__number-list,
.phone-contact-editor__notes-list {
  margin: 0 0 16px;
  color: #fff;
}

.phone-contact-editor__name-list :deep(ul),
.phone-contact-editor__number-list :deep(ul),
.phone-contact-editor__notes-list :deep(ul) {
  overflow: hidden;
  border-radius: 24px;
  background: #2c2c2e;
}

.phone-contact-editor__name-list :deep(li),
.phone-contact-editor__number-list :deep(li),
.phone-contact-editor__notes-list :deep(li) {
  min-height: 58px;
  background: transparent;
}

.phone-contact-editor__name-list :deep(input),
.phone-contact-editor__number-list :deep(input),
.phone-contact-editor__notes-list :deep(textarea) {
  color: #fff;
  font-size: 17px;
}

.phone-contact-editor__name-list :deep(input::placeholder),
.phone-contact-editor__number-list :deep(input::placeholder),
.phone-contact-editor__notes-list :deep(textarea::placeholder) {
  color: #a7a7ac;
  opacity: 1;
}

.phone-contact-editor__notes-list :deep(textarea) {
  min-height: 112px;
  resize: none;
  line-height: 1.35;
}

.phone-contact-editor__add-icon {
  display: grid;
  width: 25px;
  height: 25px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #30d158;
}

.phone-contact-editor__error {
  margin: -4px 14px 16px;
  color: #ff6961;
  font-size: 13px;
  text-align: center;
}

.phone-contact-editor__delete {
  width: 100%;
  min-height: 56px;
  border-radius: 22px;
  color: #ff453a;
  background: #2c2c2e;
  font-size: 16px;
}

.phone-contact-editor--light {
  color: #111;
  background: #e5e5ea;
}

.phone-contact-editor--light .phone-contact-editor__header {
  background: linear-gradient(180deg, #e5e5ea 72%, rgba(229, 229, 234, 0));
}

.phone-contact-editor--light .phone-contact-editor__header-button {
  border-color: var(--sky-hairline);
  color: #111;
  background: var(--sky-glass);
}

.phone-contact-editor--light .phone-contact-editor__name-list,
.phone-contact-editor--light .phone-contact-editor__number-list,
.phone-contact-editor--light .phone-contact-editor__notes-list {
  color: #111;
}

.phone-contact-editor--light .phone-contact-editor__name-list :deep(ul),
.phone-contact-editor--light .phone-contact-editor__number-list :deep(ul),
.phone-contact-editor--light .phone-contact-editor__notes-list :deep(ul),
.phone-contact-editor--light .phone-contact-editor__delete {
  background: rgba(255, 255, 255, 0.72);
}

.phone-contact-editor--light .phone-contact-editor__name-list :deep(input),
.phone-contact-editor--light .phone-contact-editor__number-list :deep(input),
.phone-contact-editor--light .phone-contact-editor__notes-list :deep(textarea) {
  color: #111;
}

@media (max-width: 360px) {
  .phone-detail-header {
    grid-template-columns: 44px minmax(0, 1fr) minmax(44px, auto);
    gap: 5px;
  }

  .phone-detail-edit {
    min-width: 74px;
    padding: 0 12px;
    font-size: 14px;
  }

  .phone-contact-actions {
    grid-template-columns: repeat(4, 56px);
    gap: 9px;
  }

  .phone-profile-action {
    --phone-profile-action-size: 56px;
  }
}

.phone-calls-app button:not(:disabled),
.phone-contact-editor button:not(:disabled) {
  cursor: pointer;
}

.phone-recents-filter :deep(.sky-segmented-button),
.phone-recents-search,
.phone-contacts-search,
.phone-recent-row,
.phone-recent-info,
.phone-contacts-add,
.phone-my-card,
.phone-contact-row,
.phone-contact-index button,
.phone-keypad-call,
.phone-profile-action,
.phone-detail-header-button,
.phone-detail-edit,
.phone-profile-info-card > button,
.phone-profile-options-card > button,
.phone-profile-single-option > button,
.phone-call-more__item,
.phone-contact-editor__avatar,
.phone-contact-editor__header-button,
.phone-contact-editor__delete,
.phone-contact-editor__photo-actions :deep(button) {
  transition:
    color 160ms ease-out,
    background-color 160ms ease-out,
    border-color 160ms ease-out,
    box-shadow 160ms ease-out,
    filter 160ms ease-out,
    transform 160ms ease-out;
}

.phone-calls-app button:focus-visible,
.phone-contact-editor button:focus-visible {
  outline: 2px solid #fff;
  outline-offset: 2px;
}

.phone-keypad-key:hover,
.phone-keypad-delete:hover {
  border-color: rgba(255, 255, 255, 0.14);
  background: linear-gradient(
    180deg,
    rgba(68, 68, 70, 0.94),
    rgba(38, 38, 40, 0.9)
  );
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.08),
    0 3px 9px rgba(0, 0, 0, 0.2);
  transform: translateY(-1px);
}

.phone-keypad-call:hover {
  border-color: rgba(151, 245, 161, 0.9);
  background: linear-gradient(180deg, #48aa54, #378c42);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.26),
    0 6px 16px rgba(52, 199, 89, 0.3);
  transform: translateY(-2px) scale(1.015);
}

.phone-in-call-keypad__grid button:hover {
  border-color: rgba(255, 255, 255, 0.22);
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.2),
    rgba(255, 255, 255, 0.12)
  );
  box-shadow: 0 3px 9px rgba(0, 0, 0, 0.22);
  transform: translateY(-1px);
}

@media (hover: hover) and (pointer: fine) {
  .phone-keypad-suggestion:hover .phone-keypad-suggestion__copy strong {
    color: #fff;
  }

  .phone-recents-filter
    :deep(.sky-segmented-button:not(.sky-segmented-button--active):hover) {
    background: rgba(118, 118, 128, 0.22);
  }

  .phone-recents-search:hover,
  .phone-contacts-search:hover {
    background: var(--sky-glass);
    box-shadow: var(--sky-shadow-glass);
  }

  .phone-recent-row:hover,
  .phone-my-card:hover,
  .phone-contact-row:hover {
    border-radius: 14px;
    background: rgba(118, 118, 128, 0.12);
    box-shadow: inset 0 0 0 1px rgba(142, 142, 147, 0.08);
  }

  .phone-recent-info:hover,
  .phone-contacts-add:hover,
  .phone-contact-index button:hover {
    background: rgba(255, 255, 255, 0.14);
    color: #fff;
    transform: translateY(-1px);
  }

  .phone-call-action:not(:disabled):not(.phone-call-action--end):not(
      .phone-call-action--answer
    ):hover::before {
    background: rgba(255, 255, 255, 0.22);
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.12),
      0 4px 12px rgba(0, 0, 0, 0.22);
    transform: translateX(-50%) translateY(-1px) scale(1.012);
  }

  .phone-call-action--end:not(:disabled):hover::before {
    border-color: rgba(255, 190, 185, 0.92);
    background: #ff3b30;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.2),
      0 5px 14px rgba(215, 45, 34, 0.34);
    transform: translateX(-50%) translateY(-1px) scale(1.012);
  }

  .phone-call-action--answer:not(:disabled):hover::before {
    border-color: rgba(190, 255, 198, 0.9);
    background: #3bc45d;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.2),
      0 5px 14px rgba(52, 168, 83, 0.3);
    transform: translateX(-50%) translateY(-1px) scale(1.012);
  }

  .phone-call-more__item:not(:disabled):hover {
    border-color: var(--sky-hairline) !important;
    background: var(--sky-glass) !important;
    transform: translateY(-1px);
  }

  .phone-detail-header-button:not(:disabled):hover,
  .phone-detail-edit:not(:disabled):hover {
    border-color: var(--sky-hairline);
    background: var(--sky-glass);
    transform: translateY(-1px);
  }

  .phone-profile-action:not(:disabled):hover {
    border-color: var(--sky-hairline);
    background: var(--sky-glass);
    box-shadow: var(--sky-shadow-glass);
    transform: translateY(-1px);
  }

  .phone-profile-options-card > button:not(:disabled):hover > span,
  .phone-profile-single-option > button:not(:disabled):hover > span {
    color: #fff;
    transform: translateX(2px);
  }

  .phone-profile-info-card > button:not(:disabled):hover > svg {
    color: #fff;
    filter: brightness(1.08);
    transform: translateX(1px);
  }

  .phone-contact-editor__avatar-wrap:not(
      .phone-contact-editor__avatar-wrap--has-photo
    ):hover
    .phone-contact-editor__avatar {
    border-color: rgba(255, 255, 255, 0.22);
    filter: brightness(1.06);
    transform: scale(1.012);
  }

  .phone-contact-editor__header-button:not(:disabled):hover,
  .phone-contact-editor__photo-actions :deep(button:not(:disabled):hover) {
    filter: brightness(1.08);
    transform: translateY(-1px);
  }

  .phone-contact-editor__delete:not(:disabled):hover {
    background: #38383a;
  }

  .phone-calls-app :deep([data-active-tab] button[aria-pressed='false']:hover) {
    background: rgba(118, 118, 128, 0.14);
    transform: translateY(-1px);
  }
}

@media (hover: none) {
  .phone-contact-editor__remove-photo {
    inset: auto 5px 5px auto;
    width: 44px !important;
    height: 44px !important;
    background: rgba(28, 28, 30, 0.9) !important;
    opacity: 1;
    pointer-events: auto;
    transform: none;
  }

  .phone-contact-editor__remove-photo > span {
    display: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .phone-detail-header,
  .phone-calls-app button,
  .phone-contact-editor button {
    transition-duration: 1ms;
    transition-delay: 0ms;
  }
}

.phone-app--light .phone-recents-filter,
.phone-app--light .phone-recents-search,
.phone-app--light .phone-contacts-add,
.phone-app--light .phone-contacts-search,
.phone-app--light .phone-recent-info,
.phone-app--light .phone-contact-actions button,
.phone-app--light .phone-own-profile-card,
.phone-app--light .phone-history-card {
  background: var(--sky-glass);
}

.phone-app--light .phone-bottom-tabbar {
  --sky-app-accent: #3a3a3c;
}

.phone-app--light .phone-contact-index button,
.phone-app--light .phone-recent-info,
.phone-app--light .phone-history-direction {
  color: #3a3a3c;
}

.phone-contact-editor--light
  .phone-contact-editor__photo-actions
  :deep(button) {
  color: #3a3a3c;
}

.phone-app--light .phone-keypad-suggestion {
  border-color: var(--sky-hairline);
  color: #111;
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
}

.phone-app--light .phone-keypad-suggestion__copy small {
  color: #6e6e73;
}

.phone-app--light .phone-keypad-key,
.phone-app--light .phone-keypad-delete {
  border-color: var(--sky-hairline);
  background: var(--sky-glass);
  box-shadow: var(--sky-shadow-glass);
  color: #000;
}

.phone-app--light .phone-keypad-key:active,
.phone-app--light .phone-keypad-delete:active {
  background: #d1d1d6;
}

.phone-app--light .phone-keypad-key:hover,
.phone-app--light .phone-keypad-delete:hover {
  border-color: rgba(60, 60, 67, 0.12);
  background: linear-gradient(
    180deg,
    rgba(248, 248, 250, 0.94),
    rgba(222, 222, 227, 0.9)
  );
}
</style>
