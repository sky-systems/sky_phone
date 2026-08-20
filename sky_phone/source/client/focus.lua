SkyPhoneFocus = {}

local blocked_phone_controls = { 24, 140, 141, 142, 257, 263, 264 }
local blocked_phone_look_controls = { 1, 2, 3, 4, 5, 6 }
local focused_control_groups = { 0, 1, 2 }

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
    if state.activity_suspended then
        return { block_game = false, cursor = false, focused = false, game_input = false, keep_input = false }
    end
    if state.call_focus then
        return { block_game = true, cursor = true, focused = true, game_input = false, keep_input = false }
    end
    if state.camera_active and not state.camera_nui_focused then
        return { block_game = false, block_look = false, cursor = false, focused = true, game_input = true, keep_input = true }
    end
    local game_input = state.is_open and state.allow_movement and not state.camera_active
    local focused = state.is_open
        or state.notification_focus
        or state.payphone_focus
        or state.sim_picker_open
        or (state.camera_active and state.camera_nui_focused)
    local cursor = focused
    return {
        block_game = cursor and (not game_input or state.text_input_focused),
        block_look = game_input,
        cursor = cursor,
        focused = focused,
        game_input = game_input,
        keep_input = game_input,
    }
end
