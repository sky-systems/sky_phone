<script setup lang="ts">
import {
  ChevronDown,
  Gamepad2,
  LayoutGrid,
  PackageOpen,
  ScrollText,
  Search,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import {
  SkyApp,
  SkyAdminRecords,
  SkyButton,
  SkyCard,
  SkyEmptyState,
  SkyField,
  SkyGlass,
  SkyInfiniteLoader,
  SkyListCard,
  SkyListItem,
  SkyNavbarBackLink,
  SkyPillNavigation,
  SkyProvider,
  SkyScrollRail,
  SkySection,
  SkySegmented,
  SkySegmentedButton,
  SkySettingsGroup,
  SkySettingsIcon,
  SkySettingsRangeRow,
  SkySettingsRow,
  SkyStatusCard,
  SkySurface,
  SkyWidgetFrame,
} from '@/ui'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'
import { useSkyUiDemoContext } from '../context'

const range = ref(45)
const notifications = ref(true)
const selectedChoice = ref<'automatic' | 'manual'>('automatic')
const fullTab = ref(0)
const compactTab = ref(0)
const splitTab = ref(0)
const loaderState = ref<'error' | 'loading' | 'ready'>('loading')
const adminCategory = ref('all')
const demo = useSkyUiDemoContext()
const fullNavigationItems = [
  { icon: LayoutGrid, label: 'Apps' },
  { icon: Gamepad2, label: 'Games' },
  { icon: Search, label: 'Search' },
] as const

const loaderError = computed(() =>
  loaderState.value === 'error' ? 'Could not load the next page.' : false,
)

function retryLoading(): void {
  loaderState.value = 'loading'
}

function requestLoading(): void {
  loaderState.value = 'loading'
}

function resetExamples(): void {
  range.value = 45
  notifications.value = true
  selectedChoice.value = 'automatic'
  fullTab.value = 0
  compactTab.value = 0
  splitTab.value = 0
  adminCategory.value = 'all'
  loaderState.value = 'loading'
}
</script>

<template>
  <SkyUiDemoPage padded title="Sky Extensions">
    <SkySection title="Status and empty states">
      <div class="sky-ui-demo-stack">
        <SkyStatusCard
          class="sky-ui-demo-extension-status"
          indicator
          subtitle="Sky-only status primitive"
          title="Ready"
          tone="success"
        />
        <SkyEmptyState
          class="sky-ui-demo-extension-empty"
          body="No additional results are available."
          compact
          title="Nothing here"
        >
          <template #icon
            ><PackageOpen :size="32" aria-hidden="true"
          /></template>
          <template #actions><SkyButton rounded>Action</SkyButton></template>
        </SkyEmptyState>
        <SkyStatusCard
          v-if="loaderState === 'error'"
          aria-live="polite"
          class="sky-ui-demo-extension-status"
          subtitle="Use Retry to return to the loading state."
          title="Additional results unavailable"
          tone="danger"
        />
        <SkyInfiniteLoader
          :error="loaderError"
          :has-more="loaderState !== 'ready'"
          :load-key="loaderState"
          :loading="loaderState === 'loading'"
          loading-label="Loading more results"
          retry-label="Retry loading results"
          @load="requestLoading"
          @retry="retryLoading"
        />
        <div
          class="sky-ui-demo-extension-state-actions"
          role="group"
          aria-label="Infinite loader state"
        >
          <SkyButton
            :aria-pressed="loaderState === 'loading'"
            inline
            rounded
            small
            :variant="loaderState === 'loading' ? 'primary' : 'secondary'"
            @click="loaderState = 'loading'"
          >
            Loading
          </SkyButton>
          <SkyButton
            :aria-pressed="loaderState === 'error'"
            inline
            rounded
            small
            :variant="loaderState === 'error' ? 'danger' : 'secondary'"
            @click="loaderState = 'error'"
          >
            Error
          </SkyButton>
          <SkyButton
            :aria-pressed="loaderState === 'ready'"
            inline
            rounded
            small
            :variant="loaderState === 'ready' ? 'primary' : 'secondary'"
            @click="loaderState = 'ready'"
          >
            Ready
          </SkyButton>
        </div>
      </div>
    </SkySection>

    <SkySection title="Cards and horizontal rail">
      <div class="sky-ui-demo-stack">
        <SkyListCard inset strong>
          <SkyListItem
            title="SkyListCard"
            subtitle="A list surface extension"
          />
        </SkyListCard>
        <SkyScrollRail label="Card examples">
          <SkyCard
            v-for="index in 4"
            :key="index"
            class="sky-ui-demo-extension-card"
          >
            Card {{ index }}
          </SkyCard>
        </SkyScrollRail>
      </div>
    </SkySection>

    <SkySection title="Admin records">
      <div class="sky-ui-demo-stack">
        <SkyField
          v-model="adminCategory"
          component="div"
          variant="admin"
          type="select"
          dropdown
          label="App"
          :options="[
            { value: 'all', label: 'All apps' },
            { value: 'feather', label: 'Feather' },
          ]"
        />
        <SkyAdminRecords aria-label="Admin record example">
          <li>
            <details>
              <summary class="sky-admin-records__summary">
                <span class="sky-admin-records__icon"
                  ><ScrollText :size="15"
                /></span>
                <span class="sky-admin-records__copy">
                  <span class="sky-admin-records__title"
                    ><strong>Feather · Created</strong
                    ><time>31.10.2026, 12:30</time></span
                  >
                  <span class="sky-admin-records__meta"
                    >Example player · ID 1</span
                  >
                  <span class="sky-admin-records__preview"
                    >A compact record with additional context available on
                    expansion.</span
                  >
                </span>
                <ChevronDown class="sky-admin-records__chevron" :size="14" />
              </summary>
              <div class="sky-admin-records__details">
                <p>
                  Keyboard-accessible disclosure keeps detailed record content
                  out of the summary.
                </p>
                <dl>
                  <dt>Action ID</dt>
                  <dd><code>feather:create-post</code></dd>
                </dl>
              </div>
            </details>
          </li>
        </SkyAdminRecords>
      </div>
    </SkySection>

    <SkySection title="Surface and nested theme provider">
      <div class="sky-ui-demo-stack">
        <SkySurface class="sky-ui-demo-extension-surface" highlight>
          <span class="sky-ui-demo-extension-preview-copy">
            <strong>SkySurface</strong>
            <small>Accent-aware content surface</small>
          </span>
        </SkySurface>
        <SkyProvider
          :accent="demo.accent.value"
          :accent-soft="demo.accentSoft.value"
          :dark="demo.dark.value"
          :safe-areas="false"
        >
          <SkyApp
            class="sky-ui-demo-extension-app"
            :accent="demo.accent.value"
            :accent-soft="demo.accentSoft.value"
            :dark="demo.dark.value"
            :safe-areas="false"
          >
            <span class="sky-ui-demo-extension-preview-copy">
              <strong>Nested SkyApp</strong>
              <small>Follows the current demo theme</small>
            </span>
          </SkyApp>
        </SkyProvider>
      </div>
    </SkySection>

    <SkySection title="Widget sizes">
      <div class="sky-ui-demo-extension-widgets">
        <SkyWidgetFrame
          v-for="size in ['small', 'medium', 'large'] as const"
          :key="size"
          :label="`${size} widget`"
          :size="size"
        >
          <SkySurface class="sky-ui-demo-extension-widget">
            {{ size }}
          </SkySurface>
        </SkyWidgetFrame>
      </div>
    </SkySection>

    <SkySection title="Glass and standalone back link">
      <div class="sky-ui-demo-extension-controls">
        <SkyGlass class="sky-ui-demo-extension-glass" component="button">
          Interactive SkyGlass
        </SkyGlass>
        <SkyNavbarBackLink
          ariaLabel="Standalone back link example"
          show-text
          text="Back"
          @click="demo.returnToCatalog"
        />
      </div>
    </SkySection>

    <SkySettingsGroup
      class="sky-ui-demo-extension-settings"
      title="Settings extensions"
    >
      <SkySettingsRow kind="navigation" title="Navigation row">
        <template #leading><SkySettingsIcon>S</SkySettingsIcon></template>
      </SkySettingsRow>
      <SkySettingsRow
        v-model="notifications"
        description="Uses the toggle row variant"
        kind="toggle"
        title="Notifications"
      />
      <SkySettingsRow
        kind="choice"
        :selected="selectedChoice === 'automatic'"
        title="Automatic"
        @activate="selectedChoice = 'automatic'"
      />
      <SkySettingsRow
        kind="choice"
        :selected="selectedChoice === 'manual'"
        title="Manual"
        @activate="selectedChoice = 'manual'"
      />
      <SkySettingsRow kind="value" title="Current mode" value="High" />
      <SkySettingsRow
        kind="custom"
        title="Custom row"
        value="Slot-compatible"
      />
      <SkySettingsRow
        kind="action"
        title="Reset examples"
        tone="danger"
        @activate="resetExamples"
      />
      <SkySettingsRangeRow v-model="range" title="Range row" />
    </SkySettingsGroup>

    <SkySection title="Full pill navigation">
      <div class="sky-ui-demo-extension-navigation-stage">
        <SkyPillNavigation label="Full pill navigation" layout="full">
          <SkySegmented
            :active-index="fullTab"
            :item-count="3"
            aria-label="Full navigation tabs"
            navigation
            rounded
            strong
          >
            <SkySegmentedButton
              v-for="(item, index) in fullNavigationItems"
              :key="item.label"
              :active="fullTab === index"
              :aria-label="item.label"
              @click="fullTab = index"
            >
              <span class="sky-ui-demo-extension-navigation-item">
                <component :is="item.icon" :size="20" aria-hidden="true" />
                <span>{{ item.label }}</span>
              </span>
            </SkySegmentedButton>
          </SkySegmented>
        </SkyPillNavigation>
      </div>
    </SkySection>

    <SkySection title="Compact pill navigation">
      <div class="sky-ui-demo-extension-navigation-stage">
        <SkyPillNavigation
          align="start"
          label="Compact pill navigation"
          layout="compact"
        >
          <SkySegmented
            :active-index="compactTab"
            :item-count="2"
            aria-label="Compact navigation tabs"
            compact
            navigation
            rounded
            strong
          >
            <SkySegmentedButton
              v-for="(label, index) in ['Apps', 'Games']"
              :key="label"
              :active="compactTab === index"
              @click="compactTab = index"
            >
              {{ label }}
            </SkySegmentedButton>
          </SkySegmented>
        </SkyPillNavigation>
      </div>
    </SkySection>

    <SkySection title="Split pill navigation">
      <div class="sky-ui-demo-extension-navigation-stage">
        <SkyPillNavigation label="Split pill navigation" layout="split">
          <SkySegmented
            :active-index="Math.min(splitTab, 1)"
            :item-count="2"
            aria-label="Primary split navigation tabs"
            compact
            navigation
            rounded
            :strong="splitTab < 2"
          >
            <SkySegmentedButton
              v-for="(label, index) in ['Apps', 'Games']"
              :key="label"
              :active="splitTab === index"
              @click="splitTab = index"
            >
              {{ label }}
            </SkySegmentedButton>
          </SkySegmented>
          <template #end>
            <SkySegmented
              :active-index="0"
              :item-count="1"
              aria-label="Secondary split navigation tabs"
              compact
              navigation
              rounded
              :strong="splitTab === 2"
            >
              <SkySegmentedButton
                :active="splitTab === 2"
                @click="splitTab = 2"
              >
                Search
              </SkySegmentedButton>
            </SkySegmented>
          </template>
        </SkyPillNavigation>
      </div>
    </SkySection>
  </SkyUiDemoPage>
