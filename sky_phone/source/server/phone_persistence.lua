Bridge.Database.AfterMigration("sky_phone", function()
SkyPhonePersistence = {}

local max_device_data_bytes = 100000
local allowed_device_namespaces = {
    settings = true,
    notifications = true,
    wallpaper = true,
    alarms = true,
    appAuth = true,
    apps = true,
    games = true,
    widgets = true,
    citywarn = true,
}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function valid_notifications(payload)
    if type(payload) ~= "table" or payload.version ~= 1 or type(payload.items) ~= "table" then
        return false
    end

    local item_count = #payload.items
    local key_count = 0
    for key in pairs(payload.items) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > item_count then
            return false
        end
        key_count = key_count + 1
    end
    if key_count ~= item_count then
        return false
    end

    for _, item in ipairs(payload.items) do
        if type(item) ~= "table"
            or type(item.appId) ~= "string" or #item.appId > 64
            or type(item.id) ~= "string" or #item.id > 100
            or type(item.title) ~= "string" or #item.title > 200
            or type(item.text) ~= "string" or #item.text > 2000
            or (item.subtitle ~= nil and (type(item.subtitle) ~= "string" or #item.subtitle > 200))
        then
            return false
        end
    end

    return true
end

Bridge.Callbacks.Register("sky_phone:device:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "device_save", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if data.imei ~= session.imei or data.sessionToken ~= session.token then
        return { success = false, error = "stale_session" }
    end
    if not allowed_device_namespaces[data.namespace] then
        return { success = false, error = "invalid_namespace" }
    end

    local encoded = json.encode(data.payload)
    if #encoded > max_device_data_bytes then
        return { success = false, error = "payload_too_large" }
    end
    local revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision`
        FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = ?
        LIMIT 1
    ]], { session.imei, data.namespace })

    if rows[1] then
        local current_revision = tonumber(rows[1].revision) or 0
        if revision ~= current_revision then
            SkyPhone.RefreshSource(source)
            return {
                success = false,
                error = "conflict",
                data = { payload = json.decode(rows[1].payload), revision = current_revision },
            }
        end
        local result = Bridge.Database.Query([[
            UPDATE `sky_phone_device_data`
            SET `payload` = ?, `revision` = `revision` + 1
            WHERE `device_imei` = ? AND `namespace` = ? AND `revision` = ?
        ]], { encoded, session.imei, data.namespace, revision })
        if affected_rows(result) ~= 1 then
            SkyPhone.RefreshSource(source)
            return { success = false, error = "conflict" }
        end
        return { success = true, data = { revision = revision + 1 } }
    end

    if revision ~= 0 then
        return { success = false, error = "conflict" }
    end
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, ?, ?)
    ]], { session.imei, data.namespace, encoded })
    if affected_rows(result) <= 0 then
        SkyPhone.RefreshSource(source)
        return { success = false, error = "conflict" }
    end
    return { success = true, data = { revision = 1 } }
end)

Bridge.Callbacks.Register("sky_phone:notifications:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "notifications_save", 240, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) or type(data.payload) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if #SkyPhone.FindDeviceSlots(source, data.imei) == 0 then
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s attempted to save notifications for unowned device %s.",
            tostring(source),
            tostring(data.imei)
        )
        return { success = false, error = "device_not_owned" }
    end
    if not valid_notifications(data.payload) then
        return { success = false, error = "invalid_request" }
    end

    local encoded = json.encode(data.payload)
    if #encoded > max_device_data_bytes then
        return { success = false, error = "payload_too_large" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, 'notifications', ?)
        ON DUPLICATE KEY UPDATE `payload` = VALUES(`payload`), `revision` = `revision` + 1
    ]], { data.imei, encoded })
    return { success = true }
end)

function SkyPhonePersistence.FactoryReset(imei)
    if not SkyPhoneImei.IsValid(imei) then
        return false, "invalid_request"
    end

    local device = SkyPhone.LoadDevice(imei)
    if not device then
        return false, "device_not_found"
    end
    local phone_number = device and device.phone_number or nil
    local media_remote_ids = SkyPhoneMedia.GetDeviceRemoteIds(imei)
    if not Bridge.Database.Transaction({
        {
            query = "DELETE FROM `sky_phone_device_security` WHERE `device_imei` = ?",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_device_data` WHERE `device_imei` = ?",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_custom_app_data` WHERE `device_imei` = ?",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_notes` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_media` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_music_playlists` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_music_youtube_songs` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_contacts` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_call_entries` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { imei },
        },
        {
            query = "DELETE FROM `sky_phone_fliptok_sessions` WHERE `device_imei` = ?",
            params = { imei },
        },
        {
            query = "UPDATE `sky_phone_devices` SET `account_id` = NULL, `device_name` = ? WHERE `imei` = ?",
            params = { Config.Phone.DeviceName, imei },
        },
    }) then
        return false, "request_failed"
    end
    SkyPhoneMedia.CleanupRemoteFiles(media_remote_ids)
    return true, phone_number
end

Bridge.Callbacks.Register("sky_phone:device:factory-reset", function(source)
    if not SkyPhone.AllowOperation(source, "factory_reset", 3, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    local reset, phone_number = SkyPhonePersistence.FactoryReset(session.imei)
    if not reset then
        return { success = false, error = phone_number }
    end
    session.unlocked = true
    if phone_number then
        TriggerEvent("sky_phone:server:factoryReset", source, phone_number)
    end
    SkyPhone.RefreshSource(source)
    return { success = true }
end)
end)
