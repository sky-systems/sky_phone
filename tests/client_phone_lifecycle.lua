local function new_client()
    local net_events, nui_callbacks, messages = {}, {}, {}
    local focused = false
    local threads, timers, logs = {}, {}, {}
    local client = { events = net_events, messages = messages, tone_requests = 0, timers = timers, logs = logs,
        tone_response = { success = true, data = { ringtones = {}, notificationSounds = {} } } }
    local noop = function() end
    local locale = { Controls = {}, DeviceErrors = { default = "Phone unavailable" }, Nui = {} }

    Config = {
        Bridge = { Locale = "en" },
        Phone = { Keybind = false, DevelopmentCommand = false },
        TestData = { Enabled = false },
        AdminPanel = { Enabled = false },
    }
    Locales = { en = locale }
    SkyPhoneLocales = { Resolve = function() return locale, "en" end }
    Bridge = {
        Debug = function(level, message, ...)
            if level == "warn" or level == "error" then logs[#logs + 1] = message:format(...) end
        end,
        Framework = { Notify = noop },
        Callbacks = {
            Trigger = function(name)
                if name == "sky_phone:device:open-request" then
                    return coroutine.yield("awaiting_inventory")
                end
                if name == "sky_phone:tones:list" then
                    client.tone_requests = client.tone_requests + 1
                    if client.block_tones then return coroutine.yield("awaiting_tones") end
                    return client.tone_response
                end
                return { success = true, data = {} }
            end,
        },
    }
    SkyPhoneApps = { SendCatalog = noop, SetPhoneOpen = noop }
    SkyPhoneCalls = { IsActive = function() return false end, ReplayNui = noop, Reset = noop }
    SkyPhoneSimPicker = { ReplayNui = noop, Reset = noop }
    SkyPhoneFocus = {
        SetPhone = function(value) focused = value end,
        BeginNuiHydration = noop,
        Reapply = noop,
        Reset = noop,
    }
    RegisterNetEvent = function(name, callback) net_events[name] = callback end
    RegisterNUICallback = function(name, callback) nui_callbacks[name] = callback end
    SendNUIMessage = function(message) messages[#messages + 1] = message end
    RegisterCommand, RegisterKeyMapping, TriggerEvent = noop, noop, noop
    AddEventHandler = RegisterNetEvent
    GetCurrentResourceName = function() return "sky_phone" end
    CreateThread = function(callback) threads[#threads + 1] = coroutine.create(callback) end
    SetTimeout = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end

    dofile("sky_phone/source/client/main.lua")

    function client.run_threads()
        while #threads > 0 do
            local thread = table.remove(threads, 1)
            local success, state = coroutine.resume(thread)
            assert(success, state)
            if state == "awaiting_tones" then client.pending_tones = thread end
        end
    end
    function client.fire_timer()
        local timer = assert(table.remove(timers, 1))
        timer.callback()
        client.run_threads()
    end
    function client.nui(name, data)
        local response
        nui_callbacks[name](data or {}, function(result) response = result end)
        assert(response, "NUI callbacks must always respond")
        return response
    end
    function client.take_messages(message_type)
        local found = {}
        for index = #messages, 1, -1 do
            if messages[index].type == message_type then
                found[#found + 1] = table.remove(messages, index)
            end
        end
        return found
    end
    function client.authorize(payload)
        net_events["sky_phone:device:open"](payload)
        assert(client.nui("ui:opened").success)
        assert(SkyPhoneClient.GetState().open and focused)
        client.take_messages("app:open")
    end
    return client
end

local function device(token, number)
    return {
        token = token,
        device = {
            imei = "356938035643809",
            sim = { number = number or "5551234567" },
        },
    }
end

local failures = 0
local function test(name, callback)
    local success, message = pcall(callback)
    if success then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(message))
    end
end

test("late device updates cannot revive a closed phone", function()
    local client = new_client()
    client.authorize(device("old-session"))
    SkyPhoneClient.Toggle(false)
    client.events["sky_phone:device:updated"](device("old-session"))
    assert(#client.take_messages("device:updated") == 0, "closed phones must not forward stale hydration")
    assert(not SkyPhoneClient.GetState().open)
end)

test("late updates cannot restore an invalidated device", function()
    local client = new_client()
    client.authorize(device("removed-device"))
    client.events["sky_phone:device:invalidated"]()
    client.events["sky_phone:device:updated"](device("removed-device"))
    assert(#client.take_messages("device:updated") == 0, "invalidated device updates must be discarded")
    assert(SkyPhoneClient.GetState().phoneNumber == nil)
end)

test("a previous session cannot overwrite the active phone", function()
    local client = new_client()
    client.authorize(device("new-session"))
    client.events["sky_phone:device:updated"](device("old-session", "5559999999"))
    assert(#client.take_messages("device:updated") == 0, "updates must belong to the current session")
    assert(SkyPhoneClient.GetState().phoneNumber == "5551234567")
end)

test("NUI reload waits for inventory authorization instead of replaying the last phone", function()
    local client = new_client()
    client.authorize(device("old-session"))
    SkyPhoneClient.Toggle(false)
    local request = coroutine.create(function() return SkyPhoneClient.Toggle(true) end)
    local resumed, state = coroutine.resume(request)
    assert(resumed and state == "awaiting_inventory")
    assert(client.nui("ui:ready", { protocolVersion = 1 }).success)
    assert(#client.take_messages("app:open") == 0, "pending inventory checks must not authorize cached devices")
    assert(not client.nui("ui:opened").success, "NUI cannot confirm an unauthorized opening")
    client.events["sky_phone:device:error"]("phone_required")
    local completed, opened = coroutine.resume(request, { success = false, error = "phone_required" })
    assert(completed and opened == false)
    assert(not SkyPhoneClient.GetState().open)
end)

test("authorized opens survive a NUI reload before the first confirmation", function()
    local client = new_client()
    client.events["sky_phone:device:open"](device("valid-session"))
    client.take_messages("app:open")
    assert(client.nui("ui:ready", { protocolVersion = 1 }).success)
    assert(#client.take_messages("app:open") == 1)
    assert(client.nui("ui:opened").success)
    assert(SkyPhoneClient.GetState().open)
end)

test("current device updates and server-authorized device switching still work", function()
    local client = new_client()
    client.authorize(device("valid-session"))
    client.events["sky_phone:device:updated"](device("valid-session", "5552222222"))
    assert(#client.take_messages("device:updated") == 1)
    assert(SkyPhoneClient.GetState().phoneNumber == "5552222222")
    client.events["sky_phone:device:open"](device("next-session", "5553333333"))
    assert(#client.take_messages("device:updated") == 1)
    assert(SkyPhoneClient.GetState().phoneNumber == "5553333333")
end)

test("tone loading never blocks NUI readiness and coalesces concurrent refreshes", function()
    local client = new_client()
    client.block_tones = true
    assert(client.nui("ui:ready", { protocolVersion = 1 }).success)
    assert(client.tone_requests == 0, "NUI must reply before starting the server request")
    client.run_threads()
    assert(client.pending_tones and client.tone_requests == 1)
    client.events["sky_phone:tones:changed"]()
    client.events["sky_phone:tones:changed"]()
    client.run_threads()
    assert(client.tone_requests == 1, "only one catalog request may be in flight")
    client.block_tones = false
    assert(coroutine.resume(client.pending_tones, { success = true, data = { old = true } }))
    assert(#client.take_messages("phone:tones") == 0, "superseded catalogs must not reach NUI")
    client.run_threads()
    local catalogs = client.take_messages("phone:tones")
    assert(client.tone_requests == 2 and #catalogs == 1 and catalogs[1].data == client.tone_response.data)
end)

test("tone catalog retries startup failures without duplicate requests or warning spam", function()
    local client = new_client()
    client.tone_response = { success = false, error = "server_initializing" }
    client.nui("ui:ready", { protocolVersion = 1 })
    client.run_threads()
    assert(#client.timers == 1 and client.timers[1].delay == 5000 and #client.logs == 0)
    client.events["sky_phone:tones:changed"]()
    client.nui("ui:ready", { protocolVersion = 1 })
    client.run_threads()
    assert(client.tone_requests == 1 and #client.timers == 1)
    client.fire_timer()
    assert(client.tone_requests == 2 and #client.logs == 0 and #client.timers == 1)
    client.tone_response = { success = true, data = { ringtones = {}, notificationSounds = {} } }
    client.fire_timer()
    assert(client.tone_requests == 3 and #client.take_messages("phone:tones") == 1 and #client.timers == 0)
end)

test("tone retries handle timeouts, malformed responses and rate limits", function()
    local client = new_client()
    client.tone_response = nil
    client.nui("ui:ready", { protocolVersion = 1 })
    client.run_threads()
    assert(client.logs[1]:find("request_failed", 1, true) and client.timers[1].delay == 5000)
    client.tone_response = { success = true, data = "invalid" }
    client.fire_timer()
    assert(client.logs[2]:find("invalid_response", 1, true) and #client.take_messages("phone:tones") == 0)
    client.tone_response = { success = false, error = "rate_limited" }
    client.fire_timer()
    assert(client.timers[1].delay == 60000)
end)

test("resource stop cancels pending catalog retries and discards in-flight results", function()
    local client = new_client()
    client.tone_response = nil
    client.nui("ui:ready", { protocolVersion = 1 })
    client.run_threads()
    client.events.onResourceStop("sky_phone")
    client.fire_timer()
    assert(client.tone_requests == 1 and #client.take_messages("phone:tones") == 0 and #client.timers == 0)

    client = new_client()
    client.block_tones = true
    client.nui("ui:ready", { protocolVersion = 1 })
    client.run_threads()
    client.events.onResourceStop("sky_phone")
    assert(coroutine.resume(client.pending_tones, client.tone_response))
    assert(#client.take_messages("phone:tones") == 0 and #client.timers == 0)
end)

assert(failures == 0, ("%s phone lifecycle tests failed"):format(failures))
