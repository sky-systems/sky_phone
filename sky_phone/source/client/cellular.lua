local previous_payload

function SkyPhoneCellular.GetPayload()
    local level = Config.CellTowers.Enabled and SkyPhoneCellular.Level(GetEntityCoords(PlayerPedId())) or 1.0
    return {
        enabled = Config.CellTowers.Enabled,
        bars = math.ceil(level * 4),
        hasSignal = level > 0,
        offlineApps = Config.CellTowers.OfflineApps,
        onlineActions = Config.CellTowers.OnlineActions,
        systemNamespaces = SkyPhoneCellular.SystemNamespaces,
        cleanupActions = SkyPhoneCellular.CleanupActions,
        appNamespaces = SkyPhoneCellular.AppNamespaces,
    }
end

AddEventHandler("sky_phone:client:nuiReady", function()
    SendNUIMessage({ type = "cellular:update", data = SkyPhoneCellular.GetPayload() })
end)

CreateThread(function()
    while true do
        local payload = SkyPhoneCellular.GetPayload()
        local encoded = json.encode(payload)
        if encoded ~= previous_payload then
            SendNUIMessage({ type = "cellular:update", data = payload })
            previous_payload = encoded
        end
        Wait(1000)
    end
end)
