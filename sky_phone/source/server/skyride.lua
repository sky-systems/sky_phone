Bridge.Database.AfterMigration("sky_phone", function()
local allowed_cancel_reasons = {
    changed_mind = true,
    driver_delay = true,
    emergency = true,
    other = true,
    wrong_pickup = true,
}
local quotes = {}
local online_drivers = {}
local operation_locks = {}
local services = {}

local function refresh_runtime_configuration()
    if Config.SkyRide.DistanceUnit ~= "kilometer" and Config.SkyRide.DistanceUnit ~= "mile" then
        error(("[sky_phone] Invalid SkyRide distance unit '%s'."):format(tostring(Config.SkyRide.DistanceUnit)))
    end

    local next_services = {}
    for index = 1, #Config.SkyRide.Services do
        local service = Config.SkyRide.Services[index]
        if service.Id ~= "taxi" and service.Id ~= "comfort" and service.Id ~= "xl" and service.Id ~= "premium" then
            error(("[sky_phone] Invalid SkyRide service class '%s'."):format(tostring(service.Id)))
        end
        if next_services[service.Id] then
            error(("[sky_phone] Duplicate SkyRide service class '%s'."):format(service.Id))
        end
        next_services[service.Id] = service
    end
    services = next_services
end

refresh_runtime_configuration()

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    refresh_runtime_configuration()
end)

local ride_select = [[
    SELECT r.*,
        passenger.`owner_identifier` AS `passenger_identifier`,
        COALESCE(NULLIF(passenger.`display_name`, ''), r.`passenger_name`) AS `passenger_profile_name`,
        passenger_avatar.`url` AS `passenger_avatar_url`,
        driver.`owner_identifier` AS `driver_identifier`,
        COALESCE(NULLIF(driver.`display_name`, ''), r.`driver_name`) AS `driver_profile_name`,
        driver_avatar.`url` AS `driver_avatar_url`,
        UNIX_TIMESTAMP(r.`created_at`) AS `created_at_unix`,
        UNIX_TIMESTAMP(r.`updated_at`) AS `updated_at_unix`,
        UNIX_TIMESTAMP(r.`accepted_at`) AS `accepted_at_unix`,
        UNIX_TIMESTAMP(r.`arrived_at`) AS `arrived_at_unix`,
        UNIX_TIMESTAMP(r.`started_at`) AS `started_at_unix`,
        UNIX_TIMESTAMP(r.`completed_at`) AS `completed_at_unix`,
        UNIX_TIMESTAMP(r.`cancelled_at`) AS `cancelled_at_unix`
    FROM `sky_phone_skyride_rides` r
    INNER JOIN `sky_phone_skyride_profiles` passenger
        ON passenger.`id` = r.`passenger_profile_id`
    LEFT JOIN `sky_phone_media` passenger_avatar
        ON passenger_avatar.`id` = passenger.`avatar_media_id`
    LEFT JOIN `sky_phone_skyride_profiles` driver
        ON driver.`id` = r.`driver_profile_id`
    LEFT JOIN `sky_phone_media` driver_avatar
        ON driver_avatar.`id` = driver.`avatar_media_id`
]]

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function player_name(source)
    local firstname = Bridge.Framework.GetFirstname(source)
    local lastname = Bridge.Framework.GetLastname(source)
    local name = ((firstname or "") .. " " .. (lastname or "")):match("^%s*(.-)%s*$")
    if name == "" then
        name = GetPlayerName(source) or ("Player %s"):format(source)
    end
    return name:sub(1, 80)
end

local function get_player_coords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function distance_between(left, right)
    local x = left.x - right.x
    local y = left.y - right.y
    local z = left.z - right.z
    return math.sqrt((x * x) + (y * y) + (z * z))
end

local function is_near(source, location, radius)
    local coords = get_player_coords(source)
    return coords and distance_between(coords, location.coords) <= radius
end

