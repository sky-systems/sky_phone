local is_open = false
local open_requested = false
local notification_focus = false
local call_focus = false
local payphone_focus = false
local camera_active = false
local camera_nui_focused = true
local device_payload = nil
local sim_picker_open = false
local sim_picker_payload = nil
local active_call_payload = nil
local call_channel = 0
local nui_generation = 0
local activity_suspended = false
local phone_block_game = false
local phone_block_look = false
local phone_game_input = false
local phone_text_input_focused = false
local live_activity_active = false
local open_home_requested = false

SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsOpen", function()
    return is_open
end)

Bridge.Debug("debug", "[sky_phone] Client script initialized.", { always = true })

local server_callbacks = {
    "security:unlock",
    "security:set-passcode",
    "security:change-passcode",
    "security:disable-passcode",
    "device:save",
    "device:notification-open",
    "notifications:save",
    "custom-app:storage:get",
    "custom-app:storage:set",
    "device:factory-reset",
    "account:login",
    "account:register",
    "account:logout",
    "account:devices",
    "account:remove-device",
    "notes:list",
    "notes:create",
    "notes:update",
    "notes:delete",
    "mail:register",
    "mail:login",
    "mail:logout",
    "mail:counts",
    "mail:mailboxes",
    "mail:create-mailbox",
    "mail:delete-mailbox",
    "mail:list",
    "mail:get",
    "mail:get-draft",
    "mail:save-draft",
    "mail:delete-draft",
    "mail:delete-many",
    "mail:send",
    "mail:set-read",
    "mail:move",
    "mail:trash",
    "mail:restore",
    "mail:delete-forever",
    "mail:empty-trash",
    "marketplace:list",
    "marketplace:profile",
    "marketplace:auth",
    "marketplace:profile-save",
    "marketplace:get",
    "marketplace:list-own",
    "marketplace:create",
    "marketplace:update",
    "marketplace:set-status",
    "marketplace:favorite",
    "marketplace:counts",
    "marketplace:list-inquiries",
    "marketplace:get-inquiry",
    "marketplace:send-message",
    "marketplace:make-offer",
    "marketplace:respond-offer",
    "marketplace:report",
    "marketplace:block",
    "pages:list",
    "pages:get",
    "pages:profile",
    "pages:profile-save",
    "pages:list-own",
    "pages:create",
    "pages:share-citymarkt",
    "pages:react",
    "pages:delete",
    "weazel-news:context",
    "weazel-news:list",
    "weazel-news:get",
    "weazel-news:manage-list",
    "weazel-news:create",
    "weazel-news:update",
    "weazel-news:delete",
    "citywarn:bootstrap",
    "citywarn:publish",
    "citywarn:update",
    "citywarn:resolve",
    "fliptok:register",
    "fliptok:login",
    "fliptok:logout",
    "fliptok:bootstrap",
    "fliptok:feed",
    "fliptok:video",
    "fliptok:discover",
    "fliptok:music-metadata",
    "fliptok:publish",
    "fliptok:react",
    "fliptok:follow",
    "fliptok:comments",
    "fliptok:comment",
    "fliptok:comment-react",
    "fliptok:view",
    "fliptok:share",
    "fliptok:profile",
    "fliptok:connections",
    "fliptok:update-profile",
    "fliptok:activities",
    "fliptok:mark-activities",
    "fliptok:report",
    "fliptok:admin-reports",
    "fliptok:admin-resolve-report",
    "fliptok:block",
    "fliptok:delete",
    "picstagram:register",
    "picstagram:login",
    "picstagram:logout",
    "picstagram:bootstrap",
    "picstagram:feed",
    "picstagram:post",
    "picstagram:explore",
    "picstagram:search",
    "picstagram:saved",
    "picstagram:profile",
    "picstagram:connections",
    "picstagram:update-profile",
    "picstagram:publish-post",
    "picstagram:update-post",
    "picstagram:set-post-status",
    "picstagram:react",
    "picstagram:follow",
    "picstagram:respond-follow",
    "picstagram:comments",
    "picstagram:comment",
    "picstagram:comment-react",
    "picstagram:remove-comment",
    "picstagram:publish-story",
    "picstagram:stories",
    "picstagram:view-story",
    "picstagram:story-viewers",
    "picstagram:remove-story",
    "picstagram:activities",
    "picstagram:mark-activities",
    "picstagram:block",
    "picstagram:report",
    "picstagram:admin-reports",
    "picstagram:admin-resolve-report",
    "feather:bootstrap",
    "feather:create-profile",
    "feather:update-profile",
    "feather:feed",
    "feather:explore",
    "feather:network",
    "feather:create-post",
    "feather:react",
    "feather:follow",
    "feather:connections",
    "feather:remove-connection",
    "feather:profile",
    "feather:bookmarks",
    "feather:thread",
    "feather:activities",
    "feather:mark-activities",
    "feather:delete",
    "feather:block",
    "feather:report",
    "calendar:list",
    "calendar:create",
    "calendar:update",
    "calendar:delete",
    "music:bootstrap",
    "music:add-youtube",
    "music:remove-youtube",
    "music:create-playlist",
    "music:rename-playlist",
    "music:delete-playlist",
    "music:add-to-playlist",
    "music:remove-from-playlist",
    "map:markers",
    "map:create-marker",
    "map:delete-marker",
    "crewlink:bootstrap",
    "crewlink:login",
    "crewlink:register",
    "crewlink:logout",
    "crewlink:update-profile",
    "crewlink:create-group",
    "crewlink:update-group",
    "crewlink:delete-group",
    "crewlink:set-active",
    "crewlink:join-code",
    "crewlink:rotate-code",
    "crewlink:nearby",
    "crewlink:invite-nearby",
    "crewlink:respond-invite",
    "crewlink:update-member",
    "crewlink:transfer-owner",
    "crewlink:remove-member",
    "crewlink:leave",
    "crewlink:create-ping",
    "crewlink:remove-ping",
    "companies:list",
    "companies:get",
    "companies:my-requests",
    "companies:get-request",
    "companies:work-context",
    "companies:work-queue",
    "companies:list-members",
    "companies:create-request",
    "companies:cancel-request",
    "companies:send-message",
    "companies:claim-request",
    "companies:assign-request",
    "companies:update-request-status",
    "companies:update-availability",
    "companies:update-profile",
    "companies:update-hours",
    "companies:update-services",
    "companies:publish-announcement",
    "companies:set-call-availability",
    "companies:call-customer",
    "companies:dial-service-line",
    "sim:insert",
    "sim:eject",
    "contacts:list",
    "contacts:save",
    "contacts:delete",
    "contacts:favorite",
    "calls:recents",
    "calls:dial",
    "calls:answer",
    "calls:set-speaker",
    "calls:set-muted",
    "calls:decline",
    "calls:hangup",
    "calls:block",
    "banking:overview",
    "banking:transfer",
    "crypto:bootstrap",
    "crypto:register",
    "crypto:login",
    "crypto:logout",
    "crypto:quote",
    "crypto:execute",
    "crypto:deposit",
    "crypto:withdraw",
    "crypto:update-profile",
    "crypto:recipient",
    "crypto:transfer",
    "billing:overview",
    "billing:list",
    "billing:detail",
    "billing:markRead",
    "billing:pay",
    "billing:dispute",
    "messages:conversations",
    "messages:thread",
    "messages:send",
    "messages:media",
    "messages:delete",
    "messages:gifs",
    "memos:list",
    "memos:update",
    "memos:delete",
    "easyshare:bootstrap",
    "easyshare:own-contact",
    "easyshare:set-visibility",
    "easyshare:request",
    "easyshare:respond",
    "easyshare:cancel",
    "darkchat:bootstrap",
    "darkchat:create-profile",
    "darkchat:delete-profile",
    "darkchat:update-profile",
    "darkchat:start",
    "darkchat:thread",
    "darkchat:send",
    "darkchat:media",
    "darkchat:react",
    "darkchat:message-action",
    "darkchat:update-conversation",
    "darkchat:add-contact",
    "darkchat:remove-contact",
    "darkchat:block",
    "darkchat:report",
    "darkchat:clear",
    "flare:bootstrap",
    "flare:delete-profile",
    "flare:save-profile",
    "flare:set-discovery",
    "flare:swipe",
    "flare:rewind",
    "flare:unmatch",
    "flare:thread",
    "flare:send",
    "gallery:list",
    "gallery:counts",
    "gallery:favorite",
    "media:config",
    "media:import:sources",
    "media:import:list",
    "media:import:commit",
    "media:import:url",
}

