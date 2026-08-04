<script setup lang="ts">
import {
  kBadge,
  kBlock,
  kBlockTitle,
  kButton,
  kDialog,
  kDialogButton,
  kLink,
  kList,
  kListButton,
  kListInput,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPreloader,
  kSearchbar,
  kToast,
} from 'konsta/vue'
import {
  FileText,
  Inbox,
  KeyRound,
  Mail,
  Send,
  SquarePen,
  Trash2,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { useMailStore } from '@/stores/mail'
import { useNotificationsStore } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import type {
  MailComposeDraft,
  MailCounts,
  MailFolder,
  MailListItem,
  MailMessage,
} from '@/types/mail'
import {
  buildForwardDraft,
  buildReplyDraft,
  parseMailRecipients,
} from '@/utils/mail'

type AuthMode = 'login' | 'register'
type MailScreen = 'folders' | 'list' | 'message' | 'compose'
type MailEvent = {
  data?: {
    counts?: MailCounts
    sender?: string
    subject?: string
  }
  type?: 'mail:changed' | 'mail:new'
}

const phone = usePhoneStore()
const mail = useMailStore()
const notifications = useNotificationsStore()
const authMode = ref<AuthMode>('login')
const authEmail = ref('')
const authPassword = ref('')
const authConfirm = ref('')
const submitting = ref(false)
const screen = ref<MailScreen>('folders')
const selectedMessage = ref<MailMessage | null>(null)
const composeReturn = ref<Exclude<MailScreen, 'compose'>>('folders')
const draftId = ref<string>()
const recipientText = ref('')
const subject = ref('')
const body = ref('')
const composeTouched = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
const emptyTrashOpened = ref(false)
let draftTimer: ReturnType<typeof setTimeout> | undefined
let searchTimer: ReturnType<typeof setTimeout> | undefined
let toastTimer: ReturnType<typeof setTimeout> | undefined

const authenticated = computed(() => Boolean(mail.accountEmail))
const folderTitle = computed(() => phone.t(`Apps.mail.${mail.folder}`))

function showToast(message: string): void {
  if (toastTimer) clearTimeout(toastTimer)
  toastText.value = message
  toastOpened.value = true
  toastTimer = setTimeout(() => {
    toastOpened.value = false
  }, 3000)
}

function errorText(error?: string): string {
  const known = [
    'invalid_email',
    'invalid_password',
    'invalid_credentials',
    'email_taken',
    'rate_limited',
    'invalid_message',
    'recipient_not_found',
    'invalid_draft',
    'not_authenticated',
    'request_failed',
    'invalid_request',
  ]
  return phone.t(
    `Apps.mail.errors.${error && known.includes(error) ? error : 'default'}`,
  )
}

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function formatDate(value: string): string {
  const date = new Date(value.replace(' ', 'T'))
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    month: 'short',
  }).format(date)
}

function itemTitle(item: MailListItem): string {
  if (mail.folder === 'drafts') {
    return item.recipients.join(', ') || phone.t('Apps.mail.compose')
  }
  if (item.folder === 'sent') return item.recipients.join(', ')
  return item.sender ?? ''
}

function itemSubtitle(item: MailListItem): string {
  const title = item.subject || phone.t('Apps.mail.untitled')
  return `${formatDate(item.created_at)} · ${title} · ${item.preview || ''}`
}

function folderCount(folder: MailFolder): number {
  return mail.counts[folder]
}

async function submitAuth(): Promise<void> {
  if (
    authMode.value === 'register' &&
    authPassword.value !== authConfirm.value
  ) {
    showToast(phone.t('Apps.mail.passwordsMismatch'))
    return
  }

  submitting.value = true
  const response =
    authMode.value === 'login'
      ? await mail.login(authEmail.value, authPassword.value)
      : await mail.register(authEmail.value, authPassword.value)
  submitting.value = false
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }

  authPassword.value = ''
  authConfirm.value = ''
  screen.value = 'folders'
}

async function signOut(): Promise<void> {
  await mail.logout()
  selectedMessage.value = null
  screen.value = 'folders'
}

