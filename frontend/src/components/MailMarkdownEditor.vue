<script setup lang="ts">
import Placeholder from '@tiptap/extension-placeholder'
import { Markdown } from '@tiptap/markdown'
import StarterKit from '@tiptap/starter-kit'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import DOMPurify from 'dompurify'
import {
  Bold,
  Italic,
  List,
  ListOrdered,
  Quote,
  Redo2,
  Undo2,
} from 'lucide-vue-next'
import { onBeforeUnmount, watch } from 'vue'

export type MailEditorLabels = {
  bold: string
  bulletList: string
  italic: string
  numberedList: string
  quote: string
  redo: string
  undo: string
}

const props = withDefaults(
  defineProps<{
    editable?: boolean
    labels?: MailEditorLabels
    modelValue: string
    placeholder?: string
  }>(),
  {
    editable: true,
    labels: () => ({
      bold: 'Bold',
      bulletList: 'Bullet list',
      italic: 'Italic',
      numberedList: 'Numbered list',
      quote: 'Quote',
      redo: 'Redo',
      undo: 'Undo',
    }),
    placeholder: '',
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

function safeMarkdown(value: string): string {
  return String(
    DOMPurify.sanitize(value.replace(/\r\n?/g, '\n'), {
      ALLOWED_ATTR: [],
      ALLOWED_TAGS: [],
      KEEP_CONTENT: true,
    }),
  )
}

const editor = useEditor({
  content: safeMarkdown(props.modelValue),
  contentType: 'markdown',
  editable: props.editable,
  extensions: [
    StarterKit.configure({
      codeBlock: false,
      heading: { levels: [2, 3] },
      horizontalRule: false,
      link: {
        autolink: true,
        linkOnPaste: true,
        openOnClick: false,
        protocols: ['http', 'https'],
      },
      strike: false,
      underline: false,
    }),
    Markdown.configure({ markedOptions: { breaks: true, gfm: true } }),
    Placeholder.configure({ placeholder: props.placeholder }),
  ],
  injectCSS: false,
  onUpdate: ({ editor: currentEditor }) => {
    emit('update:modelValue', currentEditor.getMarkdown())
  },
})

watch(
  () => props.modelValue,
  (value) => {
    if (!editor.value) return
    const safeValue = safeMarkdown(value)
    if (editor.value.getMarkdown() === safeValue) return
    editor.value.commands.setContent(safeValue, {
      contentType: 'markdown',
      emitUpdate: false,
    })
  },
)

watch(
  () => props.editable,
  (value) => editor.value?.setEditable(value),
)

onBeforeUnmount(() => editor.value?.destroy())
</script>

<template>
  <div class="mail-editor" :class="{ 'mail-editor--readonly': !editable }">
    <div v-if="editable && editor" class="mail-editor__toolbar">
      <button
        type="button"
        :class="{ 'is-active': editor.isActive('bold') }"
        :aria-label="labels.bold"
        :title="labels.bold"
        @click="editor.chain().focus().toggleBold().run()"
      >
        <Bold :size="17" />
      </button>
      <button
        type="button"
        :class="{ 'is-active': editor.isActive('italic') }"
        :aria-label="labels.italic"
        :title="labels.italic"
        @click="editor.chain().focus().toggleItalic().run()"
      >
        <Italic :size="17" />
      </button>
      <button
        type="button"
        :class="{ 'is-active': editor.isActive('bulletList') }"
        :aria-label="labels.bulletList"
        :title="labels.bulletList"
        @click="editor.chain().focus().toggleBulletList().run()"
      >
        <List :size="17" />
      </button>
      <button
        type="button"
        :class="{ 'is-active': editor.isActive('orderedList') }"
        :aria-label="labels.numberedList"
        :title="labels.numberedList"
        @click="editor.chain().focus().toggleOrderedList().run()"
      >
        <ListOrdered :size="17" />
      </button>
      <button
        type="button"
        :class="{ 'is-active': editor.isActive('blockquote') }"
        :aria-label="labels.quote"
        :title="labels.quote"
        @click="editor.chain().focus().toggleBlockquote().run()"
      >
        <Quote :size="17" />
      </button>
      <span class="mail-editor__toolbar-spacer" />
      <button
        type="button"
        :disabled="!editor.can().chain().focus().undo().run()"
        :aria-label="labels.undo"
        :title="labels.undo"
        @click="editor.chain().focus().undo().run()"
      >
        <Undo2 :size="17" />
      </button>
      <button
        type="button"
        :disabled="!editor.can().chain().focus().redo().run()"
        :aria-label="labels.redo"
        :title="labels.redo"
        @click="editor.chain().focus().redo().run()"
      >
        <Redo2 :size="17" />
      </button>
    </div>
    <EditorContent v-if="editor" :editor="editor" />
  </div>
</template>

<style scoped>
.mail-editor {
  min-height: 210px;
  color: #f5f5f7;
}

.mail-editor__toolbar {
  position: sticky;
  z-index: 2;
  top: 0;
  display: flex;
  align-items: center;
  gap: 3px;
  min-height: 43px;
  padding: 5px 7px;
  border-bottom: 1px solid #ffffff14;
  background: #1c1c1ee8;
  backdrop-filter: blur(18px) saturate(160%);
  -webkit-backdrop-filter: blur(18px) saturate(160%);
}

.mail-editor__toolbar button {
  display: grid;
  width: 32px;
  height: 32px;
  place-items: center;
  border: 0;
  border-radius: 9px;
  background: transparent;
  color: #f5f5f7;
  cursor: pointer;
}

.mail-editor__toolbar button.is-active {
  background: #0a84ff;
  color: #fff;
}

.mail-editor__toolbar button:disabled {
  opacity: 0.28;
  cursor: default;
}

.mail-editor__toolbar-spacer {
  flex: 1;
}

:deep(.tiptap) {
  min-height: 210px;
  padding: 15px 16px 92px;
  outline: none;
  font-size: 15px;
  line-height: 1.5;
  white-space: pre-wrap;
}

.mail-editor--readonly {
  min-height: 0;
}

.mail-editor--readonly :deep(.tiptap) {
  min-height: 0;
  padding: 0;
  user-select: text;
}

:deep(.tiptap p) {
  margin: 0 0 0.8em;
}

:deep(.tiptap p:last-child) {
  margin-bottom: 0;
}

:deep(.tiptap h2),
:deep(.tiptap h3) {
  margin: 1em 0 0.4em;
  line-height: 1.2;
}

:deep(.tiptap ul),
:deep(.tiptap ol) {
  margin: 0.55em 0 0.85em;
  padding-left: 1.45em;
}

:deep(.tiptap blockquote) {
  margin: 0.85em 0;
  padding-left: 0.9em;
  border-left: 3px solid #5e5e63;
  color: #a1a1a6;
}

:deep(.tiptap a) {
  color: #0a84ff;
  text-decoration: none;
}

:deep(.tiptap p.is-editor-empty:first-child::before) {
  float: left;
  height: 0;
  color: #8e8e93;
  content: attr(data-placeholder);
  pointer-events: none;
}
</style>
