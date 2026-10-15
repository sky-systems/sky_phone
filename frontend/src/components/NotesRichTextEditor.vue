<script setup lang="ts">
import Placeholder from '@tiptap/extension-placeholder'
import StarterKit from '@tiptap/starter-kit'
import { Mark, mergeAttributes } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import DOMPurify from 'dompurify'
import {
  Bold,
  Italic,
  List,
  ListOrdered,
  Quote,
  Redo2,
  Strikethrough,
  Underline,
  Undo2,
  X,
} from 'lucide-vue-next'
import { onBeforeUnmount, ref, watch } from 'vue'

import { SkyIcon, SkyTabBar, SkyTabButton } from '@/ui'
import {
  noteBodyToEditorHtml,
  serializeRichNoteBody,
} from '@/utils/noteRichText'

export type NotesEditorLabels = {
  bold: string
  bulletList: string
  decreaseText: string
  increaseText: string
  italic: string
  numberedList: string
  quote: string
  redo: string
  strike: string
  toolbar: string
  closeFormatting: string
  underline: string
  undo: string
}

const props = defineProps<{
  dark: boolean
  labels: NotesEditorLabels
  modelValue: string
  placeholder: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const formatMode = ref(false)

const allowedTags = [
  'blockquote',
  'br',
  'em',
  'h1',
  'h2',
  'h3',
  'li',
  'ol',
  'p',
  's',
  'strong',
  'span',
  'u',
  'ul',
]

const noteTextSizeSteps = [
  'tiny',
  'small',
  'compact',
  'normal',
  'medium',
  'large',
  'huge',
] as const
type NoteTextSizeStep = (typeof noteTextSizeSteps)[number]
const normalTextSizeIndex = noteTextSizeSteps.indexOf('normal')

const NoteTextSize = Mark.create({
  name: 'noteTextSize',
  addAttributes() {
    return {
      size: {
        default: null,
        parseHTML: (element) => {
          const size = element.getAttribute('data-note-size')
          return noteTextSizeSteps.includes(size as NoteTextSizeStep) &&
            size !== 'normal'
            ? size
            : null
        },
        renderHTML: (attributes) => {
          const size = attributes.size as NoteTextSizeStep | undefined
          return size && noteTextSizeSteps.includes(size) && size !== 'normal'
            ? { 'data-note-size': size }
            : {}
        },
      },
    }
  },
  parseHTML() {
    return [{ tag: 'span[data-note-size]' }]
  },
  renderHTML({ HTMLAttributes }) {
    return ['span', mergeAttributes(HTMLAttributes), 0]
  },
})

function sanitizeEditorHtml(body: string): string {
  return String(
    DOMPurify.sanitize(noteBodyToEditorHtml(body), {
      ALLOWED_ATTR: ['data-note-size'],
      ALLOWED_TAGS: allowedTags,
    }),
  )
}

function withFirstLineHeading(html: string): string {
  const match = html.match(
    /^(\s*)<(p|h[1-3])(?:\s[^>]*)?>([\s\S]*?)<\/\2>([\s\S]*)$/i,
  )
  if (!match) return `<h1></h1>${html}`

  return `${match[1]}<h1>${match[3]}</h1>${match[4]}`
}

let acceptedHtml = withFirstLineHeading(sanitizeEditorHtml(props.modelValue))

const editor = useEditor({
  content: acceptedHtml,
  extensions: [
    StarterKit.configure({
      code: false,
      codeBlock: false,
      heading: { levels: [1, 2, 3] },
      horizontalRule: false,
      link: false,
      strike: {},
      underline: {},
    }),
    NoteTextSize,
    Placeholder.configure({ placeholder: props.placeholder }),
  ],
  injectCSS: false,
  editorProps: {
    handleKeyDown: (view, event) => {
      if (event.key !== 'Backspace' || !view.state.selection.empty) return false

      const { doc, selection } = view.state
      const firstLine = doc.firstChild
      return (
        firstLine?.type.name === 'heading' &&
        firstLine.attrs.level === 1 &&
        firstLine.content.size === 0 &&
        selection.$from.parent === firstLine
      )
    },
  },
  onUpdate: ({ editor: currentEditor }) => {
    const safeHtml = String(
      DOMPurify.sanitize(currentEditor.getHTML(), {
        ALLOWED_ATTR: ['data-note-size'],
        ALLOWED_TAGS: allowedTags,
      }),
    )
    const serializedBody = serializeRichNoteBody(safeHtml)
    if (serializedBody.length > 20_000) {
      currentEditor.commands.setContent(acceptedHtml, { emitUpdate: false })
      return
    }
    acceptedHtml = safeHtml
    emit('update:modelValue', serializedBody)
  },
})

function adjustTextSize(direction: -1 | 1): void {
  if (!editor.value || editor.value.state.selection.empty) return

  const currentSize = editor.value.getAttributes('noteTextSize').size as
    | NoteTextSizeStep
    | undefined
  const currentIndex = currentSize
    ? noteTextSizeSteps.indexOf(currentSize)
    : normalTextSizeIndex
  const nextIndex = Math.max(
    0,
    Math.min(
      noteTextSizeSteps.length - 1,
      (currentIndex >= 0 ? currentIndex : normalTextSizeIndex) + direction,
    ),
  )
  const nextSize = noteTextSizeSteps[nextIndex]
  const chain = editor.value.chain().focus()

  if (nextSize === 'normal') {
    chain.unsetMark('noteTextSize').run()
    return
  }

  chain.setMark('noteTextSize', { size: nextSize }).run()
}

function toggleSelectionQuote(): void {
  if (!editor.value || editor.value.state.selection.empty) return

  const { from, to } = editor.value.state.selection
  const { doc, tr } = editor.value.state
  const selectedText = doc.textBetween(from, to)
  const isQuotedInside =
    selectedText.startsWith('„') && selectedText.endsWith('“')
  const isQuotedOutside =
    from > 1 &&
    doc.textBetween(from - 1, from) === '„' &&
    doc.textBetween(to, to + 1) === '“'

  if (isQuotedInside) {
    tr.delete(to - 1, to).delete(from, from + 1)
    tr.setSelection(TextSelection.create(tr.doc, from, to - 2))
  } else if (isQuotedOutside) {
    tr.delete(to, to + 1).delete(from - 1, from)
    tr.setSelection(TextSelection.create(tr.doc, from - 1, to - 1))
  } else {
    tr.insertText('“', to).insertText('„', from)
    tr.setSelection(TextSelection.create(tr.doc, from + 1, to + 1))
  }

  editor.value.view.dispatch(tr)
  editor.value.view.focus()
}

function hasActiveTextFormat(): boolean {
  if (!editor.value) return false
  const size = editor.value.getAttributes('noteTextSize').size
  return (
    Boolean(size) ||
    editor.value.isActive('bold') ||
    editor.value.isActive('italic') ||
    editor.value.isActive('underline') ||
    editor.value.isActive('strike')
  )
}

watch(
  () => props.modelValue,
  (body) => {
    if (!editor.value) return
    const safeHtml = withFirstLineHeading(sanitizeEditorHtml(body))
    if (editor.value.getHTML() === safeHtml) return
    acceptedHtml = safeHtml
    editor.value.commands.setContent(safeHtml, { emitUpdate: false })
  },
)

onBeforeUnmount(() => editor.value?.destroy())
</script>

<template>
  <section
    class="notes-rich-editor sky-ui-provider"
    :class="{
      'notes-rich-editor--dark': dark,
      'sky-ui-provider--dark': dark,
    }"
  >
    <EditorContent
      v-if="editor"
      class="notes-rich-editor__content"
      :editor="editor"
    />

    <SkyTabBar v-if="editor" :label="labels.toolbar" :labels="false">
      <template v-if="!formatMode">
        <SkyTabButton
          :aria-label="labels.undo"
          :disabled="!editor.can().chain().focus().undo().run()"
          @click="editor.chain().focus().undo().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Undo2" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :aria-label="labels.redo"
          :disabled="!editor.can().chain().focus().redo().run()"
          @click="editor.chain().focus().redo().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Redo2" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :active="hasActiveTextFormat()"
          :aria-label="labels.toolbar"
          @click="formatMode = true"
        >
          <span class="notes-rich-editor__format-tool">Aa</span>
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('bulletList')"
          :aria-label="labels.bulletList"
          @click="editor.chain().focus().toggleBulletList().run()"
        >
          <template #icon
            ><SkyIcon :size="21"><SkyIcon :icon="List" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('orderedList')"
          :aria-label="labels.numberedList"
          @click="editor.chain().focus().toggleOrderedList().run()"
        >
          <template #icon
            ><SkyIcon :size="21"><SkyIcon :icon="ListOrdered" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :aria-label="labels.quote"
          :disabled="editor.state.selection.empty"
          @pointerdown.prevent="toggleSelectionQuote"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Quote" /></SkyIcon
          ></template>
        </SkyTabButton>
      </template>

      <template v-else>
        <SkyTabButton
          :active="
            ['tiny', 'small', 'compact'].includes(
              editor.getAttributes('noteTextSize').size,
            )
          "
          :aria-label="labels.decreaseText"
          :disabled="editor.state.selection.empty"
          @pointerdown.prevent="adjustTextSize(-1)"
        >
          <span class="notes-rich-editor__text-tool">A−</span>
        </SkyTabButton>
        <SkyTabButton
          :active="
            ['medium', 'large', 'huge'].includes(
              editor.getAttributes('noteTextSize').size,
            )
          "
          :aria-label="labels.increaseText"
          :disabled="editor.state.selection.empty"
          @pointerdown.prevent="adjustTextSize(1)"
        >
          <span
            class="notes-rich-editor__text-tool notes-rich-editor__text-tool--large"
            >A+</span
          >
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('bold')"
          :aria-label="labels.bold"
          @click="editor.chain().focus().toggleBold().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Bold" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('italic')"
          :aria-label="labels.italic"
          @click="editor.chain().focus().toggleItalic().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Italic" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('underline')"
          :aria-label="labels.underline"
          @click="editor.chain().focus().toggleUnderline().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Underline" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :active="editor.isActive('strike')"
          :aria-label="labels.strike"
          @click="editor.chain().focus().toggleStrike().run()"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="Strikethrough" /></SkyIcon
          ></template>
        </SkyTabButton>
        <SkyTabButton
          :aria-label="labels.closeFormatting"
          @click="formatMode = false"
        >
          <template #icon
            ><SkyIcon :size="20"><SkyIcon :icon="X" /></SkyIcon
          ></template>
        </SkyTabButton>
      </template>
    </SkyTabBar>
  </section>
