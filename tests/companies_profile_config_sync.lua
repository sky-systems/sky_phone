-- Run from the repository root with Lua 5.4. Exercise the full Companies module,
-- including startup, Configurator refresh, SQL persistence and the public callback.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function new_server(database, configuration)
    database = database or { profiles = {}, services = {}, payloads = {}, writes = 0 }
    local callbacks, handlers, events = {}, {}, {}
    local env = setmetatable({
        IsDuplicityVersion = function() return true end,
        vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
        vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
        CreateThread = function() end,
        AddEventHandler = function(name, callback) handlers[name] = callback end,
        TriggerClientEvent = function(name, target, payload)
            events[#events + 1] = { name = name, target = target, payload = copy(payload) }
        end,
    }, { __index = _G })
    assert(loadfile("sky_phone/source/shared/config_default.lua", "t", env))()
    env.Config = copy(configuration or env.ConfigDefaults)
    env.json = {
        encode = function(value)
            local key = tostring(#database.payloads + 1)
            database.payloads[tonumber(key)] = copy(value)
            return key
        end,
        decode = function(key) return copy(assert(database.payloads[tonumber(key)])) end,
    }
    env.SkyPhone = {
        AllowOperation = function() return true end,
        RequireSession = function() return { imei = "test-device" } end,
    }
    env.Bridge = {
        Debug = function() end,
        Framework = {
            GetPlayers = function() return { 1, 2 } end,
            GetJob = function(player)
                return { name = player == 1 and "police" or "unemployed", grade = 4 }
            end,
        },
        Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Transaction = function() return true end,
            Query = function(sql, params)
                if sql:find("INSERT IGNORE INTO `sky_phone_company_profiles`", 1, true) then
                    if not database.profiles[params[1]] then
                        local row = { revision = 1, updated_at_unix = 100, availability_updated_at_unix = 50 }
                        local columns = assert(sql:match("%((.-)%)%s*VALUES"))
                        local index = 0
                        for column in columns:gmatch("`([^`]+)`") do
                            index = index + 1
                            row[column] = params[index]
                        end
                        database.profiles[params[1]] = row
                    end
                    return 0
                end
                if sql:find("INSERT IGNORE INTO `sky_phone_company_services`", 1, true) then
                    database.services[params[1]] = database.services[params[1]] or params[2]
                    return 0
                end
                if sql:find("UPDATE `sky_phone_company_profiles` SET", 1, true) then
                    local row = assert(database.profiles[params[#params - 1]])
                    if database.conflict then
                        database.conflict(row)
                        database.conflict = nil
                        return { affectedRows = 0 }
                    end
                    if database.fail_updates or row.revision ~= params[#params] then return 0 end
                    local assignments = assert(sql:match("SET (.-) WHERE"))
                    local index = 0
                    for column in assignments:gmatch("`([^`]+)` = %?") do
                        index = index + 1
                        row[column] = params[index]
                    end
                    assert(index == #params - 2, "Every SQL placeholder must have a parameter")
                    assert(assignments:find("`revision` = `revision` + 1", 1, true))
                    row.revision = row.revision + 1
                    if assignments:find("`updated_at` = CURRENT_TIMESTAMP", 1, true) then
                        row.updated_at_unix = row.updated_at_unix + 1
                    end
                    database.writes = database.writes + 1
                    return { affectedRows = 1 }
                end
                if sql:find("SELECT DISTINCT profile.", 1, true) then return {} end
                if sql:find("FROM `sky_phone_company_profiles`", 1, true) then
                    local row = database.profiles[params[1]]
                    return row and { copy(row) } or {}
                end
                if sql:find("SELECT `company_id` FROM `sky_phone_company_services`", 1, true) then
                    return { { company_id = database.services[params[1]] } }
                end
                if sql:find("FROM `sky_phone_migrations`", 1, true) then return { {} } end
                if sql:find("FROM `sky_phone_devices`", 1, true) then return { { device_name = "Phone" } } end
                for _, name in ipairs({ "sims", "company_services", "company_hours", "company_announcements" }) do
                    if sql:find("FROM `sky_phone_" .. name .. "`", 1, true) then return {} end
                end
                error("Unexpected SQL: " .. sql)
            end,
        },
    }
    assert(loadfile("sky_phone/source/shared/sim_number.lua", "t", env))()
    assert(loadfile("sky_phone/source/server/companies.lua", "t", env))()
    local server = { env = env, database = database, events = events }
    function server.refresh() handlers["sky_phone:configurator:serverUpdated"]() end
    function server.company()
        local result = callbacks["sky_phone:companies:get"](2, { companyId = "police" })
        assert(result.success, result.error)
        return result.data.company
    end
    return server
end

local server = new_server()
local database = server.database
local writes = database.writes
local row = database.profiles.police
local original_availability_time = row.availability_updated_at_unix
local original_timestamp = row.updated_at_unix
assert(original_timestamp == 100, "Initializing a snapshot must preserve profile timestamps")
server.refresh()
assert(database.writes == writes, "Unchanged configuration must not rewrite profiles")
assert(row.updated_at_unix == original_timestamp)

-- Reproduce the screenshot: an already seeded profile with all four panel values changed.
local definition = server.env.Config.Companies.Definitions.police
definition.Name = "Vespucci PD"
definition.Description = "Polizei"
definition.District = "Vespucci"
definition.LocationLabel = "Vespucci Beach"
definition.Address = "5943"
local previous_revision = row.revision
server.refresh()
local company = server.company()
assert(company.name == "Vespucci PD" and company.description == "Polizei")
assert(company.location.district == "Vespucci" and company.location.label == "Vespucci Beach")
assert(company.location.address == "5943")
assert(row.revision == previous_revision + 1, "Panel edits must invalidate stale manager drafts")
assert(row.availability_updated_at_unix == original_availability_time)
local work_event, directory_event = false, false
for _, event in ipairs(server.events) do
    if event.name == "sky_phone:companies:changed" and event.payload.companyId == "police" then
        work_event = work_event or event.target == 1 and event.payload.area == "work"
        directory_event = directory_event or event.target == 2 and event.payload.area == "directory"
    end
end
assert(work_event and directory_event, "Panel saves must refresh open public and manager views")

-- Manager data stays in SQL until the admin changes that specific field again.
row.description = "Manager description"
row.address = "Manager address"
row.availability = "busy"
row.accepts_requests = 0
row.revision = row.revision + 1
writes = database.writes
definition.LogoUrl = "https://example.com/new-logo.jpg"
server.refresh()
assert(database.writes == writes and row.description == "Manager description")
server = new_server(database, server.env.Config)
assert(database.writes == writes and server.company().location.address == "Manager address")
definition = server.env.Config.Companies.Definitions.police
definition.Description = "Neue Beschreibung"
server.refresh()
assert(row.description == "Neue Beschreibung" and row.address == "Manager address")
assert(row.availability == "busy" and row.accepts_requests == 0)
definition.Description = ""
definition.District = ""
definition.LocationLabel = ""
definition.Address = ""
server.refresh()
company = server.company()
assert(company.description == "" and company.location.district == "")
assert(company.location.label == "" and company.location.address == "", "Blank panel values must clear old text")

-- Config values changed while stopped must also be applied on the next start.
definition.Description = "After restart"
server = new_server(database, server.env.Config)
assert(server.company().description == "After restart")

-- Upgrade legacy stock profiles, preserving fields already customized by a manager.
local legacy = new_server()
local legacy_row = legacy.database.profiles.police
legacy_row.config_profile = nil
local updated_config = copy(legacy.env.Config)
local updated = updated_config.Companies.Definitions.police
updated.Description, updated.District = "Polizei", "Vespucci"
updated.LocationLabel, updated.Address = "Vespucci Beach", "5943"
legacy = new_server(legacy.database, updated_config)
company = legacy.company()
assert(company.description == "Polizei" and company.location.district == "Vespucci")
assert(company.location.label == "Vespucci Beach" and company.location.address == "5943")
assert(legacy_row.config_profile ~= nil)

local custom = new_server()
custom.database.profiles.police.config_profile = nil
custom.database.profiles.police.address = "Legacy manager address"
custom = new_server(custom.database, updated_config)
assert(custom.company().description == "Polizei")
assert(custom.company().location.address == "Legacy manager address")

-- A concurrent manager write must be re-read, not silently overwritten or discarded.
legacy.env.Config.Companies.Definitions.police.Description = "Admin update"
legacy.database.conflict = function(profile)
    profile.address = "Concurrent manager address"
    profile.revision = profile.revision + 1
end
legacy.refresh()
assert(legacy_row.description == "Admin update" and legacy_row.address == "Concurrent manager address")

legacy.env.Config.Companies.Definitions.police.Description = "Must fail"
legacy.database.fail_updates = true
assert(not pcall(legacy.refresh), "Persistent SQL conflicts must fail visibly")
legacy.database.fail_updates = false
legacy_row.config_profile = "corrupt"
assert(not pcall(legacy.refresh), "Corrupt snapshots must fail visibly")

print("Companies profile configuration sync tests passed")
