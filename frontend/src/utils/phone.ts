import type { PhoneNumberFormat } from '@/types/phone'

export const PHONE_NUMBER_LENGTH = 10
const DEFAULT_PHONE_NUMBER_FORMAT: PhoneNumberFormat = {
  groups: [3, 3, 4],
  length: PHONE_NUMBER_LENGTH,
}
let phoneNumberFormat: PhoneNumberFormat = DEFAULT_PHONE_NUMBER_FORMAT

export function configurePhoneNumberFormat(value?: PhoneNumberFormat): void {
  const length = value?.length
  const groups = value?.groups
  if (
    typeof length !== 'number' ||
    !Number.isInteger(length) ||
    length < 1 ||
    length > 24 ||
    !Array.isArray(groups) ||
    groups.length === 0 ||
    groups.some((group) => !Number.isInteger(group) || group < 1)
  ) {
    phoneNumberFormat = DEFAULT_PHONE_NUMBER_FORMAT
    return
  }

  phoneNumberFormat = {
    groups: [...groups],
    length,
  }
}

export function normalizePhoneNumber(value: string): string | null {
  const digits = value.replace(/\D/g, '')
  return digits.length === phoneNumberFormat.length ? digits : null
}

export function formatPhoneNumber(value: string | number): string {
  const digits = String(value)
    .replace(/\D/g, '')
    .slice(0, phoneNumberFormat.length)
  const formatted: string[] = []
  let offset = 0

  for (const size of phoneNumberFormat.groups) {
    const group = digits.slice(offset, offset + size)
    if (!group) break
    formatted.push(group)
    offset += size
  }
  if (offset < digits.length) formatted.push(digits.slice(offset))

  return formatted.join(' ')
}
