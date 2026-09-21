# Performance and lifecycle

Locate the hot path with a representative FiveM profiler capture, then inspect native/provider
work at the relevant source revision. Compare like workloads after the intended restart.
Do not claim runtime gains from Lua microbenchmarks, static edits or desktop browser timing.

- Use `Wait(0)` when an operation must run every frame, such as active drawing/input. Idle
  paths may sleep longer. Wait timing is tied to the runtime scheduler, not an exact timer.
- Start/stop or idle loops deliberately. A coroutine that exits `while enabled` while false
  does not restart when enabled changes later. Avoid accumulating duplicate loops on reopen.
- Refresh cached ped/entity/job state on the relevant lifecycle changes. A captured job string
  never updates itself; when AGENTS requires Sky job APIs, use the established PlayerCache/access lifecycle.
  Enable job-specific client work only while the current job/duty makes it applicable.
- Batch provider/SQL work only where semantics permit it. Do not trade fewer calls for stale
  permissions or shared mutable scratch tables used concurrently across yields.
- State bags have serialization and replication costs; use scoped recipients, granular keys
  and actual authority checks. They are not a blanket replacement for frequent events.
- Lua locals/direct appends can improve clarity. Avoid unsupported claims that `table.insert`
  is always expensive or `#array` scans every element. Sparse-table length is a correctness risk.

## One worker that idles and resumes

When existing lifecycle events change a local presentation flag, a single worker can remain
alive and vary its wait. This avoids the old `while enabled` example that exits permanently
when started disabled:

```lua
local interaction_active = false

AddEventHandler("example_resource:interactionActiveChanged", function(active)
    interaction_active = active
end)

CreateThread(function()
    while true do
        local sleep = 500
        if interaction_active then
            sleep = 0
            -- Run the existing per-frame drawing/input work here.
        end
        Wait(sleep)
    end
end)
```

Register/start this worker once, not on every open or job event. The idle wait affects how
soon it notices activation; choose it for the interaction's latency needs. If the owner
already starts and disposes one worker correctly, retain that design. Presentation flags
and client job state do not replace server authorization. Re-read changing positions when
needed and refresh cached handles/job state through their lifecycle, rather than freezing
coordinates at initialization.

## Allocation, configuration and diagnostics

Keep configurable distances/items/amounts in the resource's canonical configuration. Reuse
temporary tables only when no consumer retains them and no concurrent yielding operation
shares them. Let unreachable data be collected; assigning one variable to nil cannot free
an object still referenced by a cache or closure. See [Lua table ownership](../lua-basics/tables.md).

Use an existing debug flag for optional tracing, while keeping broken invariants visible.
Comment why a threshold, lifecycle transition or batching choice exists rather than restating
the expression. Timer spans can help locate a slow stage, but elapsed waits and CPU work are
different measurements; use the profiler for representative runtime-cost claims.

[Wait, state bag and Lua runtime sources](reference-links.md);
[profiler guide](https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/).
