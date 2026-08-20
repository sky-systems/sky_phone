import { defineStore } from 'pinia'

import type {
  AdminAuditEntry,
  AdminActivityResponse,
  AdminBootstrap,
  AdminCallActivity,
  AdminConfigurator,
  AdminConfiguratorChange,
  AdminCredential,
  AdminMessageActivity,
  AdminPlayerDetail,
  AdminPlayerSummary,
  AdminStats,
} from '@/types/admin'
import { nuiCall, type NuiResponse } from '@/utils/nui'

const EMPTY_STATS: AdminStats = { accounts: 0, devices: 0, online: 0 }

export const useAdminStore = defineStore('admin', {
  state: () => ({
    actionKey: '',
    activityKey: '',
    audit: [] as AdminAuditEntry[],
    configurator: null as AdminConfigurator | null,
    configuratorLoading: false,
    detailLoading: false,
    error: '',
    initialized: false,
    loading: false,
    players: [] as AdminPlayerSummary[],
    revealedCredentials: {} as Record<string, AdminCredential>,
    deviceActivity: {} as Record<
      string,
      { calls?: AdminCallActivity[]; messages?: AdminMessageActivity[] }
    >,
    selectedPlayer: null as AdminPlayerDetail | null,
    stats: { ...EMPTY_STATS },
  }),
  actions: {
    async load(): Promise<boolean> {
      this.loading = true
      const response = await nuiCall<AdminBootstrap>('admin:bootstrap')
      this.loading = false
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return false
      }
      this.players = response.data.players
      this.stats = response.data.stats
      this.audit = response.data.audit
      this.error = ''
      this.initialized = true
      return true
    },
    async openPlayer(source: number): Promise<boolean> {
      this.detailLoading = true
      this.revealedCredentials = {}
      const response = await nuiCall<AdminPlayerDetail>('admin:player', {
        source,
      })
      this.detailLoading = false
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return false
      }
      this.selectedPlayer = response.data
      this.error = ''
      return true
    },
    closePlayer(): void {
      this.selectedPlayer = null
      this.revealedCredentials = {}
    },
    async saveApps(
      source: number,
      imei: string,
      revision: number,
      changes: Array<{ appId: string; installed: boolean }>,
    ): Promise<NuiResponse<AdminPlayerDetail>> {
      this.actionKey = `${imei}:save`
      const response = await nuiCall<AdminPlayerDetail>('admin:save-apps', {
        changes,
        imei,
        revision,
        source,
      })
      this.actionKey = ''
      if (response.success && response.data) {
        this.selectedPlayer = response.data
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async revealPassword(
      source: number,
      imei: string,
    ): Promise<NuiResponse<AdminCredential>> {
      this.actionKey = `${imei}:password`
      const response = await nuiCall<AdminCredential>('admin:reveal-password', {
        imei,
        source,
      })
      this.actionKey = ''
      if (response.success && response.data) {
        this.revealedCredentials[imei] = response.data
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async loadActivity(
      source: number,
      imei: string,
      kind: 'messages' | 'calls',
    ): Promise<boolean> {
      this.activityKey = `${imei}:${kind}`
      const response = await nuiCall<AdminActivityResponse>('admin:activity', {
        imei,
        kind,
        source,
      })
      this.activityKey = ''
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return false
      }
      const activity = this.deviceActivity[imei] ?? {}
      if (response.data.kind === 'messages') {
        activity.messages = response.data.entries
      } else {
        activity.calls = response.data.entries
      }
      this.deviceActivity[imei] = activity
      this.error = ''
      return true
    },
    async loadConfigurator(): Promise<boolean> {
      this.configuratorLoading = true
      const response = await nuiCall<AdminConfigurator>('admin:configurator')
      this.configuratorLoading = false
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return false
      }
      this.configurator = response.data
      this.error = ''
      return true
    },
    async saveConfigurator(
      changes: AdminConfiguratorChange[],
    ): Promise<NuiResponse<AdminConfigurator>> {
      const current = this.configurator
      if (!current) return { error: 'request_failed', success: false }

      this.actionKey = 'configurator:save'
      const response = await nuiCall<AdminConfigurator>(
        'admin:save-configurator',
        {
          changes,
          revision: current.revision,
        },
      )
      this.actionKey = ''
      if (response.success && response.data) {
        this.configurator = response.data
        this.error = ''
      } else {
        if (response.data) this.configurator = response.data
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async resetPasscode(
      source: number,
      imei: string,
    ): Promise<NuiResponse<AdminPlayerDetail>> {
      this.actionKey = `${imei}:reset-passcode`
      const response = await nuiCall<AdminPlayerDetail>(
        'admin:reset-passcode',
        { imei, source },
      )
      this.actionKey = ''
      if (response.success && response.data) {
        this.selectedPlayer = response.data
        delete this.revealedCredentials[imei]
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async changeNumber(
      source: number,
      imei: string,
      phoneNumber: string,
    ): Promise<NuiResponse<AdminPlayerDetail>> {
      this.actionKey = `${imei}:change-number`
      const response = await nuiCall<AdminPlayerDetail>('admin:change-number', {
        imei,
        phoneNumber,
        source,
      })
      this.actionKey = ''
      if (response.success && response.data) {
        this.selectedPlayer = response.data
        delete this.deviceActivity[imei]
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async factoryReset(
      source: number,
      imei: string,
    ): Promise<NuiResponse<AdminPlayerDetail>> {
      this.actionKey = `${imei}:factory-reset`
      const response = await nuiCall<AdminPlayerDetail>('admin:factory-reset', {
        imei,
        source,
      })
      this.actionKey = ''
      if (response.success && response.data) {
        this.selectedPlayer = response.data
        delete this.deviceActivity[imei]
        delete this.revealedCredentials[imei]
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
  },
})