local locale, locale_name = SkyPhoneLocales.Resolve(Config.Bridge.Locale)

local function update_nui_focus()
    local focus = SkyPhoneFocus.Resolve({
        activity_suspended = activity_suspended,
        allow_movement = Config.Phone.AllowMovement,
        call_focus = call_focus,
        camera_active = camera_active,
        camera_nui_focused = camera_nui_focused,
        is_open = is_open,
        notification_focus = notification_focus,
        payphone_focus = payphone_focus,
        sim_picker_open = sim_picker_open,
        text_input_focused = phone_text_input_focused,
    })
    SetNuiFocus(focus.focused, focus.cursor)
    SetNuiFocusKeepInput(focus.keep_input)
    phone_block_game = focus.block_game == true
    phone_block_look = focus.block_look == true
    phone_game_input = focus.game_input
    TriggerEvent("sky_phone:client:cameraFocusApplied", {
        active = camera_active,
        cursor = focus.cursor,
        focused = focus.focused,
        gameInput = focus.keep_input,
    })
end

CreateThread(function()
    while true do
        if phone_game_input or phone_block_game then
            if phone_block_game then
                SkyPhoneFocus.ApplyFocusedControls()
            else
                SkyPhoneFocus.ApplyGameInputControls(phone_block_look)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler("sky_phone:client:setSuspended", function(suspended)
    activity_suspended = suspended == true
    update_nui_focus()
end)

AddEventHandler("sky_phone:client:setPayphoneFocus", function(focused)
    payphone_focus = focused == true
    update_nui_focus()
end)

AddEventHandler("sky_phone:client:setCameraFocus", function(data)
    if type(data) ~= "table" or type(data.active) ~= "boolean" or type(data.nuiFocused) ~= "boolean" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid camera focus claim.")
        return
    end
    camera_active = data.active
    camera_nui_focused = data.nuiFocused
    update_nui_focus()
end)

local function send_open_message()
    if not device_payload then
        return
    end

    local payload = device_payload
    payload.lang = locale_name
    payload.locales = locale.Nui
    payload.fallbackLocales = Locales.en.Nui
    SkyPhoneApps.SendCatalog()
    SendNUIMessage({
        type = "app:open",
        data = payload,
        openHome = open_home_requested,
    })
    open_home_requested = false
end

local function open_phone()
    if is_open or not device_payload then
        return
    end

    send_open_message()
end

local function close_phone(close_device_session)
    local was_requested = open_requested
    local was_open = is_open
    open_requested = false
    call_focus = false
    activity_suspended = false
    phone_text_input_focused = false
    TriggerEvent("sky_phone:animation:phone", false)
    is_open = false
    if was_open then
        SkyPhoneApps.SetPhoneOpen(false)
        TriggerEvent("sky_phone:nuiClosed")
    end
    update_nui_focus()
    if was_requested or was_open then
        SendNUIMessage({ type = "app:close" })
        if close_device_session ~= false then
            Bridge.Callbacks.Trigger("sky_phone:device:close", {})
        end
    end
end

AddEventHandler("sky_phone:client:forceClose", function()
    close_phone()
end)

local function leave_call_voice()
    if call_channel == 0 then
        return
    end
    Bridge.Calls.Leave()
    call_channel = 0
end

local function join_call_voice(channel)
    local next_channel = tonumber(channel) or 0
    if not Bridge.Calls.Join(next_channel) then
        return false
    end
    call_channel = next_channel
    return true
end

if Config.Phone.DevelopmentCommand then
    RegisterCommand(Config.Command, function()
        if is_open or open_requested then
            close_phone()
            return
        end
        Bridge.Callbacks.Trigger("sky_phone:device:development-open", {})
    end, false)
end

RegisterCommand("sky_phone_toggle", function()
    if is_open or open_requested then
        close_phone()
        return
    end

    Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})
