<script setup lang="ts">
import {
  kActions,
  kActionsButton,
  kActionsGroup,
  kBlock,
  kBlockTitle,
  kDialog,
  kDialogButton,
  kLink,
  kList,
  kListButton,
  kListInput,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kSearchbar,
} from 'konsta/vue'
import { Ellipsis, Pin, SquarePen } from 'lucide-vue-next'
import { computed, type CSSProperties, ref } from 'vue'

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
const deleteCandidate = ref<Note | null>(null)
const menuOpened = ref(false)
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

function openMenu(): void {
  if (persistDraft()) menuOpened.value = true
}

function requestDelete(): void {
  const note = persistDraft()
  if (!note) return
  menuOpened.value = false
  deleteCandidate.value = note
}

function togglePinned(): void {
  const note = persistDraft()
  if (!note) return
  notes.togglePinned(note.id)
  menuOpened.value = false
}

function confirmDelete(): void {
  if (!deleteCandidate.value) return
  notes.deleteNote(deleteCandidate.value.id)
  deleteCandidate.value = null
  editorOpened.value = false
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
        link
        link-component="button"
        :title="noteTitle(note)"
        :subtitle="noteSubtitle(note)"
        :chevron="false"
        strong-title="auto"
        @click="editNote(note)"
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
          component="button"
          icon-only
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

    <k-actions
      :opened="menuOpened"
      @backdropclick="menuOpened = false"
    >
      <k-actions-group>
        <k-actions-button @click="togglePinned">
          {{
            phone.t(currentNote?.pinned ? 'Apps.notes.unpin' : 'Apps.notes.pin')
          }}
        </k-actions-button>
        <k-actions-button @click="requestDelete">
          {{ phone.t('Apps.notes.deleteNote') }}
        </k-actions-button>
      </k-actions-group>
      <k-actions-group>
        <k-actions-button bold @click="menuOpened = false">
          {{ phone.t('Common.cancel') }}
        </k-actions-button>
      </k-actions-group>
    </k-actions>
  </k-page>

  <k-dialog
    :opened="Boolean(deleteCandidate)"
    :title="phone.t('Apps.notes.deleteTitle')"
    :content="phone.t('Apps.notes.deleteBody')"
    @backdropclick="deleteCandidate = null"
  >
    <template #buttons>
      <k-dialog-button @click="deleteCandidate = null">
        {{ phone.t('Common.cancel') }}
      </k-dialog-button>
      <k-dialog-button strong @click="confirmDelete">
        {{ phone.t('Common.delete') }}
      </k-dialog-button>
    </template>
  </k-dialog>
</template>