</template>

<style scoped>
.notes-rich-editor {
  min-height: 0;
  display: flex;
  flex: 1;
  flex-direction: column;
  overflow: hidden;
  background: #fff;
  color: #171719;
}

.notes-rich-editor--dark {
  background: #000;
  color: #f5f5f7;
}

.notes-rich-editor__content {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.notes-rich-editor__content::-webkit-scrollbar {
  display: none;
}

:deep(.tiptap) {
  min-height: 100%;
  padding: 13px var(--sky-page-gutter) 90px;
  outline: none;
  font-size: 17px;
  line-height: 1.48;
  word-break: break-word;
}

:deep(.tiptap p) {
  min-height: 1.48em;
  margin: 0 0 0.55em;
}

:deep(.tiptap h1),
:deep(.tiptap h2),
:deep(.tiptap h3) {
  margin: 0.75em 0 0.35em;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

:deep(.tiptap h1) {
  font-size: 32px;
}

:deep(.tiptap h2) {
  font-size: 28px;
}

:deep(.tiptap h3) {
  font-size: 22px;
}

:deep(.tiptap span[data-note-size='tiny']) {
  font-size: 11px;
}

:deep(.tiptap span[data-note-size='small']) {
  font-size: 13px;
}

:deep(.tiptap span[data-note-size='compact']) {
  font-size: 15px;
}

:deep(.tiptap span[data-note-size='medium']) {
  font-size: 20px;
}

:deep(.tiptap span[data-note-size='large']) {
  font-size: 23px;
}

:deep(.tiptap span[data-note-size='huge']) {
  font-size: 28px;
}

:deep(.tiptap ul),
:deep(.tiptap ol) {
  margin: 0.45em 0 0.75em;
  padding-left: 1.45em;
  list-style-position: outside;
}

:deep(.tiptap ul) {
  list-style-type: disc;
}

:deep(.tiptap ol) {
  list-style-type: decimal;
}

:deep(.tiptap ul ul) {
  list-style-type: circle;
}

:deep(.tiptap ol ol) {
  list-style-type: lower-alpha;
}

:deep(.tiptap li) {
  margin: 0.2em 0;
}

:deep(.tiptap blockquote) {
  margin: 0.65em 0;
  padding-left: 0.85em;
  border-left: 3px solid #ffcc00;
  color: #636366;
}

.notes-rich-editor--dark :deep(.tiptap blockquote) {
  color: #a1a1a6;
}

:deep(.tiptap p.is-editor-empty:first-child::before) {
  float: left;
  height: 0;
  color: #8e8e93;
  content: attr(data-placeholder);
  pointer-events: none;
}

.notes-rich-editor__text-tool {
  font-size: 14px;
  font-weight: 650;
}

.notes-rich-editor__text-tool--large {
  font-size: 17px;
}

.notes-rich-editor__format-tool {
  font-size: 17px;
  font-weight: 500;
  letter-spacing: -0.03em;
}
</style>