end, false)

RegisterCommand("sky_phone_live_activity_open", function()
    if not live_activity_active or is_open or open_requested then
        return
    end

    open_home_requested = true
    local result = Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})
    if not result or not result.success then
        open_home_requested = false
    end
end, false)

RegisterKeyMapping(
    "sky_phone_live_activity_open",
    locale.Controls.OpenPhone,
    "keyboard",
    "SPACE"
)

if Config.Phone.Keybind then
    if type(Config.Phone.Keybind) ~= "string" or Config.Phone.Keybind == "" then
        error("[sky_phone] Config.Phone.Keybind must be a non-empty keyboard key name or false.")
    end

    RegisterKeyMapping("sky_phone_toggle", locale.Controls.OpenPhone, "keyboard", Config.Phone.Keybind)
end

RegisterNetEvent("sky_phone:testdata:feedback", function(success, detail)
    local test_data_locale = locale.TestData
    local message = success and test_data_locale.Success or test_data_locale.Failed
    if success and type(detail) == "string" and detail ~= "" then
        message = message:gsub("{email}", detail)
    end
    Bridge.Framework.Notify("iFruit", message, success and "success" or "error", 7000)
end)

RegisterNUICallback("ui:ready", function(data, cb)
    if type(data) ~= "table" or data.protocolVersion ~= 1 then
        cb({ success = false, error = "unsupported_protocol" })
        return

    end
    nui_generation = nui_generation + 1
    -- Browser state is recreated on a CEF reload. A notification focus claim
    -- cannot survive unless its notification is replayed as part of this handshake.
    notification_focus = false
    phone_text_input_focused = false
    Bridge.Debug("debug", "[sky_phone] NUI reported ready.", { always = true })
    SkyPhoneApps.SendCatalog()
    if open_requested and device_payload then
        send_open_message()
    end
    if active_call_payload then
        SendNUIMessage({ type = "call:state", data = active_call_payload })
    end
    if sim_picker_open and sim_picker_payload then
        SendNUIMessage({ type = "sim:picker", data = sim_picker_payload })
    else
        SendNUIMessage({ type = "sim:picker-close" })
    end

    update_nui_focus()
    TriggerEvent("sky_phone:client:nuiReady", {
        generation = nui_generation,
        protocolVersion = 1,
    })

    cb({
        success = true,
        data = {
            generation = nui_generation,
            protocolVersion = 1,
        },
    })
end)

