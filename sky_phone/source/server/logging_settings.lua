-- SQL overrides are deliberately separate from Config/MediaConfig and their
-- client broadcasts. GetAdminData returns endpoint state, never stored URLs.
SkyPhoneWebhookSettings = {}
local settings = SkyPhoneWebhookSettings
local defaults = {}
for key, value in pairs(WebHooks) do
    defaults[key] = value
end
defaults.Actions = {}
for key, value in pairs(WebHooks.Actions or {}) do defaults.Actions[key] = value end

local categories = {}
for category in ([[Calls Contacts Messages Picstagram Feather FlipTok SkyPic DarkChat
    Flare Mail Marketplace Pages Companies Banking Crypto Billing Uploads Gallery
    Memos Notes Calendar WeazelNews CityWarn CrewLink SkyRide Radio Garage Housing
    Health Music Map EasyShare Account Device Security Sim Admin CustomApps]]):gmatch("%S+") do
    categories[#categories + 1] = category
end
table.sort(categories)

local general = { Enabled = true, Username = "Sky Phone", AvatarUrl = "", QueueLimit = 1000, MaxAttempts = 5 }
local direct_actions = {
    ["admin:save-webhooks"] = "Admin",
    ["calls:created"] = "Calls", ["calls:answered"] = "Calls", ["calls:ended"] = "Calls",
    ["calls:rerouted"] = "Calls", ["media:uploaded"] = "Uploads", ["media:deleted"] = "Gallery",
    ["memos:created"] = "Memos", ["health:activity"] = "Health",
    ["crewlink:external-ping-created"] = "CrewLink", ["crewlink:external-ping-removed"] = "CrewLink",
    ["billing:created"] = "Billing", ["billing:cancelled"] = "Billing", ["billing:balance-withdrawn"] = "Billing",
    ["fliptok:verification"] = "FlipTok", ["picstagram:verification"] = "Picstagram",
}
local overrides, revision, ready = {}, 0, false

local function endpoint_catalog()
    local result = { Default = "Default" }
    for _, category in ipairs(categories) do result[category] = category end
    for action, spec in pairs(SkyPhoneLog.Actions) do result["Actions." .. action] = spec.category end
    for action, category in pairs(direct_actions) do result["Actions." .. action] = category end
    for action in pairs(defaults.Actions) do
        local path = "Actions." .. action
        result[path] = result[path] or "CustomApps"
    end
    return result
end

local function file_value(path)
    local action = path:match("^Actions%.(.+)$")
    if action then return defaults.Actions[action] end
    return defaults[path]
end

local function effective_value(path)
    if overrides[path] ~= nil then return overrides[path] end
    return file_value(path)
end

local function apply()
    local effective = { Actions = {} }
    for key, fallback in pairs(general) do
        local value = effective_value(key)
        if value == nil then value = fallback end
        effective[key] = value
    end
    for path in pairs(endpoint_catalog()) do
        local value = effective_value(path)
        local action = path:match("^Actions%.(.+)$")
        if action then effective.Actions[action] = value else effective[path] = value end
    end
    WebHooks = effective
end

local function endpoint_mode(value)
    if value == false then return "disabled" end
    return type(value) == "string" and value ~= "" and "custom" or "inherit"
end

function settings.GetAdminData()
    if not ready then return nil end
    local endpoints, values, file_settings = {}, {}, {}
    for key, fallback in pairs(general) do
        values[key] = WebHooks[key]
        file_settings[key] = defaults[key]
        if file_settings[key] == nil then file_settings[key] = fallback end
    end
    for path, category in pairs(endpoint_catalog()) do
        local value = effective_value(path)
        endpoints[#endpoints + 1] = {
            path = path, category = category,
            mode = overrides[path] == nil and "file" or endpoint_mode(value),
            effectiveMode = endpoint_mode(value),
            configured = SkyPhoneLog.IsValidWebhook(value) == true,
        }
    end
    table.sort(endpoints, function(a, b) return a.path < b.path end)
    return { revision = revision, settings = values, defaults = file_settings, endpoints = endpoints }
end

local function valid_general(path, value)
    if path == "Enabled" then return type(value) == "boolean" end
    if path == "QueueLimit" or path == "MaxAttempts" then
        return type(value) == "number" and value >= 1 and value % 1 == 0
            and value <= (path == "QueueLimit" and 10000 or 10)
    end
    if type(value) ~= "string" or not utf8.len(value) or value:find("[%c]") then return false end
    if path == "Username" then return #value >= 1 and #value <= 80 end
    if path == "AvatarUrl" then
        return value == "" or (#value <= 2048 and value:match("^https://[^/@%s]+/%S*$") ~= nil
            and not value:find("/webhooks/", 1, true))
    end
    return false
end

local function load()
    local rows = Bridge.Database.Query("SELECT `payload`, `revision` FROM `sky_phone_webhooks` WHERE `id` = 1", {})
    local row = type(rows) == "table" and rows[1]
    if not row then error("[sky_phone] Webhook settings row is missing.") end
    local stored = json.decode(row.payload)
    if type(stored) ~= "table" then error("[sky_phone] Invalid stored webhook settings.") end
    local catalog = endpoint_catalog()
    for path, value in pairs(stored) do
        if general[path] ~= nil then
            if not valid_general(path, value) then error("[sky_phone] Invalid stored webhook option.") end
        elseif not catalog[path] or (value ~= false and value ~= "" and not SkyPhoneLog.IsValidWebhook(value)) then
            error("[sky_phone] Invalid stored webhook endpoint.")
        end
    end
    local loaded_revision = tonumber(row.revision)
    if not loaded_revision then error("[sky_phone] Invalid webhook settings revision.") end
    if loaded_revision >= revision then
        overrides, revision, ready = stored, loaded_revision, true
        apply()
    end
end

function settings.Save(expected_revision, changes)
    if not ready then return { success = false, error = "request_failed" } end
    if expected_revision ~= revision then return { success = false, error = "revision_conflict" } end
    if type(changes) ~= "table" or #changes < 1 or #changes > 512 then
        return { success = false, error = "invalid_request" }
    end
    local next_values, seen, changed_paths, catalog = {}, {}, {}, endpoint_catalog()
    for key, value in pairs(overrides) do next_values[key] = value end
    for index, change in pairs(changes) do
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #changes
            or type(change) ~= "table" or type(change.path) ~= "string" or seen[change.path] then
            return { success = false, error = "invalid_request" }
        end
        local path = change.path
        seen[path] = true
        if not catalog[path] and general[path] == nil then return { success = false, error = "invalid_field" } end
        if change.mode == "file" then
            next_values[path] = nil
        elseif general[path] ~= nil then
            if not valid_general(path, change.value) then return { success = false, error = "invalid_value" } end
            next_values[path] = change.value
        elseif change.mode == "inherit" then
            next_values[path] = ""
        elseif change.mode == "disabled" then
            next_values[path] = false
        elseif change.mode == "custom" then
            local value = change.url
            if value == nil or value == "" then value = effective_value(path) end
            if not SkyPhoneLog.IsValidWebhook(value) then return { success = false, error = "invalid_webhook" } end
            next_values[path] = value
        else
            return { success = false, error = "invalid_value" }
        end
        changed_paths[#changed_paths + 1] = path
    end
    local ok, result = pcall(function()
        return Bridge.Database.Query([[
            UPDATE `sky_phone_webhooks` SET `payload` = ?, `revision` = `revision` + 1
            WHERE `id` = 1 AND `revision` = ?
        ]], { json.encode(next_values), revision })
    end)
    if not ok then
        Bridge.Debug("warn", "[sky_phone] Could not persist webhook settings.")
        return { success = false, error = "request_failed" }
    end
    local affected = type(result) == "number" and result or type(result) == "table" and result.affectedRows
    if tonumber(affected) ~= 1 then
        local loaded = pcall(load)
        if not loaded then Bridge.Debug("warn", "[sky_phone] Could not reload webhook settings.") end
        return { success = false, error = "revision_conflict" }
    end
    -- Another callback may have loaded/saved a newer row while SQL was yielding.
    if expected_revision + 1 >= revision then
        overrides, revision = next_values, expected_revision + 1
        apply()
    end
    table.sort(changed_paths)
    return { success = true, data = settings.GetAdminData() }, changed_paths
end

Bridge.Database.AfterMigration("sky_phone", function()
    local ok = pcall(function()
        Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_webhooks` (`id`, `payload`, `revision`) VALUES (1, '{}', 0)", {})
        load()
    end)
    if not ok then
        Bridge.Debug("warn", "[sky_phone] Could not initialize webhook settings; using file configuration.")
    end
end)
