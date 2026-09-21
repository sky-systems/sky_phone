---
name: fivem-basics
description: Create or debug FiveM manifests, resource lifecycle, event boundaries and exports. Use when these runtime contracts affect the task.
metadata:
  author: germanfndez
---

# FiveM resource contracts

Identify the resource, execution side and deployed artifact before changing a runtime boundary.
Verify relevant CFX signatures in official docs, then implementation, registration/generated
binding and call path at an identified source revision. Record context, yield/RPC constraints
and any unavailable engine behavior; [source map](reference-links.md) provides starting points.

Only when the applicable `AGENTS.md` requires the Sky bridge, use its documented facades and
`Sky_Jobs.PlayerCache` for player identity/job/duty without existence guards or one-line aliases.
Otherwise preserve the resource-owned adapters; being under a Sky-Systems folder alone is not enough.

Read only the reference needed:

- [Manifest](fxmanifest.md): declarations, load order, dependencies and shipped files.
- [Client/server](client-server.md): execution context, authority and state bags.
- [Events](events.md): registration, sender identity and asynchronous lifetimes.
- [Exports](exports.md): cross-resource contracts and restart boundaries.
- [Structure](structure.md): ownership and visibility of code.
- [Debugging](debugging.md): trace the actual failing execution path.
- [Performance](optimization.md): loops, cache invalidation and profiling evidence.
