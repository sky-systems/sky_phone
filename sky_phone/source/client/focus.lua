SkyPhoneFocus = {}

local blocked_phone_controls = { 24, 140, 141, 142, 257, 263, 264 }
local blocked_phone_look_controls = { 1, 2, 3, 4, 5, 6 }
local focused_control_groups = { 0, 1, 2 }
local hold_to_look_enabled = false
local hold_to_look_control
local state = {
    admin_panel_open = false,
    activity_suspended = false,
    allow_movement = false,
    call_focus = false,
    camera_active = false,
    camera_nui_focused = true,
    cursor_disabled = false,
    external_game_input = nil,
    external_game_input_owner = nil,
    is_open = false,
    look_passthrough = false,
    notification_focus = false,
    payphone_focus = false,
    sim_picker_open = false,
    text_input_focused = false,
}
local block_game = false
local block_look = false
local game_input = false

local function refresh_focus_configuration()
    local hold_to_look_config = Config.Phone.HoldToLook
    local enabled = type(hold_to_look_config) == "table" and hold_to_look_config.Enabled == true
    local control = enabled and tonumber(hold_to_look_config.Control) or nil
    if enabled and (
        not control
        or control ~= math.floor(control)
        or control < 0
    ) then
        error("[sky_phone] Config.Phone.HoldToLook.Control must be a non-negative whole control index.")
    end

    hold_to_look_enabled = enabled
    hold_to_look_control = control
    state.allow_movement = Config.Phone.AllowMovement == true
end

local function allows_game_input(value)
    local allowed = value.external_game_input
    if allowed == nil then
        allowed = value.allow_movement
    end
    return allowed == true
end

refresh_focus_configuration()

AddEventHandler("sky_phone:configurator:updated", function()
    refresh_focus_configuration()
    SkyPhoneFocus.Reapply()
end)

function SkyPhoneFocus.ApplyFocusedControls()
    for _, group in ipairs(focused_control_groups) do
        DisableAllControlActions(group)
    end
    DisablePlayerFiring(PlayerId(), true)
end

function SkyPhoneFocus.ApplyGameInputControls(block_look)
    for _, control in ipairs(blocked_phone_controls) do
        DisableControlAction(0, control, true)
    end
    if block_look then
        for _, control in ipairs(blocked_phone_look_controls) do
            DisableControlAction(0, control, true)
        end
    end
    DisablePlayerFiring(PlayerId(), true)
end

function SkyPhoneFocus.Resolve(state)
    if state.admin_panel_open then
        return {
            block_game = true,
            cursor = true,
            focused = true,
            game_input = false,
            keep_input = false,
        }
    end
    if state.activity_suspended then
        return { block_game = false, cursor = false, focused = false, game_input = false, keep_input = false }
    end
    if state.call_focus then
        return { block_game = true, cursor = true, focused = true, game_input = false, keep_input = false }
    end
    if state.camera_active and not state.camera_nui_focused then
        return { block_game = false, block_look = false, cursor = false, focused = true, game_input = true, keep_input = true }
    end
    local game_input = state.is_open
        and allows_game_input(state)
        and not state.camera_active
        and not state.text_input_focused
    local focused = state.is_open
        or state.notification_focus
        or state.payphone_focus
        or state.sim_picker_open
        or (state.camera_active and state.camera_nui_focused)
    local cursor = focused and not (state.is_open and (state.cursor_disabled or state.look_passthrough))
    return {
        block_game = cursor and not game_input,
        block_look = game_input and cursor,
        cursor = cursor,
        focused = focused,
        game_input = game_input,
        keep_input = game_input,
    }
end

function SkyPhoneFocus.Reapply()
    if state.look_passthrough and (
        not hold_to_look_enabled
        or not state.is_open
        or state.cursor_disabled
        or state.text_input_focused
        or state.camera_active
        or not allows_game_input(state)
    ) then
        state.look_passthrough = false
    end
    local focus = SkyPhoneFocus.Resolve(state)
    SetNuiFocus(focus.focused, focus.cursor)
    SetNuiFocusKeepInput(focus.keep_input)
    block_game = focus.block_game == true
    block_look = focus.block_look == true
    game_input = focus.game_input == true
    TriggerEvent("sky_phone:client:cameraFocusApplied", {
        active = state.camera_active,
        cursor = focus.cursor,
        focused = focus.focused,
        gameInput = focus.keep_input,
    })
