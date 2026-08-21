Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneCompanies = {}

local definitions = {}
local definition_ids = {}
local definitions_by_job = {}
local service_lines_by_number = {}
local call_availability = {}
local round_robin_positions = {}
local member_tokens = {}
local terminal_statuses = {
    completed = true,
    cancelled = true,
}
local status_transitions = {
    new = { cancelled = true },
    assigned = { in_progress = true, cancelled = true },
    in_progress = { waiting_customer = true, completed = true, cancelled = true },
    waiting_customer = { in_progress = true, cancelled = true },
}

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a Companies UUID.")
    end
    return rows[1].id
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function valid_text(value, maximum, allow_empty)
    local text = trim(value)
    if not text or text:find("%z") then
        return nil
    end
    local length = utf8.len(text)
    if not length or length > maximum or (not allow_empty and length == 0) then
        return nil
    end
    return text
end

local function valid_integer(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum
        or number ~= math.floor(number)
    then
        return nil
    end
    return number
end

local function valid_uuid(value)
    return type(value) == "string"
        and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function valid_service_id(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= 64
        and value:match("^[%w_-]+$") ~= nil
end

local function valid_array(value, maximum)
    if type(value) ~= "table" or #value > maximum then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or key > #value then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local function iso_time(value)
    local seconds = tonumber(value)
    if not seconds or seconds <= 0 then
        return nil
    end
    return os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
end

local function days_from_civil(year, month, day)
    year = year - (month <= 2 and 1 or 0)
    local era = math.floor(year / 400)
    local year_of_era = year - era * 400
    local adjusted_month = month + (month > 2 and -3 or 9)
    local day_of_year = math.floor((153 * adjusted_month + 2) / 5) + day - 1
    local day_of_era = year_of_era * 365 + math.floor(year_of_era / 4)
        - math.floor(year_of_era / 100) + day_of_year
    return era * 146097 + day_of_era - 719468
end

local function utc_epoch(year, month, day, hour, minute, second)
    if year < 1970 or year > 2100 or month < 1 or month > 12
        or day < 1 or hour < 0 or hour > 23 or minute < 0 or minute > 59
        or second < 0 or second > 59
    then
        return nil
    end
    local month_lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then
        month_lengths[2] = 29
    end
    if day > month_lengths[month] then
        return nil
    end
    return days_from_civil(year, month, day) * 86400 + hour * 3600 + minute * 60 + second
end

local function parse_expiry(value, maximum_seconds)
    if value == nil or value == "" then
        return nil
    end
    if type(value) ~= "string" or #value > 40 then
        return false
    end
    local year, month, day, hour, minute, second = value:match(
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$"
    )
    if not year then
        year, month, day, hour, minute, second = value:match(
            "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)%.%d+Z$"
        )
    end
    if not year then
        return false
    end
    local epoch = utc_epoch(
        tonumber(year),
        tonumber(month),
        tonumber(day),
        tonumber(hour),
        tonumber(minute),
        tonumber(second)
    )
    local now = os.time()
    if not epoch or epoch <= now or epoch - now > maximum_seconds then
        return false
    end
    return epoch
end

local function permission_grade(definition, permission)
    local grade = definition.Permissions and tonumber(definition.Permissions[permission])
    return grade and math.max(0, math.floor(grade)) or nil
end

local function validate_configuration()
    if type(Config.Companies) ~= "table" or type(Config.Companies.Definitions) ~= "table" then
        error("[sky_phone] Config.Companies.Definitions must be configured.")
    end
    if type(Config.Companies.Enabled) ~= "boolean" then
        error("[sky_phone] Config.Companies.Enabled must be a boolean.")
    end
    for _, field in ipairs({
        { "PageSize", 1000 },
        { "MaximumPageSize", 1000 },
        { "MaximumOpenRequestsPerSim", 1000 },
        { "MaximumServices", 255 },
        { "MaximumRequestMedia", 255 },
        { "SubjectMaxLength", 120 },
        { "RequestBodyMaxLength", 2000 },
        { "MessageMaxLength", 2000 },
        { "ProfileDescriptionMaxLength", 1000 },
        { "DistrictMaxLength", 80 },
        { "AddressMaxLength", 160 },
        { "ServiceTitleMaxLength", 80 },
        { "ServiceDescriptionMaxLength", 500 },
        { "ServicePriceMaxLength", 80 },
        { "AnnouncementTitleMaxLength", 120 },
        { "AnnouncementBodyMaxLength", 1000 },
        { "AvailabilityMaximumSeconds", 31536000 },
        { "AnnouncementMaximumSeconds", 31536000 },
        { "RetentionDays", 36500 },
    }) do
        if not valid_integer(Config.Companies[field[1]], 1, field[2]) then
            error(("[sky_phone] Config.Companies.%s is outside its supported range."):format(field[1]))
        end
    end
    if Config.Companies.PageSize > Config.Companies.MaximumPageSize then
        error("[sky_phone] Companies PageSize cannot exceed MaximumPageSize.")
    end
    if type(Config.Companies.RateLimits) ~= "table" then
        error("[sky_phone] Config.Companies.RateLimits must be configured.")
    end
    for _, name in ipairs({ "Read", "Search", "CreateRequest", "Message", "RequestAction", "Profile", "CallAvailability" }) do
        if not valid_integer(Config.Companies.RateLimits[name], 1, 100000) then
            error(("[sky_phone] Companies rate limit '%s' is invalid."):format(name))
        end
    end
    if type(Config.Companies.CallRouting) ~= "table"
        or not valid_integer(Config.Companies.CallRouting.MaxAttempts, 1, 20)
        or not valid_integer(Config.Companies.CallRouting.RingSeconds, 1, 120)
    then
        error("[sky_phone] Config.Companies.CallRouting is invalid.")
    end
    local configured_statuses = {
        new = true,
        assigned = true,
        in_progress = true,
        waiting_customer = true,
        completed = true,
        cancelled = true,
    }
    if type(Config.Companies.Statuses) ~= "table" then
        error("[sky_phone] Config.Companies.Statuses must be configured.")
    end
    for status in pairs(configured_statuses) do
        if Config.Companies.Statuses[status] ~= true then
            error(("[sky_phone] Companies status '%s' must be enabled."):format(status))
        end
    end
    for status, enabled in pairs(Config.Companies.Statuses) do
        if not configured_statuses[status] or enabled ~= true then
            error(("[sky_phone] Companies status '%s' is unsupported."):format(tostring(status)))
        end
    end
    if type(Config.Companies.AvailabilityStatuses) ~= "table" then
        error("[sky_phone] Config.Companies.AvailabilityStatuses must be configured.")
    end
    local configured_availability = { available = true, busy = true, closed = true }
    for _, status in ipairs({ "available", "busy", "closed" }) do
        if Config.Companies.AvailabilityStatuses[status] ~= true then
            error(("[sky_phone] Companies availability status '%s' must be enabled."):format(status))
        end
    end
    for status, enabled in pairs(Config.Companies.AvailabilityStatuses) do
        if not configured_availability[status] or enabled ~= true then
            error(("[sky_phone] Companies availability status '%s' is unsupported."):format(tostring(status)))
        end
    end
    if not valid_array(Config.Companies.Categories, 100) then
        error("[sky_phone] Config.Companies.Categories must be a bounded array.")
    end
    local category_ids = {}
    local configured_service_ids = {}
    for _, category_id in ipairs(Config.Companies.Categories) do
        if type(category_id) ~= "string" or #category_id > 64
            or not category_id:match("^[a-z0-9_-]+$") or category_ids[category_id]
        then
            error("[sky_phone] Companies contains an invalid category ID.")
        end
        category_ids[category_id] = true
    end

    for company_id, definition in pairs(Config.Companies.Definitions) do
        if type(company_id) ~= "string" or #company_id > 64 or not company_id:match("^[a-z0-9_-]+$")
            or type(definition) ~= "table"
            or type(definition.Job) ~= "string" or #definition.Job > 64
            or not definition.Job:match("^[%w_-]+$")
            or not valid_text(definition.Name, 120, false)
            or not category_ids[definition.Category]
        then
            error(("[sky_phone] Company definition '%s' is invalid."):format(tostring(company_id)))
        end
        local description = valid_text(definition.Description or "", Config.Companies.ProfileDescriptionMaxLength, true)
        local district = valid_text(definition.District or "", Config.Companies.DistrictMaxLength, true)
        local location_label = valid_text(
            definition.LocationLabel or definition.Address or "",
            Config.Companies.DistrictMaxLength,
            true
        )
        local address = valid_text(definition.Address or "", Config.Companies.AddressMaxLength, true)
        local logo_url = valid_text(definition.LogoUrl, 2048, false)
        if not description or not district or not location_label or not address
            or type(definition.Public) ~= "boolean" or type(definition.Emergency) ~= "boolean"
            or type(definition.Verified) ~= "boolean" or type(definition.AcceptsRequests) ~= "boolean"
            or not Config.Companies.AvailabilityStatuses[definition.DefaultAvailability]
            or not valid_text(definition.Icon, 64, false)
            or not logo_url or not logo_url:match("^https://[^%s]+$")
            or (definition.Emergency and definition.AcceptsRequests)
        then
            error(("[sky_phone] Company definition '%s' has invalid public profile defaults."):format(company_id))
        end
        definition.Name = trim(definition.Name)
        definition.Description = description
        definition.District = district
        definition.LocationLabel = location_label
        definition.Address = address
        definition.LogoUrl = logo_url
        if definition.Location ~= nil then
            local location_type = type(definition.Location)
            if location_type ~= "table" and location_type ~= "vector3" then
                error(("[sky_phone] Company definition '%s' has invalid location coordinates."):format(company_id))
            end
            local x = tonumber(definition.Location.x)
            local y = tonumber(definition.Location.y)
            local z = tonumber(definition.Location.z)
            if not x or not y or not z or x ~= x or y ~= y or z ~= z
                or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000
            then
                error(("[sky_phone] Company definition '%s' has invalid location coordinates."):format(company_id))
            end
        end
        if definitions_by_job[definition.Job] then
            error(("[sky_phone] Framework job '%s' is assigned to more than one company."):format(definition.Job))
        end
        local line = definition.ServiceLine
        if type(line) ~= "table" then
            error(("[sky_phone] Company '%s' has no service line configuration."):format(company_id))
        end
        local number = SkyPhoneSimNumber.NormalizeService(line.Number, Config.Sim.NumberLength)
        if not number then
            error(("[sky_phone] Company '%s' has an invalid service number."):format(company_id))
        end
        if service_lines_by_number[number] then
            error(("[sky_phone] Service number '%s' is assigned more than once."):format(number))
        end
        if type(line.AutoContact) ~= "boolean" or type(line.CanCall) ~= "boolean"
            or type(line.CanMessage) ~= "boolean"
            or not valid_integer(line.MinimumGrade, 0, 10000)
        then
            error(("[sky_phone] Company '%s' has invalid service line flags or grade."):format(company_id))
        end
        if line.AutoContact and not definition.Public then
            error(("[sky_phone] Private company '%s' cannot create a public system contact."):format(company_id))
        end
        if line.Routing ~= "round_robin" then
            error(("[sky_phone] Company '%s' uses unsupported call routing '%s'."):format(company_id, tostring(line.Routing)))
        end
        if line.CanMessage then
            error(("[sky_phone] Company '%s' enables messaging without a virtual service-line message router."):format(company_id))
        end
        line.Number = number
        definitions[company_id] = definition
        definition_ids[#definition_ids + 1] = company_id
        definitions_by_job[definition.Job] = company_id
        service_lines_by_number[number] = company_id
        for _, permission in ipairs({ "WorkQueue", "Availability", "Assign", "Profile", "Hours", "Services", "Announcement" }) do
            if not definition.Permissions or not valid_integer(definition.Permissions[permission], 0, 10000) then
                error(("[sky_phone] Company '%s' has no valid '%s' grade."):format(company_id, permission))
            end
        end
        local default_services = definition.Services
        if default_services == nil then
            default_services = {}
            definition.Services = default_services
        end
        if not valid_array(default_services, Config.Companies.MaximumServices) then
            error(("[sky_phone] Company '%s' has an invalid default service list."):format(company_id))
        end
        for _, service in ipairs(default_services) do
            if type(service) ~= "table" then
                error(("[sky_phone] Company '%s' has an invalid default service."):format(company_id))
            end
            local title = valid_text(service.Title, Config.Companies.ServiceTitleMaxLength, false)
            local service_description = valid_text(
                service.Description or "",
                Config.Companies.ServiceDescriptionMaxLength,
                true
            )
            local price = valid_text(service.Price or "", Config.Companies.ServicePriceMaxLength, true)
            if not valid_service_id(service.Id) or not title or not service_description or not price
                or type(service.RequestsEnabled) ~= "boolean"
            then
                error(("[sky_phone] Company '%s' has an invalid default service."):format(company_id))
            end
            service.Title = title
            service.Description = service_description
            service.Price = price
            if configured_service_ids[service.Id] then
                error(("[sky_phone] Default company service ID '%s' is configured more than once."):format(service.Id))
            end
            configured_service_ids[service.Id] = true
        end
    end

    table.sort(definition_ids, function(left, right)
        local left_name = definitions[left].Name:lower()
        local right_name = definitions[right].Name:lower()
        return left_name == right_name and left < right or left_name < right_name
    end)
end

local function seed_companies()
    if #definition_ids > 0 then
        local placeholders = {}
        local numbers = {}
        for index, company_id in ipairs(definition_ids) do
            placeholders[index] = "?"
            numbers[index] = definitions[company_id].ServiceLine.Number
        end
        local collisions = Bridge.Database.Query(([[
            SELECT `phone_number` FROM `sky_phone_sims`
            WHERE `phone_number` IN (%s)
            LIMIT 1
        ]]):format(table.concat(placeholders, ", ")), numbers)
        if collisions[1] then
            error(("[sky_phone] Company service number '%s' collides with an existing SIM."):format(
                tostring(collisions[1].phone_number)
            ))
        end
    end

    for _, company_id in ipairs(definition_ids) do
        local definition = definitions[company_id]
        local location = definition.Location
        if location then
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_company_profiles`
                    (`company_id`, `description`, `district`, `location_label`, `address`,
                        `location_x`, `location_y`, `location_z`, `availability`, `accepts_requests`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                company_id,
                definition.Description or "",
                definition.District or "",
                definition.LocationLabel or definition.Address or "",
                definition.Address or "",
                location.x,
                location.y,
                location.z,
                definition.DefaultAvailability or "closed",
                definition.AcceptsRequests and 1 or 0,
            })
        else
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_company_profiles`
                    (`company_id`, `description`, `district`, `location_label`, `address`,
                        `availability`, `accepts_requests`)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]], {
                company_id,
                definition.Description or "",
                definition.District or "",
                definition.LocationLabel or definition.Address or "",
                definition.Address or "",
                definition.DefaultAvailability or "closed",
                definition.AcceptsRequests and 1 or 0,
            })
        end
        for index, service in ipairs(definition.Services or {}) do
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_company_services`
                    (`id`, `company_id`, `title`, `description`, `price_text`, `requests_enabled`, `active`, `sort_order`)
                VALUES (?, ?, ?, ?, ?, ?, 1, ?)
            ]], {
                service.Id,
                company_id,
                service.Title,
                service.Description or "",
                service.Price or "",
                service.RequestsEnabled and 1 or 0,
                index,
            })
            local seeded = Bridge.Database.Query(
                "SELECT `company_id` FROM `sky_phone_company_services` WHERE `id` = ? LIMIT 1",
                { service.Id }
            )
            if not seeded[1] or seeded[1].company_id ~= company_id then
                error(("[sky_phone] Default service ID '%s' collides with another company."):format(service.Id))
            end
        end
    end

end

local function tombstone_removed_companies()
    local profiles = Bridge.Database.Query([[
        SELECT DISTINCT profile.`company_id`
        FROM `sky_phone_company_profiles` profile
        INNER JOIN `sky_phone_company_requests` request ON request.`company_id` = profile.`company_id`
        WHERE request.`status` NOT IN ('completed', 'cancelled')
    ]], {})
    for _, profile in ipairs(profiles) do
        if not definitions[profile.company_id] then
            local mutation_token = uuid()
            if not Bridge.Database.Transaction({
                {
                    query = [[
                        UPDATE `sky_phone_company_requests`
                        SET `status` = 'cancelled', `revision` = `revision` + 1,
                            `customer_unread` = `customer_unread` + 1,
                            `cancelled_at` = CURRENT_TIMESTAMP, `mutation_token` = ?
                        WHERE `company_id` = ? AND `status` NOT IN ('completed', 'cancelled')
                    ]],
                    params = { mutation_token, profile.company_id },
                },
                {
                    query = [[
                        INSERT INTO `sky_phone_company_request_events`
                            (`id`, `request_id`, `event_type`, `actor_type`, `to_status`, `detail`)
                        SELECT UUID(), `id`, 'cancelled', 'system', 'cancelled', 'company_removed'
                        FROM `sky_phone_company_requests`
                        WHERE `company_id` = ? AND `mutation_token` = ?
                    ]],
                    params = { profile.company_id, mutation_token },
                },
            }) then
                error(("[sky_phone] Could not tombstone removed company '%s'."):format(
                    tostring(profile.company_id)
                ))
            end
        end
    end
end

local function service_line_payload(company_id)
    local definition = definitions[company_id]
    if not Config.Companies.Enabled or not definition then
        return nil
    end
    local line = definition.ServiceLine
    return {
        companyId = company_id,
        number = line.Number,
        name = definition.Name,
        canCall = line.CanCall == true,
        canMessage = line.CanMessage == true,
        autoContact = line.AutoContact == true,
        routing = line.Routing,
        icon = definition.Icon,
    }
end

function SkyPhoneCompanies.GetServiceLine(number)
    local normalized = SkyPhoneSimNumber.NormalizeService(number, Config.Sim.NumberLength)
    return normalized and service_line_payload(service_lines_by_number[normalized]) or nil
end

function SkyPhoneCompanies.GetServiceLineForCompany(company_id)
    return type(company_id) == "string" and service_line_payload(company_id) or nil
end

function SkyPhoneCompanies.IsServiceNumber(number)
    local normalized = SkyPhoneSimNumber.NormalizeService(number, Config.Sim.NumberLength)
    return normalized ~= nil and service_lines_by_number[normalized] ~= nil
end

function SkyPhoneCompanies.IsSystemContactNumber(number)
    if not Config.Companies.Enabled then
        return false
    end
    local normalized = SkyPhoneSimNumber.NormalizeService(number, Config.Sim.NumberLength)
    local company_id = normalized and service_lines_by_number[normalized] or nil
    local definition = company_id and definitions[company_id] or nil
    return definition ~= nil and definition.Public == true and definition.ServiceLine.AutoContact == true
end

function SkyPhoneCompanies.GetSystemContacts()
    local contacts = {}
    if not Config.Companies.Enabled then
        return contacts
    end
    for _, company_id in ipairs(definition_ids) do
        local definition = definitions[company_id]
        local line = definition.ServiceLine
        if definition.Public and line.AutoContact then
            contacts[#contacts + 1] = {
                id = "company:" .. company_id,
                companyId = company_id,
                name = definition.Name,
                organization = definition.Name,
                phone_number = line.Number,
                avatar_url = definition.LogoUrl,
                source = "company",
                readonly = true,
                canCall = line.CanCall == true,
                canMessage = line.CanMessage == true,
                verified = definition.Verified == true,
            }
        end
    end
    return contacts
end

function SkyPhoneCompanies.ClearCallAvailability(source)
    call_availability[tonumber(source) or source] = nil
end

local function current_device(source, registered_required)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "request_failed" }
    end
    if not device.sim_id then
        return nil, { success = false, error = "no_sim" }
    end
    if registered_required and (device.sim_type ~= "registered" or not device.registered_at) then
        return nil, { success = false, error = "anonymous_sim" }
    end
    return device
end

local function membership(source)
    local job = Bridge.Framework.GetJob(source)
    local company_id = definitions_by_job[job.name]
    if not company_id then
        return nil
    end
    return {
        company_id = company_id,
        definition = definitions[company_id],
        grade = tonumber(job.grade) or 0,
        grade_label = job.gradeLabel or job.label or "",
    }
end

local function require_permission(source, permission)
    local member = membership(source)
    if not member then
        return nil, { success = false, error = "not_authorized" }
    end
    local minimum = permission_grade(member.definition, permission)
    if not minimum or member.grade < minimum then
        return nil, { success = false, error = "not_authorized" }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "not_authorized" }
    end
    member.identifier = identifier
    return member
end

local function call_member(source)
    local member = membership(source)
    if not member then
        return nil
    end
    local minimum = tonumber(member.definition.ServiceLine.MinimumGrade) or 0
    if member.grade < minimum then
        return nil
    end
    return member
end

function SkyPhoneCompanies.CanAnswerCompanyCall(source, company_id, imei, sim_id)
    source = tonumber(source)
    if not Config.Companies.Enabled or not source or type(company_id) ~= "string"
        or type(imei) ~= "string" or type(sim_id) ~= "string"
    then
        return false
    end
    local readiness = call_availability[source]
    local member = readiness and call_member(source) or nil
    return member ~= nil
        and member.company_id == company_id
        and member.definition.ServiceLine.CanCall == true
        and readiness.company_id == company_id
        and readiness.imei == imei
        and readiness.sim_id == sim_id
end

function SkyPhoneCompanies.CanPlaceCompanyCall(source, company_id)
    source = tonumber(source)
    if not Config.Companies.Enabled or not source or type(company_id) ~= "string" then
        return false
    end
    local member = call_member(source)
    return member ~= nil and member.company_id == company_id
        and member.definition.ServiceLine.CanCall == true
end

function SkyPhoneCompanies.GetCallTargets(company_id)
    local targets = {}
    local definition = definitions[company_id]
    if not Config.Companies.Enabled or not definition or not definition.ServiceLine.CanCall then
        return targets
    end
    local online = {}
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        online[tonumber(player_source) or player_source] = true
    end
    for source, readiness in pairs(call_availability) do
        local member = online[source] and call_member(source) or nil
        local device = member and SkyPhone.LoadDevice(readiness.imei) or nil
        local device_slots = device and SkyPhone.FindDeviceSlots(source, readiness.imei) or {}
        local readiness_valid = member and device and device_slots[1]
            and member.company_id == readiness.company_id
            and device.sim_id == readiness.sim_id
            and device.sim_type == "registered"
            and device.registered_at ~= nil
        if not readiness_valid then
            call_availability[source] = nil
        elseif readiness.company_id == company_id then
            targets[#targets + 1] = {
                source = source,
                simId = device.sim_id,
                phoneNumber = device.phone_number,
                imei = device.imei,
                deviceName = device.device_name,
            }
        end
    end
    table.sort(targets, function(left, right)
        return left.source < right.source
    end)
    if #targets < 2 then
        return targets
    end
    local start = (round_robin_positions[company_id] or 0) % #targets + 1
    local ordered = {}
    for offset = 0, #targets - 1 do
        ordered[#ordered + 1] = targets[(start + offset - 1) % #targets + 1]
    end
    round_robin_positions[company_id] = start
    return ordered
end

local function profile_row(company_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`company_id`, p.`description`, p.`district`, p.`location_label`, p.`address`,
            p.`location_x`, p.`location_y`, p.`location_z`, p.`availability`,
            UNIX_TIMESTAMP(p.`availability_updated_at`) AS `availability_updated_at_unix`,
            UNIX_TIMESTAMP(p.`availability_expires_at`) AS `availability_expires_at_unix`,
            p.`logo_media_id`, p.`cover_media_id`, p.`accepts_requests`, p.`revision`,
            UNIX_TIMESTAMP(p.`updated_at`) AS `updated_at_unix`,
            logo.`url` AS `logo_url`, cover.`url` AS `cover_url`
        FROM `sky_phone_company_profiles` p
        LEFT JOIN `sky_phone_media` logo ON logo.`id` = p.`logo_media_id`
        LEFT JOIN `sky_phone_media` cover ON cover.`id` = p.`cover_media_id`
        WHERE p.`company_id` = ?
        LIMIT 1
    ]], { company_id })
    return rows[1]
end

local function company_services(company_id, include_inactive)
    local condition = include_inactive and " AND `archived` = 0"
        or " AND `archived` = 0 AND `active` = 1"
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `title`, `description`, `price_text`, `requests_enabled`, `active`
        FROM `sky_phone_company_services`
        WHERE `company_id` = ?%s
        ORDER BY `sort_order`, `title`, `id`
    ]]):format(condition), { company_id })
    local services = {}
    for _, row in ipairs(rows) do
        services[#services + 1] = {
            id = row.id,
            title = row.title,
            description = row.description,
            priceText = row.price_text ~= "" and row.price_text or nil,
            acceptsRequests = tonumber(row.requests_enabled) == 1,
            active = tonumber(row.active) == 1,
        }
    end
    return services
end

local function company_hours(company_id)
    local rows = Bridge.Database.Query([[
        SELECT `weekday`, `is_closed`, `opens_at`, `closes_at`
        FROM `sky_phone_company_hours`
        WHERE `company_id` = ?
        ORDER BY `weekday`
    ]], { company_id })
    local hours = {}
    for _, row in ipairs(rows) do
        hours[#hours + 1] = {
            day = tonumber(row.weekday),
            isClosed = tonumber(row.is_closed) == 1,
            opensAt = row.opens_at,
            closesAt = row.closes_at,
        }
    end
    return hours
end

local function current_announcement(company_id)
    local rows = Bridge.Database.Query([[
        SELECT `body`, UNIX_TIMESTAMP(`expires_at`) AS `expires_at_unix`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_company_announcements`
        WHERE `company_id` = ? AND `active` = 1
            AND (`expires_at` IS NULL OR `expires_at` > CURRENT_TIMESTAMP)
        ORDER BY `created_at` DESC
        LIMIT 1
    ]], { company_id })
    local row = rows[1]
    return row and {
        body = row.body,
        expiresAt = iso_time(row.expires_at_unix),
        publishedAt = iso_time(row.created_at_unix),
    } or nil
