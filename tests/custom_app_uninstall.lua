local callbacks, encodings, row = {}, {}, nil
local owned, relinquish_on_read, conflict, writes = true, false, false, 0
local imei = "123456789012347"
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
json = {
    encode = function(value) encodings[#encodings + 1] = copy(value) return tostring(#encodings) end,
    decode = function(value) return copy(encodings[tonumber(value)]) end,
}
Bridge = {
    Debug = function() end,
    Framework = { GetIdentifier = function() return "owner" end },
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(sql, params)
            if sql:find("SELECT", 1, true) then
                if relinquish_on_read then owned = false end
                return row and { copy(row) } or {}
            end
            assert(sql:find("'apps'", 1, true), "Only device app layout may change")
            if conflict then return 0 end
            if sql:find("INSERT", 1, true) then
                assert(row == nil)
                row = { payload = params[2], revision = 1 }
            else
                assert(params[3] == row.revision, "Removal must use compare-and-swap")
                row = { payload = params[1], revision = row.revision + 1 }
            end
            writes = writes + 1
            return 1
        end,
    },
}
SkyPhone = {
    AllowOperation = function() return true end,
    FindDeviceSlots = function(_, requested_imei) return owned and requested_imei == imei and { 1 } or {} end,
}
dofile("sky_phone/source/shared/imei.lua")
dofile("sky_phone/source/shared/custom_apps.lua")
dofile("sky_phone/source/server/phone_persistence.lua")
local uninstall = callbacks["sky_phone:custom-app:uninstall"]
local request = { imei = imei, appId = "external-market" }
assert(uninstall(1, { imei = imei, appId = "phone" }).error == "invalid_request")
owned = false
assert(uninstall(1, request).error == "device_not_owned" and writes == 0)
owned = true
assert(uninstall(1, request).success, "Closed owned phones must support permanent removal")
local payload = json.decode(row.payload)
assert(payload.uninstalledApps[1] == request.appId and payload.homeLayout.version == 6)
row = { revision = 5, payload = json.encode({ claimedApps = { request.appId, "snake" }, launchCounts = { snake = 9 }, homeLayout = { version = 6 }, uninstalledApps = { "old-app" } }) }
local result = uninstall(1, request)
assert(result.success and result.data.revision == 6)
assert(result.data.payload.claimedApps[1] == "snake" and #result.data.payload.claimedApps == 1)
assert(result.data.payload.launchCounts.snake == 9 and #result.data.payload.uninstalledApps == 2)
assert(uninstall(1, request).success)
assert(#json.decode(row.payload).uninstalledApps == 2, "Repeated removal must not duplicate tombstones")
local previous_writes = writes
conflict = true
assert(uninstall(1, request).error == "conflict" and writes == previous_writes)
conflict, relinquish_on_read = false, true
assert(uninstall(1, request).error == "device_not_owned" and writes == previous_writes)
print("Custom app permanent uninstall ownership/persistence tests passed")
