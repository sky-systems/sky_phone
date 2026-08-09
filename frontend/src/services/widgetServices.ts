import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { useBankingStore } from '@/stores/banking'
import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import { useWeatherStore } from '@/stores/weather'

const now = ref(new Date())
let clockConsumers = 0
let clockInterval: number | undefined

const tracks = [
  { artist: 'Sky Radio', title: 'Night Drive' },
  { artist: 'Los Santos FM', title: 'Pacific Coast' },
  { artist: 'Mirror Park', title: 'After Hours' },
]
const trackIndex = ref(0)
const playing = ref(false)

export function useClockService() {
  const phone = usePhoneStore()
  onMounted(() => {
    clockConsumers += 1
    if (clockInterval === undefined) {
      clockInterval = window.setInterval(() => {
        now.value = new Date()
      }, 1000)
    }
  })
  onBeforeUnmount(() => {
    clockConsumers -= 1
    if (clockConsumers === 0 && clockInterval !== undefined) {
      window.clearInterval(clockInterval)
      clockInterval = undefined
    }
  })
  return {
    date: computed(() =>
      new Intl.DateTimeFormat(phone.lang, {
        day: 'numeric',
        month: 'long',
        weekday: 'long',
      }).format(now.value),
    ),
    day: computed(() => now.value.getDate()),
    month: computed(() =>
      new Intl.DateTimeFormat(phone.lang, { month: 'long' }).format(now.value),
    ),
    time: computed(() =>
      new Intl.DateTimeFormat(phone.lang, {
        hour: '2-digit',
        hour12: false,
        minute: '2-digit',
      }).format(now.value),
    ),
    weekday: computed(() =>
      new Intl.DateTimeFormat(phone.lang, { weekday: 'long' }).format(
        now.value,
      ),
    ),
  }
}

export function useWeatherService() {
  const phone = usePhoneStore()
  const weather = useWeatherStore()
  return {
    condition: computed(() =>
      weather.forecast
        ? phone.t(`Apps.weather.conditions.${weather.forecast.condition}`)
        : phone.t('Common.loading'),
    ),
    forecast: computed(() => weather.forecast),
    location: computed(() =>
      phone.t(
        `Apps.weather.regions.${weather.forecast?.region ?? 'los_santos'}`,
      ),
    ),
  }
}

export function useMusicService() {
  return {
    current: computed(() => tracks[trackIndex.value]),
    next(): void {
      trackIndex.value = (trackIndex.value + 1) % tracks.length
      playing.value = true
    },
    playing,
    toggle(): void {
      playing.value = !playing.value
    },
  }
}

export function useBankService() {
  const banking = useBankingStore()
  const overview = computed(
    () =>
      banking.overview ?? {
        bank: 24_580,
        cash: 1_240,
        currency: '$',
        playerId: 0,
        playerName: 'Sky Citizen',
        transactions: [
          {
            amount: 1800,
            createdAt: Date.now() - 3_600_000,
            id: -1,
            kind: 'deposit' as const,
            label: 'Salary',
            reference: 'PAYROLL',
          },
          {
            amount: 86,
            createdAt: Date.now() - 7_200_000,
            id: -2,
            kind: 'withdrawal' as const,
            label: 'Fuel',
            reference: 'CARD',
          },
          {
            amount: 340,
            createdAt: Date.now() - 18_000_000,
            id: -3,
            kind: 'transfer_out' as const,
            label: 'Transfer',
            reference: 'PHONE',
          },
        ],
      },
  )
  onMounted(() => {
    if (!banking.overview && !banking.isLoading) void banking.load()
  })
  return { overview }
}

export function useContactsService() {
  const calls = useCallsStore()
  const contacts = computed(() =>
    calls.contacts.length
      ? calls.contacts
      : [
          { id: 'mock-nova', name: 'Nova', phone_number: '555-0142' },
          { id: 'mock-alex', name: 'Alex', phone_number: '555-0198' },
          { id: 'mock-mia', name: 'Mia', phone_number: '555-0121' },
          { id: 'mock-liam', name: 'Liam', phone_number: '555-0177' },
        ],
  )
  onMounted(() => {
    if (!calls.contacts.length) void calls.loadContacts()
  })
  return { contacts }
}
