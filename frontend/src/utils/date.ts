export type DatabaseDateValue = string | number

export function parseDatabaseDate(value: DatabaseDateValue): Date {
  if (typeof value === 'number') {
    const timestamp = Math.abs(value) < 1_000_000_000_000 ? value * 1000 : value
    return new Date(timestamp)
  }

  return new Date(value.replace(' ', 'T'))
}
