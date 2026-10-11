# Server phone-number changes

`exports["sky_phone"]:ChangePhoneNumber(source, newNumber)` changes the SIM in a player's equipped phone. It returns `true, normalizedNumber` after completion, or `false, errorCode`. Before API initialization it returns `nil, "api_not_ready"`, like the other server exports. `GetApiCapabilities()` advertises `features.phoneNumberChange`; API version `1.0.0` remains unchanged for this additive export.

The caller must authorize the action and handle its payment and result. This is a server export, with no client network event. Phone resolves the equipped device and SIM itself; callers cannot choose an arbitrary IMEI or SIM. The phone UI may be closed. Unique inventory phones and character phones with automatic SIMs are supported.

`exports["sky_phone"]:ValidatePhoneNumberChange(source, newNumber)` performs a read-only preflight
using the same number/SIM validation as the final change. Check `ready` and
`features.phoneNumberValidation` in `GetApiCapabilities()`. It returns `true, normalizedNumber`
or `false, errorCode`, including `false, "api_not_ready"` before initialization. The explicit
boolean preserves error reasons across FiveM function references that lose nil-leading results.
Preflight does not modify SIM/device metadata, clear availability, end calls or refresh the
device. It reserves no number; callers must still check the final change and handle its failure.

Number changes and internal lookups accept digit strings with 1 to 24 digits, independently of `Sim.NumberLength` and `Sim.NumberPrefix`. For example, `"0298822"` stays `"0298822"`, including its leading zero. Display separators are removed before storage and comparison; number groups are presentation only. Pass strings to preserve leading zeroes. New SIM generation still uses the configured length and prefix.

The SIM change rejects company service numbers, occupied or unchanged numbers, preserves the SIM identity and other item metadata, and verifies the metadata write. A conflicting SQL update restores the previous item metadata. On success Phone clears dispatcher availability, ends calls for that SIM, refreshes the equipped-number cache, and updates an active device session. Calls, contacts, messages, transfers and the shared `NormalizePhoneNumber` export use the same format-independent normalization. Display formatting never truncates a longer number.

Errors include `invalid_source`, `player_unavailable`, `device_not_equipped`, `no_sim`, `invalid_phone_number`, `phone_number_taken`, `phone_number_unchanged`, and `metadata_unsupported`. Update consuming adapters together with Phone and restart both resources. No configuration, locale or SQL migration is required.

Run `lua54 tests/public_api_server.lua`, `lua54 tests/server_sim_inventory.lua`, and `lua54 tests/server_device_directory.lua` from the Phone repository root. These cover API readiness, forwarding, SIM/metadata consistency, collisions, rejected writes and automatic SIMs. Verify actual equipped inventory state in a restarted FiveM resource; Lua fixtures do not prove NUI synchronization or multiplayer call behavior.

The Lua export side and signature follow [official Cfx Lua documentation](https://docs.fivem.net/docs/scripting-manual/runtimes/lua/). Source inspection used `citizenfx/fivem` revision `0105063b0394b1b9d085c917a8dc9c9abf0a620f`: `data/shared/citizen/scripting/lua/scheduler.lua` (`SetCallRefRoutine`, MessagePack `without_hole`, function-reference coroutine/async results and `exportProcessResult`) and `code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp` (resource identity, invoking resource, side and resource state registrations). Dense boolean-first results preserve error reasons; nil-leading lookup results can lose their later slots. Export calls can await database work through the scheduler. The inspected source revision is upstream; the local FXServer reports artifact `35265`, and its scheduler bytes differ from that revision.
