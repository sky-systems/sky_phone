# Phone performance review - 2026-10-12

Reviewed baseline: `dev` at `fcad72f9ec19725f99dbe506c68699380666e93d` (Phone 1.1.6).
Scope: client workers/native calls, NUI rendering and async cleanup, server
polling/SQL, network fanout, and framework/resource boundaries. This is a
performance repair, with no UI redesign or configuration/SQL/API migration.

## Findings fixed

| Priority | Trigger and consequence                                                                                                                                                                                                                                               | Repair and regression evidence                                                                                                                                                                                                                                                                                                                      |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1       | Several CrewLink world/live requests miss the presence cache together. SQL yields before the first rebuild publishes its result, so each request can repeat the full online-player scan. With N players and M concurrent polls, this can multiply the scan work by M. | Share the in-flight presence promise. Retain the existing cache lifetime, reject all waiters on failure, and discard a scan invalidated by a disconnect/group change. Coroutine tests cover shared work, error propagation/recovery and invalidation.                                                                                               |
| P1       | Closing CrewLink during `bootstrap()` or `nextTick()` lets its mount continuation install a 3-second interval and message listener after cleanup has already run. Repeated visits can accumulate SQL/network polls from abandoned views.                              | Check the component lifetime after each mount await. Tests execute the production hooks with deferred replies and leave the component before completion.                                                                                                                                                                                            |
| P1       | Leaving a live-broadcast view during its config request can install a 10-second interval after unmount.                                                                                                                                                               | Reject late mount continuation, prevent overlapping list polls, and suppress late list results after closing. Deferred-response lifecycle tests cover both leaks and backpressure.                                                                                                                                                                  |
| P2       | CrewLink's visible-view timer requests live data even without an authenticated profile or active group, and starts another request while a slow previous one is pending.                                                                                              | Poll only for the applicable authenticated group and keep one timer-owned refresh in flight. Background world/quick-ping authorization remains independent of opening the NUI.                                                                                                                                                                      |
| P2       | World-display capture clones/styles/embeds the whole phone DOM and encodes another JPEG every 500 ms even when the screen is unchanged. This can stall CEF independently of Lua resmon.                                                                               | Reuse still pixels; invalidate on DOM, scroll, input, asset/font load, resize and seek changes. Continue capturing canvas/video/CSS animation and its final frame. Keep the original 500 ms delivery cadence, sequence/token protection, geometry, quality and leases. Unit and real-browser tests cover still pixels, changing pixels and cleanup. |
| P2       | Every Lua world-display JPEG validation rebuilds the base64 lookup and decodes the entire bounded header even when SOF dimensions are already available near its start. Work repeats on publisher and server.                                                         | Build the alphabet lookup once and stop decoding at SOF. Keep full input-format/size checks and bounded header traversal. Existing ownership/sequence/proximity tests plus baseline/progressive/metadata/truncation/dimension/boundary cases pass.                                                                                                  |
| P2       | Qbox/QBCore status sampling repeatedly retrieves full PlayerData across resource/function-reference boundaries. The normal client restriction poll runs every 250 ms; realtime/camera paths also consult status.                                                      | Seed metadata once, then consume the framework-owned replacement event. Handle login/logout, provider restart and provider changes. Only the active provider can invalidate its cache. Tests verify one fetch across 100 polls and immediate restrictions after replacements. ESX retains its existing event-fed snapshot.                          |

## Other paths inspected

