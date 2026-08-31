SkyPhoneTones = SkyPhoneTones or {}

local MAX_TONES_PER_TYPE = 32
local MAX_AUDIO_BYTES = 2000000
local MAX_DURATION_MS = 30000
local MAX_PAYLOAD_CHARS = 2666668
local MAX_LABEL_LENGTH = 64
local MAX_TRANSFER_CHUNK_CHARS = 8000
local MAX_TRANSFER_CHUNKS = 334
local TRANSFER_TIMEOUT_MS = 120000
local AUDIO_TRANSFER_BYTES_PER_SECOND = 3000000
local MAX_AUDIO_REQUEST_ID = 2147483646
local PUBLIC_READS_PER_MINUTE = 90
local PUBLIC_AUDIO_READS_PER_MINUTE = 24
local pending_uploads = {}
local configured_rows = {}
local configured_audio = {}
local allowed_mime_types = {
    ["audio/mpeg"] = true,
    ["audio/ogg"] = true,
    ["audio/wav"] = true,
    ["audio/webm"] = true,
}
local mime_types_by_extension = {
    mp3 = "audio/mpeg",
    ogg = "audio/ogg",
    wav = "audio/wav",
    webm = "audio/webm",
}
local base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$")
end

local function valid_uuid(value)
    return type(value) == "string"
        and value:match("^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$") ~= nil
        and #value == 36
end

