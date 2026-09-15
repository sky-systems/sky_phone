local net_events = {}
local nui_messages = {}
local focus_claim = false
local joined_channel = nil
local leave_count = 0
local callback_result = { success = true }
local callback_requests = {}

Bridge = {
    Calls = {
        Join = function(channel)
            joined_channel = channel
            return channel > 0
        end,
        Leave = function()
            leave_count = leave_count + 1
        end,
    },
    Callbacks = {
        Trigger = function(name, payload)
            callback_requests[#callback_requests + 1] = { name = name, payload = payload }
            if name == "sky_phone:calls:dial" then
                assert(payload.phoneNumber == "5550101" and payload.company == nil, "dial payload changed")
            else
                assert(payload.id == "call-1", "call actions must use the active authoritative call ID")
            end
            return callback_result
        end,
    },
    Debug = function() end,
}

SkyPhoneFocus = {
    SetCall = function(active)
        focus_claim = active
    end,
}

function RegisterNetEvent(name, callback)
    net_events[name] = callback
end

function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end

function TriggerEvent() end
function AddEventHandler(name, callback) net_events[name] = callback end

dofile("sky_phone/source/client/calls.lua")

local success, error_code = SkyPhoneCalls.Dial(nil, nil)
assert(not success and error_code == "invalid_request", "empty dial target must be rejected")
assert(SkyPhoneCalls.Dial("5550101"), "valid dial target must reach the server")
assert(SkyPhoneCalls.GetActive() == nil, "inactive calls must not expose a snapshot")
success, error_code = SkyPhoneCalls.Hangup()
assert(not success and error_code == "call_not_found", "hangup must reject missing calls locally")

net_events["sky_phone:call:incoming"]({
    id = "call-1",
    state = "ringing",
    direction = "incoming",
    otherNumber = "5550102",
    device = { imei = "imei-1", name = "Test Phone" },
})
assert(SkyPhoneCalls.IsActive() and focus_claim, "incoming call must become active and claim focus")
assert(nui_messages[#nui_messages].type == "call:incoming", "incoming call must reach NUI")

local snapshot = assert(SkyPhoneCalls.GetActive())
snapshot.state = "ended"
snapshot.device.name = "Mutated"
local fresh_snapshot = assert(SkyPhoneCalls.GetActive())
assert(fresh_snapshot.state == "ringing", "call snapshots must not mutate authoritative client state")
assert(fresh_snapshot.device.name == "Test Phone", "nested call snapshot state must also be isolated")

assert(SkyPhoneCalls.Answer(), "incoming ringing calls must be answerable through the server callback")
assert(callback_requests[#callback_requests].name == "sky_phone:calls:answer", "answer callback changed")
assert(SkyPhoneCalls.Decline(), "incoming ringing calls must be declineable through the server callback")
assert(callback_requests[#callback_requests].name == "sky_phone:calls:decline", "decline callback changed")

net_events["sky_phone:call:state"]({
    id = "call-1",
    state = "connected",
    direction = "incoming",
    channel = 42,
})
assert(joined_channel == 42 and not focus_claim, "connected call must join voice and release attention focus")
success, error_code = SkyPhoneCalls.Answer()
assert(not success and error_code == "call_not_found", "connected calls must not be answered twice")

callback_result = { success = false, error = "request_failed" }
success, error_code = SkyPhoneCalls.Hangup()
assert(not success and error_code == "request_failed", "call action failures must remain visible to adapters")
callback_result = { success = true }
assert(SkyPhoneCalls.Hangup(), "connected calls must use the authoritative hangup callback")
assert(callback_requests[#callback_requests].name == "sky_phone:calls:hangup", "hangup callback changed")

net_events["sky_phone:call:state"]({ id = "call-1", state = "ended" })
assert(not SkyPhoneCalls.IsActive() and leave_count == 1, "ended call must clear state and leave voice")

print("Client call runtime tests passed")

-- Exercise animation priorities with the real event handlers, without native rendering.
local animation_handlers = {}
function AddEventHandler(name, callback) animation_handlers[name] = callback end
function CreateThread() end
function PlayerPedId() return 1 end
function DoesEntityExist() return true end
function IsEntityDead() return false end
function IsPedRagdoll() return false end
function IsPedFalling() return false end
function IsPedClimbing() return false end
function IsPedSwimming() return false end
function IsPedSwimmingUnderWater() return false end
function IsPedInParachuteFreeFall() return false end
Config = { Animations = { Enabled = true } }
dofile("sky_phone/source/client/animations.lua")
local function upvalue(fn, key)
    for i = 1, 50 do
        local name, value = debug.getupvalue(fn, i)
        if name == key then return value end
    end
    error("Missing animation upvalue " .. key)
end
local mode = upvalue(upvalue(animation_handlers["sky_phone:animation:call"], "reevaluate"), "derive_mode")
local function call_animation(state, video)
    animation_handlers["sky_phone:animation:call"]({ state = state, direction = "outgoing", video = video })
end
animation_handlers["sky_phone:animation:phone"](true)
assert(mode() == "phone_read")
call_animation("ringing", false); assert(mode() == "call")
call_animation("ringing", true); assert(mode() == "phone_read", "Outgoing FaceTime must use the phone-open pose")
call_animation("connected", true)
animation_handlers["sky_phone:animation:camera"]({ active = true, front = true })
assert(mode() == "phone_read", "Selfie camera events must not override the FaceTime pose")
call_animation("connected", false); assert(mode() == "call", "Returning to audio restores the call pose")
animation_handlers["sky_phone:animation:camera"]({ active = false })
call_animation("completed", false); assert(mode() == "phone_read")
print("FaceTime animation priority tests passed")

local animation_state = upvalue(mode, "animation_state")
local ik = {}
local vector = {}
vector.__index = vector
vector.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, vector) end
vector.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vector) end
vector.__mul = function(a, scale) return setmetatable({ x = a.x * scale, y = a.y * scale, z = a.z * scale }, vector) end
local function vec(x,y,z) return setmetatable({ x=x, y=y, z=z },vector) end
function GetPedBoneCoords() return vec(0, 0, 1.7) end
local ik_enabled = {}
function SetPedCanArmIk(ped, enabled)
    assert(ped == 1 and enabled)
    ik_enabled.arm = enabled
end
function SetPedCanHeadIk(ped, enabled)
    assert(ped == 1 and enabled)
    ik_enabled.head = enabled
end
function SetIkTarget(ped, part, entity, bone, x, y, z, flags, blend_in, blend_out)
    assert(ped == 1 and entity == 0 and bone == -1)
    assert(blend_in == 0 and blend_out == 150, "Camera IK must follow the current frame without a second blend-in")
    if part == 1 then
        assert(ik_enabled.head and flags == 0, "Head IK must be enabled and use head-compatible flags")
    else
        assert(ik_enabled.arm and flags == 1, "Hand IK must not depend on the phone clip's IK allow-tags")
    end
    assert(type(x) == "number" and type(y) == "number" and type(z) == "number")
    ik[part] = { x=x, y=y, z=z }
end
animation_state.ped, animation_state.prop, animation_state.camera_active = 1, 1, true
Config.Animations.PropBone = 28422
SkyPhoneAnimations.AimCamera(vec(0, 1, 1.7), vec(0, 0, 1.7), true)
assert(ik[4] and ik[1] and math.abs(ik[4].y - 0.52) < 0.001)
SkyPhoneAnimations.AimCamera(vec(1, 0, 1.7), vec(0, 0, 1.7), true)
assert(ik[4].x > 0.5 and ik[4].y == 0, "Hand must follow camera direction instead of holding a static pose")
Config.Animations.PropBone = 18905
ik = {}
SkyPhoneAnimations.AimCamera(vec(-1, 0, 2.2), vec(0, 0, 1.7), true)
assert(ik[3] and not ik[4] and ik[3].z > 1.56, "Custom left-hand props must use the left arm and follow vertical look")
animation_state.camera_active = false
ik, ik_enabled = {}, {}
SkyPhoneAnimations.AimCamera(vec(1, 0, 1.7), vec(0, 0, 1.7), true)
assert(not next(ik) and not next(ik_enabled), "Camera IK must stop immediately when the camera closes")
print("PASS camera arm IK: camera direction, bounded reach and cleanup")
