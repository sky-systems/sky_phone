<script setup lang="ts">
import {
  kBlock,
  kButton,
  kDialog,
  kDialogButton,
  kList,
  kListInput,
  kListItem,
  kNavbar,
  kPage,
  kSearchbar,
  kSegmented,
  kSegmentedButton,
} from 'konsta/vue'
import {
  Clock3,
  ContactRound,
  Delete,
  Phone,
  PhoneCall,
  PhoneIncoming,
  PhoneOff,
  Plus,
} from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'

import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneContact, RecentCall } from '@/types/phone'
import { formatPhoneNumber, normalizePhoneNumber } from '@/utils/phone'

type PhoneTab = 'recents' | 'contacts' | 'keypad'

const phone = usePhoneStore()
const calls = useCallsStore()
const tab = ref<PhoneTab>('recents')
const query = ref('')
const keypad = ref('')
const editorOpened = ref(false)
const editingContact = ref<PhoneContact | null>(null)
const contactName = ref('')
const contactNumber = ref('')
const error = ref('')
const tabs = [
  { id: 'recents', icon: Clock3 },
  { id: 'contacts', icon: ContactRound },
  { id: 'keypad', icon: Phone },
] as const
const tabBarColors = {
  strongHighlightBgIos: 'bg-[#e5e5ea] dark:bg-[#2c2c2e]',
}
const callButtonColors = {
  fillBgIos: 'bg-[#34c759] active:bg-[#30b350]',
  fillTextIos: 'text-white',
}
const endButtonColors = {
  fillBgIos: 'bg-[#ff3b30] active:bg-[#e6352b]',
  fillTextIos: 'text-white',
}

