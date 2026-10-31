-- Direct net events do not pass through the app callback dispatcher.
local enabled = { health = true, memos = true }
local events, callbacks, sent, queries, timeouts = {}, {}, {}, {}, {}
local rate_calls, provider_calls, delete_calls = 0, 0, 0
local request_ids = { "550e8400-e29b-41d4-a716-446655440001", "550e8400-e29b-41d4-a716-446655440002" }
local environment = setmetatable({
    source = 7,
    Config = {
        Health = { ReportsPerMinute = 5, ReportIntervalSeconds = 30, MaximumSpeedMetersPerSecond = 12 },
        Memos = { UploadsPerMinute = 5, MaximumWaveformSamples = 64, TitleMaxLength = 64, NoteMaxLength = 300,
            MaximumDurationMs = 60000, MaximumBytes = 1000000, MaximumCount = 20,
            MaximumPendingUploads = 5, UploadSessionTimeoutMs = 60000 },
        Media = { FiveManage = { UploadTimeoutMs = 30000 } },
    },
    SkyPhoneAppDatabase = {
        Enabled = function(app) return enabled[app] ~= false end,
        Bind = function() return function(start) start() end end,
    },
    SkyPhone = {
        AllowOperation = function() rate_calls = rate_calls + 1 return true end,
        FindDeviceSlots = function() return { {} } end,
        LoadDevice = function() return { account_id = 1 } end,
    },
    SkyPhoneImei = { IsValid = function(value) return value == "490154203237518" end },
    SkyPhoneMedia = {
        RequestPresignedUrl = function() provider_calls = provider_calls + 1 return "https://example.invalid/upload" end,
        DeleteRemoteFile = function() delete_calls = delete_calls + 1 return true end,
    },
    Bridge = {
        Debug = function() end,
        Framework = { GetIdentifier = function() return "test-character" end },
        Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        Database = { Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("COUNT(*)", 1, true) then return { { count = 0 } } end
            if sql:find("SELECT UUID()", 1, true) then return { { request_id = request_ids[provider_calls] } } end
            return 1
        end },
    },
    RegisterNetEvent = function(name, callback) events[name] = callback end,
    AddEventHandler = function() end,
    SetTimeout = function(_, callback) timeouts[#timeouts + 1] = callback end,
    TriggerClientEvent = function(name, target, data) sent[#sent + 1] = { name = name, target = target, data = data } end,
}, { __index = _G })

assert(loadfile("sky_phone/source/server/health.lua", "t", environment))()
local record = assert(events["sky_phone:health:record-activity"])
record({ steps = 1, distanceMeters = 1, activeSeconds = 1 })
assert(#queries == 1 and rate_calls == 1)
enabled.health = false
record({ steps = 1, distanceMeters = 1, activeSeconds = 1 })
record(nil)
assert(#queries == 1 and rate_calls == 1, "Disabled Health must reject direct reports before rate/SQL work")
enabled.health = true
record({ steps = 1, distanceMeters = 1, activeSeconds = 1 })
assert(#queries == 2 and rate_calls == 2, "Health reports must resume after re-enabling")

assert(loadfile("sky_phone/source/server/memos.lua", "t", environment))()
local upload = assert(events["sky_phone:memos:request-upload"])
local function request(correlation)
    upload({ correlationId = correlation, deviceImei = "490154203237518", title = "Voice note", note = "",
        durationMs = 1000, sizeBytes = 1000, mimeType = "audio/ogg", pinned = false,
        waveform = { 0, 0, 0, 0, 0, 0, 0, 0 } })
end
request("before-disable-a")
request("before-disable-b")
assert(provider_calls == 2 and sent[#sent].name == "sky_phone:memos:upload-ready")
local before_queries, before_rate = #queries, rate_calls
enabled.memos = false
request("disabled")
assert(#queries == before_queries and rate_calls == before_rate and provider_calls == 2,
    "Disabled Memos must reject new direct uploads before SQL/provider work")
assert(sent[#sent].data.error == "app_disabled" and sent[#sent].data.correlationId == "disabled")
events["sky_phone:memos:cancel-upload"]({ requestId = request_ids[1] })
assert(sent[#sent].data.error == "cancelled" and sent[#sent].data.correlationId == "before-disable-a",
    "Disabling Memos must not block cancellation of an accepted upload")
events["sky_phone:memos:fail-upload"]({ requestId = request_ids[2], error = "upload_timeout" })
assert(sent[#sent].data.error == "upload_timeout" and sent[#sent].data.correlationId == "before-disable-b")
local terminal_events = #sent
for _, timeout in ipairs(timeouts) do timeout() end
assert(#sent == terminal_events and delete_calls == 0, "Cancelled/failed uploads must be terminal without unrelated remote cleanup")
print("Disabled app direct-event guards preserve Health resumption and Memos in-flight cleanup")
