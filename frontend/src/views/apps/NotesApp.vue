<script setup lang="ts">
import {
  kBlock,
  kBlockTitle,
  kLink,
  kList,
  kListButton,
  kListInput,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPopover,
  kSearchbar,
} from 'konsta/vue'
import { Ellipsis, Pin, PinOff, SquarePen, Trash2 } from 'lucide-vue-next'
import {
  computed,
  type ComponentPublicInstance,
  type CSSProperties,
  nextTick,
  ref,
} from 'vue'

import { useNotesStore } from '@/stores/notes'
import { usePhoneStore } from '@/stores/phone'
import type { Note } from '@/utils/notes'

const phone = usePhoneStore()
const notes = useNotesStore()
const searchQuery = ref('')
const editorId = ref<string | null>(null)
const editorOpened = ref(false)
const draftTitle = ref('')
const draftBody = ref('')
const menuButton = ref<ComponentPublicInstance | null>(null)
const menuOpened = ref(false)
const menuTarget = computed(
  () => menuButton.value?.$el as HTMLElement | undefined,
)
const menuTargetStyle = ref<CSSProperties>({})
const pinActionColors = computed(() => ({
  textIos: phone.isDarkMode ? 'text-white' : 'text-black',
  textMaterial: phone.isDarkMode ? 'text-white' : 'text-black',
}))
const deleteActionColors = {
  textIos: 'text-red-500',
  textMaterial: 'text-red-500',
}
const noteBodyStyle: CSSProperties = {
  height: 'calc(100cqh - 210px)',
  resize: 'none',
}
const currentNote = computed(() =>
  editorId.value
    ? notes.notes.find((note) => note.id === editorId.value)
    : undefined,
)

const visibleNotes = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase(phone.lang)
  return [...notes.notes]
    .filter((note) => {
      if (!query) return true
      return `${note.title}\n${note.body}`
        .toLocaleLowerCase(phone.lang)
        .includes(query)
    })
    .sort(
      (left, right) =>
        Number(right.pinned) - Number(left.pinned) ||
        right.updatedAt - left.updatedAt,
    )
})

function noteTitle(note: Note): string {
  return note.title.trim() || phone.t('Apps.notes.untitled')
}

function notePreview(note: Note): string {
  return note.body.trim().replace(/\s+/g, ' ') || phone.t('Apps.notes.noText')
}

function noteDate(note: Note): string {
  const date = new Date(note.updatedAt)
  const sameYear = date.getFullYear() === new Date().getFullYear()
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'short',
    ...(sameYear ? {} : { year: 'numeric' }),
  }).format(date)
}

function noteSubtitle(note: Note): string {
  return `${noteDate(note)} · ${notePreview(note)}`
}

function updateSearch(event: Event): void {
  searchQuery.value = (event.target as HTMLInputElement).value
}

function updateTitle(event: Event): void {
  draftTitle.value = (event.target as HTMLInputElement).value
}

function updateBody(event: Event): void {
  draftBody.value = (event.target as HTMLTextAreaElement).value
}

function createNote(): void {
  editorId.value = null
  draftTitle.value = ''
  draftBody.value = ''
  editorOpened.value = true
}

function editNote(note: Note): void {
  editorId.value = note.id
  draftTitle.value = note.title
  draftBody.value = note.body
  editorOpened.value = true
}

function persistDraft(): Note | undefined {
  const draft = {
    body: draftBody.value.trim(),
    title: draftTitle.value.trim(),
  }

  if (editorId.value) {
    notes.updateNote(editorId.value, draft)
    return notes.notes.find((note) => note.id === editorId.value)
  }
  if (!draft.title && !draft.body) return undefined

  const note = notes.createNote(draft)
  editorId.value = note.id
  return note
}

function saveAndClose(): void {
  persistDraft()
  menuOpened.value = false
  editorOpened.value = false
}

async function openMenu(): Promise<void> {
  if (!persistDraft()) return

  const target = menuTarget.value
  const screen = target?.closest('.phone-screen')
  if (target && screen) {
    const screenRect = screen.getBoundingClientRect()
    menuTargetStyle.value = {
      '--k-safe-area-left': `${Math.round(screenRect.left + 2)}px`,
      '--k-safe-area-right': `${Math.round(
        document.body.offsetWidth - screenRect.right + 2,
      )}px`,
      '--k-safe-area-top': `${Math.round(screenRect.top + 8)}px`,
    }
    await nextTick()
  }

  menuOpened.value = true
}

