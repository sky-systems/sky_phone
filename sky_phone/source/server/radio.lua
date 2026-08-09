local profiles = {}
local channels = {}
local joined_at = {}
local last_requests = {}

local function supports_secondary()
    if not Config.Radio.AllowSecondary then
        return false
    end
    local configured = Config.Radio.VoiceProvider
    if configured == "pma" or configured == "pma-voice" then
        return false
    end
    if configured ~= "auto" then
        return true
    end
    if GetResourceState("yaca-voice") == "started" then
        return true
    end
    if GetResourceState("pma-voice") == "started" then
        return false
    end
    return GetResourceState("saltychat") == "started"
end

local function default_profile()
    return {
        history = {},
        settings = {
            autoRejoin = Config.Radio.AutoRejoin,
            notifications = Config.Radio.Notifications,
        },
        primaryFrequency = 0,
        secondaryFrequency = 0,
        badge = "",
        displayName = "",
    }
end

local function decode_table(value, fallback)
    if type(value) ~= "string" or value == "" then
        return fallback
    end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == "table" and decoded or fallback
end

local function normalize_frequency(value, allow_zero)
    local frequency = tonumber(value)
    if not frequency or frequency ~= frequency then
        return nil
    end
    if allow_zero and frequency == 0 then
        return 0
    end
    if frequency < Config.Radio.FrequencyMin or frequency > Config.Radio.FrequencyMax then
        return nil
    end
    local factor = 10 ^ Config.Radio.FrequencyDecimals
    return math.floor(frequency * factor + 0.5) / factor
end

local function can_set_display_name(source)
    local config = Config.Radio.DisplayName
    if type(config) ~= "table" or not config.Enabled then
        return false
    end

    local job = Bridge.Framework.GetJob(source)
    local minimum_grade = type(config.AllowedJobs) == "table" and tonumber(config.AllowedJobs[job.name]) or nil
    return minimum_grade ~= nil and (tonumber(job.grade) or 0) >= minimum_grade
end

local function normalize_display_name(value)
    local name = tostring(value or ""):gsub("%c", ""):gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or ""
    local length = utf8.len(name)
    if not length then
        return nil
    end

    local maximum = math.max(1, math.min(tonumber(Config.Radio.DisplayName.MaxLength) or 32, 64))
    if length > maximum then
        local next_character = utf8.offset(name, maximum + 1)
        name = next_character and name:sub(1, next_character - 1) or name
    end
    return name
end

local function has_channel_access(source, frequency)
    local job = Bridge.Framework.GetJob(source)
    for _, locked in ipairs(Config.Radio.LockedChannels or {}) do
        local minimum = tonumber(locked.range and locked.range[1])
        local maximum = tonumber(locked.range and locked.range[2])
        if minimum and maximum and frequency >= minimum and frequency <= maximum then
            return locked.jobs and locked.jobs[job.name] == true
        end
    end
    return true
end

