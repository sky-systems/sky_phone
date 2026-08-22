SkyPhoneClient = {}

local is_open = false
local open_requested = false
local open_without_focus = false
local device_payload = nil
local equipped_phone_number = nil
local nui_generation = 0
local live_activity_active = false
local open_home_requested = false
local admin_panel_open = false
local suggested_admin_command = nil
local suggested_test_data_command = nil
local active_development_command = nil
local registered_development_commands = {}
local active_key_mapping_command = nil
local active_key_mapping_key = nil
local key_mapping_revision = 0
local refresh_development_command
local refresh_phone_key_mapping
local refresh_test_data_command_suggestion

local function get_equipped_phone_number()
    if not device_payload or not device_payload.device.sim then
        return nil
    end

    return device_payload.device.sim.number
end

local function set_equipped_phone_number(next_number)
    if next_number ~= nil and type(next_number) ~= "string" then
        next_number = nil
    end
    if next_number == equipped_phone_number then
        return
    end

    equipped_phone_number = next_number
    TriggerEvent("sky_phone:client:phoneNumberChanged", next_number)
end

local function update_equipped_phone_number(data)
    set_equipped_phone_number(type(data) == "table"
        and type(data.device) == "table"
        and type(data.device.sim) == "table"
        and data.device.sim.number
        or nil)
end

local function get_authoritative_phone_number()
    local result = Bridge.Callbacks.Trigger("sky_phone:device:equipped-number", {})
    if type(result) ~= "table" or not result.success or type(result.data) ~= "table" then
        return nil
    end

    local phone_number = result.data.phoneNumber
    set_equipped_phone_number(phone_number)
    return phone_number
end

local function get_phone_state()
    return {
        inCall = SkyPhoneCalls.IsActive(),
        onScreen = is_open,
        open = is_open,
        phoneNumber = get_equipped_phone_number(),
    }
end

SkyPhoneClient.GetState = get_phone_state
SkyPhoneClient.GetEquippedPhoneNumber = get_authoritative_phone_number

Bridge.Debug("debug", "[sky_phone] Client script initialized.", { always = true })

local locale, locale_name = SkyPhoneLocales.Resolve(Config.Bridge.Locale)

local function send_admin_panel_open()
    SendNUIMessage({
        type = "admin:open",
        data = {
            lang = locale_name,
            locales = locale.Nui,
            fallbackLocales = Locales.en.Nui,
        },
    })
end

local function close_admin_panel()
    if not admin_panel_open then
        return
    end
    admin_panel_open = false
    SkyPhoneFocus.SetAdminPanel(false)
    SendNUIMessage({ type = "admin:close" })
end

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

local function refresh_admin_command_suggestion()
    if suggested_admin_command then
        TriggerEvent("chat:removeSuggestion", "/" .. suggested_admin_command)
        suggested_admin_command = nil
    end
    if Config.AdminPanel.Enabled then
        suggested_admin_command = Config.AdminPanel.Command
        TriggerEvent(
            "chat:addSuggestion",
            "/" .. suggested_admin_command,
            locale.AdminCommand.CommandDescription
        )
    end
end

AddEventHandler("sky_phone:configurator:updated", function()
    locale, locale_name = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
    refresh_development_command()
    refresh_phone_key_mapping()
    refresh_test_data_command_suggestion()
    refresh_admin_command_suggestion()
    SkyPhoneApps.SendCatalog()
    if is_open and device_payload then
        device_payload.lang = locale_name
        device_payload.locales = locale.Nui
        device_payload.fallbackLocales = Locales.en.Nui
        SendNUIMessage({ type = "device:updated", data = device_payload })
    end
    if admin_panel_open then
        send_admin_panel_open()
    end
end)

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
    open_without_focus = false
    TriggerEvent("sky_phone:animation:phone", false)
    is_open = false
    if was_open then
        SkyPhoneApps.SetPhoneOpen(false)
        TriggerEvent("sky_phone:nuiClosed")
        TriggerEvent("sky_phone:client:phoneToggled", false)
    end
    SkyPhoneFocus.SetPhone(false)
    if was_requested or was_open then
        SendNUIMessage({ type = "app:close" })
        if close_device_session ~= false then
            Bridge.Callbacks.Trigger("sky_phone:device:close", {})
        end
    end
end

local function toggle_phone(open, no_focus)
    if open ~= nil and type(open) ~= "boolean" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid phone toggle state.")
        return false
    end
    if no_focus ~= nil and type(no_focus) ~= "boolean" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid phone toggle focus state.")
        return false
    end

    local should_open = open
    if should_open == nil then
        should_open = not (is_open or open_requested)
    end
    if not should_open then
        close_phone()
        return true
    end

    open_without_focus = no_focus == true
    if is_open or open_requested then
        if is_open then
            SkyPhoneFocus.SetPhone(true, open_without_focus)
        end
        return true
    end

    local result = Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})
    if type(result) ~= "table" or result.success ~= true then
        open_without_focus = false
        return false
    end
    return true
end

SkyPhoneClient.Toggle = toggle_phone

AddEventHandler("sky_phone:client:forceClose", function()
    close_phone()
end)

local function run_development_command()
    if is_open or open_requested then
        close_phone()
        return
    end

    open_without_focus = false
    Bridge.Callbacks.Trigger("sky_phone:device:development-open", {})
end

