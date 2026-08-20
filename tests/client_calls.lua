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
