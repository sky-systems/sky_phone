local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function load_script(path, environment)
    assert(loadfile("sky_phone/" .. path, "t", environment))()
end

local function new_server(database, configure_defaults)
    database = database or { payloads = {}, writes = 0 }
    local callbacks, broadcasts, updates = {}, {}, {}
    local noop = function() end
    local environment = setmetatable({
        Config = {},
        IsDuplicityVersion = function() return true end,
        vector3 = function(x, y, z) return { __skyType = "vector3", x = x, y = y, z = z } end,
        print = noop,
    }, { __index = _G })
    load_script("config/config.lua", environment)
    load_script("config/media.lua", environment)
    load_script("source/shared/config_default.lua", environment)
    if configure_defaults then configure_defaults(environment.ConfigDefaults) end

    -- Snapshot encoded values so the SQL stub cannot share mutable runtime tables.
    environment.json = {
        encode = function(value)
            local key = tostring(#database.payloads + 1)
            database.payloads[tonumber(key)] = copy(value)
            return key
        end,
        decode = function(key) return copy(assert(database.payloads[tonumber(key)])) end,
    }
    environment.Bridge = {
        Debug = noop,
        Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        Database = {
            Migrate = noop,
            AfterMigration = noop,
            Query = function(sql, parameters)
                if sql:find("INSERT IGNORE", 1, true) then
                    database.row = database.row or {
                        config_payload = parameters[2], media_payload = parameters[3], revision = 1,
                    }
                    return 0
                end
                if sql:find("UPDATE", 1, true) then
                    assert(parameters[5] == 1 and parameters[6] == database.row.revision)
                    database.writes = database.writes + 1
                    database.row = {
                        config_payload = parameters[1], media_payload = parameters[2],
                        revision = database.row.revision + 1, updated_by_name = parameters[4],
                    }
                    return { affectedRows = 1 }
                end
                assert(sql:find("SELECT", 1, true), "unexpected SQL: " .. sql)
                return { copy(database.row) }
            end,
        },
    }
    environment.SkyPhoneCompanies = { ValidateConfiguration = function() return true end }
    environment.TriggerEvent = function(name, revision)
        assert(name == "sky_phone:configurator:serverUpdated")
        updates[#updates + 1] = { revision = revision, config = copy(environment.Config) }
    end
    environment.TriggerClientEvent = function(name, target, payload)
        assert(name == "sky_phone:configurator:sync" and target == -1)
        broadcasts[#broadcasts + 1] = copy(payload)
    end
    load_script("source/server/phone_configurator.lua", environment)

    local server = {
        env = environment, database = database, broadcasts = broadcasts, updates = updates,
    }
    function server.field(path, scope)
        for _, section in ipairs(environment.SkyPhoneConfigurator.GetAdminData().sections) do
            for _, field in ipairs(section.fields) do
                if field.path == path and field.scope == (scope or "config") then return field end
            end
        end
        error("missing configurator field: " .. path)
    end
    function server.save(changes, revision)
        return environment.SkyPhoneConfigurator.Save(
            revision or database.row.revision, changes, "test-admin", "Test Admin"
        )
    end
    function server.runtime()
        return callbacks["sky_phone:configurator:runtime"]().data
    end
    return server
end

local function new_client(server)
    local events, revisions = {}, {}
    local environment = setmetatable({
        Config = copy(server.env.ConfigDefaults),
        Bridge = { Callbacks = { Trigger = function(name)
            assert(name == "sky_phone:configurator:runtime")
            return { success = true, data = server.runtime() }
        end } },
        RegisterNetEvent = function(name, callback) events[name] = callback end,
        TriggerEvent = function(name, revision)
            assert(name == "sky_phone:configurator:updated")
            revisions[#revisions + 1] = revision
        end,
        vector3 = server.env.vector3,
    }, { __index = _G })
    load_script("source/client/phone_configurator.lua", environment)
    return { config = environment.Config, sync = events["sky_phone:configurator:sync"], revisions = revisions }
end

local function change(path, value, scope)
    return { scope = scope or "config", path = path, value = value }
end

local failures = 0
local function test(name, callback)
    local success, message = pcall(callback)
    if success then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(message))
    end
end

test("false scalar settings save together with other panel changes and survive reload", function()
    local server = new_server()
    local apps = server.field("Apps").value
    apps.feather = false
    local result = server.save({ change("Companies.Enabled", false), change("Apps", apps) })
    assert(result.success, "valid false rejected: " .. tostring(result.error))
    assert(server.field("Companies.Enabled").value == false)
    assert(server.env.Config.Companies.Enabled == false and server.env.Config.Apps.feather == false)
    assert(server.updates[1].config.Companies.Enabled == false, "refresh must observe the saved value")
    assert(#server.broadcasts == 1 and server.broadcasts[1].config.Apps.feather == false)
    assert(server.database.writes == 1 and result.data.revision == 2)
    local restarted = new_server(server.database)
    assert(restarted.field("Companies.Enabled").value == false)
    assert(restarted.env.Config.Apps.feather == false)
    assert(restarted.save({ change("Companies.Enabled", true) }).success)
    assert(restarted.env.Config.Companies.Enabled == true)
end)

test("disabled numeric map entries reach existing and newly connected phones", function()
    local server = new_server()
    local client = new_client(server)
    local client_timers = client.config.DarkChat.AllowedDisappearTimers
    local server_timers = server.env.Config.DarkChat.AllowedDisappearTimers
    local darkchat = server.field("DarkChat").value
    for _, entry in ipairs(darkchat.AllowedDisappearTimers.entries) do
        if entry.key == 0 or entry.key == -1 then entry.value = false end
    end
    local result = server.save({ change("DarkChat", darkchat) })
    assert(result.success, tostring(result.error))
    assert(server_timers[0] == false and server_timers[-1] == false, "saved false restored to default")
    assert(server_timers == server.env.Config.DarkChat.AllowedDisappearTimers)
    client.sync(server.broadcasts[1])
    assert(client_timers == client.config.DarkChat.AllowedDisappearTimers)
    assert(client_timers[0] == false and client_timers[-1] == false and client_timers[60] == true)
    assert(client.revisions[#client.revisions] == result.data.revision)
    local restarted = new_server(server.database)
    local reconnect = new_client(restarted)
    assert(reconnect.config.DarkChat.AllowedDisappearTimers[0] == false)
    assert(reconnect.config.DarkChat.AllowedDisappearTimers[-1] == false)
end)

test("boolean list entries survive save and default merging", function()
    -- Synthetic collection exercises the generic list merge independently of map handling.
    local function defaults(config) config.Phone.TestFlags = { true, true } end
    local server = new_server(nil, defaults)
    local phone = server.field("Phone").value
    phone.TestFlags = { false, true, false }
    local result = server.save({ change("Phone", phone) })
    assert(result.success, tostring(result.error))
    assert(server.env.Config.Phone.TestFlags[1] == false, "saved list flag restored to default")
    local restarted = new_server(server.database, defaults)
    local flags = new_client(restarted).config.Phone.TestFlags
    assert(flags[1] == false and flags[2] == true and flags[3] == false)
end)

test("nested switches, optional false strings and media settings still roundtrip", function()
    local server = new_server()
    local phone = server.field("Phone").value
    phone.Keybind = false
    phone.DevelopmentCommand = false
    local wallpaper = server.field("Wallpaper", "media").value
    wallpaper.CustomUploadEnabled = false
    local result = server.save({ change("Phone", phone), change("Wallpaper", wallpaper, "media") })
    assert(result.success, tostring(result.error))
    assert(server.env.Config.Phone.Keybind == false)
    assert(server.env.Config.Media.Wallpaper.CustomUploadEnabled == false)
    local restarted = new_server(server.database)
    local client = new_client(restarted)
    assert(client.config.Phone.Keybind == false and client.config.Phone.DevelopmentCommand == false)
    assert(restarted.field("Wallpaper", "media").value.CustomUploadEnabled == false)
    assert(server.broadcasts[1].config.Media == nil, "media credentials must remain server-owned")
end)

test("invalid boolean values reject the entire save without updating SQL or clients", function()
    for _, invalid in ipairs({ "false", 0, {} }) do
        local server = new_server()
        local apps = server.field("Apps").value
        apps.feather = false
        local result = server.save({ change("Apps", apps), change("Companies.Enabled", invalid) })
        assert(not result.success and result.error == "invalid_value")
        assert(server.database.writes == 0 and server.database.row.revision == 1)
        assert(server.env.Config.Apps.feather == true and server.env.Config.Companies.Enabled == true)
        assert(#server.broadcasts == 0 and #server.updates == 0)
    end
end)

test("stale revisions cannot overwrite saved settings", function()
    local server = new_server()
    assert(server.save({ change("Companies.Enabled", true) }).success)
    local result = server.save({ change("Companies.Enabled", false) }, 1)
    assert(not result.success and result.error == "revision_conflict")
    assert(server.database.writes == 1 and #server.broadcasts == 1)
    assert(server.env.Config.Companies.Enabled == true)
end)

assert(failures == 0, ("%s phone configurator tests failed"):format(failures))