refresh_development_command = function()
    local command_name = Config.Phone.DevelopmentCommand and Config.Command or nil
    if command_name ~= nil and (type(command_name) ~= "string" or command_name == "") then
        error("[sky_phone] Config.Command must be a non-empty command name.")
    end

    if active_development_command then
        TriggerEvent("chat:removeSuggestion", "/" .. active_development_command)
    end

    active_development_command = command_name
    if not command_name then
        return
    end

    if not registered_development_commands[command_name] then
        registered_development_commands[command_name] = true
        RegisterCommand(command_name, function()
            if active_development_command == command_name and Config.Phone.DevelopmentCommand then
                run_development_command()
            end
        end, false)
    end

    TriggerEvent("chat:addSuggestion", "/" .. command_name, locale.CommandDescription)
end

refresh_development_command()

local function run_phone_toggle()
    if is_open or open_requested then
        close_phone()
        return
    end

    open_without_focus = false
    Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})
end

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

RegisterCommand("sky_phone_toggle", run_phone_toggle, false)

refresh_phone_key_mapping = function()
    local key_name = Config.Phone.Keybind
    if key_name ~= false and key_name ~= nil and (type(key_name) ~= "string" or key_name == "") then
        error("[sky_phone] Config.Phone.Keybind must be a non-empty keyboard key name or false.")
    end
    if key_name == active_key_mapping_key then
        return
    end

    active_key_mapping_key = key_name
    active_key_mapping_command = nil
    if not key_name then
        return
    end

    key_mapping_revision = key_mapping_revision + 1
    local command_name = "sky_phone_toggle_config_" .. key_mapping_revision
    active_key_mapping_command = command_name
    RegisterCommand(command_name, function()
        if active_key_mapping_command == command_name then
            run_phone_toggle()
        end
    end, false)
    RegisterKeyMapping(command_name, locale.Controls.OpenPhone, "keyboard", key_name)
end

refresh_phone_key_mapping()

RegisterKeyMapping(
    "sky_phone_live_activity_open",
    locale.Controls.OpenPhone,
    "keyboard",
    "SPACE"
)

refresh_test_data_command_suggestion = function()
    if suggested_test_data_command then
        TriggerEvent("chat:removeSuggestion", "/" .. suggested_test_data_command)
        suggested_test_data_command = nil
    end
    if Config.TestData.Enabled then
        suggested_test_data_command = Config.TestData.Command
        TriggerEvent("chat:addSuggestion", "/" .. suggested_test_data_command, locale.TestData.CommandDescription)
    end
end

refresh_test_data_command_suggestion()

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
    -- Browser state is recreated on a CEF reload. Browser-owned focus claims
    -- cannot survive unless their UI is replayed as part of this handshake.
    SkyPhoneFocus.BeginNuiHydration()
    Bridge.Debug("debug", "[sky_phone] NUI reported ready.", { always = true })
    SkyPhoneApps.SendCatalog()
    if open_requested and device_payload then
        send_open_message()
    end
    if admin_panel_open then
        send_admin_panel_open()
    end
    SkyPhoneCalls.ReplayNui()
    SkyPhoneSimPicker.ReplayNui()
    SkyPhoneFocus.Reapply()
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
        SkyPhoneFocus.Reapply()
        cb({ success = false, error = "open_not_requested" })
        return
    end

    local was_open = is_open
    is_open = true
    SkyPhoneApps.SetPhoneOpen(true)
    if not was_open then
        TriggerEvent("sky_phone:client:phoneToggled", true)
    end
    SkyPhoneFocus.SetPhone(true, open_without_focus)
    TriggerEvent("sky_phone:animation:phone", true)
    cb({ success = true })
end)

RegisterNetEvent("sky_phone:admin:launch", function()
    if is_open or open_requested then
        close_phone()
    end
    admin_panel_open = true
    SkyPhoneFocus.SetAdminPanel(true)
    send_admin_panel_open()
end)

RegisterNetEvent("sky_phone:admin:command-error", function(error_code)
    local messages = locale.AdminCommand.Errors
    Bridge.Framework.Notify(
        "iFruit",
        messages[error_code] or messages.default,
        "error",
        5000
    )
end)

RegisterNUICallback("admin:close", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    close_admin_panel()
    cb({ success = true })
end)

RegisterNUICallback("ui:input-focus", function(data, cb)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    SkyPhoneFocus.SetTextInputFocused(
        data.active and (is_open or open_requested or admin_panel_open)
    )
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
    update_equipped_phone_number(data)
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
    update_equipped_phone_number(data)
    SendNUIMessage({ type = "device:updated", data = data })
end)

RegisterNetEvent("sky_phone:device:invalidated", function()
    TriggerEvent("sky_phone:animation:reset")
    close_phone(false)
    device_payload = nil
    update_equipped_phone_number(nil)
    live_activity_active = false
    open_home_requested = false
end)

RegisterNetEvent("sky_phone:device:error", function(error_code)
    if not is_open and not open_requested then
        open_without_focus = false
    end
    Bridge.Debug(
        "debug",
        "[sky_phone] Client received device error: %s.",
        tostring(error_code),
        { always = true }
    )
    local message = locale.DeviceErrors[error_code] or locale.DeviceErrors.default
    Bridge.Framework.Notify("iFruit", message, "error", 5000)
end)

CreateThread(function()
    refresh_admin_command_suggestion()
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    is_open = false
    open_requested = false
    open_without_focus = false
    admin_panel_open = false

    TriggerEvent("sky_phone:animation:reset")
    SkyPhoneCalls.Reset()
    SkyPhoneSimPicker.Reset()
    SkyPhoneFocus.Reset()

    if active_development_command then
        TriggerEvent("chat:removeSuggestion", "/" .. active_development_command)
    end
    if suggested_test_data_command then
        TriggerEvent("chat:removeSuggestion", "/" .. suggested_test_data_command)
    end
    if suggested_admin_command then
        TriggerEvent("chat:removeSuggestion", "/" .. suggested_admin_command)
    end
end)
