---
name: oxlib
description: Implement or debug direct ox_lib callbacks, commands, keybinds, zones or UI using the installed module contracts.
metadata:
  author: germanfndez
---

# ox_lib integration

Confirm the installed provider/version and existing resource integration. When the applicable
AGENTS.md requires the Sky bridge, retain Sky callbacks, interaction/UI helpers and shared tablet
controls; otherwise retain the resource-owned adapters. Do not replace an interface solely
because ox_lib provides another one.

Read only the relevant reference: [setup](init.md), [callbacks](callback.md),
[commands](addCommand.md), [zones](zones.md), [interface](interface.md) or
[keybind/nearby-vehicle lookup routes](sources.md#additional-lookup-routes).
Verify the exact provider method in official docs and installed/matching source.
For relevant CFX APIs verify signature/context plus registration/generated binding and source
call path, including coroutine/RPC constraints. The [source map](sources.md) records evidence.

Client callback delays, dialog field limits and client zone membership are not server
authorization. Validate mutations at their server owner, preserve lifecycle cleanup and
localize user-facing text according to the resource's conventions.
