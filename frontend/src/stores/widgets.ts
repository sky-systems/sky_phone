import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'
import type { WidgetKind, WidgetSettings, WidgetSize } from '@/types/widgets'
import {
  addWidget,
  createDefaultWidgetLayout,
  deleteWidgetPage,
  moveWidget,
  parseWidgetLayout,
  removeWidget,
  resizeWidget,
  updateWidgetSettings,
} from '@/utils/widgetLayout'

export const useWidgetsStore = defineStore('widgets', {
  state: () => ({
    layout: createDefaultWidgetLayout(),
  }),
  actions: {
    add(kind: WidgetKind, size: WidgetSize, page: number): string | null {
      const previousIds = new Set(
        this.layout.instances.map((instance) => instance.id),
      )
      const next = addWidget(this.layout, kind, size, page)
      if (next === this.layout) return null
      this.layout = next
      this.persist()
      return (
        this.layout.instances.find((instance) => !previousIds.has(instance.id))
          ?.id ?? null
      )
    },
    hydrate(payload: unknown): void {
      this.layout = parseWidgetLayout(payload)
    },
    deletePage(page: number, maximumPage: number): boolean {
      const next = deleteWidgetPage(this.layout, page, maximumPage)
      if (next === this.layout) return false
      this.layout = next
      this.persist()
      return true
    },
    move(id: string, page: number, column: number, row: number): void {
      const next = moveWidget(this.layout, id, page, column, row)
      if (next === this.layout) return
      this.layout = next
      this.persist()
    },
    remove(id: string): void {
      const next = removeWidget(this.layout, id)
      if (next.instances.length === this.layout.instances.length) return
      this.layout = next
      this.persist()
    },
    resize(id: string, size: WidgetSize): void {
      const next = resizeWidget(this.layout, id, size)
      if (next === this.layout) return
      this.layout = next
      this.persist()
    },
    updateSettings(id: string, settings: WidgetSettings): void {
      this.layout = updateWidgetSettings(this.layout, id, settings)
      this.persist()
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('widgets', this.layout)
    },
  },
})
