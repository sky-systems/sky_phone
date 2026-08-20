local disabled_controls = {}
local all_controls_disabled = {}
local firing_disabled = false
local event_handlers = {}
local nui_callbacks = {}
local nui_focus = nil
local nui_keep_input = nil

Config = { Phone = { AllowMovement = true } }
Bridge = { Debug = function() end }

function CreateThread(callback)
    assert(type(callback) == "function", "focus runtime must register its control thread")
end

function AddEventHandler(event_name, callback)
    event_handlers[event_name] = callback
end

function RegisterNUICallback(callback_name, callback)
    nui_callbacks[callback_name] = callback
end

function SetNuiFocus(focused, cursor)
    nui_focus = { focused = focused, cursor = cursor }
end

function SetNuiFocusKeepInput(keep_input)
    nui_keep_input = keep_input
end

function TriggerEvent() end

function DisableControlAction(group, control, disabled)
    assert(group == 0 and disabled, "phone controls must be disabled in the primary input group")
    disabled_controls[control] = true
end

function DisableAllControlActions(group)
    all_controls_disabled[group] = true
end

function PlayerId()
    return 7
end

function DisablePlayerFiring(player, disabled)
    assert(player == 7, "movement filtering must target the local player")
    firing_disabled = disabled
end

dofile("sky_phone/source/client/focus.lua")

local function resolve(overrides)
    local state = {
        activity_suspended = false,
        allow_movement = false,
        call_focus = false,
        camera_active = false,
        camera_nui_focused = true,
        cursor_disabled = false,
        external_game_input = nil,
        is_open = false,
        notification_focus = false,
        payphone_focus = false,
        sim_picker_open = false,
        text_input_focused = false,
    }
    for key, value in pairs(overrides or {}) do
        state[key] = value
    end
    return SkyPhoneFocus.Resolve(state)
end

local idle = resolve()
assert(
    not idle.cursor and not idle.focused and not idle.keep_input,
    "idle NUI must release focus and game input override"
)

local minimized_call = resolve()
assert(not minimized_call.focused, "a replayed call without an attention claim must stay unfocused")

local incoming_call = resolve({ call_focus = true })
assert(
    incoming_call.cursor and incoming_call.focused and not incoming_call.keep_input,
    "incoming call attention must focus the NUI"
)

local stationary_phone = resolve({ is_open = true })
assert(
    stationary_phone.cursor
        and stationary_phone.focused
        and stationary_phone.block_game
        and not stationary_phone.keep_input,
    "an open phone must block game input when movement is disabled"
)

local movable_phone = resolve({ allow_movement = true, is_open = true })
assert(
    movable_phone.cursor
        and movable_phone.focused
        and movable_phone.keep_input
        and movable_phone.game_input
        and not movable_phone.block_game
        and movable_phone.block_look,
    "an open phone must allow movement without hiding the NUI cursor"
)

local typing_phone = resolve({
    allow_movement = true,
    is_open = true,
    text_input_focused = true,
})
assert(
    typing_phone.cursor
        and typing_phone.focused
        and typing_phone.keep_input
        and typing_phone.game_input
        and typing_phone.block_game,
    "a focused phone text input must block GTA controls without hiding the NUI cursor"
)

local external_movement_phone = resolve({
    external_game_input = true,
    is_open = true,
})
assert(
    external_movement_phone.cursor
        and external_movement_phone.focused
        and external_movement_phone.keep_input
        and external_movement_phone.game_input
        and not external_movement_phone.block_game,
    "an external input claim must preserve movement while the app cursor is active"
)

local external_movement_typing_phone = resolve({
    external_game_input = true,
    is_open = true,
    text_input_focused = true,
})
assert(
    external_movement_typing_phone.cursor
        and external_movement_typing_phone.focused
        and external_movement_typing_phone.keep_input
        and external_movement_typing_phone.game_input
        and external_movement_typing_phone.block_game,
    "a focused text input must override an external movement claim"
)

local external_typing_phone = resolve({
    allow_movement = true,
    external_game_input = false,
    is_open = true,
})
assert(
    external_typing_phone.cursor
        and external_typing_phone.focused
        and not external_typing_phone.keep_input
        and not external_typing_phone.game_input
        and external_typing_phone.block_game,
    "an external typing claim must block GTA input"
)

local movable_cursor_disabled_phone = resolve({
    allow_movement = true,
    cursor_disabled = true,
    is_open = true,
})
assert(
    not movable_cursor_disabled_phone.cursor
        and movable_cursor_disabled_phone.focused
        and movable_cursor_disabled_phone.keep_input
        and movable_cursor_disabled_phone.game_input
        and not movable_cursor_disabled_phone.block_game
        and not movable_cursor_disabled_phone.block_look,
    "LB noFocus must preserve movement and camera look without retaining the NUI cursor"
)

local stationary_cursor_disabled_phone = resolve({
    cursor_disabled = true,
    is_open = true,
})
assert(
    not stationary_cursor_disabled_phone.cursor
        and stationary_cursor_disabled_phone.focused
        and not stationary_cursor_disabled_phone.keep_input,
    "LB noFocus must hide the cursor even when phone movement is disabled"
)