end

local function company_payload(company_id, include_inactive_services)
    local definition = definitions[company_id]
    local row = definition and profile_row(company_id) or nil
    if not definition or not row then
        return nil
    end
    local services = company_services(company_id, include_inactive_services)
    local availability = row.availability
    local availability_expires = tonumber(row.availability_expires_at_unix)
    if availability_expires and availability_expires <= os.time() then
        availability = definition.DefaultAvailability or "closed"
    end
    local location = nil
    local x = tonumber(row.location_x)
    local y = tonumber(row.location_y)
    local z = tonumber(row.location_z)
    if x and y and z then
        location = {
            address = row.address,
            district = row.district,
            label = row.location_label,
            coords = { x = x, y = y, z = z },
        }
    end
    local line = definition.ServiceLine
    return {
        id = company_id,
        name = definition.Name,
        categoryId = definition.Category,
        categoryName = definition.Category,
        verified = definition.Verified == true,
        description = row.description,
        availability = availability,
        availabilityUpdatedAt = iso_time(row.availability_updated_at_unix)
            or iso_time(row.updated_at_unix),
        acceptsRequests = tonumber(row.accepts_requests) == 1 and not definition.Emergency,
        phoneNumber = line and line.Number or nil,
        canCall = line and line.CanCall == true or false,
        canMessage = line and line.CanMessage == true or false,
        location = location,
        logoUrl = row.logo_url or definition.LogoUrl,
        coverUrl = row.cover_url,
        serviceSummary = services[1] and services[1].title or "",
        announcement = current_announcement(company_id),
        services = services,
        hours = company_hours(company_id),
        revision = tonumber(row.revision) or 1,
        updatedAtUnix = tonumber(row.updated_at_unix) or 0,
    }
