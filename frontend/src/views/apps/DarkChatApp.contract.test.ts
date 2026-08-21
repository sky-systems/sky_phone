import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./DarkChatApp.vue', import.meta.url),
  'utf8',
)

describe('DarkChatApp Sky UI contract', () => {
  it('uses first-party Sky UI without direct Konsta markup', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toMatch(/<\/?k-[a-z]/)
    expect(source).toContain('<SkyAppPage')
    expect(source).toContain('<SkyNavbar')
    expect(source).toContain('<SkyScrollArea')
    expect(source).toContain('<SkySettingsGroup')
    expect(source).toContain('<SkyMessagebar')
    expect(source).not.toContain('<SkyPillNavigation')
  })

  it('keeps one identity action in the inbox header', () => {
    const inboxStart = source.indexOf("screen === 'inbox'")
    const newChatStart = source.indexOf("screen === 'new'")
    const inbox = source.slice(inboxStart, newChatStart)

    expect(inbox.match(/@click="openProfile"/g)).toHaveLength(1)
    expect(inbox).toContain('@click="beginNewChat"')
    expect(inbox).toContain('<SquarePen :size="21" />')
  })

  it('matches the SMS recipient composer for new private chats', () => {
    const newChatStart = source.indexOf("screen === 'new'")
    const threadStart = source.indexOf("screen === 'thread'", newChatStart)
    const newChat = source.slice(newChatStart, threadStart)

    expect(newChat).toContain('class="dc-recipient-field"')
    expect(newChat).toContain('layout="inline"')
    expect(newChat).toContain('class="dc-new-chat-contacts"')
    expect(newChat).toContain("{{ t('newChatBody') }}")
    expect(newChat).toContain("{{ phone.t('Common.cancel') }}")
    expect(newChat).not.toContain('class="dc-hero"')
  })

  it('rejects the current profile identifiers before opening confirmation', () => {
    expect(source).toContain('darkchat.profile?.darkId')
    expect(source).toContain('darkchat.profile?.inviteCode')
    expect(source).toContain("showToast(errorText('self_chat'))")
  })

  it('keeps the search visually compact without shrinking its wrapper', () => {
    expect(source).toMatch(
      /\.dc-search :deep\(\.sky-searchbar__control\),[\s\S]*?height:\s*38px;[\s\S]*?min-height:\s*38px;/,
    )
  })

  it('shares and consumes private profile invitations', () => {
    expect(source).toContain('function sharePrivateInvite(): void')
    expect(source).toContain('@click="sharePrivateInvite"')
    expect(source).toContain('easyShareDarkChatInviteCode(')
    expect(source).toContain('function openSharedInvite(): void')
    expect(source).toMatch(
      /openSharedInvite\(\)[\s\S]*?identifier\.value = sharedInviteCode\.value[\s\S]*?screen\.value = 'new'/,
    )
  })

  it('uses the full conversation card width', () => {
    const conversationStart = source.indexOf(
      'v-for="conversation in filteredConversations"',
    )
    const conversationEnd = source.indexOf('</SkyListItem>', conversationStart)
    const conversation = source.slice(conversationStart, conversationEnd)

    expect(conversation).not.toMatch(/\scontacts(?:\s|>)/)
  })

  it('bottom-aligns short threads and exposes profile lifecycle actions', () => {
    expect(source).toContain('ref="messagesArea"')
    expect(source).toMatch(/\.dc-day\s*\{[^}]*margin:\s*auto 0 8px/s)
    expect(source).toContain('@click="signOut"')
    expect(source).toContain('@click="deleteProfile"')
  })

  it('aligns the attachment action, input, and send icon in one composer pill', () => {
    const composerStart = source.indexOf('<div v-else class="dc-composer-row">')
    const composerEnd = source.indexOf('</section>', composerStart)
    const composer = source.slice(composerStart, composerEnd)

    expect(source).toContain('class="dc-composer-row"')
    expect(source).toContain('class="dc-composer-action"')
    expect(source).toContain('class="dc-composer-pill"')
    expect(source).toMatch(
      /<div v-else class="dc-composer-row">[\s\S]*?class="dc-composer-pill"[\s\S]*?class="dc-composer-action"[\s\S]*?<SkyMessagebar/,
    )
    expect(composer).not.toContain('<template #left>')
    expect(source).toMatch(
      /\.dc-composer-pill\s*\{[^}]*border-radius:\s*var\(--sky-radius-pill\)/s,
    )
    expect(source).toMatch(
      /\.dc-composer-action\s*\{[^}]*border-radius:\s*50%/s,
    )
  })

  it('presents attachments as the vertical five-action SMS glass menu', () => {
    const attachmentsStart = source.indexOf(
      'v-if="attachmentOpen" class="dc-attachments"',
    )
    const attachmentsEnd = source.indexOf('</div>', attachmentsStart)
    const attachments = source.slice(attachmentsStart, attachmentsEnd)

    expect(attachments.match(/class="dc-attachment-action"/g)).toHaveLength(5)
    expect(attachments.match(/<SkyGlass/g)).toHaveLength(5)
    expect(source).toMatch(
      /\.dc-attachments\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;/s,
    )
  })

  it('centers all composer controls on the same level', () => {
    expect(source).toMatch(
      /\.dc-composer-row \.dc-composer-pill\s*\{[^}]*display:\s*flex;[^}]*align-items:\s*center;/s,
    )
    expect(source).toMatch(
      /\.dc-composer-action\s*\{[^}]*width:\s*46px;[^}]*height:\s*46px;/s,
    )
  })

  it('raises only the DarkChat inbox title block', () => {
    expect(source).toContain('class="dc-inbox-navbar"')
    expect(source).toMatch(
      /\.dc-inbox-navbar :deep\(\.sky-navbar__title-container > div\)\s*\{[^}]*translateY\(-14px\)/s,
    )
  })
})
