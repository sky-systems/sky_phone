-- Common status normalization. SaltyChat_IsAlive is deliberately not a death flag:
-- the phone uses SetPlayerAlive(false) for mute without changing medical state.
Bridge.PlayerState = {}
local state = Bridge.PlayerState

function state.Flag(value)
    return value == true or value == 1
end

function state.FromData(data)
    data = type(data) == "table" and data or {}
    local flag = state.Flag
    return {
        dead = flag(data.dead) or flag(data.isDead) or flag(data.isdead)
            or flag(data.inlaststand) or flag(data.isDowned) or flag(data.unconscious)
            or flag(data.skyAmbulanceDead) or flag(data.skyAmbulanceKnockout),
        cuffed = flag(data.ishandcuffed) or flag(data.isHandcuffed) or flag(data.handcuffed)
            or flag(data.isCuffed) or flag(data.skyCuffed),
    }
end

function state.Reason(status)
    local config = Config.Phone or {}
    if config.BlockWhenDead ~= false and status.dead then return "player_incapacitated" end
    if config.BlockWhenCuffed ~= false and status.cuffed then return "player_cuffed" end
end

local warned = {}
function state.Export(resource, name, ...)
    if GetResourceState(resource) ~= "started" then return nil end
    local ok, result = pcall(exports[resource][name], nil, ...)
    if ok then return result end
    local key = resource .. ":" .. name
    if not warned[key] then
        warned[key] = true
        Bridge.Debug("warn", "[sky_phone] Player status export %s failed: %s", key, tostring(result))
    end
end
