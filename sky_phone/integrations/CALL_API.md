# Server call API

Server resources can answer an actual incoming call and manage company call readiness through Phone's public API. Phone remains standalone: it owns routing, membership, devices, SIMs, voice and call persistence. The consuming resource must authorize its own user workflow before invoking these server exports.

Check `exports["sky_phone"]:GetApiCapabilities()` first. The API must be `ready` and advertise `features.calls.externalControl == true`. An older Phone version does not provide these additions. API version `1.0.0` is retained because this is an additive capability.

| Server export | Result and behavior |
| --- | --- |
| `AnswerCallForSource(source, { id = callId, video? })` | `{ success, data?, error? }`. Executes the same handler as the native phone UI. Only a real pending recipient can answer; company eligibility, phone ownership, SIM, restrictions and reception are checked again. Competing answers are reserved before any yielding operation. Success requires voice startup and call persistence. Audio integrations can omit `video`. |
| `SetCallAvailabilityForSource(source, { available = boolean, dispatcher? = boolean })` | `{ success, data?, error? }`. Derives the current company, grade, equipped phone and SIM server-side. Enabling requires an eligible company service device and an unrestricted player; the phone UI can be closed. `dispatcher = true` prioritizes this member using the existing service-line routing. Disabling removes readiness and dispatcher priority. |
| `GetActiveCallBySource(source)` | A fresh snapshot of the player's actual pending/connected call, or `nil, errorCode`. |
| `GetActiveCallById(callId)` | A fresh snapshot from the caller perspective, or `nil, errorCode`. A released ring-all recipient does not mean the overall call has ended. |
| `EndCallForSource(source)` | `boolean, errorCode?`. Uses normal hangup/decline. A ringing company recipient can leave their offer while other recipients or routing attempts remain eligible. |
| `TerminateCallForSource(source)` | Existing forced termination of the entire call. Use only when that full cancellation is intended. |

The snapshot now includes `serviceCall` to distinguish incoming company service calls from personal calls and outbound calls on behalf of a company. Existing `id`, `state`, `direction`, `companyId`, caller/callee, anonymous-number protection and voice fields remain available. The snapshot stays `ringing` without a channel while an answer is still being persisted; it becomes `connected` after confirmation.

Local server event `sky_phone:server:callChanged(source, snapshot)` is emitted for incoming ringing offers, confirmed connection updates and terminal/released states. It is deliberately not a network event. Snapshots are fresh tables; events do not expose a hidden caller's number to the recipient. Read the authoritative getters before deciding whether a released recipient or the complete conversation ended. Event handlers can yield, so do not assume that an event notification waits for a consumer's database work.

The existing client callbacks and call UI are preserved. Their session and rate requirements stay in place; external server readiness instead resolves the equipped device. No config, locale or SQL migration is required. To receive calls to **112**, configure that number on the corresponding company service line in Phone configurator (or the existing company definitions in file mode), enable `CanCall`, and use the existing grade/routing settings. Company membership and dispatcher priority do not create a shared queue for arbitrary unrelated jobs.

Before production use, test with a restarted FiveM resource and experimental OAL: two-way audio, both routing modes, competing answers, caller cancellation during acceptance, a busy/offline dispatcher, device/SIM loss, disconnect and resource restart. Lua tests prove the server logic with deterministic provider/database seams; they do not prove live audio.
