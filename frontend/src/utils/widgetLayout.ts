import { WIDGET_REGISTRY_BY_KIND } from '@/config/widgets'
import type {
  WidgetInstance,
  WidgetKind,
  WidgetLayout,
  WidgetSettings,
  WidgetSize,
} from '@/types/widgets'

export const WIDGET_GRID_COLUMNS = 4
export const WIDGET_HOME_ROWS = 5
export const WIDGET_PAGE_ROWS = 10
const MAX_WIDGET_HOME_PAGES = 5

export const WIDGET_SPANS: Record<
  WidgetSize,
  { columns: number; rows: number }
> = {
  small: { columns: 2, rows: 2 },
  medium: { columns: 4, rows: 2 },
  large: { columns: 4, rows: 4 },
}

function rowsForPage(page: number): number {
  return page === 0 ? WIDGET_PAGE_ROWS : WIDGET_HOME_ROWS
}

function overlaps(left: WidgetInstance, right: WidgetInstance): boolean {
  if (left.page !== right.page) return false
  const leftSpan = WIDGET_SPANS[left.size]
  const rightSpan = WIDGET_SPANS[right.size]
  return (
    left.column < right.column + rightSpan.columns &&
    left.column + leftSpan.columns > right.column &&
    left.row < right.row + rightSpan.rows &&
    left.row + leftSpan.rows > right.row
  )
}

function fits(instance: WidgetInstance, placed: WidgetInstance[]): boolean {
  const span = WIDGET_SPANS[instance.size]
  return (
    instance.column >= 0 &&
    instance.row >= 0 &&
    instance.column + span.columns <= WIDGET_GRID_COLUMNS &&
    instance.row + span.rows <= rowsForPage(instance.page) &&
    !placed.some((candidate) => overlaps(instance, candidate))
  )
}

function findPosition(
  instance: WidgetInstance,
  placed: WidgetInstance[],
  startPage: number,
  maximumPage = MAX_WIDGET_HOME_PAGES,
): WidgetInstance | null {
  const lastPage = startPage === 0 ? 0 : maximumPage
  for (let page = startPage; page <= lastPage; page += 1) {
    const span = WIDGET_SPANS[instance.size]
    for (let row = 0; row <= rowsForPage(page) - span.rows; row += 1) {
      for (
        let column = 0;
        column <= WIDGET_GRID_COLUMNS - span.columns;
        column += 1
      ) {
        const candidate = { ...instance, column, page, row }
        if (fits(candidate, placed)) return candidate
      }
    }
  }
  return null
}

export function deleteWidgetPage(
  layout: WidgetLayout,
  page: number,
  maximumPage: number,
): WidgetLayout {
  if (page < 1 || maximumPage < 1 || page > maximumPage + 1) return layout

  const placed = layout.instances
    .filter((instance) => instance.page !== page)
    .map((instance) => ({
      ...instance,
      page: instance.page > page ? instance.page - 1 : instance.page,
    }))
  const removed = layout.instances.filter((instance) => instance.page === page)
  for (const instance of removed) {
    const positioned = findPosition(
      { ...instance, page: 1 },
      placed,
      1,
      maximumPage,
    )
    if (!positioned) return layout
    placed.push(positioned)
  }

  return { instances: placed, version: 1 }
}

function normalizeSettings(value: unknown): WidgetSettings {
  if (!value || typeof value !== 'object') return {}
  const source = value as WidgetSettings
  return {
    ...(source.balanceSource === 'cash' || source.balanceSource === 'bank'
      ? { balanceSource: source.balanceSource }
      : {}),
    ...(Array.isArray(source.contactIds)
      ? {
          contactIds: source.contactIds
            .filter((id): id is string => typeof id === 'string')
            .slice(0, 6),
        }
      : {}),
    ...(typeof source.showDate === 'boolean'
      ? { showDate: source.showDate }
      : {}),
  }
}

export function createDefaultWidgetLayout(): WidgetLayout {
  return {
    instances: [
      {
        column: 0,
        id: 'home-clock',
        kind: 'clock',
        page: 1,
        row: 0,
        settings: { showDate: true },
        size: 'small',
      },
      {
        column: 2,
        id: 'home-weather',
        kind: 'weather',
        page: 1,
        row: 0,
        settings: {},
        size: 'small',
      },
      {
        column: 0,
        id: 'home-music',
        kind: 'music',
        page: 1,
        row: 2,
        settings: {},
        size: 'medium',
      },
      {
        column: 0,
        id: 'page-date',
        kind: 'date',
        page: 0,
        row: 0,
        settings: {},
        size: 'medium',
      },
      {
        column: 0,
        id: 'page-wallet',
        kind: 'wallet',
        page: 0,
        row: 2,
        settings: { balanceSource: 'bank' },
        size: 'medium',
      },
      {
        column: 0,
        id: 'page-transactions',
        kind: 'transactions',
        page: 0,
        row: 4,
        settings: {},
        size: 'medium',
      },
      {
        column: 0,
        id: 'page-contacts',
        kind: 'contacts',
        page: 0,
        row: 6,
        settings: {},
        size: 'medium',
      },
    ],
    version: 1,
  }
}

