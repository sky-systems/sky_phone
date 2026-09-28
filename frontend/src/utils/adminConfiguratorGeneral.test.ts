import { createRequire } from 'node:module'
import { describe, expect, it } from 'vitest'
import { computed, reactive } from 'vue'

import type { AdminConfiguratorSection } from '@/types/admin'
import {
  GENERAL_CONFIGURATOR_GROUPS,
  patchGeneralConfiguratorValue,
  resolveGeneralConfiguratorField,
} from './adminConfiguratorGeneral'

const require = createRequire(import.meta.url)
const { loadConfiguratorSections } =
  require('../../testserver/configurator-fixture.cjs') as {
    loadConfiguratorSections: () => AdminConfiguratorSection[]
  }

describe('General Configurator draft projection', () => {
  it('updates an already rendered field when its first draft is created or discarded', () => {
    const sections = loadConfiguratorSections()
    const drafts = reactive<Record<string, unknown>>({})
    const field = computed(
      () => resolveGeneralConfiguratorField(sections, drafts, 'Phone.Keybind')!,
    )
    const initial = field.value.value
    drafts['config:Phone'] = patchGeneralConfiguratorValue(
      field.value.rootValue,
      field.value.parts,
      'OEM_1',
    )
    expect(field.value.value).toBe('OEM_1')
    delete drafts['config:Phone']
    expect(field.value.value).toBe(initial)
  })

  it('resolves every General setting from the actual resource fixture without exposing fixed permissions', () => {
    const sections = loadConfiguratorSections()
    for (const group of GENERAL_CONFIGURATOR_GROUPS) {
      for (const path of group.paths)
        expect(
          resolveGeneralConfiguratorField(sections, {}, path),
          path,
        ).not.toBeNull()
    }
    expect(
      resolveGeneralConfiguratorField(
        sections,
        {},
        'CommandPermissions.phonepanel',
      ),
    ).toBeNull()
  })

  it('preserves sibling edits and false values when switching between General and detail views', () => {
    const sections = loadConfiguratorSections()
    const initial = resolveGeneralConfiguratorField(
      sections,
      {},
      'Phone.Unique',
    )!
    const first = patchGeneralConfiguratorValue(
      initial.rootValue,
      initial.parts,
      false,
    )
    const drafts = { 'config:Phone': first }
    const hotkey = resolveGeneralConfiguratorField(
      sections,
      drafts,
      'Phone.Keybind',
    )!
    const second = patchGeneralConfiguratorValue(
      hotkey.rootValue,
      hotkey.parts,
      'OEM_1',
    )
    const final = resolveGeneralConfiguratorField(
      sections,
      { 'config:Phone': second },
      'Phone.Unique',
    )!
    expect(final.value).toBe(false)
    expect(
      resolveGeneralConfiguratorField(
        sections,
        { 'config:Phone': second },
        'Phone.Keybind',
      )?.value,
    ).toBe('OEM_1')
    expect(
      resolveGeneralConfiguratorField(sections, {}, 'Phone.Unique')?.value,
    ).toBe(true)
    expect((second as Record<string, unknown>).HoldToLook).toEqual(
      (initial.rootValue as Record<string, unknown>).HoldToLook,
    )
  })

  it('patches nested controls without modifying server data or accepting unknown paths', () => {
    const original = {
      HoldToLook: { Enabled: true, Control: 19 },
      Unique: true,
    }
    expect(
      patchGeneralConfiguratorValue(original, ['HoldToLook', 'Enabled'], false),
    ).toEqual({ HoldToLook: { Enabled: false, Control: 19 }, Unique: true })
    expect(original.HoldToLook.Enabled).toBe(true)
    expect(() =>
      patchGeneralConfiguratorValue(original, ['missing'], false),
    ).toThrow()
  })
})
