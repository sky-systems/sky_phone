import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./CryptoApp.vue', import.meta.url), 'utf8')
const logoSource = readFileSync(
  new URL('../../components/crypto/CryptoLogo.vue', import.meta.url),
  'utf8',
)
const server = readFileSync(
  new URL('../../../../sky_phone/source/server/crypto.lua', import.meta.url),
  'utf8',
)
const passwordProvider = readFileSync(
  new URL(
    '../../../../sky_phone/source/server/crypto_password.js',
    import.meta.url,
  ),
  'utf8',
)
const config = readFileSync(
  new URL('../../../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
)
const testServer = readFileSync(
  new URL('../../../testserver/index.cjs', import.meta.url),
  'utf8',
)

describe('VaultX crypto app contracts', () => {
  it('uses Sky UI without introducing Konsta components', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    for (const component of [
      'SkyAppPage',
      'SkyNavbar',
      'SkyScrollArea',
      'SkyField',
      'SkyButton',
      'SkySheet',
      'SkyPillNavigation',
      'SkySegmented',
    ]) {
      expect(source).toContain(`<${component}`)
    }
  })

  it('shows distinct icons in every primary navigation item', () => {
    expect(source).toContain('<WalletCards')
    expect(source).toContain('<ChartNoAxesCombined')
    expect(source).toContain('<History')
    expect(source).toContain('<UserRound')
    expect(source).toMatch(
      /\.sky-pill-navigation \.sky-segmented-button--active\)\s*\{\s*color:\s*#fff;/,
    )
  })

  it('includes advanced market detail and persistent profile controls', () => {
    expect(source).toContain('selected.priceHistory')
    expect(source).toContain('const detailChart = computed')
    expect(source).toContain('CHART_PERIOD_CONFIG[period.value]')
    expect(source).toContain('class="detail-chart__marker"')
    expect(source).toContain('v-for="tick in detailChart.yTicks"')
    expect(source).toContain('v-for="value in CHART_PERIODS"')
    expect(source).toContain(':aria-pressed="period === value"')
    expect(source).toContain("t('marketDetail.statistics')")
    expect(source).toContain('class="detail-trade-dock"')
    expect(source).toContain('class="vault-view vault-detail-scroll"')
    expect(source).toContain('class="trade-side-selector"')
    expect(source).toContain('class="trade-entry-card"')
    expect(source).toContain('class="trade-protection"')
    expect(source).toContain('crypto.pendingQuote = null')
    expect(source).toContain('<SkyToggle')
    expect(server).toContain('sky_phone:crypto:update-profile')
    expect(server).toContain('`price_alerts`')
  })

  it('supports secure profile editing and header sign out', () => {
    expect(source).toContain('class="profile-signout"')
    expect(source).toContain("<span>{{ t('logout') }}</span>")
    expect(source).toContain('@click="logoutDialogOpen = true"')
    expect(source).toContain(':opened="logoutDialogOpen"')
    expect(source).toContain("t('logoutConfirm.title')")
    expect(source).toContain("t('logoutConfirm.cancel')")
    expect(source).toContain("'logoutConfirm.confirm'")
    expect(source).toContain('@click="signOut"')
    expect(source).not.toMatch(/icon-only\s+class="profile-signout"/)
    expect(source).toContain('class="profile-edit-button"')
    expect(source).toContain("sheet.value = 'profile'")
    expect(source).toContain('v-model="profileCurrentPassword"')
    expect(source).toContain('v-model="profileNewPassword"')
    expect(server).toContain(
      'verify_password(profile.id, data.currentPassword)',
    )
    expect(server).toContain('CryptoHashPassword(new_password)')
  })

  it('keeps registration focused and crypto-key transfers server-authoritative', () => {
    const transferServer = server.slice(
      server.indexOf('local function execute_transfer'),
      server.indexOf('Bridge.Callbacks.Register("sky_phone:crypto:quote"'),
    )

    expect(source).toContain('class="auth-account"')
    expect(source).toContain('<img :src="cryptoHeaderLogo" alt="" />')
    expect(source).not.toContain(
      '<span class="auth-hero__mark"><ChartCandlestick',
    )
    expect(source).toContain(
      "import { useAccountStore } from '@/stores/account'",
    )
    expect(source).toContain("account.email || t('auth.accountMissing')")
    expect(source).not.toContain('v-model="confirmPassword"')
    expect(source).not.toContain('v-model="acceptedTerms"')
    expect(source).not.toContain('class="password-strength"')
    expect(source).not.toContain('class="auth-status"')
    expect(source).toContain('class="auth-shell"')
    expect(source).toMatch(/<SkyNavbar\s+v-if="authenticated"/)
    expect(source).not.toContain('class="auth-benefits"')
    expect(source).not.toContain('class="auth-panel__heading"')
    expect(source).not.toContain('class="auth-action-dock"')
    expect(source).not.toContain('class="password-rules"')
    expect(source).toContain('class="auth-password-hint"')
    expect(source).toContain("t('auth.ruleSpecial')")
    expect(source).toMatch(
      /\.auth-shell\s*\{[^}]*width:\s*100%;[^}]*max-width:\s*338px;/s,
    )
    expect(source).toMatch(
      /\.auth-field\s*\{[^}]*min-height:\s*68px;[^}]*border-radius:\s*17px;/s,
    )
    expect(source).toMatch(
      /\.auth-field :deep\(\.sky-field__input\)\s*\{[^}]*font-size:\s*16px;/s,
    )
    expect(source).toMatch(
      /\.auth-submit\s*\{[^}]*background:\s*var\(--vault-mint\);[^}]*box-shadow:\s*none;/s,
    )
    for (const selector of [
      'transfer-submit',
      'settlement-submit',
      'profile-save-button',
    ]) {
      expect(source).toMatch(
        new RegExp(
          `\\.${selector}\\s*\\{[^}]*background:\\s*var\\(--vault-mint\\);[^}]*box-shadow:\\s*none;`,
          's',
        ),
      )
    }
    for (const selector of [
      'detail-trade-action--buy',
      'detail-trade-action--sell',
      'trade-submit--buy',
      'trade-submit--sell',
    ]) {
      const rule = source.match(
        new RegExp(`\\.${selector}\\s*\\{([^}]*)\\}`, 's'),
      )
      expect(rule?.[1]).not.toContain('linear-gradient')
      expect(rule?.[1]).toContain('box-shadow: none')
    }
    expect(testServer).toContain('let cryptoRegistered = true')
    expect(testServer).toContain('registered: cryptoRegistered')
    expect(testServer).toContain(
      "cryptoRegistered = testScenario !== 'crypto-register'",
    )
    expect(testServer).toContain('cryptoPassword = password')
    expect(source).not.toContain('v-model="confirmPassword"')
    expect(source).not.toContain('<SkyCheckbox')
    expect(source).toContain("sheet.value = 'send'")
    expect(source).toContain('v-model="transferWalletKey"')
    expect(source).toContain('profile?.walletKey')
    expect(server).toContain('`crypto_key` CHAR(22)')
    expect(server).toContain(
      'Bridge.Callbacks.Register("sky_phone:crypto:recipient"',
    )
    expect(server).toContain(
      'Bridge.Callbacks.Register("sky_phone:crypto:transfer"',
    )
    expect(server).toContain("'transfer_out'")
    expect(server).toContain("'transfer_in'")
    expect(server).toContain('Bridge.Database.Transaction(queries)')
    expect(server).toContain('verify_password(profile.id, data.password)')
    expect(transferServer).not.toContain('"CASH"')
    expect(transferServer).not.toContain('Bridge.Framework.AddMoney')
    expect(transferServer).not.toContain('Bridge.Framework.RemoveMoney')
  })

  it('copies and shares the public account key through phone-owned flows', () => {
    expect(source).toContain("import { copyText } from '@/utils/clipboard'")
    expect(source).toContain(
      "import { useEasyShareStore } from '@/stores/easyshare'",
    )
    expect(source).toContain('class="wallet-key-card__actions"')
    expect(source).toContain('@click="copyWalletKey"')
    expect(source).toContain('@click="shareWalletKey"')
    expect(source).toContain("appId: 'crypto'")
    expect(source).toContain("kind: 'text'")
  })

  it('uses the premium dashboard hierarchy without manual refresh controls', () => {
    expect(source).toContain('class="portfolio-shell"')
    expect(source).toContain('class="featured-market"')
    expect(source).toContain('class="activity-status"')
    expect(source).toContain('class="profile-card"')
    expect(source).not.toContain('RefreshCw')
    expect(source).not.toContain(':aria-label="t(\'refresh\')"')
  })

  it('keeps portfolio quick actions concise and interactive', () => {
    const quickActions = source.slice(
      source.indexOf('<div class="quick">'),
      source.indexOf('<SkyCard class="allocation-card">'),
    )

    expect(quickActions).not.toContain('<small>')
    expect(source).toContain('@media (hover: hover) and (pointer: fine)')
    expect(source).toContain('.quick button:hover')
    expect(source).toContain('.quick button:focus-visible')
  })

  it('anchors portfolio performance history and forecast at the current position', () => {
    expect(source).toContain('const portfolioProfitLoss = computed')
    expect(source).toContain('class="portfolio-history"')
    expect(source).toContain('class="portfolio-forecast"')
    expect(source).toContain(':cx="portfolioChart.currentX"')
    expect(source).toContain(':cy="portfolioChart.currentY"')
    expect(source).toContain("t('portfolio.current')")
    expect(source).toContain('stroke-dasharray: 7 7')
  })

  it('uses the compact Flare-style navigation and polished overlay transitions', () => {
    const navbarTag = source.match(/<SkyNavbar[\s\S]*?>/)?.[0] ?? ''

    expect(source).toContain('class="vault-navbar"')
    expect(source).toContain('class="vault-header-logo"')
    expect(source).toContain(
      '<CryptoLogo class="vault-detail-logo" :market="detail" />',
    )
    expect(source).toContain('.vault-detail-title > span:last-child')
    expect(source).not.toMatch(/\.vault-detail-title > span\s*\{/)
    expect(source).not.toContain('vault-header-logo--detail')
    expect(source).not.toContain('class="coin-detail-logo"')
    expect(source).not.toContain('.vault-header-brand > i')
    expect(source).toContain(':show-back="Boolean(detail)"')
    expect(navbarTag).not.toMatch(/\slarge(?:\s|=|>)/)
    expect(source).toContain('class="vault-view"')
    expect(source).toContain('@keyframes vault-view-in')
    expect(source).toContain('class="sheet-header"')
    expect(source).not.toContain('class="sheet-close"')
    expect(source).toContain('class="sheet-market-summary"')
    expect(source).toContain('grabber-clickable')
    expect(source).toContain('@grabberclick="closeSheet"')
    expect(source).toContain('.crypto-app :deep(.sky-sheet__grabber::after)')
  })

  it('uses a wide close-free settlement form with composed fields', () => {
    expect(source).toContain(
      "'sheet--settlement': sheet === 'deposit' || sheet === 'withdraw'",
    )
    expect(source).toContain('class="settlement-form"')
    expect(source.match(/class="sheet-field settlement-field"/g)).toHaveLength(
      2,
    )
    expect(source).toContain('class="settlement-submit"')
    expect(source).toContain('.sheet-field :deep(.sky-field__border)')
  })

  it('gives profile editing a full-width field and save treatment', () => {
    expect(source).toContain("'sheet--profile': sheet === 'profile'")
    expect(source).toContain('class="profile-edit-fields"')
    expect(
      source.match(/class="sheet-field profile-edit-field"/g),
    ).toHaveLength(3)
    expect(source).toContain('autocomplete="current-password"')
    expect(source).toContain('autocomplete="new-password"')
    expect(source).toContain('class="profile-save-button"')
    expect(source.match(/class="sheet-field(?: [^"]+)?"/g)).toHaveLength(9)
  })

  it('keeps app typography readable on the scaled phone surface', () => {
    expect(source).not.toMatch(/font-size:\s*[6-8]px/)
    expect(source).toContain(':content-wrap="false"')
  })

  it('keeps the profile sign-out action free of a second navbar surface', () => {
    expect(source).toContain("'vault-navbar--profile'")
    expect(source).toContain('.crypto-app :deep(.sky-navbar__right)')
    expect(source).toContain('.crypto-app :deep(.vault-navbar--profile)')
    expect(source).toContain(
      '.crypto-app :deep(.vault-navbar--profile .sky-navbar__background)',
    )
    expect(source).toContain('background: transparent;')
    expect(source).toContain('backdrop-filter: none;')
  })

  it('groups the activity summary and icon filters into one VaultX hub', () => {
    expect(source).toContain('class="activity-overview"')
    expect(source).toContain('class="activity-filter-panel"')
    expect(source).toContain('class="activity-filters"')
    expect(source).toContain('class="activity-status__icon"')
    expect(source.match(/class="activity-filter-content"/g)).toHaveLength(3)
    expect(source).toContain('<WalletCards :size="15" />')
    expect(source).not.toContain('inset-inline-start: 10px;')
    expect(source).toContain('transform: translateY(1px);')
  })

  it('exposes a broad fictional market with dedicated logo marks', () => {
    const cryptoConfig = config.slice(
      config.indexOf('Config.Crypto = {'),
      config.indexOf('-- Server-only configuration'),
    )
    expect(cryptoConfig.match(/\n\s+Id = "/g)).toHaveLength(24)
    expect(cryptoConfig.match(/\n\s+Logo = "/g)).toHaveLength(24)
    expect(server).toContain('logo = config.Logo')
    expect(source).toContain('<CryptoLogo')
    expect(logoSource.match(/^  [a-z]+: \[/gm)).toHaveLength(24)
    for (const mark of [
      'ember',
      'crown',
      'orbit',
      'quantum',
      'moss',
      'flux',
      'tide',
      'shard',
      'pixel',
    ]) {
      expect(logoSource).toContain(`  ${mark}: [`)
    }
  })

  it('keeps all consequential calculations and state transitions on the server', () => {
    expect(server).toContain(
      'Bridge.Callbacks.Register("sky_phone:crypto:quote"',
    )
    expect(server).toContain(
      'Bridge.Callbacks.Register("sky_phone:crypto:execute"',
    )
    expect(server).toContain('`consumed_operation_id`')
    expect(server).toContain('`idempotency_key`')
    expect(server).toContain("`status` = 'manual_review'")
    expect(server).toContain('Bridge.Framework.RemoveMoney')
    expect(server).toContain('Bridge.Framework.AddMoney')
    expect(server).toContain('local function with_exchange_lock')
    expect(server).toContain('local function reconcile_settlements')
    expect(server).toContain('settlement_ledger_queries')
  })

  it('streams server-driven market movement into live portfolio values', () => {
    expect(config).toContain('PriceTickMinimumSeconds')
    expect(config).toContain('MarketsPerTickMaximum')
    expect(config).toContain('TickMovementDivisor')
    expect(config).toContain('CycleDurationMinimumTicks')
    expect(config).toContain('CycleStrengthMaximumBasisPoints')
    expect(config).toContain('GlobalCycleMinimumTicks')
    expect(config).toContain('MarketShockChanceBasisPoints')
    expect(server).toContain('local market_dynamics = {}')
    expect(server).toContain('global_market_trend')
    expect(server).toContain('local function advance_market_cycle')
    expect(server).toContain(
      'dynamics.cycle_direction = -dynamics.cycle_direction',
    )
    expect(server).toContain('local function advance_global_market_cycle')
    expect(server).toContain('Config.Crypto.MeanReversionBasisPoints')
    expect(server).toContain('TriggerClientEvent("sky_phone:crypto:changed"')
    expect(server).toContain('priceHistory = price_history')
    expect(source).toContain('selected.priceHistory')
    expect(source).toContain('4500 + Math.random() * 2500')
    expect(testServer).toContain('const cryptoMarketDynamics = new Map()')
    expect(testServer).toContain('function advanceCryptoCycle(')
  })

  it('stores cash in price-scale minor units throughout the ledger', () => {
    expect(server).toContain(
      'local ledger_amount = amount * Config.Crypto.PriceScale',
    )
    expect(server).toContain(
      'Config.Crypto.TreasuryCash * Config.Crypto.PriceScale',
    )
    expect(server).toContain(
      'amount = decimal_string(row.amount, Config.Crypto.PriceScale)',
    )
  })

  it('uses a memory-hard password provider with constant-time verification', () => {
    expect(passwordProvider).toContain('scryptSync')
    expect(passwordProvider).toContain('timingSafeEqual')
    expect(passwordProvider).toContain('randomBytes(16)')
    expect(server).not.toMatch(/data\.price\b/)
    expect(server).not.toMatch(/data\.fee\b/)
  })
})
