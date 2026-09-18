local callbacks = {}
local server_result = { success = true, data = { ok = true } }
local last_server_callback = nil
local last_payload
local ped, drawable, texture = 9, 12, 3
function PlayerPedId() return ped end
function DoesEntityExist(entity) return entity == 9 end
function GetEntityModel(entity) assert(entity == 9); return 1885233650 end
function GetPedDrawableVariation(entity, component)
    assert(entity == 9 and component == 1)
    return drawable
end
function GetPedTextureVariation(entity, component)
    assert(entity == 9 and component == 1)
    return texture
end

Bridge = {
    Callbacks = {
        Trigger = function(name, payload)
            assert(type(payload) == "table", "NUI bridge must forward a table payload")
            last_server_callback = name
            last_payload = payload
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
assert(callback_count == 326, ("expected 326 NUI server callbacks, got %d"):format(callback_count))
for _, required in ipairs({
    "companies:dial-service-line",
    "fliptok:profiles",
    "mail:mailboxes",
    "calls:set-speaker",
    "calls:video",
    "realtime:config", "realtime:create", "realtime:join", "realtime:ready",
    "realtime:signal", "realtime:sfu", "realtime:chat", "realtime:drop",
    "media:import:commit",
    "flare:delete-profile",
    "admin:webhooks",
    "admin:save-webhooks",
    "security:set-face-id",
    "security:face-id-unlock",
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

for _, endpoint in ipairs({ "security:face-id-unlock", "security:set-face-id" }) do
    local responses = 0
    callbacks[endpoint]({ enabled = true, faceIdAppearance = { drawable = 0 } }, function(result)
        assert(result == server_result)
        responses = responses + 1
    end)
    assert(responses == 1 and last_payload.faceIdAppearance.drawable == 12)
    assert(last_payload.faceIdAppearance.model == 1885233650 and last_payload.faceIdAppearance.texture == 3)
end
drawable = 0
callbacks["security:face-id-unlock"]({}, function() end)
assert(last_payload.faceIdAppearance.drawable == 0, "Retry must sample the current mask")
ped = 0
last_server_callback = nil
callbacks["security:face-id-unlock"]({}, function(result)
    assert(not result.success and result.error == "face_id_unavailable")
end)
assert(last_server_callback == nil, "Missing ped must not initiate an unlock")
callbacks["security:set-face-id"]({ enabled = false, passcode = "1234" }, function(result)
    assert(result == server_result)
end)
assert(last_payload.faceIdAppearance == nil, "Disabling Face ID never needs a scan")

print("Client NUI server bridge tests passed")
