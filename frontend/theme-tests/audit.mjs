// Runs in the browser. A 3:1 floor detects severe theme regressions; this is
// deliberately not a claim of full WCAG AA conformance (normal text needs 4.5:1).
export function auditTheme({ selector, mode, checkPalette = true }) {
  const root = document.querySelector(selector)
  if (!root) throw new Error(`App did not render: ${selector}`)
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = 1
  const context = canvas.getContext('2d', { willReadFrequently: true })
  const rgba = (value) => {
    context.clearRect(0, 0, 1, 1)
    context.fillStyle = value
    context.fillRect(0, 0, 1, 1)
    return [...context.getImageData(0, 0, 1, 1).data].map((x, i) =>
      i === 3 ? x / 255 : x,
    )
  }
  const over = (a, b) =>
    [0, 1, 2].map((i) => a[i] * a[3] + b[i] * (1 - a[3])).concat(1)
  const luminance = (c) =>
    c
      .slice(0, 3)
      .map((x) => x / 255)
      .map((x) => (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4))
      .reduce((s, x, i) => s + x * [0.2126, 0.7152, 0.0722][i], 0)
  const contrast = (a, b) =>
    (Math.max(luminance(a), luminance(b)) + 0.05) /
    (Math.min(luminance(a), luminance(b)) + 0.05)
  const issues = []
  const checked = []
  const skipped = []
  const label = (el) =>
    `${el.tagName.toLowerCase()}.${[...el.classList].slice(0, 3).join('.')}`
  const page = root.matches('.sky-app-page')
    ? root
    : root.querySelector('.sky-app-page') || root.firstElementChild
  if (checkPalette && !page)
    issues.push({ type: 'palette', message: 'Missing SkyAppPage theme root' })
  else if (checkPalette) {
    const style = getComputedStyle(page)
    const expected = page.dataset.themePolicy === 'scene' ? 'dark' : mode
    if (style.colorScheme !== expected)
      issues.push({
        type: 'palette',
        message: `Expected ${expected}, got ${style.colorScheme}`,
      })
    for (const [token, light] of [
      ['--sky-bg', expected === 'light'],
      ['--sky-text', expected === 'dark'],
    ]) {
      const value = style.getPropertyValue(token).trim()
      if (!value || luminance(rgba(value)) > 0.5 !== light)
        issues.push({ type: 'palette', token, value, expected })
    }
    const bg = rgba(style.backgroundColor)
    if (bg[3] > 0.95 && luminance(bg) > 0.5 !== (expected === 'light'))
      issues.push({
        type: 'surface',
        selector: label(page),
        color: style.backgroundColor,
        expected,
      })
  }
  // Include painted decorative siblings (e.g. the accent behind a FAB icon),
  // which normally opt out of hit testing. This only changes hit testing during
  // this synchronous audit and is removed before any browser interaction.
  const paintHitTest = document.createElement('style')
  paintHitTest.textContent = '* { pointer-events: auto !important; }'
  document.head.append(paintHitTest)
  paintHitTest.sheet.disabled = true
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
  const targets = []
  while (walker.nextNode()) {
    const node = walker.currentNode
    if (node.textContent.trim())
      targets.push({
        el: node.parentElement,
        node,
        text: node.textContent.trim().slice(0, 70),
      })
  }
  for (const el of root.querySelectorAll('input, textarea, select')) {
    targets.push({
      el,
      text:
        el.value ||
        el.placeholder ||
        el.getAttribute('aria-label') ||
        el.tagName,
      placeholder: !el.value && !!el.placeholder,
    })
  }
  for (const control of root.querySelectorAll('button, a')) {
    if (control.textContent.trim() || control.querySelector('img')) continue
    const icon = control.querySelector('svg')
    if (icon)
      targets.push({
        el: icon,
        icon: true,
        text:
          control.getAttribute('aria-label') || control.title || label(control),
      })
  }
  for (const { el, node, text, placeholder, icon } of targets) {
    if (
      el.closest(
        icon
          ? '[disabled],[aria-disabled="true"]'
          : 'script,style,svg,[aria-hidden="true"],[disabled],[aria-disabled="true"]',
      )
    )
      continue
    const style = getComputedStyle(el)
    if (style.visibility !== 'visible' || style.display === 'none') continue
    let opacity = 1
    for (let a = el; a; a = a.parentElement)
      opacity *= Number(getComputedStyle(a).opacity)
    if (opacity < 0.5) continue // hidden/transitioning/disabled content
    const range = document.createRange()
    if (node) range.selectNodeContents(node)
    const rect = node
      ? range.getBoundingClientRect()
      : el.getBoundingClientRect()
    if (rect.width < 1 || rect.height < 1) continue
    const x = Math.min(innerWidth - 1, Math.max(0, rect.left + rect.width / 2))
    const y = rect.top + rect.height / 2
    if (y < 0 || y >= innerHeight || rect.right < 0 || rect.left >= innerWidth)
      continue
    const first = document.elementsFromPoint(x, y)[0]
    if (first && !el.contains(first) && !first.contains(el)) continue // clipped/covered content
    paintHitTest.sheet.disabled = false
    const painted = document.elementsFromPoint(x, y)
    paintHitTest.sheet.disabled = true
    // Only layers behind the text/icon form its background. The transparent
    // phone-frame image and drag portals are foreground chrome, not a backdrop.
    const targetIndex = painted.indexOf(el)
    if (targetIndex < 0) continue
    const layers = painted.slice(targetIndex)
    const merge = (front, back) => {
      const alpha = front[3] + back[3] * (1 - front[3])
      return alpha
        ? [0, 1, 2]
            .map(
              (i) =>
                (front[i] * front[3] + back[i] * back[3] * (1 - front[3])) /
                alpha,
            )
            .concat(alpha)
        : [0, 0, 0, 0]
    }
    let backgrounds = [[0, 0, 0, 0]]
    let unknown = false
    // Check all gradient color bounds; mixed pass/fail bounds need a screenshot.
    for (const layer of layers) {
      const css = getComputedStyle(layer)
      if (
        ['IMG', 'VIDEO', 'CANVAS', 'IFRAME'].includes(layer.tagName) ||
        css.backgroundImage.includes('url(')
      ) {
        unknown = true
        break
      }
      const base = rgba(css.backgroundColor)
      const stops = css.backgroundImage.match(
        /(?:rgba?|oklab|oklch|color)\([^)]*\)/g,
      )
      const colors = stops?.length
        ? stops.map((stop) => merge(rgba(stop), base))
        : [base]
      for (const color of colors) color[3] *= Number(css.opacity)
      backgrounds = backgrounds.flatMap((front) =>
        colors.map((back) => merge(front, back)),
      )
      // Bound work on complex layered artwork; never silently treat it as passing.
      if (backgrounds.length > 128) {
        unknown = true
        break
      }
      if (backgrounds.every((bg) => bg[3] > 0.995)) break
    }
    if (unknown || backgrounds.some((bg) => bg[3] < 0.995)) {
      skipped.push({
        selector: label(el),
        text,
        reason: 'image, complex gradient or transparent game surface',
      })
      continue
    }
    const ink = placeholder ? getComputedStyle(el, '::placeholder') : style
    const foreground = rgba(ink.color)
    foreground[3] *= opacity * (placeholder ? Number(ink.opacity) : 1)
    const ratios = backgrounds.map((bg) => contrast(over(foreground, bg), bg))
    if (Math.min(...ratios) < 3 && Math.max(...ratios) >= 3) {
      skipped.push({
        selector: label(el),
        text,
        reason: 'gradient has mixed contrast bounds',
      })
      continue
    }
    const ratio = Math.min(...ratios)
    const background = backgrounds[ratios.indexOf(ratio)]
    const result = {
      selector: label(el),
      text,
      kind: icon
        ? 'icon'
        : placeholder
          ? 'placeholder'
          : el.matches('input,textarea,select')
            ? 'input'
            : 'text',
      foreground: ink.color,
      background: background.slice(0, 3).map(Math.round),
      contrast: Number(ratio.toFixed(2)),
    }
    checked.push(result)
    if (ratio < 3) issues.push(result)
  }
  paintHitTest.remove()
  return { mode, issues, checked, skipped }
}