end

function SkyPhoneFocus.BeginNuiHydration()
    -- Browser-owned focus claims cannot survive a CEF reload.
    state.notification_focus = false
    state.look_passthrough = false
    state.text_input_focused = false
end

function SkyPhoneFocus.SetPhone(open, cursor_disabled)
    state.is_open = open == true
    if cursor_disabled ~= nil then
        state.cursor_disabled = cursor_disabled == true
    end
    if state.is_open then
        state.notification_focus = false
        state.call_focus = false
    else
        state.activity_suspended = false
        state.call_focus = false
        state.cursor_disabled = false
        state.external_game_input = nil
        state.external_game_input_owner = nil
        state.look_passthrough = false
        state.text_input_focused = false
    end
    SkyPhoneFocus.Reapply()
end

function SkyPhoneFocus.SetAdminPanel(open)
    state.admin_panel_open = open == true
    if state.admin_panel_open then
        state.notification_focus = false
        state.text_input_focused = false
    end
    SkyPhoneFocus.Reapply()
end

function SkyPhoneFocus.SetCall(active)
    state.call_focus = active == true
    SkyPhoneFocus.Reapply()
end

function SkyPhoneFocus.SetSimPicker(active)
    state.sim_picker_open = active == true
    SkyPhoneFocus.Reapply()
end

function SkyPhoneFocus.SetTextInputFocused(active)
    state.text_input_focused = active == true
    if state.text_input_focused then
        state.look_passthrough = false
    end
    SkyPhoneFocus.Reapply()
end

function SkyPhoneFocus.SetExternalGameInput(owner_resource, allow_game_input)
    if type(owner_resource) ~= "string" or owner_resource == "" or type(allow_game_input) ~= "boolean" then
        return false, "invalid_focus_claim"
    end
    if not state.is_open then
        return false, "phone_closed"
    end

    state.external_game_input = allow_game_input
    state.external_game_input_owner = owner_resource
    SkyPhoneFocus.Reapply()
    return true
end

function SkyPhoneFocus.Reset()
    state.admin_panel_open = false
    state.activity_suspended = false
    state.call_focus = false
    state.camera_active = false
    state.camera_nui_focused = true
    state.cursor_disabled = false
    state.external_game_input = nil
    state.external_game_input_owner = nil
    state.is_open = false
    state.look_passthrough = false
    state.notification_focus = false
    state.payphone_focus = false
    state.sim_picker_open = false
    state.text_input_focused = false
    block_game = false
    block_look = false
    game_input = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end

CreateThread(function()
    while true do
        if game_input or block_game then
            local look_passthrough = hold_to_look_enabled
                and game_input
                and not state.cursor_disabled
                and IsControlPressed(0, hold_to_look_control)
            if look_passthrough ~= state.look_passthrough then
                state.look_passthrough = look_passthrough
                SkyPhoneFocus.Reapply()
            end
            if block_game then
                SkyPhoneFocus.ApplyFocusedControls()
            else
                SkyPhoneFocus.ApplyGameInputControls(block_look)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler("sky_phone:client:setSuspended", function(suspended)
    state.activity_suspended = suspended == true
    SkyPhoneFocus.Reapply()
end)

AddEventHandler("sky_phone:client:setPayphoneFocus", function(focused)
    state.payphone_focus = focused == true
    SkyPhoneFocus.Reapply()
end)

AddEventHandler("sky_phone:client:setCameraFocus", function(data)
    if type(data) ~= "table" or type(data.active) ~= "boolean" or type(data.nuiFocused) ~= "boolean" then
        Bridge.Debug("error", "[sky_phone] Rejected invalid camera focus claim.")
        return
    end
    state.camera_active = data.active
    state.camera_nui_focused = data.nuiFocused
    SkyPhoneFocus.Reapply()
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    if resource_name ~= state.external_game_input_owner then
        return
    end

    state.external_game_input = nil
    state.external_game_input_owner = nil
    SkyPhoneFocus.Reapply()
end)

RegisterNUICallback("notification:focus", function(data, cb)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    state.notification_focus = data.active == true and not state.is_open
    SkyPhoneFocus.Reapply()
    cb({ success = true })
end)
