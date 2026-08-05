export const PHONE_NUMBER_LENGTH = 10

export function normalizePhoneNumber(value: string): string | null {
  const digits = value.replace(/\D/g, '')
  return digits.length === PHONE_NUMBER_LENGTH ? digits : null
}

export function formatPhoneNumber(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, PHONE_NUMBER_LENGTH)
  const groups = [digits.slice(0, 3), digits.slice(3, 6), digits.slice(6, 10)]
  return groups.filter(Boolean).join(' ')
}
