import { defineStore } from 'pinia'

import type {
  AdminAuditEntry,
  AdminBootstrap,
  AdminCredential,
  AdminPlayerDetail,
  AdminPlayerSummary,
  AdminStats,
} from '@/types/admin'
import { nuiCall, type NuiResponse } from '@/utils/nui'

const EMPTY_STATS: AdminStats = { accounts: 0, devices: 0, online: 0 }

export const useAdminStore = defineStore('admin', {
  state: () => ({
    actionKey: '',
    audit: [] as AdminAuditEntry[],
    detailLoading: false,
    error: '',
    initialized: false,
    loading: false,
    players: [] as AdminPlayerSummary[],
    revealedCredentials: {} as Record<string, AdminCredential>,
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
  },
})
