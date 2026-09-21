---
name: oxmysql
description: Implement or debug FiveM SQL using oxmysql, including bound parameters, result shapes, schema changes and transaction semantics.
metadata:
  author: germanfndez
---

# oxmysql contracts

Identify the installed SQL provider and calling facade first. When the applicable AGENTS.md
requires the Sky bridge, retain Sky.Query/Sky.DB and verify their own source contracts;
otherwise preserve the resource-owned database adapter. Do not assign oxmysql return semantics
to a wrapper without inspecting it.

For direct use, import @oxmysql/lib/MySQL.lua before its server consumers. Verify the method
in current official docs and installed/matching source; [sources](sources.md) records the
inspected revision. Await yields a CFX scheduler coroutine and may raise on rejection.
Capture raw event source before yielding and preserve the operation's existing serialization.

Read only the matching contract: [parameters](placeholders.md), [query](query.md),
[single](single.md), [scalar](scalar.md), [insert](insert.md), [update](update.md),
[prepare](prepare.md), [rawExecute](rawExecute.md), or [transactions](transaction.md).
A successful SQL transaction does not prove an authorized or correct business operation.

For schema work follow the Phone repository's migration rules. Keep
`sky_phone/source/server/db_migrate.lua` and `sky_phone/sql/install.sql` aligned.
Inherit database charset/collation; an explicit override requires the documented and reviewed
compatibility requirement described in `CONTRIBUTING.md`. Preserve the operation's constraints/indexes.
