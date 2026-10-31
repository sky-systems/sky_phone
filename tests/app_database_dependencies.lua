-- Cold-database boundary check against the real full migration schema. Every
-- selected FK parent and every startup follow-up query must have storage.
local function cold_database(apps)
    local tables, schemas, queries, handlers, completed = {}, {}, {}, {}, {}
    local env = setmetatable({ Config = { Apps = apps }, SkyPhoneConfiguratorSchema = {
        name = "sky_phone_configurator", columns = {},
    } }, { __index = _G })
    env.AddEventHandler = function(name, callback)
        handlers[name] = handlers[name] or {}
        handlers[name][#handlers[name] + 1] = callback
    end
    env.Bridge = { Callbacks = {}, Database = {
        Query = function(sql)
            queries[#queries + 1] = sql
            if sql:find("INFORMATION_SCHEMA.TABLES", 1, true) then return {} end
            for name in sql:gmatch("`(sky_phone_[%w_]+)`") do
                assert(tables[name], "Cold startup query references absent table: " .. name)
            end
            return {}
        end,
        Migrate = function(name, schema)
            assert(not completed[name], "A completed migration name must never be repeated")
            completed[name] = true
            schemas[#schemas + 1] = schema
            for _, definition in ipairs(schema) do tables[definition.name] = true end
            for _, definition in ipairs(schema) do
                for _, key in ipairs(definition.foreignKeys or {}) do
                    local parent = key.references:match("^`([^`]+)`")
                    assert(tables[parent], "Missing FK parent " .. tostring(parent) .. " for " .. definition.name)
                end
            end
        end,
        EnsureIndex = function(name) assert(tables[name], "Index on absent table: " .. name) end,
        CompleteMigration = function() end,
        AfterMigration = function(_, callback) callback() end,
    } }
    assert(loadfile("sky_phone/source/server/app_database.lua", "t", env))()
    assert(loadfile("sky_phone/source/server/db_migrate.lua", "t", env))()
    return env, tables, schemas, queries, handlers
end

local disabled = setmetatable({}, { __index = function() return false end })
local env, tables, _, cold_queries = cold_database(disabled)
for _, name in ipairs({ "sky_phone_notes", "sky_phone_music_playlists", "sky_phone_music_youtube_songs",
    "sky_phone_music_playlist_items", "sky_phone_fliptok_sessions", "sky_phone_sms_messages",
    "sky_phone_map_markers", "sky_phone_flare_profile_photos", "sky_phone_flare_profiles",
    "sky_phone_skypic_profiles", "sky_phone_skypic_friendships", "sky_phone_skypic_messages",
    "sky_phone_skypic_stories", "sky_phone_skypic_spotlights" }) do
    assert(tables[name], "Core cloud/reset/gallery/share consumer lost required storage: " .. name)
end
assert(not tables.sky_phone_picstagram_posts and not tables.sky_phone_bank_transactions,
    "App-only storage must still be skipped")

-- Turning Local Pages on after an all-disabled cold start must also create the
-- still-disabled CityMarkt parent table, without starting the CityMarkt app.
assert(not tables.sky_phone_marketplace_listings)
env.Config.Apps["local-pages"] = true
env.SkyPhoneAppDatabase.Ensure("local-pages")
assert(tables.sky_phone_pages_posts and tables.sky_phone_marketplace_listings)
assert(not env.SkyPhoneAppDatabase.Enabled("citymarkt"))

-- The same dependency must be retained during the initial migration.
local initial_apps = setmetatable({ ["local-pages"] = true }, { __index = function() return false end })
local _, initial_tables = cold_database(initial_apps)
assert(initial_tables.sky_phone_pages_posts and initial_tables.sky_phone_marketplace_listings)

-- A failed follow-up must remain retryable; success is published only after
-- every statement actually finishes.
local ran, fail = 0, true
env.SkyPhoneAppDatabase.Run("picstagram", function()
    ran = ran + 1
    if fail then error("synthetic post-migration failure") end
end)
env.Config.Apps.picstagram = true
assert(not pcall(env.SkyPhoneAppDatabase.Ensure, "picstagram"))
fail = false
assert(env.SkyPhoneAppDatabase.Ensure("picstagram") and ran == 2)

-- Reentrant configuration events must not start one module twice while its
-- lazy migration yields. A later disable must cancel the pending start.
local start_count = 0
local toggle_env, _, _, _, toggle_handlers = cold_database(setmetatable({}, { __index = function() return false end }))
toggle_env.SkyPhoneAppDatabase.WhenEnabled("calendar", function() start_count = start_count + 1 end)
toggle_env.Config.Apps.calendar = true
local migrate = toggle_env.Bridge.Database.Migrate
toggle_env.Bridge.Database.Migrate = function(...)
    coroutine.yield("migrating")
    return migrate(...)
end
local attempt = toggle_handlers["sky_phone:configurator:serverUpdated"][1]
local first = coroutine.create(attempt)
assert(coroutine.resume(first))
attempt()
assert(start_count == 0)
toggle_env.Config.Apps.calendar = false
assert(coroutine.resume(first) and start_count == 0)
toggle_env.Config.Apps.calendar = true
attempt()
assert(start_count == 1)

-- Disabled optional content has an explicit admin error; the core panel still
-- opens because its SMS statistics dependency is retained on a fresh database.
local callbacks = {}
env.Config.AdminPanel = { Enabled = true, Command = "phonepanel", ReadRequestsPerMinute = 60 }
env.RegisterCommand = function() end
env.GetPlayerName = function() return "Test Admin" end
env.SkyPhone = { AllowOperation = function() return true end, GetDisabledApps = function() return {} end }
env.Bridge.Debug = function() end
env.Bridge.Framework = {
    HasPermission = function() return true end,
    GetPlayers = function() return {} end,
    GetIdentifier = function() return "test-admin" end,
}
env.Bridge.Callbacks.Register = function(name, callback) callbacks[name] = callback end
assert(loadfile("sky_phone/source/server/admin.lua", "t", env))()
assert(callbacks["sky_phone:admin:bootstrap"](1, {}).success)
assert(callbacks["sky_phone:admin:statistics"](1, {}).success)
for _, platform in ipairs({ "feather", "picstagram", "fliptok", "skypic", "skypic-stories", "weazel-news" }) do
    env.Config.Apps[platform == "skypic-stories" and "skypic" or platform] = false
    local query_count = #cold_queries
    assert(callbacks["sky_phone:admin:social-posts"](1, { platform = platform, page = 0, query = "" }).error == "app_disabled")
    assert(callbacks["sky_phone:admin:delete-social-post"](1, {
        platform = platform, id = "550e8400-e29b-41d4-a716-446655440001",
    }).error == "app_disabled")
    assert(#cold_queries == query_count, "Disabled social administration must not query absent optional tables")
end
print("app database: real-schema cold startup, core stores, FK closure and lazy start recovery passed")
