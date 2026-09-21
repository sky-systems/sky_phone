# Event and mutation boundaries

Keep internal privileged actions in functions or local-only events. Register a network event
only when remote callers need it. RegisterNetEvent permits network dispatch; it does not
validate permissions. GetInvokingResource reports script provenance, not a trustworthy
player or client. Rejecting non-nil provenance does not secure a server event.

For a client-triggered mutation, apply the checks the action actually requires:

- Capture event source before yielding; resolve the actor server-side. Authorize job/duty,
  grade/role and target ownership from server-owned state, not submitted identity fields.
- Bound types, lengths, numeric ranges and collection sizes. Select catalog records and
  calculate prices/rewards on the server. A recognized item name alone does not authorize a grant.
- Check relevant distance and routing/instance membership from the server. Verify the entity
  exists and belongs to the intended session before using its coordinates; a universal latency
  radius is not appropriate. OneSync position is synchronized state, not proof of honest movement.
- Validate the allowed workflow transition. Claim/consume a completion before a yielding
  side effect, then follow the existing success/failure/compensation path. Recheck session
  identity after asynchronous work when disconnect or source reuse can change the actor.
- Rate-limit the relevant actor/action and bound pending state. A client-local delay can be
  bypassed; a global cooldown can block unrelated players. Caller-generated UUIDs are not receipts.

Do not expose a generic give-item/pay event that accepts arbitrary quantities. Prefer a request
for an existing server-owned operation. Client origin filters and callback correlation are
additional boundaries, not server authorization. UI visibility does not grant permission.

When working with the Sky bridge, inspect Security.lua before choosing its helpers. At the
inspected revision, server Cooldown(time, description, noNotify) uses a shared flag;
IsNotDuplicate(uuid) keeps bounded recent UUIDs. Neither provides per-player ownership or a
once-only business transaction. Preserve established serialization rather than adding a new layer.

Reject invalid requests through explicit results and explanatory English diagnostics; do not
silently mask broken invariants. Keep logs bounded and free of secrets. See [sources](sources.md).

## Worked once-only claim boundary

This pure Lua example shows the non-yielding claim step only. `operations` contains records
created/completed by trusted server logic; `actor_key` is resolved server-side, not supplied
by the client. Perform the action's permission, distance and session checks before this step.

```lua
local function claim_completed_operation(operations, actor_key, operation_id)
    local operation
    local rejection
    if type(operation_id) ~= "string" or #operation_id == 0 or #operation_id > 64 then
        rejection = "invalid_operation_id"
    else
        operation = operations[operation_id]
        if not operation then
            rejection = "unknown_operation"
        elseif operation.actor_key ~= actor_key then
            rejection = "wrong_owner"
        elseif operation.state ~= "completed_unclaimed" then
            rejection = "not_claimable"
        end
    end

    if rejection then
        print(("[claim] Request rejected: %s"):format(rejection))
        return nil, rejection
    end

    -- No await/Wait/provider call between checking and claiming this record.
    operation.state = "claimed"
    return operation
end
```

The caller derives the reward from the returned server record, never from request values.
A second call for the same operation cannot pass the state check, including while the first
call yields in the provider. This protects the local claim boundary, not persistence across
restarts or multiple processes: durable rewards need an authoritative unique claim/ledger
and an idempotent delivery contract. Keep claimed/uncertain state when a provider outcome is
unknown; blindly resetting it or retrying can duplicate a grant. Reconcile through the owning
service's documented failure path and use stable session/identity checks after yielding.

Transport wiring stays with the resource's existing server callback/event owner. Do not expose
this helper as a generic client-chosen payment API or treat a notification as proof of delivery.
