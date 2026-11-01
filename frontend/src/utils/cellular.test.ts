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
  it.each([false, true])(
    'keeps KnoWay ride controls reachable with offlineApps.knoway=%s',
    (offline) => {
      cellular.offlineApps.knoway = offline
      Object.assign(cellular.cleanupActions, {
        'knoway:bootstrap': true,
        'knoway:start': true,
        'knoway:cancel': true,
      })

      expect(appNeedsSignal('knoway')).toBe(false)
      for (const action of ['bootstrap', 'start', 'cancel'])
        expect(blocksCellularRequest(`knoway:${action}`)).toBe(false)
      for (const action of ['quote', 'request'])
        expect(blocksCellularRequest(`knoway:${action}`)).toBe(true)

      cellular.hasSignal = true
      expect(blocksCellularRequest('knoway:quote')).toBe(false)
      expect(blocksCellularRequest('knoway:request')).toBe(false)
      cellular.hasSignal = false
      cellular.enabled = false
      expect(appNeedsSignal('knoway')).toBe(false)
      expect(blocksCellularRequest('knoway:quote')).toBe(false)
      expect(blocksCellularRequest('knoway:request')).toBe(false)
    },
  )
  it('restores requests when reception returns or the master switch is off', () => {
    cellular.hasSignal = true
    expect(blocksCellularRequest('calls:dial')).toBe(false)
    cellular.hasSignal = false
    cellular.enabled = false
    expect(blocksCellularRequest('calls:dial')).toBe(false)
    expect(appNeedsSignal('feather')).toBe(false)
  })
})
