import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore } from '@/stores/phone'

describe('phone locale fallback', () => {
  beforeEach(() => {
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
    })
    setActivePinia(createPinia())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('keeps CityMarkt profile copy translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { citymarkt: { name: 'CityMarkt' } } } })

    expect(phone.t('Apps.citymarkt.editProfile')).toBe('Edit profile')
    expect(phone.t('Apps.citymarkt.profileIntro')).toBe(
      'Your iFruit email stays linked to this profile.',
    )
    expect(phone.t('Apps.citymarkt.saveProfile')).toBe('Save profile')
    expect(phone.t('Apps.citymarkt.addFavorite')).toBe('Add to favorites')
    expect(phone.t('Apps.citymarkt.removeFavorite')).toBe(
      'Remove from favorites',
    )
  })

  it('keeps mailbox and filter copy translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { mail: { name: 'Mail' } } } })

    expect(phone.t('Apps.mail.newMailbox')).toBe('New Mailbox')
    expect(phone.t('Apps.mail.mailboxNamePlaceholder')).toBe('Mailbox name')
    expect(phone.t('Apps.mail.filterTitle')).toBe('Filter')
    expect(phone.t('Apps.mail.filterUnreadLabel')).toBe('Unread')
    expect(phone.t('Apps.mail.errors.mailbox_exists')).toBe(
      'A mailbox with that name already exists.',
    )
  })

  it('keeps provider capability copy translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { radio: { name: 'Radio' } } } })

    expect(phone.t('Apps.radio.notSupported')).toBe('Not supported')
    expect(phone.t('Apps.radio.providerFeatureUnavailable')).toBe(
      'Not supported by this voice service',
    )
    expect(phone.t('Apps.radio.displayNamePlaceholder')).toBe('Character name')
  })

  it('keeps Messages media controls translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { messages: { name: 'Messages' } } } })

    expect(phone.t('Apps.messages.attachmentPreview')).toBe(
      'Selected attachments',
    )
    expect(phone.t('Apps.messages.attachmentLimit', { count: '6' })).toBe(
      'You can attach up to 6 photos or videos.',
    )
    expect(phone.t('Apps.messages.removeAttachment', { number: '2' })).toBe(
      'Remove attachment 2',
    )
    expect(phone.t('Apps.messages.seekAudio')).toBe('Seek Audio')
  })

  it('keeps VaultX wallet key actions translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { crypto: { name: 'VaultX' } } } })

    expect(phone.t('Apps.crypto.profile.walletKey')).toBe('Public crypto key')
    expect(phone.t('Apps.crypto.profile.walletKeyBody')).toBe(
      'Share this key to receive crypto. It cannot access your account.',
    )
    expect(phone.t('Apps.crypto.profile.copyKey')).toBe('Copy')
    expect(phone.t('Apps.crypto.profile.shareKey')).toBe('Share')
  })

  it('keeps CityWarn copy translated with a partial server locale', () => {
    const phone = usePhoneStore()
    phone.open({ locales: { Apps: { citywarn: { name: 'CityWarn' } } } })

    const cityWarnKeys = [
      'name',
      'navigation',
      'loading',
      'issuedBy',
      'updated',
      'expires',
      'affectedArea',
      'currentLocation',
      'details',
      'instructions',
      'timeline',
      'publishedBy',
      'radius',
      'emptyArchive',
      'emptyArchiveBody',
      'emptyFiltered',
      'emptyFilteredBody',
      'mapTitle',
      'mapBody',
      ...['active', 'map', 'archive', 'settings'].map((key) => `tabs.${key}`),
      ...['safe', 'safeBody', 'active', 'activeBody'].map(
        (key) => `hero.${key}`,
      ),
      ...['active', 'resolved', 'expired'].map((key) => `status.${key}`),
      ...['information', 'warning', 'danger', 'extreme'].map(
        (key) => `severity.${key}`,
      ),
      ...[
        'public_safety',
        'police',
        'fire',
        'medical',
        'infrastructure',
        'evacuation',
      ].map((key) => `categories.${key}`),
      ...['title', 'body', 'offDuty', 'unavailable'].map(
        (key) => `publisher.${key}`,
      ),
      ...[
        'new',
        'step',
        'categoryTitle',
        'categoryBody',
        'severityTitle',
        'areaTitle',
        'areaBody',
        'areaTypes.radius',
        'areaTypes.district',
        'areaTypes.city',
        'areaLabel',
        'areaPlaceholder',
        'radius',
        'useLocation',
        'locationSet',
        'contentTitle',
        'title',
        'titlePlaceholder',
        'body',
        'bodyPlaceholder',
        'instructions',
        'instructionsPlaceholder',
        'duration',
        'durationMinutes',
        'previewTitle',
        'recipients',
        'legal',
        'back',
        'next',
        'publish',
        'publishing',
        'success',
      ].map((key) => `compose.${key}`),
      ...[
        'update',
        'resolve',
        'updateTitle',
        'resolveTitle',
        'updatePlaceholder',
        'resolvePlaceholder',
        'send',
        'confirm',
        'success',
        'resolved',
      ].map((key) => `manage.${key}`),
      ...[
        'locationTitle',
        'locationBody',
        'levelTitle',
        'levelBody',
        'categoryTitle',
        'categoryBody',
        'notificationHint',
      ].map((key) => `settings.${key}`),
      ...['published', 'update', 'resolved'].map(
        (key) => `notifications.${key}`,
      ),
      ...[
        'feature_disabled',
        'not_authorized',
        'invalid_warning',
        'invalid_update',
        'active_limit',
        'revision_conflict',
        'rate_limited',
        'request_failed',
        'not_found',
        'device_not_open',
        'device_not_owned',
        'device_locked',
        'default',
      ].map((key) => `errors.${key}`),
    ]

    for (const key of cityWarnKeys) {
      const path = `Apps.citywarn.${key}`
      expect(phone.t(path), path).not.toBe(path)
    }
    expect(phone.t('Apps.citywarn.compose.recipients', { count: '42' })).toBe(
      'About 42 people are currently reachable.',
    )
  })

  it('uses the English Lua payload before the bundled emergency fallback', () => {
    const phone = usePhoneStore()
    phone.open({
      fallbackLocales: {
        Common: {
          cancel: 'Cancel from en.lua',
          save: 'Save from en.lua',
        },
      },
      locales: { Common: { save: 'Speichern' } },
    })

    expect(phone.t('Common.save')).toBe('Speichern')
    expect(phone.t('Common.cancel')).toBe('Cancel from en.lua')
    expect(phone.t('Common.close')).toBe('Close')
  })

  it('keeps call and camera controls readable with older client locales', () => {
    const phone = usePhoneStore()
    phone.open({
      locales: {
        Apps: { camera: { name: 'Kamera' }, phone: { name: 'Telefon' } },
        HardwareButtons: { lock: 'Handy sperren' },
      },
      fallbackLocales: {
        Apps: { camera: { name: 'Camera' }, phone: { name: 'Phone' } },
      },
    })

    expect(phone.t('HardwareButtons.unlock')).toBe('Unlock phone')
    expect(phone.t('Apps.phone.returnToCall')).toBe('Return to Call')
    expect(phone.t('Apps.camera.lockCamera')).toBe('Lock camera movement')
    expect(phone.t('Apps.camera.unlockCamera')).toBe('Unlock camera movement')
    expect(phone.t('Apps.camera.lookKey')).toBe('Look')
    expect(phone.t('Apps.camera.name')).toBe('Kamera')
    expect(phone.t('Apps.phone.name')).toBe('Telefon')
  })
})
