local net_events = {}
local nui_callbacks = {}
local nui_messages = {}
local picker_focus = false

Bridge = {
    Callbacks = {
        Trigger = function(name)
            assert(name == "sky_phone:sim:picker-close", "SIM picker must close through the server")
            return { success = true }
        end,
    },
    Debug = function() end,
}

SkyPhoneFocus = {
    SetSimPicker = function(active)
        picker_focus = active
    end,
}

function RegisterNetEvent(name, callback)
    net_events[name] = callback
end

function RegisterNUICallback(name, callback)
    nui_callbacks[name] = callback
end

function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end

dofile("sky_phone/source/client/sim.lua")

net_events["sky_phone:sim:picker"]({ number = "5550101", choices = { "sim-1" } })
assert(picker_focus and nui_messages[#nui_messages].type == "sim:picker", "valid SIM picker must claim focus")

nui_messages = {}
SkyPhoneSimPicker.ReplayNui()
assert(nui_messages[1].type == "sim:picker", "NUI reload must replay the active SIM picker")

local close_result
nui_callbacks["sim:picker-close"]({}, function(result)
    close_result = result
end)
assert(close_result.success and not picker_focus, "SIM picker close must release focus")
assert(nui_messages[#nui_messages].type == "sim:picker-close", "SIM picker close must reach NUI")

print("Client SIM picker tests passed")
