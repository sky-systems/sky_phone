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

import { SkyButton, SkyIcon, SkyToolbar, SkyToolbarPane } from '@/ui'

export type MailEditorLabels = {
  bold: string
  bulletList: string
  italic: string
  numberedList: string
  quote: string
  redo: string
  toolbar: string
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
      toolbar: 'Formatting tools',
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
    <EditorContent
      v-if="editor"
      class="mail-editor__content"
      :editor="editor"
    />
    <SkyToolbar
      v-if="editable && editor"
      class="mail-editor__tools"
      component="footer"
      :aria-label="labels.toolbar"
    >
      <SkyToolbarPane class="mail-editor__tool-pane">
        <SkyButton
          class="mail-editor__tool"
          :class="{
            'mail-editor__tool--active': editor.isActive('bold'),
          }"
          variant="plain"
          icon-only
          :aria-label="labels.bold"
          :aria-pressed="editor.isActive('bold')"
          @click="editor.chain().focus().toggleBold().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="Bold" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          :class="{
            'mail-editor__tool--active': editor.isActive('italic'),
          }"
          variant="plain"
          icon-only
          :aria-label="labels.italic"
          :aria-pressed="editor.isActive('italic')"
          @click="editor.chain().focus().toggleItalic().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="Italic" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          :class="{
            'mail-editor__tool--active': editor.isActive('bulletList'),
          }"
          variant="plain"
          icon-only
          :aria-label="labels.bulletList"
          :aria-pressed="editor.isActive('bulletList')"
          @click="editor.chain().focus().toggleBulletList().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="List" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          :class="{
            'mail-editor__tool--active': editor.isActive('orderedList'),
          }"
          variant="plain"
          icon-only
          :aria-label="labels.numberedList"
          :aria-pressed="editor.isActive('orderedList')"
          @click="editor.chain().focus().toggleOrderedList().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="ListOrdered" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          :class="{
            'mail-editor__tool--active': editor.isActive('blockquote'),
          }"
          variant="plain"
          icon-only
          :aria-label="labels.quote"
          :aria-pressed="editor.isActive('blockquote')"
          @click="editor.chain().focus().toggleBlockquote().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="Quote" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          variant="plain"
          icon-only
          :disabled="!editor.can().chain().focus().undo().run()"
          :aria-label="labels.undo"
          @click="editor.chain().focus().undo().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="Undo2" /></SkyIcon>
        </SkyButton>
        <SkyButton
          class="mail-editor__tool"
          variant="plain"
          icon-only
          :disabled="!editor.can().chain().focus().redo().run()"
          :aria-label="labels.redo"
          @click="editor.chain().focus().redo().run()"
        >
          <SkyIcon :size="20"><SkyIcon :icon="Redo2" /></SkyIcon>
        </SkyButton>
      </SkyToolbarPane>
    </SkyToolbar>
  </div>
</template>

<style scoped>
.mail-editor {
  width: 100%;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: var(--sky-bg);
  color: var(--sky-text);
}

.mail-editor__content {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.mail-editor__content::-webkit-scrollbar {
  display: none;
}

.mail-editor__tools {
  padding-right: var(--sky-space-3);
  padding-left: var(--sky-space-3);
}

.mail-editor__tools :deep(.sky-toolbar__inner),
.mail-editor__tool-pane {
  width: 100%;
}

.mail-editor__tool {
  min-width: var(--sky-touch-target);
  min-height: var(--sky-touch-target);
  flex: 1 1 0;
  border-radius: 0;
  background: transparent;
  color: var(--sky-button-text, #ffffff);
}

.mail-editor__tool--active {
  background: transparent;
  color: var(--sky-app-accent);
}

:deep(.tiptap) {
  min-height: 100%;
  padding: 15px 16px 124px;
  outline: none;
  font-size: 15px;
  line-height: 1.5;
  white-space: pre-wrap;
}

.mail-editor--readonly {
  height: auto;
  display: block;
  min-height: 0;
  overflow: visible;
}

.mail-editor--readonly .mail-editor__content {
  overflow: visible;
}

.mail-editor--readonly :deep(.tiptap) {
  min-height: 0;
  padding: 0;
  user-select: text;
}

:deep(.tiptap p) {
  margin: 0;
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