RegisterNUICallback("ui:opened", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if not open_requested or not device_payload then
        Bridge.Debug(
            "warn",
            "[sky_phone] Ignored a NUI open confirmation without a pending device open.",
            { always = true }
        )
        SendNUIMessage({ type = "app:close" })
        update_nui_focus()
        cb({ success = false, error = "open_not_requested" })
        return
    end

    is_open = true
    SkyPhoneApps.SetPhoneOpen(true)
    notification_focus = false
    call_focus = false
    update_nui_focus()
    TriggerEvent("sky_phone:animation:phone", true)
    cb({ success = true })
end)

RegisterNUICallback("ui:input-focus", function(data, cb)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    phone_text_input_focused = data.active and (is_open or open_requested)
    update_nui_focus()
    cb({ success = true })
end)

RegisterNUICallback("ui:live-activity", function(data, cb)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    live_activity_active = data.active
    cb({ success = true })
end)

RegisterNUICallback("close", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    close_phone()
    cb({ success = true })
end)

RegisterNUICallback("notification:focus", function(data, cb)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    notification_focus = data.active == true and not is_open
    update_nui_focus()
    cb({ success = true })
end)

RegisterNUICallback("sim:picker-close", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    sim_picker_open = false
    sim_picker_payload = nil
    update_nui_focus()
    SendNUIMessage({ type = "sim:picker-close" })
    local result = Bridge.Callbacks.Trigger("sky_phone:sim:picker-close", {})
    cb(type(result) == "table" and result or { success = false, error = "request_failed" })
end)

RegisterNUICallback("map:getPlayerCoords", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local coords = GetEntityCoords(PlayerPedId())
    cb({
        success = true,
        data = {
            coords = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            }
        }
    })
