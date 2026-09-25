-- Exercise the real admin callbacks without a phone session or social account.
local callbacks, queries, audits = {}, {}, {}
local authorized, allowed, affected = true, true, 1
local rows = {}
Config = { AdminPanel = { Enabled = true, Command = "phonepanel", ReadRequestsPerMinute = 60, ActionRequestsPerMinute = 30 } }
Bridge = {
    Debug = function() end,
    Framework = {
        HasPermission = function(_, permission) assert(permission == "phonepanel") return authorized end,
        GetIdentifier = function() return "admin-test" end,
        GetFirstname = function() return "Test" end, GetLastname = function() return "Admin" end,
    },
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("sky_phone_admin_audit", 1, true) then
                audits[#audits + 1] = params
                return 1
            end
            if sql:find("SELECT", 1, true) then return rows end
            return { affectedRows = affected }
        end,
    },
}
SkyPhone = { AllowOperation = function() return allowed end }
json = { encode = function(data) return data end }
function RegisterCommand() end
function AddEventHandler() end
function GetPlayerName() return "Test Admin" end
dofile("sky_phone/source/server/admin.lua")
local list = callbacks["sky_phone:admin:social-posts"]
local remove = callbacks["sky_phone:admin:delete-social-post"]
local id = "550e8400-e29b-41d4-a716-446655440001"
authorized = false
assert(list(1, { platform = "feather", query = "", page = 0 }).error == "not_authorized")
assert(remove(1, { platform = "feather", id = id }).error == "not_authorized")
assert(#queries == 0, "Unauthorized callers must never reach the database")
authorized, allowed = true, false
assert(remove(1, { platform = "feather", id = id }).error == "rate_limited")
allowed = true
assert(remove(1, { platform = "unknown", id = id }).error == "invalid_request")
assert(remove(1, { platform = "feather", id = "'; DELETE" }).error == "invalid_request")
assert(list(1, { platform = "feather", query = "", page = -1 }).error == "invalid_request")
assert(#queries == 0)
for _, platform in ipairs({ "feather", "fliptok", "picstagram", "weazel-news" }) do
    rows = {}
    for index = 1, 51 do rows[index] = { id = tostring(index) } end
    local result = list(1, { platform = platform, query = "test", page = 1 })
    assert(result.success and #result.data.items == 50 and result.data.hasMore)
    local query = queries[#queries]
    assert(query.params[1] == "%test%" and query.params[4] == 50)
    assert(remove(1, { platform = platform, id = id }).success)
    local mutation = queries[#queries - 1]
    assert(mutation.sql:find("UPDATE", 1, true) and mutation.sql:find("published", 1, true))
    local audit = audits[#audits]
    assert(audit[6] == "delete_social_post" and audit[7].platform == platform and audit[7].postId == id)
end
affected = 0
assert(remove(1, { platform = "feather", id = id }).error == "not_found")
assert(#audits == 4, "Already removed/missing posts must not generate success audits")
print("Admin social moderation permission, pagination and deletion tests passed")
