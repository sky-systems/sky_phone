---
name: esx-framework
description: Inspect or repair ESX Legacy adapters and direct ESX integrations using the installed player, callback and inventory contracts.
metadata:
  author: germanfndez
---

# ESX integration

Identify the installed ESX revision, inventory/provider overrides and owning execution side.
Verify only the method/event in question using current official docs and matching source;
[source map](reference-links.md) records inspected paths, not universal version promises.
For CFX/native use, also verify docs, registration/generated binding and implementation,
including context, yield/RPC behavior and source limits.

When the applicable AGENTS.md requires the Sky bridge, keep Sky.FW facades and
Sky_Jobs.PlayerCache identity/job/duty; direct ESX belongs in framework adapters. Preserve
Sky callbacks/UI/localization and unconditional documented APIs. Otherwise retain resource-owned
adapters. External ESX player objects can legitimately be absent; handle that boundary with an
explicit result and diagnostic rather than confusing it with a missing framework API.

Read only the relevant reference:

- [Initialization and lifecycle](core-concepts.md)
- [Client state and UI boundaries](client-functions.md)
- [Server lookups and services](server-functions.md)
- [Player methods and provider results](xplayer-methods.md)
- [Events and callbacks](events-callbacks.md)
- [Integration review](best-practices.md)