end)

RegisterNUICallback("map:setWaypoint", function(data, cb)
    local coords = type(data) == "table" and data.coords or nil
    local x = type(coords) == "table" and tonumber(coords.x) or nil
    local y = type(coords) == "table" and tonumber(coords.y) or nil
    if not x or not y or x ~= x or y ~= y or math.abs(x) > 10000.0 or math.abs(y) > 10000.0 then
        cb({ success = false, error = "invalid_marker" })
        return
    end

    SetNewWaypoint(x, y)
    cb({ success = true })
end)

local weather_types = {
    [joaat("EXTRASUNNY")] = "sunny",
    [joaat("CLEAR")] = "clear",
    [joaat("CLOUDS")] = "partly_cloudy",
    [joaat("OVERCAST")] = "cloudy",
    [joaat("RAIN")] = "rain",
    [joaat("CLEARING")] = "rain",
    [joaat("THUNDER")] = "thunder",
    [joaat("SMOG")] = "fog",
    [joaat("FOGGY")] = "fog",
    [joaat("NEUTRAL")] = "cloudy",
    [joaat("SNOW")] = "snow",
    [joaat("BLIZZARD")] = "snow",
    [joaat("SNOWLIGHT")] = "snow",
    [joaat("XMAS")] = "snow",
    [joaat("HALLOWEEN")] = "cloudy",
}

local function weather_region(coords)
    if coords.x > 2500.0 and coords.y < -3000.0 then
        return "cayo_perico"
    end
    if coords.y > 900.0 then
        return "blaine_county"
    end
    return "los_santos"
end

RegisterNUICallback("weather:get", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local coords = GetEntityCoords(PlayerPedId())
    local weather_hash = GetPrevWeatherTypeHashName()
    local next_weather_hash = GetNextWeatherTypeHashName()
    cb({
        success = true,
        data = {
            condition = weather_types[weather_hash] or "clear",
            nextCondition = weather_types[next_weather_hash] or weather_types[weather_hash] or "clear",
            region = weather_region(coords),
            clock = {
                year = GetClockYear(),
                month = GetClockMonth() + 1,
                day = GetClockDayOfMonth(),
                hour = GetClockHours(),
                minute = GetClockMinutes(),
            },
            windSpeed = math.max(0.0, GetWindSpeed()),
            rainLevel = math.max(0.0, math.min(1.0, GetRainLevel())),
        },
    })
end)

local function garage_vehicle_kind(model_hash, fallback)
    if IsThisModelABoat(model_hash) then
        return "boat"
    end
    if IsThisModelAPlane(model_hash) then
        return "plane"
    end
    if IsThisModelAHeli(model_hash) then
        return "helicopter"
    end
    if IsThisModelABike(model_hash) or IsThisModelABicycle(model_hash) then
        return "bike"
    end
    return fallback
end

RegisterNUICallback("garage:vehicles", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = Bridge.Callbacks.Trigger("sky_phone:garage:vehicles", data)
    if type(result) ~= "table" or not result.success or type(result.data) ~= "table" then
        cb(type(result) == "table" and result or { success = false, error = "request_failed" })
        return
    end
    for _, vehicle in ipairs(result.data.vehicles or {}) do
        local model_hash = tonumber(vehicle.model)
        if not model_hash and type(vehicle.model) == "string" and vehicle.model ~= "" then
            model_hash = joaat(vehicle.model)
        end
        if model_hash then
            local display_name = GetDisplayNameFromVehicleModel(model_hash)
            local label = display_name and GetLabelText(display_name) or nil
            if label and label ~= "NULL" and label ~= "CARNOTFOUND" then
                vehicle.name = label
            elseif type(vehicle.model) == "string" and vehicle.model ~= "" then
                vehicle.name = vehicle.model
            end
            vehicle.kind = garage_vehicle_kind(model_hash, vehicle.kind)
        end
    end
    cb(result)
end)

