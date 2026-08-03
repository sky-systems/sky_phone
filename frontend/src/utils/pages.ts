export const SPRINGBOARD_PAGE_COUNT = 3

export function clampPage(
  page: number,
  pageCount = SPRINGBOARD_PAGE_COUNT,
): number {
  if (!Number.isFinite(page) || pageCount <= 0) return 0
  return Math.min(pageCount - 1, Math.max(0, Math.round(page)))
}