local function decoded_base64_size(payload)
    if type(payload) ~= "string"
        or payload == ""
        or #payload > MAX_PAYLOAD_CHARS
        or #payload % 4 ~= 0
    then
        return nil
    end
    local body, padding = payload:match("^([A-Za-z0-9+/]*)(=*)$")
    if not body or #padding > 2 then
        return nil
    end
    return math.floor(#payload * 3 / 4) - #padding
end

local function decode_base64_prefix(payload, max_bytes)
    local decoded = {}
    local output_length = 0
    for index = 1, #payload, 4 do
        local first = base64_alphabet:find(payload:sub(index, index), 1, true)
        local second = base64_alphabet:find(payload:sub(index + 1, index + 1), 1, true)
        local third_character = payload:sub(index + 2, index + 2)
        local fourth_character = payload:sub(index + 3, index + 3)
        local third = third_character == "=" and 1
            or base64_alphabet:find(third_character, 1, true)
        local fourth = fourth_character == "=" and 1
            or base64_alphabet:find(fourth_character, 1, true)
        if not first or not second or not third or not fourth then
            return nil
        end

        local combined = (first - 1) * 262144
            + (second - 1) * 4096
            + (third - 1) * 64
            + (fourth - 1)
        decoded[#decoded + 1] = string.char(math.floor(combined / 65536) % 256)
        output_length = output_length + 1
        if third_character ~= "=" and output_length < max_bytes then
            decoded[#decoded + 1] = string.char(math.floor(combined / 256) % 256)
            output_length = output_length + 1
        end
        if fourth_character ~= "=" and output_length < max_bytes then
            decoded[#decoded + 1] = string.char(combined % 256)
            output_length = output_length + 1
        end
        if output_length >= max_bytes then
            break
        end
    end
    return table.concat(decoded)
end

local function valid_audio_signature(mime_type, raw)
    if type(raw) ~= "string" then
        return false
    end
    if mime_type == "audio/mpeg" then
        local first, second = raw:byte(1, 2)
        return raw:sub(1, 3) == "ID3"
            or (first == 0xFF and second ~= nil and (second & 0xE0) == 0xE0)
    end
    if mime_type == "audio/ogg" then
        return raw:sub(1, 4) == "OggS"
    end
    if mime_type == "audio/wav" then
        return raw:sub(1, 4) == "RIFF" and raw:sub(9, 12) == "WAVE"
    end
    if mime_type == "audio/webm" then
        return raw:sub(1, 4) == string.char(0x1A, 0x45, 0xDF, 0xA3)
    end
    return false
end

local function encode_base64(value)
    local encoded = {}
    local output_index = 1
    for index = 1, #value, 3 do
        local first, second, third = value:byte(index, index + 2)
        second = second or 0
        third = third or 0
        local combined = first * 65536 + second * 256 + third
        local first_index = math.floor(combined / 262144) % 64 + 1
        local second_index = math.floor(combined / 4096) % 64 + 1
        local third_index = math.floor(combined / 64) % 64 + 1
        local fourth_index = combined % 64 + 1
        encoded[output_index] = base64_alphabet:sub(first_index, first_index)
        encoded[output_index + 1] = base64_alphabet:sub(second_index, second_index)
        encoded[output_index + 2] = index + 1 <= #value
            and base64_alphabet:sub(third_index, third_index)
            or "="
        encoded[output_index + 3] = index + 2 <= #value
            and base64_alphabet:sub(fourth_index, fourth_index)
            or "="
        output_index = output_index + 4
    end
    return table.concat(encoded)
end

local function normalize_create_payload(data)
    if type(data) ~= "table" then
        return nil
    end

    local tone_type = data.toneType
    local label = trim(data.label)
    local mime_type = type(data.mimeType) == "string" and data.mimeType:lower() or ""
    local duration_ms = tonumber(data.durationMs)
    local byte_size = decoded_base64_size(data.payload)
    local prefix = byte_size and decode_base64_prefix(data.payload, 16) or nil
    if (tone_type ~= "ringtone" and tone_type ~= "notification")
        or label == ""
        or #label > MAX_LABEL_LENGTH
        or label:find("[%c]")
        or not allowed_mime_types[mime_type]
        or not byte_size
        or not valid_audio_signature(mime_type, prefix)
        or byte_size < 1
        or byte_size > MAX_AUDIO_BYTES
        or not duration_ms
        or duration_ms ~= math.floor(duration_ms)
        or duration_ms < 250
        or duration_ms > MAX_DURATION_MS
    then
        return nil
    end

    return {
        audioPayload = data.payload,
        byteSize = byte_size,
        durationMs = duration_ms,
        label = label,
        mimeType = mime_type,
        toneType = tone_type,
    }
end

local function map_tone(row, include_admin_fields)
    local tone = {
        byteSize = tonumber(row.byte_size) or 0,
        createdAt = row.created_at,
        durationMs = tonumber(row.duration_ms) or 0,
        id = row.id,
        label = row.label,
        mimeType = row.mime_type,
        source = row.source == "config" and "config" or "database",
        toneType = row.tone_type,
    }
    if include_admin_fields then
        tone.createdBy = row.created_by_name
    end
    return tone
end

local function load_database_rows()
    return Bridge.Database.Query([[
        SELECT
            `id`, `tone_type`, `label`, `mime_type`, `byte_size`, `duration_ms`,
            `created_by_name`, `created_at`
        FROM `sky_phone_custom_tones`
        ORDER BY `tone_type` ASC, `label` ASC, `id` ASC
    ]], {})
end

local function load_rows()
    local rows = {}
    for _, row in ipairs(configured_rows) do
        rows[#rows + 1] = row
    end
    for _, row in ipairs(load_database_rows()) do
        row.source = "database"
        rows[#rows + 1] = row
    end
    table.sort(rows, function(left, right)
        if left.tone_type ~= right.tone_type then
            return left.tone_type < right.tone_type
        end
        if left.label ~= right.label then
            return left.label < right.label
        end
        return left.id < right.id
    end)
    return rows
end

function SkyPhoneTones.GetAdminList()
    local tones = {}
    for _, row in ipairs(load_rows()) do
        tones[#tones + 1] = map_tone(row, true)
    end
    return tones
end

function SkyPhoneTones.GetCatalog()
    local catalog = {
        notificationSounds = {},
        ringtones = {},
    }
    local counts = { notification = 0, ringtone = 0 }
    for _, row in ipairs(load_rows()) do
        if counts[row.tone_type] < MAX_TONES_PER_TYPE then
            counts[row.tone_type] = counts[row.tone_type] + 1
            local target = row.tone_type == "ringtone" and catalog.ringtones or catalog.notificationSounds
            target[#target + 1] = map_tone(row, false)
        end
    end
    return catalog
end

function SkyPhoneTones.GetAudio(id)
    local configured = type(id) == "string" and configured_audio[id] or nil
    if configured then
        local raw = LoadResourceFile(GetCurrentResourceName(), configured.file)
        if type(raw) ~= "string"
            or #raw < 1
            or #raw > MAX_AUDIO_BYTES
            or not valid_audio_signature(configured.mime_type, raw:sub(1, 16))
        then
            Bridge.Debug(
                "error",
                "[sky_phone] Configured custom tone '%s' could not be read safely.",
                tostring(id),
                { always = true }
            )
            return nil
        end
        return {
            id = id,
            mimeType = configured.mime_type,
            payload = encode_base64(raw),
        }
    end
    if not valid_uuid(id) then
        return nil
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `mime_type`, `audio_payload`
        FROM `sky_phone_custom_tones`
        WHERE `id` = ?
        LIMIT 1
    ]], { id })
    local row = rows[1]
    if not row then
        return nil
    end
    return {
        id = row.id,
        mimeType = row.mime_type,
        payload = row.audio_payload,
    }
end

local function configured_type_count(tone_type)
    local count = 0
    for _, row in ipairs(configured_rows) do
        if row.tone_type == tone_type then
            count = count + 1
        end
    end
    return count
end

local function configured_label_exists(tone_type, label)
    for _, row in ipairs(configured_rows) do
        if row.tone_type == tone_type and row.label == label then
            return true
        end
    end
    return false
end

function SkyPhoneTones.Create(data, actor_identifier, actor_name)
    local tone = normalize_create_payload(data)
    if not tone or type(actor_identifier) ~= "string" or type(actor_name) ~= "string" then
        return { success = false, error = "invalid_tone" }
    end
    if configured_label_exists(tone.toneType, tone.label) then
        return { success = false, error = "tone_name_taken" }
    end

    local duplicate = Bridge.Database.Query([[
        SELECT 1
        FROM `sky_phone_custom_tones`
        WHERE `tone_type` = ? AND `label` = ?
        LIMIT 1
    ]], { tone.toneType, tone.label })
    if duplicate[1] then
        return { success = false, error = "tone_name_taken" }
    end

    local count_rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_custom_tones`
        WHERE `tone_type` = ?
    ]], { tone.toneType })
    if (tonumber(count_rows[1] and count_rows[1].count) or 0) + configured_type_count(tone.toneType)
        >= MAX_TONES_PER_TYPE
    then
        return { success = false, error = "tone_limit" }
    end

    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = ids[1] and ids[1].id
    if not valid_uuid(id) then
        error("[sky_phone] Database did not generate a custom tone UUID.")
    end

    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_custom_tones` (
            `id`, `tone_type`, `label`, `mime_type`, `audio_payload`, `byte_size`,
            `duration_ms`, `created_by_identifier`, `created_by_name`
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        id,
        tone.toneType,
        tone.label,
        tone.mimeType,
        tone.audioPayload,
        tone.byteSize,
        tone.durationMs,
        actor_identifier,
        actor_name,
    })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "request_failed" }
    end

    TriggerClientEvent("sky_phone:tones:changed", -1)
    return { success = true, data = SkyPhoneTones.GetAdminList(), toneId = id }
end

local function normalize_upload_metadata(data)
    if type(data) ~= "table" then
        return nil
    end
    local tone_type = data.toneType
    local label = trim(data.label)
    local mime_type = type(data.mimeType) == "string" and data.mimeType:lower() or ""
    local duration_ms = tonumber(data.durationMs)
    local payload_length = tonumber(data.payloadLength)
    if (tone_type ~= "ringtone" and tone_type ~= "notification")
        or label == ""
        or #label > MAX_LABEL_LENGTH
        or label:find("[%c]")
        or not allowed_mime_types[mime_type]
        or not duration_ms
        or duration_ms ~= math.floor(duration_ms)
        or duration_ms < 250
        or duration_ms > MAX_DURATION_MS
        or not payload_length
        or payload_length ~= math.floor(payload_length)
        or payload_length < 4
        or payload_length > MAX_PAYLOAD_CHARS
        or payload_length % 4 ~= 0
    then
        return nil
    end
    return {
        durationMs = duration_ms,
        label = label,
        mimeType = mime_type,
        payloadLength = payload_length,
        toneType = tone_type,
    }
end

function SkyPhoneTones.BeginUpload(source, data, actor_identifier, actor_name)
    local metadata = normalize_upload_metadata(data)
    if type(source) ~= "number"
        or not metadata
        or type(actor_identifier) ~= "string"
        or type(actor_name) ~= "string"
    then
        return { success = false, error = "invalid_tone" }
    end
    pending_uploads[source] = nil
    if configured_label_exists(metadata.toneType, metadata.label) then
        return { success = false, error = "tone_name_taken" }
    end

    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local upload_id = ids[1] and ids[1].id
    if not valid_uuid(upload_id) then
        error("[sky_phone] Database did not generate a custom tone upload UUID.")
    end
    local state = {
        actor_identifier = actor_identifier,
        actor_name = actor_name,
        chunks = {},
        length = 0,
        metadata = metadata,
        next_index = 1,
        upload_id = upload_id,
    }
    pending_uploads[source] = state
    SetTimeout(TRANSFER_TIMEOUT_MS, function()
        if pending_uploads[source] == state then
            pending_uploads[source] = nil
        end
    end)
    return { success = true, data = { uploadId = upload_id } }
end

function SkyPhoneTones.AppendUploadChunk(source, data)
    local state = pending_uploads[source]
    local chunk = type(data) == "table" and data.chunk or nil
    local index = type(data) == "table" and tonumber(data.index) or nil
    if not state
        or type(data) ~= "table"
        or data.uploadId ~= state.upload_id
        or not index
        or index ~= math.floor(index)
        or index ~= state.next_index
        or index > MAX_TRANSFER_CHUNKS
        or type(chunk) ~= "string"
        or #chunk < 1
        or #chunk > MAX_TRANSFER_CHUNK_CHARS
        or not chunk:match("^[A-Za-z0-9+/=]+$")
        or state.length + #chunk > state.metadata.payloadLength
    then
        return { success = false, error = "invalid_upload" }
    end
    state.chunks[index] = chunk
    state.length = state.length + #chunk
    state.next_index = index + 1
    return { success = true }
end

function SkyPhoneTones.CompleteUpload(source, data)
    local state = pending_uploads[source]
    if not state
        or type(data) ~= "table"
        or data.uploadId ~= state.upload_id
        or state.length ~= state.metadata.payloadLength
    then
        return { success = false, error = "invalid_upload" }
    end
    pending_uploads[source] = nil
    local payload = table.concat(state.chunks)
    local response = SkyPhoneTones.Create({
        durationMs = state.metadata.durationMs,
        label = state.metadata.label,
        mimeType = state.metadata.mimeType,
        payload = payload,
        toneType = state.metadata.toneType,
    }, state.actor_identifier, state.actor_name)
    if response.success then
        response.upload = state.metadata
    end
    return response
end

function SkyPhoneTones.CancelUpload(source, data)
    local state = pending_uploads[source]
    if state and type(data) == "table" and data.uploadId == state.upload_id then
        pending_uploads[source] = nil
    end
    return { success = true }
end

function SkyPhoneTones.Delete(id)
    if not valid_uuid(id) then
        return { success = false, error = "invalid_request" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `tone_type`, `label`
        FROM `sky_phone_custom_tones`
        WHERE `id` = ?
        LIMIT 1
    ]], { id })
    local tone = rows[1]
    if not tone then
        return { success = false, error = "tone_not_found" }
    end

    local result = Bridge.Database.Query(
        "DELETE FROM `sky_phone_custom_tones` WHERE `id` = ?",
        { id }
    )
    if affected_rows(result) ~= 1 then
        return { success = false, error = "tone_not_found" }
    end

    TriggerClientEvent("sky_phone:tones:changed", -1)
    return { success = true, data = SkyPhoneTones.GetAdminList(), tone = tone }
end

local function load_configured_tones()
    local groups = {
        { entries = Config.CustomTones and Config.CustomTones.Ringtones, name = "Ringtones", tone_type = "ringtone" },
        {
            entries = Config.CustomTones and Config.CustomTones.NotificationSounds,
            name = "NotificationSounds",
            tone_type = "notification",
        },
    }
    local seen_ids = {}
    local seen_labels = {}
    for _, group in ipairs(groups) do
        local entries = type(group.entries) == "table" and group.entries or {}
        for index, entry in ipairs(entries) do
            local id = type(entry) == "table" and trim(entry.Id):lower() or ""
            local label = type(entry) == "table" and trim(entry.Label) or ""
            local file = type(entry) == "table" and trim(entry.File):gsub("\\", "/") or ""
            local duration_ms = type(entry) == "table" and tonumber(entry.DurationMs) or nil
            local extension = file:lower():match("%.([a-z0-9]+)$")
            local mime_type = extension and mime_types_by_extension[extension] or nil
            local row_id = ("config:%s:%s"):format(group.tone_type, id)
            local label_key = group.tone_type .. ":" .. label
            local invalid_reason
            if type(entry) ~= "table" then
                invalid_reason = "entry must be a table"
            elseif not id:match("^[a-z0-9][a-z0-9_-]*$") or #id > 48 then
                invalid_reason = "Id must contain 1-48 lowercase letters, numbers, underscores, or hyphens"
            elseif label == "" or #label > MAX_LABEL_LENGTH or label:find("[%c]") then
                invalid_reason = "Label must contain 1-64 visible characters"
            elseif file:sub(1, 20) ~= "config/custom_tones/" or file:find("..", 1, true) then
                invalid_reason = "File must stay inside config/custom_tones"
            elseif not mime_type then
                invalid_reason = "File must use mp3, ogg, wav, or webm"
            elseif not duration_ms
                or duration_ms ~= math.floor(duration_ms)
                or duration_ms < 250
                or duration_ms > MAX_DURATION_MS
            then
                invalid_reason = "DurationMs must be an integer between 250 and 30000"
            elseif seen_ids[row_id] then
                invalid_reason = "Id is duplicated"
            elseif seen_labels[label_key] then
                invalid_reason = "Label is duplicated in this category"
            elseif configured_type_count(group.tone_type) >= MAX_TONES_PER_TYPE then
                invalid_reason = "the category contains more than 32 configured tones"
            end

            local raw
            if not invalid_reason then
                raw = LoadResourceFile(GetCurrentResourceName(), file)
                if type(raw) ~= "string" or #raw < 1 then
                    invalid_reason = "File could not be read"
                elseif #raw > MAX_AUDIO_BYTES then
                    invalid_reason = "File exceeds 2 MB"
                elseif not valid_audio_signature(mime_type, raw:sub(1, 16)) then
                    invalid_reason = "File content does not match its audio extension"
                end
            end

            if invalid_reason then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Ignored Config.CustomTones.%s[%s]: %s.",
                    group.name,
                    tostring(index),
                    invalid_reason,
                    { always = true }
                )
            else
                seen_ids[row_id] = true
                seen_labels[label_key] = true
                configured_rows[#configured_rows + 1] = {
                    byte_size = #raw,
                    created_at = "",
                    created_by_name = "config.lua",
                    duration_ms = duration_ms,
                    id = row_id,
                    label = label,
                    mime_type = mime_type,
                    source = "config",
                    tone_type = group.tone_type,
                }
                configured_audio[row_id] = { file = file, mime_type = mime_type }
            end
        end
    end
