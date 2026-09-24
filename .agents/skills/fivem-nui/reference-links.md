# NUI Primary Sources

Checked 2026-09-20. Start with official docs, then inspect implementation/registration/binding at the target revision. Refresh mutable platform claims when they matter. A public source SHA does not identify the installed client.

## Public contracts

- [Fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/): manifest, asset origins, messaging and focus.
- [NUI callbacks](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/): JSON requests/results, injected parent-resource API and callback completion.
- [Resource manifest](https://docs.fivem.net/docs/scripting-reference/resource-manifest/): packaged files and secure resource configuration.
- [DUI](https://docs.fivem.net/docs/scripting-manual/nui-development/dui/): direct-rendered UI lifecycle.
- [Server security](https://docs.fivem.net/docs/developers/server-security/): server validation of client input.
- [Legacy/Enhanced comparison](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/): edition-specific behavior. Check the actual target.

## Inspected public source revision

`citizenfx/fivem` SHA `0d8a2a6f78a9922445d8930305af82a7b1826980` was public master during this check. Prefer a matching deployed revision when available.

| Path/function | What it establishes |
| --- | --- |
| [RegisterNuiCallback declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/RegisterNuiCallback.md) | Client, callback-name/function inputs, void return |
| [SendNuiMessage declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/SendNuiMessage.md) | Client, JSON-string input, raw BOOL result |
| [SetNuiFocus declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/SetNuiFocus.md) | Client, focus/cursor booleans, void return |
| [ResourceUICallbacks.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-resources/src/ResourceUICallbacks.cpp), `MakeUICallback`, `RegisterNuiCallback<IsRef>` | JSON/MessagePack conversion, direct references and legacy event registration |
| [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua#L739-L810) | Current/legacy Lua callback wrappers; `SendNUIMessage` encodes the table and does not return the raw native result |
| [ResourceUI.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-resources/src/ResourceUI.cpp), `Create`, `InvokeCallback`, `OnTick` hook | Resource origins, revision-specific strict-mode check, queued callback execution and dead-resource check |
| [ResourceUIScripting.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-resources/src/ResourceUIScripting.cpp), `sendMessageToFrame`, `SEND_NUI_MESSAGE`, `SET_NUI_FOCUS` | JSON parsing/emission, resource/frame lookup and focus/cursor votes |
| [Lua generator](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/natives/codegen_out_lua.lua), `printArgument`, `printInvocationArguments`, `printNative` | Function references and argument/result binding |

Those three signatures have no output-pointer parameter. Callback execution is scheduled locally; this path is not a server RPC. The send path does not await an application listener or server outcome. For any additional native, verify its own docs/source rather than extending these conclusions by analogy.

Keep runtime probes and profiling separate from source evidence. This record does not prove browser capability, input behavior, live resource correctness or GTA engine internals on a deployed client.

## Worked-example source details

The restoration rechecked these paths at the same Cfx SHA:

- [NUICallbacks_PushEvent.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-core/src/NUICallbacks_PushEvent.cpp#L73): injected `GetParentResourceName` returns the browser's registered frame name, not a parsed URL hostname.
- [RegisterCommand declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/RegisterCommand.md), [GetCurrentResourceName declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetCurrentResourceName.md), and [ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp#L48): shared registration/context; command arguments are `(name, function, restricted)` and have no out-pointer, resource name comes from the current script runtime. See [command docs](https://docs.fivem.net/docs/scripting-manual/migrating-from-deprecated/creating-commands/).
- [onResourceStop docs](https://docs.fivem.net/docs/scripting-reference/events/list/onResourceStop/) and [ResourceEventComponent.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-resources-core/src/ResourceEventComponent.cpp#L93): `onResourceStop` is synchronous during stop; `onClientResourceStop` is queued after stop. Use the former for this resource's own cleanup.
- [Loading screens](https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/) are a separate lifecycle from an ordinary `ui_page`; use that reference when the task concerns one.

For browser examples, [Fetch](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API), [AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController), [DOM textContent](https://developer.mozilla.org/en-US/docs/Web/API/Node/textContent) and [TypeScript narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html) document the web-language side. Check actual embedded capabilities and the installed bundler/framework docs; this skill does not prescribe a new UI stack.