end

local function public_company(company_id)
    local definition = definitions[company_id]
    if not definition or not definition.Public then
        return nil
    end
    return company_payload(company_id, false)
end

local function category_payloads()
    local categories = {}
    for _, category_id in ipairs(Config.Companies.Categories or {}) do
        categories[#categories + 1] = { id = category_id, name = category_id }
    end
    return categories
end

local function allow_read(source, operation)
    if not Config.Companies.Enabled then
        return nil, { success = false, error = "service_unavailable" }
    end
    local limit = Config.Companies.RateLimits[operation] or Config.Companies.RateLimits.Read
    if not SkyPhone.AllowOperation(source, "companies_" .. operation:lower(), limit, 60) then
        return nil, { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    return session
end

local function cleanup_retained_data()
    local cutoff = os.time() - Config.Companies.RetentionDays * 86400
    local success = Bridge.Database.Transaction({
        {
            query = [[
                DELETE FROM `sky_phone_company_requests`
                WHERE `status` IN ('completed', 'cancelled')
                    AND COALESCE(`completed_at`, `cancelled_at`, `updated_at`) < FROM_UNIXTIME(?)
            ]],
            params = { cutoff },
        },
        {
            query = [[
                DELETE FROM `sky_phone_company_audit`
                WHERE `created_at` < FROM_UNIXTIME(?)
            ]],
            params = { cutoff },
        },
        {
            query = [[
                DELETE FROM `sky_phone_company_announcements`
                WHERE (`active` = 0 OR `expires_at` <= CURRENT_TIMESTAMP)
                    AND `created_at` < FROM_UNIXTIME(?)
            ]],
            params = { cutoff },
        },
    })
    if not success then
        Bridge.Debug("error", "[sky_phone] Companies retention cleanup failed.")
    end
end

validate_configuration()
seed_companies()
tombstone_removed_companies()
cleanup_retained_data()

CreateThread(function()
    while true do
        Wait(24 * 60 * 60 * 1000)
        cleanup_retained_data()
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local online = {}
        for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
            online[tonumber(player_source) or player_source] = true
        end
        for source, readiness in pairs(call_availability) do
            local member = online[source] and call_member(source) or nil
            if not member or member.company_id ~= readiness.company_id
                or member.definition.ServiceLine.CanCall ~= true
            then
                call_availability[source] = nil
            end
        end
    end
end)

local function company_summary(company)
    return {
        id = company.id,
        name = company.name,
        categoryId = company.categoryId,
        categoryName = company.categoryName,
        verified = company.verified,
        description = company.description,
        availability = company.availability,
        availabilityUpdatedAt = company.availabilityUpdatedAt,
        acceptsRequests = company.acceptsRequests,
        phoneNumber = company.phoneNumber,
        canCall = company.canCall,
        canMessage = company.canMessage,
        location = company.location,
        logoUrl = company.logoUrl,
        serviceSummary = company.serviceSummary,
        announcement = company.announcement,
    }
end

local function search_score(company, search)
    if search == "" then
        return 0
    end
    local name = company.name:lower()
    if name:sub(1, #search) == search then
        return 4
    end
    if name:find(search, 1, true) then
        return 3
    end
    local values = {
        company.categoryId,
        company.description,
        company.location and company.location.district or "",
        company.location and company.location.address or "",
        company.serviceSummary,
    }
    for _, value in ipairs(values) do
        if tostring(value):lower():find(search, 1, true) then
            return 1
        end
    end
    for _, service in ipairs(company.services) do
        if service.title:lower():find(search, 1, true)
            or service.description:lower():find(search, 1, true)
        then
            return 1
        end
    end
    return -1
end

Bridge.Callbacks.Register("sky_phone:companies:list", function(source, data)
    local session, error_response = allow_read(source, "Search")
    if not session then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local search = valid_text(data.search or "", 80, true)
    if not search then
        return { success = false, error = "invalid_request" }
    end
    search = search:lower()
    local category_id = data.categoryId
    if category_id ~= nil then
        local category_valid = false
        for _, configured in ipairs(Config.Companies.Categories or {}) do
            if category_id == configured then
                category_valid = true
                break
            end
        end
        if not category_valid then
            return { success = false, error = "invalid_request" }
        end
    end
    local availability = data.availability
    if availability ~= nil and not Config.Companies.AvailabilityStatuses[availability] then
        return { success = false, error = "invalid_request" }
    end
    if data.acceptsRequests ~= nil and type(data.acceptsRequests) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if data.hasLocation ~= nil and type(data.hasLocation) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local sort = data.sort or "relevance"
    if sort ~= "relevance" and sort ~= "name" and sort ~= "updated" then
        return { success = false, error = "invalid_request" }
    end
    local cursor = data.cursor == nil and 0 or valid_integer(data.cursor, 0, 100000)
    if not cursor then
        return { success = false, error = "invalid_request" }
    end

    local matches = {}
    for _, company_id in ipairs(definition_ids) do
        local company = public_company(company_id)
        if company then
            local score = search_score(company, search)
            if score >= 0
                and (not category_id or company.categoryId == category_id)
                and (not availability or company.availability == availability)
                and (data.acceptsRequests ~= true or company.acceptsRequests)
                and (data.hasLocation ~= true or company.location ~= nil)
            then
                matches[#matches + 1] = { company = company, score = score }
            end
        end
    end
    table.sort(matches, function(left, right)
        if sort == "updated" and left.company.updatedAtUnix ~= right.company.updatedAtUnix then
            return left.company.updatedAtUnix > right.company.updatedAtUnix
        end
        if sort == "relevance" and left.score ~= right.score then
            return left.score > right.score
        end
        local left_name = left.company.name:lower()
        local right_name = right.company.name:lower()
        return left_name == right_name and left.company.id < right.company.id or left_name < right_name
    end)

    local companies = {}
    local page_size = math.min(Config.Companies.PageSize, Config.Companies.MaximumPageSize)
    local last_index = math.min(#matches, cursor + page_size)
    for index = cursor + 1, last_index do
        companies[#companies + 1] = company_summary(matches[index].company)
    end
    return {
        success = true,
        data = {
            companies = companies,
            categories = category_payloads(),
            nextCursor = last_index < #matches and tostring(last_index) or nil,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:companies:get", function(source, data)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local company_id = type(data) == "table" and data.companyId or nil
    local company = type(company_id) == "string" and public_company(company_id) or nil
    if not company then
        return { success = false, error = "company_not_found" }
    end
    company.updatedAtUnix = nil
    return { success = true, data = { company = company } }
end)

local function decode_request_cursor(value)
    if value == nil then
        return nil, nil
    end
    if type(value) ~= "string" or #value > 64 then
        return false, false
    end
    local timestamp, request_id = value:match("^(%d+):(.+)$")
    timestamp = valid_integer(timestamp, 1, 4102444800)
    if not timestamp or not valid_uuid(request_id) then
        return false, false
    end
    return timestamp, request_id
end

local function encode_request_cursor(row)
    return ("%s:%s"):format(tostring(math.floor(tonumber(row.updated_at_unix) or 0)), row.id)
end

local function request_row(request_id)
    local rows = Bridge.Database.Query([[
        SELECT r.`id`, r.`company_id`, r.`service_id`, r.`customer_sim_id`, r.`subject`, r.`description`,
            r.`status`, r.`assigned_identifier`, r.`customer_unread`,
            r.`company_activity_revision`, r.`revision`,
            UNIX_TIMESTAMP(r.`created_at`) AS `created_at_unix`,
            UNIX_TIMESTAMP(r.`updated_at`) AS `updated_at_unix`, service.`title` AS `service_title`,
            logo.`url` AS `company_logo_url`
        FROM `sky_phone_company_requests` r
        LEFT JOIN `sky_phone_company_services` service ON service.`id` = r.`service_id`
        LEFT JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = r.`company_id`
        LEFT JOIN `sky_phone_media` logo ON logo.`id` = profile.`logo_media_id`
        WHERE r.`id` = ?
        LIMIT 1
    ]], { request_id })
    return rows[1]
end

local function request_summary(row, audience, identifier)
    local definition = definitions[row.company_id]
    local assigned_label = nil
    if row.assigned_identifier then
        assigned_label = identifier and row.assigned_identifier == identifier and "you" or "assigned"
    end
    local unread_count
    if audience == "customer" then
        unread_count = tonumber(row.customer_unread) or 0
    else
        local relevant = not terminal_statuses[row.status]
            and (row.status == "new" or row.assigned_identifier == identifier)
        unread_count = relevant and math.max(
            0,
            (tonumber(row.company_activity_revision) or 1)
                - (tonumber(row.company_read_revision) or 0)
        ) or 0
    end
    return {
        id = row.id,
        companyId = row.company_id,
        companyName = definition and definition.Name or row.company_id,
        companyLogoUrl = row.company_logo_url,
        serviceId = row.service_id,
        serviceName = row.service_title,
        subject = row.subject,
        status = row.status,
        assignedLabel = assigned_label,
        unreadCount = unread_count,
        createdAt = iso_time(row.created_at_unix),
        updatedAt = iso_time(row.updated_at_unix),
    }
end

local function request_access(source, request_id)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local row = request_row(request_id)
    if not row then
        return nil, { success = false, error = "request_not_found" }
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "request_failed" }
    end
    if device.sim_id and device.sim_id == row.customer_sim_id
        and device.sim_type == "registered" and device.registered_at
    then
        return { audience = "customer", row = row, device = device }
    end
    local member = membership(source)
    if not member or member.company_id ~= row.company_id
        or member.grade < permission_grade(member.definition, "WorkQueue")
    then
        return nil, { success = false, error = "request_not_found" }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "not_authorized" }
    end
    member.identifier = identifier
    return { audience = "company", row = row, device = device, member = member }
end

local function can_handle_request(access)
    if access.audience ~= "company" then
        return false
    end
    return access.row.assigned_identifier == access.member.identifier
        or access.member.grade >= permission_grade(access.member.definition, "Assign")
end

local function request_actions(access)
    local row = access.row
    local definition = definitions[row.company_id]
    local active = not terminal_statuses[row.status]
    if access.audience == "customer" then
        return {
            allowedStatuses = {},
            canAssign = false,
            canCall = definition ~= nil and definition.ServiceLine.CanCall == true,
            canCancel = active,
            canClaim = false,
            canReply = active,
        }
    end
    local handler = can_handle_request(access)
    local allowed = {}
    if handler then
        for _, status in ipairs({ "in_progress", "waiting_customer", "completed", "cancelled" }) do
            if status_transitions[row.status] and status_transitions[row.status][status] then
                allowed[#allowed + 1] = status
            end
        end
    end
    return {
        allowedStatuses = allowed,
        canAssign = active and access.member.grade >= permission_grade(access.member.definition, "Assign"),
        canCall = active
            and access.member.definition.ServiceLine.CanCall == true
            and access.member.grade >= (tonumber(access.member.definition.ServiceLine.MinimumGrade) or 0),
        canCancel = active and handler,
        canClaim = row.status == "new" and not row.assigned_identifier,
        canReply = active and handler,
    }
end

local function request_detail(access)
    local row = request_row(access.row.id)
    if not row then
        return nil
    end
    access.row = row
    if access.audience == "customer" then
        Bridge.Database.Query(
            "UPDATE `sky_phone_company_requests` SET `customer_unread` = 0, `updated_at` = `updated_at` WHERE `id` = ?",
            { row.id }
        )
        row.customer_unread = 0
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_company_request_reads`
                (`request_id`, `reader_identifier`, `read_revision`)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                `read_revision` = GREATEST(`read_revision`, VALUES(`read_revision`)),
                `updated_at` = CURRENT_TIMESTAMP
        ]], { row.id, access.member.identifier, row.company_activity_revision })
        row.company_read_revision = row.company_activity_revision
    end
    local messages = Bridge.Database.Query([[
        SELECT `id`, `sender_type`, `sender_identifier`, `sender_sim_id`, `body`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_company_request_messages`
        WHERE `request_id` = ?
        ORDER BY `created_at`, `id`
    ]], { row.id })
    local message_payloads = {}
    for _, message in ipairs(messages) do
        local mine = access.audience == "customer"
            and message.sender_type == "customer" and message.sender_sim_id == row.customer_sim_id
            or access.audience == "company"
                and message.sender_type == "company" and message.sender_identifier == access.member.identifier
        message_payloads[#message_payloads + 1] = {
            id = message.id,
            author = message.sender_type,
            authorLabel = mine and "you" or message.sender_type,
            body = message.body,
            createdAt = iso_time(message.created_at_unix),
            isMine = mine,
        }
    end
    local events = Bridge.Database.Query([[
        SELECT `id`, `event_type`, `to_status`, UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_company_request_events`
        WHERE `request_id` = ?
        ORDER BY `created_at`, `id`
    ]], { row.id })
    local event_payloads = {}
    for _, event in ipairs(events) do
        local event_type = event.event_type
        if event_type == "status" then
            event_type = event.to_status == "completed" and "completed" or "status_changed"
        end
        event_payloads[#event_payloads + 1] = {
            id = event.id,
            type = event_type,
            status = event.to_status,
            createdAt = iso_time(event.created_at_unix),
        }
    end
    local media_rows = Bridge.Database.Query([[
        SELECT media.`id`, media.`url`
        FROM `sky_phone_company_request_media` request_media
        INNER JOIN `sky_phone_media` media ON media.`id` = request_media.`media_id`
        WHERE request_media.`request_id` = ?
        ORDER BY request_media.`sort_order`
    ]], { row.id })
    local payload = request_summary(
        row,
        access.audience,
        access.member and access.member.identifier or nil
    )
    payload.description = row.description
    payload.revision = tonumber(row.revision) or 1
    local definition = definitions[row.company_id]
    payload.phoneNumber = definition and definition.ServiceLine.Number or nil
    payload.messages = message_payloads
    payload.events = event_payloads
    payload.media = media_rows
    payload.actions = request_actions(access)
    return payload
end

local function list_request_rows(query, parameters, audience, identifier)
    local rows = Bridge.Database.Query(query, parameters)
    local has_more = #rows > Config.Companies.PageSize
    if has_more then
        rows[#rows] = nil
    end
    local requests = {}
    for _, row in ipairs(rows) do
        requests[#requests + 1] = request_summary(row, audience, identifier)
    end
    return requests, has_more and encode_request_cursor(rows[#rows]) or nil
end

local request_list_select = [[
    SELECT r.`id`, r.`company_id`, r.`service_id`, r.`customer_sim_id`, r.`subject`, r.`status`,
        r.`assigned_identifier`, r.`customer_unread`, r.`company_activity_revision`, r.`revision`,
        UNIX_TIMESTAMP(r.`created_at`) AS `created_at_unix`,
        UNIX_TIMESTAMP(r.`updated_at`) AS `updated_at_unix`, service.`title` AS `service_title`,
        logo.`url` AS `company_logo_url`, NULL AS `company_read_revision`
    FROM `sky_phone_company_requests` r
    LEFT JOIN `sky_phone_company_services` service ON service.`id` = r.`service_id`
    LEFT JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = r.`company_id`
    LEFT JOIN `sky_phone_media` logo ON logo.`id` = profile.`logo_media_id`
]]

local company_request_list_select = [[
    SELECT r.`id`, r.`company_id`, r.`service_id`, r.`customer_sim_id`, r.`subject`, r.`status`,
        r.`assigned_identifier`, r.`customer_unread`, r.`company_activity_revision`, r.`revision`,
        UNIX_TIMESTAMP(r.`created_at`) AS `created_at_unix`,
        UNIX_TIMESTAMP(r.`updated_at`) AS `updated_at_unix`, service.`title` AS `service_title`,
        logo.`url` AS `company_logo_url`, company_read.`read_revision` AS `company_read_revision`
    FROM `sky_phone_company_requests` r
    LEFT JOIN `sky_phone_company_services` service ON service.`id` = r.`service_id`
    LEFT JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = r.`company_id`
    LEFT JOIN `sky_phone_media` logo ON logo.`id` = profile.`logo_media_id`
    LEFT JOIN `sky_phone_company_request_reads` company_read
        ON company_read.`request_id` = r.`id` AND company_read.`reader_identifier` = ?
]]

local function context_request_rows(company_id, identifier, own)
    local condition = own
        and " AND r.`assigned_identifier` = ? AND r.`status` NOT IN ('completed', 'cancelled')"
        or ""
    local parameters = { identifier, company_id }
    if own then
        parameters[#parameters + 1] = identifier
    end
    parameters[#parameters + 1] = 4
    local rows = Bridge.Database.Query(company_request_list_select .. ([=[
        WHERE r.`company_id` = ?%s
        ORDER BY r.`updated_at` DESC, r.`id` DESC
        LIMIT ?
    ]=]):format(condition), parameters)
    local requests = {}
    for _, row in ipairs(rows) do
        requests[#requests + 1] = request_summary(row, "company", identifier)
    end
    return requests
end

local function work_context(source)
    local member = membership(source)
    if not member or member.grade < permission_grade(member.definition, "WorkQueue") then
        return {
            authorized = false,
            callAvailable = false,
            company = nil,
            metrics = { assigned = 0, completedToday = 0, new = 0, waiting = 0 },
            ownRequests = {},
            recentRequests = {},
            permissions = {
                canAssign = false,
                canManageAnnouncement = false,
                canManageHours = false,
                canManageProfile = false,
                canManageServices = false,
                canSetAvailability = false,
                canTakeCalls = false,
            },
            role = nil,
            unreadCount = 0,
        }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end
    member.identifier = identifier
    local rows = Bridge.Database.Query([[
        SELECT
            COALESCE(SUM(request.`status` = 'new'), 0) AS `new_count`,
            COALESCE(SUM(request.`assigned_identifier` = ?
                AND request.`status` NOT IN ('completed', 'cancelled')), 0) AS `assigned_count`,
            COALESCE(SUM(request.`status` = 'waiting_customer'), 0) AS `waiting_count`,
            COALESCE(SUM(request.`status` = 'completed'
                AND DATE(request.`completed_at`) = CURRENT_DATE), 0) AS `completed_today`,
            COALESCE(SUM(CASE
                WHEN request.`status` NOT IN ('completed', 'cancelled')
                    AND (request.`status` = 'new' OR request.`assigned_identifier` = ?)
                    AND COALESCE(company_read.`read_revision`, 0) < request.`company_activity_revision`
                    THEN request.`company_activity_revision` - COALESCE(company_read.`read_revision`, 0)
                ELSE 0
            END), 0) AS `unread_count`
        FROM `sky_phone_company_requests` request
        LEFT JOIN `sky_phone_company_request_reads` company_read
            ON company_read.`request_id` = request.`id` AND company_read.`reader_identifier` = ?
        WHERE request.`company_id` = ?
    ]], { identifier, identifier, identifier, member.company_id })
    local metrics = rows[1] or {}
    local permissions = {
        canAssign = member.grade >= permission_grade(member.definition, "Assign"),
        canManageAnnouncement = member.grade >= permission_grade(member.definition, "Announcement"),
        canManageHours = member.grade >= permission_grade(member.definition, "Hours"),
        canManageProfile = member.grade >= permission_grade(member.definition, "Profile"),
        canManageServices = member.grade >= permission_grade(member.definition, "Services"),
        canSetAvailability = member.grade >= permission_grade(member.definition, "Availability"),
        canTakeCalls = member.definition.ServiceLine.CanCall == true
            and member.grade >= (tonumber(member.definition.ServiceLine.MinimumGrade) or 0),
    }
    local manager = permissions.canAssign or permissions.canManageAnnouncement
        or permissions.canManageHours or permissions.canManageProfile or permissions.canManageServices
    local readiness = call_availability[source]
    local company = company_payload(member.company_id, true)
    company.updatedAtUnix = nil
    return {
        authorized = true,
        callAvailable = permissions.canTakeCalls and readiness ~= nil
            and readiness.company_id == member.company_id,
        company = company,
        metrics = {
            new = tonumber(metrics.new_count) or 0,
            assigned = tonumber(metrics.assigned_count) or 0,
            waiting = tonumber(metrics.waiting_count) or 0,
            completedToday = tonumber(metrics.completed_today) or 0,
        },
        ownRequests = context_request_rows(member.company_id, identifier, true),
        recentRequests = context_request_rows(member.company_id, identifier, false),
        permissions = permissions,
        role = manager and "manager" or "employee",
        unreadCount = tonumber(metrics.unread_count) or 0,
    }
end

local function notify_sim(sim_id, event_name, payload)
    local devices = Bridge.Database.Query([[
        SELECT d.`imei`, d.`device_name`, settings.`payload` AS `settings`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_device_data` settings
            ON settings.`device_imei` = d.`imei` AND settings.`namespace` = 'settings'
        WHERE d.`sim_id` = ?
    ]], { sim_id })
    for _, device in ipairs(devices) do
        for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
            local target = tonumber(player_source) or player_source
            if SkyPhone.FindDeviceSlots(target, device.imei)[1] then
                local event_payload = {}
                for key, value in pairs(payload) do
                    event_payload[key] = value
                end
                event_payload.device = {
                    imei = device.imei,
                    name = device.device_name,
                    settings = device.settings,
                }
                TriggerClientEvent(event_name, target, event_payload)
            end
        end
    end
end

local function notify_source(source, event_name, payload)
    local session = SkyPhone.RequireSession(source)
    if not session then
        return
    end
    local rows = Bridge.Database.Query([[
        SELECT d.`device_name`, settings.`payload` AS `settings`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_device_data` settings
            ON settings.`device_imei` = d.`imei` AND settings.`namespace` = 'settings'
        WHERE d.`imei` = ?
        LIMIT 1
    ]], { session.imei })
    if not rows[1] then
        return
    end
    local event_payload = {}
    for key, value in pairs(payload) do
        event_payload[key] = value
    end
    event_payload.device = {
        imei = session.imei,
        name = rows[1].device_name,
        settings = rows[1].settings,
    }
    TriggerClientEvent(event_name, source, event_payload)
end

local function notify_company(company_id, event_name, payload, excluded_source)
    local definition = definitions[company_id]
    if not definition then
        return
    end
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(player_source) or player_source
        if target ~= excluded_source then
            local job = Bridge.Framework.GetJob(target)
            if job.name == definition.Job and (tonumber(job.grade) or 0) >= permission_grade(definition, "WorkQueue") then
                notify_source(target, event_name, payload)
            end
        end
    end
end

local function notify_identifier(identifier, company_id, event_name, payload)
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(player_source) or player_source
        local member = membership(target)
        if member and member.company_id == company_id
            and member.grade >= permission_grade(member.definition, "WorkQueue")
            and Bridge.Framework.GetIdentifier(target) == identifier
        then
            notify_source(target, event_name, payload)
        end
    end
end

local function emit_public_change(company_id)
    local definition = definitions[company_id]
    if not definition then
        return
    end
    notify_company(company_id, "sky_phone:companies:changed", {
        area = "work",
        companyId = company_id,
    })
    if not definition.Public then
        return
    end
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        notify_source(tonumber(player_source) or player_source, "sky_phone:companies:changed", {
            area = "directory",
            companyId = company_id,
        })
    end
end

local function emit_request_change(row, customer, company, excluded_source)
    local payload = {
        area = customer and "customer" or "work",
        companyId = row.company_id,
        requestId = row.id,
    }
    if customer then
        notify_sim(row.customer_sim_id, "sky_phone:companies:changed", payload)
    end
    if company then
        payload = {
            area = "work",
            companyId = row.company_id,
            requestId = row.id,
        }
        notify_company(row.company_id, "sky_phone:companies:changed", payload, excluded_source)
    end
end

Bridge.Callbacks.Register("sky_phone:companies:my-requests", function(source, data)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local device, device_error = current_device(source, true)
    if not device then
        return device_error
    end
    data = type(data) == "table" and data or {}
    local list = data.list or "open"
    if list ~= "open" and list ~= "closed" then
        return { success = false, error = "invalid_request" }
    end
    local cursor_time, cursor_id = decode_request_cursor(data.cursor)
    if cursor_time == false then
        return { success = false, error = "invalid_request" }
    end
    local status_condition = list == "open"
        and "r.`status` NOT IN ('completed', 'cancelled')"
        or "r.`status` IN ('completed', 'cancelled')"
    local cursor_condition = ""
    local parameters = { device.sim_id }
    if cursor_time then
        cursor_condition = [[
            AND (r.`updated_at` < FROM_UNIXTIME(?)
                OR (r.`updated_at` = FROM_UNIXTIME(?) AND r.`id` < ?))
        ]]
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_id
    end
    parameters[#parameters + 1] = Config.Companies.PageSize + 1
    local requests, next_cursor = list_request_rows(request_list_select .. ([=[
        WHERE r.`customer_sim_id` = ? AND %s %s
        ORDER BY r.`updated_at` DESC, r.`id` DESC
        LIMIT ?
    ]=]):format(status_condition, cursor_condition), parameters, "customer")
    local unread_rows = Bridge.Database.Query([[
        SELECT COALESCE(SUM(`customer_unread`), 0) AS `unread_count`
        FROM `sky_phone_company_requests`
        WHERE `customer_sim_id` = ?
    ]], { device.sim_id })
    return {
        success = true,
        data = {
            requests = requests,
            nextCursor = next_cursor,
            unreadCount = tonumber(unread_rows[1] and unread_rows[1].unread_count) or 0,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:companies:get-request", function(source, data)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local request_id = type(data) == "table" and data.requestId or nil
    if not valid_uuid(request_id) then
        return { success = false, error = "invalid_request" }
    end
    local access, access_error = request_access(source, request_id)
    if not access then
        return access_error
    end
    local request = request_detail(access)
    if not request then
        return { success = false, error = "request_not_found" }
    end
    return { success = true, data = { request = request } }
end)

Bridge.Callbacks.Register("sky_phone:companies:work-context", function(source)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local context = work_context(source)
    if not context then
        return { success = false, error = "not_authorized" }
    end
    return { success = true, data = { context = context } }
end)

Bridge.Callbacks.Register("sky_phone:companies:work-queue", function(source, data)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local member, member_error = require_permission(source, "WorkQueue")
    if not member then
        return member_error
    end
    data = type(data) == "table" and data or {}
    local filter = data.filter or "new"
    local filters = {
        new = "r.`status` = 'new'",
        assigned = "r.`assigned_identifier` = ? AND r.`status` NOT IN ('completed', 'cancelled')",
        in_progress = "r.`status` = 'in_progress'",
        waiting_customer = "r.`status` = 'waiting_customer'",
        completed = "r.`status` = 'completed'",
    }
    if not filters[filter] then
        return { success = false, error = "invalid_request" }
    end
    local cursor_time, cursor_id = decode_request_cursor(data.cursor)
    if cursor_time == false then
        return { success = false, error = "invalid_request" }
    end
    local parameters = { member.identifier, member.company_id }
    if filter == "assigned" then
        parameters[#parameters + 1] = member.identifier
    end
    local cursor_condition = ""
    if cursor_time then
        cursor_condition = [[
            AND (r.`updated_at` < FROM_UNIXTIME(?)
                OR (r.`updated_at` = FROM_UNIXTIME(?) AND r.`id` < ?))
        ]]
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_id
    end
    parameters[#parameters + 1] = Config.Companies.PageSize + 1
    local requests, next_cursor = list_request_rows(company_request_list_select .. ([=[
        WHERE r.`company_id` = ? AND %s %s
        ORDER BY r.`updated_at` DESC, r.`id` DESC
        LIMIT ?
    ]=]):format(filters[filter], cursor_condition), parameters, "company", member.identifier)
    return { success = true, data = { requests = requests, nextCursor = next_cursor } }
end)

local function member_token(target, company_id, identifier)
    local entry = member_tokens[target]
    if not entry or entry.company_id ~= company_id or entry.identifier ~= identifier
        or os.time() - entry.created_at > 300
    then
        entry = {
            token = uuid(),
            company_id = company_id,
            identifier = identifier,
            created_at = os.time(),
        }
        member_tokens[target] = entry
    end
    return entry.token
end

Bridge.Callbacks.Register("sky_phone:companies:list-members", function(source)
    local session, error_response = allow_read(source, "Read")
    if not session then
        return error_response
    end
    local member, member_error = require_permission(source, "Assign")
    if not member then
        return member_error
    end
    local members = {}
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(player_source) or player_source
        local target_member = membership(target)
        local target_identifier = target_member and Bridge.Framework.GetIdentifier(target) or nil
        if target_member and target_member.company_id == member.company_id
            and target_member.grade >= permission_grade(target_member.definition, "WorkQueue")
            and type(target_identifier) == "string" and target_identifier ~= ""
        then
            local first_name = trim(Bridge.Framework.GetFirstname(target) or "") or ""
            local last_name = trim(Bridge.Framework.GetLastname(target) or "") or ""
            local name = trim(first_name .. " " .. last_name)
            members[#members + 1] = {
                id = member_token(target, member.company_id, target_identifier),
                name = name,
                online = true,
                role = target_member.grade_label,
            }
        end
    end
    table.sort(members, function(left, right)
        return left.name:lower() < right.name:lower()
    end)
    return { success = true, data = { members = members } }
end)

local function allow_mutation(source, operation, limit_name)
    if not Config.Companies.Enabled then
        return false, { success = false, error = "service_unavailable" }
    end
    local limit = Config.Companies.RateLimits[limit_name]
    if not SkyPhone.AllowOperation(source, "companies_" .. operation, limit, 60) then
        return false, { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return false, error_response
    end
    return true
end

local function mutation_request_payload(source, request_id)
    local access, access_error = request_access(source, request_id)
    if not access then
        return nil, access_error
    end
    local request = request_detail(access)
    if not request then
        return nil, { success = false, error = "request_not_found" }
    end
    local data = { request = request }
    if access.audience == "company" then
        data.context = work_context(source)
    end
    return data
end

local function notification_payload(kind, area, row)
    return {
        kind = kind,
        area = area,
        companyId = row.company_id,
        requestId = row.id,
    }
end

Bridge.Callbacks.Register("sky_phone:companies:create-request", function(source, data)
    local allowed, rate_error = allow_mutation(source, "create_request", "CreateRequest")
    if not allowed then
        return rate_error
    end
    local device, device_error = current_device(source, true)
    if not device then
        return device_error
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local company_id = data.companyId
    local definition = type(company_id) == "string" and definitions[company_id] or nil
    if not definition or not definition.Public or definition.Emergency then
        return { success = false, error = "company_not_found" }
    end
    local subject = valid_text(data.subject, Config.Companies.SubjectMaxLength, false)
    local description = valid_text(data.description, Config.Companies.RequestBodyMaxLength, false)
    if not subject or not description or not valid_service_id(data.serviceId) then
        return { success = false, error = "invalid_request" }
    end
    local profiles = Bridge.Database.Query(
        "SELECT `accepts_requests` FROM `sky_phone_company_profiles` WHERE `company_id` = ? LIMIT 1",
        { company_id }
    )
    if not profiles[1] or tonumber(profiles[1].accepts_requests) ~= 1 then
        return { success = false, error = "invalid_service" }
    end
    local services = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_company_services`
        WHERE `id` = ? AND `company_id` = ? AND `archived` = 0
            AND `active` = 1 AND `requests_enabled` = 1
        LIMIT 1
    ]], { data.serviceId, company_id })
    if not services[1] then
        return { success = false, error = "invalid_service" }
    end
    local media_ids = data.mediaIds
    if media_ids == nil then
        media_ids = {}
    end
    if not valid_array(media_ids, Config.Companies.MaximumRequestMedia) then
        return { success = false, error = "invalid_media" }
    end
    local media_seen = {}
    local normalized_media = {}
    for _, media_id in ipairs(media_ids) do
        local normalized = valid_integer(media_id, 1, 9007199254740991)
        if not normalized or media_seen[normalized]
            or not SkyPhoneMedia.ResolveOwnedMedia(source, normalized, "photo")
        then
            return { success = false, error = "invalid_media" }
        end
        media_seen[normalized] = true
        normalized_media[#normalized_media + 1] = normalized
    end
    local counts = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_company_requests`
        WHERE `customer_sim_id` = ? AND `status` NOT IN ('completed', 'cancelled')
    ]], { device.sim_id })
    if (tonumber(counts[1] and counts[1].count) or 0) >= Config.Companies.MaximumOpenRequestsPerSim then
        return { success = false, error = "too_many_open_requests" }
    end
    local request_id = uuid()
    local event_id = uuid()
    local statements = {
        {
            query = "UPDATE `sky_phone_sims` SET `updated_at` = `updated_at` WHERE `id` = ?",
            params = { device.sim_id },
        },
        {
            query = [[
                INSERT INTO `sky_phone_company_requests`
                    (`id`, `company_id`, `service_id`, `customer_sim_id`, `subject`, `description`)
                SELECT ?, profile.`company_id`, service.`id`, sim.`id`, ?, ?
                FROM `sky_phone_sims` sim
                INNER JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = ?
                INNER JOIN `sky_phone_company_services` service
                    ON service.`id` = ? AND service.`company_id` = profile.`company_id`
                WHERE sim.`id` = ? AND profile.`accepts_requests` = 1
                    AND service.`archived` = 0 AND service.`active` = 1
                    AND service.`requests_enabled` = 1 AND (
                    SELECT COUNT(*) FROM `sky_phone_company_requests`
                    WHERE `customer_sim_id` = ? AND `status` NOT IN ('completed', 'cancelled')
                ) < ?
            ]],
            params = {
                request_id,
                subject,
                description,
                company_id,
                data.serviceId,
                device.sim_id,
                device.sim_id,
                Config.Companies.MaximumOpenRequestsPerSim,
            },
        },
        {
            query = [[
                INSERT INTO `sky_phone_company_request_events`
                    (`id`, `request_id`, `event_type`, `actor_type`, `to_status`)
                SELECT ?, `id`, 'created', 'customer', 'new'
                FROM `sky_phone_company_requests` WHERE `id` = ?
            ]],
            params = { event_id, request_id },
        },
    }
    for index, media_id in ipairs(normalized_media) do
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_company_request_media` (`request_id`, `media_id`, `sort_order`)
                SELECT `id`, ?, ? FROM `sky_phone_company_requests` WHERE `id` = ?
            ]],
            params = { media_id, index, request_id },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local row = request_row(request_id)
    if not row then
        local available = Bridge.Database.Query([[
            SELECT service.`id`
            FROM `sky_phone_company_profiles` profile
            INNER JOIN `sky_phone_company_services` service ON service.`company_id` = profile.`company_id`
            WHERE profile.`company_id` = ? AND profile.`accepts_requests` = 1
                AND service.`id` = ? AND service.`archived` = 0
                AND service.`active` = 1 AND service.`requests_enabled` = 1
            LIMIT 1
        ]], { company_id, data.serviceId })
        if not available[1] then
            return { success = false, error = "invalid_service" }
        end
        return { success = false, error = "too_many_open_requests" }
    end
    emit_request_change(row, true, true, source)
    notify_company(company_id, "sky_phone:companies:notification", notification_payload(
        "newRequest",
        "work",
        row
    ), source)
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:companies:cancel-request", function(source, data)
    local allowed, rate_error = allow_mutation(source, "cancel_request", "RequestAction")
    if not allowed then
        return rate_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not valid_uuid(request_id) or not revision then
        return { success = false, error = "invalid_request" }
    end
    local access, access_error = request_access(source, request_id)
    if not access then
        return access_error
    end
    if terminal_statuses[access.row.status]
        or (access.audience == "company" and not can_handle_request(access))
    then
        return { success = false, error = "invalid_status" }
    end
    local actor_type = access.audience
    local customer_unread_update = actor_type == "company"
        and ", `customer_unread` = `customer_unread` + 1" or ""
    local mutation_token = uuid()
    local event_id = uuid()
    local event_query
    local event_params
    if actor_type == "customer" then
        event_query = [[
            INSERT INTO `sky_phone_company_request_events`
                (`id`, `request_id`, `event_type`, `actor_type`, `from_status`, `to_status`)
            SELECT ?, `id`, 'cancelled', 'customer', ?, 'cancelled'
            FROM `sky_phone_company_requests`
            WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
        ]]
        event_params = { event_id, access.row.status, request_id, revision + 1, mutation_token }
    else
        event_query = [[
            INSERT INTO `sky_phone_company_request_events`
                (`id`, `request_id`, `event_type`, `actor_type`, `actor_identifier`, `from_status`, `to_status`)
            SELECT ?, `id`, 'cancelled', 'company', ?, ?, 'cancelled'
            FROM `sky_phone_company_requests`
            WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
        ]]
        event_params = {
            event_id,
            access.member.identifier,
            access.row.status,
            request_id,
            revision + 1,
            mutation_token,
        }
    end
    if not Bridge.Database.Transaction({
        {
            query = (([[
                UPDATE `sky_phone_company_requests`
                SET `status` = 'cancelled', `revision` = `revision` + 1,
                    `cancelled_at` = CURRENT_TIMESTAMP, `mutation_token` = ?%s
                WHERE `id` = ? AND `revision` = ? AND `status` = ?
            ]])):format(customer_unread_update),
            params = { mutation_token, request_id, revision, access.row.status },
        },
        { query = event_query, params = event_params },
    }) then
        return { success = false, error = "request_failed" }
    end
    local committed = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_request_events` WHERE `id` = ? LIMIT 1",
        { event_id }
    )
    if not committed[1] then
        return { success = false, error = "revision_conflict" }
    end
    local row = request_row(request_id)
    emit_request_change(row, true, true, source)
    if actor_type == "customer" then
        notify_company(row.company_id, "sky_phone:companies:notification", notification_payload(
            "requestUpdated",
            "work",
            row
        ), source)
    else
        notify_sim(row.customer_sim_id, "sky_phone:companies:notification", notification_payload(
            "requestUpdated",
            "customer",
            row
        ))
    end
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:companies:send-message", function(source, data)
    local allowed, rate_error = allow_mutation(source, "send_message", "Message")
    if not allowed then
        return rate_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local body = type(data) == "table" and valid_text(data.body, Config.Companies.MessageMaxLength, false) or nil
    if not valid_uuid(request_id) or not revision or not body then
        return { success = false, error = "invalid_request" }
    end
    local access, access_error = request_access(source, request_id)
    if not access then
        return access_error
    end
    if terminal_statuses[access.row.status]
        or (access.audience == "company" and not can_handle_request(access))
    then
        return { success = false, error = "invalid_status" }
    end
    local message_id = uuid()
    local mutation_token = uuid()
    local new_status = access.audience == "customer" and access.row.status == "waiting_customer"
        and "in_progress" or access.row.status
    local audience_unread_update = access.audience == "customer"
        and ", `company_activity_revision` = `company_activity_revision` + 1"
        or ", `customer_unread` = `customer_unread` + 1"
    local statements = {
        {
            query = ([[
                UPDATE `sky_phone_company_requests`
                SET `status` = ?, `revision` = `revision` + 1, `mutation_token` = ?%s
                WHERE `id` = ? AND `revision` = ? AND `status` = ?
                    AND `status` NOT IN ('completed', 'cancelled')
            ]]):format(audience_unread_update),
            params = { new_status, mutation_token, request_id, revision, access.row.status },
        },
    }
    if access.audience == "customer" then
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_company_request_messages`
                    (`id`, `request_id`, `sender_type`, `sender_sim_id`, `body`)
                SELECT ?, `id`, 'customer', ?, ? FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = { message_id, access.row.customer_sim_id, body, request_id, revision + 1, mutation_token },
        }
    else
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_company_request_messages`
                    (`id`, `request_id`, `sender_type`, `sender_identifier`, `body`)
                SELECT ?, `id`, 'company', ?, ? FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = { message_id, access.member.identifier, body, request_id, revision + 1, mutation_token },
        }
    end
    if new_status ~= access.row.status then
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_company_request_events`
                    (`id`, `request_id`, `event_type`, `actor_type`, `from_status`, `to_status`)
                SELECT ?, `id`, 'status', 'customer', ?, ? FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = { uuid(), access.row.status, new_status, request_id, revision + 1, mutation_token },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local inserted = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_request_messages` WHERE `id` = ? LIMIT 1",
        { message_id }
    )
    if not inserted[1] then
        return { success = false, error = "revision_conflict" }
    end
    local row = request_row(request_id)
    emit_request_change(row, true, true, source)
    if access.audience == "customer" then
        local notification = notification_payload("newMessage", "work", row)
        if row.assigned_identifier then
            notify_identifier(
                row.assigned_identifier,
                row.company_id,
                "sky_phone:companies:notification",
                notification
            )
        end
    else
        notify_sim(row.customer_sim_id, "sky_phone:companies:notification", notification_payload(
            "newMessage",
            "customer",
            row
        ))
    end
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:companies:claim-request", function(source, data)
    local allowed, rate_error = allow_mutation(source, "claim_request", "RequestAction")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "WorkQueue")
    if not member then
        return member_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not valid_uuid(request_id) or not revision then
        return { success = false, error = "invalid_request" }
    end
    local mutation_token = uuid()
    local event_id = uuid()
    if not Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_company_requests`
                SET `assigned_identifier` = ?, `status` = 'assigned', `revision` = `revision` + 1,
                    `customer_unread` = `customer_unread` + 1, `mutation_token` = ?
                WHERE `id` = ? AND `company_id` = ? AND `revision` = ?
                    AND `status` = 'new' AND `assigned_identifier` IS NULL
            ]],
            params = { member.identifier, mutation_token, request_id, member.company_id, revision },
        },
        {
            query = [[
                INSERT INTO `sky_phone_company_request_events`
                    (`id`, `request_id`, `event_type`, `actor_type`, `actor_identifier`, `from_status`, `to_status`)
                SELECT ?, `id`, 'assigned', 'company', ?, 'new', 'assigned'
                FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = { event_id, member.identifier, request_id, revision + 1, mutation_token },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    local committed = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_request_events` WHERE `id` = ? LIMIT 1",
        { event_id }
    )
    if not committed[1] then
        local current = Bridge.Database.Query([[
            SELECT `id` FROM `sky_phone_company_requests`
            WHERE `id` = ? AND `company_id` = ?
            LIMIT 1
        ]], { request_id, member.company_id })
        return { success = false, error = current[1] and "revision_conflict" or "request_not_found" }
    end
    local row = request_row(request_id)
    emit_request_change(row, true, true, source)
    notify_sim(row.customer_sim_id, "sky_phone:companies:notification", notification_payload(
        "assigned",
        "customer",
        row
    ))
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

local function resolve_member(member_id, company_id)
    if not valid_uuid(member_id) then
        return nil
    end
    local online = {}
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        online[tonumber(player_source) or player_source] = true
    end
    for target, token in pairs(member_tokens) do
        if token.token == member_id and token.company_id == company_id and online[target]
            and os.time() - token.created_at <= 300
        then
            local target_member = membership(target)
            if not target_member or target_member.company_id ~= company_id
                or target_member.grade < permission_grade(target_member.definition, "WorkQueue")
            then
                return nil
            end
            local identifier = Bridge.Framework.GetIdentifier(target)
            if type(identifier) ~= "string" or identifier == "" or identifier ~= token.identifier then
                return nil
            end
            return { source = target, identifier = identifier }
        end
    end
    return nil
end

Bridge.Callbacks.Register("sky_phone:companies:assign-request", function(source, data)
    local allowed, rate_error = allow_mutation(source, "assign_request", "RequestAction")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Assign")
    if not member then
        return member_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local target = type(data) == "table" and resolve_member(data.memberId, member.company_id) or nil
    if not valid_uuid(request_id) or not revision or not target then
        return { success = false, error = "invalid_request" }
    end
    local row = request_row(request_id)
    if not row or row.company_id ~= member.company_id then
        return { success = false, error = "request_not_found" }
    end
    if terminal_statuses[row.status] then
        return { success = false, error = "invalid_status" }
    end
    if row.assigned_identifier == target.identifier then
        return { success = false, error = "invalid_status" }
    end
    local next_status = row.status == "new" and "assigned" or row.status
    local mutation_token = uuid()
    local event_id = uuid()
    if not Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_company_requests`
                SET `assigned_identifier` = ?, `status` = ?, `revision` = `revision` + 1,
                    `customer_unread` = `customer_unread` + 1,
                    `company_activity_revision` = `company_activity_revision` + 1,
                    `mutation_token` = ?
                WHERE `id` = ? AND `company_id` = ? AND `revision` = ? AND `status` = ?
                    AND `status` NOT IN ('completed', 'cancelled')
            ]],
            params = {
                target.identifier,
                next_status,
                mutation_token,
                request_id,
                member.company_id,
                revision,
                row.status,
            },
        },
        {
            query = [[
                INSERT INTO `sky_phone_company_request_events`
                    (`id`, `request_id`, `event_type`, `actor_type`, `actor_identifier`, `from_status`, `to_status`)
                SELECT ?, `id`, 'assigned', 'company', ?, ?, ?
                FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = {
                event_id,
                member.identifier,
                row.status,
                next_status,
                request_id,
                revision + 1,
                mutation_token,
            },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    local committed = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_request_events` WHERE `id` = ? LIMIT 1",
        { event_id }
    )
    if not committed[1] then
        return { success = false, error = "revision_conflict" }
    end
    row = request_row(request_id)
    emit_request_change(row, true, true, source)
    notify_identifier(
        target.identifier,
        row.company_id,
        "sky_phone:companies:notification",
        notification_payload("assigned", "work", row)
    )
    notify_sim(row.customer_sim_id, "sky_phone:companies:notification", notification_payload(
        "assigned",
        "customer",
        row
    ))
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:companies:update-request-status", function(source, data)
    local allowed, rate_error = allow_mutation(source, "update_request_status", "RequestAction")
    if not allowed then
        return rate_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local status = type(data) == "table" and data.status or nil
    if not valid_uuid(request_id) or not revision or not Config.Companies.Statuses[status] then
        return { success = false, error = "invalid_request" }
    end
    local access, access_error = request_access(source, request_id)
    if not access then
        return access_error
    end
    if access.audience ~= "company" or not can_handle_request(access) then
        return { success = false, error = "not_authorized" }
    end
    if not status_transitions[access.row.status] or not status_transitions[access.row.status][status] then
        return { success = false, error = "invalid_status" }
    end
    local mutation_token = uuid()
    local event_id = uuid()
    if not Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_company_requests`
                SET `status` = ?, `revision` = `revision` + 1, `customer_unread` = `customer_unread` + 1,
                    `completed_at` = CASE WHEN ? = 'completed' THEN CURRENT_TIMESTAMP ELSE `completed_at` END,
                    `cancelled_at` = CASE WHEN ? = 'cancelled' THEN CURRENT_TIMESTAMP ELSE `cancelled_at` END,
                    `mutation_token` = ?
                WHERE `id` = ? AND `company_id` = ? AND `revision` = ? AND `status` = ?
            ]],
            params = {
                status,
                status,
                status,
                mutation_token,
                request_id,
                access.row.company_id,
                revision,
                access.row.status,
            },
        },
        {
            query = [[
                INSERT INTO `sky_phone_company_request_events`
                    (`id`, `request_id`, `event_type`, `actor_type`, `actor_identifier`, `from_status`, `to_status`)
                SELECT ?, `id`, ?, 'company', ?, ?, ?
                FROM `sky_phone_company_requests`
                WHERE `id` = ? AND `revision` = ? AND `mutation_token` = ?
            ]],
            params = {
                event_id,
                status == "cancelled" and "cancelled" or "status",
                access.member.identifier,
                access.row.status,
                status,
                request_id,
                revision + 1,
                mutation_token,
            },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    local committed = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_request_events` WHERE `id` = ? LIMIT 1",
        { event_id }
    )
    if not committed[1] then
        return { success = false, error = "revision_conflict" }
    end
    local row = request_row(request_id)
    emit_request_change(row, true, true, source)
    notify_sim(row.customer_sim_id, "sky_phone:companies:notification", notification_payload(
        "requestUpdated",
        "customer",
        row
    ))
    local payload, payload_error = mutation_request_payload(source, request_id)
    if not payload then
        return payload_error
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:companies:call-customer", function(source, data)
    local allowed, rate_error = allow_mutation(source, "call_customer", "RequestAction")
    if not allowed then
        return rate_error
    end
    local request_id = type(data) == "table" and data.requestId or nil
    if not valid_uuid(request_id) then
        return { success = false, error = "invalid_request" }
    end
    local access, access_error = request_access(source, request_id)
    if not access then
        return access_error
    end
    if access.audience ~= "company" or not can_handle_request(access) or terminal_statuses[access.row.status] then
        return { success = false, error = "not_authorized" }
    end
    if not SkyPhoneCompanies.CanPlaceCompanyCall(source, access.row.company_id) then
        return { success = false, error = "not_authorized" }
    end
    local rows = Bridge.Database.Query([[
        SELECT sim.`phone_number`
        FROM `sky_phone_company_requests` request
        INNER JOIN `sky_phone_sims` sim ON sim.`id` = request.`customer_sim_id`
        WHERE request.`id` = ? AND request.`company_id` = ?
        LIMIT 1
    ]], { request_id, access.row.company_id })
    if not rows[1] then
        return { success = false, error = "call_unavailable" }
    end
    local result = SkyPhoneCalls.StartCompanyCall(source, access.row.company_id, rows[1].phone_number)
    if not result.success and (result.error == "recipient_unavailable" or result.error == "company_unavailable") then
        return { success = false, error = "call_unavailable" }
    end
    return result
end)

Bridge.Callbacks.Register("sky_phone:companies:dial-service-line", function(source, data)
    local allowed, rate_error = allow_mutation(source, "dial_service_line", "RequestAction")
    if not allowed then
        return rate_error
    end
    local phone_number = type(data) == "table" and data.phoneNumber or nil
    if type(phone_number) ~= "string" or phone_number == "" then
        return { success = false, error = "invalid_number" }
    end
    local member = call_member(source)
    if not member or member.definition.ServiceLine.CanCall ~= true then
        return { success = false, error = "not_authorized" }
    end
    return SkyPhoneCalls.StartCompanyCall(source, member.company_id, phone_number)
end)

local function company_mutation_payload(source, company_id)
    local company = company_payload(company_id, true)
    if not company then
        return nil
    end
    company.updatedAtUnix = nil
    return { company = company, context = work_context(source) }
end

local function audit_statement(company_id, identifier, action, target_type, target_id, mutation_token, audit_id)
    return {
        query = [[
            INSERT INTO `sky_phone_company_audit`
                (`id`, `company_id`, `actor_identifier`, `action`, `target_type`, `target_id`, `metadata`)
            SELECT ?, `company_id`, ?, ?, ?, ?, ?
            FROM `sky_phone_company_profiles`
            WHERE `company_id` = ? AND `mutation_token` = ?
        ]],
        params = {
            audit_id,
            identifier,
            action,
            target_type,
            target_id,
            json.encode({ revisionChecked = true }),
            company_id,
            mutation_token,
        },
    }
end

local function audit_committed(audit_id)
    local rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_company_audit`
        WHERE `id` = ?
        LIMIT 1
    ]], { audit_id })
    return rows[1] ~= nil
