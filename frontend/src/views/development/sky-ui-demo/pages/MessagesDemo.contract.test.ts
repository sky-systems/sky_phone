import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./MessagesDemo.vue', import.meta.url),
  'utf8',
)

describe('MessagesDemo Konsta parity', () => {
  it('uses the real scroll owner without tabbar padding', () => {
    expect(source).not.toContain('with-tabbar')
    expect(source).toContain("closest('.sky-scroll-area')")
    expect(source).toContain(
      'scrollArea.scrollHeight - scrollArea.clientHeight',
    )
    expect(source.indexOf('</SkyMessages>')).toBeLessThan(
      source.indexOf('ref="messagesEnd"'),
    )
    expect(source).toMatch(
      /\.sky-ui-demo-messages__end\s*\{[\s\S]*?height:\s*36px;/,
    )
  })

  it('keeps the camera and send actions at 20px and 28px', () => {
    expect(source).toContain('<SkyIcon :size="20"><Camera /></SkyIcon>')
    expect(source).toContain('<SkyIcon :size="28"><CircleArrowUp /></SkyIcon>')
    expect(source.match(/component="button"/g)).toHaveLength(2)
  })
})
