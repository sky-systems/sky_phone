-- Exercise the real admin callbacks without a phone session or social account.
local callbacks, queries, audits = {}, {}, {}
local authorized, allowed, affected = true, true, 1
local rows, profiles, attachments = {}, {}, {}
local imei = "490154203237518"
Config = { AdminPanel = { Enabled = true, Command = "phonepanel", ReadRequestsPerMinute = 60, ActionRequestsPerMinute = 30 } }
Config.Phone = { Item = "phone" }
Bridge = {
    Debug = function() end,
    Framework = {
        HasPermission = function(_, permission) assert(permission == "phonepanel") return authorized end,
        GetIdentifier = function(source)
            if source == 1 then return "admin-test" end
            if source == 2 then return "target-test" end
        end,
        GetFirstname = function() return "Test" end, GetLastname = function() return "Admin" end,
    },
    Inventory = { GetSlotsWithItem = function() return { { metadata = { imei = imei } } } end },
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("sky_phone_admin_audit", 1, true) then
                audits[#audits + 1] = params
                return 1
            end
            if sql:find("sky_phone_character_devices", 1, true) then return {} end
            if sql:find("profile.`account_id` AS `accountId`", 1, true) then
                assert(sql:find("SELECT DISTINCT", 1, true), "Multiple devices linked to the same account must not duplicate profiles")
                return profiles
            end
            if sql:find("SELECT relation.", 1, true) or sql:find("AS `postId`", 1, true) then
                return attachments
            end
            if sql:find("AND 1 = 0", 1, true) then return {} end
            if sql:find("SELECT", 1, true) then return rows end
            return { affectedRows = affected }
        end,
    },
}
SkyPhone = { AllowOperation = function() return allowed end }
SkyPhoneImei = { IsValid = function(value) return value == imei end }
json = { encode = function(data) return data end }
function RegisterCommand() end
function AddEventHandler() end
function GetPlayerName() return "Test Admin" end
dofile("sky_phone/source/server/admin.lua")
local list = callbacks["sky_phone:admin:social-posts"]
local remove = callbacks["sky_phone:admin:delete-social-post"]
local id = "550e8400-e29b-41d4-a716-446655440001"
local platforms = { "feather", "fliptok", "picstagram", "weazel-news", "skypic", "skypic-stories" }
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
for _, platform in ipairs(platforms) do
    local skypic = platform == "skypic" or platform == "skypic-stories"
    rows = {}
    for index = 1, 51 do rows[index] = { id = tostring(index) } end
    local before = #queries
    local result = list(1, { platform = platform, query = "test", page = 1 })
    assert(result.success and #result.data.items == 50 and result.data.hasMore)
    local query = queries[before + 1]
    assert(query.params[1] == "%test%" and query.params[4] == 50)
    assert(query.sql:find(skypic and "= 'active'" or "published", 1, true), "Global moderation must preserve public content states")
    if skypic then
        assert(query.sql:find("post.`expires_at` > CURRENT_TIMESTAMP(6)", 1, true), "Global SkyPic results must respect expiry")
        assert(query.sql:find("post.`overlay_text`", 1, true), "SkyPic overlays are part of posted content")
        if platform == "skypic-stories" then
            assert(query.sql:find("post.`privacy` = 'everyone'", 1, true), "Global stories must not include friends-only content")
        end
    end
    assert(remove(1, { platform = platform, id = id }).success)
    local mutation = queries[#queries - 1]
    assert(mutation.sql:find("UPDATE", 1, true) and mutation.sql:find(skypic and "= 'active'" or "published", 1, true))
    local audit = audits[#audits]
    assert(audit[6] == "delete_social_post" and audit[7].platform == platform and audit[7].postId == id)
    assert(audit[3] == "", "Global moderation audits must satisfy the non-null target schema")
end
affected = 0
assert(remove(1, { platform = "feather", id = id }).error == "not_found")
assert(#audits == #platforms, "Already removed/missing posts must not generate success audits")

-- The server resolves player/device/account scope. Client profile ids never grant access.
affected = 1
local before = #queries
assert(list(1, { platform = "feather", query = "", page = 0, targetSource = 99 }).error == "player_unavailable")
assert(remove(1, { platform = "feather", id = id, targetSource = 99 }).error == "player_unavailable")
assert(#queries == before, "Invalid targets must never reach content queries")

for _, platform in ipairs(platforms) do
    local profile_id = (platform == "picstagram" or platform == "skypic" or platform == "skypic-stories") and id or 7
    profiles = { { id = profile_id, accountId = 3, handle = "target", displayName = "Target" } }
    rows = { { id = id, profileId = profile_id, body = string.rep("x", 800), status = "archived", expiresAt = "1793433600000" } }
    attachments = { { postId = id, url = "https://example.invalid/test.jpg", type = "photo" } }
    local result = list(1, { platform = platform, query = "needle", page = 0, targetSource = 2, profileId = "foreign" })
    assert(result.success and not result.data.hasMore)
    assert(#result.data.items == 1 and #result.data.items[1].body == 800, "Captions must not be truncated")
    assert(#result.data.items[1].media == 1, "Attachments should be batched and fallback covers deduplicated")
    assert(result.data.items[1].media[1].type == "photo")
    assert(result.data.items[1].expiresAt == 1793433600000)
    local content_query
    for index = #queries, 1, -1 do
        if queries[index].sql:find("LIMIT 51 OFFSET", 1, true) then content_query = queries[index] break end
    end
    assert(content_query.params[4] == (platform == "weazel-news" and "target-test" or profile_id))
    assert(content_query.params[5] == 0)
    assert(not content_query.sql:find("= 'published'", 1, true), "Target administration includes unpublished content")
    if platform ~= "weazel-news" then
        assert(result.data.accounts[1].id == tostring(profile_id) and result.data.accounts[1].accountId == 3)
        assert(result.data.items[1].profileId == tostring(profile_id))
    end
    assert(remove(1, { platform = platform, id = id, targetSource = 2 }).success)
    local mutation = queries[#queries - 1]
    assert(mutation.params[platform == "weazel-news" and 3 or 2] == (platform == "weazel-news" and "target-test" or profile_id))
    local audit = audits[#audits]
    assert(audit[3] == "target-test" and audit[4] == 2)
end

profiles, rows, attachments = {}, { { id = "foreign" } }, {}
local empty = list(1, { platform = "feather", query = "", page = 0, targetSource = 2 })
assert(empty.success and #empty.data.items == 0 and #empty.data.accounts == 0)
assert(queries[#queries - 1].sql:find("AND 1 = 0", 1, true), "No associated profile must never expose global posts")
assert(audits[#audits][6] == "view_social_posts", "Access to private target content must be audited")
local audit_count = #audits
assert(remove(1, { platform = "feather", id = id, targetSource = 2 }).error == "not_found")
assert(#audits == audit_count, "An unassociated target cannot remove arbitrary content or generate a success audit")

print("Admin social permission, target/account scope, media, content states, pagination and deletion tests passed")
