Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneMemos = {}

local pending_uploads = {}
local pending_deletes = {}
local allowed_audio_mimes = {
    ["audio/ogg"] = "audio/ogg",
    ["audio/webm"] = "audio/webm",
    ["audio/webm;codecs=opus"] = "audio/webm",
}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function valid_uuid(value)
    if type(value) ~= "string" or #value ~= 36
        or value:sub(9, 9) ~= "-"
        or value:sub(14, 14) ~= "-"
        or value:sub(19, 19) ~= "-"
        or value:sub(24, 24) ~= "-"
    then
        return false
    end
    local compact = value:gsub("-", "")
    return #compact == 32 and compact:match("^%x+$") ~= nil
end

local function session_owner(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end
    return {
        account_id = device.account_id and tonumber(device.account_id) or nil,
        imei = session.imei,
    }
end

local function device_owner(source, imei)
    if not SkyPhoneImei.IsValid(imei) then
        return nil, { success = false, error = "invalid_request" }
    end
    if not SkyPhone.FindDeviceSlots(source, imei)[1] then
        return nil, { success = false, error = "owner_changed" }
    end
    local device = SkyPhone.LoadDevice(imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end
    return {
        account_id = device.account_id and tonumber(device.account_id) or nil,
        imei = imei,
    }
end

local function owner_condition(owner, alias)
    local prefix = alias and ("`%s`."):format(alias) or ""
    if owner.account_id then
        return prefix .. "`account_id` = ?", { owner.account_id }
    end
    return prefix .. "`account_id` IS NULL AND " .. prefix .. "`device_imei` = ?", { owner.imei }
end

local function owner_key(owner)
    if owner.account_id then
        return "account:" .. tostring(owner.account_id)
    end
    return "device:" .. owner.imei
end

local function append_params(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function memo_dto(row)
    local waveform = json.decode(row.waveform)
    if type(waveform) ~= "table" then
        error(("[sky_phone] Voice memo %s has an invalid waveform payload."):format(tostring(row.id)))
    end
    return {
        id = row.id,
        title = row.title,
        note = row.note,
        url = row.url,
        mimeType = row.mime_type,
        durationMs = tonumber(row.duration_ms) or 0,
        waveform = waveform,
        pinned = tonumber(row.pinned) == 1,
        revision = tonumber(row.revision) or 1,
        createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
        updatedAt = (tonumber(row.updated_at_unix) or 0) * 1000,
    }
end

local function list_memos(owner)
    local condition, params = owner_condition(owner, "media")
    params[#params + 1] = Config.Memos.MaximumCount
    local rows = Bridge.Database.Query(([[
        SELECT memo.`id`, memo.`title`, memo.`note`, memo.`duration_ms`,
            memo.`waveform`, memo.`pinned`, memo.`revision`, media.`url`, media.`mime_type`,
            UNIX_TIMESTAMP(memo.`created_at`) AS `created_at_unix`,
            UNIX_TIMESTAMP(memo.`updated_at`) AS `updated_at_unix`
        FROM `sky_phone_voice_memos` memo
        INNER JOIN `sky_phone_media` media ON media.`id` = memo.`media_id`
        WHERE %s AND media.`media_type` = 'audio'
        ORDER BY memo.`pinned` DESC, memo.`updated_at` DESC, memo.`id` DESC
        LIMIT ?
    ]]):format(condition), params)
    local memos = {}
    for index, row in ipairs(rows) do
        memos[index] = memo_dto(row)
    end
    return memos
end

local function find_memo(memos, id)
    for _, memo in ipairs(memos) do
        if memo.id == id then
            return memo
        end
    end
end

function SkyPhoneMemos.List(account_id, imei)
    return list_memos({ account_id = account_id and tonumber(account_id) or nil, imei = imei })
end

local function normalize_waveform(value)
    if type(value) ~= "table" or #value < 8 or #value > Config.Memos.MaximumWaveformSamples then
        return nil
    end
    local waveform = {}
    for index = 1, #value do
        local sample = tonumber(value[index])
        if not sample or sample ~= sample or sample == math.huge or sample == -math.huge
            or sample < 0 or sample > 1
        then
            return nil
        end
        waveform[index] = math.floor(sample * 1000 + 0.5) / 1000
    end
    return waveform
end

local function validate_upload(data)
    if type(data) ~= "table" or type(data.correlationId) ~= "string"
        or #data.correlationId < 1 or #data.correlationId > 80
    then
        return nil
    end
    local title = trim(data.title)
    local note = data.note == nil and "" or trim(data.note)
    local title_length = title and utf8.len(title) or nil
    local note_length = note and utf8.len(note) or nil
    local duration_ms = tonumber(data.durationMs)
    local normalized_mime = allowed_audio_mimes[data.mimeType]
    local waveform = normalize_waveform(data.waveform)
    if not title_length or title_length < 1 or title_length > Config.Memos.TitleMaxLength
        or not note_length or note_length > Config.Memos.NoteMaxLength
        or not duration_ms or duration_ms ~= duration_ms
        or duration_ms == math.huge or duration_ms == -math.huge
        or duration_ms < 300 or duration_ms > Config.Memos.MaximumDurationMs
        or not normalized_mime or not waveform or type(data.pinned) ~= "boolean"
    then
        return nil
    end
    duration_ms = math.floor(duration_ms)
    return {
        correlation_id = data.correlationId,
        duration_ms = duration_ms,
        mime_type = normalized_mime,
        note = note,
        pinned = data.pinned,
        title = title,
        waveform = waveform,
    }
end

local function upload_result(source, correlation_id, success, error_code, memo)
    TriggerClientEvent("sky_phone:memos:upload-result", source, {
        correlationId = correlation_id,
        success = success,
        error = error_code,
        memo = memo,
    })
end

local function discard_verified_upload(remote_id)
    local deleted, delete_error = SkyPhoneMedia.DeleteRemoteFile(remote_id)
    if not deleted then
        Bridge.Debug(
            "warn",
            "[sky_phone] Could not remove rejected voice memo upload %s: %s.",
            tostring(remote_id),
            tostring(delete_error)
        )
    end
end

local function expire_upload(request_id)
    local state = pending_uploads[request_id]
    if not state or state.completing then
        return
    end
    pending_uploads[request_id] = nil
    upload_result(state.source, state.memo.correlation_id, false, "upload_timeout")
end

Bridge.Callbacks.Register("sky_phone:memos:list", function(source)
    if not SkyPhone.AllowOperation(source, "memos_list", Config.Memos.ListsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    return { success = true, data = list_memos(owner) }
end)

Bridge.Callbacks.Register("sky_phone:memos:update", function(source, data)
    if not SkyPhone.AllowOperation(source, "memos_write", Config.Memos.WritesPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    local title = type(data) == "table" and trim(data.title) or nil
    local note = type(data) == "table" and (data.note == nil and "" or trim(data.note)) or nil
    local title_length = title and utf8.len(title) or nil
    local note_length = note and utf8.len(note) or nil
    local revision = type(data) == "table" and tonumber(data.revision) or nil
    if type(data) ~= "table" or not valid_uuid(data.id)
        or not title_length or title_length < 1 or title_length > Config.Memos.TitleMaxLength
        or not note_length or note_length > Config.Memos.NoteMaxLength
        or type(data.pinned) ~= "boolean" or not revision or revision ~= revision
        or revision == math.huge or revision == -math.huge or revision ~= math.floor(revision)
        or revision < 1 or revision > 4294967295
    then
        return { success = false, error = "invalid_memo" }
    end
    local condition, owner_params = owner_condition(owner, "media")
    local params = { title, note, data.pinned and 1 or 0, data.id, revision }
    append_params(params, owner_params)
    local result = Bridge.Database.Query(([[
        UPDATE `sky_phone_voice_memos` memo
        INNER JOIN `sky_phone_media` media ON media.`id` = memo.`media_id`
        SET memo.`title` = ?, memo.`note` = ?, memo.`pinned` = ?, memo.`revision` = memo.`revision` + 1
        WHERE memo.`id` = ? AND memo.`revision` = ? AND %s AND media.`media_type` = 'audio'
    ]]):format(condition), params)
    if affected_rows(result) ~= 1 then
        return { success = false, error = "conflict", data = list_memos(owner) }
    end
    return { success = true, data = find_memo(list_memos(owner), data.id) }
end)

Bridge.Callbacks.Register("sky_phone:memos:delete", function(source, data)
    if not SkyPhone.AllowOperation(source, "memos_write", Config.Memos.WritesPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    if type(data) ~= "table" or not valid_uuid(data.id) then
        return { success = false, error = "invalid_memo" }
    end
    local condition, owner_params = owner_condition(owner, "media")
    local params = { data.id }
    append_params(params, owner_params)
    local rows = Bridge.Database.Query(([[
        SELECT media.`id` AS `media_id`, media.`remote_id`
        FROM `sky_phone_voice_memos` memo
        INNER JOIN `sky_phone_media` media ON media.`id` = memo.`media_id`
        WHERE memo.`id` = ? AND %s AND media.`media_type` = 'audio'
        LIMIT 1
    ]]):format(condition), params)
    local memo = rows[1]
    if not memo then
        return { success = false, error = "memo_not_found" }
    end
    if pending_deletes[memo.remote_id] then
        return { success = false, error = "operation_in_progress" }
    end
    pending_deletes[memo.remote_id] = source
    local references = Bridge.Database.Query(
        "SELECT COUNT(*) AS `count` FROM `sky_phone_media` WHERE `remote_id` = ?",
        { memo.remote_id }
    )
    if (tonumber(references[1] and references[1].count) or 0) <= 1 then
        local deleted, delete_error = SkyPhoneMedia.DeleteRemoteFile(memo.remote_id)
        if not deleted then
            pending_deletes[memo.remote_id] = nil
            return { success = false, error = delete_error }
        end
    end
    local result = Bridge.Database.Query(([[
        DELETE media FROM `sky_phone_media` media
        INNER JOIN `sky_phone_voice_memos` memo ON memo.`media_id` = media.`id`
        WHERE memo.`id` = ? AND %s AND media.`media_type` = 'audio'
    ]]):format(condition), params)
    pending_deletes[memo.remote_id] = nil
    if affected_rows(result) ~= 1 then
        error(("[sky_phone] Voice memo %s disappeared during deletion."):format(data.id))
    end
    return { success = true, data = { id = data.id } }
end)

RegisterNetEvent("sky_phone:memos:request-upload", function(data)
    local src = source
    if not SkyPhone.AllowOperation(src, "memos_upload", Config.Memos.UploadsPerMinute, 60) then
        upload_result(src, type(data) == "table" and data.correlationId or nil, false, "rate_limited")
        return
    end
    local memo = validate_upload(data)
    if not memo then
        upload_result(src, type(data) == "table" and data.correlationId or nil, false, "invalid_memo")
        return
    end
    local owner, error_response = device_owner(src, data.deviceImei)
    if not owner then
        upload_result(src, memo.correlation_id, false, error_response.error)
        return
    end
    local condition, params = owner_condition(owner, "media")
    local counts = Bridge.Database.Query(([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_voice_memos` memo
        INNER JOIN `sky_phone_media` media ON media.`id` = memo.`media_id`
        WHERE %s AND media.`media_type` = 'audio'
    ]]):format(condition), params)
    if (tonumber(counts[1] and counts[1].count) or 0) >= Config.Memos.MaximumCount then
        upload_result(src, memo.correlation_id, false, "memo_limit")
        return
    end
    local pending_count = 0
    local pending_owner_key = owner_key(owner)
    for _, state in pairs(pending_uploads) do
        if state.owner_key == pending_owner_key then
            pending_count = pending_count + 1
        end
    end
    if pending_count >= Config.Memos.MaximumPendingUploads then
        upload_result(src, memo.correlation_id, false, "operation_in_progress")
        return
    end
    local presigned_url, presigned_error, provider_base_url = SkyPhoneMedia.RequestPresignedUrl()
    if not presigned_url then
        Bridge.Debug(
            "error",
            "[sky_phone] Voice memo upload could not start for source %s: %s.",
            tostring(src),
            tostring(presigned_error),
            { always = true }
        )
        upload_result(src, memo.correlation_id, false, presigned_error)
        return
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `request_id`, UUID() AS `capture_token`", {})
    local request_id = ids[1] and ids[1].request_id
    local capture_token = ids[1] and ids[1].capture_token
    if type(request_id) ~= "string" or type(capture_token) ~= "string" then
        error("[sky_phone] Database did not generate a voice memo upload token.")
    end
    pending_uploads[request_id] = {
        capture_token = capture_token,
        media_type = "audio",
        mime_type = memo.mime_type,
        memo = memo,
        owner = owner,
        owner_key = pending_owner_key,
        provider_base_url = provider_base_url,
        purpose = "memo",
        source = src,
        upload_path = "sky_phone-" .. capture_token,
    }
    SetTimeout(Config.Memos.UploadSessionTimeoutMs, function()
        expire_upload(request_id)
    end)
    TriggerClientEvent("sky_phone:memos:upload-ready", src, {
        requestId = request_id,
        correlationId = memo.correlation_id,
        captureToken = capture_token,
        presignedUrl = presigned_url,
        uploadPath = pending_uploads[request_id].upload_path,
        uploadTimeoutMs = Config.Media.FiveManage.UploadTimeoutMs,
    })
end)

RegisterNetEvent("sky_phone:memos:complete-upload", function(data)
    local src = source
    local request_id = type(data) == "table" and data.requestId or nil
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
        return
    end
    state.completing = true
    local owner, error_response = device_owner(src, state.owner.imei)
    if not owner or owner.imei ~= state.owner.imei or owner.account_id ~= state.owner.account_id then
        pending_uploads[request_id] = nil
        local rejected, _, trusted_remote = SkyPhoneMedia.VerifyRemoteUpload(
            state,
            data.remoteId,
            data.url,
            data.originalUrl
        )
        if rejected or trusted_remote then
            discard_verified_upload(data.remoteId)
        end
        upload_result(src, state.memo.correlation_id, false, error_response and error_response.error or "owner_changed")
        return
    end
    local verified, verify_error, trusted_remote = SkyPhoneMedia.VerifyRemoteUpload(
        state,
        data.remoteId,
        data.url,
        data.originalUrl
    )
    if not verified then
        pending_uploads[request_id] = nil
        if trusted_remote then
            discard_verified_upload(data.remoteId)
        end
        upload_result(src, state.memo.correlation_id, false, verify_error)
        return
    end
    local size_bytes = tonumber(verified.size)
    if not size_bytes or size_bytes ~= size_bytes
        or size_bytes == math.huge or size_bytes == -math.huge
        or size_bytes < 1 or size_bytes > Config.Memos.MaximumBytes
    then
        pending_uploads[request_id] = nil
        discard_verified_upload(verified.remote_id)
        upload_result(src, state.memo.correlation_id, false, "recording_too_large")
        return
    end
    size_bytes = math.floor(size_bytes)
    local condition, count_params = owner_condition(owner, "media")
    local counts = Bridge.Database.Query(([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_voice_memos` memo
        INNER JOIN `sky_phone_media` media ON media.`id` = memo.`media_id`
        WHERE %s AND media.`media_type` = 'audio'
    ]]):format(condition), count_params)
    if (tonumber(counts[1] and counts[1].count) or 0) >= Config.Memos.MaximumCount then
        pending_uploads[request_id] = nil
        discard_verified_upload(verified.remote_id)
        upload_result(src, state.memo.correlation_id, false, "memo_limit")
        return
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local memo_id = ids[1] and ids[1].id
    if type(memo_id) ~= "string" then
        error("[sky_phone] Database did not generate a voice memo id.")
    end
    local media_query
    local media_params
    if owner.account_id then
        media_query = [[
            INSERT INTO `sky_phone_media`
                (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`, `verified_at`)
            VALUES (?, NULL, ?, ?, 'audio', ?, CURRENT_TIMESTAMP)
        ]]
        media_params = { owner.account_id, verified.url, verified.remote_id, verified.mime_type }
    else
        media_query = [[
            INSERT INTO `sky_phone_media`
                (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`, `verified_at`)
            VALUES (NULL, ?, ?, ?, 'audio', ?, CURRENT_TIMESTAMP)
        ]]
        media_params = { owner.imei, verified.url, verified.remote_id, verified.mime_type }
    end
    local transaction = {
        {
            query = media_query,
            params = media_params,
        },
        {
            query = [[
                INSERT INTO `sky_phone_voice_memos`
                    (`id`, `media_id`, `title`, `note`, `duration_ms`, `size_bytes`, `waveform`, `pinned`)
                SELECT ?, LAST_INSERT_ID(), ?, ?, ?, ?, ?, ?
            ]],
            params = {
                memo_id,
                state.memo.title,
                state.memo.note,
                state.memo.duration_ms,
                size_bytes,
                json.encode(state.memo.waveform),
                state.memo.pinned and 1 or 0,
            },
        },
    }
    if not Bridge.Database.Transaction(transaction) then
        pending_uploads[request_id] = nil
        discard_verified_upload(verified.remote_id)
        upload_result(src, state.memo.correlation_id, false, "request_failed")
        return
    end
    pending_uploads[request_id] = nil
    local memos = list_memos(owner)
    local created = find_memo(memos, memo_id)
    if not created then
        error(("[sky_phone] Created voice memo %s could not be hydrated."):format(memo_id))
    end
    upload_result(src, state.memo.correlation_id, true, nil, created)
end)

RegisterNetEvent("sky_phone:memos:cancel-upload", function(data)
    local src = source
    local request_id = type(data) == "table" and data.requestId or nil
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if state and state.source == src and not state.completing then
        pending_uploads[request_id] = nil
        upload_result(src, state.memo.correlation_id, false, "cancelled")
    end
end)

RegisterNetEvent("sky_phone:memos:fail-upload", function(data)
    local src = source
    local request_id = type(data) == "table" and data.requestId or nil
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
        return
    end
    local allowed_errors = {
        capture_failed = true,
        unsupported = true,
        upload_failed = true,
        upload_timeout = true,
    }
    pending_uploads[request_id] = nil
    upload_result(src, state.memo.correlation_id, false, allowed_errors[data.error] and data.error or "upload_failed")
end)

AddEventHandler("playerDropped", function()
    local src = source
    for request_id, state in pairs(pending_uploads) do
        if state.source == src then
            pending_uploads[request_id] = nil
        end
    end
end)
end)