export function parseWidgetLayout(value: unknown): WidgetLayout {
  if (!value || typeof value !== 'object') return createDefaultWidgetLayout()
  const source = value as Partial<WidgetLayout>
  if (source.version !== 1 || !Array.isArray(source.instances))
    return createDefaultWidgetLayout()

  const placed: WidgetInstance[] = []
  const ids = new Set<string>()
  for (const raw of source.instances) {
    if (!raw || typeof raw !== 'object') continue
    const candidate = raw as Partial<WidgetInstance>
    if (
      typeof candidate.id !== 'string' ||
      ids.has(candidate.id) ||
      typeof candidate.kind !== 'string' ||
      !WIDGET_REGISTRY_BY_KIND.has(candidate.kind as WidgetKind)
    ) {
      continue
    }
    const definition = WIDGET_REGISTRY_BY_KIND.get(candidate.kind as WidgetKind)
    const size = definition?.supportedSizes.includes(
      candidate.size as WidgetSize,
    )
      ? (candidate.size as WidgetSize)
      : definition?.defaultSize
    if (!size) continue
    const instance: WidgetInstance = {
      column: Math.floor(Number(candidate.column) || 0),
      id: candidate.id,
      kind: candidate.kind as WidgetKind,
      page: Math.max(0, Math.floor(Number(candidate.page) || 0)),
      row: Math.floor(Number(candidate.row) || 0),
      settings: normalizeSettings(candidate.settings),
      size,
    }
    const normalized = fits(instance, placed)
      ? instance
      : findPosition(instance, placed, instance.page)
    if (!normalized) continue
    placed.push(normalized)
    ids.add(normalized.id)
  }
  return { instances: placed, version: 1 }
}

export function addWidget(
  layout: WidgetLayout,
  kind: WidgetKind,
  size: WidgetSize,
  page: number,
): WidgetLayout {
  const definition = WIDGET_REGISTRY_BY_KIND.get(kind)
  if (!definition?.supportedSizes.includes(size)) return layout
  const instance: WidgetInstance = {
    column: 0,
    id: `${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    kind,
    page,
    row: 0,
    settings: {
      ...(kind === 'clock' ? { showDate: true } : {}),
      ...(kind === 'wallet' ? { balanceSource: 'bank' as const } : {}),
    },
    size,
  }
  const positioned = findPosition(instance, layout.instances, page)
  if (!positioned) return layout
  return { instances: [...layout.instances, positioned], version: 1 }
}

export function removeWidget(layout: WidgetLayout, id: string): WidgetLayout {
  return {
    instances: layout.instances.filter((instance) => instance.id !== id),
    version: 1,
  }
}

export function moveWidget(
  layout: WidgetLayout,
  id: string,
  page: number,
  column: number,
  row: number,
): WidgetLayout {
  const moving = layout.instances.find((instance) => instance.id === id)
  if (!moving) return layout
  const span = WIDGET_SPANS[moving.size]
  const requested: WidgetInstance = {
    ...moving,
    column: Math.max(0, Math.min(column, WIDGET_GRID_COLUMNS - span.columns)),
    page,
    row: Math.max(0, Math.min(row, rowsForPage(page) - span.rows)),
  }
  const placed: WidgetInstance[] = [requested]
  for (const instance of layout.instances) {
    if (instance.id === id) continue
    if (fits(instance, placed)) placed.push(instance)
    else {
      const repositioned = findPosition(instance, placed, instance.page)
      if (!repositioned) return layout
      placed.push(repositioned)
    }
  }
  return { instances: placed, version: 1 }
}

export function resizeWidget(
  layout: WidgetLayout,
  id: string,
  size: WidgetSize,
): WidgetLayout {
  const instance = layout.instances.find((candidate) => candidate.id === id)
  const definition = instance && WIDGET_REGISTRY_BY_KIND.get(instance.kind)
  if (!instance || !definition?.supportedSizes.includes(size)) return layout
  const resized = { ...instance, size }
  const remaining = layout.instances.filter((candidate) => candidate.id !== id)
  const positioned = findPosition(resized, remaining, instance.page)
  if (!positioned) return layout
  return {
    instances: [
      ...remaining.map((candidate) => ({ ...candidate })),
      positioned,
    ],
    version: 1,
  }
}

export function updateWidgetSettings(
  layout: WidgetLayout,
  id: string,
  settings: WidgetSettings,
): WidgetLayout {
  return {
    instances: layout.instances.map((instance) =>
      instance.id === id
        ? {
            ...instance,
            settings: normalizeSettings({ ...instance.settings, ...settings }),
          }
        : instance,
    ),
    version: 1,
  }
}

export function widgetOccupiedCells(
  instances: WidgetInstance[],
  page: number,
): Set<number> {
  const cells = new Set<number>()
  for (const instance of instances) {
    if (instance.page !== page) continue
    const span = WIDGET_SPANS[instance.size]
    for (let row = instance.row; row < instance.row + span.rows; row += 1) {
      for (
        let column = instance.column;
        column < instance.column + span.columns;
        column += 1
      ) {
        cells.add(row * WIDGET_GRID_COLUMNS + column)
      }
    }
  }
  return cells
}