async function openFolder(folder: MailFolder): Promise<void> {
  if (!(await mail.loadFolder(folder))) {
    showToast(errorText())
    return
  }
  screen.value = 'list'
}

async function openItem(item: MailListItem): Promise<void> {
  if (mail.folder === 'drafts') {
    const draft = await mail.openDraft(String(item.id))
    if (!draft) {
      showToast(errorText('invalid_draft'))
      return
    }
    beginCompose({
      body: draft.body,
      id: draft.id,
      recipients: draft.recipients,
      subject: draft.subject,
    })
    return
  }

  const message = await mail.openMessage(Number(item.id))
  if (!message) {
    showToast(errorText())
    return
  }
  selectedMessage.value = message
  screen.value = 'message'
}

function draftRecipientValues(): string[] {
  return recipientText.value
    .split(/[;,]/)
    .map((recipient) => recipient.trim())
    .filter(Boolean)
    .slice(0, 10)
}

async function saveDraftNow(): Promise<void> {
  if (!authenticated.value || screen.value !== 'compose') return
  if (
    !recipientText.value.trim() &&
    !subject.value.trim() &&
    !body.value.trim()
  ) {
    return
  }

  const id = await mail.saveDraft({
    body: body.value,
    id: draftId.value,
    recipients: draftRecipientValues(),
    subject: subject.value,
  })
  if (id) draftId.value = id
}

function scheduleDraftSave(): void {
  if (!composeTouched.value || screen.value !== 'compose') return
  if (draftTimer) clearTimeout(draftTimer)
  draftTimer = setTimeout(() => void saveDraftNow(), 750)
}

function beginCompose(draft?: MailComposeDraft): void {
  composeReturn.value = screen.value === 'compose' ? 'folders' : screen.value
  draftId.value = draft?.id
  recipientText.value = draft?.recipients.join(', ') ?? ''
  subject.value = draft?.subject ?? ''
  body.value = draft?.body ?? ''
  composeTouched.value = false
  screen.value = 'compose'
}

async function closeCompose(): Promise<void> {
  await saveDraftNow()
  screen.value = composeReturn.value
}

async function deleteCurrentDraft(): Promise<void> {
  if (draftId.value) await mail.deleteDraft(draftId.value)
  screen.value = composeReturn.value
}

async function sendMessage(): Promise<void> {
  const recipients = parseMailRecipients(recipientText.value)
  if (!recipients) {
    showToast(errorText('invalid_message'))
    return
  }

  submitting.value = true
  const response = await mail.send({
    body: body.value,
    id: draftId.value,
    recipients,
    subject: subject.value,
  })
  submitting.value = false
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }

  showToast(phone.t('Apps.mail.sentSuccess'))
  selectedMessage.value = null
  screen.value = 'folders'
}

function composeReply(replyAll = false): void {
  if (!selectedMessage.value) return
  beginCompose(
    buildReplyDraft(selectedMessage.value, mail.accountEmail, replyAll),
  )
}

function composeForward(): void {
  if (selectedMessage.value)
    beginCompose(buildForwardDraft(selectedMessage.value))
}

async function mutateSelected(
  endpoint: string,
  extra: Record<string, unknown> = {},
): Promise<void> {
  if (!selectedMessage.value) return
  if (!(await mail.mutateEntry(endpoint, selectedMessage.value.id, extra))) {
    showToast(errorText())
    return
  }
  selectedMessage.value = null
  screen.value = 'list'
}

function updateSearch(event: Event): void {
  const value = (event.target as HTMLInputElement).value
  if (searchTimer) clearTimeout(searchTimer)
  if (toastTimer) clearTimeout(toastTimer)
  searchTimer = setTimeout(() => {
    void mail.loadFolder(mail.folder, value)
  }, 300)
}

async function confirmEmptyTrash(): Promise<void> {
  emptyTrashOpened.value = false
  if (!(await mail.emptyTrash())) showToast(errorText())
}

function goBack(): void {
  if (screen.value === 'list') screen.value = 'folders'
  else if (screen.value === 'message') screen.value = 'list'
}