function deleteNote(): void {
  const note = persistDraft()
  if (!note) return
  notes.deleteNote(note.id)
  menuOpened.value = false
  editorOpened.value = false
}

function togglePinned(): void {
  const note = persistDraft()
  if (!note) return
  notes.togglePinned(note.id)
  menuOpened.value = false
}

</script>

<template>
  <k-page
    v-if="!editorOpened"
    class="!pt-[44px] !pb-[25px]"
    :aria-label="phone.t('Apps.notes.name')"
  >
    <k-navbar
      large
      transparent
      :title="phone.t('Apps.notes.name')"
    >
      <template #right>
        <k-link
          component="button"
          icon-only
          :aria-label="phone.t('Apps.notes.newNote')"
          @click="createNote"
        >
          <SquarePen :size="21" />
        </k-link>
      </template>
      <template #subnavbar>
        <k-searchbar
          :value="searchQuery"
          :placeholder="phone.t('Apps.notes.searchPlaceholder')"
          @input="updateSearch"
          @clear="searchQuery = ''"
        />
      </template>
    </k-navbar>

    <k-list v-if="visibleNotes.length" strong inset>
      <k-list-item
        v-for="note in visibleNotes"
        :key="note.id"
        href="#"
        :title="noteTitle(note)"
        :subtitle="noteSubtitle(note)"
        :chevron="false"
        strong-title="auto"
        @click.prevent="editNote(note)"
      >
        <template v-if="note.pinned" #after>
          <Pin :size="15" aria-hidden="true" />
        </template>
      </k-list-item>
    </k-list>

    <template v-else>
      <k-block-title large>{{
        phone.t(searchQuery ? 'Apps.notes.noResults' : 'Apps.notes.emptyTitle')
      }}</k-block-title>
      <k-block strong inset>{{
        phone.t(
          searchQuery ? 'Apps.notes.noResultsBody' : 'Apps.notes.emptyBody',
        )
      }}</k-block>
      <k-list v-if="!searchQuery" strong inset>
        <k-list-button link-component="button" @click="createNote">
          {{ phone.t('Apps.notes.newNote') }}
        </k-list-button>
      </k-list>
    </template>
  </k-page>

  <k-page v-else class="!pt-[44px] !pb-[25px]">
    <k-navbar :title="phone.t('Apps.notes.note')">
      <template #left>
        <k-navbar-back-link
          component="button"
          :text="phone.t('Apps.notes.back')"
          :aria-label="phone.t('Apps.notes.back')"
          @click="saveAndClose"
        />
      </template>
      <template #right>
        <k-link
          ref="menuButton"
          component="button"
          icon-only
          :style="menuTargetStyle"
          :aria-label="phone.t('Apps.notes.actions')"
          @click="openMenu"
        >
          <Ellipsis :size="22" />
        </k-link>
      </template>
    </k-navbar>

    <k-list nested :dividers="false">
      <k-list-input
        :value="draftTitle"
        :label="phone.t('Apps.notes.title')"
        :placeholder="phone.t('Apps.notes.titlePlaceholder')"
        maxlength="120"
        clear-button
        @input="updateTitle"
        @clear="draftTitle = ''"
      />
      <k-list-input
        type="textarea"
        :value="draftBody"
        :label="phone.t('Apps.notes.body')"
        :placeholder="phone.t('Apps.notes.bodyPlaceholder')"
        :input-style="noteBodyStyle"
        maxlength="20000"
        @input="updateBody"
      />
    </k-list>

    <Teleport to="body">
      <k-popover
        :opened="menuOpened"
        :target="menuTarget"
        :class="{
          dark: phone.isDarkMode,
          'phone-app--light': !phone.isDarkMode,
          [`phone-app--${phone.preferences.settings.graphicsMode}`]: true,
        }"
        angle
        @backdropclick="menuOpened = false"
      >
        <k-list nested>
          <k-list-button
            link-component="button"
            :colors="pinActionColors"
            @click="togglePinned"
          >
            <PinOff v-if="currentNote?.pinned" :size="18" />
            <Pin v-else :size="18" />
            {{
              phone.t(
                currentNote?.pinned ? 'Apps.notes.unpin' : 'Apps.notes.pin',
              )
            }}
          </k-list-button>
          <k-list-button
            link-component="button"
            :colors="deleteActionColors"
            @click="deleteNote"
          >
            <Trash2 :size="18" />
            {{ phone.t('Apps.notes.deleteNote') }}
          </k-list-button>
        </k-list>
      </k-popover>
    </Teleport>
  </k-page>
</template>
