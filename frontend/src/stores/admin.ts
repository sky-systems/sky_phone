import { defineStore } from 'pinia'

import type {
  AdminAuditEntry,
  AdminActivityResponse,
  AdminBootstrap,
  AdminCallActivity,
  AdminConfigurator,
  AdminConfiguratorChange,
  AdminCredential,
  AdminCustomTone,
  AdminCustomToneCreate,
  AdminMessageActivity,
  AdminPlayerDetail,
  AdminPlayerSummary,
  AdminStats,
} from '@/types/admin'
import {
  cacheCustomPhoneTonePayload,
  CUSTOM_TONE_CHUNK_CHARS,
} from '@/utils/customTones'
import { nuiCall, type NuiResponse } from '@/utils/nui'

const EMPTY_STATS: AdminStats = {
  accounts: 0,
  activeDevices: 0,
  auditEntries: 0,
  auditToday: 0,
  callsToday: 0,
  devices: 0,
  linkedDevices: 0,
  messagesToday: 0,
  online: 0,
  simDevices: 0,
}

function disabledAppsFromConfigurator(
  configurator: AdminConfigurator,
): string[] {
  const apps = configurator.sections
    .flatMap((section) => section.fields)
    .find((field) => field.scope === 'config' && field.path === 'Apps')?.value
  if (!apps || typeof apps !== 'object' || Array.isArray(apps)) return []

  return Object.entries(apps)
    .filter(([, enabled]) => enabled === false)
    .map(([appId]) => appId)
    .sort()
}

export const useAdminStore = defineStore('admin', {
  state: () => ({
    actionKey: '',
    activityKey: '',
    audit: [] as AdminAuditEntry[],
    configurator: null as AdminConfigurator | null,
    configuratorLoading: false,
    customTones: [] as AdminCustomTone[],
    customTonesLoading: false,
    detailLoading: false,
    disabledApps: [] as string[],
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
      this.disabledApps = Array.isArray(response.data.disabledApps)
        ? response.data.disabledApps
        : []
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
      this.disabledApps = disabledAppsFromConfigurator(response.data)
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
        this.disabledApps = disabledAppsFromConfigurator(response.data)
        this.error = ''
      } else {
        if (response.data) this.configurator = response.data
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async loadCustomTones(): Promise<boolean> {
      this.customTonesLoading = true
      const response = await nuiCall<AdminCustomTone[]>('admin:tones')
      this.customTonesLoading = false
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return false
      }
      this.customTones = response.data
      this.error = ''
      return true
    },
    async createCustomTone(
      tone: AdminCustomToneCreate,
    ): Promise<NuiResponse<AdminCustomTone[]>> {
      this.actionKey = 'custom-tone:create'
      const { payload, ...metadata } = tone
      let uploadId = ''
      try {
        const started = await nuiCall<{ uploadId: string }>(
          'admin:tone-upload-start',
          {
            ...metadata,
            payloadLength: payload.length,
          },
        )
        uploadId = started.data?.uploadId ?? ''
        if (!started.success || !uploadId) {
          this.error = started.error ?? 'request_failed'
          return { error: this.error, success: false }
        }

        for (let offset = 0, index = 1; offset < payload.length; index += 1) {
          const response = await nuiCall('admin:tone-upload-chunk', {
            chunk: payload.slice(offset, offset + CUSTOM_TONE_CHUNK_CHARS),
            index,
            uploadId,
          })
          if (!response.success) {
            await nuiCall('admin:tone-upload-cancel', { uploadId })
            this.error = response.error ?? 'request_failed'
            return { error: this.error, success: false }
          }
          offset += CUSTOM_TONE_CHUNK_CHARS
        }

        const response: NuiResponse<AdminCustomTone[]> & {
          toneId?: unknown
        } = await nuiCall<AdminCustomTone[]>('admin:tone-upload-finish', {
          uploadId,
        })
        if (response.success && response.data) {
          this.customTones = response.data
          if (typeof response.toneId === 'string') {
            cacheCustomPhoneTonePayload(
              `custom:${response.toneId}`,
              tone.mimeType,
              payload,
            )
          }
          this.error = ''
        } else {
          await nuiCall('admin:tone-upload-cancel', { uploadId })
          this.error = response.error ?? 'request_failed'
        }
        return response
      } catch (error) {
        if (uploadId) {
          await nuiCall('admin:tone-upload-cancel', { uploadId })
        }
        console.error('[Phone admin] Custom tone upload failed.', error)
        this.error = 'request_failed'
        return { error: this.error, success: false }
      } finally {
        this.actionKey = ''
      }
    },
    async deleteCustomTone(
      id: string,
    ): Promise<NuiResponse<AdminCustomTone[]>> {
      this.actionKey = `custom-tone:delete:${id}`
      const response = await nuiCall<AdminCustomTone[]>('admin:delete-tone', {
        id,
      })
      this.actionKey = ''
      if (response.success && response.data) {
        this.customTones = response.data
        this.error = ''
      } else {
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
