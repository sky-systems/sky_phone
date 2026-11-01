import { createRequire } from 'node:module'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { KnowayQuote, KnowayState } from '../src/types/knoway'

const require = createRequire(import.meta.url)
const { handleKnoway } = require('./knoway-fixture.cjs') as {
  handleKnoway: (
    endpoint: string,
    body: Record<string, unknown>,
  ) => { success: boolean; data?: unknown; error?: string } | null
}
const destination = {
  coords: { x: -1037.5, y: -2737.6, z: 20.2 },
  label: 'Airport',
}

describe('KnoWay browser session dispatch', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(2_000_000_000_000)
  })

  afterEach(() => vi.useRealTimers())

  function book(scenario: string) {
    const quoted = handleKnoway('knoway:quote', {
      _testScenario: scenario,
      destination,
    })
    expect(quoted?.success).toBe(true)
    const quote = quoted?.data as KnowayQuote
    const booked = handleKnoway('knoway:request', {
      _testScenario: scenario,
      quoteId: quote.id,
    })
    expect(booked?.success).toBe(true)
    return (booked?.data as KnowayState).activeRide!
  }

  it.each(['__proto__', 'constructor', 'toString', 'hasOwnProperty'])(
    'treats the scenario %s only as a session key',
    (scenario) => {
      const ride = book(scenario)
      expect(ride.status).toBe('approaching')
      const state = handleKnoway('knoway:bootstrap', {
        _testScenario: scenario,
      })?.data as KnowayState
      expect(state.activeRide?.id).toBe(ride.id)
    },
  )

  it('keeps quotes and bookings isolated between scenarios', () => {
    const ride = book('knoway-session-owner')
    const other = handleKnoway('knoway:bootstrap', {
      _testScenario: 'knoway-other-session',
    })?.data as KnowayState
    expect(other.activeRide).toBeNull()
    expect(
      handleKnoway('knoway:cancel', {
        _testScenario: 'knoway-other-session',
        rideId: ride.id,
      }),
    ).toEqual({ success: false, error: 'not_ride_owner' })
  })

  it('retains the quote, boarding, start and cancellation workflow', () => {
    const scenario = 'knoway-session-workflow'
    const ride = book(scenario)
    vi.advanceTimersByTime(6000)
    const waiting = handleKnoway('knoway:bootstrap', {
      _testScenario: scenario,
    })?.data as KnowayState
    expect(waiting.activeRide?.status).toBe('waiting')
    const started = handleKnoway('knoway:start', {
      _testScenario: scenario,
      rideId: ride.id,
    })?.data as KnowayState
    expect(started.activeRide?.status).toBe('driving')
    const cancelled = handleKnoway('knoway:cancel', {
      _testScenario: scenario,
      rideId: ride.id,
    })?.data as KnowayState
    expect(cancelled.activeRide?.status).toBe('cancelled')
    expect(cancelled.activeRide?.refundStatus).toBe('settled')
  })

  it('continues to reject unknown actions and ignore other apps', () => {
    expect(handleKnoway('knoway:unknown', {})).toEqual({
      success: false,
      error: 'request_failed',
    })
    expect(handleKnoway('skyride:bootstrap', {})).toBeNull()
  })
})
