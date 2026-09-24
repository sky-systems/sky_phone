-- Editable player checks, shared by the client and server.
-- Keep these functions synchronous: do not Wait or await callbacks/SQL here.
-- See integrations/PLAYER_CHECKS.md for the context and cancellation contract.
PhoneFunctions = {}

function PhoneFunctions.IsDead(context)
    if context.report.dead == true or context.legacyDead then return true end
    if context.isServer then
        if context.ped ~= nil and context.ped ~= 0 and GetEntityHealth(context.ped) <= 0 then
            return true
        end
    elseif IsEntityDead(context.ped) then
        return true
    end

    -- SaltyChat_IsAlive is a voice mute flag, not a medical state.
    for _, data in ipairs({ context.state, context.framework }) do
        for _, key in ipairs({ "dead", "isDead", "isdead", "inlaststand", "isDowned", "unconscious" }) do
            if data[key] == true or data[key] == 1 then return true end
        end
    end
    return false
end

function PhoneFunctions.IsHandcuffed(context)
    if context.report.cuffed == true then return true end
    if not context.isServer and IsPedCuffed(context.ped) then return true end
    for _, data in ipairs({ context.state, context.framework }) do
        for _, key in ipairs({ "ishandcuffed", "isHandcuffed", "handcuffed", "isCuffed" }) do
            if data[key] == true or data[key] == 1 then return true end
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
