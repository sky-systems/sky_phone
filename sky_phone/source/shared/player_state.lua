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
    local sky_cuffed = data.skyCuffType == "cuffs" or data.skyCuffType == "zipties"
    -- Sky restraints also set isDead to disable inventory actions. Medical death
    -- remains independent through skyAmbulanceDead/dead/isdead and native health.
    return {
        dead = flag(data.dead) or (flag(data.isDead) and not sky_cuffed) or flag(data.isdead)
            or flag(data.inlaststand) or flag(data.isDowned) or flag(data.unconscious)
            or flag(data.skyAmbulanceDead) or flag(data.skyAmbulanceKnockout),
        cuffed = flag(data.ishandcuffed) or flag(data.isHandcuffed) or flag(data.handcuffed)
            or flag(data.isCuffed) or flag(data.skyCuffed) or sky_cuffed,
    }
end

function state.Reason(status)
    local config = Config.Phone or {}
    if config.BlockWhenDead ~= false and status.dead then return "player_incapacitated" end
    if config.BlockWhenCuffed ~= false and status.cuffed then return "player_cuffed" end
end
