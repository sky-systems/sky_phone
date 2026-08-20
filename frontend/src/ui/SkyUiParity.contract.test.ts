import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import {
  SkyActionButton,
  SkyActionGroup,
  SkyBadge,
  SkyButton,
  SkyCard,
  SkyChip,
  SkyDialog,
  SkyField,
  SkyListItem,
  SkyMessage,
  SkyMessagebar,
  SkyMenuList,
  SkyMenuListItem,
  SkySearchbar,
  SkyScrollArea,
  SkySpinner,
  SkyToast,
} from '@/ui'

async function render(
  component: Parameters<typeof h>[0],
  props: Record<string, unknown> = {},
  slots?: Record<string, () => ReturnType<typeof h> | string>,
): Promise<string> {
  return renderToString(
    createSSRApp({ render: () => h(component, props, slots) }),
  )
}

describe('Sky UI Konsta 5.3 parity contracts', () => {
  it('keeps Page content edge-to-edge unless padded compatibility is explicit', async () => {
    const edgeToEdge = await render(
      SkyScrollArea,
      {},
      { default: () => 'Content' },
    )
    const padded = await render(
      SkyScrollArea,
      { padded: true },
      { default: () => 'Content' },
    )

    expect(edgeToEdge).toContain('class="sky-scroll-area"')
    expect(edgeToEdge).not.toContain('sky-scroll-area--padded')
    expect(padded).toContain('sky-scroll-area--padded')
  })

  it('keeps Field styling on its root while forwarding native attrs to the control', async () => {
    const html = await render(SkyField, {
      class: 'native-input-class',
      'data-native': 'yes',
      inputId: 'native-input',
      placeholder: 'Name',
    })

    const rootTag = html.match(/^<li[^>]*>/)?.[0]
    const inputTag = html.match(/<input[^>]*>/)?.[0]

    expect(rootTag).toMatch(/class="[^"]*\bsky-field\b/)
    expect(rootTag).toContain('native-input-class')
    expect(rootTag).not.toContain('sky-field--error')
    expect(rootTag).not.toContain('data-native')
    expect(inputTag).not.toContain('native-input-class')
    expect(inputTag).toContain('data-native="yes"')
  })

  it('uses Konsta iOS defaults for Badge, Button, Messagebar, Message and Spinner', async () => {
    const [badge, button, messagebar, message, spinner] = await Promise.all([
      render(SkyBadge),
      render(SkyButton, {}, { default: () => 'Continue' }),
      render(SkyMessagebar),
      render(SkyMessage, {}, { default: () => 'Sent' }),
      render(SkySpinner),
    ])

    expect(badge).toContain('sky-badge--primary')
    expect(button).not.toContain('sky-button--inline')
    expect(messagebar).not.toContain('sky-messagebar--outline')
    expect(message).toMatch(/^<div[^>]*sky-message--sent/)
    expect(spinner).toContain('width:32px')
    expect(spinner.match(/<path/g)).toHaveLength(8)
    expect(spinner).not.toContain('<i')
  })

  it('keeps the main ListItem migration hooks and slot geometry', async () => {
    const html = await render(
      SkyListItem,
      {
        after: 'Now',
        contentClass: 'custom-content',
        dividers: true,
        href: '/details',
        innerClass: 'custom-inner',
        media: 'M',
        mediaClass: 'custom-media',
        target: '_blank',
        text: 'Body',
        title: 'Title',
        titleWrapClass: 'custom-title-wrap',
      },
      {
        content: () => h('span', { class: 'custom-content-slot' }, 'Content'),
        default: () => h('span', { class: 'custom-default-slot' }, 'Default'),
        inner: () => h('span', { class: 'custom-inner-slot' }, 'Inner'),
      },
    )

    expect(html).toContain('<a')
    expect(html).toContain('href="/details"')
    expect(html).toContain('target="_blank"')
    expect(html).toContain('sky-list-item--dividers')
    expect(html).toContain('sky-list-item__title-wrap custom-title-wrap')
    expect(html).toContain('custom-content')
    expect(html).toContain('custom-inner')
    expect(html).toContain('custom-media')
    expect(html).toContain('custom-content-slot')
    expect(html.indexOf('custom-default-slot')).toBeGreaterThan(
      html.indexOf('</a>'),
    )
    expect(html).toContain('custom-inner-slot')
    expect(html).toContain('<div class="sky-list-item__title')
  })

  it('marks MenuList and forwards inherited MenuListItem content', async () => {
    const app = createSSRApp({
      render: () =>
        h(
          SkyMenuList,
          { dividers: false, outline: true },
          {
            default: () =>
              h(SkyMenuListItem, {
                active: true,
                footer: 'Footer',
                text: 'Text',
                title: 'Entry',
              }),
          },
        ),
    })
    const html = await renderToString(app)

    expect(html).toContain('sky-list--menu')
    expect(html).toContain('sky-list--outline')
    expect(html).toContain('sky-menu-list-item--active')
    expect(html).toContain('Text')
    expect(html).toContain('Footer')
  })

  it('exposes Searchbar migration props without unnamed action buttons', async () => {
    const html = await render(SkySearchbar, {
      clearLabel: 'Clear query',
      component: 'form',
      disableButton: true,
      disableLabel: 'Close search',
      inputId: 'directory-search',
      modelValue: 'sky',
    })

    expect(html).toContain('<form')
    expect(html).toContain('id="directory-search"')
    expect(html).toContain('sky-glass')
    expect(html).not.toContain('sky-glass--highlight')
    expect(html).toContain('<svg class="sky-searchbar__icon"')
    expect(html).toContain('fill-rule="evenodd"')
    expect(html).not.toContain('<circle')
    expect(html).toContain('sky-searchbar__clear')
    expect(html).toContain('aria-label="Clear query"')
    expect(html).toContain('sky-searchbar__disable')
    expect(html).toContain('aria-label="Close search"')
  })

  it('renders added Chip, Badge, and Card variants', async () => {
    const chip = await render(
      SkyChip,
      { deleteButton: true, deleteLabel: 'Remove', outline: true },
      {
        default: () => 'Tag',
        media: () => h('span', 'M'),
      },
    )
    const badge = await render(SkyBadge, { component: 'strong', small: true })
    const card = await render(
      SkyCard,
      { contentWrapPadding: 'custom-padding' },
      { default: () => 'Body' },
    )

    expect(chip).toContain('sky-chip--outline')
    expect(chip).toContain('sky-chip__media')
    expect(chip).toContain('sky-chip__delete')
    expect(chip).toContain('aria-label="Remove"')
    expect(badge).toContain('<strong')
    expect(badge).toContain('sky-badge--small')
    expect(card).toContain('sky-card__content custom-padding')
  })

  it('keeps overlay component, backdrop, slot, and position parity', async () => {
    const dialog = await render(
      SkyDialog,
      { backdrop: false, opened: true },
      {
        buttons: () => h('button', 'OK'),
        title: () => h('span', 'Title slot'),
      },
    )
    const toast = await render(
      SkyToast,
      { opened: true, position: 'right', verticalPosition: 'center' },
      {
        button: () => h('button', 'Undo'),
        default: () => 'Saved',
      },
    )
    const actionGroup = await render(
      SkyActionGroup,
      { component: 'section', dividers: false },
      { default: () => h(SkyActionButton, { href: '/action' }, () => 'Open') },
    )

    expect(dialog).toContain('Title slot')
    expect(dialog).not.toContain('sky-overlay-backdrop')
    expect(toast).toContain('sky-toast--right')
    expect(toast).toContain('sky-toast--vertical-center')
    expect(toast).toContain('sky-toast__button')
    expect(actionGroup).toContain('<section')
    expect(actionGroup).not.toContain('sky-action-group--dividers')
    expect(actionGroup).toContain('<a')
    expect(actionGroup).toContain('href="/action"')
  })

  it('keeps Konsta glass blur optional over a solid fallback', () => {
    const uiDirectory = fileURLToPath(new URL('.', import.meta.url))
    const sources = ['controls.css', 'foundation.css', 'overlays.css'].map(
      (file) => readFileSync(`${uiDirectory}/${file}`, 'utf8'),
    )
    const combined = sources.join('\n')

    expect(combined).toContain('--sky-shadow-glass')
    expect(combined).toContain('var(--sky-glass-solid')
    expect(combined).toMatch(/@supports[\s\S]*backdrop-filter/)
    expect(combined).toContain('sky-glass--highlight-visible')
    expect(combined).toContain('sky-glass--touch-highlight')
    expect(combined).toContain('sky-glass-surface')
    expect(combined).toContain('var(--sky-navbar-glass, var(--sky-bg))')
  })

  it('locks visible iOS geometry while keeping touch expansion invisible', () => {
    const uiDirectory = fileURLToPath(new URL('.', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')
    const overlays = readFileSync(`${uiDirectory}/overlays.css`, 'utf8')

    expect(controls).toMatch(
      /\.sky-button\s*\{[^}]*height:\s*34px[^}]*min-height:\s*34px[^}]*padding:\s*4px 8px/s,
    )
    expect(controls).toMatch(
      /\.sky-button--small\s*\{[^}]*height:\s*28px[^}]*min-height:\s*28px[^}]*padding-inline:\s*8px/s,
    )
    expect(controls).toMatch(
      /\.sky-button::before\s*\{[^}]*width:\s*max\(100%, var\(--sky-touch-target, 44px\)\)[^}]*inset-block:\s*-5px/s,
    )
    expect(controls).not.toMatch(
      /\.sky-button:active:not\(:disabled\)\s*\{[^}]*transform:/s,
    )
    expect(controls).toMatch(
      /\.sky-checkbox__mark\s*\{[^}]*width:\s*22px[^}]*height:\s*22px/s,
    )
    expect(controls).toMatch(
      /\.sky-list-item__title-wrap\s*\{[^}]*min-height:\s*28px/s,
    )
    expect(controls).toMatch(
      /\.sky-list-item__row\s*\{[^}]*gap:\s*0[^}]*padding:\s*0 0 0 calc\(var\(--sky-safe-area-left\) \+ 16px\)/s,
    )
    expect(controls).toMatch(
      /\.sky-list-item__media\s*\{[^}]*margin-right:\s*16px[^}]*padding:\s*8px 0/s,
    )
    expect(controls).toMatch(
      /\.sky-list-item__content\s*\{[^}]*padding:\s*12px calc\(var\(--sky-safe-area-right\) \+ 16px\) 12px 0/s,
    )
    expect(controls).toMatch(
      /\.sky-block-title \+ \.sky-block-header,[\s\S]*?\.sky-block-title \+ \.sky-block-footer,[\s\S]*?\{[\s\S]*?margin-top:\s*8px;/,
    )
    expect(controls).toContain(
      '.sky-list-item--dividers:not(.sky-list-item--menu)',
    )
    expect(controls).toMatch(
      /\.sky-radio__mark\s*\{[^}]*width:\s*22px[^}]*height:\s*22px/s,
    )
    expect(controls).toMatch(
      /\.sky-toggle__track\s*\{[^}]*width:\s*64px[^}]*height:\s*28px/s,
    )
    expect(controls).toMatch(/\.sky-range__input\s*\{[^}]*height:\s*28px/s)
    expect(controls).toMatch(
      /\.sky-spinner__svg\s*\{[^}]*animation:\s*sky-spinner-spin 1s steps\(8, end\) infinite/s,
    )
    expect(controls).toMatch(
      /\.sky-list-item--group-title\.sky-list-item--contacts\s*\{[^}]*background:\s*var\(--sky-list-group-title-contacts-background[^}]*color:\s*var\(--sky-list-group-title-contacts-text/s,
    )
    expect(overlays).toMatch(/\.sky-action-button\s*\{[^}]*font-size:\s*20px/s)
    expect(overlays).toMatch(/\.sky-messages\s*\{[^}]*margin-bottom:\s*48px/s)
  })
})
