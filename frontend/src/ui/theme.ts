import {
  computed,
  inject,
  provide,
  type ComputedRef,
  type InjectionKey,
} from 'vue'

export interface SkyThemeContext {
  accent: ComputedRef<string>
  accentSoft: ComputedRef<string>
  dark: ComputedRef<boolean>
  glassEffects: ComputedRef<boolean>
  safeAreas: ComputedRef<boolean>
}

interface SkyThemeSource {
  accent: () => string
  accentSoft: () => string
  dark: () => boolean
  glassEffects?: () => boolean | undefined
  safeAreas: () => boolean
}

const skyThemeKey: InjectionKey<SkyThemeContext> = Symbol('sky-ui-theme')

export function provideSkyTheme(source: SkyThemeSource): SkyThemeContext {
  const parent = useSkyTheme()
  const context: SkyThemeContext = {
    accent: computed(source.accent),
    accentSoft: computed(source.accentSoft),
    dark: computed(source.dark),
    glassEffects: computed(
      () => source.glassEffects?.() ?? parent?.glassEffects.value ?? true,
    ),
    safeAreas: computed(source.safeAreas),
  }

  provide(skyThemeKey, context)
  return context
}

export function useSkyTheme(): SkyThemeContext | null {
  return inject(skyThemeKey, null)
}
