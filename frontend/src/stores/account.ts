import { defineStore } from 'pinia'

import type { AccountDevice, IfruitAccount } from '@/types/device'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useAccountStore = defineStore('account', {
  state: () => ({
    devices: [] as AccountDevice[],
    email: '',
  }),
  actions: {
    hydrate(account: IfruitAccount | null): void {
      this.email = account?.email ?? ''
      this.devices = account?.devices ?? []
    },
    async login(email: string, password: string): Promise<NuiResponse<IfruitAccount>> {
      const response = await nuiCall<IfruitAccount>('account:login', {
        email,
        password,
      })
      if (response.success && response.data) this.hydrate(response.data)
      return response
    },
    async register(email: string, password: string): Promise<NuiResponse<IfruitAccount>> {
      const response = await nuiCall<IfruitAccount>('account:register', {
        email,
        password,
      })
      if (response.success && response.data) this.hydrate(response.data)
      return response
    },
    async logout(): Promise<boolean> {
      const response = await nuiCall('account:logout')
      if (response.success) this.hydrate(null)
      return response.success
    },
    async loadDevices(): Promise<boolean> {
      const response = await nuiCall<AccountDevice[]>('account:devices')
      if (response.success && response.data) this.devices = response.data
      return response.success
    },
    async removeDevice(imei: string, password: string): Promise<NuiResponse<AccountDevice[]>> {
      const response = await nuiCall<AccountDevice[]>('account:remove-device', {
        imei,
        password,
      })
      if (response.success && response.data) this.devices = response.data
      return response
    },
    async factoryReset(): Promise<boolean> {
      const response = await nuiCall('device:factory-reset')
      if (response.success) this.hydrate(null)
      return response.success
    },
  },
})
