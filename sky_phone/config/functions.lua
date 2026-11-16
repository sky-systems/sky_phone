-- Editable player checks, shared by the client and server.
-- Keep these functions synchronous: do not Wait or await callbacks/SQL here.
-- See integrations/PLAYER_CHECKS.md for the context and cancellation contract.
PhoneFunctions = {}

local death_keys = { "dead", "isDead", "isdead", "inlaststand", "isDowned", "unconscious" }

local function has_death_flag(data)
    for _, key in ipairs(death_keys) do
        local value = data[key]
        if value == true or value == 1 then return true end
    end
    return false
end

function PhoneFunctions.IsDead(context)
    if context.report.dead == true or context.legacyDead then return true end
    if context.isServer then
        if context.ped ~= nil and context.ped ~= 0 and GetEntityHealth(context.ped) <= 0 then
            return true
        end
    elseif IsEntityDead(context.ped) then
        return true
    end

    if Bridge.Framework.GetName() == "qbox" and GetResourceState("qbx_medical") == "started" then
        local death_state = context.state["qbx_medical:deathState"]
        -- qbx_medical's DeathState enum: ALIVE (1), LAST_STAND (2), DEAD (3).
        if death_state == 2 or death_state == 3 then return true end
        if death_state == 1 then
            -- Legacy flags can lag after a revive. Server metadata still applies.
            return context.isServer and has_death_flag(context.framework)
        end
    end

    -- SaltyChat_IsAlive is a voice mute flag, not a medical state.
    return has_death_flag(context.state) or has_death_flag(context.framework)
end

function PhoneFunctions.IsHandcuffed(context)
    if context.report.cuffed == true then return true end
    if not context.isServer and IsPedCuffed(context.ped) then return true end
    for _, data in ipairs({ context.state, context.framework }) do
        for _, key in ipairs({ "ishandcuffed", "isHandcuffed", "handcuffed", "isCuffed" }) do
            local value = data[key]
            if value == true or value == 1 then return true end
        end
    end
    return false
end

-- player_source is the player's server ID on the server, nil on the client.
-- Return false (optionally with a DeviceErrors locale key) to cancel opening.
function PhoneFunctions.CanOpenPhone(player_source)
    local reason = Bridge.PlayerState.GetBlockReason(player_source)
    if reason then return false, reason end

    -- Add custom opening checks here. Example: return false, "request_cancelled".
    return true
end
