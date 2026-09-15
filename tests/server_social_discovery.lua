-- Execute the real discovery callbacks; verify auth, limits and public SQL projections.
local callbacks, queries = {}, {}
local authenticated, permitted = true, true
local app_name = "picstagram"
Config = {
    Server = { PicstagramPasswordPepper = "test", FlipTokPasswordPepper = "test" },
    Picstagram = { ReportReasons = {}, PageSize = 20, VerifyCommand = "picverify" },
    FlipTok = { MusicTracks = {}, VerifyCommand = "flipverify" },
}
function AddEventHandler() end
function RegisterCommand() end
Bridge = {
    Debug = function() end,
    Callbacks = { Register = function(name, fn) callbacks[name] = fn end },
    Database = {
        AfterMigration = function(_, fn) fn() end,
        Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("_sessions`", 1, true) then
                return { { id = app_name == "picstagram" and "viewer-id" or 1, status = "active" } }
            end
            if sql:find("ORDER BY candidate.", 1, true) or sql:find("ORDER BY p.`id` = ?", 1, true) then
                return { {
                    id = app_name == "picstagram" and "creator-id" or 2, handle = "nova", display_name = "Nova",
                    followers = "9", following = "3", verified = 1, private = 1, follow_status = "", is_following = 0,
                } }
            end
            return {}
        end,
    },
}
SkyPhone = {
    RequireSession = function()
        if authenticated then return { imei = "viewer-device" } end
        return nil, { success = false, error = "session_required" }
    end,
    AllowOperation = function(_, _, count, window)
        assert(count == 40 and window == 60, "Discovery must stay rate limited")
        return permitted
    end,
}
dofile("sky_phone/source/server/picstagram.lua")
dofile("sky_phone/source/server/fliptok.lua")
for _, name in ipairs({ "picstagram", "fliptok" }) do
    app_name = name
    local callback = callbacks["sky_phone:" .. name .. (name == "picstagram" and ":search" or ":profiles")]
    local function request(search)
        queries = {}
        return callback(1, { search = search })
    end
    local result = request("")
    assert(result.success, "Empty discovery must suggest real users in " .. name)
    local profiles = name == "picstagram" and result.data.profiles or result.data
    assert(#profiles == 1 and profiles[1].display_name == "Nova" and profiles[1].followers == 9)
    assert(profiles[1].verified == true and profiles[1].is_owner == false)
    if name == "picstagram" then
        assert(profiles[1].locked == true, "Suggestions must not unlock a private profile")
        assert(#result.data.posts == 0)
    end
    local query = queries[2]
    assert(query and query.params[2] == "%%" and query.params[3] == "%%")
    assert(not query.sql:find(".*", 1, true) and not query.sql:find("password", 1, true), "Only public profile fields may be projected")
    assert(query.sql:find("NOT EXISTS", 1, true) and query.sql:find("`blocker_id` = ?", 1, true)
        and query.sql:find("`blocked_id` = ?", 1, true), "Both directions of a block must exclude suggestions")
    assert(query.params[4] == query.params[1] and query.params[5] == query.params[1])
    assert(query.sql:find("LIMIT 20", 1, true), "Discovery must have bounded output")
    result = request("  @NoVa  ")
    assert(result.success and queries[2].params[2] == "%nova%", "Search must normalize handles")
    request("' OR 1=1 --")
    assert(not queries[2].sql:find("' OR 1=1 --", 1, true), "Search must remain a bound parameter")
    local limit = name == "picstagram" and 80 or 50
    assert(request(string.rep("a", limit)).success)
    assert(not request(string.rep("a", limit + 1)).success)
    authenticated = false
    assert(request("").error == "session_required" and #queries == 0)
    authenticated, permitted = true, false
    assert(request("").error == "rate_limited")
    permitted = true
end
print("Social discovery auth, limits, public fields, block filters and empty-query suggestions passed")
