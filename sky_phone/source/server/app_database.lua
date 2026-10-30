SkyPhoneAppDatabase = {}

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
local pending_sql = {}
local migrated = {}
local starters = {}

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
    return longest_owner(tostring(table_name):lower(), table_owners)
end

function SkyPhoneAppDatabase.CallbackApp(name)
    return longest_owner(tostring(name), callback_owners)
end

function SkyPhoneAppDatabase.Filter(schema)
    local filtered = {}
    for index = 1, #schema do
        local table_definition = schema[index]
        local owner = SkyPhoneAppDatabase.Owner(table_definition.name)
        if not owner or SkyPhoneAppDatabase.Enabled(owner) then
            filtered[#filtered + 1] = table_definition
        end
    end
    return filtered
end

function SkyPhoneAppDatabase.Remember(schema)
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
        entry.ran = true
        entry.statement()
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
    if tables and tables[1] then
        Bridge.Database.Migrate("sky_phone_app_" .. app_id:gsub("[^%w]", "_"), tables)
    end
    migrated[app_id] = true
    local entries = pending_sql[app_id] or {}
    for index = 1, #entries do
        local entry = entries[index]
        if not entry.ran then
            entry.ran = true
            entry.statement()
        end
    end
    return true
end

function SkyPhoneAppDatabase.WhenEnabled(app_id, start, deferred_names)
    local function attempt()
        if starters[app_id] then
            return
        end
        if not SkyPhoneAppDatabase.Enabled(app_id) then
            cancel_deferred(deferred_names)
            return
        end
        SkyPhoneAppDatabase.Ensure(app_id)
        starters[app_id] = true
        start()
    end
    Bridge.Database.AfterMigration("sky_phone", attempt)
    AddEventHandler("sky_phone:configurator:serverUpdated", attempt)
end

function SkyPhoneAppDatabase.Bind(app_id, deferred_names)
    return function(start)
        SkyPhoneAppDatabase.WhenEnabled(app_id, start, deferred_names)
    end
end