| Area                                               | Result and remaining cost                                                                                                                                                                                                                                                                                                   |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Focus and camera controls                          | The normal-phone capture attributes most steady Lua cost to the active focus worker. It already exits when no input claim exists and applies required controls each frame. Camera orbit, HUD hiding, local invisibility and lights also have active-only per-frame work. No arbitrary waits were added to drawing/input.    |
| Animations and props                               | Context checking is bounded by the existing configured poll and one owned watcher; transitions use revisions. Prop matrices are already sampled once per rendered screen. DUI rendering can still be expensive with many simultaneous nearby screens; screen geometry and display limits are preserved.                     |
| Payphones                                          | Scanning is conditional, ignores unloaded archetypes, and uses the configured interval. Interaction/drawing/call workers are active-only. No broad game-object pool scan was introduced.                                                                                                                                    |
| Health, cellular, CityWarn and weather             | Health rejects stationary/teleport samples before movement natives and batches activity. Cellular compares its payload before sending. Weather is requested/refreshed through the view lifecycle. Alert expiry workers use bounded polling. Their representative baseline cost was small; sampling semantics remain intact. |
| CrewLink map/blips                                 | Background access remains server-owned and works with a closed phone. Location delivery, routing buckets, map/overhead opt-in, quick-ping cooldown and expiry remain covered by existing specs. The SQL rebuild and abandoned-view defects above are addressed without caching permissions.                                 |
| Calls, service lines and radio                     | Active sessions are periodically revalidated for inventory, restriction, proximity/signal and service permissions. These checks are authoritative and were retained. No evidence in the captured workload warrants weakening them.                                                                                          |
| Realtime media and custom apps                     | Media streams, graphics views and animation handles have disposal paths; custom frames abort document requests, remove listeners and release lifecycle/focus claims. Server room snapshots already suppress unchanged revisions. Large live audiences/nearby screens still need a representative multi-player load capture. |
| Calendar, social feeds, messages and device lookup | Reviewed polling and query/fanout paths, configured pagination and existing query bounds. Calendar reminder updates are conditional and bounded. The recorded idle server workload does not establish production-scale SQL latency or query plans; no speculative schema/index migration is included.                       |
| Diagnostics and deployment                         | Phone remains standalone. MCP is only external local test orchestration, with no Phone dependency on another Sky resource. Private captures, identifiers, configuration and credentials are excluded from the PR.                                                                                                           |

## Runtime baseline

The local ESX server ran FXServer artifact `35265`, ESX `1.13.4`, oxmysql `2.14.1`
and Phone `1.1.6`. The user recorded the open-phone/scrolling client workload
with `profiler resource sky_phone 1000` before deployment of these changes.

| Completed scope                  | Calls | Total elapsed scope time | Mean per call |  Maximum |
| -------------------------------- | ----: | -----------------------: | ------------: | -------: |
| Client `tick (sky_phone)`        |   999 |                81.094 ms |   0.081175 ms | 1.264 ms |
| Active focus thread              |   999 |                53.413 ms |   0.053466 ms | 0.259 ms |
| Client restriction poll          |    63 |                 6.362 ms |   0.100984 ms | 0.173 ms |
| Client animations context thread |    63 |                 3.166 ms |   0.050254 ms | 0.096 ms |

The full client trace contains 1,000 frames / 447,975 events over 16.266 seconds
and one incomplete capture-boundary scope. The raw 78,878,416-byte trace exceeds
MCP's 64 MiB report limit; it was analyzed locally using the same current
`analyzeTrace` implementation, without changing the original capture. Only
completed scopes are reported here. Inclusive times overlap and must not be
summed as CPU percentages or equated to resmon/FPS.

The restarted candidate was also recorded with 1,000 frames / 452,441 events
over 18.029 seconds. Its completed Phone tick averaged **0.086059 ms** (999
calls, 85.973 ms total, 2.358 ms maximum), compared with **0.081175 ms** before.
The focus worker averaged 0.055737 ms versus 0.053466 ms before. Both normal
open/scroll captures therefore remain around 0.08 ms per Phone tick; these
samples do not demonstrate a reduction for this already-light ESX workload.
Client reconnection, manually performed interactions and capture duration differ,
so this is not a controlled equal-input benchmark.

An apparent 16.608 ms camera-focus event in the second trace contains a
**16.577 ms `(profiler gc)`** scope. The trace attributes this isolated outlier
to profiler collection, not expensive camera/input code. The ordinary focus
worker was not changed by this PR. Both raw captures remain private and unchanged.

An earlier 1,000-frame idle server capture measured 36.053 ms inclusive Phone
resource scope time across 61.879 seconds. It included startup/activity from
other resources, so it is context rather than a controlled before/after test.

