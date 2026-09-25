import { beforeEach, describe, expect, it } from 'vitest'
import { appNeedsSignal, blocksCellularRequest, cellular } from './cellular'

beforeEach(() => {
  Object.assign(cellular, {
    enabled: true,
    hasSignal: false,
    bars: 0,
    offlineApps: { phone: true, messages: true, notes: true, camera: true },
    onlineActions: { 'calls:dial': true, 'messages:send': true },
    systemNamespaces: { admin: true, device: true, close: true },
    cleanupActions: { 'calls:hangup': true },
    appNamespaces: { calls: 'phone', contacts: 'phone' },
  })
})

describe('cellular policy supplied by Lua', () => {
  it('blocks online apps but keeps local data and cleanup available', () => {
    expect(appNeedsSignal('feather')).toBe(true)
    expect(appNeedsSignal('notes')).toBe(false)
    expect(blocksCellularRequest('calls:dial')).toBe(true)
    expect(blocksCellularRequest('messages:send')).toBe(true)
    expect(blocksCellularRequest('messages:thread')).toBe(false)
    expect(blocksCellularRequest('contacts:list')).toBe(false)
    expect(blocksCellularRequest('calls:hangup')).toBe(false)
    expect(blocksCellularRequest('admin:delete-social-post')).toBe(false)
    expect(blocksCellularRequest('close')).toBe(false)
    expect(blocksCellularRequest('new-app:send')).toBe(true)
  })
  it('uses each custom app ID for its storage policy', () => {
    cellular.offlineApps['offline-custom'] = true
    expect(
      blocksCellularRequest('custom-app:storage:set', {
        appId: 'offline-custom',
      }),
    ).toBe(false)
    expect(
      blocksCellularRequest('custom-app:storage:set', {
        appId: 'online-custom',
      }),
    ).toBe(true)
    expect(blocksCellularRequest('custom-app:storage:set', { appId: {} })).toBe(
      true,
    )
  })
  it('restores requests when reception returns or the master switch is off', () => {
    cellular.hasSignal = true
    expect(blocksCellularRequest('calls:dial')).toBe(false)
    cellular.hasSignal = false
    cellular.enabled = false
    expect(blocksCellularRequest('calls:dial')).toBe(false)
    expect(appNeedsSignal('feather')).toBe(false)
  })
})