local function validate_location(value)
    if type(value) ~= "table" or type(value.coords) ~= "table" then
        return nil
    end
    local label = type(value.label) == "string" and value.label:match("^%s*(.-)%s*$") or nil
    local label_length = label and utf8.len(label) or nil
    local x = tonumber(value.coords.x)
    local y = tonumber(value.coords.y)
    local z = tonumber(value.coords.z)
    local id = value.id
    if not label_length
        or label_length < 1
        or label_length > 80
        or not x
        or not y
        or not z
        or x ~= x
        or y ~= y
        or z ~= z
        or math.abs(x) > 10000.0
        or math.abs(y) > 10000.0
        or z < -1000.0
        or z > 3000.0
        or (id ~= nil and (type(id) ~= "string" or #id > 40 or not id:match("^[%w_-]+$")))
    then
        return nil
    end
    return {
        coords = { x = x, y = y, z = z },
        id = id,
        label = label,
    }
end

local function quick_locations()
    local result = {}
    for index = 1, #Config.SkyRide.QuickLocations do
        local location = Config.SkyRide.QuickLocations[index]
        result[index] = {
            coords = {
                x = location.Coords.x,
                y = location.Coords.y,
                z = location.Coords.z,
            },
            id = location.Id,
            label = location.Label,
        }
    end
    return result
end

local function generate_uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = rows[1] and rows[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Database did not generate a SkyRide id.")
    end
    return id
end

local function discard_quote_group(group)
    for quote_id, quote in pairs(quotes) do
        if quote.group == group then
            quotes[quote_id] = nil
        end
    end
end

local function require_profile(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" or #identifier > 80 then
        return nil, { success = false, error = "skyride_unavailable" }
    end
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_skyride_profiles` (`id`, `owner_identifier`)
        SELECT UUID(), ?
    ]], { identifier })
    local rows = Bridge.Database.Query([[
        SELECT profile.`id`, profile.`owner_identifier`, profile.`display_name`,
            profile.`avatar_media_id`, avatar.`url` AS `avatar_url`,
            UNIX_TIMESTAMP(profile.`created_at`) AS `created_at_unix`
        FROM `sky_phone_skyride_profiles` profile
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        WHERE profile.`owner_identifier` = ?
        LIMIT 1
    ]], { identifier })
    if not rows[1] then
        error(("[sky_phone] Failed to load SkyRide profile for source %s."):format(tostring(source)))
    end
    return rows[1]
end

local function driver_eligible(source)
    local job = Bridge.Framework.GetJob(source)
    local minimum_grade = Config.SkyRide.DriverJobs[job.name]
    return minimum_grade ~= nil and (tonumber(job.grade) or 0) >= minimum_grade
end

local function driver_online(source, profile)
    local state = online_drivers[source]
    if not state or state.profile_id ~= profile.id or not driver_eligible(source) then
        online_drivers[source] = nil
        return false
    end
    return true
end

local function current_vehicle(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end
    local entity = GetVehiclePedIsIn(ped, false)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end
    if GetPedInVehicleSeat(entity, -1) ~= ped then
        return nil
    end
    local vehicle = {
        color = "",
        model = "",
        plate = "",
    }
    vehicle.model = tostring(GetEntityModel(entity) or "")
    vehicle.plate = tostring(GetVehicleNumberPlateText(entity) or ""):match("^%s*(.-)%s*$"):sub(1, 16)
    return vehicle
end

local function profile_snapshot(source, profile)
    local rows = Bridge.Database.Query([[
        SELECT
            (SELECT COUNT(*)
                FROM `sky_phone_skyride_rides`
                WHERE `status` = 'completed'
                    AND (`passenger_profile_id` = ? OR `driver_profile_id` = ?)) AS `completed_rides`,
            (SELECT COUNT(*)
                FROM `sky_phone_skyride_rides`
                WHERE `status` = 'cancelled'
                    AND (`passenger_profile_id` = ? OR `driver_profile_id` = ?)) AS `cancelled_rides`,
            (SELECT AVG(`passenger_rating`)
                FROM `sky_phone_skyride_rides`
                WHERE `driver_profile_id` = ? AND `passenger_rating` IS NOT NULL) AS `rating`,
            (SELECT COALESCE(SUM(`payout_amount` + `tip_amount`), 0)
                FROM `sky_phone_skyride_rides`
                WHERE `driver_profile_id` = ?
                    AND `status` = 'completed'
                    AND DATE(`completed_at`) = CURRENT_DATE) AS `earnings_today`
    ]], { profile.id, profile.id, profile.id, profile.id, profile.id, profile.id })
    local stats = rows[1] or {}
    return {
        acceptanceRate = false,
        avatarMediaId = profile.avatar_media_id and tonumber(profile.avatar_media_id) or false,
        avatarUrl = profile.avatar_url or false,
        cancelledRides = tonumber(stats.cancelled_rides) or 0,
        completedRides = tonumber(stats.completed_rides) or 0,
        currency = Config.SkyRide.Currency,
        defaultPaymentMethod = Config.SkyRide.PaymentAccount,
        earningsToday = driver_eligible(source) and (tonumber(stats.earnings_today) or 0) or false,
        id = profile.id,
        memberSince = tonumber(profile.created_at_unix) or os.time(),
        name = profile.display_name or player_name(source),
        rating = math.floor(((tonumber(stats.rating) or 5.0) * 100) + 0.5) / 100,
    }
end

local function select_ride_rows(where_clause, parameters, limit)
    local values = {}
    for index = 1, #parameters do
        values[index] = parameters[index]
    end
    values[#values + 1] = limit
    return Bridge.Database.Query(
        ride_select .. " WHERE " .. where_clause .. " ORDER BY r.`updated_at` DESC, r.`id` DESC LIMIT ?",
        values
    )
end

local function profile_metrics(rows)
    local profile_ids = {}
    local seen = {}
    for index = 1, #rows do
        local row = rows[index]
        for _, profile_id in ipairs({ row.passenger_profile_id, row.driver_profile_id }) do
            if profile_id and not seen[profile_id] then
                seen[profile_id] = true
                profile_ids[#profile_ids + 1] = profile_id
            end
        end
    end
    if #profile_ids == 0 then
        return {}
    end
    local placeholders = {}
    for index = 1, #profile_ids do
        placeholders[index] = "?"
    end
    local metrics_rows = Bridge.Database.Query(([[
        SELECT profile.`id`,
            (SELECT AVG(ride.`passenger_rating`)
                FROM `sky_phone_skyride_rides` ride
                WHERE ride.`driver_profile_id` = profile.`id`
                    AND ride.`passenger_rating` IS NOT NULL) AS `rating`,
            (SELECT COUNT(*)
                FROM `sky_phone_skyride_rides` ride
                WHERE ride.`status` = 'completed'
                    AND (ride.`passenger_profile_id` = profile.`id`
                        OR ride.`driver_profile_id` = profile.`id`)) AS `trips`
        FROM `sky_phone_skyride_profiles` profile
        WHERE profile.`id` IN (%s)
    ]]):format(table.concat(placeholders, ", ")), profile_ids)
    local metrics = {}
    for index = 1, #metrics_rows do
        local row = metrics_rows[index]
        metrics[row.id] = {
            rating = math.floor(((tonumber(row.rating) or 5.0) * 100) + 0.5) / 100,
            trips = tonumber(row.trips) or 0,
        }
    end
    return metrics
end

local function source_for_identifier(identifier)
    if not identifier then
        return nil
    end
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local source = tonumber(player_source) or player_source
        if Bridge.Framework.GetIdentifier(source) == identifier then
            return source
        end
    end
    return nil
end

local function phone_number_for_source(source)
    local session = source and SkyPhone.RequireSession(source) or nil
    if not session then
        return nil
    end
    local device = SkyPhone.LoadDevice(session.imei)
    return device and device.phone_number or nil
end

local function online_source_for_identifier(identifier)
    if not identifier then
        return nil
    end
    for source, state in pairs(online_drivers) do
        if state.identifier == identifier and GetPlayerName(source) then
            return source
        end
    end
    return nil
end

local function person_dto(id, name, avatar_url, metrics)
    return {
        avatarUrl = avatar_url or false,
        id = id,
        name = name or "",
        rating = metrics and metrics.rating or 5.0,
        trips = metrics and metrics.trips or 0,
    }
end

local function ride_dtos(rows)
    local metrics = profile_metrics(rows)
    local result = {}
    for index = 1, #rows do
        local row = rows[index]
        local status = row.status == "completing" and "in_progress" or row.status
        local passenger = person_dto(
            row.passenger_profile_id,
            row.passenger_profile_name,
            row.passenger_avatar_url,
            metrics[row.passenger_profile_id]
        )
        local driver = false
        if row.driver_profile_id then
            driver = person_dto(
                row.driver_profile_id,
                row.driver_profile_name,
                row.driver_avatar_url,
                metrics[row.driver_profile_id]
            )
            driver.vehicle = {
                color = row.driver_vehicle_color or "",
                model = row.driver_vehicle_model or "",
                plate = row.driver_vehicle_plate or "",
            }
            if status == "accepted" or status == "arrived" or status == "in_progress" then
                local source = online_source_for_identifier(row.driver_identifier)
                local location = source and get_player_coords(source) or nil
                if location then
                    driver.location = location
                end
            end
        end
        local ride = {
            acceptedAt = row.accepted_at_unix and tonumber(row.accepted_at_unix) or nil,
            arrivedAt = row.arrived_at_unix and tonumber(row.arrived_at_unix) or nil,
            cancelledAt = row.cancelled_at_unix and tonumber(row.cancelled_at_unix) or nil,
            cancelledBy = row.cancelled_by,
            completedAt = row.completed_at_unix and tonumber(row.completed_at_unix) or nil,
            createdAt = tonumber(row.created_at_unix) or 0,
            currency = row.currency,
            destination = {
                coords = {
                    x = tonumber(row.destination_x) or 0.0,
                    y = tonumber(row.destination_y) or 0.0,
                    z = tonumber(row.destination_z) or 0.0,
                },
                label = row.destination_label,
            },
            distanceMeters = tonumber(row.distance_meters) or 0,
            driver = driver,
            durationSeconds = tonumber(row.duration_seconds) or 0,
            id = row.id,
            passenger = passenger,
            pickup = {
                coords = {
                    x = tonumber(row.pickup_x) or 0.0,
                    y = tonumber(row.pickup_y) or 0.0,
                    z = tonumber(row.pickup_z) or 0.0,
                },
                label = row.pickup_label,
            },
            price = tonumber(row.price) or 0,
            serviceClass = row.service_class,
            startedAt = row.started_at_unix and tonumber(row.started_at_unix) or nil,
            status = status,
            updatedAt = tonumber(row.updated_at_unix) or 0,
        }
        if status == "completed" then
            ride.finalPrice = tonumber(row.price) or 0
        end
        if row.passenger_rating then
            ride.rating = tonumber(row.passenger_rating)
        end
        result[index] = ride
    end
    return result
end

local function active_ride(profile_id)
    local rows = select_ride_rows([[
        (r.`passenger_profile_id` = ? OR r.`driver_profile_id` = ?)
            AND r.`status` IN ('searching','accepted','arrived','in_progress','completing')
    ]], { profile_id, profile_id }, 2)
    if #rows > 1 then
        Bridge.Debug(
            "error",
            "[sky_phone] SkyRide profile '%s' has multiple active rides.",
            tostring(profile_id)
        )
    end
    local rides = ride_dtos(rows)
    if rides[1] and rows[1] then
        local passenger_number = phone_number_for_source(source_for_identifier(rows[1].passenger_identifier))
        if passenger_number then
            rides[1].passenger.phoneNumber = passenger_number
        end
        if type(rides[1].driver) == "table" then
            local driver_number = phone_number_for_source(source_for_identifier(rows[1].driver_identifier))
            if driver_number then
                rides[1].driver.phoneNumber = driver_number
            end
        end
    end
    return rides[1], rows[1]
end

local function available_requests(profile_id)
    local rows = select_ride_rows([[
        r.`status` = 'searching' AND r.`passenger_profile_id` <> ?
    ]], { profile_id }, Config.SkyRide.HistoryLimit)
    return ride_dtos(rows)
end

local function ride_history(profile_id)
    local rows = select_ride_rows([[
        (r.`passenger_profile_id` = ? OR r.`driver_profile_id` = ?)
            AND r.`status` IN ('completed','cancelled')
    ]], { profile_id, profile_id }, Config.SkyRide.HistoryLimit)
    return ride_dtos(rows)
end

local function pending_rating(profile_id)
    local rows = select_ride_rows([[
        r.`passenger_profile_id` = ?
            AND r.`status` = 'completed'
            AND r.`passenger_rating` IS NULL
            AND r.`tip_status` = 'none'
    ]], { profile_id }, 1)
    local rides = ride_dtos(rows)
    return rides[1]
end

local function ride_by_id(ride_id)
    local rows = select_ride_rows("r.`id` = ?", { ride_id }, 1)
    local rides = ride_dtos(rows)
    return rides[1], rows[1]
end

local function process_pending_refund(row)
    if not row or (row.status ~= "payment_pending" and row.status ~= "cancelled") then
        return false
    end
    if row.refund_status == "completed" then
        if row.status ~= "payment_pending" then
            return true
        end
        local delete_success, delete_result = pcall(
            Bridge.Database.Query,
            [[
                DELETE FROM `sky_phone_skyride_rides`
                WHERE `id` = ? AND `status` = 'payment_pending'
                    AND `refund_status` = 'completed'
            ]],
            { row.id }
        )
        if not delete_success then
            Bridge.Debug(
                "error",
                "[sky_phone] Failed to remove refunded payment-pending SkyRide '%s': %s",
                row.id,
                tostring(delete_result)
            )
            return false
        end
        return true
    end
    if row.refund_status ~= "pending" then
        return false
    end
    local price = tonumber(row.price) or 0
    local passenger_source = source_for_identifier(row.passenger_identifier)
    if price > 0 and not passenger_source then
        return false
    end
    local claim_success, claim_result = pcall(
        Bridge.Database.Query,
        [[
            UPDATE `sky_phone_skyride_rides`
            SET `refund_status` = 'processing'
            WHERE `id` = ? AND `status` IN ('payment_pending','cancelled')
                AND `refund_status` = 'pending'
        ]],
        { row.id }
    )
    if not claim_success then
        Bridge.Debug(
            "error",
            "[sky_phone] Failed to claim pending refund for SkyRide '%s': %s",
            row.id,
            tostring(claim_result)
        )
        return false
    end
    if affected_rows(claim_result) ~= 1 then
        return false
    end
    local money_success = true
    local money_result = true
    if price > 0 then
        money_success, money_result = pcall(
            Bridge.Framework.AddMoney,
            passenger_source,
            Config.SkyRide.PaymentAccount,
            price
        )
    end
    if not money_success then
        Bridge.Debug(
            "error",
            "[sky_phone] Framework refund crashed for SkyRide '%s'; processing state prevents an automatic duplicate refund and requires manual reconciliation: %s",
            row.id,
            tostring(money_result)
        )
        return false
    end
    if not money_result then
        local reset_success, reset_result = pcall(
            Bridge.Database.Query,
            [[
                UPDATE `sky_phone_skyride_rides`
                SET `refund_status` = 'pending'
                WHERE `id` = ? AND `refund_status` = 'processing'
            ]],
            { row.id }
        )
        if not reset_success or affected_rows(reset_result) ~= 1 then
            Bridge.Debug(
                "error",
                "[sky_phone] Refund failed and its claim could not be reset for SkyRide '%s'; manual reconciliation is required.",
                row.id
            )
        end
        Bridge.Debug(
            "error",
            "[sky_phone] Framework refund failed for SkyRide '%s': %s",
            row.id,
            tostring(money_result)
        )
        return false
    end
    local finalize_success, finalize_result = pcall(
        Bridge.Database.Query,
        [[
            UPDATE `sky_phone_skyride_rides`
            SET `refund_status` = 'completed', `refunded_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `refund_status` = 'processing'
        ]],
        { row.id }
    )
    if not finalize_success or affected_rows(finalize_result) ~= 1 then
        Bridge.Debug(
            "error",
            "[sky_phone] Refund was paid but could not be finalized for SkyRide '%s'; processing state prevents an automatic duplicate refund.",
            row.id
        )
        return false
    end
    if passenger_source then
        TriggerClientEvent("sky_phone:banking:changed", passenger_source)
    end
    if row.status == "payment_pending" then
        local delete_success, delete_result = pcall(
            Bridge.Database.Query,
            [[
                DELETE FROM `sky_phone_skyride_rides`
                WHERE `id` = ? AND `status` = 'payment_pending'
                    AND `refund_status` = 'completed'
            ]],
            { row.id }
        )
        if not delete_success or affected_rows(delete_result) ~= 1 then
            Bridge.Debug(
                "error",
                "[sky_phone] Refunded payment-pending SkyRide '%s' could not be removed; recovery will retry cleanup.",
                row.id
            )
            return false
        end
    end
    return true
end

local function transition_tip_status(ride_id, expected_status, next_status)
    local update_success, update_result = pcall(
        Bridge.Database.Query,
        [[
            UPDATE `sky_phone_skyride_rides`
            SET `tip_status` = ?
            WHERE `id` = ? AND `tip_status` = ?
        ]],
        { next_status, ride_id, expected_status }
    )
    if not update_success or affected_rows(update_result) ~= 1 then
        Bridge.Debug(
            "error",
            "[sky_phone] Failed to move SkyRide '%s' tip state from '%s' to '%s'.",
            ride_id,
            expected_status,
            next_status
        )
        return false
    end
    return true
end

local function state_snapshot(source, profile, fields)
    local result = {}
    if fields.activeRide then
        result.activeRide = active_ride(profile.id) or false
    end
    if fields.availableRequests then
        result.availableRequests = driver_online(source, profile) and available_requests(profile.id) or {}
    end
    if fields.driverOnline then
        result.driverOnline = driver_online(source, profile)
    end
    if fields.history then
        result.history = ride_history(profile.id)
    end
    if fields.pendingRating then
        result.pendingRating = pending_rating(profile.id) or false
    end
    if fields.profile then
        result.profile = profile_snapshot(source, profile)
    end
    return result
end

local function push_update(source, fields)
    local profile = require_profile(source)
    if not profile then
        return
    end
    TriggerClientEvent("sky_phone:skyride:changed", source, state_snapshot(source, profile, fields))
end

local function push_participants(row, fields, excluded_source)
    for _, identifier in ipairs({ row.passenger_identifier, row.driver_identifier }) do
        local source = source_for_identifier(identifier)
        if source and source ~= excluded_source then
            push_update(source, fields)
        end
    end
end

local function push_available_requests(excluded_source)
    for source in pairs(online_drivers) do
        if source ~= excluded_source then
            push_update(source, { availableRequests = true })
        end
    end
end

local function run_locked(key, callback)
    if operation_locks[key] then
        return nil, { success = false, error = "rate_limited" }
    end
    operation_locks[key] = true
    local success, result = pcall(callback)
    operation_locks[key] = nil
    if not success then
        error(result)
    end
    return result
end

local function valid_ride_id(data)
    return type(data) == "table"
        and type(data.rideId) == "string"
        and #data.rideId == 36
        and data.rideId:match("^[%x%-]+$")
        and data.rideId
        or nil
end

local function transition_driver_ride(source, data, expected_statuses, next_status, timestamp_column, radius, location_kind)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if not driver_online(source, profile) then
        return { success = false, error = "driver_offline" }
    end
    local ride_id = valid_ride_id(data)
    if not ride_id then
        return { success = false, error = "ride_not_found" }
    end
    local result, lock_error = run_locked("profile:" .. profile.id, function()
        local _, row = ride_by_id(ride_id)
        if not row then
            return { success = false, error = "ride_not_found" }
        end
        if row.driver_profile_id ~= profile.id then
            return { success = false, error = "not_ride_participant" }
        end
        if not expected_statuses[row.status] then
            return { success = false, error = "invalid_ride_status" }
        end
        local location = location_kind == "pickup" and {
            coords = {
                x = tonumber(row.pickup_x),
                y = tonumber(row.pickup_y),
                z = tonumber(row.pickup_z),
            },
        } or {
            coords = {
                x = tonumber(row.destination_x),
                y = tonumber(row.destination_y),
                z = tonumber(row.destination_z),
            },
        }
        if not is_near(source, location, radius) then
            return {
                success = false,
                error = location_kind == "pickup" and "driver_too_far" or "destination_too_far",
            }
        end
        if next_status == "in_progress" or next_status == "completing" then
            local passenger_source = source_for_identifier(row.passenger_identifier)
            if not passenger_source or not is_near(passenger_source, location, radius) then
                return { success = false, error = "passenger_too_far" }
            end
        end
        local status_placeholders = {}
        local parameters = { next_status }
        for status in pairs(expected_statuses) do
            status_placeholders[#status_placeholders + 1] = "?"
            parameters[#parameters + 1] = status
        end
        parameters[#parameters + 1] = ride_id
        parameters[#parameters + 1] = profile.id
        local update = Bridge.Database.Query(([[
            UPDATE `sky_phone_skyride_rides`
            SET `status` = ?, `%s` = CURRENT_TIMESTAMP
            WHERE `status` IN (%s) AND `id` = ? AND `driver_profile_id` = ?
        ]]):format(timestamp_column, table.concat(status_placeholders, ", ")), parameters)
        if affected_rows(update) ~= 1 then
            return { success = false, error = "invalid_ride_status" }
        end
        local _, updated_row = ride_by_id(ride_id)
        push_participants(updated_row, { activeRide = true }, source)
        return {
            success = true,
            data = state_snapshot(source, profile, { activeRide = true }),
        }
    end)
    return result or lock_error
end

Bridge.Callbacks.Register("sky_phone:skyride:bootstrap", function(source)
    if not SkyPhone.AllowOperation(source, "skyride_read", Config.SkyRide.ReadsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local online = driver_online(source, profile)
    return {
        success = true,
        data = {
            activeRide = active_ride(profile.id) or false,
            availableRequests = online and available_requests(profile.id) or {},
            driverEligible = driver_eligible(source),
            driverOnline = online,
            history = ride_history(profile.id),
            pendingRating = pending_rating(profile.id) or false,
            profile = profile_snapshot(source, profile),
            quickLocations = quick_locations(),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skyride:update-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local name = type(data) == "table" and type(data.name) == "string"
        and data.name:match("^%s*(.-)%s*$") or nil
    local name_length = name and utf8.len(name) or nil
    local avatar_media_id = type(data) == "table" and tonumber(data.avatarMediaId) or nil
    if not name_length
        or name_length < Config.SkyRide.ProfileNameMinLength
        or name_length > Config.SkyRide.ProfileNameMaxLength
    then
        return { success = false, error = "invalid_profile_name" }
    end
    if not avatar_media_id or avatar_media_id < 0 or avatar_media_id ~= math.floor(avatar_media_id) then
        return { success = false, error = "invalid_profile_image" }
    end
    if avatar_media_id > 0
        and not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(avatar_media_id), "photo")
    then
        return { success = false, error = "invalid_profile_image" }
    end
    local result, lock_error = run_locked("profile:" .. profile.id, function()
        local update = Bridge.Database.Query([[
            UPDATE `sky_phone_skyride_profiles`
            SET `display_name` = ?, `avatar_media_id` = NULLIF(?, 0)
            WHERE `id` = ? AND `owner_identifier` = ?
        ]], { name, avatar_media_id, profile.id, profile.owner_identifier })
        if affected_rows(update) > 1 then
            error(("[sky_phone] SkyRide profile update affected multiple rows for '%s'."):format(profile.id))
        end
        local updated_profile = require_profile(source)
        local ride = active_ride(profile.id)
        if ride then
            push_participants(ride, { activeRide = true }, source)
        end
        push_available_requests(source)
        return {
            success = true,
            data = state_snapshot(source, updated_profile, { profile = true }),
        }
    end)
    return result or lock_error
end)

Bridge.Callbacks.Register("sky_phone:skyride:history", function(source)
    if not SkyPhone.AllowOperation(source, "skyride_read", Config.SkyRide.ReadsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    return { success = true, data = { items = ride_history(profile.id) } }
end)

Bridge.Callbacks.Register("sky_phone:skyride:quote", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_quote", Config.SkyRide.QuotesPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local pickup = validate_location(data and data.pickup)
    local destination = validate_location(data and data.destination)
    if not pickup or not destination then
        return { success = false, error = "invalid_location" }
    end
    if not is_near(source, pickup, Config.SkyRide.PickupSelectionRadius) then
        return { success = false, error = "pickup_too_far" }
    end
    local custom_fare = data and data.customFare or nil
    if custom_fare ~= nil then
        local custom_service = type(custom_fare) == "table" and custom_fare.serviceClass or nil
        local custom_price = type(custom_fare) == "table" and custom_fare.price or nil
        if not Config.SkyRide.CustomFare.Enabled
            or type(custom_service) ~= "string"
            or not services[custom_service]
            or type(custom_price) ~= "number"
            or custom_price ~= custom_price
            or custom_price ~= math.floor(custom_price)
        then
            return { success = false, error = "invalid_custom_fare" }
        end
        custom_fare = {
            price = custom_price,
            service_class = custom_service,
        }
    end
    local direct_distance = distance_between(pickup.coords, destination.coords)
    local distance_meters = math.floor((direct_distance * Config.SkyRide.RouteDistanceMultiplier) + 0.5)
    if distance_meters < Config.SkyRide.MinimumDistanceMeters
        or distance_meters > Config.SkyRide.MaximumDistanceMeters
    then
        return { success = false, error = "invalid_route" }
    end
    local duration_seconds = math.max(
        60,
        math.floor((distance_meters / Config.SkyRide.AverageSpeedMetersPerSecond) + 0.5)
    )
    local now = os.time()
    local expires_at = now + Config.SkyRide.QuoteLifetimeSeconds
    local quote_group = generate_uuid()
    local options = {}
    local distance_unit = Config.SkyRide.DistanceUnit
    local distance_value = distance_meters / (distance_unit == "mile" and 1609.344 or 1000)
    for index = 1, #Config.SkyRide.Services do
        local service = Config.SkyRide.Services[index]
        local price_per_distance_unit = distance_unit == "mile"
            and service.PricePerMile
            or service.PricePerKilometer
        local calculated_price = math.floor(math.max(
            service.MinimumFare,
            service.BaseFare
                + (distance_value * price_per_distance_unit)
                + ((duration_seconds / 60) * service.PricePerMinute)
        ) + 0.5)
        local minimum_custom_price = math.floor(math.max(
            Config.SkyRide.CustomFare.MinimumPrice,
            service.MinimumFare,
            calculated_price * Config.SkyRide.CustomFare.MinimumCalculatedMultiplier
        ) + 0.5)
        local maximum_custom_price = math.floor(math.min(
            Config.SkyRide.CustomFare.MaximumPrice,
            calculated_price * Config.SkyRide.CustomFare.MaximumCalculatedMultiplier
        ) + 0.5)
        local uses_custom_fare = custom_fare and custom_fare.service_class == service.Id
        if uses_custom_fare
            and (custom_fare.price < minimum_custom_price or custom_fare.price > maximum_custom_price)
        then
            discard_quote_group(quote_group)
            return { success = false, error = "invalid_custom_fare" }
        end
        local price = uses_custom_fare and custom_fare.price or calculated_price
        local quote_id = quote_group .. ":" .. service.Id
        local option = {
            available = true,
            calculatedPrice = calculated_price,
            currency = Config.SkyRide.Currency,
            etaMinutes = service.EtaMinutes,
            fareMode = uses_custom_fare and "custom" or "calculated",
            maximumCustomPrice = maximum_custom_price,
            minimumCustomPrice = minimum_custom_price,
            price = price,
            pricePerDistanceUnit = price_per_distance_unit,
            quoteId = quote_id,
            seats = service.Seats,
            serviceClass = service.Id,
        }
        quotes[quote_id] = {
            destination = destination,
            distance_meters = distance_meters,
            duration_seconds = duration_seconds,
            expires_at = expires_at,
            group = quote_group,
            option = option,
            pickup = pickup,
            profile_id = profile.id,
            source = source,
        }
        options[index] = option
    end
    return {
        success = true,
        data = {
            destination = destination,
            distance = distance_value,
            distanceMeters = distance_meters,
            distanceUnit = distance_unit,
            durationSeconds = duration_seconds,
            expiresAt = expires_at,
            options = options,
            pickup = pickup,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skyride:request", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local quote_id = type(data) == "table" and data.quoteId or nil
    if type(quote_id) ~= "string" or #quote_id > 64 then
        return { success = false, error = "quote_not_found" }
    end
    local quote = quotes[quote_id]
    if not quote or quote.source ~= source or quote.profile_id ~= profile.id then
        return { success = false, error = "quote_not_found" }
    end
    if quote.expires_at <= os.time() then
        quotes[quote_id] = nil
        return { success = false, error = "quote_expired" }
    end
    if not is_near(source, quote.pickup, Config.SkyRide.PickupSelectionRadius) then
        return { success = false, error = "pickup_too_far" }
    end
    local result, lock_error = run_locked("profile:" .. profile.id, function()
        local pending_rows = select_ride_rows([[
            r.`passenger_profile_id` = ? AND r.`status` = 'payment_pending'
        ]], { profile.id }, 1)
        if active_ride(profile.id) or pending_rows[1] then
            return { success = false, error = "active_ride_exists" }
        end
        local ride_id = generate_uuid()
        local price = quote.option.price
        local payout = math.floor((price * Config.SkyRide.DriverPayoutPercent / 100) + 0.5)
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_skyride_rides`
                (`id`, `passenger_profile_id`, `passenger_name`, `status`, `service_class`,
                    `pickup_label`, `pickup_x`, `pickup_y`, `pickup_z`,
                    `destination_label`, `destination_x`, `destination_y`, `destination_z`,
                    `distance_meters`, `duration_seconds`, `price`, `payout_amount`, `currency`)
            VALUES (?, ?, ?, 'payment_pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            ride_id,
            profile.id,
            profile.display_name or player_name(source),
            quote.option.serviceClass,
            quote.pickup.label,
            quote.pickup.coords.x,
            quote.pickup.coords.y,
            quote.pickup.coords.z,
            quote.destination.label,
            quote.destination.coords.x,
            quote.destination.coords.y,
            quote.destination.coords.z,
            quote.distance_meters,
            quote.duration_seconds,
            price,
            payout,
            quote.option.currency,
        })
        local charge_success = true
        local charge_result = true
        if price > 0 then
            charge_success, charge_result = pcall(
                Bridge.Framework.RemoveMoney,
                source,
                Config.SkyRide.PaymentAccount,
                price
            )
        end
        if not charge_success then
            discard_quote_group(quote.group)
            Bridge.Debug(
                "error",
                "[sky_phone] Fare debit crashed for SkyRide '%s'; payment state is ambiguous and requires manual reconciliation: %s",
                ride_id,
                tostring(charge_result)
            )
            return { success = false, error = "refund_failed" }
        end
        if not charge_result then
            local delete_success, delete_result = pcall(
                Bridge.Database.Query,
                "DELETE FROM `sky_phone_skyride_rides` WHERE `id` = ? AND `status` = 'payment_pending'",
                { ride_id }
            )
            if not delete_success or affected_rows(delete_result) ~= 1 then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Failed to remove uncharged payment-pending SkyRide '%s'.",
                    ride_id
                )
            end
            return { success = false, error = "insufficient_funds" }
        end
        discard_quote_group(quote.group)
        if price > 0 then
            local capture_success, capture_result = pcall(
                Bridge.Database.Query,
                [[
                    UPDATE `sky_phone_skyride_rides`
                    SET `refund_status` = 'pending'
                    WHERE `id` = ? AND `status` = 'payment_pending'
                        AND `refund_status` = 'none'
                ]],
                { ride_id }
            )
            if not capture_success then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Fare was charged but its recovery marker failed for SkyRide '%s': %s. Manual reconciliation is required.",
                    ride_id,
                    tostring(capture_result)
                )
                return { success = false, error = "refund_failed" }
            end
            if affected_rows(capture_result) ~= 1 then
                local refund_success, refund_result = pcall(
                    Bridge.Framework.AddMoney,
                    source,
                    Config.SkyRide.PaymentAccount,
                    price
                )
                if refund_success and refund_result then
                    local delete_success, delete_result = pcall(
                        Bridge.Database.Query,
                        "DELETE FROM `sky_phone_skyride_rides` WHERE `id` = ? AND `status` = 'payment_pending'",
                        { ride_id }
                    )
                    if delete_success and affected_rows(delete_result) == 1 then
                        TriggerClientEvent("sky_phone:banking:changed", source)
                        return { success = false, error = "request_failed" }
                    end
                end
                Bridge.Debug(
                    "error",
                    "[sky_phone] Fare recovery failed before activating SkyRide '%s'. Manual reconciliation is required.",
                    ride_id
                )
                return { success = false, error = "refund_failed" }
            end
        end
        local update_success, update = pcall(Bridge.Database.Query, [[
            UPDATE `sky_phone_skyride_rides`
            SET `status` = 'searching', `refund_status` = 'none'
            WHERE `id` = ? AND `status` = 'payment_pending'
                AND `refund_status` = ?
        ]], { ride_id, price > 0 and "pending" or "none" })
        if not update_success or affected_rows(update) ~= 1 then
            local load_success, _, pending_row = pcall(ride_by_id, ride_id)
            if load_success and pending_row and pending_row.status == "searching" then
                update_success = true
            elseif load_success and pending_row and price > 0 and pending_row.refund_status == "pending" then
                local refunded = process_pending_refund(pending_row)
                if not refunded then
                    return { success = false, error = "refund_failed" }
                end
                return { success = false, error = "request_failed" }
            elseif price > 0 then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Could not verify fare recovery after SkyRide '%s' activation failed; manual reconciliation is required.",
                    ride_id
                )
                return { success = false, error = "refund_failed" }
            else
                local delete_success, delete_result = pcall(
                    Bridge.Database.Query,
                    [[
                        DELETE FROM `sky_phone_skyride_rides`
                        WHERE `id` = ? AND `status` = 'payment_pending'
                            AND `refund_status` = 'none'
                    ]],
                    { ride_id }
                )
                if not delete_success or affected_rows(delete_result) ~= 1 then
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Failed to clean payment-pending SkyRide '%s' after request activation failed.",
                        ride_id
                    )
                end
                if not update_success then
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Failed to activate SkyRide '%s': %s",
                        ride_id,
                        tostring(update)
                    )
                end
                return { success = false, error = "request_failed" }
            end
        end
        TriggerClientEvent("sky_phone:banking:changed", source)
        push_available_requests(source)
        return {
            success = true,
            data = state_snapshot(source, profile, {
                activeRide = true,
                availableRequests = true,
            }),
        }
    end)
    return result or lock_error
end)

Bridge.Callbacks.Register("sky_phone:skyride:set-driver-status", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or type(data.online) ~= "boolean" then
        return { success = false, error = "invalid_driver_status" }
    end
    if data.online and not driver_eligible(source) then
        return { success = false, error = "driver_not_eligible" }
    end
    local _, ride_row = active_ride(profile.id)
    if not data.online and ride_row and ride_row.driver_profile_id == profile.id then
        return { success = false, error = "active_ride_exists" }
    end
    if data.online and ride_row and ride_row.passenger_profile_id == profile.id and not ride_row.driver_profile_id then
        return { success = false, error = "active_ride_exists" }
    end
    online_drivers[source] = data.online and {
        identifier = profile.owner_identifier,
        profile_id = profile.id,
    } or nil
    return {
        success = true,
        data = state_snapshot(source, profile, {
            driverOnline = true,
            availableRequests = true,
        }),
    }
end)

Bridge.Callbacks.Register("sky_phone:skyride:accept", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if not driver_online(source, profile) then
        return { success = false, error = "driver_offline" }
    end
    local ride_id = valid_ride_id(data)
    if not ride_id then
        return { success = false, error = "ride_not_found" }
    end
    local result, lock_error = run_locked("profile:" .. profile.id, function()
        if active_ride(profile.id) then
            return { success = false, error = "active_ride_exists" }
        end
        local _, row = ride_by_id(ride_id)
        if not row then
            return { success = false, error = "ride_not_found" }
        end
        if row.status ~= "searching" then
            return { success = false, error = "invalid_ride_status" }
        end
        if row.passenger_profile_id == profile.id then
            return { success = false, error = "not_ride_participant" }
        end
        local vehicle = current_vehicle(source)
        if not vehicle then
            return { success = false, error = "driver_vehicle_required" }
        end
        local update = Bridge.Database.Query([[
            UPDATE `sky_phone_skyride_rides`
            SET `driver_profile_id` = ?, `driver_name` = ?, `status` = 'accepted',
                `driver_vehicle_model` = ?, `driver_vehicle_color` = ?, `driver_vehicle_plate` = ?,
                `accepted_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `status` = 'searching' AND `driver_profile_id` IS NULL
        ]], {
            profile.id,
            profile.display_name or player_name(source),
            vehicle.model,
            vehicle.color,
            vehicle.plate,
            ride_id,
        })
        if affected_rows(update) ~= 1 then
            return { success = false, error = "invalid_ride_status" }
        end
        local _, updated_row = ride_by_id(ride_id)
        push_participants(updated_row, { activeRide = true, availableRequests = true }, source)
        push_available_requests(source)
        return {
            success = true,
            data = state_snapshot(source, profile, {
                activeRide = true,
                availableRequests = true,
            }),
        }
    end)
    return result or lock_error
end)

Bridge.Callbacks.Register("sky_phone:skyride:arrive", function(source, data)
    return transition_driver_ride(
        source,
        data,
        { accepted = true },
        "arrived",
        "arrived_at",
        Config.SkyRide.ArrivalRadius,
        "pickup"
    )
end)

Bridge.Callbacks.Register("sky_phone:skyride:start", function(source, data)
    return transition_driver_ride(
        source,
        data,
        { arrived = true },
        "in_progress",
        "started_at",
        Config.SkyRide.ArrivalRadius,
        "pickup"
    )
end)

Bridge.Callbacks.Register("sky_phone:skyride:complete", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if not driver_online(source, profile) then
        return { success = false, error = "driver_offline" }
    end
    local ride_id = valid_ride_id(data)
    if not ride_id then
        return { success = false, error = "ride_not_found" }
    end
    local result, lock_error = run_locked("ride:" .. ride_id, function()
        local _, row = ride_by_id(ride_id)
        if not row then
            return { success = false, error = "ride_not_found" }
        end
        if row.driver_profile_id ~= profile.id then
            return { success = false, error = "not_ride_participant" }
        end
        if row.status ~= "in_progress" then
            return { success = false, error = "invalid_ride_status" }
        end
        local destination = {
            coords = {
                x = tonumber(row.destination_x),
                y = tonumber(row.destination_y),
                z = tonumber(row.destination_z),
            },
        }
        if not is_near(source, destination, Config.SkyRide.CompletionRadius) then
            return { success = false, error = "destination_too_far" }
        end
        local passenger_source = source_for_identifier(row.passenger_identifier)
        if not passenger_source or not is_near(passenger_source, destination, Config.SkyRide.CompletionRadius) then
            return { success = false, error = "passenger_too_far" }
        end
        local completing = Bridge.Database.Query([[
            UPDATE `sky_phone_skyride_rides`
            SET `status` = 'completing'
            WHERE `id` = ? AND `driver_profile_id` = ? AND `status` = 'in_progress'
        ]], { ride_id, profile.id })
        if affected_rows(completing) ~= 1 then
            return { success = false, error = "invalid_ride_status" }
        end
        local payout = tonumber(row.payout_amount) or 0
        local payout_success = true
        local payout_result = true
        if payout > 0 then
            payout_success, payout_result = pcall(
                Bridge.Framework.AddMoney,
                source,
                Config.SkyRide.PaymentAccount,
                payout
            )
        end
        if not payout_success then
            Bridge.Debug(
                "error",
                "[sky_phone] Driver payout crashed for SkyRide '%s'; completing state prevents an ambiguous retry and requires manual reconciliation: %s",
                ride_id,
                tostring(payout_result)
            )
            return { success = false, error = "payout_failed" }
        end
        if not payout_result then
            local reset_success, reset_result = pcall(Bridge.Database.Query, [[
                UPDATE `sky_phone_skyride_rides`
                SET `status` = 'in_progress'
                WHERE `id` = ? AND `status` = 'completing'
            ]], { ride_id })
            if not reset_success or affected_rows(reset_result) ~= 1 then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Driver payout failed and SkyRide '%s' could not be restored to in-progress.",
                    ride_id
                )
            end
            return { success = false, error = "payout_failed" }
        end
        local completed_success, completed = pcall(Bridge.Database.Query, [[
            UPDATE `sky_phone_skyride_rides`
            SET `status` = 'completed', `completed_at` = CURRENT_TIMESTAMP,
                `paid_out_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `status` = 'completing'
        ]], { ride_id })
        if not completed_success then
            Bridge.Debug(
                "error",
                "[sky_phone] SkyRide '%s' completion query crashed after payout; completing state blocks an ambiguous retry and requires manual reconciliation: %s",
                ride_id,
                tostring(completed)
            )
            return { success = false, error = "payout_failed" }
        end
        if affected_rows(completed) ~= 1 then
            local compensation_success = true
            local compensation_result = true
            if payout > 0 then
                compensation_success, compensation_result = pcall(
                    Bridge.Framework.RemoveMoney,
                    source,
                    Config.SkyRide.PaymentAccount,
                    payout
                )
            end
            if compensation_success and compensation_result then
                local reset_success, reset_result = pcall(Bridge.Database.Query, [[
                    UPDATE `sky_phone_skyride_rides`
                    SET `status` = 'in_progress', `completed_at` = NULL, `paid_out_at` = NULL
                    WHERE `id` = ? AND `status` = 'completing'
                ]], { ride_id })
                if reset_success and affected_rows(reset_result) == 1 then
                    if payout > 0 then
                        TriggerClientEvent("sky_phone:banking:changed", source)
                    end
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Compensated driver payout after SkyRide '%s' completion could not be finalized.",
                        ride_id
                    )
                    return { success = false, error = "payout_failed" }
                end
                Bridge.Debug(
                    "error",
                    "[sky_phone] Driver payout was compensated but SkyRide '%s' could not be restored; manual reconciliation is required.",
                    ride_id
                )
                return { success = false, error = "payout_failed" }
            end
            Bridge.Debug(
                "error",
                "[sky_phone] Failed to compensate payout for unfinalized SkyRide '%s'; completing state prevents an automatic duplicate payout: %s",
                ride_id,
                tostring(compensation_result)
            )
            return { success = false, error = "payout_failed" }
        end
        TriggerClientEvent("sky_phone:banking:changed", source)
        local _, updated_row = ride_by_id(ride_id)
        push_participants(updated_row, {
            activeRide = true,
            history = true,
            pendingRating = true,
            profile = true,
        }, source)
        return {
            success = true,
            data = state_snapshot(source, profile, {
                activeRide = true,
                history = true,
                pendingRating = true,
                profile = true,
            }),
        }
    end)
    return result or lock_error
end)

Bridge.Callbacks.Register("sky_phone:skyride:cancel", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local ride_id = valid_ride_id(data)
    if not ride_id then
        return { success = false, error = "ride_not_found" }
    end
    local reason = data.reason
    if reason ~= nil and (type(reason) ~= "string" or not allowed_cancel_reasons[reason]) then
        return { success = false, error = "invalid_cancel_reason" }
    end
    local result, lock_error = run_locked("ride:" .. ride_id, function()
        local _, row = ride_by_id(ride_id)
        if not row then
            return { success = false, error = "ride_not_found" }
        end
        local role
        if row.passenger_profile_id == profile.id then
            role = "passenger"
        elseif row.driver_profile_id == profile.id then
            role = "driver"
        else
            return { success = false, error = "not_ride_participant" }
        end
        if row.status ~= "searching"
            and row.status ~= "accepted"
            and row.status ~= "arrived"
            and row.status ~= "in_progress"
        then
            return { success = false, error = "invalid_ride_status" }
        end
        if row.status == "searching" and role ~= "passenger" then
            return { success = false, error = "not_ride_participant" }
        end
        local update = Bridge.Database.Query([[
            UPDATE `sky_phone_skyride_rides`
            SET `status` = 'cancelled', `cancelled_by` = ?, `cancel_reason` = ?,
                `cancelled_at` = CURRENT_TIMESTAMP, `refund_status` = 'pending'
            WHERE `id` = ? AND `status` IN ('searching','accepted','arrived','in_progress')
                AND `refund_status` = 'none'
        ]], { role, reason, ride_id })
        if affected_rows(update) ~= 1 then
            return { success = false, error = "invalid_ride_status" }
        end
        local _, updated_row = ride_by_id(ride_id)
        if not process_pending_refund(updated_row) then
            Bridge.Debug(
                "info",
                "[sky_phone] Refund for cancelled SkyRide '%s' remains queued for server recovery.",
                ride_id
            )
        end
        _, updated_row = ride_by_id(ride_id)
        push_participants(updated_row, {
            activeRide = true,
            availableRequests = true,
            history = true,
            pendingRating = true,
            profile = true,
        }, source)
        push_available_requests(source)
        return {
            success = true,
            data = state_snapshot(source, profile, {
                activeRide = true,
                availableRequests = true,
                history = true,
                pendingRating = true,
                profile = true,
            }),
        }
    end)
    return result or lock_error
end)

Bridge.Callbacks.Register("sky_phone:skyride:rate", function(source, data)
    if not SkyPhone.AllowOperation(source, "skyride_action", Config.SkyRide.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local ride_id = valid_ride_id(data)
    if not ride_id then
        return { success = false, error = "ride_not_found" }
    end
    local rating = tonumber(data.rating)
    local tip = tonumber(data.tip) or 0
    local comment = type(data.comment) == "string" and data.comment:match("^%s*(.-)%s*$") or ""
    local comment_length = utf8.len(comment)
    if not rating or rating ~= math.floor(rating) or rating < 1 or rating > 5 then
        return { success = false, error = "invalid_rating" }
    end
    if not tip or tip ~= math.floor(tip) or tip < 0 or tip > Config.SkyRide.MaximumTip then
        return { success = false, error = "invalid_tip" }
    end
    if not comment_length or comment_length > Config.SkyRide.RatingCommentMaxLength then
        return { success = false, error = "invalid_comment" }
    end
    local result, lock_error = run_locked("ride:" .. ride_id, function()
        local _, row = ride_by_id(ride_id)
        if not row then
            return { success = false, error = "ride_not_found" }
        end
        if row.passenger_profile_id ~= profile.id then
            return { success = false, error = "not_ride_participant" }
        end
        if row.status ~= "completed" or row.passenger_rating ~= nil or row.tip_status ~= "none" then
            return { success = false, error = "invalid_ride_status" }
        end
        local driver_source = source_for_identifier(row.driver_identifier)
        if tip > 0 and not driver_source then
            return { success = false, error = "driver_unavailable" }
        end
        if not transition_tip_status(ride_id, "none", "processing") then
            return { success = false, error = "invalid_ride_status" }
        end
        if tip > 0 then
            local debit_success, debit_result = pcall(
                Bridge.Framework.RemoveMoney,
                source,
                Config.SkyRide.PaymentAccount,
                tip
            )
            if not debit_success then
                transition_tip_status(ride_id, "processing", "failed")
                Bridge.Debug(
                    "error",
                    "[sky_phone] Passenger tip debit crashed for SkyRide '%s'; manual reconciliation is required: %s",
                    ride_id,
                    tostring(debit_result)
                )
                return { success = false, error = "tip_failed" }
            end
            if not debit_result then
                transition_tip_status(ride_id, "processing", "none")
                return { success = false, error = "insufficient_funds" }
            end
            local credit_success, credit_result = pcall(
                Bridge.Framework.AddMoney,
                driver_source,
                Config.SkyRide.PaymentAccount,
                tip
            )
            if not credit_success then
                transition_tip_status(ride_id, "processing", "failed")
                Bridge.Debug(
                    "error",
                    "[sky_phone] Driver tip credit crashed for SkyRide '%s'; retry is blocked for manual reconciliation: %s",
                    ride_id,
                    tostring(credit_result)
                )
                return { success = false, error = "tip_failed" }
            end
            if not credit_result then
                local refund_success, refund_result = pcall(
                    Bridge.Framework.AddMoney,
                    source,
                    Config.SkyRide.PaymentAccount,
                    tip
                )
                if refund_success and refund_result then
                    transition_tip_status(ride_id, "processing", "none")
                    TriggerClientEvent("sky_phone:banking:changed", source)
                else
                    transition_tip_status(ride_id, "processing", "failed")
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Passenger refund after rejected driver tip credit is ambiguous or failed for SkyRide '%s'; retry is blocked for manual reconciliation: %s",
                        ride_id,
                        tostring(refund_result)
                    )
                end
                return { success = false, error = "tip_failed" }
            end
        end
        local update_success, update = pcall(Bridge.Database.Query, [[
            UPDATE `sky_phone_skyride_rides`
            SET `passenger_rating` = ?, `rating_comment` = ?, `tip_amount` = ?,
                `tip_status` = 'completed'
            WHERE `id` = ? AND `passenger_profile_id` = ?
                AND `status` = 'completed' AND `passenger_rating` IS NULL
                AND `tip_status` = 'processing'
        ]], { rating, comment, tip, ride_id, profile.id })
        if not update_success then
            Bridge.Debug(
                "error",
                "[sky_phone] Rating query crashed after tip transfer for SkyRide '%s'; processing state blocks an ambiguous retry and requires manual reconciliation: %s",
                ride_id,
                tostring(update)
            )
            return { success = false, error = "tip_failed" }
        end
        if affected_rows(update) ~= 1 then
            if tip == 0 then
                transition_tip_status(ride_id, "processing", "none")
                return { success = false, error = "tip_failed" }
            end
            local driver_debit_success, driver_debit_result = pcall(
                Bridge.Framework.RemoveMoney,
                driver_source,
                Config.SkyRide.PaymentAccount,
                tip
            )
            if not driver_debit_success or not driver_debit_result then
                transition_tip_status(ride_id, "processing", "failed")
                Bridge.Debug(
                    "error",
                    "[sky_phone] Rating persistence failed and driver tip debit was ambiguous or rejected for SkyRide '%s'; passenger refund was not attempted and manual reconciliation is required: %s",
                    ride_id,
                    tostring(driver_debit_result)
                )
                return { success = false, error = "tip_failed" }
            end
            TriggerClientEvent("sky_phone:banking:changed", driver_source)
            local passenger_refund_success, passenger_refund_result = pcall(
                Bridge.Framework.AddMoney,
                source,
                Config.SkyRide.PaymentAccount,
                tip
            )
            if passenger_refund_success and passenger_refund_result then
                TriggerClientEvent("sky_phone:banking:changed", source)
                transition_tip_status(ride_id, "processing", "none")
                Bridge.Debug(
                    "error",
                    "[sky_phone] Compensated rating persistence failure for SkyRide '%s'.",
                    ride_id
                )
            else
                transition_tip_status(ride_id, "processing", "failed")
                Bridge.Debug(
                    "error",
                    "[sky_phone] Driver tip was removed but passenger refund was ambiguous or rejected for SkyRide '%s'; manual reconciliation is required: %s",
                    ride_id,
                    tostring(passenger_refund_result)
                )
            end
            return { success = false, error = "tip_failed" }
        end
        if tip > 0 then
            TriggerClientEvent("sky_phone:banking:changed", source)
            TriggerClientEvent("sky_phone:banking:changed", driver_source)
        end
        local _, updated_row = ride_by_id(ride_id)
        push_participants(updated_row, { history = true, pendingRating = true, profile = true }, source)
        return {
            success = true,
            data = state_snapshot(source, profile, {
                history = true,
                pendingRating = true,
                profile = true,
            }),
        }
    end)
    return result or lock_error
end)

AddEventHandler("playerDropped", function()
    local player_source = source
    online_drivers[player_source] = nil
    for quote_id, quote in pairs(quotes) do
        if quote.source == player_source then
            quotes[quote_id] = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for quote_id, quote in pairs(quotes) do
            if quote.expires_at <= now or not GetPlayerName(quote.source) then
                quotes[quote_id] = nil
            end
        end
        for source in pairs(online_drivers) do
            if not GetPlayerName(source) then
                online_drivers[source] = nil
            end
        end
    end
end)

CreateThread(function()
    local reconciliation_rows = Bridge.Database.Query([[
        SELECT
            SUM(`refund_status` = 'processing') AS `processing_refunds`,
            SUM(`tip_status` IN ('processing','failed')) AS `unresolved_tips`,
            SUM(`status` = 'completing') AS `unresolved_payouts`,
            SUM(`status` = 'payment_pending' AND `refund_status` = 'none') AS `ambiguous_payments`
        FROM `sky_phone_skyride_rides`
    ]], {})
    local reconciliation = reconciliation_rows[1] or {}
    if (tonumber(reconciliation.processing_refunds) or 0) > 0
        or (tonumber(reconciliation.unresolved_tips) or 0) > 0
        or (tonumber(reconciliation.unresolved_payouts) or 0) > 0
        or (tonumber(reconciliation.ambiguous_payments) or 0) > 0
    then
        Bridge.Debug(
            "error",
            "[sky_phone] SkyRide has unresolved cross-system payments (refunds=%s, tips=%s, payouts=%s, ambiguous fares=%s); manual reconciliation is required.",
            tostring(reconciliation.processing_refunds or 0),
            tostring(reconciliation.unresolved_tips or 0),
            tostring(reconciliation.unresolved_payouts or 0),
            tostring(reconciliation.ambiguous_payments or 0)
        )
    end
    while true do
        local recovery_success, recovery_rows = pcall(
            Bridge.Database.Query,
            (([[
                SELECT r.`id`, r.`status`, r.`refund_status`, r.`price`,
                    passenger.`owner_identifier` AS `passenger_identifier`
                FROM `sky_phone_skyride_rides` r
                INNER JOIN `sky_phone_skyride_profiles` passenger
                    ON passenger.`id` = r.`passenger_profile_id`
                WHERE (
                        r.`refund_status` = 'pending'
                        AND r.`status` = 'cancelled'
                    ) OR (
                        r.`refund_status` IN ('pending','completed')
                        AND r.`status` = 'payment_pending'
                        AND r.`updated_at` <= DATE_SUB(
                            CURRENT_TIMESTAMP,
                            INTERVAL %d SECOND
                        )
                    )
                ORDER BY r.`updated_at` ASC
                LIMIT 50
            ]]):format(math.floor(Config.SkyRide.PaymentPendingRecoverySeconds)))
        )
        if recovery_success then
            for index = 1, #recovery_rows do
                process_pending_refund(recovery_rows[index])
            end
        else
            Bridge.Debug(
                "error",
                "[sky_phone] SkyRide refund recovery query failed: %s",
                tostring(recovery_rows)
            )
        end
        Wait(math.floor(Config.SkyRide.RecoveryIntervalSeconds * 1000))
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    quotes = {}
    online_drivers = {}
    operation_locks = {}
end)
end)
