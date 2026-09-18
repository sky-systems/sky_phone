Bridge.Database.AfterMigration("sky_phone", function()
local STORAGE_JSON_MAX_DEPTH = 8
local STORAGE_JSON_MAX_NODES = 512
local storage_write_locks = {}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function validate_storage_json(value, depth, state)
    state.nodes = state.nodes + 1
    if state.nodes > STORAGE_JSON_MAX_NODES or depth > STORAGE_JSON_MAX_DEPTH then
        return false
    end

    local value_type = type(value)
    if value_type == "nil" or value_type == "boolean" then
        return true
    end
    if value_type == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    if value_type == "string" then
        return #value <= math.min(Config.CustomApps.MaximumStorageValueBytes, 65536)
    end
    if value_type ~= "table" or state.seen[value] then
        return false
    end

    state.seen[value] = true
    local key_type = nil
    local numeric_keys = 0
    local value_count = 0
    for key, nested_value in pairs(value) do
        value_count = value_count + 1
        local current_key_type = type(key)
        if current_key_type == "number" then
            if key < 1 or key % 1 ~= 0 then
                state.seen[value] = nil
                return false
            end
            numeric_keys = numeric_keys + 1
        elseif current_key_type ~= "string"
            or #key == 0
            or #key > 64
            or key == "__proto__"
            or key == "constructor"
            or key == "prototype"
        then
            state.seen[value] = nil
            return false
        end

        if key_type and key_type ~= current_key_type then
            state.seen[value] = nil
            return false
        end
        key_type = current_key_type

        if not validate_storage_json(nested_value, depth + 1, state) then
            state.seen[value] = nil
            return false
        end
    end

    if key_type == "number" and (numeric_keys ~= value_count or #value ~= value_count) then
        state.seen[value] = nil
        return false
    end

    state.seen[value] = nil
    return true
end

local function with_storage_write_lock(lock_key, callback)
    local previous_lock = storage_write_locks[lock_key]
    local current_lock = promise.new()
    storage_write_locks[lock_key] = current_lock

    if previous_lock then
        Citizen.Await(previous_lock)
    end

    local success, result = xpcall(callback, debug.traceback)
    current_lock:resolve(true)
    if storage_write_locks[lock_key] == current_lock then
        storage_write_locks[lock_key] = nil
    end
    if not success then
        error(result, 0)
    end
    return result
end

local function validate_request(source, data, operation)
    if not Config.CustomApps.Enabled then
        return nil, nil, { success = false, error = "custom_apps_disabled" }
    end
    if not SkyPhone.AllowOperation(
        source,
        "custom_app_storage_" .. operation,
        Config.CustomApps.StorageRequestsPerMinute,
        60
    ) then
        return nil, nil, { success = false, error = "rate_limited" }
    end

    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, nil, error_response
    end
    if type(data) ~= "table" or not SkyPhoneApps.HasPermission(data.appId, "device.storage") then
        return nil, nil, { success = false, error = "storage_not_allowed" }
    end
    if type(data.key) ~= "string"
        or #data.key == 0
        or #data.key > math.min(Config.CustomApps.MaximumStorageKeyLength, 64)
        or not data.key:match("^[%w._-]+$")
    then
        return nil, nil, { success = false, error = "invalid_storage_key" }
    end

    return session, data, nil
end

local function read_row(imei, app_id, data_key)
    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision`
        FROM `sky_phone_custom_app_data`
        WHERE `device_imei` = ? AND `app_id` = ? AND `data_key` = ?
        LIMIT 1
    ]], { imei, app_id, data_key })
    return rows[1]
end

local function conflict_response(row)
    if not row then
        return {
            success = false,
            error = "storage_conflict",
            data = { exists = false, revision = 0 },
        }
    end

    return {
        success = false,
        error = "storage_conflict",
        data = {
            exists = true,
            revision = tonumber(row.revision) or 0,
            value = json.decode(row.payload),
        },
    }
end

Bridge.Callbacks.Register("sky_phone:custom-app:storage:get", function(source, data)
    local session, request, error_response = validate_request(source, data, "get")
    if not session then
        return error_response
    end

    local row = read_row(session.imei, request.appId, request.key)
    if not row then
        return { success = true, data = { exists = false, revision = 0 } }
    end

    return {
        success = true,
        data = {
            exists = true,
            revision = tonumber(row.revision) or 0,
            value = json.decode(row.payload),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:custom-app:storage:set", function(source, data)
    local session, request, error_response = validate_request(source, data, "set")
    if not session then
        return error_response
    end
    if request.value == nil then
        return { success = false, error = "invalid_storage_value" }
    end

    local expected_revision = tonumber(request.revision)
    if not expected_revision
        or expected_revision ~= math.floor(expected_revision)
        or expected_revision < 0
        or expected_revision > 4294967294
    then
        return { success = false, error = "invalid_storage_revision" }
    end

    if not validate_storage_json(request.value, 0, { nodes = 0, seen = {} }) then
        return { success = false, error = "invalid_storage_value" }
    end

    local encoded, payload = pcall(json.encode, request.value)
    if not encoded
        or type(payload) ~= "string"
        or #payload > math.min(Config.CustomApps.MaximumStorageValueBytes, 65536)
    then
        return { success = false, error = "storage_value_too_large" }
    end

    local lock_key = session.imei .. "\0" .. request.appId
    return with_storage_write_lock(lock_key, function()
        local current_session, session_error = SkyPhone.RequireSession(source)
        if not current_session then
            return session_error
        end
        if current_session.imei ~= session.imei
            or not SkyPhoneApps.HasPermission(request.appId, "device.storage")
        then
            return { success = false, error = "storage_not_allowed" }
        end

        local current = read_row(session.imei, request.appId, request.key)
        local current_revision = current and tonumber(current.revision) or 0
        if current_revision ~= expected_revision then
            return conflict_response(current)
        end

        local totals = Bridge.Database.Query([[
            SELECT COALESCE(SUM(OCTET_LENGTH(`payload`)), 0) AS `total`, COUNT(*) AS `keys`
            FROM `sky_phone_custom_app_data`
            WHERE `device_imei` = ? AND `app_id` = ?
        ]], { session.imei, request.appId })
        local current_size = current and #current.payload or 0
        local next_total = (tonumber(totals[1] and totals[1].total) or 0) - current_size + #payload
        if next_total > Config.CustomApps.MaximumStorageBytesPerApp then
            return { success = false, error = "storage_quota_exceeded" }
        end
        if not current
            and (tonumber(totals[1] and totals[1].keys) or 0) >= Config.CustomApps.MaximumStorageKeysPerApp
        then
            return { success = false, error = "storage_key_limit" }
        end

        if expected_revision == 0 then
            local inserted = Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_custom_app_data`
                    (`device_imei`, `app_id`, `data_key`, `payload`, `revision`)
                VALUES (?, ?, ?, ?, 1)
            ]], { session.imei, request.appId, request.key, payload })
            if affected_rows(inserted) ~= 1 then
                return conflict_response(read_row(session.imei, request.appId, request.key))
            end
            return { success = true, data = { revision = 1 } }
        end

        local updated = Bridge.Database.Query([[
            UPDATE `sky_phone_custom_app_data`
            SET `payload` = ?, `revision` = `revision` + 1
            WHERE `device_imei` = ? AND `app_id` = ? AND `data_key` = ? AND `revision` = ?
        ]], { payload, session.imei, request.appId, request.key, expected_revision })
        if affected_rows(updated) ~= 1 then
            return conflict_response(read_row(session.imei, request.appId, request.key))
        end

        return { success = true, data = { revision = expected_revision + 1 } }
    end)
end)
end)
