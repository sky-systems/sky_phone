SkyPhoneAppDatabase = {}

-- These stores are also used by core device/cloud lifecycle, gallery media
-- safety, administration or receiving EasyShare content. Disabling an app must
-- not break those consumers or bypass their ownership/reference checks.
local shared_tables = {
    sky_phone_notes = true,
    sky_phone_sms_messages = true,
    sky_phone_music_youtube_songs = true,
    sky_phone_music_playlists = true,
    sky_phone_music_playlist_items = true,
    sky_phone_map_markers = true,
    sky_phone_fliptok_sessions = true,
    sky_phone_flare_profiles = true,
    sky_phone_flare_profile_photos = true,
    sky_phone_skypic_profiles = true,
    sky_phone_skypic_friendships = true,
    sky_phone_skypic_messages = true,
    sky_phone_skypic_stories = true,
    sky_phone_skypic_spotlights = true,
}

local table_owners = {
    { "sky_phone_picstagram_", "picstagram" },
    { "sky_phone_darkchat_", "darkchat" },
    { "sky_phone_feather_", "feather" },
    { "sky_phone_flare_", "flare" },
    { "sky_phone_fliptok_", "fliptok" },
    { "sky_phone_skypic_", "skypic" },
    { "sky_phone_marketplace_", "citymarkt" },
    { "sky_phone_pages_", "local-pages" },
    { "sky_phone_skyride_", "skyride" },
    { "sky_phone_calendar_", "calendar" },
    { "sky_phone_music_", "music" },
    { "sky_phone_map_", "map" },
    { "sky_phone_crewlink_", "crewlink" },
    { "sky_phone_weazel_", "weazel-news" },
    { "sky_phone_citywarn_", "citywarn" },
    { "sky_phone_radio_", "radio" },
    { "sky_phone_voice_memos", "memos" },
    { "sky_phone_health_", "health" },
    { "sky_phone_billing_", "billing" },
    { "sky_phone_bank_", "banking" },
    { "sky_phone_sms_", "messages" },
    { "sky_phone_mail", "mail" },
    { "sky_phone_notes", "notes" },
}

local callback_owners = {
    { "sky_phone:picstagram:", "picstagram" },
    { "sky_phone:darkchat:", "darkchat" },
    { "sky_phone:feather:", "feather" },
    { "sky_phone:flare:", "flare" },
    { "sky_phone:fliptok:", "fliptok" },
    { "sky_phone:skypic:", "skypic" },
    { "sky_phone:marketplace:", "citymarkt" },
    { "sky_phone:pages:", "local-pages" },
    { "sky_phone:skyride:", "skyride" },
    { "sky_phone:calendar:", "calendar" },
    { "sky_phone:music:", "music" },
    { "sky_phone:map:", "map" },
    { "sky_phone:crewlink:", "crewlink" },
    { "sky_phone:weazel-news:", "weazel-news" },
    { "sky_phone:citywarn:", "citywarn" },
    { "sky_phone:radio:", "radio" },
    { "sky_phone:memos:", "memos" },
    { "sky_phone:health:", "health" },
    { "sky_phone:billing:", "billing" },
    { "sky_phone:banking:", "banking" },
    { "sky_phone:messages:", "messages" },
    { "sky_phone:mail:", "mail" },
    { "sky_phone:notes:", "notes" },
    { "sky_phone:crypto:", "crypto" },
    { "sky_phone:garage:", "garage" },
    { "sky_phone:housing:", "house" },
}

local schema_by_app = {}
local full_schema = {}
local pending_sql = {}
local migrated = {}
local schema_migrated = {}
local starters = {}
local starting = {}
local managed_apps, ready_apps = {}, {}

