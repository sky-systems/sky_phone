local relays_with_data = {
    ["sky_phone:mail:changed"] = "mail:changed",
    ["sky_phone:easyshare:changed"] = "easyshare:changed",
    ["sky_phone:marketplace:changed"] = "marketplace:changed",
    ["sky_phone:companies:changed"] = "companies:changed",
    ["sky_phone:fliptok:verification-changed"] = "fliptok:verification-changed",
    ["sky_phone:picstagram:verification-changed"] = "picstagram:verification-changed",
    ["sky_phone:banking:changed"] = "banking:changed",
    ["sky_phone:crewlink:changed"] = "crewlink:changed",
    ["sky_phone:messages:changed"] = "messages:changed",
    ["sky_phone:darkchat:changed"] = "darkchat:changed",
}

local relays_without_data = {
    ["sky_phone:gallery:changed"] = "gallery:changed",
    ["sky_phone:contacts:changed"] = "contacts:changed",
    ["sky_phone:calls:changed"] = "calls:changed",
    ["sky_phone:crypto:account-changed"] = "crypto:account-changed",
    ["sky_phone:billing:changed"] = "billing:changed",
}

for event_name, nui_type in pairs(relays_with_data) do
    RegisterNetEvent(event_name, function(data)
        SendNUIMessage({ type = nui_type, data = data })
    end)
end

for event_name, nui_type in pairs(relays_without_data) do
    RegisterNetEvent(event_name, function()
        SendNUIMessage({ type = nui_type })
    end)
end

RegisterNetEvent("sky_phone:crypto:changed", function(data)
    if type(data) ~= "table" or type(data.markets) ~= "table" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid crypto market data.")
        return
    end
    SendNUIMessage({ type = "crypto:changed", data = data })
end)
