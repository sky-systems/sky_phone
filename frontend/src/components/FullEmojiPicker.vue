<script setup lang="ts">
import emojiData from 'emoji-picker-element-data/en/emojibase/data.json'
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

const emojis = computed(() => {
  const needle = query.value.trim().toLocaleLowerCase(phone.lang)
  return (emojiData as EmojiEntry[])
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
          : entry.skins?.find((skin) => skin.tone === skinTone.value)?.emoji ??
            entry.emoji,
    }))
})
</script>

<template>
  <section class="messages-full-emoji-picker" aria-label="Emoji picker">
    <header>
      <strong>{{ phone.t('Apps.messages.emoji') }}</strong>
      <button type="button" :aria-label="phone.t('Common.done')" @click="emit('close')">
        <X :size="18" />
      </button>
    </header>
    <label class="messages-full-emoji-picker__search">
      <Search :size="15" />
      <input
        v-model="query"
        type="search"
        :placeholder="phone.t('Common.search')"
        autocomplete="off"
      />
    </label>
    <nav v-if="!query" aria-label="Emoji categories">
      <button
        v-for="(group, index) in groups"
        :key="group"
        type="button"
        :class="{ active: activeGroup === index }"
        @click="activeGroup = index"
      >
        {{ group }}
      </button>
      <i aria-hidden="true" />
      <button
        v-for="(tone, index) in skinTones"
        :key="tone"
        type="button"
        :class="{ active: skinTone === index }"
        :title="`Skin tone ${index}`"
        @click="skinTone = index"
      >
        {{ tone }}
      </button>
    </nav>
    <div class="messages-full-emoji-picker__grid">
      <button
        v-for="entry in emojis"
        :key="`${entry.emoji}-${entry.annotation}`"
        type="button"
        :title="entry.annotation"
        @click="emit('pick', entry.emoji)"
      >
        {{ entry.emoji }}
      </button>
    </div>
  </section>
</template>
