local registered_callbacks = {}
local migration_callback = nil
local client_events = {}
local transactions = {}
local stopped_calls = {}
local speaker_enabled = true

Bridge = {
    Callbacks = {
        Register = function(name, callback)
            assert(type(name) == "string" and type(callback) == "function")
            registered_callbacks[name] = callback
        end,
    },
    Calls = {
        IsAvailable = function()
            return true
        end,
        SetMuted = function()
            return true
        end,
        SetSpeaker = function()
            return true
        end,
        Start = function()
            return true, "yaca"
        end,
        Stop = function(call_id, sources, provider)
            stopped_calls[#stopped_calls + 1] = {
                callId = call_id,
                provider = provider,
                sources = sources,
            }
        end,
        SupportsMute = function()
            return false
        end,
        SupportsSpeaker = function()
            return false
        end,
    },
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            migration_callback = callback
        end,
        Query = function()
            return {}
        end,
        Transaction = function(operations)
            transactions[#transactions + 1] = operations
            return true
        end,
    },
    Debug = function()
    end,
    Framework = {
        GetPlayers = function()
            return {}
        end,
    },
    Speaker = {
        IsEnabled = function()
            return speaker_enabled
        end,
    },
}

Config = {
    Calls = {
        RecentPageSize = 50,
        RingSeconds = 30,
    },
    Companies = {
        CallRouting = {
            MaxAttempts = 1,
            RingSeconds = 30,
        },
    },
    Mail = {
        Domain = "test.local",
        LocalPartMaxLength = 32,
        LocalPartMinLength = 3,
    },
    Payphones = {
        Animation = {
            HangupDurationMs = 2000,
        },
    },
    Sim = {
        NumberLength = 7,
        NumberPrefix = "",
    },
}

SkyPhone = {}
SkyPhoneCompanies = {}
SkyPhoneSimNumber = {}

json = {
    decode = function()
        return {}
    end,
}

function AddEventHandler()
end

function CreateThread()
end

function GetCurrentResourceName()
    return "sky_phone"
end

function SetTimeout()
end

function TriggerClientEvent(name, target, payload)
    client_events[#client_events + 1] = {
        name = name,
        payload = payload,
        target = target,
    }
end

assert(loadfile("sky_phone/source/server/calls.lua"))()
assert(type(migration_callback) == "function", "calls module must wait for its migration")
migration_callback()

local function find_upvalue(callback, expected_name)
    for index = 1, 100 do
        local name, value = debug.getupvalue(callback, index)
        if not name then
            break
        end
        if name == expected_name then
            return value
        end
    end
    error("missing upvalue: " .. expected_name)
end

local active_lookup = find_upvalue(SkyPhoneCalls.GetForSource, "active_call_for_source")
local active_by_source = find_upvalue(active_lookup, "active_by_source")
local calls = find_upvalue(active_lookup, "calls")

local function seed_call(call)
    calls[call.id] = call
    active_by_source[call.caller_source] = call.id
    active_by_source[call.callee_source] = call.id
end

local call = {
    id = "550e8400-e29b-41d4-a716-446655440000",
    caller_number = "5550101",
    caller_source = 10,
    callee_number = "5550102",
    callee_source = 20,
    muted = {},
    speakers = {},
    started_at = 1000,
}
seed_call(call)

assert(SkyPhoneCalls.IsActiveForSource(10), "caller must be active while ringing")
assert(SkyPhoneCalls.IsActiveForSource(20), "callee must be active while ringing")
assert(not SkyPhoneCalls.IsActiveForSource("10"), "numeric strings must not be coerced into player sources")
assert(not SkyPhoneCalls.IsActiveForSource(10.5), "fractional player sources must be rejected")

local invalid_call, invalid_error = SkyPhoneCalls.GetForSource("10")
assert(invalid_call == nil and invalid_error == "invalid_source", "invalid source lookups must be explicit")

local caller_state = assert(SkyPhoneCalls.GetForSource(10))
assert(type(caller_state.id) == "string", "Sky call UUIDs must stay strings")
assert(caller_state.id == call.id and caller_state.state == "ringing", "ringing call state changed")
assert(caller_state.direction == "outgoing" and caller_state.otherNumber == "5550102", "caller view changed")
assert(caller_state.channel == nil, "ringing calls must not expose a voice channel")
assert(caller_state.caller.source == 10 and caller_state.caller.number == "5550101", "caller identity changed")
assert(caller_state.callee.source == 20 and caller_state.callee.number == "5550102", "callee identity changed")
assert(not caller_state.anonymous and not caller_state.video, "unsupported call modes must remain explicit")
assert(not caller_state.payphone and caller_state.companyId == nil, "ordinary call classification changed")

caller_state.state = "ended"
assert(SkyPhoneCalls.GetForSource(10).state == "ringing", "call lookups must return isolated snapshots")

local callee_state = assert(SkyPhoneCalls.GetForSource(20))
assert(callee_state.direction == "incoming" and callee_state.otherNumber == "5550101", "callee view changed")

