const faceIdErrors = new Set([
  'face_id_not_enabled',
  'face_id_not_recognized',
  'face_id_unavailable',
  'invalid_passcode',
  'passcode_locked',
  'passcode_not_set',
  'rate_limited',
  'device_not_open',
  'device_locked',
])

export function faceIdErrorKey(error?: string): string {
  return `FaceId.errors.${error && faceIdErrors.has(error) ? error : 'request_failed'}`
}
