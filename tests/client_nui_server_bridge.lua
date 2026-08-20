local callbacks = {}
local server_result = { success = true, data = { ok = true } }
local last_server_callback = nil

Bridge = {
    Callbacks = {
        Trigger = function(name, payload)
            assert(type(payload) == "table", "NUI bridge must forward a table payload")
            last_server_callback = name
            return server_result
        end,
    },
    Debug = function() end,
}

function RegisterNUICallback(name, callback)
    assert(not callbacks[name], ("duplicate NUI callback %s"):format(name))
    callbacks[name] = callback
end

dofile("sky_phone/source/client/nui_server_bridge.lua")

local callback_count = 0
for _ in pairs(callbacks) do
    callback_count = callback_count + 1
end
assert(callback_count == 292, ("expected 292 NUI server callbacks, got %d"):format(callback_count))
for _, required in ipairs({
    "companies:dial-service-line",
    "mail:mailboxes",
    "calls:set-speaker",
    "media:import:commit",
    "flare:delete-profile",
}) do
    assert(type(callbacks[required]) == "function", ("missing callback %s"):format(required))
end

local invalid_result
callbacks["mail:list"]("invalid", function(result)
    invalid_result = result
end)
assert(not invalid_result.success and invalid_result.error == "invalid_request", "invalid NUI payload must be rejected")

local forwarded_result
callbacks["mail:list"]({}, function(result)
    forwarded_result = result
end)
assert(forwarded_result == server_result, "server response must be returned unchanged")
assert(last_server_callback == "sky_phone:mail:list", "NUI bridge callback name changed")

print("Client NUI server bridge tests passed")