local function sanitize_history(source, history)
    local result = {}
    local seen = {}
    if type(history) ~= "table" then
        return result
    end
    for index = 1, #history do
        local entry = history[index]
        if type(entry) == "table" then
            local primary = normalize_frequency(entry.primary or entry.frequency, false)
            local secondary = normalize_frequency(entry.secondary or entry.secondaryFrequency or 0, true)
            if primary and secondary and secondary == primary then
                secondary = 0
            end
            if primary and secondary and has_channel_access(source, primary)
                and (secondary == 0 or has_channel_access(source, secondary)) then
                local key = ("%.3f|%.3f"):format(primary, secondary)
                if not seen[key] then
                    result[#result + 1] = { primary = primary, secondary = secondary }
                    seen[key] = true
                end
            end
        end
        if #result >= Config.Radio.HistoryLimit then
            break
        end
    end
    return result
end

local function load_profile(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return nil, nil
    end
    if profiles[identifier] then
        return identifier, profiles[identifier]
    end

    local profile = default_profile()
    local rows = Bridge.Database.Query([[
        SELECT `history`, `settings`, `primary_frequency`, `secondary_frequency`, `badge`, `display_name`
        FROM `sky_phone_radio_profiles` WHERE `identifier` = ? LIMIT 1
    ]], { identifier })
    local row = rows[1]
    if row then
        profile.history = sanitize_history(source, decode_table(row.history, {}))
        local settings = decode_table(row.settings, {})
        profile.settings.autoRejoin = settings.autoRejoin == true
        profile.settings.notifications = settings.notifications == true
        profile.primaryFrequency = normalize_frequency(row.primary_frequency, true) or 0
        profile.secondaryFrequency = normalize_frequency(row.secondary_frequency, true) or 0
        profile.badge = tostring(row.badge or ""):sub(1, math.min(Config.Radio.Badge.MaxLength, 32))
        profile.displayName = normalize_display_name(row.display_name) or ""
    end
    profiles[identifier] = profile
    return identifier, profile
end

local function save_profile(identifier, profile)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_radio_profiles`
            (`identifier`, `history`, `settings`, `primary_frequency`, `secondary_frequency`, `badge`, `display_name`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `history` = VALUES(`history`), `settings` = VALUES(`settings`),
            `primary_frequency` = VALUES(`primary_frequency`),
            `secondary_frequency` = VALUES(`secondary_frequency`), `badge` = VALUES(`badge`),
            `display_name` = VALUES(`display_name`)
    ]], {
        identifier,
        json.encode(profile.history),
        json.encode(profile.settings),
        profile.primaryFrequency,
        profile.secondaryFrequency,
        profile.badge,
        profile.displayName,
    })
end

local function get_effective_display_name(source, profile)
    if not can_set_display_name(source) then
        return ""
    end
    if not profile then
        local _, loaded_profile = load_profile(source)
        profile = loaded_profile
    end
    return profile and profile.displayName or ""
end

local function get_radio_member_name(source)
    local display_name = get_effective_display_name(source)
    return display_name ~= "" and display_name or GetPlayerName(source) or "Unknown"
end

local function frequency_set(channel)
    local result = {}
    if channel and channel.primary and channel.primary > 0 then
        result[channel.primary] = true
    end
    if channel and channel.secondary and channel.secondary > 0 then
        result[channel.secondary] = true
    end
    return result
end

local function get_members(frequency)
    local members = {}
    for player_source, channel in pairs(channels) do
        if channel.primary == frequency or channel.secondary == frequency then
            local job = Bridge.Framework.GetJob(player_source)
            local _, profile = load_profile(player_source)
            members[#members + 1] = {
                id = player_source,
                name = get_radio_member_name(player_source),
                badge = Config.Radio.Badge.Enabled and profile and profile.badge or "",
                joinTime = os.time() - (joined_at[player_source] or os.time()),
                rank = job.gradeLabel,
                rankNumber = job.grade,
            }
        end
    end
    table.sort(members, function(left, right)
        return left.name:lower() < right.name:lower()
    end)
    return members
end

local function broadcast_frequency(frequency)
    if not frequency or frequency <= 0 then
        return
    end
    local members = get_members(frequency)
    for _, member in ipairs(members) do
        TriggerClientEvent("sky_phone:radio:members", member.id, {
            frequency = frequency,
            members = members,
        })
    end
end

local function notify_frequency(frequency, excluded_source, player_name, joined)
    if not frequency or frequency <= 0 then
        return
    end
    for player_source, channel in pairs(channels) do
        if player_source ~= excluded_source
            and (channel.primary == frequency or channel.secondary == frequency) then
            TriggerClientEvent("sky_phone:radio:notification", player_source, {
                joined = joined,
                playerName = player_name,
            })
        end
    end
end

local function remove_from_channels(source)
    local previous = channels[source]
    if not previous then
        return
    end
    channels[source] = nil
    joined_at[source] = nil
    local name = get_radio_member_name(source)
    for frequency in pairs(frequency_set(previous)) do
        notify_frequency(frequency, source, name, false)
        broadcast_frequency(frequency)
    end
end

local function rate_limited(source, action, milliseconds)
    local now = GetGameTimer()
    local key = ("%s:%s"):format(source, action)
    if last_requests[key] and now - last_requests[key] < milliseconds then
        return true
    end
    last_requests[key] = now
    return false
end

Bridge.Callbacks.Register("sky_phone:radio:get", function(source)
    local _, profile = load_profile(source)
    if not profile then
        return { success = false, error = "player_unavailable" }
    end
    local channel = channels[source]
    return {
        success = true,
        data = {
            connected = channel ~= nil,
            frequency = channel and channel.primary or 0,
            secondaryFrequency = channel and channel.secondary or 0,
            members = channel and get_members(channel.primary) or {},
            history = profile.history,
            settings = profile.settings,
            badge = profile.badge,
            badgeEnabled = Config.Radio.Badge.Enabled,
            badgeMaxLength = math.min(Config.Radio.Badge.MaxLength, 32),
            displayName = profile.displayName,
            displayNameAllowed = can_set_display_name(source),
            displayNameEnabled = Config.Radio.DisplayName.Enabled,
            displayNameMaxLength = math.min(Config.Radio.DisplayName.MaxLength, 64),
            frequencyMin = Config.Radio.FrequencyMin,
            frequencyMax = Config.Radio.FrequencyMax,
            frequencyStep = 1 / (10 ^ Config.Radio.FrequencyDecimals),
            savedFrequency = profile.primaryFrequency,
            savedSecondaryFrequency = profile.secondaryFrequency,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:radio:connect", function(source, data)
    if rate_limited(source, "connect", 500) then
        return { success = false, error = "rate_limited" }
    end
    local primary = normalize_frequency(data.frequency, false)
    local secondary = normalize_frequency(data.secondaryFrequency or 0, true)
    if not primary or not secondary then
        return { success = false, error = "invalid_frequency" }
    end
    if secondary == primary then
        secondary = 0
    end
    if not supports_secondary() then
        secondary = 0
    end
    if not has_channel_access(source, primary) then
        return { success = false, error = "channel_locked" }
    end
    if secondary > 0 and not has_channel_access(source, secondary) then
        return { success = false, error = "secondary_locked" }
    end

    local identifier, profile = load_profile(source)
    if not profile then
        return { success = false, error = "player_unavailable" }
    end
    local previous = channels[source]
    local previous_set = frequency_set(previous)
    channels[source] = { primary = primary, secondary = secondary }
    joined_at[source] = os.time()

    profile.primaryFrequency = primary
    profile.secondaryFrequency = secondary
    profile.history = sanitize_history(source, (function()
        local history = { { primary = primary, secondary = secondary } }
        for _, entry in ipairs(profile.history) do
            history[#history + 1] = entry
        end
        return history
    end)())
    save_profile(identifier, profile)

    local current_set = frequency_set(channels[source])
    local name = get_radio_member_name(source)
    for frequency in pairs(previous_set) do
        if not current_set[frequency] then
            notify_frequency(frequency, source, name, false)
            broadcast_frequency(frequency)
        end
    end
    for frequency in pairs(current_set) do
        if not previous_set[frequency] then
            notify_frequency(frequency, source, name, true)
        end
        broadcast_frequency(frequency)
    end

    return {
        success = true,
        data = {
            connected = true,
            frequency = primary,
            secondaryFrequency = secondary,
            members = get_members(primary),
            history = profile.history,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:radio:disconnect", function(source)
    remove_from_channels(source)
    local identifier, profile = load_profile(source)
    if profile then
        profile.primaryFrequency = 0
        profile.secondaryFrequency = 0
        save_profile(identifier, profile)
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:radio:save-settings", function(source, data)
    local key = tostring(data.key or "")
    if key ~= "autoRejoin" and key ~= "notifications" then
        return { success = false, error = "invalid_setting" }
    end
    local identifier, profile = load_profile(source)
    if not profile then
        return { success = false, error = "player_unavailable" }
    end
    profile.settings[key] = data.value == true
    save_profile(identifier, profile)
    return { success = true, data = profile.settings }
end)

local function badge_forbidden(badge)
    local digits = badge:gsub("%D", "")
    for _, pattern in ipairs(Config.Radio.Badge.ForbiddenPatterns or {}) do
        if digits:find(tostring(pattern), 1, true) then
            return true
        end
    end
    return false
end

Bridge.Callbacks.Register("sky_phone:radio:save-badge", function(source, data)
    if not Config.Radio.Badge.Enabled then
        return { success = false, error = "badge_disabled" }
    end
    local badge = tostring(data.badge or ""):gsub("[^%w_%-]", ""):sub(1, math.min(Config.Radio.Badge.MaxLength, 32))
    if badge_forbidden(badge) then
        return { success = false, error = "badge_forbidden" }
    end
    local identifier, profile = load_profile(source)
    if not profile then
        return { success = false, error = "player_unavailable" }
    end
    profile.badge = badge
    save_profile(identifier, profile)
    for frequency in pairs(frequency_set(channels[source])) do
        broadcast_frequency(frequency)
    end
    return { success = true, data = { badge = badge } }
end)

Bridge.Callbacks.Register("sky_phone:radio:save-display-name", function(source, data)
    if not Config.Radio.DisplayName.Enabled then
        return { success = false, error = "display_name_disabled" }
    end
    if rate_limited(source, "save-display-name", 750) then
        return { success = false, error = "rate_limited" }
    end
    if not can_set_display_name(source) then
        return { success = false, error = "display_name_forbidden" }
    end

    local display_name = normalize_display_name(data.displayName)
    if display_name == nil then
        return { success = false, error = "invalid_display_name" }
    end
    local identifier, profile = load_profile(source)
    if not profile then
        return { success = false, error = "player_unavailable" }
    end

    profile.displayName = display_name
    save_profile(identifier, profile)
    for frequency in pairs(frequency_set(channels[source])) do
        broadcast_frequency(frequency)
    end
    return { success = true, data = { displayName = display_name } }
end)

AddEventHandler("playerDropped", function()
    local player_source = source
    local identifier = Bridge.Framework.GetIdentifier(player_source)
    remove_from_channels(player_source)
    if identifier then
        profiles[identifier] = nil
    end
    for key in pairs(last_requests) do
        if key:sub(1, #tostring(player_source) + 1) == tostring(player_source) .. ":" then
            last_requests[key] = nil
        end
    end
end)
