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
local disabled_pressed_controls = {}
local disabled_control_normals = {}
local triggered_events = {}
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
function SendNUIMessage() end
function CreateThread(callback)
    threads[#threads + 1] = callback
end
function Wait()
    error(thread_stop, 0)
end
function PlayerPedId() return 7 end
function PlayerId() return 8 end
function GetFrameTime() return 1.0 / 60.0 end
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
function IsDisabledControlPressed(group, control)
    assert(group == 0, "camera passthrough must read the primary input group")
    return disabled_pressed_controls[control] == true
end
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
disabled_pressed_controls[22] = true
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
for _, control in ipairs({ 30, 31, 32, 33, 34, 35 }) do
    assert(not disabled_controls[control], ("camera passthrough must preserve movement control %d"):format(control))
end
local camera_ok, camera_error = pcall(threads[1])
assert(not camera_ok and camera_error == thread_stop, "selfie camera must render one controlled frame")
assert(not close_enough(camera_coord.x, 10.0), "horizontal look input must orbit the selfie camera around the player")
assert(camera_coord.y < 21.05, "selfie orbit must retain its configured distance from the player")
disabled_pressed_controls[22] = false
disabled_control_normals[1] = 0.0

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

print("Client camera tests passed")

-- Run the real camera and animation handlers together. Native spies validate the
-- submitted pose; only a FiveM session can validate the engine's rendered bones.
threads = {}
function CreateThread(callback)
    threads[#threads + 1] = coroutine.create(callback)
end
function Wait() coroutine.yield() end
local record_event = TriggerEvent
function TriggerEvent(name, data)
    record_event(name, data)
    if event_handlers[name] then event_handlers[name](data) end
end

local prop_exists = false
local ragdoll = false
local played_clip = nil
local hand_targets = {}
local arm_enabled = false
local head_enabled = false
Bridge = { Debug = function(_, message) error(message) end }
Config = { Animations = {
    Enabled = true, PropModel = "prop_npc_phone_02", PropBone = 28422,
    LoadTimeoutMs = 5000, ContextPollMs = 250,
    Dictionaries = { OnFoot = "cellphone@", Camera = "cellphone@self" },
    Clips = {
        TextIn = "cellphone_text_in", TextRead = "cellphone_text_read_base",
        TextOut = "cellphone_text_out", CallListen = "cellphone_call_listen_base",
        TextToCall = "cellphone_text_to_call", CallToText = "cellphone_call_to_text",
        CallOut = "cellphone_call_out", Camera = "selfie",
    },
    Transforms = { Portrait = { position = vector3(0, 0, 0), rotation = vector3(0, 0, 0) } },
} }
function DoesEntityExist(entity) return entity == 7 or (entity == 99 and prop_exists) end
function IsEntityDead() return false end
function IsPedRagdoll() return ragdoll end
function IsPedFalling() return false end
function IsPedClimbing() return false end
function IsPedSwimming() return false end
function IsPedSwimmingUnderWater() return false end
function IsPedInParachuteFreeFall() return false end
function joaat(value) return value end
function RequestModel() end
function HasModelLoaded() return true end
function SetModelAsNoLongerNeeded() end
function GetGameTimer() return 0 end
function CreateObject() prop_exists = true; return 99 end
function SetEntityCollision() end
function GetPedBoneIndex(_, bone) return bone end
function AttachEntityToEntity(prop, ped, bone)
    assert(prop == 99 and ped == 7 and bone == Config.Animations.PropBone,
        "The phone must remain attached to the configured hand")
end
function RequestAnimDict() end
function HasAnimDictLoaded() return true end
function GetAnimDuration() return 0.5 end
function TaskPlayAnim(_, _, clip) played_clip = clip end
function StopAnimTask() played_clip = nil end
function DetachEntity() end
function SetEntityAsMissionEntity() end
function DeleteEntity() prop_exists = false end
function GetGameplayCamCoord() return vector3(10, 20, 2.7) end
function GetGameplayCamRot() return vector3(15, 0, 30) end
function SetPedCanArmIk(ped, enabled)
    assert(ped == 7 and enabled)
    arm_enabled = true
end
function SetPedCanHeadIk(ped, enabled)
    assert(ped == 7 and enabled)
    head_enabled = true
end
function SetIkTarget(_, part, _, _, x, y, z)
    if part == 1 then
        assert(head_enabled, "Selfie head tracking must enable head IK")
    else
        assert(arm_enabled, "A moving camera must enable arm IK before submitting the hand target")
        hand_targets[part] = vector3(x, y, z)
    end
end

local function frame()
    hand_targets, arm_enabled, head_enabled = {}, false, false
    local count = #threads
    for i = 1, count do
        if coroutine.status(threads[i]) ~= "dead" then
            local ok, err = coroutine.resume(threads[i])
            assert(ok, err)
        end
    end
end
local function frames(count)
    for _ = 1, count do frame() end
end
local function assert_hand_follows_selfie()
    local hand = assert(hand_targets[4], "An active FaceTime camera must update the holding arm every frame")
    local direction = camera_coord - camera_target
    local length = math.sqrt(direction.x ^ 2 + direction.y ^ 2 + direction.z ^ 2)
    local expected = GetPedBoneCoords() + direction * (0.52 / length) - vector3(0, 0, 0.14)
    assert(close_enough(hand.x, expected.x) and close_enough(hand.y, expected.y)
        and close_enough(hand.z, expected.z), "The hand must track the rendered camera, including its orbit smoothing")
    return hand
end

dofile("sky_phone/source/client/animations.lua")
dofile("sky_phone/source/client/camera.lua")
TriggerEvent("sky_phone:animation:phone", true)
TriggerEvent("sky_phone:animation:call", { state = "connected", direction = "outgoing", video = true })
frames(4)
assert(played_clip == "cellphone_text_read_base", "FaceTime must preserve the requested phone-open base pose")
assert(response_from("camera:setActive", { active = true }).success)
assert(response_from("camera:setFacing", { front = true }).success)
TriggerEvent("sky_phone:client:cameraFocusApplied", { active = true, cursor = false, focused = true, gameInput = true })
frames(4)
local initial_hand = assert_hand_follows_selfie()
assert(played_clip == "cellphone_text_read_base", "Camera tracking must overlay the phone pose")

disabled_control_normals[1], disabled_control_normals[2] = 0.5, -0.5
frames(8)
local raised_hand = assert_hand_follows_selfie()
assert(raised_hand.x > initial_hand.x and raised_hand.z > initial_hand.z,
    "Turning and raising the camera must also move the holding arm horizontally and vertically")
disabled_control_normals[1], disabled_control_normals[2] = -0.5, 0.5
frames(16)
local lowered_hand = assert_hand_follows_selfie()
assert(lowered_hand.x < raised_hand.x and lowered_hand.z < raised_hand.z,
    "The arm must follow both directions, not remain at the previous camera target")
disabled_control_normals[1], disabled_control_normals[2] = 0, 0
frame()
assert_hand_follows_selfie() -- Native targets expire after one update, even with no new mouse input.

ragdoll = true
frame()
assert(not next(hand_targets) and not arm_enabled, "Unavailable peds must not receive camera arm overrides")
ragdoll = false
frames(4)
assert_hand_follows_selfie()
assert(response_from("camera:setFacing", { front = false }).success)
frames(2)
assert(hand_targets[4] and not head_enabled, "Rear video must follow camera aim without selfie head tracking")
assert(response_from("camera:setActive", { active = false }).success)
frames(2)
assert(not next(hand_targets) and not arm_enabled, "Closing video must release the arm while the call remains active")
TriggerEvent("sky_phone:animation:reset")
frames(2)
assert(not prop_exists and not next(hand_targets), "Reset must release the phone prop and arm tracking")
print("PASS FaceTime camera/animation integration: base pose, both axes, continuous targets, facing and cleanup")