</template>

<style scoped>
.sky-ui-demo-extension-status,
.sky-ui-demo-extension-card,
.sky-ui-demo-extension-empty {
  margin: 0;
}

.sky-ui-demo-extension-card {
  flex: 0 0 140px;
}

.sky-ui-demo-extension-state-actions {
  min-height: var(--sky-touch-target);
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-2);
}

.sky-ui-demo-extension-surface,
.sky-ui-demo-extension-app {
  box-sizing: border-box;
  min-height: 92px;
  display: grid;
  place-items: center;
  padding: var(--sky-space-3);
}

.sky-ui-demo-extension-surface {
  border: 1px solid var(--sky-app-accent);
}

.sky-ui-demo-extension-app {
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}

.sky-ui-demo-extension-preview-copy {
  min-width: 0;
  display: grid;
  gap: var(--sky-space-1);
  text-align: center;
}

.sky-ui-demo-extension-preview-copy small {
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 16px;
}

.sky-ui-demo-extension-widgets {
  --sky-widget-label-color: var(--sky-text);
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: end;
  gap: var(--sky-space-3);
}

.sky-ui-demo-extension-widgets > :nth-child(1) {
  height: 112px;
}

.sky-ui-demo-extension-widgets > :nth-child(2) {
  height: 136px;
}