local by_id_state = assert(SkyPhoneCalls.GetById(call.id))
assert(by_id_state.id == call.id and by_id_state.direction == "outgoing", "ID lookup must use a caller view")
by_id_state.caller.number = "changed"
assert(SkyPhoneCalls.GetById(call.id).caller.number == "5550101", "ID lookups must be isolated")
local invalid_id_call, invalid_id_error = SkyPhoneCalls.GetById("not-a-uuid")
assert(invalid_id_call == nil and invalid_id_error == "invalid_call_id", "invalid call IDs must be rejected")

call.answered_at = 1010
call.channel = 42
call.muted[10] = true
call.speakers[10] = true
call.voice_provider = "yaca"
call.voice_started = true

caller_state = assert(SkyPhoneCalls.GetForSource(10))
assert(caller_state.state == "connected" and caller_state.channel == 42, "connected call state changed")
assert(caller_state.muted and caller_state.muteSupported, "muted state must be projected for the caller")
assert(caller_state.speakerEnabled and caller_state.speakerSupported, "speaker state must be projected for the caller")

local ended, end_error = SkyPhoneCalls.EndForSource(0)
assert(not ended and end_error == "invalid_source", "invalid termination sources must be rejected")
assert(SkyPhoneCalls.EndForSource(10), "authoritative source termination must end the call")
assert(not SkyPhoneCalls.IsActiveForSource(10) and not SkyPhoneCalls.IsActiveForSource(20), "termination must clear participants")
assert(calls[call.id] == nil, "termination must remove the authoritative call")
local ended_id_call, ended_id_error = SkyPhoneCalls.GetById(call.id)
assert(ended_id_call == nil and ended_id_error == "call_not_found", "ended calls must not remain addressable")
assert(#stopped_calls == 1 and stopped_calls[1].callId == call.id, "termination must stop the voice backend")
assert(#transactions == 1, "termination must persist the completed call lifecycle")
assert(transactions[1][1].params[1] == "completed", "answered calls must remain completed")
assert(#client_events == 2, "both participants must receive the terminal state")
assert(client_events[1].payload.channel == nil and client_events[2].payload.channel == nil, "terminal states must drop the voice channel")

ended, end_error = SkyPhoneCalls.EndForSource(10)
assert(not ended and end_error == "call_not_found", "finished calls must not be ended twice")

local callback_call = {
    id = "550e8400-e29b-41d4-a716-446655440001",
    caller_number = "5550103",
    caller_source = 30,
    callee_number = "5550104",
    callee_source = 40,
    muted = {},
    speakers = {},
    started_at = 1100,
}
seed_call(callback_call)

local hangup_response = registered_callbacks["sky_phone:calls:hangup"](30, { id = callback_call.id })
assert(hangup_response.success, "the existing NUI hangup callback must retain its behavior")
assert(transactions[2][1].params[1] == "cancelled", "unanswered caller hangups must remain cancelled")
assert(transactions[2][3].params[1] == "missed", "unanswered callees must retain their missed status")

local company_call = {
    id = "550e8400-e29b-41d4-a716-446655440002",
    caller_number = "5550105",
    caller_source = 50,
    callee_number = "911",
    callee_source = 60,
    company_service_call = true,
    muted = {},
    speakers = {},
    started_at = 1200,
}
seed_call(company_call)
assert(SkyPhoneCalls.TerminateForSource(60), "provider termination must end a routed company call")
assert(calls[company_call.id] == nil, "forced company-call termination must remove the call")
assert(not SkyPhoneCalls.IsActiveForSource(50) and not SkyPhoneCalls.IsActiveForSource(60),
    "forced company-call termination must clear both participants")
assert(transactions[3][1].params[1] == "cancelled",
    "forced unanswered company calls must remain cancelled")

local provider_call = {
    id = "550e8400-e29b-41d4-a716-446655440003",
    caller_number = "5550106",
    caller_source = 70,
    callee_number = "911",
    callee_source = 80,
    company_service_call = true,
    muted = {},
    speakers = {},
    started_at = 1300,
}
seed_call(provider_call)
local terminate_response = registered_callbacks["sky_phone:calls:terminate"](
    80,
    { id = provider_call.id }
)
assert(terminate_response.success, "provider termination callback must end the participant's call")
assert(calls[provider_call.id] == nil, "provider termination callback must bypass company rerouting")
assert(not SkyPhoneCalls.IsActiveForSource(70) and not SkyPhoneCalls.IsActiveForSource(80),
    "provider termination callback must clear both participants")
local spoofed_terminate = registered_callbacks["sky_phone:calls:terminate"](
    70,
    { id = "550e8400-e29b-41d4-a716-446655440099" }
)
assert(not spoofed_terminate.success and spoofed_terminate.error == "call_not_found",
    "provider termination must revalidate the participant and call ID")

print("Server call seam tests passed")