function onMailEvent(event: MessageEvent<MailEvent>): void {
  if (event.data.type === 'mail:changed' && event.data.data?.counts) {
    mail.setCounts(event.data.data.counts)
    if (screen.value === 'list') {
      void mail.loadFolder(mail.folder, mail.search)
    }
    return
  }

  if (event.data.type === 'mail:new' && event.data.data?.sender) {
    notifications.show({
      appId: 'mail',
      subtitle: event.data.data.subject || phone.t('Apps.mail.untitled'),
      text: phone.t('Apps.mail.newMessage', {
        sender: event.data.data.sender,
      }),
      title: phone.t('Apps.mail.name'),
    })
  }
}

watch([recipientText, subject, body], () => {
  composeTouched.value = true
  scheduleDraftSave()
})

onMounted(() => window.addEventListener('message', onMailEvent))

onBeforeUnmount(() => {
  window.removeEventListener('message', onMailEvent)
  if (draftTimer) clearTimeout(draftTimer)
  if (searchTimer) clearTimeout(searchTimer)
  if (screen.value === 'compose') {
    void saveDraftNow().finally(() => mail.logout())
  } else {
    void mail.logout()
  }
})
</script>

<template>
  <k-page
    v-if="!authenticated"
    class="!pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.mail.loginTitle')"
  >
    <k-navbar large transparent :title="phone.t('Apps.mail.name')">
      <template #right>
        <k-link
          component="button"
          @click="authMode = authMode === 'login' ? 'register' : 'login'"
        >
          {{
            phone.t(
              authMode === 'login'
                ? 'Apps.mail.registerLink'
                : 'Apps.mail.login',
            )
          }}
        </k-link>
      </template>
    </k-navbar>
    <k-block-title>
      {{
        phone.t(
          authMode === 'login'
            ? 'Apps.mail.loginBody'
            : 'Apps.mail.passwordWarning',
        )
      }}
    </k-block-title>
    <k-list>
      <k-list-input
        class="relative"
        :value="authEmail"
        :label="
          phone.t(
            authMode === 'login' ? 'Apps.mail.email' : 'Apps.mail.localPart',
          )
        "
        outline
        floating-label
        :input-class="authMode === 'register' ? 'pr-20' : undefined"
        autocomplete="username"
        autocapitalize="none"
        spellcheck="false"
        :clear-button="authMode === 'login'"
        @input="authEmail = eventValue($event)"
        @clear="authEmail = ''"
      >
        <span
          v-if="authMode === 'register'"
          class="pointer-events-none absolute right-8 top-1/2 -translate-y-1/2 text-sm opacity-50"
        >
          @ifruit.com
        </span>
      </k-list-input>
      <k-list-input
        type="password"
        :value="authPassword"
        :label="phone.t('Apps.mail.password')"
        outline
        floating-label
        autocomplete="current-password"
        @input="authPassword = eventValue($event)"
      >
        <template #media><KeyRound :size="20" /></template>
      </k-list-input>
      <k-list-input
        v-if="authMode === 'register'"
        type="password"
        :value="authConfirm"
        :label="phone.t('Apps.mail.confirmPassword')"
        outline
        floating-label
        autocomplete="new-password"
        @input="authConfirm = eventValue($event)"
      >
        <template #media><KeyRound :size="20" /></template>
      </k-list-input>
    </k-list>
    <k-block>
      <k-button large rounded :disabled="submitting" @click="submitAuth">
        <k-preloader v-if="submitting" />
        <template v-else>
          {{
            phone.t(
              authMode === 'login' ? 'Apps.mail.login' : 'Apps.mail.register',
            )
          }}
        </template>
      </k-button>
    </k-block>
  </k-page>

  <k-page
    v-else-if="screen === 'folders'"
    class="!pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.mail.mailboxes')"
  >
    <k-navbar large transparent :title="phone.t('Apps.mail.mailboxes')">
      <template #left>
        <k-link component="button" @click="signOut">
          {{ phone.t('Apps.mail.logout') }}
        </k-link>
      </template>
      <template #right>
        <k-link
          component="button"
          icon-only
          :aria-label="phone.t('Apps.mail.compose')"
          @click="beginCompose()"
        >
          <SquarePen :size="21" />
        </k-link>
      </template>
    </k-navbar>
    <k-block-title>{{ mail.accountEmail }}</k-block-title>
    <k-list strong inset>
      <k-list-item
        link
        :title="phone.t('Apps.mail.inbox')"
        @click="openFolder('inbox')"
      >
        <template #media><Inbox :size="20" /></template>
        <template #after>
          <k-badge v-if="mail.counts.unread">{{ mail.counts.unread }}</k-badge>
          <template v-else>{{ folderCount('inbox') }}</template>
        </template>
      </k-list-item>
      <k-list-item
        link
        :title="phone.t('Apps.mail.sent')"
        @click="openFolder('sent')"
      >
        <template #media><Send :size="20" /></template>
        <template #after>{{ folderCount('sent') }}</template>
      </k-list-item>
      <k-list-item
        link
        :title="phone.t('Apps.mail.drafts')"
        @click="openFolder('drafts')"
      >
        <template #media><FileText :size="20" /></template>
        <template #after>{{ folderCount('drafts') }}</template>
      </k-list-item>
      <k-list-item
        link
        :title="phone.t('Apps.mail.trash')"
        @click="openFolder('trash')"
      >
        <template #media><Trash2 :size="20" /></template>
        <template #after>{{ folderCount('trash') }}</template>
      </k-list-item>
    </k-list>
  </k-page>

  <k-page
    v-else-if="screen === 'list'"
    class="!pt-[44px] !pb-[25px]"
    :aria-label="folderTitle"
  >
    <k-navbar :title="folderTitle">
      <template #left>
        <k-navbar-back-link
          component="button"
          :text="phone.t('Apps.mail.mailboxes')"
          :aria-label="phone.t('Apps.mail.mailboxes')"
          @click="goBack"
        />
      </template>
      <template #right>
        <k-link
          v-if="mail.folder === 'trash' && mail.items.length"
          component="button"
          icon-only
          :aria-label="phone.t('Apps.mail.emptyTrash')"
          @click="emptyTrashOpened = true"
        >
          <Trash2 :size="20" />
        </k-link>
        <k-link
          v-else
          component="button"
          icon-only
          :aria-label="phone.t('Apps.mail.compose')"
          @click="beginCompose()"
        >
          <SquarePen :size="21" />
        </k-link>
      </template>
      <template #subnavbar>
        <k-searchbar
          :value="mail.search"
          :placeholder="phone.t('Apps.mail.search')"
          @input="updateSearch"
          @clear="mail.loadFolder(mail.folder, '')"
        />
      </template>
    </k-navbar>

    <k-block v-if="mail.loading"><k-preloader /></k-block>
    <k-list v-else-if="mail.items.length" strong>
      <k-list-item
        v-for="item in mail.items"
        :key="`${mail.folder}-${item.id}`"
        link
        :title="itemTitle(item)"
        :subtitle="itemSubtitle(item)"
        :strong-title="mail.folder === 'inbox' && !item.is_read"
        @click="openItem(item)"
      >
      </k-list-item>
    </k-list>
    <template v-else>
      <k-block-title large>
        {{ phone.t(mail.search ? 'Apps.mail.noResults' : 'Apps.mail.noMail') }}
      </k-block-title>
      <k-block strong inset>
        {{
          phone.t(
            mail.search ? 'Apps.mail.noResultsBody' : 'Apps.mail.noMailBody',
          )
        }}
      </k-block>
    </template>
    <k-list v-if="mail.hasMore" inset>
      <k-list-button @click="mail.loadFolder(mail.folder, mail.search, true)">
        {{ phone.t('Apps.mail.loadMore') }}
      </k-list-button>
    </k-list>
  </k-page>

  <k-page
    v-else-if="screen === 'message' && selectedMessage"
    class="!pt-[44px] !pb-[25px]"
  >
    <k-navbar :title="phone.t('Apps.mail.name')">
      <template #left>
        <k-navbar-back-link
          component="button"
          :text="folderTitle"
          :aria-label="folderTitle"
          @click="goBack"
        />
      </template>
    </k-navbar>
    <k-list strong>
      <k-list-item
        :title="selectedMessage.sender"
        :subtitle="`${formatDate(selectedMessage.created_at)} · ${phone.t('Apps.mail.to')}: ${selectedMessage.recipients.join(', ')}`"
      >
        <template #media><Mail :size="20" /></template>
      </k-list-item>
    </k-list>
    <k-block-title>
      {{ selectedMessage.subject || phone.t('Apps.mail.untitled') }}
    </k-block-title>
    <k-block strong inset>
      <span class="whitespace-pre-wrap">{{ selectedMessage.body }}</span>
    </k-block>
    <k-list strong inset>
      <k-list-button @click="composeReply(false)">{{
        phone.t('Apps.mail.reply')
      }}</k-list-button>
      <k-list-button @click="composeReply(true)">{{
        phone.t('Apps.mail.replyAll')
      }}</k-list-button>
      <k-list-button @click="composeForward">{{
        phone.t('Apps.mail.forward')
      }}</k-list-button>
      <k-list-button
        v-if="!selectedMessage.trashed_at"
        @click="mutateSelected('mail:set-read', { read: false })"
      >
        {{ phone.t('Apps.mail.markUnread') }}
      </k-list-button>
      <k-list-button
        v-if="selectedMessage.trashed_at"
        @click="mutateSelected('mail:restore')"
      >
        {{ phone.t('Apps.mail.restore') }}
      </k-list-button>
      <k-list-button
        v-if="selectedMessage.trashed_at"
        @click="mutateSelected('mail:delete-forever')"
      >
        {{ phone.t('Apps.mail.deleteForever') }}
      </k-list-button>
      <k-list-button v-else @click="mutateSelected('mail:trash')">
        {{ phone.t('Apps.mail.moveToTrash') }}
      </k-list-button>
    </k-list>
  </k-page>

  <k-page v-else-if="screen === 'compose'" class="!pt-[44px] !pb-[25px]">
    <k-navbar>
      <template #left>
        <k-link component="button" @click="closeCompose">
          {{ phone.t('Common.cancel') }}
        </k-link>
      </template>
      <template #right>
        <k-link component="button" :disabled="submitting" @click="sendMessage">
          {{ phone.t('Common.send') }}
        </k-link>
      </template>
    </k-navbar>
    <k-block-title large>{{ phone.t('Apps.mail.compose') }}</k-block-title>
    <k-list strong>
      <k-list-input
        :value="recipientText"
        :label="phone.t('Apps.mail.recipients')"
        :info="phone.t('Apps.mail.recipientHint')"
        autocapitalize="none"
        spellcheck="false"
        @input="recipientText = eventValue($event)"
      />
      <k-list-input
        :value="subject"
        :label="phone.t('Apps.mail.subject')"
        maxlength="120"
        @input="subject = eventValue($event)"
      />
      <k-list-input
        type="textarea"
        :value="body"
        :label="phone.t('Apps.mail.body')"
        maxlength="20000"
        @input="body = eventValue($event)"
      />
    </k-list>
    <k-list v-if="draftId" strong inset>
      <k-list-button @click="deleteCurrentDraft">
        {{ phone.t('Apps.mail.deleteDraft') }}
      </k-list-button>
    </k-list>
    <k-block v-if="submitting"><k-preloader /></k-block>
  </k-page>

  <k-dialog
    :opened="emptyTrashOpened"
    :title="phone.t('Apps.mail.emptyTrashTitle')"
    :content="phone.t('Apps.mail.emptyTrashBody')"
    @backdropclick="emptyTrashOpened = false"
  >
    <template #buttons>
      <k-dialog-button @click="emptyTrashOpened = false">
        {{ phone.t('Common.cancel') }}
      </k-dialog-button>
      <k-dialog-button strong @click="confirmEmptyTrash">
        {{ phone.t('Apps.mail.emptyTrash') }}
      </k-dialog-button>
    </template>
  </k-dialog>

  <k-toast
    :opened="toastOpened"
    position="center"
    :text="toastText"
    @click="toastOpened = false"
  />
</template>
