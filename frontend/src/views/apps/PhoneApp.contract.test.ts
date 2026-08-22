import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./PhoneApp.vue', import.meta.url), 'utf8')

describe('PhoneApp EasyShare contract', () => {
  it('loads the server-canonical own contact instead of creating a profile payload', () => {
    expect(source).toContain(
      "nuiCall<EasySharePayload>('easyshare:own-contact')",
    )
    expect(source).toContain('easyShare.open(response.data)')
    expect(source).not.toContain("kind: 'profile'")
  })

  it('uses the shared full-width Sky tab bar for phone sections', () => {
    expect(source).toContain('<sky-tab-bar')
    expect(source).toContain('<sky-tab-button')
    expect(source).toContain(
      'calc(var(--sky-tabbar-height) + var(--sky-safe-area-bottom) + 16px);',
    )
    expect(source).not.toMatch(
      /\.phone-contacts\s*\{[^}]*padding-bottom:\s*20px;/s,
    )
  })

  it('uses shared interactive liquid glass surfaces for phone controls', () => {
    expect(source).toMatch(
      /<sky-button\s+glass\s+rounded\s+class="phone-detail-header-button phone-detail-back"/,
    )
    expect(source).toMatch(
      /<sky-button\s+glass\s+v-for="action in contactProfileActions"[\s\S]*?icon-only[\s\S]*?class="phone-profile-action"/,
    )
    expect(source).toContain(
      'width: var(--phone-profile-action-size) !important;',
    )
    expect(source).toContain(
      'height: var(--phone-profile-action-size) !important;',
    )
    expect(source).toMatch(
      /<sky-glass\s+v-for="key in keypadKeys"[\s\S]*?component="button"[\s\S]*?class="phone-keypad-key"/,
    )
    expect(source).toContain('class="phone-contacts-add"')
    expect(source).toContain('class="phone-recents-search"')

    const recentsFilter = source.slice(
      source.indexOf('<sky-segmented'),
      source.indexOf('</sky-segmented>') + '</sky-segmented>'.length,
    )
    expect(recentsFilter).toContain('class="phone-recents-filter"')
    expect(recentsFilter).toContain('navigation')
    expect(recentsFilter).toContain('strong')
    expect(recentsFilter.match(/<sky-segmented-button/g)).toHaveLength(2)
    expect(source).toContain(
      'background: var(--sky-tabbar-highlight-background);',
    )
    expect(source).toContain(
      'grid-template-columns: 52px minmax(0, 1fr) auto 44px;',
    )
    expect(source).not.toMatch(
      /#(?:007aff|0a84ff|195287|22527d|25458e|2a468f|2f4a98|4b92d1|55aaff|5b91c2|64a8ff|68adff)/i,
    )
    expect(source).not.toContain('rgba(10, 132, 255')
  })

  it('opens contact deep links only after contacts bootstrap and consumes the query', () => {
    const mounted = source.slice(
      source.indexOf('onMounted(async () => {'),
      source.indexOf('onBeforeUnmount(() => {'),
    )
    const bootstrapIndex = mounted.indexOf('await calls.bootstrap()')
    const contactRequestIndex = mounted.indexOf(
      "typeof route.query.contactId === 'string'",
    )

    expect(bootstrapIndex).toBeGreaterThanOrEqual(0)
    expect(contactRequestIndex).toBeGreaterThan(bootstrapIndex)
    expect(mounted).toContain(
      '(contact) => contact.id === route.query.contactId',
    )
    expect(mounted).toContain("tab.value = 'contacts'")
    expect(mounted).toContain('openRecentDetail(requestedContact.phone_number)')
    expect(mounted).toMatch(
      /route\.query\.contactId[\s\S]*await router\.replace\('\/apps\/phone'\)/,
    )
  })

  it('opens new-contact deep links in the contact editor and consumes the query', () => {
    const mounted = source.slice(
      source.indexOf('onMounted(async () => {'),
      source.indexOf('onBeforeUnmount(() => {'),
    )
    const bootstrapIndex = mounted.indexOf('await calls.bootstrap()')
    const newContactRequestIndex = mounted.indexOf(
      "typeof route.query.newContactNumber === 'string'",
    )

    expect(bootstrapIndex).toBeGreaterThanOrEqual(0)
    expect(newContactRequestIndex).toBeGreaterThan(bootstrapIndex)
    expect(mounted).toContain(
      'openContact(undefined, route.query.newContactNumber)',
    )
    expect(mounted).toMatch(
      /route\.query\.newContactNumber[\s\S]*await router\.replace\('\/apps\/phone'\)/,
    )
  })
})
