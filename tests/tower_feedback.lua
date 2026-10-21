-- Lua 5.4: execute the real standalone bridges with a cooperative frame clock.
local root = "sky_phone/source/bridge/client/"
local function runtime(started, version)
    local env = setmetatable({}, { __index = _G })
    local now, threads, events, calls, state = 0, {}, {}, {}, { valid = true }
    env.Bridge = {}
    env.GetCurrentResourceName = function() return "sky_phone" end
    env.GetResourceState = function(name) return started[name] and "started" or "missing" end
    env.GetResourceMetadata = function() return version or "4.1.0" end
    env.GetGameTimer = function() return now end
    env.PlayerPedId = function() return 10 end
    env.IsEntityDead = function() return state.dead end
    env.IsPedInAnyVehicle = function() return state.vehicle end
    env.IsControlJustReleased = function(_, control) return control == 73 and state.cancel end
    env.HasAnimDictLoaded = function() return not state.loading end
    env.Wait = function(ms) coroutine.yield(math.max(ms, 20)) end
    env.CreateThread = function(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = now } end
    env.AddEventHandler = function(name, fn)
        events[name] = events[name] or {}
        table.insert(events[name], fn)
    end
    for _, name in ipairs({ "RequestAnimDict", "RemoveAnimDict", "TaskPlayAnim", "StopAnimTask",
        "DisableControlAction", "DrawRect", "SetTextFont", "SetTextScale", "SetTextColour",
        "SetTextCentre", "BeginTextCommandDisplayText", "AddTextComponentSubstringPlayerName",
        "EndTextCommandDisplayText", "BeginTextCommandDisplayHelp", "EndTextCommandDisplayHelp",
        "BeginTextCommandThefeedPost", "EndTextCommandThefeedPostTicker" }) do
        env[name] = function(...) calls[#calls + 1] = { name = name, args = { ... } } end
    end
    env.exports = {}
    env.TriggerEvent = function(name) calls[#calls + 1] = { name = name } end
    for _, name in ipairs({ "helpnotify", "notifications", "progressbar" }) do
        assert(loadfile(root .. name .. ".lua", "t", env))()
    end
    local rt = { env = env, state = state, calls = calls, started = started }
    function rt.emit(name, value)
        for _, fn in ipairs(events[name] or {}) do fn(value) end
    end
    function rt.tick(ms)
        local deadline = now + ms
        while true do
            table.sort(threads, function(a, b) return a.at < b.at end)
            if not threads[1] or threads[1].at > deadline then break end
            local thread = table.remove(threads, 1)
            now = thread.at
            local ok, delay = coroutine.resume(thread.co)
            assert(ok, delay)
            if coroutine.status(thread.co) ~= "dead" then
                thread.at = now + delay
                threads[#threads + 1] = thread
            end
        end
        now = deadline
    end
    function rt.count(name)
        local count = 0
        for _, call in ipairs(calls) do if call.name == name then count = count + 1 end end
        return count
    end
    function rt.run()
        local result = {}
        env.CreateThread(function()
            result.success, result.error = env.Bridge.Progressbar.Run({
                label = "Repairing", cancelLabel = "Cancel", duration = 1000,
                animation = { dict = "test_dictionary", clip = "test_clip" },
                valid = function() return state.valid end,
            })
        end)
        return result
    end
    return rt
end

local native = runtime({ sky_base = true, sky_hud = true })
native.env.Bridge.Notifications.Show("Tower", "Closed", "success")
assert(native.count("EndTextCommandThefeedPostTicker") == 1, "No Sky dependency: native notification fallback")
local completed = native.run()
native.tick(900)
assert(completed.success == nil and native.count("DrawRect") > 0)
native.tick(200)
assert(completed.success and native.count("TaskPlayAnim") == 1 and native.count("StopAnimTask") == 1)

for _, trigger in ipairs({ "cancel", "dead", "vehicle", "invalid", "phone_stop", "loading_cancel" }) do
    local rt = runtime({})
    if trigger == "loading_cancel" then rt.state.loading = true end
    local result = rt.run()
    rt.tick(100)
    if trigger == "invalid" then rt.state.valid = false
    elseif trigger == "phone_stop" then rt.emit("onResourceStop", "sky_phone")
    elseif trigger == "loading_cancel" then rt.env.Bridge.Progressbar.Cancel()
    else rt.state[trigger] = true end
    rt.tick(50)
    assert(result.success == false, trigger)
    assert(rt.count("StopAnimTask") == (trigger == "loading_cancel" and 0 or 1), trigger)
end

local esx = runtime({ esx_progressbar = true, msk_core = true }, "3.3.0")
local finish, cancelled, provider_stops = nil, nil, 0
esx.env.exports.esx_progressbar = {
    Progressbar = function(_, label, duration, options)
        assert(label == "Repairing" and duration == 1000 and options.animation == nil)
        finish, cancelled = options.onFinish, options.onCancel
        return true
    end,
    CancelProgressbar = function() provider_stops = provider_stops + 1 cancelled() end,
}
esx.env.exports.msk_core = { ShowTextUI = function() end, HideTextUI = function() end }
local first = esx.run()
esx.tick(1100)
assert(first.success == nil, "A provider's start result or elapsed timer is not completion")
finish()
esx.tick(20)
assert(first.success and esx.count("DrawRect") == 0, "Old MSK falls through to supported ESX progress")
local second = esx.run()
esx.tick(100)
local old_finish = finish
esx.state.valid = false
esx.tick(50)
assert(second.success == false and provider_stops == 1)
esx.state.valid = true
local third = esx.run()
esx.tick(100)
old_finish()
esx.tick(50)
assert(third.success == nil, "A cancelled provider callback cannot complete the next action")
finish()
esx.tick(20)
assert(third.success)

local mov = runtime({ ["17mov_Hud"] = true })
local on_finish, stopped = nil, 0
mov.env.exports["17mov_Hud"] = {
    StartProgress = function(_, data, on_start, on_tick, callback) on_finish = callback end,
    StopProgress = function() stopped = stopped + 1 on_finish(false) end,
    ShowHelpNotification = function() end, HideHelpNotification = function() end,
}
local interrupted = mov.run()
mov.tick(100)
mov.env.Bridge.Progressbar.Cancel()
mov.tick(20)
assert(interrupted.success == false and stopped == 1, "17mov's stop callback must preserve cancellation")
local unloaded = mov.run()
mov.tick(100)
mov.started["17mov_Hud"] = nil
mov.emit("onResourceStop", "17mov_Hud")
mov.tick(20)
assert(unloaded.success == false and stopped == 1, "Do not call exports on a stopped provider")

local help = runtime({ ["qs-textui"] = true })
local displayed, changed, hidden = 0, 0, 0
help.env.exports["qs-textui"] = {
    displayTextUI = function(_, text) displayed = displayed + 1 assert(text == "[E] Unlock") end,
    changeText = function(_, text) changed = changed + 1 assert(text == "[E] Close | [G] Repair") end,
    hideTextUI = function() hidden = hidden + 1 end,
}
help.env.Bridge.HelpNotify.Show("Unlock", "E")
help.env.Bridge.HelpNotify.Show("Unlock", "E")
help.env.Bridge.HelpNotify.Show("Close | [G] Repair", "E")
assert(displayed == 1 and changed == 1, "Persistent text UI changes only when its content changes")
help.env.Bridge.HelpNotify.Hide()
help.env.Bridge.HelpNotify.Hide()
assert(hidden == 1)
help.env.Bridge.HelpNotify.Show("Unlock", "E", "cell_tower")
help.env.Bridge.HelpNotify.Show("Close | [G] Repair", "E", "payphone_interaction")
help.env.Bridge.HelpNotify.Hide("cell_tower")
help.env.Bridge.HelpNotify.Hide("progressbar")
assert(hidden == 1, "Idle tower and progress cleanup must not erase a payphone hint")
help.env.Bridge.HelpNotify.Show("Close | [G] Repair", "E", "payphone_call")
assert(displayed == 2 and changed == 2, "Ownership can change without redrawing identical content")
help.env.Bridge.HelpNotify.Hide("payphone_interaction")
assert(hidden == 1, "Interaction-thread cleanup must not erase a newly started call hint")
help.env.Bridge.HelpNotify.Hide("payphone_call")
assert(hidden == 2, "The current owner can hide its persistent hint")
help.env.Bridge.HelpNotify.Show("Unlock", "E", "cell_tower")
help.env.Bridge.HelpNotify.Hide("payphone_call")
assert(hidden == 2, "Payphone cleanup must not erase a tower hint")
help.emit("onResourceStop", "sky_phone")
assert(hidden == 3, "Resource shutdown must hide any owner's hint")
help.started["qs-textui"] = nil
help.emit("onResourceStop", "qs-textui")
help.env.Bridge.HelpNotify.Show("Unlock", "E")
assert(help.count("EndTextCommandDisplayHelp") == 1, "Native help after provider stop")

local notification = runtime({ esx_notify = true })
local notified
notification.env.exports.esx_notify = { Notify = function(_, ...)
    notified = { ... }
end }
notification.env.Bridge.Notifications.Show("Tower", "Closed", "success", 3000)
assert(notified, "The configured standalone notification adapter is called")
print("Tower feedback: native UI, animation cleanup, provider completion/cancellation, restarts and text lifecycle passed")
