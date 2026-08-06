export const SPRINGBOARD_PAGE_COUNT = 3

export function paginateItems<T>(items: readonly T[], pageSize: number): T[][] {
  if (!Number.isInteger(pageSize) || pageSize <= 0) return []
  const pages: T[][] = []
  for (let index = 0; index < items.length; index += pageSize) {
    pages.push(items.slice(index, index + pageSize))
  }
  return pages
}

export function clampPage(
  page: number,
  pageCount = SPRINGBOARD_PAGE_COUNT,
): number {
  if (!Number.isFinite(page) || pageCount <= 0) return 0
  return Math.min(pageCount - 1, Math.max(0, Math.round(page)))
}