for _, callback_name in ipairs(server_callbacks) do
    RegisterNUICallback(callback_name, function(data, cb)
        if type(data) ~= "table" then
            cb({ success = false, error = "invalid_request" })
            return
        end
        local result = Bridge.Callbacks.Trigger("sky_phone:" .. callback_name, data)
        if callback_name:match("^media:import:") and (not result or not result.success) then
            Bridge.Debug(
                "warn",
                "[sky_phone] NUI callback '%s' failed: %s.",
                callback_name,
                tostring(result and result.error or "no server response"),
                { always = true }
            )
        end
        if type(result) == "table" then
            cb(result)
            return
        end

        cb({ success = false, error = "request_failed" })
    end)
end

RegisterNetEvent("sky_phone:device:open", function(data)
    if type(data) ~= "table" or type(data.device) ~= "table" or type(data.device.imei) ~= "string" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid device open data.")
        return
    end
    Bridge.Debug(
        "debug",
        "[sky_phone] Client received device open for IMEI %s account_linked=%s.",
        tostring(data.device.imei),
        tostring(data.account ~= nil),
        { always = true }
    )
    device_payload = data
    open_requested = true
    if is_open then
        SkyPhoneApps.SendCatalog()
        SendNUIMessage({ type = "device:updated", data = data })
        return
    end
    open_phone()
end)

RegisterNetEvent("sky_phone:device:updated", function(data)
    if type(data) ~= "table" or type(data.device) ~= "table" or type(data.device.imei) ~= "string" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid device update data.")
        return
    end
    device_payload = data
    SendNUIMessage({ type = "device:updated", data = data })
end)

RegisterNetEvent("sky_phone:device:invalidated", function()
    TriggerEvent("sky_phone:animation:reset")
    close_phone(false)
    device_payload = nil
    live_activity_active = false
    open_home_requested = false
end)

RegisterNetEvent("sky_phone:device:error", function(error_code)
    Bridge.Debug(
        "debug",
        "[sky_phone] Client received device error: %s.",
        tostring(error_code),
        { always = true }
    )
    local message = locale.DeviceErrors[error_code] or locale.DeviceErrors.default
    Bridge.Framework.Notify("iFruit", message, "error", 5000)
end)

RegisterNetEvent("sky_phone:mail:changed", function(data)
    SendNUIMessage({ type = "mail:changed", data = data })
end)

RegisterNetEvent("sky_phone:easyshare:changed", function(data)
    SendNUIMessage({ type = "easyshare:changed", data = data })
end)

RegisterNetEvent("sky_phone:gallery:changed", function()
    SendNUIMessage({ type = "gallery:changed" })
end)

RegisterNetEvent("sky_phone:mail:new", function(data)
    local mail_locale = locale.Nui.Apps.mail
    data.title = mail_locale.name
    data.text = mail_locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "mail:new", data = data })
end)

RegisterNetEvent("sky_phone:marketplace:changed", function(data)
    SendNUIMessage({ type = "marketplace:changed", data = data })
end)

RegisterNetEvent("sky_phone:companies:changed", function(data)
    SendNUIMessage({ type = "companies:changed", data = data })
end)

RegisterNetEvent("sky_phone:citywarn:changed", function(data)
    if type(data) ~= "table" then
        return
    end
    local citywarn_locale = locale.Nui.Apps.citywarn
    data.title = citywarn_locale.name
    data.text = citywarn_locale.notifications[data.kind] or citywarn_locale.notifications.update
    SendNUIMessage({ type = "citywarn:changed", data = data })
end)

RegisterNetEvent("sky_phone:companies:notification", function(data)
    local companies_locale = locale.Nui.Apps.companies
    data.title = companies_locale.name
    data.text = companies_locale.notifications[data.kind]
        or companies_locale.notifications.requestUpdated
    SendNUIMessage({ type = "companies:notification", data = data })
end)

RegisterNetEvent("sky_phone:fliptok:command-feedback", function(data)
    Bridge.Framework.Notify("FlipTok", data.message, data.notificationType, 5000)
end)

RegisterNetEvent("sky_phone:fliptok:verification-changed", function(data)
    SendNUIMessage({ type = "fliptok:verification-changed", data = data })
end)

