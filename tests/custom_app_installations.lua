local callbacks, ledger, encodings = {}, {}, {}
local source_session = { imei = "111", token = "token" }
local identifier, job, balance, debits, refunds = "owner", { name = "police", grade = 2 }, 1000, 0, 0
local policy = { id = "dispatch", ownerResource = "dispatch_resource", store = { price = 500 } }
local fail_paid_save, close_after_reservation, change_price, yield_read = false, false, false, false
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
json = {
    encode = function(value)
        local key = tostring(#encodings + 1)
        encodings[#encodings + 1] = copy(value)
        return key
    end,
    decode = function(key) return copy(encodings[tonumber(key)]) end,
}
Bridge = {
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Debug = function() end,
    Framework = {
        GetIdentifier = function() return identifier end,
        GetJob = function() return job end,
        GetMoney = function() return balance end,
        RemoveMoney = function(_, account, amount)
            assert(account == "bank")
            debits, balance = debits + 1, balance - amount
            return true
        end,
        AddMoney = function(_, _, amount) refunds, balance = refunds + 1, balance + amount return true end,
    },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(sql, params)
            if sql:find("SELECT", 1, true) then
                if yield_read then yield_read = false coroutine.yield() end
                return ledger.row and { copy(ledger.row) } or {}
            end
            local insert = sql:find("INSERT", 1, true)
            local payload = insert and params[3] or params[1]
            if insert and ledger.row then return 0 end
            if not insert and (not ledger.row or ledger.row.revision ~= params[4]) then return 0 end
            local data = json.decode(payload)
            if fail_paid_save and data["dispatch_resource/dispatch"] and data["dispatch_resource/dispatch"].status == "paid" then return 0 end
            ledger.row = { payload = payload, revision = insert and 1 or ledger.row.revision + 1 }
            if data["dispatch_resource/dispatch"] and data["dispatch_resource/dispatch"].status == "pending" then
                if close_after_reservation then source_session = nil end
                if change_price then policy.store.price = 600 end
            end
            return 1
        end,
    },
}
SkyPhone = {
    AllowOperation = function() return true end,
    RequireSession = function() return source_session, source_session == nil and { success = false, error = "device_not_open" } or nil end,
}
SkyPhoneApps = {
    ValidateAppId = function(value) return value == "dispatch" end,
    GetPolicy = function() return copy(policy) end,
}
dofile("sky_phone/source/server/custom_app_installations.lua")
local install = callbacks["sky_phone:custom-app:install"]
local authorize = callbacks["sky_phone:custom-app:authorize"]
local function request(patch)
    local data = { appId = "dispatch", ownerResource = "dispatch_resource", imei = "111", sessionToken = "token", requirePolicy = true, expectedPrice = 500 }
    for key, value in pairs(patch or {}) do data[key] = value end
    return data
end
local function reset()
    ledger = {}
    source_session = { imei = "111", token = "token" }
    policy = { id = "dispatch", ownerResource = "dispatch_resource", store = { price = 500 } }
    job, identifier, balance, debits, refunds = { name = "police", grade = 2 }, "owner", 1000, 0, 0
    fail_paid_save, close_after_reservation, change_price = false, false, false
end
assert(authorize(1, request()).error == "app_not_purchased")
assert(install(1, request({ expectedPrice = 0 })).error == "app_price_changed")
assert(install(1, request({ ownerResource = "attacker" })).error == "app_owner_mismatch")
assert(install(1, request({ sessionToken = "old" })).error == "stale_session")
assert(debits == 0)
assert(install(1, request()).success)
assert(balance == 500 and debits == 1)
assert(authorize(1, request()).success)
assert(install(1, request()).success and debits == 1, "Reinstallation must retain the device entitlement")
policy.ownerResource = "other_resource"
assert(install(1, request({ ownerResource = "other_resource" })).success and debits == 2)
policy.ownerResource = "dispatch_resource"
assert(install(1, request()).success and debits == 2, "Different app owners must retain separate entitlements")
reset()
policy = nil
assert(install(1, request()).error == "app_policy_required")
assert(authorize(1, request()).error == "app_policy_required")
assert(install(1, request({ requirePolicy = false, expectedPrice = 0 })).success and debits == 0,
    "Free unrestricted legacy apps must continue to install without a server policy")
reset()
policy.store.allowedJobs = { police = 3 }
assert(install(1, request()).error == "app_job_denied")
job.grade = 3
policy.store.disabledJobs = { police = 0 }
assert(install(1, request()).error == "app_job_denied", "Deny list must win")
reset()
balance = 499
assert(install(1, request()).error == "insufficient_funds" and debits == 0)
reset()
close_after_reservation = true
assert(install(1, request()).error == "stale_session" and debits == 0)
reset()
change_price = true
assert(install(1, request()).error == "app_price_changed" and debits == 0)
reset()
fail_paid_save = true
assert(install(1, request()).error == "app_purchase_failed")
assert(balance == 1000 and debits == 1 and refunds == 1, "Rejected purchase persistence must refund")
reset()
ledger.row = { revision = 1, payload = json.encode({ ["dispatch_resource/dispatch"] = { ownerResource = "dispatch_resource", status = "pending" } }) }
assert(install(1, request()).error == "app_install_pending" and debits == 0)
reset()
yield_read = true
local thread = coroutine.create(function() assert(install(1, request()).success) end)
assert(coroutine.resume(thread))
assert(install(1, request()).error == "app_install_pending", "Concurrent requests must not charge twice")
local prior_session = source_session
source_session = { imei = "222", token = "second" }
assert(install(1, request({ imei = "222", sessionToken = "second" })).error == "app_install_pending",
    "Concurrent purchases from another device must share the character payment lock")
source_session = prior_session
assert(coroutine.resume(thread))
assert(debits == 1)
reset()
Config = { CustomApps = { Enabled = true, StorageRequestsPerMinute = 60, MaximumStorageKeyLength = 64 } }
SkyPhoneApps.HasPermission = function() return true end
dofile("sky_phone/source/server/custom_app_storage.lua")
local storage_get = callbacks["sky_phone:custom-app:storage:get"]
local storage_set = callbacks["sky_phone:custom-app:storage:set"]
assert(storage_get(1, { appId = "dispatch", key = "state" }).error == "app_not_purchased",
    "Direct storage calls must not bypass payment authorization")
assert(storage_set(1, { appId = "dispatch", key = "state", value = {}, revision = 0 }).error == "app_not_purchased")
policy.store = { allowedJobs = { police = 3 } }
assert(storage_get(1, { appId = "dispatch", key = "state" }).error == "app_job_denied",
    "Direct storage calls must use the current authoritative job")
policy.store = {}
assert(storage_get(1, { appId = "dispatch", key = "state" }).success,
    "Unrestricted authorized storage retains its existing behavior")
print("Custom app installation authority/payment tests passed")
