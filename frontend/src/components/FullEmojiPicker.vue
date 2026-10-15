<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

import deEmojiData from 'emoji-picker-element-data/de/cldr/data.json'
import enEmojiData from 'emoji-picker-element-data/en/cldr/data.json'
import { Search, X } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'

type EmojiEntry = {
  annotation: string
  emoji: string
  group: number
  skins?: Array<{ emoji: string; tone: number }>
  shortcodes?: string[]
  tags?: string[]
}

const emit = defineEmits<{
  close: []
  pick: [emoji: string]
}>()

const phone = usePhoneStore()
const query = ref('')
const activeGroup = ref(0)
const skinTone = ref(0)
const groups = ['😀', '👋', '🧑', '🐻', '🍔', '⚽', '🚗', '💡', '❤️', '🏳️']
const skinTones = ['✋', '✋🏻', '✋🏼', '✋🏽', '✋🏾', '✋🏿']
const localizedEmojiData = computed(() =>
  phone.lang.toLocaleLowerCase().startsWith('de') ? deEmojiData : enEmojiData,
)

const emojis = computed(() => {
  const needle = query.value.trim().toLocaleLowerCase(phone.lang)
  return (localizedEmojiData.value as EmojiEntry[])
    .filter((entry) => {
      if (!needle) return entry.group === activeGroup.value
      return `${entry.annotation} ${entry.shortcodes?.join(' ') ?? ''} ${entry.tags?.join(' ') ?? ''}`
        .toLocaleLowerCase(phone.lang)
        .includes(needle)
    })
    .map((entry) => ({
      ...entry,
      emoji:
        skinTone.value === 0
          ? entry.emoji
          : (entry.skins?.find((skin) => skin.tone === skinTone.value)?.emoji ??
            entry.emoji),
    }))
})
</script>

<template>
  <section
    class="messages-full-emoji-picker"
    :aria-label="phone.t('Apps.messages.emojiPicker')"
  >
    <header>
      <strong>{{ phone.t('Apps.messages.emoji') }}</strong>
      <SkyButton
        variant="content"
        type="button"
        :aria-label="phone.t('Common.done')"
        @click="emit('close')"
      >
        <SkyIcon :icon="X" :size="18" />
      </SkyButton>
    </header>
    <label class="messages-full-emoji-picker__search">
      <SkyIcon :icon="Search" :size="15" />
      <input
        v-model="query"
        type="search"
        :placeholder="phone.t('Common.search')"
        autocomplete="off"
      />
    </label>
    <nav v-if="!query" :aria-label="phone.t('Apps.messages.emojiCategories')">
      <SkyButton
        variant="content"
        v-for="(group, index) in groups"
        :key="group"
        type="button"
        :class="{ active: activeGroup === index }"
        @click="activeGroup = index"
      >
        {{ group }}
      </SkyButton>
      <i aria-hidden="true" />
      <SkyButton
        variant="content"
        v-for="(tone, index) in skinTones"
        :key="tone"
        type="button"
        :class="{ active: skinTone === index }"
        :title="phone.t('Apps.messages.skinTone', { number: String(index) })"
        @click="skinTone = index"
      >
        {{ tone }}
      </SkyButton>
    </nav>
    <div class="messages-full-emoji-picker__grid">
      <SkyButton
        variant="content"
        v-for="entry in emojis"
        :key="`${entry.emoji}-${entry.annotation}`"
        type="button"
        :title="entry.annotation"
        @click="emit('pick', entry.emoji)"
      >
        {{ entry.emoji }}
      </SkyButton>
    </div>
  </section>
</template>