local function longest_owner(value, owners)
    local owner = nil
    local matched = 0
    for index = 1, #owners do
        local prefix = owners[index][1]
        if value:sub(1, #prefix) == prefix and #prefix > matched then
            owner = owners[index][2]
            matched = #prefix
        end
    end
    return owner
end

local function cancel_deferred(deferred_names)
    if not deferred_names or not Bridge.Callbacks or not Bridge.Callbacks.CancelDeferred then
        return
    end
    for index = 1, #deferred_names do
        Bridge.Callbacks.CancelDeferred(deferred_names[index])
    end
end

function SkyPhoneAppDatabase.Enabled(app_id)
    return type(Config.Apps) ~= "table" or Config.Apps[app_id] ~= false
end

function SkyPhoneAppDatabase.Owner(table_name)
    local name = tostring(table_name):lower()
    if shared_tables[name] or name:sub(1, #"sky_phone_skyride_") == "sky_phone_skyride_" then return nil end
    return longest_owner(name, table_owners)
end

function SkyPhoneAppDatabase.CallbackApp(name)
    return longest_owner(tostring(name), callback_owners)
end

local cleanup_callbacks = {
    ["sky_phone:radio:disconnect"] = true,
    ["sky_phone:garage:valet-cancel"] = true,
    ["sky_phone:garage:valet-complete"] = true,
    ["sky_phone:skyride:bootstrap"] = true,
    ["sky_phone:skyride:arrive"] = true,
    ["sky_phone:skyride:start"] = true,
    ["sky_phone:skyride:complete"] = true,
    ["sky_phone:skyride:cancel"] = true,
    ["sky_phone:skyride:rate"] = true,
}

-- Disabling an app rejects new work; it cannot prevent an already accepted
-- operation from releasing inventory, refunding money or settling its payment.
function SkyPhoneAppDatabase.CanCleanup(name, data)
    if cleanup_callbacks[name] then return true end
    return name == "sky_phone:skyride:set-driver-status" and type(data) == "table" and data.online == false
end

function SkyPhoneAppDatabase.Initializing(app_id)
    return managed_apps[app_id] and not ready_apps[app_id]
end

local function include_parents(schema, required)
    local filtered, by_name = {}, {}
    for index = 1, #schema do
        local table_definition = schema[index]
        by_name[table_definition.name] = table_definition
    end
    -- A visible app can depend on storage owned by an invisible app. In
    -- particular Local Pages references CityMarkt listings through a foreign key.
    local visited = {}
    local function require_parents(name)
        if visited[name] then return end
        visited[name] = true
        local definition = by_name[name]
        for _, foreign_key in ipairs(definition and definition.foreignKeys or {}) do
            local parent = foreign_key.references:match("^`([^`]+)`")
            if parent and by_name[parent] then
                required[parent] = true
                require_parents(parent)
            end
        end
    end
    local roots = {}
    for name in pairs(required) do roots[#roots + 1] = name end
    for _, name in ipairs(roots) do require_parents(name) end
    for index = 1, #schema do
        if required[schema[index].name] then filtered[#filtered + 1] = schema[index] end
    end
    return filtered
end

function SkyPhoneAppDatabase.Filter(schema)
    local required = {}
    for _, definition in ipairs(schema) do
        local owner = SkyPhoneAppDatabase.Owner(definition.name)
        if not owner or SkyPhoneAppDatabase.Enabled(owner) then required[definition.name] = true end
    end
    return include_parents(schema, required)
end

function SkyPhoneAppDatabase.Remember(schema)
    full_schema = schema
    schema_by_app = {}
    for index = 1, #schema do
        local table_definition = schema[index]
        local owner = SkyPhoneAppDatabase.Owner(table_definition.name)
        if owner then
            local tables = schema_by_app[owner]
            if not tables then
                tables = {}
                schema_by_app[owner] = tables
            end
            tables[#tables + 1] = table_definition
        end
    end
    for app_id in pairs(schema_by_app) do
        if SkyPhoneAppDatabase.Enabled(app_id) then
            migrated[app_id] = true
            schema_migrated[app_id] = true
        end
    end
end

function SkyPhoneAppDatabase.Run(app_id, statement)
    local entries = pending_sql[app_id]
    if not entries then
        entries = {}
        pending_sql[app_id] = entries
    end
    local entry = { statement = statement, ran = false }
    entries[#entries + 1] = entry
    if SkyPhoneAppDatabase.Enabled(app_id) then
        entry.statement()
        entry.ran = true
    end
end

function SkyPhoneAppDatabase.Ensure(app_id, force)
    if not force and not SkyPhoneAppDatabase.Enabled(app_id) then
        return false
    end
    if migrated[app_id] then
        return true
    end
    local tables = schema_by_app[app_id]
    if not schema_migrated[app_id] and tables and tables[1] then
        local required = {}
        for _, definition in ipairs(tables) do required[definition.name] = true end
        Bridge.Database.Migrate("sky_phone_app_" .. app_id:gsub("[^%w]", "_"), include_parents(full_schema, required))
    end
    schema_migrated[app_id] = true
    local entries = pending_sql[app_id] or {}
    for index = 1, #entries do
        local entry = entries[index]
        if not entry.ran then
            entry.statement()
            entry.ran = true
        end
    end
    migrated[app_id] = true
    return true
end

function SkyPhoneAppDatabase.WhenEnabled(app_id, start, deferred_names)
    managed_apps[app_id] = true
    local function attempt()
        if starters[app_id] or starting[app_id] then
            return
        end
        if not SkyPhoneAppDatabase.Enabled(app_id) then
            cancel_deferred(deferred_names)
            return
        end
        starting[app_id] = true
        local ok, reason = pcall(SkyPhoneAppDatabase.Ensure, app_id)
        starting[app_id] = nil
        if not ok then error(reason, 0) end
        if not SkyPhoneAppDatabase.Enabled(app_id) then return end
        starters[app_id] = true
        start()
        ready_apps[app_id] = true
    end
    Bridge.Database.AfterMigration("sky_phone", attempt)
    AddEventHandler("sky_phone:configurator:serverUpdated", attempt)
end

function SkyPhoneAppDatabase.Bind(app_id, deferred_names)
    return function(start)
        SkyPhoneAppDatabase.WhenEnabled(app_id, start, deferred_names)
    end
end
