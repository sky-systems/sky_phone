---
name: oxmysql
description: "OxMySQL for FiveM - SQL integrations with MySQL/MariaDB. Use when writing or editing server-side database code: queries, inserts, updates, transactions, or any resource that uses oxmysql (query, insert, prepare, update, single, scalar, rawExecute, transaction)."
author: germanfndez
version: "1.0.0"
mcp-server: projecthub
---

# OxMySQL

SQL integration for FiveM using OxMySQL (replacement for mysql-async / ghmattimysql). Server-side only. Use MariaDB over MySQL 8 for compatibility.

## When to use

- User asks for database queries, inserts, updates, or SQL in a FiveM resource.
- Editing or writing code that uses `MySQL.*` or `exports.oxmysql`.
- Designing tables, upserts, or transactions.

## Setup
- Lua: `server_script '@oxmysql/lib/MySQL.lua'` in fxmanifest (above other scripts).

## Rules

Read the rule that matches what you're doing:

- **rules/placeholders.md** — Safe parameters (`?` placeholders), avoid SQL injection.
- **rules/query.md** — `MySQL.query` / `MySQL.query.await`: SELECT returns rows; other statements return insertId/affectedRows.
- **rules/insert.md** — `MySQL.insert`: insert row, returns insert id.
- **rules/prepare.md** — `MySQL.prepare`: prepared statements, only `?` placeholders; faster for repeated queries.
- **rules/update.md** — `MySQL.update`: update rows, returns affected count.
- **rules/single.md** — `MySQL.single`: one row or nil.
- **rules/scalar.md** — `MySQL.scalar`: single value (one row, one column).
- **rules/rawExecute.md** — `MySQL.rawExecute`: raw execution, no automatic result shape.
- **rules/transaction.md** — `MySQL.transaction`: run multiple queries in a transaction.

## References (look up if not covered in the rules above)

If something isn't covered in the rules above, check the official docs:

- **OxMySQL (index):** https://coxdocs.dev/oxmysql  
- **Placeholders:** https://coxdocs.dev/oxmysql/placeholders  
- **Functions (query, insert, prepare, update, single, scalar, rawExecute, transaction):** https://coxdocs.dev/oxmysql (Functions section)
