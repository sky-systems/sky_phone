import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./CompaniesApp.vue', import.meta.url),
  'utf8',
)
const testserverSource = readFileSync(
  new URL('../../../testserver/index.cjs', import.meta.url),
  'utf8',
)
const requestListClassIndex = source.indexOf('company-request-list')
const requestListStart = source.lastIndexOf(
  '<SkyListCard',
  requestListClassIndex,
)
const requestListSource = source.slice(
  requestListStart,
  source.indexOf('</SkyListCard>', requestListStart) + '</SkyListCard>'.length,
)

describe('CompaniesApp request card contract', () => {
  it('keeps the screenshot hierarchy and request state visible', () => {
    expect(requestListStart).toBeGreaterThan(-1)
    expect(requestListSource).toMatch(/:header=\x22item\.companyName\x22/)
    expect(requestListSource).toMatch(/:title=\x22item\.subject\x22/)
    expect(requestListSource).toMatch(
      /:subtitle=\x22requestSubtitle\(item\)\x22/,
    )
    expect(requestListSource).toMatch(
      /<SkyIcon :icon="ClipboardList" :size=\x2219\x22/,
    )
    expect(requestListSource).toMatch(/v-if=\x22item\.unreadCount\x22/)
    expect(requestListSource).toContain('item.unreadCount')
    expect(requestListSource).toMatch(
      /:class=\x22statusClass\(item\.status\)\x22/,
    )
    expect(requestListSource).toContain(
      'Apps.companies.requestStatuses.${item.status}',
    )
    expect(requestListSource).toMatch(/openRequest\(item\.id, 'customer'\)/)
  })

  it('uses separate token-based request surfaces instead of hardcoded colors', () => {
    expect(source).toMatch(
      /\.company-request-list \{[\s\S]*?display: grid;[\s\S]*?gap: var\(--sky-space-2\);[\s\S]*?background: transparent;[\s\S]*?\}/,
    )
    expect(source).toMatch(
      /\.company-request-list :deep\(\.sky-list-item\) \{[\s\S]*?border: 1px solid var\(--company-border\);[\s\S]*?border-radius: var\(--sky-radius-card\);[\s\S]*?background: var\(--company-surface\);[\s\S]*?\}/,
    )
  })

  it('retains the in-progress reference request in the browser mock', () => {
    expect(testserverSource).toMatch(/name: [\x22']Benny's Motor Works[\x22']/)
    expect(testserverSource).toMatch(/subject: 'Vehicle will not start'/)
    expect(testserverSource).toMatch(/serviceName: 'Roadside Assistance'/)
    expect(testserverSource).toMatch(/status: 'in_progress'/)
    expect(testserverSource).toContain('unreadCount: 1')
  })
})