end

load_configured_tones()

AddEventHandler("playerDropped", function()
    pending_uploads[source] = nil
end)

Bridge.Database.AfterMigration("sky_phone", function()
    Bridge.Callbacks.Register("sky_phone:tones:list", function(source)
        if not SkyPhone.AllowOperation(source, "custom_tones_list", PUBLIC_READS_PER_MINUTE, 60) then
            return { success = false, error = "rate_limited" }
        end
        return { success = true, data = SkyPhoneTones.GetCatalog() }
    end)

    RegisterNetEvent("sky_phone:tones:audio-request", function(request_id, tone_id)
        local player_source = source
        if type(player_source) ~= "number"
            or player_source < 1
            or type(request_id) ~= "number"
            or request_id ~= math.floor(request_id)
            or request_id < 1
            or request_id > MAX_AUDIO_REQUEST_ID
            or type(tone_id) ~= "string"
            or tone_id == ""
            or #tone_id > 128
        then
            return
        end
        if not SkyPhone.AllowOperation(
            player_source,
            "custom_tones_audio",
            PUBLIC_AUDIO_READS_PER_MINUTE,
            60
        ) then
            TriggerClientEvent(
                "sky_phone:tones:audio-response",
                player_source,
                request_id,
                { success = false, error = "rate_limited" }
            )
            return
        end

        local audio = SkyPhoneTones.GetAudio(tone_id)
        local audio_size = audio and decoded_base64_size(audio.payload) or nil
        local signature = audio_size and decode_base64_prefix(audio.payload, 16) or nil
        if not audio
            or audio.id ~= tone_id
            or not allowed_mime_types[audio.mimeType]
            or not audio_size
            or audio_size < 1
            or audio_size > MAX_AUDIO_BYTES
            or not valid_audio_signature(audio.mimeType, signature)
        then
            TriggerClientEvent(
                "sky_phone:tones:audio-response",
                player_source,
                request_id,
                { success = false, error = "tone_not_found" }
            )
            return
        end

        TriggerLatentClientEvent(
            "sky_phone:tones:audio-response",
            player_source,
            AUDIO_TRANSFER_BYTES_PER_SECOND,
            request_id,
            { success = true, data = audio }
        )
    end)
end)
