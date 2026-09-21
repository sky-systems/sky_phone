---
name: fivem-security
description: Review or implement FiveM server authority for network events, callbacks, rewards, permissions and shared state changes.
---

# FiveM server authority

Trace who requests an action and which server-owned state authorizes its result. Client input,
NUI, client callback results and client-writable state bags do not establish entitlement.
Validate the relevant actor, target, bounded input and permitted transition; consume rewards
once and protect yielding mutations against re-entry.

When the applicable AGENTS.md requires the Sky bridge, retain Sky.FW operations,
Sky_Jobs.PlayerCache identity/job/duty and the existing callback/serialization paths without
documented-API existence guards. Otherwise preserve resource-owned adapters. A cooldown or
duplicate UUID helper is not a permission or transaction lock.

Read [event and mutation boundaries](events.md) for the applicable action. Verify relevant
CFX APIs in official docs, then registration/binding and implementation at an identified
revision; [sources](sources.md) records the inspected paths. State runtime/source limits
instead of treating example code as complete protection.