RegisterNetEvent("sky_phone:fliptok:new", function(data)
    local fliptok_locale = locale.Nui.Apps.fliptok
    local notification_text = fliptok_locale.notifications[data.kind] or fliptok_locale.notifications.default
    data.title = fliptok_locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "fliptok:new", data = data })
end)

RegisterNetEvent("sky_phone:picstagram:command-feedback", function(data)
    Bridge.Framework.Notify("Picstagram", data.message, data.notificationType, 5000)
end)

RegisterNetEvent("sky_phone:picstagram:verification-changed", function(data)
    SendNUIMessage({ type = "picstagram:verification-changed", data = data })
end)

RegisterNetEvent("sky_phone:picstagram:new", function(data)
    local picstagram_locale = locale.Nui.Apps.picstagram
    local notification_text = picstagram_locale.notifications[data.kind] or picstagram_locale.notifications.default
    data.title = picstagram_locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "picstagram:new", data = data })
end)

RegisterNetEvent("sky_phone:feather:new", function(data)
    local feather_locale = locale.Nui.Apps.feather
    local notification_text = feather_locale.notifications[data.kind] or feather_locale.notifications.default
    data.title = feather_locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "feather:new", data = data })
end)

RegisterNetEvent("sky_phone:marketplace:new-message", function(data)
    local marketplace_locale = locale.Nui.Apps.citymarkt
    data.title = marketplace_locale.name
    if data.kind == "offer" then
        data.text = marketplace_locale.newOffer
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "accepted" then
        data.text = marketplace_locale.offerAcceptedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "rejected" then
        data.text = marketplace_locale.offerRejectedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    else
        data.text = marketplace_locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "marketplace:new-message", data = data })
end)

RegisterNetEvent("sky_phone:calendar:reminder", function(data)
    local calendar_locale = locale.Nui.Apps.calendar
    data.title = calendar_locale.name
    data.text = calendar_locale.reminder:gsub("{title}", tostring(data.eventTitle))
    SendNUIMessage({ type = "calendar:reminder", data = data })
end)

RegisterNetEvent("sky_phone:flare:match", function(data)
    local flare_locale = locale.Nui.Apps.flare
    data.title = flare_locale.name
    data.text = flare_locale.newMatchNotification:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "flare:new-match", data = data })
end)

RegisterNetEvent("sky_phone:flare:message", function(data)
    local flare_locale = locale.Nui.Apps.flare
    data.title = flare_locale.name
    data.text = flare_locale.newMessageNotification:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "flare:new-message", data = data })
end)

RegisterNetEvent("sky_phone:sim:picker", function(data)
    if type(data) ~= "table" or type(data.number) ~= "string" or type(data.choices) ~= "table" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid SIM picker data.")
        return
    end
    sim_picker_open = true
    sim_picker_payload = data
    update_nui_focus()
    SendNUIMessage({ type = "sim:picker", data = data })
end)

RegisterNetEvent("sky_phone:sim:picker-close", function()
    sim_picker_open = false
    sim_picker_payload = nil
    update_nui_focus()
    SendNUIMessage({ type = "sim:picker-close" })
end)

RegisterNetEvent("sky_phone:contacts:changed", function()
    SendNUIMessage({ type = "contacts:changed" })
end)

RegisterNetEvent("sky_phone:calls:changed", function()
    SendNUIMessage({ type = "calls:changed" })
end)

RegisterNetEvent("sky_phone:banking:changed", function(data)
    SendNUIMessage({ type = "banking:changed", data = data })
end)

RegisterNetEvent("sky_phone:crypto:changed", function(data)
    if type(data) ~= "table" or type(data.markets) ~= "table" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid crypto market data.")
        return
    end
    SendNUIMessage({ type = "crypto:changed", data = data })
end)

RegisterNetEvent("sky_phone:crypto:account-changed", function()
    SendNUIMessage({ type = "crypto:account-changed" })
end)

RegisterNetEvent("sky_phone:billing:changed", function()
    SendNUIMessage({ type = "billing:changed" })
end)

RegisterNetEvent("sky_phone:billing:new", function(data)
    local billing_locale = locale.Nui.Apps.billing
    data.title = billing_locale.name
    data.text = billing_locale.notifications.newInvoice
        :gsub("{issuer}", tostring(data.issuer))
        :gsub("{amount}", ("%s %s"):format(tostring(data.amount), Config.Billing.Currency))
    SendNUIMessage({ type = "billing:new", data = data })
end)

