local callbacks, queries, liked = {}, {}, false
local env = setmetatable({
    Config = { SkyPic = { PageSize = 10, SpotlightPageSize = 5, SpotlightCommentPageSize = 7 } },
    json = { null = {} },
    AddEventHandler = function() end,
    CreateThread = function() end,
    SkyPhone = {
        AllowOperation = function() return true end,
        RequireAccount = function() return { id = 1 } end,
    },
}, { __index = _G })
env.Bridge = {
    Callbacks = { Register = function(name, handler) callbacks[name] = handler end },
    Database = {
        AfterMigration = function(_, handler) handler() end,
        Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("WHERE profile.`account_id` = ?", 1, true) then
                return { { profile_id = "profile-self" } }
            elseif sql:find("SELECT spotlight.`id`, spotlight.`profile_id`, spotlight.`comments_enabled`", 1, true) then
                return { { id = "00000000-0000-4000-8000-000000000001", profile_id = "profile-other", comments_enabled = 1 } }
            elseif sql:find("INSERT IGNORE INTO `sky_phone_skypic_spotlight_likes`", 1, true) then
                liked = true
            elseif sql:find("DELETE FROM `sky_phone_skypic_spotlight_likes`", 1, true) then
                liked = false
            elseif sql:find("SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_spotlight_likes`", 1, true) then
                return { { count = liked and 1 or 0 } }
            elseif sql:find("SELECT `id` FROM `sky_phone_skypic_stories`", 1, true) then
                return { { id = "00000000-0000-4000-8000-000000000002" } }
            end
            return {}
        end,
    },
}
assert(loadfile("sky_phone/source/server/skypic.lua", "t", env))()
local react = callbacks["sky_phone:skypic:like-spotlight"]
assert(react(1, { spotlightId = "00000000-0000-4000-8000-000000000001", active = true }).success and liked)
assert(react(1, { spotlightId = "00000000-0000-4000-8000-000000000001", active = false }).success and not liked,
    "A valid false must reach the unlike operation")
assert(not react(1, { spotlightId = "00000000-0000-4000-8000-000000000001", active = "false" }).success)

for _, case in ipairs({
    { "stories", {}, 10 },
    { "story-viewers", { storyId = "00000000-0000-4000-8000-000000000002" }, 10 },
    { "spotlight-feed", {}, 5 },
    { "spotlight-comments", { spotlightId = "00000000-0000-4000-8000-000000000001" }, 7 },
}) do
    local response = callbacks["sky_phone:skypic:" .. case[1]](1, case[2])
    assert(response.success and response.pageSize == case[3], case[1])
    local params = queries[#queries].params
    assert(params[#params - 1] == response.pageSize, "Pagination metadata must match the SQL limit")
end
print("SkyPic unlike and configured pagination tests passed")
