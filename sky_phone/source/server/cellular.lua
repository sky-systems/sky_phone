function SkyPhoneCellular.HasSignal(player_source)
    if not Config.CellTowers.Enabled then return true end
    local ped = GetPlayerPed(tostring(player_source))
    if ped == 0 then
        Bridge.Debug("debug", "[sky_phone] Cannot resolve cellular coverage: source %s has no player ped.", tostring(player_source))
        return false
    end
    return SkyPhoneCellular.Level(GetEntityCoords(ped)) > 0
end
