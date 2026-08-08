import type { WidgetDefinition, WidgetKind } from '@/types/widgets'

export const WIDGET_REGISTRY: WidgetDefinition[] = [
  {
    categoryKey: 'Home.widgetSystem.categories.essentials',
    configurable: true,
    defaultSize: 'small',
    descriptionKey: 'Home.widgetSystem.clock.description',
    kind: 'clock',
    labelKey: 'Home.widgetSystem.clock.name',
    supportedSizes: ['small', 'medium'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.essentials',
    configurable: false,
    defaultSize: 'small',
    descriptionKey: 'Home.widgetSystem.date.description',
    kind: 'date',
    labelKey: 'Home.widgetSystem.date.name',
    supportedSizes: ['small', 'medium'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.information',
    configurable: false,
    defaultSize: 'medium',
    descriptionKey: 'Home.widgetSystem.weather.description',
    kind: 'weather',
    labelKey: 'Home.widgetSystem.weather.name',
    supportedSizes: ['small', 'medium', 'large'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.media',
    configurable: false,
    defaultSize: 'medium',
    descriptionKey: 'Home.widgetSystem.music.description',
    kind: 'music',
    labelKey: 'Home.widgetSystem.music.name',
    supportedSizes: ['medium', 'large'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.finance',
    configurable: true,
    defaultSize: 'small',
    descriptionKey: 'Home.widgetSystem.wallet.description',
    kind: 'wallet',
    labelKey: 'Home.widgetSystem.wallet.name',
    supportedSizes: ['small', 'medium'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.finance',
    configurable: false,
    defaultSize: 'medium',
    descriptionKey: 'Home.widgetSystem.transactions.description',
    kind: 'transactions',
    labelKey: 'Home.widgetSystem.transactions.name',
    supportedSizes: ['medium', 'large'],
  },
  {
    categoryKey: 'Home.widgetSystem.categories.people',
    configurable: true,
    defaultSize: 'medium',
    descriptionKey: 'Home.widgetSystem.contacts.description',
    kind: 'contacts',
    labelKey: 'Home.widgetSystem.contacts.name',
    supportedSizes: ['medium', 'large'],
  },
]

export const WIDGET_REGISTRY_BY_KIND = new Map<WidgetKind, WidgetDefinition>(
  WIDGET_REGISTRY.map((definition) => [definition.kind, definition]),
)
