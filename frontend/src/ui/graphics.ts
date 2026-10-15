/** CSS parsing support does not establish that an older Cfx compositor renders blur correctly. */
type GraphicsEnvironment = {
  nui: boolean
  supports: (property: string, value: string) => boolean
  userAgent: string
}

export function supportsSkyBackdrop(environment: GraphicsEnvironment): boolean {
  const parsesBackdrop =
    environment.supports('backdrop-filter', 'blur(1px)') ||
    environment.supports('-webkit-backdrop-filter', 'blur(1px)')
  if (!parsesBackdrop) return false
  if (!environment.nui) return true
  const chromium = environment.userAgent.match(/\bChrome\/(\d+)/)
  return Boolean(chromium && Number(chromium[1]) >= 144)
}

export function supportsSkyRefraction(
  environment: GraphicsEnvironment,
): boolean {
  return (
    supportsSkyBackdrop(environment) &&
    /\b(?:Headless)?Chrome\/\d+/.test(environment.userAgent) &&
    environment.supports('backdrop-filter', 'url("#sky-glass")')
  )
}

export function initializeSkyGraphics(): void {
  const environment = {
    nui: typeof window.GetParentResourceName === 'function',
    supports: (property: string, value: string) =>
      CSS.supports(property, value),
    userAgent: navigator.userAgent,
  }
  document.documentElement.dataset.skyBackdrop = String(
    supportsSkyBackdrop(environment),
  )
  document.documentElement.dataset.skyRefraction = String(
    supportsSkyRefraction(environment),
  )
}
