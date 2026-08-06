export function cloneJsonData<T>(value: T): T {
  const serialized = JSON.stringify(value)
  if (serialized === undefined) return value
  return JSON.parse(serialized) as T
}
