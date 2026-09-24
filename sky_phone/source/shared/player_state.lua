-- State collection lives in the side-specific adapters; editable checks live in
-- config/functions.lua. These switches control how the resulting status is used.
Bridge.PlayerState = {}
local state = Bridge.PlayerState

function state.Reason(status)
    local config = Config.Phone or {}
    if config.BlockWhenDead ~= false and status.dead then return "player_incapacitated" end
    if config.BlockWhenCuffed ~= false and status.cuffed then return "player_cuffed" end
end
