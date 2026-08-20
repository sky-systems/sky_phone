local NOTIFICATION_TEXT_MAX_LENGTH = 2000
local NOTIFICATION_TITLE_MAX_LENGTH = 160

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function normalize_text(value, error_code, maximum_length)
    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = trim(value)
    if normalized == "" or #normalized > maximum_length then
        return nil, error_code
    end
    return normalized
end

local function resolve_alias(data, primary_key, alternate_key, error_code)
    local primary = data[primary_key]
    local alternate = data[alternate_key]
    if primary ~= nil and alternate ~= nil and primary ~= alternate then
        return nil, error_code
    end
    return primary ~= nil and primary or alternate
end

local function normalize_notification(notification)
    if type(notification) ~= "table" then
        return nil, "invalid_notification"
    end

    local app_id = resolve_alias(notification, "appId", "app_id", "invalid_app_id")
    local valid_app_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_app_id then
        return nil, "invalid_app_id"
    end

    local title, title_error = normalize_text(
        notification.title,
        "invalid_title",
        NOTIFICATION_TITLE_MAX_LENGTH
    )
    if not title then
        return nil, title_error
    end

    local raw_text = resolve_alias(notification, "text", "body", "invalid_text")
    local notification_text, text_error = normalize_text(
        raw_text,
        "invalid_text",
        NOTIFICATION_TEXT_MAX_LENGTH
    )
    if not notification_text then
        return nil, text_error
    end

    return {
        appId = app_id,
        text = notification_text,
        title = title,
    }
end

local function normalize_source(value)
    if type(value) ~= "number"
        or value ~= value
        or value <= 0
        or value >= math.huge
        or value ~= math.floor(value)
    then
        return nil
    end
    return value
end

local function normalize_list_source(value)
    return normalize_source(tonumber(value))
end

local function normalize_target(target)
    if type(target) ~= "table" or type(target.kind) ~= "string" then
        return nil, "invalid_target"
    end

    if target.kind == "all" then
        if target.value ~= nil then
            return nil, "invalid_target"
        end
        return { kind = "all" }
    end

    if target.kind == "source" then
        local player_source = normalize_source(target.value)
        if not player_source then
            return nil, "invalid_target"
        end
        return { kind = "source", value = player_source }
    end

    if target.kind == "number" then
        local phone_number = SkyPhoneSimNumber.Normalize(
            target.value,
            Config.Sim.NumberLength,
            Config.Sim.NumberPrefix
        )
        if not phone_number then
            return nil, "invalid_target"
        end
        return { kind = "number", value = phone_number }
    end

    if target.kind == "device" then
        if not SkyPhoneImei.IsValid(target.value) then
            return nil, "invalid_target"
        end
        return { kind = "device", value = target.value }
    end

    return nil, "invalid_target"
end

Bridge.Database.AfterMigration("sky_phone", function()
    if type(SkyPhoneDeviceDirectory) ~= "table"
        or type(SkyPhoneDeviceDirectory.GetOnlineBySource) ~= "function"
        or type(SkyPhoneDeviceDirectory.GetOnlineByPhoneNumber) ~= "function"
        or type(SkyPhoneDeviceDirectory.GetOnlineByImei) ~= "function"
    then
        error("[sky_phone] Notification router initialized before the phone device directory.")
    end

    SkyPhoneNotifications = {}

    local function add_candidate(candidates, identity, expected_phone_number)
        if type(identity) ~= "table" then
            return
        end
        local player_source = normalize_source(identity.source)
        if not player_source or candidates[player_source] then
            return
        end
        if not SkyPhoneImei.IsValid(identity.imei) then
            return
        end

        candidates[player_source] = {
            expectedImei = identity.imei,
            expectedPhoneNumber = expected_phone_number,
            source = player_source,
        }
    end

    local function resolve_candidates(target)
        local candidates = {}
        if target.kind == "source" then
            add_candidate(candidates, SkyPhoneDeviceDirectory.GetOnlineBySource(target.value))
            return candidates
        end

        if target.kind == "number" then
            local identity = SkyPhoneDeviceDirectory.GetOnlineByPhoneNumber(target.value)
            add_candidate(candidates, identity, target.value)
            return candidates
        end

        if target.kind == "device" then
            add_candidate(candidates, SkyPhoneDeviceDirectory.GetOnlineByImei(target.value))
            return candidates
        end

        for _, player in ipairs(Bridge.Framework.GetPlayers()) do
            local player_source = normalize_list_source(player)
            if player_source and not candidates[player_source] then
                add_candidate(
                    candidates,
                    SkyPhoneDeviceDirectory.GetOnlineBySource(player_source)
                )
            end
        end
        return candidates
    end

    local function identity_still_matches(candidate, identity)
        return type(identity) == "table"
            and identity.source == candidate.source
            and identity.imei == candidate.expectedImei
            and (
                candidate.expectedPhoneNumber == nil
                or identity.phoneNumber == candidate.expectedPhoneNumber
            )
    end

    local function load_device_context(imei)
        local rows = Bridge.Database.Query([[
            SELECT d.`imei`, d.`device_name`, settings.`payload` AS `settings`
            FROM `sky_phone_devices` d
            LEFT JOIN `sky_phone_device_data` settings
                ON settings.`device_imei` = d.`imei`
                AND settings.`namespace` = 'settings'
            WHERE d.`imei` = ?
            LIMIT 1
        ]], { imei })
        local row = rows[1]
        if not row or row.imei ~= imei or type(row.device_name) ~= "string" then
            Bridge.Debug(
                "error",
                "[sky_phone] Notification delivery could not load device %s.",
                tostring(imei)
            )
            return nil
        end
        return {
            imei = row.imei,
            name = row.device_name,
            settings = row.settings,
        }
    end

    function SkyPhoneNotifications.Send(target, notification)
        local normalized_target, target_error = normalize_target(target)
        if not normalized_target then
            return nil, target_error
        end

        local normalized_notification, notification_error = normalize_notification(notification)
        if not normalized_notification then
            return nil, notification_error
        end

        local delivered = 0
        local candidates = resolve_candidates(normalized_target)
        for _, candidate in pairs(candidates) do
            local identity = SkyPhoneDeviceDirectory.GetOnlineBySource(candidate.source)
            if identity_still_matches(candidate, identity) then
                local device = load_device_context(candidate.expectedImei)
                local current_identity = device
                    and SkyPhoneDeviceDirectory.GetOnlineBySource(candidate.source)
                    or nil
                if device and identity_still_matches(candidate, current_identity) then
                    TriggerClientEvent(
                        "sky_phone:notifications:show",
                        candidate.source,
                        {
                            appId = normalized_notification.appId,
                            device = device,
                            text = normalized_notification.text,
                            title = normalized_notification.title,
                        }
                    )
                    delivered = delivered + 1
                end
            end
        end
        return { delivered = delivered }
    end

    Bridge.Callbacks.Register("sky_phone:notifications:self", function(source, notification)
        local result, notification_error = SkyPhoneNotifications.Send(
            { kind = "source", value = source },
            notification
        )
        if not result then
            return { success = false, error = notification_error }
        end
        if result.delivered ~= 1 then
            return { success = false, error = "device_not_equipped" }
        end
        return { success = true, data = result }
    end)
end)
