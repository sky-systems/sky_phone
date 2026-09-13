import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./CompaniesApp.vue', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const apostrophe = String.fromCharCode(39)
const quote = String.fromCharCode(34)

function sourceBlock(startMarker: string, endMarker: string) {
  const start = source.indexOf(startMarker)
  const end = source.indexOf(endMarker, start)

  expect(start).toBeGreaterThanOrEqual(0)
  expect(end).toBeGreaterThan(start)
  return source.slice(start, end)
}

describe('CompaniesApp outbound service-line dialer contract', () => {
  it('uses the server service capability for automatic numbers without pretending the SIM is registered', () => {
    const capability = sourceBlock(
      'const canUseServiceRequests = computed(',
      'const requestProgress = computed(',
    )
    expect(capability).toContain('sim.servicesAllowed ?? sim.registered')
    const composer = sourceBlock(
      'const requestProgress = computed(',
      'const canSendThreadMessage = computed(',
    )
    expect(composer).toContain('canUseServiceRequests.value')
    expect(composer).not.toContain('sim?.registered')
    expect(source).toContain(
      'v-if="canUseServiceRequests && phone.device?.sim"',
    )
  })
  it('gates the work action and its opener by service-line permission', () => {
    const openDialer = sourceBlock(
      'function openServiceLineDialer()',
      '\n\nfunction closeServiceLineDialer()',
    )
    const workAction = sourceBlock(
      `phone.t(${apostrophe}Apps.companies.work.takeCalls${apostrophe})`,
      `phone.t(${apostrophe}Apps.companies.manager.title${apostrophe})`,
    )

    expect(openDialer).toContain(
      'if (!companies.workContext?.permissions.canTakeCalls) return',
    )
    expect(workAction).toContain(
      `v-if=${quote}companies.workContext.permissions.canTakeCalls${quote}`,
    )
    expect(workAction).toContain(`@click=${quote}openServiceLineDialer${quote}`)
    expect(workAction).toContain('Apps.companies.work.dialServiceLine')
  })

  it('uses a Sky sheet and telephone field for the target number', () => {
    const sheet = sourceBlock(
      `<div class=${quote}companies-sheet companies-service-line-sheet${quote}>`,
      `<div class=${quote}companies-sheet companies-assignment-sheet${quote}>`,
    )

    expect(sheet).toContain('<SkySheet')
    expect(sheet).toContain(`:opened=${quote}serviceLineSheetOpened${quote}`)
    expect(sheet).toContain(
      `<SkyList inset strong class=${quote}service-line-sheet__form${quote}>`,
    )
    expect(sheet).toContain('<SkyField')
    expect(sheet).not.toMatch(/<SkyField\s+outline/)
    expect(sheet).toContain(`type=${quote}tel${quote}`)
    expect(sheet).toContain(`:value=${quote}serviceLineTarget${quote}`)
    expect(sheet).toContain(`:disabled=${quote}!canDialServiceLine${quote}`)
    expect(sheet).toContain(`@click=${quote}dialServiceLine${quote}`)
  })

  it('applies the authoritative call state before opening the Phone app', () => {
    const dial = sourceBlock(
      'async function dialServiceLine()',
      '\n\nfunction syncManagerDraft(',
    )
    const applyIndex = dial.indexOf('calls.applyCallState(response.data)')
    const routeIndex = dial.indexOf(
      `await router.push(${apostrophe}/apps/phone${apostrophe})`,
    )

    expect(dial).toContain('companies.dialServiceLine(')
    expect(dial).toContain('serviceLineTarget.value.trim()')
    expect(applyIndex).toBeGreaterThanOrEqual(0)
    expect(routeIndex).toBeGreaterThan(applyIndex)
  })
})
