# SQL provider evidence

Checked 2026-09-20 against oxmysql 030d3bda11098fc4a78f1940545b674c374daa45.
Match the installed provider and facade before applying these contracts.

- [parseResponse.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/utils/parseResponse.ts):
  query returns the result; insert/update select numeric fields; single/scalar extract a row/value.
- [rawQuery.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/database/rawQuery.ts),
  [rawExecute.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/database/rawExecute.ts),
  [connection.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/database/connection.ts):
  query vs execute path and prepare result unpacking.
- [rawTransaction.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/database/rawTransaction.ts):
  statement execution, commit and rollback; no automatic zero-row business assertion.
- [lib/MySQL.lua](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/lib/MySQL.lua):
  Lua import, parameter normalization and await rejection propagation.
- [lib/MySQL.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/lib/MySQL.ts)
  and [package metadata](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/lib/package.json):
  the named `oxmysql` JS export, Promise/callback forms and import package.
- [parseTransaction.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/utils/parseTransaction.ts):
  per-statement values/parameters, tuple and shared-parameter formats.
- [typeCast.ts](https://github.com/overextended/oxmysql/blob/030d3bda11098fc4a78f1940545b674c374daa45/src/utils/typeCast.ts):
  query/execute date and tinyint/bit conversion differences; inspect timezone/null semantics.
- [Current provider docs](https://overextended.dev/docs/oxmysql) and
  [prepare placeholder constraints](https://overextended.dev/docs/oxmysql/Functions/prepare).
- CFX [Await docs](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await),
  [event source docs](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/),
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua)
  at 0d8a2a6f78a9922445d8930305af82a7b1826980: Citizen.Await/SetEventRoutine.

For new CFX use, verify official signature/context and matching registration/generated binding
plus implementation. A mock, parse or build does not prove a live DB/provider/gameplay outcome.
Report actual tests and the remaining deployment/runtime boundary.
