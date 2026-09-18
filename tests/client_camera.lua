local callbacks = {}
local camera_coord = nil
local camera_target = nil
local camera_created = false
local camera_destroyed = false
local scripted_camera_rendering = false
local event_handlers = {}
local threads = {}
local hold_to_look_pressed = false
local disabled_controls = {}
local disabled_control_normals = {}
local triggered_events = {}
local nui_messages = {}
local thread_stop = {}

SkyPhoneFocus = {
    IsHoldToLookPressed = function()
        return hold_to_look_pressed
    end,
}

local vector_meta = {}
vector_meta.__index = vector_meta

function vector_meta.__add(left, right)
    return vector3(left.x + right.x, left.y + right.y, left.z + right.z)
end

function vector_meta.__sub(left, right)
    return vector3(left.x - right.x, left.y - right.y, left.z - right.z)
end

function vector_meta.__mul(left, right)
    if type(left) == "number" then
        left, right = right, left
    end
    return vector3(left.x * right, left.y * right, left.z * right)
end

function vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, vector_meta)
end

function RegisterNUICallback(name, callback)
    callbacks[name] = callback
end

function RegisterNetEvent() end
function AddEventHandler(name, callback)
    event_handlers[name] = callback
end
function TriggerEvent(name, data)
    triggered_events[#triggered_events + 1] = { name = name, data = data }
end
function TriggerServerEvent() end
function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end
function CreateThread(callback)
    threads[#threads + 1] = callback
end
function Wait()
    error(thread_stop, 0)
end
function PlayerPedId() return 7 end
function PlayerId() return 8 end
function GetFollowPedCamViewMode() return 1 end
function GetFollowVehicleCamViewMode() return 2 end
function IsRadarHidden() return false end
function DisplayRadar() end
function SetFollowPedCamViewMode() end
function SetFollowVehicleCamViewMode() end
function IsPedInAnyVehicle() return false end
function DisableControlAction(group, control, disabled)
    assert(group == 0 and disabled, "camera controls must be disabled in the primary input group")
    disabled_controls[control] = true
end
function DisablePlayerFiring() end
function HideHudAndRadarThisFrame() end
function GetCurrentResourceName() return "sky_phone" end
function IsDisabledControlJustPressed() return false end
function GetDisabledControlNormal(_, control) return disabled_control_normals[control] or 0.0 end

function GetEntityCoords()
    return vector3(10.0, 20.0, 1.0)
end

function GetPedBoneCoords()
    return vector3(10.0, 20.0, 2.7)
end

function GetEntityForwardVector()
    return vector3(0.0, 1.0, 0.0)
end

function CreateCam(name, active)
    assert(name == "DEFAULT_SCRIPTED_CAMERA" and active, "selfie camera must be created active")
    camera_created = true
    camera_destroyed = false
    return 73
end

function DoesCamExist(handle)
    return camera_created and not camera_destroyed and handle == 73
end

function SetCamFov() end
function SetCamActive() end

function RenderScriptCams(active)
    scripted_camera_rendering = active
end

function SetCamCoord(_, x, y, z)
    camera_coord = vector3(x, y, z)
end

function PointCamAtCoord(_, x, y, z)
    camera_target = vector3(x, y, z)
end

function DestroyCam(handle)
    assert(handle == 73, "the selfie camera handle must be destroyed")
    camera_destroyed = true
end

local function response_from(name, data)
    local response = nil
    callbacks[name](data, function(value)
        response = value
    end)
    return response
end

local function close_enough(actual, expected)
    return math.abs(actual - expected) < 0.0001
end

dofile("sky_phone/source/client/camera.lua")

assert(response_from("camera:setActive", { active = true }).success)
assert(response_from("camera:setFacing", { front = true }).success)
assert(camera_created and scripted_camera_rendering, "selfie mode must render a scripted camera")
assert(camera_coord and camera_target, "selfie mode must position and aim the camera")
assert(close_enough(camera_coord.x, 10.0))
assert(close_enough(camera_coord.y, 21.05))
assert(close_enough(camera_coord.z, 2.75))
assert(close_enough(camera_target.x, 10.0))
assert(close_enough(camera_target.y, 20.0))
assert(close_enough(camera_target.z, 2.73))

event_handlers["sky_phone:client:cameraFocusApplied"]({
    active = true,
    cursor = false,
    focused = true,
    gameInput = true,
})
assert(response_from("camera:setFocus", { focused = false }).success)
disabled_control_normals[1] = 0.2
local watcher_ok, watcher_error = pcall(threads[2])
assert(not watcher_ok and watcher_error == thread_stop, "camera watcher must run one controlled frame")
local camera_focus_event = triggered_events[#triggered_events]
assert(
    camera_focus_event.name == "sky_phone:client:setCameraFocus"
        and camera_focus_event.data.active
        and not camera_focus_event.data.nuiFocused,
    "holding Space must release the camera cursor for simultaneous look and movement"
)
assert(nui_messages[#nui_messages].data.looking, "the UI must learn that looking is active even while keyboard focus stays true")
for _, control in ipairs({ 30, 31, 32, 33, 34, 35 }) do
    assert(not disabled_controls[control], ("camera passthrough must preserve movement control %d"):format(control))
end
local camera_ok, camera_error = pcall(threads[1])
assert(not camera_ok and camera_error == thread_stop, "selfie camera must render one controlled frame")
assert(not close_enough(camera_coord.x, 10.0), "horizontal look input must orbit the selfie camera around the player")
assert(camera_coord.y < 21.05, "selfie orbit must retain its configured distance from the player")
disabled_control_normals[1] = 0.0

local function run_controls_frame()
    local ok, err = pcall(threads[2])
    assert(not ok and err == thread_stop, "camera controls must finish one controlled frame")
end

local function last_cursor_claim()
    for index = #triggered_events, 1, -1 do
        local event = triggered_events[index]
        if event.name == "sky_phone:client:setCameraFocus" then
            return event.data.nuiFocused
        end
    end
    error("expected a camera focus claim")
end

local stable_event_count = #triggered_events
run_controls_frame()
assert(#triggered_events == stable_event_count, "holding Space must keep its focus claim without per-frame churn")
assert(response_from("camera:setFocus", { focused = true }).success)
assert(last_cursor_claim(), "releasing Space must immediately restore the cursor")
run_controls_frame()
assert(last_cursor_claim(), "the control watcher must preserve the released Space state")

hold_to_look_pressed = true
run_controls_frame()
assert(not last_cursor_claim(), "the configured HoldToLook control must still release the cursor")
assert(response_from("camera:setFocus", { focused = false }).success)
hold_to_look_pressed = false
run_controls_frame()
assert(not last_cursor_claim(), "releasing the configured control must not cancel a held Space key")
hold_to_look_pressed = true
assert(response_from("camera:setFocus", { focused = true }).success)
assert(not last_cursor_claim(), "releasing Space must not cancel the configured control")
hold_to_look_pressed = false
run_controls_frame()
assert(last_cursor_claim(), "releasing both look inputs must restore the cursor")

assert(response_from("camera:setLocked", { locked = true }).success)
assert(response_from("camera:setFocus", { focused = false }).success)
hold_to_look_pressed = true
run_controls_frame()
assert(last_cursor_claim(), "a locked camera must reject both look input sources")
assert(response_from("camera:setFocus", { focused = true }).success)
hold_to_look_pressed = false
assert(response_from("camera:setLocked", { locked = false }).success)
assert(not response_from("camera:setFocus", { focused = "false" }).success, "malformed focus claims must be rejected")
assert(not response_from("camera:setFocus", {}).success, "missing focus values must be rejected")
assert(not response_from("camera:setFocus", false).success, "non-table focus requests must be rejected")

event_handlers["sky_phone:client:cameraFocusApplied"]({
    active = true,
    cursor = true,
    focused = true,
    gameInput = false,
})
assert(not nui_messages[#nui_messages].data.looking, "restoring the cursor must clear the UI look indicator")

assert(response_from("camera:setFacing", { front = false }).success)
assert(camera_destroyed and not scripted_camera_rendering, "rear mode must release the selfie camera")

assert(type(SkyPhoneCamera.EnableWalkable) == "function", "walkable camera enable seam must exist")
assert(type(SkyPhoneCamera.DisableWalkable) == "function", "walkable camera disable seam must exist")
assert(type(SkyPhoneCamera.SetSelfie) == "function", "selfie camera seam must exist")
assert(type(SkyPhoneCamera.ToggleFrozen) == "function", "frozen camera seam must exist")
assert(type(SkyPhoneCamera.SetFlashlight) == "function", "flashlight seam must exist")
assert(type(SkyPhoneCamera.GetState) == "function", "camera state seam must exist")

SkyPhoneCamera.SetFlashlight(true)
assert(SkyPhoneCamera.GetState().flashEnabled, "flashlight state must report enabled")
SkyPhoneCamera.SetFlashlight(false)
assert(not SkyPhoneCamera.GetState().flashEnabled, "flashlight state must report disabled")

SkyPhoneCamera.EnableWalkable(true)
stable_event_count = #triggered_events
assert(response_from("camera:setFocus", { focused = true }).success)
assert(#triggered_events == stable_event_count, "NUI key release must not steal focus from a walkable camera")
local walkable_state = SkyPhoneCamera.GetState()
assert(walkable_state.walkable, "walkable camera must report enabled")
assert(walkable_state.selfie, "walkable camera must preserve selfie mode")
assert(walkable_state.active, "walkable camera must open the camera")
SkyPhoneCamera.SetSelfie(false)
assert(not SkyPhoneCamera.GetState().selfie, "selfie camera must switch back to rear mode")
SkyPhoneCamera.ToggleFrozen()
SkyPhoneCamera.DisableWalkable()
local closed_state = SkyPhoneCamera.GetState()
assert(not closed_state.walkable, "walkable camera must report disabled")
assert(not closed_state.active, "walkable camera disable must close the camera")

assert(response_from("camera:setActive", { active = true }).success)
assert(response_from("camera:setFocus", { focused = false }).success)
assert(not last_cursor_claim())
assert(response_from("camera:setActive", { active = false }).success)
assert(response_from("camera:setActive", { active = true }).success)
run_controls_frame()
assert(last_cursor_claim(), "reopening the camera must discard the previous held Space state")
assert(response_from("camera:setActive", { active = false }).success)

print("Client camera tests passed")