end

Bridge.Callbacks.Register("sky_phone:companies:update-availability", function(source, data)
    local allowed, rate_error = allow_mutation(source, "update_availability", "Profile")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Availability")
    if not member then
        return member_error
    end
    local availability = type(data) == "table" and data.availability or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not Config.Companies.AvailabilityStatuses[availability] or not revision then
        return { success = false, error = "invalid_request" }
    end
    local expiry = parse_expiry(data.expiresAt, Config.Companies.AvailabilityMaximumSeconds)
    if expiry == false then
        return { success = false, error = "invalid_expiration" }
    end
    local mutation_token = uuid()
    local audit_id = uuid()
    local update_query
    local update_params
    if expiry then
        update_query = [[
            UPDATE `sky_phone_company_profiles`
            SET `availability` = ?, `availability_updated_by` = ?,
                `availability_updated_at` = CURRENT_TIMESTAMP,
                `availability_expires_at` = FROM_UNIXTIME(?),
                `revision` = `revision` + 1, `mutation_token` = ?
            WHERE `company_id` = ? AND `revision` = ?
        ]]
        update_params = { availability, member.identifier, expiry, mutation_token, member.company_id, revision }
    else
        update_query = [[
            UPDATE `sky_phone_company_profiles`
            SET `availability` = ?, `availability_updated_by` = ?,
                `availability_updated_at` = CURRENT_TIMESTAMP, `availability_expires_at` = NULL,
                `revision` = `revision` + 1, `mutation_token` = ?
            WHERE `company_id` = ? AND `revision` = ?
        ]]
        update_params = { availability, member.identifier, mutation_token, member.company_id, revision }
    end
    if not Bridge.Database.Transaction({
        { query = update_query, params = update_params },
        audit_statement(
            member.company_id,
            member.identifier,
            "update_availability",
            "profile",
            member.company_id,
            mutation_token,
            audit_id
        ),
    }) then
        return { success = false, error = "request_failed" }
    end
    if not audit_committed(audit_id) then
        return { success = false, error = "revision_conflict" }
    end
    emit_public_change(member.company_id)
    return { success = true, data = company_mutation_payload(source, member.company_id) }
end)