RegisterNetEvent("sky_phone:crewlink:changed", function(data)
    SendNUIMessage({ type = "crewlink:changed", data = data })
end)

RegisterNetEvent("sky_phone:crewlink:notification", function(data)
    local crewlink_locale = locale.Nui.Apps.crewlink
    local notification_text = crewlink_locale.notifications[data.kind]
        or crewlink_locale.notifications.default
    data.title = crewlink_locale.name
    data.text = notification_text
        :gsub("{actor}", tostring(data.actor or ""))
        :gsub("{group}", tostring(data.groupName or ""))
        :gsub("{ping}", tostring(data.pingLabel or ""))
    SendNUIMessage({ type = "crewlink:notification", data = data })
end)

RegisterNetEvent("sky_phone:messages:changed", function(data)
    SendNUIMessage({ type = "messages:changed", data = data })
end)

RegisterNetEvent("sky_phone:messages:new", function(data)
    local messages_locale = locale.Nui.Apps.messages
    data.title = messages_locale.name
    data.text = messages_locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "messages:new", data = data })
end)

RegisterNetEvent("sky_phone:darkchat:changed", function(data)
    SendNUIMessage({ type = "darkchat:changed", data = data })
end)

RegisterNetEvent("sky_phone:darkchat:new", function(data)
    local darkchat_locale = locale.Nui.Apps.darkchat
    data.title = darkchat_locale.name
    if data.notificationMode == "private" then
        data.sender = nil
        data.text = darkchat_locale.privateNotification
    elseif data.notificationMode == "hidden" then
        data.sender = nil
        data.text = ""
    else
        data.text = darkchat_locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "darkchat:new", data = data })
end)

RegisterNetEvent("sky_phone:call:incoming", function(data)
    if type(data) ~= "table" or type(data.id) ~= "string" or data.state ~= "ringing" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid incoming call data.")
        return
    end
    active_call_payload = data
    call_focus = true
    update_nui_focus()
    TriggerEvent("sky_phone:animation:call", data)
    SendNUIMessage({ type = "call:incoming", data = data })
end)

RegisterNetEvent("sky_phone:call:state", function(data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.state) ~= "string" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid call state data.")
        return
    end
    if data.state == "ringing" or data.state == "connected" then
        active_call_payload = data
    end
    if data.state ~= "ringing" then
        local focus_changed = call_focus
        call_focus = false
        if focus_changed then
            update_nui_focus()
        end
    end
    if data.state ~= "ringing" and data.state ~= "connected" then
        active_call_payload = nil
    end
    if data.state == "connected" and data.channel then
        if not join_call_voice(data.channel) then
            TriggerEvent("sky_phone:device:error", "voice_unavailable")
        end
    elseif data.state ~= "ringing" then
        leave_call_voice()
    end
    TriggerEvent("sky_phone:animation:call", data)
    SendNUIMessage({ type = "call:state", data = data })
end)

CreateThread(function()
    if Config.Phone.DevelopmentCommand then
        TriggerEvent("chat:addSuggestion", "/" .. Config.Command, locale.CommandDescription)
    end
    if Config.TestData.Enabled then
        TriggerEvent("chat:addSuggestion", "/" .. Config.TestData.Command, locale.TestData.CommandDescription)
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    is_open = false
    open_requested = false
    notification_focus = false
    call_focus = false
    payphone_focus = false
    camera_active = false
    camera_nui_focused = true
    sim_picker_open = false
    sim_picker_payload = nil
    active_call_payload = nil
    activity_suspended = false
    phone_game_input = false
    phone_text_input_focused = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)

    TriggerEvent("sky_phone:animation:reset")
    leave_call_voice()

    if Config.Phone.DevelopmentCommand then
        TriggerEvent("chat:removeSuggestion", "/" .. Config.Command)
    end
    if Config.TestData.Enabled then
        TriggerEvent("chat:removeSuggestion", "/" .. Config.TestData.Command)
    end
end)
