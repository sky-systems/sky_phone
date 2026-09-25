SkyPhoneCellular = {}

-- These are device lifecycle/cleanup operations, independent of mobile data.
SkyPhoneCellular.SystemNamespaces = {
    admin = true, cellular = true, configurator = true, device = true,
    security = true, sim = true, tones = true, notifications = true,
    payphone = true, ui = true, close = true, navigation = true,
    notification = true, worldDisplay = true,
}
SkyPhoneCellular.CleanupActions = {
    ["calls:hangup"] = true, ["calls:decline"] = true, ["calls:terminate"] = true,
    ["calls:set-muted"] = true, ["calls:set-speaker"] = true,
    ["realtime:leave"] = true, ["realtime:drop"] = true, ["realtime:microphone"] = true,
    ["realtime:config"] = true,
    ["custom-app:lifecycle"] = true, ["custom-app:catalog-debug"] = true,
    ["garage:valet-cancel"] = true, ["radio:disconnect"] = true,
}
SkyPhoneCellular.AppNamespaces = {
    calls = "phone", contacts = "phone", gallery = "photos", media = "camera",
    marketplace = "citymarkt", pages = "local-pages", housing = "house",
    account = "settings", easyshare = "photos",
}

function SkyPhoneCellular.Level(coords)
    if not Config.CellTowers.Enabled then return 1.0 end
    local strongest = 0.0
    for _, tower in ipairs(Config.CellTowers.Towers) do
        -- Coverage is horizontal: antenna/aircraft height does not shrink its footprint.
        local dx, dy = coords.x - tower.Coords.x, coords.y - tower.Coords.y
        strongest = math.max(strongest, 1.0 - math.sqrt(dx * dx + dy * dy) / tower.Range)
    end
    return strongest
end

function SkyPhoneCellular.RequiresSignal(endpoint, data)
    endpoint = endpoint:gsub("^sky_phone:", "")
    local namespace = endpoint:match("^([^:]+)")
    if SkyPhoneCellular.SystemNamespaces[namespace] or SkyPhoneCellular.CleanupActions[endpoint] then
        return false
    end
    if Config.CellTowers.OnlineActions[endpoint] then return true end
    local app = SkyPhoneCellular.AppNamespaces[namespace] or namespace
    if namespace == "custom-app" and type(data) == "table" and type(data.appId) == "string" then
        app = data.appId
    end
    return Config.CellTowers.OfflineApps[app] ~= true
end
