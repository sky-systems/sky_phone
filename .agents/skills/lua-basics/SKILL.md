---
name: lua-basics
description: Diagnose or write FiveM Lua involving table semantics, scope, return values, errors or coroutine lifetimes. Use when these language details matter.
metadata:
  author: germanfndez
---

# Lua semantics for FiveM

Use the deployed runtime's language contract. FiveM extends Lua; do not assume a standalone
parser covers every extension. Verify relevant CFX APIs against official docs and pinned source,
including context and yield behavior; see the [source map](reference-links.md).

Follow the applicable `AGENTS.md` and resource style. When it requires the Sky bridge, keep
four-space indent, double quotes, snake_case locals, no one-line aliases and no documented-API
existence guards; player identity/job/duty use PlayerCache. Otherwise retain resource-owned adapters.

Read only the relevant topic: [functions and returns](functions.md), [tables](tables.md),
[variables and lifetime](variables.md), [conditionals](conditionals.md), or
[errors and asynchronous work](errors.md). Prefer correct ownership and measured work over
unverified micro-optimization rules.