This workload does **not** demonstrate an always-high Phone resmon, prove the
cause of every reported hitch, or exercise enabled multi-player screen mirroring
or loaded CrewLink groups. The defects above have concrete execution paths and
regression coverage; performance gains for those workloads need matching live
captures. Qbox/QBCore caching is source/spec-tested, not Qbox/QBCore gameplay proof.

## Verification

- All 74 repository Lua specs passed; affected CrewLink/world-display/framework
  specs were rerun with the final Lua patch. All 278 Lua files pass syntax checks.
- Final frontend suite: 261 files / 1,888 tests passed, plus license tests and 77 browser
  mock endpoints/stateful actions.
- Type checking with `vue-tsc --build --noEmit`, lint, and repository policy passed.
- Five actual-browser world-display tests passed, including scroll offset,
  live-video capture, spectator isolation and executable/URL rejection.
- Full browser/theme suite: all 50 tests passed, including every registered app
  in light/dark and the new world-display regression.
- `build_copy.bat -DryRun` and `build_frontend.bat` passed. The latter performed
  the production build, notice/default generation and copy to ESX and Qbox.
  Each deployment had 562/562 files with identical source SHA-256 hashes.
- The local test checkout composed performance code `4cf3d30e` with already
  deployed number-change fixes `4115c6e4` from PR #133 (local merge `bf376498`).
  This preserves that test-server feature; PR #134 itself is based only on `dev`.
- Restarted ESX Phone: manifest OAL `yes`, server `IsApiReady()` true, phone
  reopened through its existing public export, client open/data-loaded true.
  Startup's error-level configurator banner is informational; no Phone client
  script errors appeared in the checked log tail.
- A bounded real-server task verified eight shared-promise waiters and rejection
  propagation. It reached `completed` with zero timers/running threads after
  cleanup. This verifies the Cfx primitive, not a many-player SQL benchmark.
- PR #134 CI at `4cf3d30e`: Repository policy, Frontend, CodeQL, Dependency review
  and Pull request policy passed. Its test-resource artifact was inspected for
  one `sky_phone` root, manifest/NUI/notices and the committed performance Lua
  contents. Build/package/copy evidence remains distinct from gameplay proof.

## Platform/source evidence

Public Cfx source inspected at `0105063b0394b1b9d085c917a8dc9c9abf0a620f`.
This identifies the inspected public revision, not a proven exact match to every
installed artifact or client binary.

- [Lua Wait contract](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Wait)
  and [LuaScriptRuntime.cpp](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/code/components/citizen-scripting-lua/src/LuaScriptRuntime.cpp):
  `Lua_Wait`, `Lua_CreateThreadInternal`, `RunBookmark` and the Wait/CreateThread
  registration. Wait yields the calling coroutine; frame/control work cannot
  be replaced by an arbitrary long sleep.
- [Await contract](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await),
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/data/shared/citizen/scripting/lua/scheduler.lua)
  (`Citizen.Await`, `SetCallRefRoutine`, function-reference `__call`) and
  [deferred.lua](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/data/shared/citizen/scripting/lua/deferred.lua)
  (`promise.new`, resolve/reject). Await needs a scheduler coroutine and propagates
  rejection; cross-resource function calls pack/unpack full argument/return values.
- [NUI contract](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/)
  and [ResourceUIScripting.cpp](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/code/components/nui-resources/src/ResourceUIScripting.cpp)
  (`sendMessageToFrame`, `SEND_NUI_MESSAGE`, `SEND_DUI_MESSAGE`): client resource
  routing, JSON parse/re-emit and asynchronous browser delivery.
- [Lua binding generator](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/ext/natives/codegen_out_lua.lua):
  `printArgument`/`printInvocationArguments` distinguish scalar, vector, pointer
  and function-reference arguments. No native signature/OAL setting is changed.
- [Qbox events](https://docs.qbox.re/resources/qbx_core/events/client), installed
  Qbox `1.23.0` `modules/playerdata.lua`/`client/events.lua`/`client/functions.lua`,
  and installed QBCore `1.3.0` `client/events.lua`/`client/functions.lua` confirm
  metadata replacement, logout and PlayerData access contracts.

GTA engine-native implementations are outside the inspected public Cfx source.
No new engine behavior or FPS claim is inferred from the bindings.