local function media_id_for_profile(source, value)
    local media_id = valid_integer(value, 1, 9007199254740991)
    if not media_id or not SkyPhoneMedia.ResolveOwnedMedia(source, media_id, "photo") then
        return nil
    end
    return media_id
end

Bridge.Callbacks.Register("sky_phone:companies:update-profile", function(source, data)
    local allowed, rate_error = allow_mutation(source, "update_profile", "Profile")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Profile")
    if not member then
        return member_error
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local revision = valid_integer(data.revision, 1, 4294967295)
    local description = valid_text(data.description, Config.Companies.ProfileDescriptionMaxLength, true)
    local district = valid_text(data.district, Config.Companies.DistrictMaxLength, true)
    local location_label = valid_text(data.locationLabel or "", Config.Companies.DistrictMaxLength, true)
    local address = valid_text(data.address, Config.Companies.AddressMaxLength, true)
    if not revision or not description or not district or not location_label or not address
        or type(data.acceptsRequests) ~= "boolean"
        or (member.definition.Emergency and data.acceptsRequests)
    then
        return { success = false, error = "invalid_profile" }
    end
    if data.phoneNumber ~= nil then
        local number = SkyPhoneSimNumber.NormalizeService(data.phoneNumber, Config.Sim.NumberLength)
        if number ~= member.definition.ServiceLine.Number then
            return { success = false, error = "invalid_profile" }
        end
    end
    local set_parts = {
        "`description` = ?",
        "`district` = ?",
        "`location_label` = ?",
        "`address` = ?",
        "`accepts_requests` = ?",
    }
    local parameters = { description, district, location_label, address, data.acceptsRequests and 1 or 0 }
    if data.coords ~= nil then
        if type(data.coords) ~= "table" then
            return { success = false, error = "invalid_profile" }
        end
        local x = tonumber(data.coords.x)
        local y = tonumber(data.coords.y)
        local z = tonumber(data.coords.z)
        if not x or not y or not z or x ~= x or y ~= y or z ~= z
            or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000
        then
            return { success = false, error = "invalid_profile" }
        end
        set_parts[#set_parts + 1] = "`location_x` = ?"
        set_parts[#set_parts + 1] = "`location_y` = ?"
        set_parts[#set_parts + 1] = "`location_z` = ?"
        parameters[#parameters + 1] = x
        parameters[#parameters + 1] = y
        parameters[#parameters + 1] = z
    end
    for _, media_field in ipairs({
        { input = "logoMediaId", column = "logo_media_id" },
        { input = "coverMediaId", column = "cover_media_id" },
    }) do
        if data[media_field.input] ~= nil then
            local media_id = media_id_for_profile(source, data[media_field.input])
            if not media_id then
                return { success = false, error = "invalid_media" }
            end
            set_parts[#set_parts + 1] = ("`%s` = ?"):format(media_field.column)
            parameters[#parameters + 1] = media_id
        end
    end
    local mutation_token = uuid()
    local audit_id = uuid()
    set_parts[#set_parts + 1] = "`revision` = `revision` + 1"
    set_parts[#set_parts + 1] = "`mutation_token` = ?"
    parameters[#parameters + 1] = mutation_token
    parameters[#parameters + 1] = member.company_id
    parameters[#parameters + 1] = revision
    if not Bridge.Database.Transaction({
        {
            query = ("UPDATE `sky_phone_company_profiles` SET %s WHERE `company_id` = ? AND `revision` = ?")
                :format(table.concat(set_parts, ", ")),
            params = parameters,
        },
        audit_statement(
            member.company_id,
            member.identifier,
            "update_profile",
            "profile",
            member.company_id,
            mutation_token,
            audit_id
        ),
    }) then
        return { success = false, error = "request_failed" }
    end
    if not audit_committed(audit_id) then
        return { success = false, error = "revision_conflict" }
    end
    emit_public_change(member.company_id)
    return { success = true, data = company_mutation_payload(source, member.company_id) }
end)

local function valid_clock(value)
    if type(value) ~= "string" then
        return false
    end
    local hour, minute = value:match("^(%d%d):(%d%d)$")
    hour = tonumber(hour)
    minute = tonumber(minute)
    return hour and minute and hour <= 23 and minute <= 59
end

Bridge.Callbacks.Register("sky_phone:companies:update-hours", function(source, data)
    local allowed, rate_error = allow_mutation(source, "update_hours", "Profile")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Hours")
    if not member then
        return member_error
    end
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local hours = type(data) == "table" and data.hours or nil
    if not revision or not valid_array(hours, 7) then
        return { success = false, error = "invalid_profile" }
    end
    local seen_days = {}
    for _, entry in ipairs(hours) do
        local day = type(entry) == "table" and valid_integer(entry.day, 0, 6) or nil
        if not day or seen_days[day] or type(entry.isClosed) ~= "boolean"
            or (not entry.isClosed and (not valid_clock(entry.opensAt) or not valid_clock(entry.closesAt)
                or entry.opensAt == entry.closesAt))
        then
            return { success = false, error = "invalid_profile" }
        end
        seen_days[day] = true
    end
    local mutation_token = uuid()
    local audit_id = uuid()
    local statements = {
        {
            query = [[
                UPDATE `sky_phone_company_profiles`
                SET `revision` = `revision` + 1, `mutation_token` = ?
                WHERE `company_id` = ? AND `revision` = ?
            ]],
            params = { mutation_token, member.company_id, revision },
        },
        {
            query = [[
                DELETE hours FROM `sky_phone_company_hours` hours
                INNER JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = hours.`company_id`
                WHERE hours.`company_id` = ? AND profile.`mutation_token` = ?
            ]],
            params = { member.company_id, mutation_token },
        },
    }
    for _, entry in ipairs(hours) do
        local query
        local params
        if entry.isClosed then
            query = [[
                INSERT INTO `sky_phone_company_hours` (`company_id`, `weekday`, `is_closed`)
                SELECT `company_id`, ?, 1 FROM `sky_phone_company_profiles`
                WHERE `company_id` = ? AND `mutation_token` = ?
            ]]
            params = { entry.day, member.company_id, mutation_token }
        else
            query = [[
                INSERT INTO `sky_phone_company_hours`
                    (`company_id`, `weekday`, `is_closed`, `opens_at`, `closes_at`)
                SELECT `company_id`, ?, 0, ?, ? FROM `sky_phone_company_profiles`
                WHERE `company_id` = ? AND `mutation_token` = ?
            ]]
            params = { entry.day, entry.opensAt, entry.closesAt, member.company_id, mutation_token }
        end
        statements[#statements + 1] = { query = query, params = params }
    end
    statements[#statements + 1] = audit_statement(
        member.company_id,
        member.identifier,
        "update_hours",
        "hours",
        member.company_id,
        mutation_token,
        audit_id
    )
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    if not audit_committed(audit_id) then
        return { success = false, error = "revision_conflict" }
    end
    emit_public_change(member.company_id)
    return { success = true, data = company_mutation_payload(source, member.company_id) }
end)

Bridge.Callbacks.Register("sky_phone:companies:update-services", function(source, data)
    local allowed, rate_error = allow_mutation(source, "update_services", "Profile")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Services")
    if not member then
        return member_error
    end
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local services = type(data) == "table" and data.services or nil
    if not revision or not valid_array(services, Config.Companies.MaximumServices) then
        return { success = false, error = "invalid_profile" }
    end
    local existing_rows = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_company_services` WHERE `company_id` = ? AND `archived` = 0",
        { member.company_id }
    )
    local existing = {}
    for _, row in ipairs(existing_rows) do
        existing[row.id] = true
    end
    local normalized = {}
    local seen = {}
    for index, service in ipairs(services) do
        if type(service) ~= "table" or type(service.active) ~= "boolean"
            or type(service.acceptsRequests) ~= "boolean"
        then
            return { success = false, error = "invalid_profile" }
        end
        local title = valid_text(service.title, Config.Companies.ServiceTitleMaxLength, false)
        local description = valid_text(
            service.description or "",
            Config.Companies.ServiceDescriptionMaxLength,
            true
        )
        local price = service.priceText == nil and ""
            or valid_text(service.priceText, Config.Companies.ServicePriceMaxLength, true)
        if not title or not description or not price then
            return { success = false, error = "invalid_profile" }
        end
        local service_id = valid_service_id(service.id) and existing[service.id] and service.id or uuid()
        if seen[service_id] then
            return { success = false, error = "invalid_profile" }
        end
        seen[service_id] = true
        normalized[#normalized + 1] = {
            id = service_id,
            title = title,
            description = description,
            price = price,
            accepts_requests = service.acceptsRequests,
            active = service.active,
            sort_order = index,
        }
    end
    local mutation_token = uuid()
    local audit_id = uuid()
    local statements = {
        {
            query = [[
                UPDATE `sky_phone_company_profiles`
                SET `revision` = `revision` + 1, `mutation_token` = ?
                WHERE `company_id` = ? AND `revision` = ?
            ]],
            params = { mutation_token, member.company_id, revision },
        },
        {
            query = [[
                UPDATE `sky_phone_company_services` service
                INNER JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = service.`company_id`
                SET service.`active` = 0, service.`requests_enabled` = 0, service.`archived` = 1
                WHERE service.`company_id` = ? AND profile.`mutation_token` = ?
            ]],
            params = { member.company_id, mutation_token },
        },
    }
    for _, service in ipairs(normalized) do
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_company_services`
                    (`id`, `company_id`, `title`, `description`, `price_text`, `requests_enabled`, `active`, `sort_order`)
                SELECT ?, `company_id`, ?, ?, ?, ?, ?, ? FROM `sky_phone_company_profiles`
                WHERE `company_id` = ? AND `mutation_token` = ?
                ON DUPLICATE KEY UPDATE
                    `title` = VALUES(`title`), `description` = VALUES(`description`),
                    `price_text` = VALUES(`price_text`), `requests_enabled` = VALUES(`requests_enabled`),
                    `active` = VALUES(`active`), `archived` = 0, `sort_order` = VALUES(`sort_order`)
            ]],
            params = {
                service.id,
                service.title,
                service.description,
                service.price,
                service.accepts_requests and 1 or 0,
                service.active and 1 or 0,
                service.sort_order,
                member.company_id,
                mutation_token,
            },
        }
    end
    statements[#statements + 1] = audit_statement(
        member.company_id,
        member.identifier,
        "update_services",
        "services",
        member.company_id,
        mutation_token,
        audit_id
    )
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    if not audit_committed(audit_id) then
        return { success = false, error = "revision_conflict" }
    end
    emit_public_change(member.company_id)
    return { success = true, data = company_mutation_payload(source, member.company_id) }
end)

Bridge.Callbacks.Register("sky_phone:companies:publish-announcement", function(source, data)
    local allowed, rate_error = allow_mutation(source, "publish_announcement", "Profile")
    if not allowed then
        return rate_error
    end
    local member, member_error = require_permission(source, "Announcement")
    if not member then
        return member_error
    end
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    local body = type(data) == "table"
        and valid_text(data.body or "", Config.Companies.AnnouncementBodyMaxLength, true) or nil
    if not revision or body == nil then
        return { success = false, error = "invalid_profile" }
    end
    local expiry = parse_expiry(data.expiresAt, Config.Companies.AnnouncementMaximumSeconds)
    if expiry == false then
        return { success = false, error = "invalid_expiration" }
    end
    local mutation_token = uuid()
    local audit_id = uuid()
    local statements = {
        {
            query = [[
                UPDATE `sky_phone_company_profiles`
                SET `revision` = `revision` + 1, `mutation_token` = ?
                WHERE `company_id` = ? AND `revision` = ?
            ]],
            params = { mutation_token, member.company_id, revision },
        },
        {
            query = [[
                UPDATE `sky_phone_company_announcements` announcement
                INNER JOIN `sky_phone_company_profiles` profile ON profile.`company_id` = announcement.`company_id`
                SET announcement.`active` = 0
                WHERE announcement.`company_id` = ? AND profile.`mutation_token` = ?
            ]],
            params = { member.company_id, mutation_token },
        },
    }
    if body ~= "" then
        local insert_query
        local insert_params
        if expiry then
            insert_query = [[
                INSERT INTO `sky_phone_company_announcements`
                    (`id`, `company_id`, `title`, `body`, `created_by`, `expires_at`)
                SELECT ?, `company_id`, '', ?, ?, FROM_UNIXTIME(?) FROM `sky_phone_company_profiles`
                WHERE `company_id` = ? AND `mutation_token` = ?
            ]]
            insert_params = { uuid(), body, member.identifier, expiry, member.company_id, mutation_token }
        else
            insert_query = [[
                INSERT INTO `sky_phone_company_announcements`
                    (`id`, `company_id`, `title`, `body`, `created_by`)
                SELECT ?, `company_id`, '', ?, ? FROM `sky_phone_company_profiles`
                WHERE `company_id` = ? AND `mutation_token` = ?
            ]]
            insert_params = { uuid(), body, member.identifier, member.company_id, mutation_token }
        end
        statements[#statements + 1] = { query = insert_query, params = insert_params }
    end
    statements[#statements + 1] = audit_statement(
        member.company_id,
        member.identifier,
        "publish_announcement",
        "announcement",
        member.company_id,
        mutation_token,
        audit_id
    )
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    if not audit_committed(audit_id) then
        return { success = false, error = "revision_conflict" }
    end
    emit_public_change(member.company_id)
    return { success = true, data = company_mutation_payload(source, member.company_id) }
end)

Bridge.Callbacks.Register("sky_phone:companies:set-call-availability", function(source, data)
    local allowed, rate_error = allow_mutation(source, "set_call_availability", "CallAvailability")
    if not allowed then
        return rate_error
    end
    if type(data) ~= "table" or type(data.available) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if not data.available then
        SkyPhoneCompanies.ClearCallAvailability(source)
        return { success = true, data = { context = work_context(source) } }
    end
    local member = call_member(source)
    if not member or not member.definition.ServiceLine.CanCall then
        return { success = false, error = "not_authorized" }
    end
    local device, device_error = current_device(source, true)
    if not device then
        return device_error
    end
    call_availability[source] = {
        company_id = member.company_id,
        sim_id = device.sim_id,
        imei = device.imei,
    }
    return { success = true, data = { context = work_context(source) } }
end)

AddEventHandler("playerDropped", function()
    SkyPhoneCompanies.ClearCallAvailability(source)
    member_tokens[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    call_availability = {}
    round_robin_positions = {}
    member_tokens = {}
end)
end)
