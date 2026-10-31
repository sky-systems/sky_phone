# Phonepanel activity history

The Phonepanel activity view records successful server-owned Phone actions from
the existing mutation catalog in `source/server/logging_actions.lua`, plus the
call lifecycle already recorded by `source/server/calls.lua`. It does not infer
what a player is doing from UI focus, record keystrokes, or log feed polling.
History begins after this update is deployed; older actions cannot be reconstructed.

Local history is available while `Config.AdminPanel.Enabled` is enabled, even
when Discord logging is disabled or no webhook is configured. The existing
`phonepanel` permission and admin read rate limit protect the reader. Selecting
an online player resolves the character identifier on the server. Responses omit
the database owner identifier, and a source ID is retained only as historical
context because FiveM can reuse it after disconnecting.

`sky_phone_activity_log` is created by the normal additive runtime migration and
is included in `sql/install.sql` for clean installations. No manual SQL or new
configuration setting is required. Disabling the panel stops new local records;
it does not erase existing history. There are deliberately no foreign keys to
devices or accounts: resetting a phone must not erase its historical activity.

Each successful catalogued action adds one parameterized INSERT. Reads add no
activity writes. Local-only logging does not run the extra before/enrichment
queries used for complete Discord audits. Request fields use the existing
allowlist; nested secrets are removed by the shared sanitizer. Details are
limited to a 12,000-byte/500-node sanitization budget and a 16 KiB encoded storage
limit. An explicit omission marker replaces details that exceed the encoded
limit. Failed persistence emits a bounded English diagnostic and does not turn
an already completed gameplay action into a failed mutation response.

Retention maintenance removes at most 1,000 records older than 30 days, at most
once per ten minutes of mutation traffic. It adds no background timer or writes
to panel polling. When there is a large backlog or no new traffic, older rows
may remain longer until subsequent maintenance batches remove them.

The reader uses descending BIGINT IDs with an exclusive `beforeId` cursor, so
new activity does not shift later pages. IDs stay strings across the Lua/NUI
boundary to preserve values larger than JavaScript's safe integer range. The
existing `AdminPanel.ActivityLimit` controls page size (clamped to 1–100).
The ORDER BY and cursor predicate explicitly use the numeric table column:
ordering by the unqualified `id` output alias would sort its CHAR cast
lexicographically (for example, 99 before 100) and overlap later pages. This was
reproduced during the live multi-page activity test and is guarded by the SQL
contract assertions in the local activity suite.

Run `lua54 tests/server_activity_logging.lua` for local persistence, redaction,
retention, callback failure, source reuse, permission and pagination checks. The
same suite is also invoked by `tests/server_logging.lua`, which is part of CI.
Static tests do not establish restarted FiveM or NUI behavior.

The accompanying account fanout repair filters the server-owned session account
before running `RequireAccount`. Matching recipients still pass the same current
restriction and inventory ownership checks, and the account is checked again
after validation. The regression fixture checks four matching sessions among
1,005 open phones: only those four enter validation, and only the two recipients
that remain authorized receive the event/refresh. This proves reduced validation
work in that path; it is not an FPS, resmon or production-load measurement.

Call lifecycle activity retains the original actor and character owner before
yielding SQL, including terminal/payphone calls and accepted calls. This prevents
a reused source ID from attaching the original caller's final event to a new
player. The actor-name read uses a string server source, as declared by the
[official server native declaration](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/ext/native-decls/GetPlayerName.md).
Inspected Cfx revision `9f0e34e1cbdfc34fd05079416791f01938279097`:
[`PlayerScriptFunctions.cpp`, `CreatePlayerCommands`/`GET_PLAYER_NAME`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/code/components/citizen-server-impl/src/PlayerScriptFunctions.cpp)
reads the server client registry name through
[`MakeClientFunction.h`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/code/components/citizen-server-impl/include/MakeClientFunction.h).
The wrapper resolves the source string to a registry client; an absent client
returns the default null value. The Lua
[`codegen_out_lua.lua`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/ext/natives/codegen_out_lua.lua)
maps string arguments and string results. This is a synchronous server lookup
with no out-pointer, game-engine native or OneSync RPC. The inspected public
revision was not matched to the deployed artifact; runtime validation remains
separate from this source inspection.
