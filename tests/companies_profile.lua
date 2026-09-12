-- Run from the repository root with Lua 5.4.
local file = assert(io.open("sky_phone/source/server/companies.lua", "r"))
local source = file:read("*a")
file:close()

local function block(first, following)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(following, start, true))
    return source:sub(start, finish - 1)
end

function IsDuplicityVersion() return true end
function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
dofile("sky_phone/source/shared/config_default.lua")
dofile("sky_phone/source/shared/sim_number.lua")
Config = ConfigDefaults

local database_rows = {}
Bridge = { Database = { Query = function() return database_rows end } }

local helpers = block("local function trim(value)", "function SkyPhoneCompanies.ValidateConfiguration")
local api = assert(load(helpers
    .. block("local function company_services(", "local function current_announcement(")
    .. block("local function valid_clock(", "Bridge.Callbacks.Register(\"sky_phone:companies:update-hours\"")
    .. [[return {
        boolean = database_boolean, validate = validate_configuration,
        services = company_services, hours = company_hours, clock = valid_clock,
    }]]))()

for _, value in ipairs({ true, 1, "1" }) do
    database_rows = {{ id = "service", title = "Help", description = "", price_text = "",
        active = value, requests_enabled = value, weekday = 0, is_closed = value }}
    local service = api.services("police", true)[1]
    assert(service.active and service.acceptsRequests, "enabled database flags must survive reload")
    assert(api.hours("police")[1].isClosed, "closed days must survive reload")
end
for _, value in ipairs({ false, 0, "0" }) do
    database_rows = {{ id = "service", title = "Help", description = "", price_text = "",
        active = value, requests_enabled = value, weekday = 0, is_closed = value }}
    local service = api.services("police", true)[1]
    assert(not service.active and not service.acceptsRequests, "disabled flags must remain disabled")
    assert(not api.hours("police")[1].isClosed)
end
assert(not api.boolean(nil))
assert(api.validate(Config))
local company = Config.Companies.Definitions.police
local original_name = company.Name
company.Name = string.rep("W", 32)
assert(api.validate(Config), "32 character names must be accepted")
company.Name = string.rep("W", 33)
assert(not api.validate(Config), "oversized names must be rejected")
company.Name = string.rep(utf8.char(0xFC), 32)
assert(api.validate(Config), "name limits must count Unicode characters, not bytes")
company.Name = original_name
for _, cover in ipairs({ "", "https://example.com/cover.jpg" }) do
    company.CoverUrl = cover
    assert(api.validate(Config))
end
for _, cover in ipairs({ false, 42, "javascript:alert(1)", "http://example.com/cover.jpg", "https://bad host/image" }) do
    company.CoverUrl = cover
    assert(not api.validate(Config), "unsafe or malformed covers must be rejected")
end
company.CoverUrl = nil
assert(api.validate(Config), "legacy configurations without a cover must still load")
assert(company.CoverUrl == "")
for _, clock in ipairs({ "00:00", "09:05", "12:00", "23:59" }) do
    assert(api.clock(clock))
end
for _, clock in ipairs({ "24:00", "12:60", "9:05", "12:00 PM", "" }) do
    assert(not api.clock(clock))
end

-- Exercise the actual request callback up to service lookup: true must pass
-- the profile gate just like 1, while false must stop before service access.
local request_callback
local service_queried
Bridge.Callbacks = { Register = function(_, callback) request_callback = callback end }
Bridge.Database.Query = function(query)
    if query:find("SELECT `accepts_requests`", 1, true) then return database_rows end
    assert(query:find("FROM `sky_phone_company_services`", 1, true))
    service_queried = true
    return {}
end
local request_source = helpers .. [[
local definitions = Config.Companies.Definitions
local function allow_mutation() return true end
local function current_device() return { sim_id = "test" } end
]] .. block('Bridge.Callbacks.Register("sky_phone:companies:create-request"',
    'Bridge.Callbacks.Register("sky_phone:companies:cancel-request"')
assert(load(request_source))()
for _, value in ipairs({ true, 1, "1", false, 0, "0" }) do
    database_rows = {{ accepts_requests = value }}
    service_queried = false
    local result = request_callback(1, {
        companyId = "police", subject = "Test request", description = "Test request description",
        serviceId = "service",
    })
    assert(result.error == "invalid_service")
    assert(service_queried == api.boolean(value), "request gate must respect every database flag representation")
end
-- The manager callback must reject forged logo/cover changes before any write.
local profile_callback
Bridge.Callbacks.Register = function(_, callback) profile_callback = callback end
local profile_source = helpers .. [[
local function allow_mutation() return true end
local function require_permission() return { definition = Config.Companies.Definitions.police } end
]] .. block('Bridge.Callbacks.Register("sky_phone:companies:update-profile"', 'local function valid_clock(')
assert(load(profile_source))()
for _, field in ipairs({ "coverMediaId", "coverUrl", "logoMediaId", "logoUrl" }) do
    local draft = { revision = 1, description = "", district = "", address = "", acceptsRequests = true }
    draft[field] = field:find("MediaId", 1, true) and 42 or "https://example.com/unauthorized.jpg"
    assert(profile_callback(1, draft).error == "invalid_profile")
end
print("Companies profile regression tests passed")