SkyPhoneFocus.ApplyFocusedControls()
for _, group in ipairs({ 0, 1, 2 }) do
    assert(all_controls_disabled[group], ("focused phone cursor must block input group %d while typing"):format(group))
end
assert(firing_disabled, "focused phone cursor must block attacks while typing")

all_controls_disabled = {}
firing_disabled = false
SkyPhoneFocus.ApplyGameInputControls(true)
for _, control in ipairs({ 24, 140, 141, 142, 257, 263, 264 }) do
    assert(disabled_controls[control], ("phone control %d must remain disabled"):format(control))
end
assert(not disabled_controls[19], "Alt must remain available while no phone text input is focused")
for _, control in ipairs({ 1, 2, 3, 4, 5, 6 }) do
    assert(disabled_controls[control], ("look control %d must be disabled while the phone cursor is active"):format(control))
end
assert(not disabled_controls[21] and not disabled_controls[22], "sprint and jump must stay enabled")
assert(not disabled_controls[30] and not disabled_controls[31], "movement axes must stay enabled")
assert(firing_disabled, "player attacks must remain disabled while the phone is open")

disabled_controls = {}
firing_disabled = false
SkyPhoneFocus.ApplyGameInputControls(false)
assert(not disabled_controls[1] and not disabled_controls[2], "camera passthrough must preserve camera look")
assert(firing_disabled, "player attacks must remain disabled during camera passthrough")

local movable_notification = resolve({ allow_movement = true, notification_focus = true })
assert(
    movable_notification.focused and not movable_notification.keep_input,
    "movement configuration must not affect a notification without an open phone"
)

local camera_game_input = resolve({
    camera_active = true,
    camera_nui_focused = false,
    is_open = true,
})
assert(
    not camera_game_input.cursor
        and camera_game_input.focused
        and camera_game_input.keep_input
        and camera_game_input.game_input
        and not camera_game_input.block_look,
    "camera movement must keep keyboard focus and GTA movement without retaining the NUI cursor"
)

local focused_camera = resolve({
    allow_movement = true,
    camera_active = true,
    camera_nui_focused = true,
    is_open = true,
})
assert(
    focused_camera.cursor
        and focused_camera.focused
        and not focused_camera.keep_input
        and not focused_camera.game_input,
    "focused camera must override movement configuration until Space enables passthrough"
)

local camera_interrupted_by_call = resolve({
    call_focus = true,
    camera_active = true,
    camera_nui_focused = false,
    is_open = true,
})
assert(
    camera_interrupted_by_call.cursor
        and camera_interrupted_by_call.focused
        and not camera_interrupted_by_call.keep_input,
    "incoming call attention must override camera passthrough input"
)

local camera_after_connected_call = resolve({
    call_focus = false,
    camera_active = true,
    camera_nui_focused = false,
    is_open = true,
})
assert(
    not camera_after_connected_call.cursor
        and camera_after_connected_call.focused
        and camera_after_connected_call.keep_input,
    "connected call without an attention claim must restore camera movement input"
)

local payphone_closed_behind_phone = resolve({ is_open = true, payphone_focus = false })
assert(payphone_closed_behind_phone.focused, "releasing payphone focus must not clear mobile phone focus")

local suspended = resolve({ activity_suspended = true, call_focus = true, is_open = true })
assert(not suspended.focused and not suspended.keep_input, "suspended activities must mask every focus claim")

SkyPhoneFocus.SetPhone(true, true)
assert(
    nui_focus.focused and not nui_focus.cursor and nui_keep_input,
    "runtime phone focus must preserve the no-focus opening contract"
)

SkyPhoneFocus.SetPhone(false)
SkyPhoneFocus.SetPhone(true)
assert(nui_focus.cursor, "closing the phone must clear the previous no-focus claim")

local external_success, external_error = SkyPhoneFocus.SetExternalGameInput("custom_app", true)
assert(external_success and external_error == nil and nui_keep_input, "external movement claim must apply")
external_success, external_error = SkyPhoneFocus.SetExternalGameInput("custom_app", false)
assert(external_success and external_error == nil and not nui_keep_input, "external typing claim must apply")
event_handlers["onClientResourceStop"]("custom_app")
assert(nui_keep_input, "resource stop must restore configured phone movement")

SkyPhoneFocus.SetPhone(false)
external_success, external_error = SkyPhoneFocus.SetExternalGameInput("custom_app", true)
assert(not external_success and external_error == "phone_closed", "closed phones must reject external focus claims")

local notification_result
SkyPhoneFocus.SetPhone(false)
nui_callbacks["notification:focus"]({ active = true }, function(result)
    notification_result = result
end)
assert(notification_result.success and nui_focus.focused, "notification focus must be applied through the focus owner")

SkyPhoneFocus.BeginNuiHydration()
SkyPhoneFocus.Reapply()
assert(not nui_focus.focused, "CEF hydration must discard browser-owned notification focus")

SkyPhoneFocus.Reset()
assert(not nui_focus.focused and not nui_focus.cursor and not nui_keep_input, "focus reset must release NUI input")

print("Client focus tests passed")
