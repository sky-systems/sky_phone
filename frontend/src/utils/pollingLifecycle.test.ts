import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import ts from 'typescript'
import { describe, expect, it, vi } from 'vitest'

// Run the actual component lifecycle hooks with deferred owner responses. This
// reproduces leaving an app before its initial NUI callback has completed.
function lifecycle(file: string, context: Record<string, unknown>) {
  const source = readFileSync(new URL(file, import.meta.url), 'utf8')
  const script = source.match(
    /<script setup lang="ts">([\s\S]*?)<\/script>/,
  )![1]
  const parsed = ts.createSourceFile(
    'Component.ts',
    script,
    ts.ScriptTarget.Latest,
    true,
  )
  const names = new Set([
    'timer',
    'liveTimer',
    'disposed',
    'refreshPending',
    'liveRefreshPending',
  ])
  const hooks = parsed.statements
    .filter((statement) => {
      if (ts.isVariableStatement(statement))
        return statement.declarationList.declarations.some((declaration) =>
          names.has(declaration.name.getText(parsed)),
        )
      if (
        !ts.isExpressionStatement(statement) ||
        !ts.isCallExpression(statement.expression)
      )
        return false
      const call = statement.expression
      if (call.expression.getText(parsed) === 'onMounted') return true
      return (
        call.expression.getText(parsed) === 'onBeforeUnmount' &&
        ts.isArrowFunction(call.arguments[0])
      )
    })
    .map((statement) => statement.getText(parsed))
    .join('\n')
  const javascript = ts.transpileModule(hooks, {
    compilerOptions: { target: ts.ScriptTarget.ES2022 },
  }).outputText
  let mount!: () => Promise<void>
  let unmount!: () => void
  const timers = new Map<number, () => Promise<void>>()
  const listeners = { addEventListener: vi.fn(), removeEventListener: vi.fn() }
  const clearInterval = (id: number) => timers.delete(id)
  runInNewContext(javascript, {
    ...context,
    onMounted: (hook: () => Promise<void>) => (mount = hook),
    onBeforeUnmount: (hook: () => void) => (unmount = hook),
    window: {
      ...listeners,
      setInterval: (callback: () => Promise<void>) => {
        const id = timers.size + 1
        timers.set(id, callback)
        return id
      },
      clearInterval,
      clearTimeout: vi.fn(),
    },
    clearInterval,
  })
  return { mount, unmount, timers, listeners }
}

function deferred() {
  let resolve!: (value?: unknown) => void
  const promise = new Promise((finish) => (resolve = finish))
  return { promise, resolve }
}

function crewContext(bootstrap: Promise<unknown>, tick = Promise.resolve()) {
  return {
    appAuth: { isSignedIn: () => true, signOut: vi.fn() },
    crew: {
      bootstrap: () => bootstrap,
      authenticated: true,
      activeGroup: {},
      profile: null,
      refreshLive: vi.fn().mockResolvedValue(true),
    },
    messageMedia: { consumeMany: () => null },
    username: { value: '' },
    nextTick: () => tick,
    openSharedInvite: vi.fn(),
    fitOnlineMembers: vi.fn(),
    onKeydown: vi.fn(),
    onCrewLinkMessage: vi.fn(),
    toastTimer: undefined,
    pointerFrame: undefined,
  }
}

describe('app polling lifecycle', () => {
  it('does not install CrewLink polling or listeners after leaving during bootstrap', async () => {
    const request = deferred()
    const hooks = lifecycle(
      '../views/apps/CrewLinkApp.vue',
      crewContext(request.promise),
    )
    const mounted = hooks.mount()
    hooks.unmount()
    request.resolve()
    await mounted
    expect(hooks.timers.size).toBe(0)
    expect(
      hooks.listeners.addEventListener.mock.calls.map(([event]) => event),
    ).toEqual(['keydown'])
  })

  it('does not install CrewLink polling after leaving during the pending DOM tick', async () => {
    const tick = deferred()
    const context = crewContext(
      Promise.resolve(),
      tick.promise as Promise<void>,
    )
    context.appAuth.isSignedIn = () => false
    const hooks = lifecycle('../views/apps/CrewLinkApp.vue', context)
    const mounted = hooks.mount()
    hooks.unmount()
    tick.resolve()
    await mounted
    expect(hooks.timers.size).toBe(0)
  })

  it('serializes CrewLink refreshes and does not poll signed-out or groupless users', async () => {
    const context = crewContext(Promise.resolve())
    const hooks = lifecycle('../views/apps/CrewLinkApp.vue', context)
    await hooks.mount()
    const poll = [...hooks.timers.values()][0]
    context.crew.authenticated = false
    await poll()
    expect(context.crew.refreshLive).not.toHaveBeenCalled()
    context.crew.authenticated = true
    const response = deferred()
    context.crew.refreshLive.mockReturnValue(response.promise)
    const running = poll()
    await poll()
    expect(context.crew.refreshLive).toHaveBeenCalledTimes(1)
    response.resolve()
    await running
    hooks.unmount()
    expect(hooks.timers.size).toBe(0)
  })

  it('does not restart LiveBroadcast polling after a late config response', async () => {
    const config = deferred()
    const hooks = lifecycle('../components/LiveBroadcast.vue', {
      realtime: { refreshConfig: () => config.promise, stop: vi.fn() },
      opened: { value: false },
      current: { value: null },
    })
    const mounted = hooks.mount()
    hooks.unmount()
    config.resolve()
    await mounted
    expect(hooks.timers.size).toBe(0)
  })

  it('does not overlap live list requests or publish a late list into a closed sheet', async () => {
    const response = deferred()
    const opened = { value: true }
    const entries = { value: [] }
    const realtime = {
      refreshConfig: async () => {},
      list: vi.fn(() => response.promise),
    }
    const hooks = lifecycle('../components/LiveBroadcast.vue', {
      realtime,
      opened,
      entries,
      current: { value: null },
      props: { app: 'fliptok' },
    })
    await hooks.mount()
    const poll = [...hooks.timers.values()][0]
    const pending = poll()
    await poll()
    expect(realtime.list).toHaveBeenCalledTimes(1)
    opened.value = false
    hooks.unmount()
    response.resolve([{ id: 'late' }])
    await pending
    expect(entries.value).toEqual([])
    expect(hooks.timers.size).toBe(0)
  })
})
