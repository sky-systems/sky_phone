import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'

export const APP_AUTH_IDS = [
  'citymarkt',
  'local-pages',
  'feather',
  'crewlink',
  'skypic',
] as const

export type AppAuthId = (typeof APP_AUTH_IDS)[number]

type PersistedAppAuth = {
  accountEmail: string
  signedIn: AppAuthId[]
  version: 1
}

function emptySessions(): Record<AppAuthId, boolean> {
  return {
    citymarkt: false,
    'local-pages': false,
    feather: false,
    crewlink: false,
    skypic: false,
  }
}

export const useAppAuthStore = defineStore('app-auth', {
  state: () => ({
    accountEmail: '',
    sessions: emptySessions(),
  }),
  actions: {
    hydrate(payload: unknown, accountEmail: string): void {
      this.accountEmail = accountEmail
      this.sessions = emptySessions()
      if (!accountEmail || !payload || typeof payload !== 'object') return

      const data = payload as Partial<PersistedAppAuth>
      if (
        data.version !== 1 ||
        data.accountEmail !== accountEmail ||
        !Array.isArray(data.signedIn)
      )
        return

      for (const appId of data.signedIn) {
        if (APP_AUTH_IDS.includes(appId)) this.sessions[appId] = true
      }
    },
    isSignedIn(appId: AppAuthId): boolean {
      return Boolean(this.accountEmail && this.sessions[appId])
    },
    signIn(appId: AppAuthId, accountEmail: string): void {
      if (this.accountEmail !== accountEmail) this.sessions = emptySessions()
      this.accountEmail = accountEmail
      this.sessions[appId] = true
      this.persist()
    },
    signOut(appId: AppAuthId): void {
      this.sessions[appId] = false
      this.persist()
    },
    clear(): void {
      this.accountEmail = ''
      this.sessions = emptySessions()
      this.persist()
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('appAuth', {
        accountEmail: this.accountEmail,
        signedIn: APP_AUTH_IDS.filter((appId) => this.sessions[appId]),
        version: 1,
      } satisfies PersistedAppAuth)
    },
  },
})
