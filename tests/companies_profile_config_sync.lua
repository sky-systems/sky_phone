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
            Transaction = function(statements)
                local before = { profiles = copy(database.profiles), services = copy(database.services), writes = database.writes }
                for index, statement in ipairs(statements) do
                    if database.fail_transaction and index > 1 then
                        for _, name in ipairs({ "profiles", "services" }) do
                            for id, row in pairs(database[name]) do
                                if not before[name][id] then
                                    database[name][id] = nil
                                else
                                    for key in pairs(row) do row[key] = nil end
                                    for key, value in pairs(before[name][id]) do row[key] = copy(value) end
                                end
                            end
                        end
                        database.writes = before.writes
                        return false
                    end
                    env.Bridge.Database.Query(statement.query, statement.params)
                end
                return true
            end,
            Query = function(sql, params)
                if sql:find("SELECT UUID()", 1, true) then
                    database.uuid = (database.uuid or 0) + 1
                    return { { id = "test-token-" .. database.uuid } }
                end
                for _, name in ipairs({ "company_requests", "company_audit", "company_announcements" }) do
                    if sql:find("DELETE FROM `sky_phone_" .. name .. "`", 1, true) then return 0 end
                end
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
                if sql:find("INSERT INTO `sky_phone_company_services`", 1, true) then
                    assert(#params == 8)
                    local profile = database.profiles[params[7]]
                    if profile.mutation_token ~= params[8] then return 0 end
                    assert(not database.services[params[1]], "Duplicate service ID")
                    database.services[params[1]] = {
                        id = params[1], title = params[2], description = params[3], price_text = params[4],
                        requests_enabled = params[5], sort_order = params[6], company_id = params[7],
                        active = 1, archived = 0,
                    }
                    return 0
                end
                if sql:find("UPDATE `sky_phone_company_services` service", 1, true) then
                    local row = assert(database.services[params[#params - 2]])
                    local company_id = params[#params - 1]
                    if row.company_id ~= company_id or database.profiles[company_id].mutation_token ~= params[#params] then
                        return 0
                    end
                    local assignments = assert(sql:match("SET (.-)%s+WHERE"))
                    local index = 0
                    for column in assignments:gmatch("service%.`([^`]+)` = %?") do
                        index = index + 1
                        row[column] = params[index]
                    end
                    assert(index == #params - 3)
                    for column, value in assignments:gmatch("service%.`([^`]+)` = ([01])") do
                        row[column] = tonumber(value)
                    end
                    return 1
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
                    for column in assignments:gmatch("`([^`]+)` = NULL") do
                        row[column] = nil
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
                if sql:find("SELECT `description`", 1, true) then
                    local row = database.profiles[params[1]]
                    if not row then return {} end
                    local selected = {}
                    for column in assert(sql:match("SELECT (.-)FROM")):gmatch("`([^`]+)`") do
                        selected[column] = copy(row[column])
                    end
                    return { selected }
                end
                if sql:find("FROM `sky_phone_company_profiles`", 1, true) then
                    local row = database.profiles[params[1]]
                    return row and { copy(row) } or {}
                end
                if sql:find("FROM `sky_phone_company_services`", 1, true) then
                    local rows = {}
                    for _, service in pairs(database.services) do
                        local included = service.company_id == params[1]
                        for index = 2, #params do included = included or service.id == params[index] end
                        if sql:find("`archived` = 0", 1, true) then included = included and service.archived == 0 end
                        if sql:find("`active` = 1", 1, true) then included = included and service.active == 1 end
                        if included then rows[#rows + 1] = copy(service) end
                    end
                    table.sort(rows, function(left, right)
                        return left.sort_order == right.sort_order and left.id < right.id or left.sort_order < right.sort_order
                    end)
                    return rows
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
assert(original_timestamp == 101, "Initial services and their snapshot must be committed together")
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

-- Location-only panel edits must reach SQL and the public payload together.
local located = new_server()
local located_row = located.database.profiles.police
local located_definition = located.env.Config.Companies.Definitions.police
local location_revision = located_row.revision
located_definition.Location = { x = -1113.45, y = -823.49, z = 19.32 }
located.refresh()
assert(located_row.location_x == -1113.45 and located_row.location_y == -823.49
    and located_row.location_z == 19.32, "Panel location changes must update existing SQL coordinates")
company = located.company()
assert(company.location.coords.x == -1113.45 and company.location.coords.y == -823.49
    and company.location.coords.z == 19.32)
assert(located_row.revision == location_revision + 1)
assert(located_row.updated_at_unix == 102)
assert(located_row.availability_updated_at_unix == 50)
writes = located.database.writes
located = new_server(located.database, located.env.Config)
assert(located.database.writes == writes, "Unchanged locations must not rewrite profiles on restart")

-- Preserve manager coordinates on unrelated saves; a changed Location replaces the whole point.
located_row.location_x, located_row.location_y, located_row.location_z = 100, 200, 30
located_definition = located.env.Config.Companies.Definitions.police
located_definition.Description = "Unrelated description"
located.refresh()
located = new_server(located.database, located.env.Config)
assert(located_row.location_x == 100 and located_row.location_y == 200 and located_row.location_z == 30)
located_definition = located.env.Config.Companies.Definitions.police
located_definition.Location.x = 0
located.refresh()
assert(located_row.location_x == 0 and located_row.location_y == -823.49 and located_row.location_z == 19.32,
    "A location edit must not mix configured axes with manager axes")

-- SQL DECIMAL coordinates and vector float precision must share the same three-decimal representation.
located_definition.Location = { x = -1113.449951171875, y = -823.489990234375, z = 19.319999694824 }
located.refresh()
assert(located_row.location_x == -1113.45 and located_row.location_y == -823.49 and located_row.location_z == 19.32)
located_row.location_x, located_row.location_y, located_row.location_z = "-1113.450", "-823.490", "19.320"
writes = located.database.writes
located.refresh()
assert(located.database.writes == writes, "Float precision and SQL strings must not cause repeated updates")

-- Clearing an optional Location writes SQL NULL, including after a restart; zero remains a valid coordinate.
located_definition.Location = nil
located.refresh()
assert(located_row.location_x == nil and located_row.location_y == nil and located_row.location_z == nil)
assert(located.company().location == nil)
writes = located.database.writes
located = new_server(located.database, located.env.Config)
assert(located.database.writes == writes and located.company().location == nil)
located.env.Config.Companies.Definitions.police.Location = { x = 0, y = 0, z = 0 }
located = new_server(located.database, located.env.Config)
assert(located.company().location.coords.x == 0 and located_row.location_y == 0 and located_row.location_z == 0)

-- Upgrade both pre-snapshot rows and the existing text-only snapshot from the reported SQL dump.
for _, snapshot_kind in ipairs({ "none", "text-only" }) do
    for _, manager_location in ipairs({ false, true }) do
        local upgrading = new_server()
        local upgrading_row = upgrading.database.profiles.police
        if snapshot_kind == "none" then
            upgrading_row.config_profile = nil
        else
            upgrading.database.payloads[tonumber(upgrading_row.config_profile)].location = nil
        end
        upgrading_row.location_x, upgrading_row.location_y, upgrading_row.location_z = "425.100", "-979.500", "30.700"
        if manager_location then upgrading_row.location_y = "123.000" end
        local upgrading_config = copy(upgrading.env.Config)
        upgrading_config.Companies.Definitions.police.Location = { x = -1113.45, y = -823.49, z = 19.32 }
        upgrading = new_server(upgrading.database, upgrading_config)
        local coords = upgrading.company().location.coords
        if manager_location then
            assert(coords.x == 425.1 and coords.y == 123 and coords.z == 30.7,
                "The initial upgrade must preserve a customized location as a whole")
        else
            assert(coords.x == -1113.45 and coords.y == -823.49 and coords.z == 19.32,
                "Existing stock locations must follow saved panel values on upgrade")
        end
        writes = upgrading.database.writes
        upgrading.refresh()
        assert(upgrading.database.writes == writes, "The upgraded snapshot must make later refreshes idempotent")
    end
end

local managed = new_server()
local managed_definition = managed.env.Config.Companies.Definitions.police
local managed_profile = managed.database.profiles.police
managed_definition.AcceptsRequests = false
managed.refresh()
assert(managed_profile.accepts_requests == 0 and not managed.company().acceptsRequests)
managed = new_server(managed.database, managed.env.Config)
assert(not managed.company().acceptsRequests)
managed_definition = managed.env.Config.Companies.Definitions.police
managed_profile.accepts_requests = true -- oxmysql's boolean representation; a manager enabled requests.
managed_definition.Description = "Unrelated panel edit"
managed.refresh()
assert(managed.company().acceptsRequests, "Unrelated saves must preserve manager request preferences")
managed_definition.AcceptsRequests = true
managed.refresh()
managed_definition.AcceptsRequests = false
managed.refresh()
assert(not managed.company().acceptsRequests)

local configured_service = managed_definition.Services[1]
local service_id = configured_service.Id
local service_row = managed.database.services[service_id]
service_row.description = "Manager description"
configured_service.Title, configured_service.Price, configured_service.RequestsEnabled = "New service", "500", false
local service_revision = managed_profile.revision
managed.refresh()
assert(service_row.title == "New service" and service_row.price_text == "500" and service_row.requests_enabled == 0)
assert(service_row.description == "Manager description")
assert(managed.company().services[1].title == "New service" and not managed.company().services[1].acceptsRequests)
assert(managed_profile.revision == service_revision + 1, "Service edits must invalidate manager drafts")
writes = managed.database.writes
managed = new_server(managed.database, managed.env.Config)
assert(managed.database.writes == writes and managed.company().services[1].title == "New service")
managed_definition = managed.env.Config.Companies.Definitions.police
configured_service = managed_definition.Services[1]

-- Renames archive the old ID, retaining references from existing requests.
configured_service.Id = "replacement-service"
managed.refresh()
assert(service_row.archived == 1 and service_row.active == 0 and service_row.requests_enabled == 0)
assert(#managed.company().services == 1 and managed.company().services[1].id == "replacement-service")
local second = copy(configured_service)
second.Id, second.Title = "second-service", "Second service"
managed_definition.Services = { second, configured_service }
managed.refresh()
assert(managed.company().services[1].id == "second-service")
assert(managed.database.services["replacement-service"].sort_order == 2)

-- Manager-created services are outside the configured list and remain untouched.
managed.database.services["manager-service"] = {
    id = "manager-service", company_id = "police", title = "Manager service", description = "",
    price_text = "", requests_enabled = 1, active = 1, archived = 0, sort_order = 3,
}
managed_definition.Services = {}
managed.refresh()
assert(managed.database.services["replacement-service"].archived == 1)
assert(managed.database.services["second-service"].archived == 1)
assert(#managed.company().services == 1 and managed.company().services[1].id == "manager-service")
managed_definition.Services = { configured_service }
managed.refresh()
assert(managed.database.services["replacement-service"].archived == 0)
assert(managed.database.services["replacement-service"].active == 1)
managed.database.services["replacement-service"].active = 0
managed_definition.Address = "Another unrelated edit"
managed.refresh()
assert(managed.database.services["replacement-service"].active == 0)

-- A stale profile CAS must gate every service statement; retry from fresh manager data.
configured_service.Title = "Concurrent admin edit"
managed.database.conflict = function(profile)
    managed.database.services["replacement-service"].price_text = "Manager price"
    profile.revision = profile.revision + 1
end
managed.refresh()
assert(managed.database.services["replacement-service"].title == "Concurrent admin edit")
assert(managed.database.services["replacement-service"].price_text == "Manager price")

-- Service changes and the profile snapshot must roll back together on SQL failure.
local before_snapshot, before_revision = managed_profile.config_profile, managed_profile.revision
configured_service.Title = "Transaction failure"
managed.database.fail_transaction = true
assert(not pcall(managed.refresh))
assert(managed_profile.config_profile == before_snapshot and managed_profile.revision == before_revision)
assert(managed.database.services["replacement-service"].title == "Concurrent admin edit")
managed.database.fail_transaction = false
managed.refresh()
assert(managed.database.services["replacement-service"].title == "Transaction failure")

-- Old snapshots reconcile stock services, but do not discard manager customization.
for _, customized in ipairs({ false, true }) do
    local upgrading = new_server()
    local profile = upgrading.database.profiles.police
    local snapshot = upgrading.database.payloads[tonumber(profile.config_profile)]
    snapshot.services, snapshot.accepts_requests = nil, nil
    local old_id = upgrading.env.Config.Companies.Definitions.police.Services[1].Id
    local old = upgrading.database.services[old_id]
    if customized then old.description = "Legacy manager service" end
    local configuration = copy(upgrading.env.Config)
    configuration.Companies.Definitions.police.Services[1].Id = "upgraded-service"
    configuration.Companies.Definitions.police.AcceptsRequests = false
    upgrading = new_server(upgrading.database, configuration)
    assert(not upgrading.company().acceptsRequests)
    assert(old.archived == (customized and 0 or 1))
    assert(upgrading.database.services["upgraded-service"].active == 1)
    writes = upgrading.database.writes
    upgrading.refresh()
    assert(upgrading.database.writes == writes)
end

-- A configured ID can never overwrite a service owned by another company.
managed.database.services["foreign-service"] = {
    id = "foreign-service", company_id = "another-company", title = "Foreign", description = "",
    price_text = "", requests_enabled = 1, active = 1, archived = 0, sort_order = 1,
}
configured_service.Id = "foreign-service"
assert(not pcall(managed.refresh))
assert(managed.database.services["foreign-service"].company_id == "another-company")

legacy.env.Config.Companies.Definitions.police.Description = "Must fail"
legacy.database.fail_updates = true
assert(not pcall(legacy.refresh), "Persistent SQL conflicts must fail visibly")
legacy.database.fail_updates = false
legacy_row.config_profile = "corrupt"
assert(not pcall(legacy.refresh), "Corrupt snapshots must fail visibly")

print("Companies profile configuration sync tests passed")
