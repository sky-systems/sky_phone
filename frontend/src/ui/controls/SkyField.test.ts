import { readFileSync } from 'node:fs'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyField from '@/ui/controls/SkyField.vue'

describe('SkyField', () => {
  it('forwards min, max, and step to the native input', async () => {
    const app = createSSRApp(SkyField, {
      ariaLabel: 'Primary frequency',
      max: 999.9,
      min: 0.1,
      step: 0.1,
      type: 'number',
    })

    const html = await renderToString(app)
    const input = html.match(/<input[^>]+>/)?.[0] ?? ''

    expect(input).toContain('aria-label="Primary frequency"')
    expect(input).toContain('max="999.9"')
    expect(input).toContain('min="0.1"')
    expect(input).toContain('step="0.1"')
  })

  it('exposes the inline settings layout without changing input semantics', async () => {
    const app = createSSRApp(SkyField, {
      label: 'Service number',
      layout: 'inline',
      modelValue: '231',
    })

    const html = await renderToString(app)

    expect(html).toContain('sky-field--inline')
    expect(html).toMatch(/<label[^>]+for="([^"]+)"/)
    expect(html).toContain('value="231"')
  })

  it('keeps the leading alias on the canonical Konsta media column', async () => {
    const app = createSSRApp({
      render: () =>
        h(
          SkyField,
          { label: 'Primary frequency' },
          { leading: () => h('span', 'icon') },
        ),
    })

    const html = await renderToString(app)

    expect(html).toContain('sky-field--has-leading')
    expect(html).toContain('sky-field--has-media')
    expect(html).toContain('class="sky-field__media"')
    expect(html.indexOf('sky-field__media')).toBeLessThan(
      html.indexOf('sky-field__inner'),
    )
  })

  it('renders canonical media, inner, label, and control nesting', async () => {
    const app = createSSRApp({
      render: () =>
        h(
          SkyField,
          { label: 'Name' },
          { media: () => h('img', { alt: 'icon', src: '/demo.png' }) },
        ),
    })

    const html = await renderToString(app)

    expect(html).toMatch(
      /<span class="sky-field__media">[\s\S]*?<\/span><div class="sky-field__inner"><label[\s\S]*?<div class="sky-field__control">/,
    )
  })

  it('forwards text-entry hints to the native input', async () => {
    const app = createSSRApp(SkyField, {
      autocapitalize: 'none',
      autocomplete: 'off',
      autocorrect: 'off',
      pattern: '[A-Z0-9]+',
      spellcheck: false,
      type: 'text',
    })

    const html = await renderToString(app)
    const input = html.match(/<input[^>]+>/)?.[0] ?? ''

    expect(input).toContain('autocapitalize="none"')
    expect(input).toContain('autocomplete="off"')
    expect(input).toContain('autocorrect="off"')
    expect(input).toContain('pattern="[A-Z0-9]+"')
    expect(input).toContain('spellcheck="false"')
  })

  it('renders a native date input without changing its accessible label', async () => {
    const app = createSSRApp(SkyField, {
      id: 'birthday',
      label: 'Birthday',
      modelValue: '2014-04-30',
      type: 'date',
    })

    const html = await renderToString(app)

    expect(html).toContain('<label class="sky-field__label" for="birthday"')
    expect(html).toMatch(
      /<input[^>]+id="birthday"[^>]+type="date"[^>]+value="2014-04-30"/,
    )
  })

  it('renders typed select options and native options from the default slot', async () => {
    const options = [
      { label: 'Male', value: 'male' },
      { disabled: true, label: 'Unavailable', value: 0 },
    ] as const
    const app = createSSRApp({
      render: () =>
        h(
          SkyField,
          {
            ariaLabel: 'Gender',
            modelValue: 'male',
            options,
            placeholder: 'Please choose...',
            type: 'select',
          },
          {
            default: () => h('option', { value: 'custom' }, 'Custom'),
          },
        ),
    })

    const html = await renderToString(app)
    const select = html.match(/<select[^>]+>/)?.[0] ?? ''

    expect(select).toContain('class="sky-field__input sky-field__select"')
    expect(select).toContain('aria-label="Gender"')
    expect(select).toContain('placeholder="Please choose..."')
    expect(select).toContain('value="male"')
    expect(html).not.toContain('>Please choose...</option>')
    expect(html).toContain('<option value="male">Male</option>')
    expect(html).toContain('<option disabled value="0">Unavailable</option>')
    expect(html).toContain('<option value="custom">Custom</option>')
  })

  it('renders the exact Konsta dropdown triangle', async () => {
    const app = createSSRApp(SkyField, {
      dropdown: true,
      options: [{ label: 'Male', value: 'Male' }],
      type: 'select',
    })

    const html = await renderToString(app)

    expect(html).toContain(
      '<svg class="sky-field__dropdown" xmlns="http://www.w3.org/2000/svg" width="8" height="5" viewBox="0 0 8 5" fill="currentColor" aria-hidden="true" focusable="false">',
    )
    expect(html).toContain(
      '<polygon fill-rule="evenodd" points="0 0 8 0 4 5"></polygon>',
    )
  })

  it('keeps native select options readable on the CEF popup surface', () => {
    const controls = readFileSync(
      new URL('../controls.css', import.meta.url),
      'utf8',
    )
    const tokens = readFileSync(
      new URL('../tokens.css', import.meta.url),
      'utf8',
    )

    expect(controls).toMatch(
      /\.sky-field__select option\s*\{[^}]*background:\s*var\(--sky-native-select-option-background, #ffffff\);[^}]*color:\s*var\(--sky-native-select-option-text, #000000\);/s,
    )
    expect(tokens).toContain('--sky-native-select-option-background: #ffffff;')
    expect(tokens).toContain('--sky-native-select-option-text: #000000;')
  })

  it('raises floating labels only after the field has a value', async () => {
    const emptyApp = createSSRApp(SkyField, {
      floatingLabel: true,
      label: 'Name',
      placeholder: 'Your name',
    })
    const valuedApp = createSSRApp(SkyField, {
      floatingLabel: true,
      label: 'Name',
      modelValue: 'Sky',
      placeholder: 'Your name',
    })

    const emptyHtml = await renderToString(emptyApp)
    const valuedHtml = await renderToString(valuedApp)

    expect(emptyHtml).toContain('sky-field--floating-label')
    expect(emptyHtml).not.toContain('sky-field--floating-raised')
    expect(valuedHtml).toContain('sky-field--floating-label')
    expect(valuedHtml).toContain('sky-field--floating-raised')
  })

  it('locks Konsta input, outline, floating-label, and reduced-motion geometry', () => {
    const controls = readFileSync(
      new URL('../controls.css', import.meta.url),
      'utf8',
    )

    expect(controls).toMatch(
      /\.sky-field__input\s*\{[^}]*height:\s*40px;[^}]*min-height:\s*40px;[^}]*font-size:\s*16px;[^}]*line-height:\s*24px/s,
    )
    expect(controls).toMatch(/\.sky-field__media,[\s\S]*?padding:\s*8px 0;/)
    expect(controls).toMatch(
      /\.sky-field__inner\s*\{[^}]*padding:\s*12px calc\(16px \+ var\(--sky-safe-area-right, 0px\)\) 12px 0/s,
    )
    expect(controls).toMatch(/\.sky-field--outline\s*\{[^}]*margin:\s*16px 0;/s)
    expect(controls).toMatch(
      /\.sky-field--floating-label:not\(\.sky-field--inline\) \.sky-field__label\s*\{[^}]*transform:\s*translateY\(16px\) scale\(1\.33\)/s,
    )
    expect(controls).toMatch(
      /\.sky-field--floating-label\.sky-field--outline:not\([\s\S]*?\.sky-field__label\s*\{[^}]*transform:\s*translateY\(24px\) scale\(1\.33\)/s,
    )
    expect(controls).toMatch(
      /@media \(prefers-reduced-motion: reduce\)\s*\{[^}]*\.sky-field__label/s,
    )
  })

  it('renders an explicitly labelled clear control only for a non-empty value', async () => {
    const app = createSSRApp(SkyField, {
      clearButton: true,
      clearLabel: 'Clear email',
      modelValue: 'alex@example.com',
    })

    const html = await renderToString(app)

    expect(html).toContain('class="sky-field__clear"')
    expect(html).toContain('type="button"')
    expect(html).toContain('aria-label="Clear email"')
  })

  it('does not expose an unnamed clear control', async () => {
    const app = createSSRApp(SkyField, {
      clearButton: true,
      modelValue: 'alex@example.com',
    })

    const html = await renderToString(app)

    expect(html).not.toContain('sky-field__clear')
  })

  it('declares its accessible clear event without changing existing events', () => {
    const component = SkyField as unknown as { emits: string[] }

    expect(component.emits).toEqual(
      expect.arrayContaining([
        'blur',
        'change',
        'clear',
        'focus',
        'input',
        'update:modelValue',
      ]),
    )
  })
})
