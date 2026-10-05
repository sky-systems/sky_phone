import { createPinia, setActivePinia } from 'pinia'
import { computed } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore } from '@/stores/phone'
import { normalizeMailAddress, parseMailRecipients } from '@/utils/mail'

describe('configured mail domain', () => {
  beforeEach(() => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    setActivePinia(createPinia())
  })

  afterEach(() => vi.unstubAllGlobals())

  it('uses the shipped domain until a runtime payload supplies the active setting', () => {
    const phone = usePhoneStore()
    phone.open()
    expect(phone.mailDomain).toBe('ifruit.com')

    phone.open({ mailDomain: 'city-mail.test' })
    expect(normalizeMailAddress('Alex', phone.mailDomain)).toBe(
      'alex@city-mail.test',
    )
    phone.open({})
    expect(phone.mailDomain).toBe('city-mail.test')
  })

  it('updates account validation, recipients and localized hints after a panel save', () => {
    const phone = usePhoneStore()
    const address = computed(() =>
      normalizeMailAddress('Alex', phone.mailDomain),
    )
    const recipients = computed(() =>
      parseMailRecipients('Alex; Jamie', phone.mailDomain),
    )
    const hint = computed(() =>
      phone.t('Apps.mail.registerBody', { domain: phone.mailDomain }),
    )

    phone.open({ mailDomain: 'city.example' })
    expect(address.value).toBe('alex@city.example')
    expect(hint.value).toBe('Choose your new @city.example address.')

    phone.open({ mailDomain: 'mail.example' })
    expect(address.value).toBe('alex@mail.example')
    expect(recipients.value).toEqual([
      'alex@mail.example',
      'jamie@mail.example',
    ])
    expect(hint.value).toBe('Choose your new @mail.example address.')
    expect(
      phone.t('Apps.mail.emailPlaceholder', { domain: phone.mailDomain }),
    ).toBe('name@mail.example')
    expect(
      phone.t('Apps.mail.recipientPlaceholder', { domain: phone.mailDomain }),
    ).toBe('name@mail.example')
    expect(
      normalizeMailAddress('alex@city.example', phone.mailDomain),
    ).toBeNull()
  })
})
