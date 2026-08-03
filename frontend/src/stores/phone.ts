import { defineStore } from 'pinia'

type LocaleTree = Record<string, unknown>

export type PhoneOpenPayload = {
  lang?: string
  locales?: LocaleTree
}

const defaultLocales: LocaleTree = {
  Phone: {
    close: 'Close',
    readyBody: 'Konsta UI is connected to the FiveM NUI bridge.',
    readyTitle: 'Boilerplate ready',
    title: 'Phone',
  },
}

function getByPath(source: LocaleTree, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (
      typeof current !== 'object' ||
      current === null ||
      Array.isArray(current)
    )
      return undefined
    return (current as LocaleTree)[segment]
  }, source)
}

export const usePhoneStore = defineStore('phone', {
  state: () => ({
    isOpen: false,
    lang: 'en',
    locales: defaultLocales,
  }),
  actions: {
    close(): void {
      this.isOpen = false
    },
    open(payload: PhoneOpenPayload = {}): void {
      this.lang = payload.lang ?? 'en'
      this.locales = payload.locales ?? defaultLocales
      this.isOpen = true
    },
    t(path: string): string {
      const translated = getByPath(this.locales, path)
      const fallback = getByPath(defaultLocales, path)
      return typeof translated === 'string'
        ? translated
        : typeof fallback === 'string'
          ? fallback
          : path
    },
  },
})
