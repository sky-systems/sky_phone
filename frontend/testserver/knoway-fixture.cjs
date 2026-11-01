const { randomUUID } = require('node:crypto')

const pickup = {
  coords: { x: -265.1, y: -960.2, z: 31.2 },
  label: 'Legion Square',
}
function createSession() {
  let quote = null
  let ride = null
  let changedAt = 0
  const refundPolicy = { beforeStart: true, afterStart: false, technical: true }

  function state() {
    const now = Date.now()
    if (ride?.status === 'approaching' && now - changedAt >= 6000) {
      ride.status = 'waiting'
      ride.expiresAt = Math.floor(now / 1000) + 120
      changedAt = now
    } else if (ride?.status === 'driving' && now - changedAt >= 60000) {
      ride.status = 'arrived'
      ride.refundStatus = 'settled'
      ride.reason = 'destination_reached'
    }
    if (ride) {
      const duration = ride.status === 'approaching' ? 6000 : 60000
      const progress = Math.min(1, (now - changedAt) / duration)
      const from =
        ride.status === 'approaching'
          ? { x: pickup.coords.x - 140, y: pickup.coords.y + 80, z: 31.2 }
          : pickup.coords
      const to =
        ride.status === 'approaching' || ride.status === 'waiting'
          ? pickup.coords
          : ride.destination.coords
      ride.position = {
        x: from.x + (to.x - from.x) * progress,
        y: from.y + (to.y - from.y) * progress,
        z: to.z,
      }
    }
    return { activeRide: ride, available: true, currency: '$', refundPolicy }
  }

  function handleKnoway(endpoint, body) {
    if (!endpoint.startsWith('knoway:')) return null
    if (body._testScenario === 'knoway-unavailable') {
      return {
        success: true,
        data: { activeRide: null, available: false, currency: '$' },
      }
    }
    if (endpoint === 'knoway:get-player-coords')
      return { success: true, data: { coords: pickup.coords } }
    if (endpoint === 'knoway:get-waypoint') {
      return {
        success: true,
        data: { coords: { x: -1037.5, y: -2737.6, z: 20.2 } },
      }
    }
    if (endpoint === 'knoway:bootstrap') return { success: true, data: state() }
    if (endpoint === 'knoway:quote') {
      const destination = body.destination
      if (
        !destination?.coords ||
        !Number.isFinite(destination.coords.x) ||
        !Number.isFinite(destination.coords.y)
      ) {
        return { success: false, error: 'invalid_route' }
      }
      if (ride && ['approaching', 'waiting', 'driving'].includes(ride.status)) {
        return { success: false, error: 'ride_active' }
      }
      const distanceMeters = Math.ceil(
        Math.hypot(
          destination.coords.x - pickup.coords.x,
          destination.coords.y - pickup.coords.y,
        ) * 1.25,
      )
      if (distanceMeters < 250 || distanceMeters > 40000)
        return { success: false, error: 'invalid_route' }
      quote = {
        id: randomUUID(),
        expiresAt: Math.floor(Date.now() / 1000) + 120,
        pickup,
        destination,
        price: Math.max(15, Math.ceil(12 + (18 * distanceMeters) / 1000)),
        currency: '$',
        distanceMeters,
        durationSeconds: Math.ceil(distanceMeters / 12),
        refundPolicy,
      }
      return { success: true, data: quote }
    }
    if (endpoint === 'knoway:request') {
      if (
        !quote ||
        body.quoteId !== quote.id ||
        quote.expiresAt <= Date.now() / 1000
      )
        return { success: false, error: 'quote_expired' }
      ride = {
        ...quote,
        status: 'approaching',
        createdAt: Math.floor(Date.now() / 1000),
        vehicle: {
          model: 'KnoWay Ocelot E-Stride',
          plate: 'KN042026',
          netId: 1,
          driverNetId: 2,
        },
        refundStatus: 'charged',
      }
      quote = null
      changedAt = Date.now()
      return { success: true, data: state() }
    }
    if (endpoint === 'knoway:start' || endpoint === 'knoway:cancel') {
      state()
      if (!ride || body.rideId !== ride.id)
        return { success: false, error: 'not_ride_owner' }
      if (endpoint === 'knoway:start') {
        if (ride.status !== 'waiting')
          return { success: false, error: 'ride_not_ready' }
        ride.status = 'driving'
        changedAt = Date.now()
      } else {
        ride.refundStatus = ride.status === 'driving' ? 'settled' : 'refunded'
        ride.status = 'cancelled'
        ride.reason = 'passenger_cancelled'
      }
      return { success: true, data: state() }
    }
    return { success: false, error: 'request_failed' }
  }
  return handleKnoway
}

const sessions = new Map()
function handleKnoway(endpoint, body) {
  if (!endpoint.startsWith('knoway:')) return null
  const key = body._testScenario || 'default'
  if (!sessions.has(key)) sessions.set(key, createSession())
  return sessions.get(key)(endpoint, body)
}

module.exports = { handleKnoway }
