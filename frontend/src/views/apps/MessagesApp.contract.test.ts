import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./MessagesApp.vue', import.meta.url),
  'utf8',
)
const styles = readFileSync(
  new URL('../../assets/main.css', import.meta.url),
  'utf8',
)

describe('MessagesApp Sky UI contract', () => {
  it('uses first-party Sky UI without direct Konsta markup', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toMatch(/<\/?k-[a-z]/)
    expect(source).toContain('<SkyAppPage')
    expect(source).toContain('<SkyNavbar')
    expect(source).toContain('<SkyScrollArea')
    expect(source).toContain('<SkySearchbar')
    expect(source).toContain('<SkyDropdown')
    expect(source).toContain('<SkyFab')
    expect(source).toContain('<SkyMessages')
    expect(source).toContain('<SkyMessagebar')
    expect(source).toContain('<SkyPillNavigation')
    expect(source).toContain('<SkySettingsGroup')
    expect(source).toContain('<SkySettingsRow')
    expect(source).toContain('<SkySheet')
    expect(source).toContain('<SkyToolbar')
    expect(source).not.toContain('<SkySegmented')
  })

  it('uses the anchored central dropdown for sort, filter, and edit actions', () => {
    const inboxStart = source.indexOf(
      'class="messages-sky-page messages-sky-inbox"',
    )
    const composeStart = source.indexOf('v-else-if="composing"')
    const inbox = source.slice(inboxStart, composeStart)

    expect(source).toContain("id: 'sort-newest'")
    expect(source).toContain("id: 'sort-oldest'")
    expect(source).toContain("id: 'filter-all'")
    expect(source).toContain("id: 'filter-unread'")
    expect(source).toContain("id: 'edit'")
    expect(source).toContain("phone.t('Apps.messages.sortNewest')")
    expect(source).toContain("phone.t('Apps.messages.sortOldest')")
    expect(source).toContain("phone.t('Apps.messages.allMessages')")
    expect(source).toContain("phone.t('Apps.messages.unreadMessages')")
    expect(source).toContain("phone.t('Common.edit')")
    expect(source).toContain("group: 'sort'")
    expect(source).toContain("group: 'filter'")
    expect(source).toContain("phone.t('Apps.messages.sortLabel')")
    expect(source).toContain("phone.t('Apps.messages.filterLabel')")
    expect(source).toContain(
      'inboxMenuTarget.value = event.currentTarget as HTMLElement',
    )
    expect(source).toContain("if (id === 'edit') toggleListEditing()")

    expect(inbox).toContain('class="messages-sky-inbox-menu-trigger"')
    expect(inbox).toContain('aria-haspopup="menu"')
    expect(inbox).toContain(':aria-expanded="inboxMenuOpened"')
    expect(inbox).toContain('@click="openInboxMenu"')
    expect(inbox).toContain('id="messages-inbox-menu"')
    expect(inbox).toContain(':items="inboxMenuItems"')
    expect(inbox).toContain(':opened="inboxMenuOpened"')
    expect(inbox).toContain(':target="inboxMenuTarget"')
    expect(inbox).toContain('@backdropclick="dismissInboxMenu"')
    expect(inbox).toContain('@escape="dismissInboxMenu"')
    expect(inbox).toContain('@positionerror="dismissInboxMenu"')
    expect(inbox).toContain('@select="selectInboxMenuItem"')
  })

  it('places search and the compose action together in the bottom toolbar', () => {
    const inboxStart = source.indexOf(
      'class="messages-sky-page messages-sky-inbox"',
    )
    const composeStart = source.indexOf('v-else-if="composing"')
    const inbox = source.slice(inboxStart, composeStart)
    const scrollEnd = inbox.indexOf('</SkyScrollArea>')
    const toolbarStart = inbox.indexOf('<SkyToolbar')
    const toolbarEnd = inbox.indexOf('</SkyToolbar>', toolbarStart)
    const toolbar = inbox.slice(toolbarStart, toolbarEnd)
    const searchbarStart = toolbar.indexOf('<SkySearchbar')
    const fabStart = toolbar.indexOf('<SkyFab')

    expect(toolbarStart).toBeGreaterThan(scrollEnd)
    expect(toolbar).toContain('class="messages-sky-inbox-toolbar"')
    expect(toolbar).toContain('component="footer"')
    expect(searchbarStart).toBeGreaterThan(-1)
    expect(fabStart).toBeGreaterThan(searchbarStart)
    expect(toolbar).toContain('v-model="search"')
    expect(toolbar).toContain('variant="glass"')
    expect(toolbar).toContain('@click="beginCompose"')
    expect(toolbar).toContain('<SquarePen :size="21" />')
    expect(inbox).not.toContain('messages-sky-compose-navigation')
  })

  it('uses the results-empty state for search and unread filters', () => {
    expect(source).toContain('search || showUnreadOnly')
    expect(source).toContain('v-if="!search && !showUnreadOnly" #actions')
  })

  it('keeps the unread marker in the media slot left of the avatar', () => {
    const inboxStart = source.indexOf(
      'class="messages-sky-page messages-sky-inbox"',
    )
    const composeStart = source.indexOf('v-else-if="composing"')
    const inbox = source.slice(inboxStart, composeStart)
    const mediaSlotStart = inbox.indexOf('<template #media>')
    const unreadSlot = inbox.indexOf(
      'class="messages-sky-unread-slot"',
      mediaSlotStart,
    )
    const avatar = inbox.indexOf('class="messages-avatar"', mediaSlotStart)

    expect(mediaSlotStart).toBeGreaterThan(-1)
    expect(unreadSlot).toBeGreaterThan(mediaSlotStart)
    expect(avatar).toBeGreaterThan(unreadSlot)
    expect(inbox).toContain(
      "'is-visible': !editingList && conversation.unread > 0",
    )
    expect(source).toContain('count: String(conversation.unread)')
    expect(inbox).toContain("'aria-pressed': selectedNumbers.includes(")
  })

  it('uses one compact scroll region and an in-flow composer in threads', () => {
    expect(source).toContain('class="messages-sky-thread-scroll"')
    expect(source).toContain('class="messages-bubbles"')
    expect(source).toContain('class="messages-sky-composer-pill"')
    expect(source).toContain('class="messages-sky-messagebar"')
    expect(source).toMatch(
      /\.messages-bubbles\s*\{[^}]*min-height:\s*100%[^}]*justify-content:\s*flex-end/s,
    )
    expect(source).toMatch(
      /\.messages-sky-composer-shell\s*\{[^}]*flex:\s*none/s,
    )
    expect(source).toMatch(
      /\.messages-sky-composer-pill\s*\{[^}]*border-radius:\s*var\(--sky-radius-pill\)/s,
    )
  })

  it('keeps add and text entry in separate glass surfaces', () => {
    expect(source).toContain('class="messages-sky-composer-row"')
    expect(source).toMatch(
      /<SkyGlass[\s\S]*?class="messages-sky-messagebar__action messages-sky-messagebar__plus"[\s\S]*?<\/SkyGlass>[\s\S]*?<SkyGlass[\s\S]*?class="messages-sky-composer-pill"/,
    )
  })

  it('round-trips up to six media items into a removable composer preview', () => {
    expect(source).toContain('const MAX_PENDING_ATTACHMENTS = 6')
    expect(source).toContain(
      'pendingAttachments: [...pendingAttachments.value]',
    )
    expect(source).toContain('messageMedia.consumeMany<MessagesMediaContext>')
    expect(source).toContain('class="messages-pending-media"')
    expect(source).toContain('@click="removePendingAttachment(media.id)"')
    expect(source).toContain('Apps.photos.videoAlt')
    expect(source).not.toMatch(/await sendAttachment\([\s\S]*?media\.mediaType/)
  })

  it('sends selected media in order and captions the last item', () => {
    expect(source).toContain(
      'for (const [index, media] of queuedAttachments.entries())',
    )
    expect(source).toContain(
      'index === queuedAttachments.length - 1 ? body : undefined',
    )
    expect(source).toContain("media.mediaType === 'photo' ? 'image' : 'video'")
  })

  it('normalizes voice waveforms and uses the regular unfilled send icon', () => {
    expect(source).toContain(
      'compressWaveformSamples(recordingSamples, WAVEFORM_SAMPLES)',
    )
    expect(source).toContain('class="messages-recorder__send"')
    expect(source).toContain('<ArrowUpCircle :size="27" :stroke-width="2.4" />')
    expect(source).not.toContain('fill="currentColor" />\n      </SkyButton>')
    expect(source).toContain('const recordingStarting = ref(false)')
    expect(source).toContain('if (requestId !== recordingRequestId)')
    expect(source).toContain('requestedStream.getTracks().forEach')
    expect(source).toContain(':disabled="sending || recordingStarting"')
  })

  it('uses provider dimensions for proportional GIF picker results', () => {
    expect(source).toContain(
      'aspectRatio: `${Math.max(1, gif.width)} / ${Math.max(1, gif.height)}`',
    )
    expect(source).toContain('const gifColumns = computed')
    expect(source).toContain('class="messages-gif-grid"')
    expect(source).toContain('class="messages-gif-column"')
    expect(source).toContain('class="messages-gif-result"')
    expect(styles).toMatch(
      /\.messages-media-picker__gifs--masonry \.messages-gif-result img\s*\{[^}]*object-fit:\s*cover/s,
    )
  })

  it('opens contact sharing in a draggable Sky UI bottom sheet', () => {
    const sheetStart = source.indexOf('class="messages-media-picker-sheet"')
    const sheetEnd = source.indexOf('</SkySheet>', sheetStart)
    const sheet = source.slice(sheetStart, sheetEnd)

    expect(sheetStart).toBeGreaterThan(-1)
    expect(sheetEnd).toBeGreaterThan(sheetStart)
    expect(sheet).toContain(
      ':opened="activeCanMessage && attachmentPicker !== null"',
    )
    expect(sheet).toContain('swipe-to-close')
    expect(sheet).toContain('grabber-clickable')
    expect(sheet).toContain('@backdropclick="closeAttachmentPicker"')
    expect(sheet).toContain('@escape="closeAttachmentPicker"')
    expect(sheet).toContain('@grabberclick="closeAttachmentPicker"')
    expect(sheet).toContain('@swipeclose="closeAttachmentPicker"')
    expect(sheet).toContain('v-if="attachmentPicker === \'contacts\'"')
    expect(sheet).toContain('@click="sendContact(contact)"')
    expect(source).toContain('function closeAttachmentPicker(): void')
    expect(styles).toMatch(
      /\.messages-media-picker-sheet \.sky-sheet__panel\s*\{[^}]*border-radius:\s*30px 30px 0 0/s,
    )
  })

  it('uses a surface back target in the thread and a compact recipient row', () => {
    const threadStart = source.indexOf(
      'class="messages-sky-page messages-sky-thread"',
    )
    const contactProfileStart = source.indexOf(
      'v-if="contactDetailsOpen"',
      threadStart,
    )
    const threadHeader = source.slice(threadStart, contactProfileStart)

    expect(threadHeader).toContain('class="messages-sky-thread-navbar"')
    expect(threadHeader).toContain('show-back')
    expect(threadHeader).toContain('back-appearance="surface"')
    expect(threadHeader).toContain('@back="goBack"')
    expect(source).toContain('class="messages-recipient-field"')
    expect(source).toContain('layout="inline"')
    expect(source).toMatch(
      /\.messages-recipient-field :deep\(\.sky-field\)\s*\{[^}]*min-height:\s*52px/s,
    )
  })

  it('renders contact details read-only with icon actions and contact routing', () => {
    const contactOverlayClass = source.indexOf(
      'class="messages-contact-overlay"',
    )
    const contactProfileStart = source.lastIndexOf(
      '<SkyAppPage',
      contactOverlayClass,
    )
    const threadScrollStart = source.indexOf(
      'class="messages-sky-thread-scroll"',
      contactProfileStart,
    )
    const contactProfile = source.slice(contactProfileStart, threadScrollStart)

    expect(contactProfileStart).toBeGreaterThan(-1)
    expect(threadScrollStart).toBeGreaterThan(contactProfileStart)
    expect(contactProfile).toContain('component="section"')
    expect(contactProfile).toContain('back-appearance="surface"')
    expect(contactProfile).toContain('activeContact?.avatar_url')
    expect(contactProfile).toContain('<SkySettingsGroup')
    expect(contactProfile).toContain('<SkySettingsRow')
    expect(contactProfile).toContain('activeContact?.organization')
    expect(contactProfile).toContain(':value="activeContact.organization"')
    expect(contactProfile).toContain('activeContact?.notes')
    expect(contactProfile).not.toContain('<SkyField')

    expect(contactProfile).toMatch(
      /<SkyButton\s+v-if="activeContact\?\.canCall !== false"\s+icon-only\s+rounded\s+tonal[\s\S]*?@click="callActiveContact"/,
    )
    expect(contactProfile).toMatch(
      /<SkyButton\s+v-if="activeCanMessage"\s+icon-only\s+rounded\s+tonal[\s\S]*?@click="contactDetailsOpen = false"/,
    )
    expect(contactProfile).toMatch(
      /<SkyButton\s+v-if="activeContactEmail"\s+icon-only\s+rounded\s+tonal[\s\S]*?@click="mailActiveContact"/,
    )
    expect(contactProfile).toContain('<PhoneIcon :size="22" />')
    expect(contactProfile).toContain('<MessageCircle :size="22" />')
    expect(contactProfile).toContain('<Mail :size="22" />')

    expect(contactProfile).toContain('Apps.messages.showInContacts')
    expect(contactProfile).toContain('Apps.messages.addContact')
    expect(contactProfile).toContain('@activate="openActiveContactInPhone"')
    expect(source).toContain("path: '/apps/phone'")
    expect(source).toContain('{ contactId: activeContact.value.id }')
    expect(source).toContain('{ newContactNumber: messages.activeNumber }')
    expect(source).toContain("path: '/apps/mail'")
    expect(source).toContain(
      "query: { compose: '1', to: activeContactEmail.value }",
    )

    expect(contactProfile).not.toContain('Common.edit')
    expect(source).not.toContain('contactEditing')
    expect(source).not.toContain('saveContactDetails')
    expect(source).not.toContain('deleteActiveContact')
    expect(source).not.toContain('Apps.messages.deleteContact')
    expect(contactProfile).not.toContain('<Pencil')
    expect(source).toContain(':inert="contactDetailsOpen || undefined"')
    expect(source).toContain(':aria-hidden="contactDetailsOpen"')
  })

  it('confirms contact blocking in a dismissible dialog', () => {
    const contactOverlayClass = source.indexOf(
      'class="messages-contact-overlay"',
    )
    const contactProfileStart = source.lastIndexOf(
      '<SkyAppPage',
      contactOverlayClass,
    )
    const threadScrollStart = source.indexOf(
      'class="messages-sky-thread-scroll"',
      contactProfileStart,
    )
    const contactProfile = source.slice(contactProfileStart, threadScrollStart)
    const blockDialogOpened = source.indexOf(':opened="blockDialogOpened"')
    const blockDialogStart = source.lastIndexOf('<SkyDialog', blockDialogOpened)
    const notificationStart = source.indexOf(
      '<SkyNotification',
      blockDialogStart,
    )
    const blockDialog = source.slice(blockDialogStart, notificationStart)

    expect(contactProfile).toContain('kind="action"')
    expect(contactProfile).toContain('tone="danger"')
    expect(contactProfile).toContain('Apps.messages.blockContact')
    expect(contactProfile).toContain('@activate="confirmBlockActiveContact"')
    expect(blockDialogStart).toBeGreaterThan(-1)
    expect(blockDialog).toContain('@backdropclick="blockDialogOpened = false"')
    expect(blockDialog).toContain('@escape="blockDialogOpened = false"')
    expect(blockDialog).toContain('Apps.messages.blockContactTitle')
    expect(blockDialog).toContain('Apps.messages.blockContactBody')
    expect(blockDialog).toContain('@click="blockActiveContact"')
    expect(source).toContain(
      'const response = await calls.blockNumber(messages.activeNumber)',
    )
  })

  it('keeps SMS conversations and recipients in flat iMessage-style lists', () => {
    expect(source).not.toMatch(
      /\.messages-sky-page\s*\{[^}]*--sky-page-gutter/s,
    )
    expect(source).toMatch(
      /v-if="filteredConversations.length"\s+flush\s+class="messages-sky-conversation-list"/,
    )
    expect(source).toMatch(
      /class="messages-recipient-field"\s+density="compact"\s+flush/,
    )
    expect(source).toMatch(
      /v-if="contactSuggestions.length"\s+class="messages-contact-list"\s+flush/,
    )
  })
})
