import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./BillingApp.vue', import.meta.url),
  'utf8',
)

describe('Billing app Sky UI migration', () => {
  it('uses Sky UI instead of Konsta components', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toMatch(/<\/?k[A-Z-]/)
    expect(source).not.toContain('--k-')

    for (const component of [
      'SkyAppPage',
      'SkyNavbar',
      'SkyNavbarBackLink',
      'SkyGlass',
      'SkyCard',
      'SkyBadge',
      'SkyButton',
      'SkyLink',
      'SkySearchbar',
      'SkySegmented',
      'SkySegmentedButton',
      'SkySpinner',
      'SkyTabBar',
      'SkyTabButton',
      'SkySheet',
      'SkyNotification',
    ]) {
      expect(source).toContain(`<${component}`)
    }
  })

  it('uses the Sky sheet focus and escape behavior for payment', () => {
    expect(source).toContain('@escape="paymentOpen = false"')
    expect(source).toContain(':ariaLabelledby=')
  })

  it('shows the Billing icon and localized name as one navbar brand', () => {
    expect(source).toContain('<span class="billing-navbar__brand">')
    expect(source).toContain(
      '<SkyIcon :icon="ReceiptText" :size="22" :stroke-width="2" />',
    )
    expect(source).toContain("<strong>{{ t('name') }}</strong>")
  })

  it('blends every navbar into dark and light page backgrounds', () => {
    expect(source).toMatch(
      /\.billing-navbar::after\s*\{[^}]*bottom:\s*-18px;[^}]*height:\s*18px;[^}]*linear-gradient\(to bottom, rgb\(7 9 12 \/ 88%\), transparent\);/s,
    )
    expect(source).toMatch(
      /\.billing-app--light \.billing-navbar::after\s*\{[^}]*linear-gradient\(to bottom, rgb\(245 247 250 \/ 88%\), transparent\);/s,
    )
  })

  it('keeps every overview box icon white', () => {
    expect(source).toMatch(
      /\.billing-summary__item svg\s*\{[^}]*color:\s*#fff;/s,
    )
    expect(source).not.toContain('.billing-summary__item--open svg')
    expect(source).not.toContain('.billing-summary__item--due svg')
    expect(source).not.toContain('.billing-summary__item--overdue svg')
  })

  it('aligns invoice information and note with the detail hero edges', () => {
    expect(source).toMatch(
      /\.billing-panel,\s*\.billing-note\s*\{[^}]*margin-right:\s*0;[^}]*margin-left:\s*0;/s,
    )
  })

  it('presents pay and dispute as a matched action pair', () => {
    expect(source).toContain('class="billing-action billing-action--pay"')
    expect(source).toContain('class="billing-action billing-action--dispute"')
    expect(source).toContain('variant="secondary"')
    expect(source).toMatch(
      /\.billing-detail__actions\s*\{[^}]*grid-template-columns:\s*repeat\(2, minmax\(0, 1fr\)\);/s,
    )
    expect(source).toMatch(
      /\.billing-detail__actions :deep\(\.sky-button\)\s*\{[^}]*height:\s*44px;[^}]*border-radius:\s*14px;/s,
    )
    expect(source).toMatch(
      /@media \(hover: hover\)\s*\{[^}]*\.billing-detail__actions :deep\(\.billing-action:hover\)\s*\{[^}]*transform:\s*translateY\(-2px\);/s,
    )
    expect(source).toContain(
      ':deep(.billing-action:hover .billing-action-chevron)',
    )
  })

  it('keeps the invoice and payment information heading readable', () => {
    expect(source).toMatch(
      /\.billing-detail__section-title\s*\{[^}]*font-size:\s*11px;/s,
    )
  })

  it('keeps the Overview brand in main and detail headers', () => {
    expect(source).toContain('<template #title>')
    expect(source).toContain('<template v-if="screen === \'detail\'" #left>')
    expect(source).not.toContain(':subtitle=')
    expect(source).not.toContain("t('detail.title')")
  })

  it('identifies Inbox and History with content headings', () => {
    expect(source).toContain('<header class="billing-view-heading">')
    expect(source).toContain(
      '<SkyIcon :icon="Inbox" v-if="tab === \'inbox\'" :size="20" />',
    )
    expect(source).toContain('<SkyIcon :icon="History" v-else :size="20" />')
    expect(source).toContain('<h1>{{ t(`tabs.${tab}`) }}</h1>')
    expect(source).toMatch(
      /\.billing-view-heading h1\s*\{[^}]*font-size:\s*23px;/s,
    )
  })

  it('keeps overview invoice cards vertically compact', () => {
    expect(source).toMatch(
      /\.billing-invoice-card\s*\{[^}]*min-height:\s*88px;[^}]*padding:\s*11px 13px;/s,
    )
    expect(source).toMatch(
      /\.billing-invoice-card__amount\s*\{[^}]*grid-template-columns:\s*auto 17px;[^}]*row-gap:\s*5px;/s,
    )
    expect(source).toMatch(
      /\.billing-invoice-card__amount \.billing-status\s*\{[^}]*grid-column:\s*1 \/ -1;/s,
    )
  })
})