const visibleContacts = computed(() => {
  const needle = query.value.trim().toLowerCase()
  if (!needle) return calls.contacts
  return calls.contacts.filter(
    (contact) =>
      contact.name.toLowerCase().includes(needle) ||
      contact.phone_number.includes(needle.replace(/\D/g, '')),
  )
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

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function contactNameFor(number: string): string {
  return (
    calls.contacts.find((contact) => contact.phone_number === number)?.name ??
    formatPhoneNumber(number)
  )
}

function openContact(contact?: PhoneContact, number = ''): void {
  editingContact.value = contact ?? null
  contactName.value = contact?.name ?? ''
  contactNumber.value = contact?.phone_number ?? number
  error.value = ''
  editorOpened.value = true
}

async function saveContact(): Promise<void> {
  const number = normalizePhoneNumber(contactNumber.value)
  if (!contactName.value.trim() || !number) {
    error.value = phone.t('Apps.phone.errors.invalid_contact')
    return
  }
  const response = await calls.saveContact({
    id: editingContact.value?.id,
    name: contactName.value.trim(),
    phoneNumber: number,
  })
  if (!response.success) {
    error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
    return
  }
  editorOpened.value = false
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

async function deleteEditedContact(): Promise<void> {
  if (!editingContact.value) return
  if (await calls.deleteContact(editingContact.value.id)) {
    editorOpened.value = false
  }
}

function addDigit(digit: string): void {
  if (keypad.value.length < 10) keypad.value += digit
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

onMounted(() => {
  void calls.bootstrap()
})
</script>

<template>
  <k-page
    class="native-app phone-calls-app"
    :class="{ 'phone-app--light': !phone.isDarkMode }"
  >
    <template v-if="calls.activeCall">
      <k-navbar :title="phone.t('Apps.phone.name')" transparent />
      <k-block
        class="flex h-full flex-col items-center justify-center text-center"
      >
        <div
          class="mb-3 flex h-20 w-20 items-center justify-center rounded-full bg-[#007aff] text-white"
        >
          <PhoneIncoming
            v-if="calls.activeCall.direction === 'incoming'"
            class="h-9 w-9"
          />
          <PhoneCall v-else class="h-9 w-9" />
        </div>
        <h2 class="m-0 text-2xl font-semibold">
          {{ contactNameFor(calls.activeCall.otherNumber) }}
        </h2>
        <p class="mt-2 text-[#8e8e93]">{{ activeCallLabel }}</p>
        <p v-if="error" class="mt-2 text-sm text-[#ff3b30]">{{ error }}</p>
        <div class="mt-10 flex gap-5">
          <k-button
            v-if="
              calls.activeCall.state === 'ringing' &&
              calls.activeCall.direction === 'incoming'
            "
            rounded
            large
            :colors="callButtonColors"
            @click="answerCall"
          >
            <Phone class="mr-2 h-5 w-5" />{{ phone.t('Apps.phone.answer') }}
          </k-button>
          <k-button
            v-if="
              calls.activeCall.state === 'ringing' &&
              calls.activeCall.direction === 'incoming'
            "
            rounded
            large
            :colors="endButtonColors"
            @click="calls.decline()"
          >
            <PhoneOff class="mr-2 h-5 w-5" />{{ phone.t('Apps.phone.decline') }}
          </k-button>
          <k-button
            v-else-if="
              ['ringing', 'connected'].includes(calls.activeCall.state)
            "
            rounded
            large
            :colors="endButtonColors"
            @click="calls.hangup()"
          >
            <PhoneOff class="mr-2 h-5 w-5" />{{ phone.t('Apps.phone.hangup') }}
          </k-button>
        </div>
      </k-block>
    </template>

    <template v-else>
      <k-navbar :title="phone.t(`Apps.phone.${tab}`)" large transparent>
        <template #right>
          <k-button
            v-if="tab === 'contacts'"
            clear
            rounded
            @click="openContact()"
          >
            <Plus class="h-5 w-5" />
          </k-button>
        </template>
      </k-navbar>

      <div class="phone-call-content">
        <k-block v-if="!phone.device?.sim" class="text-center">
          <h2>{{ phone.t('Apps.phone.noSim') }}</h2>
          <p class="text-[#8e8e93]">{{ phone.t('Apps.phone.noSimBody') }}</p>
        </k-block>

        <template v-else-if="tab === 'recents'">
          <k-list v-if="calls.recents.length" strong inset>
            <k-list-item
              v-for="recent in calls.recents"
              :key="recent.id"
              :title="contactNameFor(recent.other_number)"
              :subtitle="recentSubtitle(recent)"
              link
              @click="startCall(recent.other_number)"
            >
              <template #after>
                <span class="flex flex-col items-end gap-1 text-xs">
                  {{ new Date(recent.created_at).toLocaleString(phone.lang) }}
                  <k-button
                    v-if="
                      !calls.contacts.some(
                        (contact) =>
                          contact.phone_number === recent.other_number,
                      )
                    "
                    clear
                    rounded
                    :aria-label="phone.t('Apps.phone.addToContacts')"
                    @click.stop="openContact(undefined, recent.other_number)"
                  >
                    <Plus class="h-5 w-5" />
                  </k-button>
                </span>
              </template>
            </k-list-item>
          </k-list>
          <k-block v-else class="text-center text-[#8e8e93]">{{
            phone.t('Apps.phone.noRecents')
          }}</k-block>
        </template>

        <template v-else-if="tab === 'contacts'">
          <k-searchbar
            :value="query"
            :placeholder="phone.t('Apps.phone.searchContacts')"
            @input="query = eventValue($event)"
            @clear="query = ''"
          />
          <k-list v-if="visibleContacts.length" strong inset>
            <k-list-item
              v-for="contact in visibleContacts"
              :key="contact.id"
              :title="contact.name"
              :subtitle="formatPhoneNumber(contact.phone_number)"
              link
              @click="openContact(contact)"
            >
              <template #after>
                <k-button
                  clear
                  rounded
                  @click.stop="startCall(contact.phone_number)"
                  ><Phone class="h-5 w-5"
                /></k-button>
              </template>
            </k-list-item>
          </k-list>
          <k-block v-else class="text-center text-[#8e8e93]">{{
            phone.t('Apps.phone.noContacts')
          }}</k-block>
        </template>

        <template v-else>
          <k-block class="text-center">
            <div class="mb-5 min-h-10 text-2xl font-medium">
              {{ formatPhoneNumber(keypad) }}
            </div>
            <div class="mx-auto grid max-w-[240px] grid-cols-3 gap-3">
              <k-button
                v-for="digit in [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  '*',
                  '0',
                  '#',
                ]"
                :key="digit"
                tonal
                rounded
                large
                @click="addDigit(digit)"
              >
                {{ digit }}
              </k-button>
            </div>
            <div class="mt-5 flex justify-center gap-4">
              <k-button
                :disabled="keypad.length !== 10"
                rounded
                large
                :colors="callButtonColors"
                @click="startCall(keypad)"
              >
                <Phone class="h-6 w-6" />
              </k-button>
              <k-button
                tonal
                rounded
                large
                :disabled="!keypad"
                @click="keypad = keypad.slice(0, -1)"
              >
                <Delete class="h-6 w-6" />
              </k-button>
            </div>
          </k-block>
        </template>

        <p v-if="error" class="px-5 text-center text-sm text-[#ff3b30]">
          {{ error }}
        </p>
      </div>
      <k-navbar component="nav" :aria-label="phone.t('Apps.phone.name')">
        <template #subnavbar>
          <k-segmented strong rounded :colors="tabBarColors">
            <k-segmented-button
              v-for="item in tabs"
              :key="item.id"
              large
              :active="tab === item.id"
              :class="tab === item.id ? 'text-[#007aff]' : 'text-[#8e8e93]'"
              @click="tab = item.id"
            >
              <span
                class="flex flex-col items-center gap-0.5 text-[10px] leading-none"
              >
                <component :is="item.icon" class="h-5 w-5" />
                <span>{{ phone.t(`Apps.phone.${item.id}`) }}</span>
              </span>
            </k-segmented-button>
          </k-segmented>
        </template>
      </k-navbar>
    </template>
  </k-page>

  <k-dialog :opened="editorOpened" @backdropclick="editorOpened = false">
    <template #title>{{
      phone.t(
        editingContact ? 'Apps.phone.editContact' : 'Apps.phone.addContact',
      )
    }}</template>
    <k-list strong inset>
      <k-list-input
        :value="contactName"
        :label="phone.t('Apps.phone.contactName')"
        @input="contactName = eventValue($event)"
      />
      <k-list-input
        :value="contactNumber"
        :label="phone.t('Apps.phone.phoneNumber')"
        inputmode="numeric"
        @input="contactNumber = eventValue($event)"
      />
    </k-list>
    <p v-if="error" class="text-sm text-[#ff3b30]">{{ error }}</p>
    <template #buttons>
      <k-dialog-button @click="editorOpened = false">{{
        phone.t('Common.cancel')
      }}</k-dialog-button>
      <k-dialog-button v-if="editingContact" @click="deleteEditedContact">{{
        phone.t('Common.delete')
      }}</k-dialog-button>
      <k-dialog-button strong @click="saveContact">{{
        phone.t('Common.save')
      }}</k-dialog-button>
    </template>
  </k-dialog>
</template>
