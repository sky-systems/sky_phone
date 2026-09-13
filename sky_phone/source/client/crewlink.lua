local overhead_members = {}
local blips = {}
local snapshot_started = 0
local snapshot_ttl = 0
local sync_requested = true
local version = 0
local stopped = false
local quick_ping_pending = false
local last_quick_ping_at
local key_mapping_registered = false
local colours = { cyan = 18, blue = 3, violet = 7, orange = 17, green = 2, rose = 8 }

local function elapsed(since)
    return (GetGameTimer() - since) & 0xffffffff
end

local function remove_blip(id)
    local entry = blips[id]
    if entry and DoesBlipExist(entry.handle) then RemoveBlip(entry.handle) end
    blips[id] = nil
end

local function clear_world()
    overhead_members = {}
    snapshot_ttl = 0
    for id in pairs(blips) do remove_blip(id) end
end

local function request_sync()
    version = version + 1
    sync_requested = true
    clear_world()
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function update_blip(id, coords, name, sprite, colour, remaining_ms)
    if type(coords) ~= "table" or not finite(coords.x) or not finite(coords.y) or not finite(coords.z) then
        return false
    end
    local entry = blips[id] or {}
    if not entry.handle or not DoesBlipExist(entry.handle) then
        entry.handle = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end
    if not entry.handle or not DoesBlipExist(entry.handle) then return false end
    blips[id] = entry
    local settings = Config.CrewLink.Blip
    SetBlipCoords(entry.handle, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(entry.handle, sprite)
    SetBlipCategory(entry.handle, settings.CategoryId)
    SetBlipDisplay(entry.handle, 2)
    SetBlipAsShortRange(entry.handle, false)
    SetBlipScale(entry.handle, settings.Scale + 0.0)
    SetBlipColour(entry.handle, colour)
    BeginTextCommandSetBlipName("STRING")
    local label = name:gsub("~", "")
    local first = 1
    while first <= #label do
        local last = math.min(first + 98, #label)
        while last < #label and label:byte(last + 1) >= 128 and label:byte(last + 1) < 192 do
            last = last - 1
        end
        AddTextComponentSubstringPlayerName(label:sub(first, last))
        first = last + 1
    end
    EndTextCommandSetBlipName(entry.handle)
    entry.started = GetGameTimer()
    entry.remaining = remaining_ms
    return true
end

local function apply_snapshot(data, started)
    snapshot_started = started
    snapshot_ttl = math.max(3000, Config.CrewLink.OverheadRefreshMilliseconds * 2)
    overhead_members = data.overheadMembers or {}
    local seen = {}
    local settings = Config.CrewLink.Blip
    if settings.Enabled and data.groupId then
        AddTextEntry("BLIP_CAT_" .. settings.CategoryId, settings.CategoryName)
        local colour = colours[data.colour] or 3
        local own_source = GetPlayerServerId(PlayerId())
        for _, member in ipairs(data.members or {}) do
            if member.online and member.mapVisible and member.source ~= own_source then
                local id = "member:" .. member.id
                seen[id] = update_blip(id, member.coords, member.username, settings.Sprite, colour)
            end
        end
        for _, ping in ipairs(data.pings or {}) do
            local remaining = ping.expiresAt - data.serverTime - elapsed(started)
            if remaining > 0 then
                local id = "ping:" .. ping.id
                seen[id] = update_blip(id, ping.coords, ping.label, settings.PingSprite, colour, remaining)
            end
        end
    end
    for id in pairs(blips) do
        if not seen[id] then remove_blip(id) end
    end
end

local function draw_overhead_label(coords, username, role)
    SetDrawOrigin(coords.x, coords.y, coords.z + 1.05, 0)
    SetTextScale(0.0, 0.29)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(235, 245, 255, 235)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(("~b~%s~s~  %s"):format(username, role))
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNUICallback("crewlink:live", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb(Bridge.Callbacks.Trigger("sky_phone:crewlink:live", data)
        or { success = false, error = "request_failed" })
end)

local function register_key_mapping()
    if key_mapping_registered then return end
    key_mapping_registered = true
    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).Nui.Apps.crewlink
    -- Keep the command stable so FiveM preserves each player's chosen binding.
    RegisterKeyMapping("sky_phone_crewlink_ping", locale.quickPingKeybind, "keyboard", Config.CrewLink.QuickPing.DefaultKey)
end

RegisterCommand("sky_phone_crewlink_ping", function()
    if not Config.CrewLink.QuickPing.Enabled or quick_ping_pending or IsNuiFocused() or IsPauseMenuActive() then return end
    if last_quick_ping_at and elapsed(last_quick_ping_at) < (Config.CrewLink.PingCooldownSeconds or 5) * 1000 then return end
    quick_ping_pending = true
    local result = Bridge.Callbacks.Trigger("sky_phone:crewlink:quick-ping", {})
    quick_ping_pending = false
    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).Nui.Apps.crewlink
    local success = result and result.success
    Bridge.Framework.Notify(locale.name, success and locale.pingCreated
        or locale.errors[result and result.error or "request_failed"] or locale.errors.request_failed,
        success and "success" or "error", 4000)
    if success then
        last_quick_ping_at = GetGameTimer()
        request_sync()
    end
end, false)
register_key_mapping()

RegisterNetEvent("sky_phone:crewlink:changed", function()
    if source == 65535 then request_sync() end
end)
RegisterNetEvent("sky_phone:device:invalidated", request_sync)
AddEventHandler("sky_phone:configurator:updated", request_sync)
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        stopped = true
        clear_world()
    end
end)

-- Background authorization uses the carried phone and its saved CrewLink login;
-- closing the NUI must not stop crew locations or the quick-ping key.
CreateThread(function()
    local last_attempt = GetGameTimer()
    local retry_after = 0
    local last_error
    while not stopped do
        if sync_requested or elapsed(last_attempt) >= retry_after then
            sync_requested = false
            local request_version = version
            local started = GetGameTimer()
            local result = Bridge.Callbacks.Trigger("sky_phone:crewlink:world", {})
            last_attempt = GetGameTimer()
            retry_after = math.max(1000, Config.CrewLink.OverheadRefreshMilliseconds)
            if not stopped and request_version == version then
                if result and result.success and type(result.data) == "table" then
                    apply_snapshot(result.data, started)
                    last_error = nil
                else
                    clear_world()
                    local error_code = result and result.error or "request_failed"
                    if error_code == "not_authenticated" or error_code == "disabled" then
                        retry_after = 15000
                    elseif error_code ~= "server_initializing" and error_code ~= last_error then
                        Bridge.Debug("warn", "[sky_phone] CrewLink world sync failed: %s.", error_code)
                    end
                    last_error = error_code
                end
            end
        end
        Wait(500)
    end
end)

CreateThread(function()
    while not stopped do
        local sleep = 500
        if snapshot_ttl > 0 and elapsed(snapshot_started) >= snapshot_ttl then clear_world() end
        for id, entry in pairs(blips) do
            if entry.remaining and elapsed(entry.started) >= entry.remaining then remove_blip(id) end
        end
        if #overhead_members > 0 then
            local player_coords = GetEntityCoords(PlayerPedId())
            for _, member in ipairs(overhead_members) do
                local player = GetPlayerFromServerId(member.source)
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        if #(player_coords - coords) <= Config.CrewLink.OverheadDistance then
                            sleep = 0
                            draw_overhead_label(coords, member.username, member.roleLabel)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
