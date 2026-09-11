local function new_client()
    local net_events, nui_callbacks, messages = {}, {}, {}
    local focused = false
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
        Debug = noop,
        Framework = { Notify = noop },
        Callbacks = {
            Trigger = function(name)
                if name == "sky_phone:device:open-request" then
                    return coroutine.yield("awaiting_inventory")
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
    RegisterCommand, RegisterKeyMapping, AddEventHandler, TriggerEvent, CreateThread = noop, noop, noop, noop, noop

    dofile("sky_phone/source/client/main.lua")

    local client = { events = net_events, messages = messages }
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

assert(failures == 0, ("%s phone lifecycle tests failed"):format(failures))