.sky-ui-demo-extension-widgets > :nth-child(3) {
  height: 160px;
  grid-column: 1 / -1;
}

.sky-ui-demo-extension-widget {
  box-sizing: border-box;
  width: 100%;
  height: 100%;
  min-height: 0;
  display: grid;
  place-items: center;
  padding: var(--sky-space-3);
}

.sky-ui-demo-extension-widgets > :nth-child(1) .sky-ui-demo-extension-widget {
  border-radius: var(--sky-widget-radius-small);
}

.sky-ui-demo-extension-widgets > :nth-child(2) .sky-ui-demo-extension-widget {
  border-radius: var(--sky-widget-radius-medium);
}

.sky-ui-demo-extension-widgets > :nth-child(3) .sky-ui-demo-extension-widget {
  border-radius: var(--sky-widget-radius-large);
}

.sky-ui-demo-extension-widgets :deep(.sky-widget-frame__label) {
  text-shadow: none;
}

.sky-ui-demo-extension-controls {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: var(--sky-space-3);
}

.sky-ui-demo-extension-glass {
  box-sizing: border-box;
  width: 100%;
  min-height: 52px;
  padding: 0 var(--sky-space-4);
  border-radius: var(--sky-radius-pill);
  font: inherit;
  font-weight: 600;
}

.sky-ui-demo-extension-glass:focus-visible {
  outline: 2px solid var(--sky-app-accent);
  outline-offset: 2px;
}

.sky-ui-demo-extension-settings :deep(.sky-settings-group__title) {
  margin-right: 0;
  margin-left: 0;
}

.sky-ui-demo-extension-navigation-stage {
  min-height: 76px;
  position: relative;
  display: flex;
  align-items: center;
}

.sky-ui-demo-extension-navigation-stage :deep(.sky-pill-navigation) {
  position: relative;
  right: auto;
  bottom: auto;
  left: auto;
  width: 100%;
}

.sky-ui-demo-extension-navigation-item {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  line-height: 1;
}

.sky-ui-demo-extension-navigation-item > span {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
