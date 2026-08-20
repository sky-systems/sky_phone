Bridge.Database.AfterMigration("sky_phone", function()
local BUILTIN_APPS = {
    banking = true,
    billing = true,
    calculator = true,
    calendar = true,
    camera = true,
    citymarkt = true,
    citywarn = true,
    clock = true,
    companies = true,
    crewlink = true,
    crypto = true,
    darkchat = true,
    feather = true,
    flare = true,
    fliptok = true,
    garage = true,
    health = true,
    house = true,
    ["app-store"] = true,
    ["local-pages"] = true,
    mail = true,
    map = true,
    memos = true,
    memory = true,
    messages = true,
    minesweeper = true,
    music = true,
    ["neon-drop"] = true,
    notes = true,
    ["number-merge"] = true,
    phone = true,
    photos = true,
    picstagram = true,
    radio = true,
    settings = true,
    ["sky-flappy"] = true,
    skyride = true,
    snake = true,
    ["tower-stack"] = true,
    weather = true,
    ["weazel-news"] = true,
}

local DEFAULT_INSTALLED_APPS = {
    ["app-store"] = true,
    calculator = true,
    calendar = true,
    camera = true,
    citywarn = true,
    clock = true,
    health = true,
    mail = true,
    map = true,
    memos = true,
    messages = true,
    notes = true,
    phone = true,
    photos = true,
    settings = true,
    weather = true,
}

local PROTECTED_APPS = {
    ["app-store"] = true,
    camera = true,
    citywarn = true,
    health = true,
    mail = true,
    messages = true,
    phone = true,
    photos = true,
    settings = true,
}

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

local function player_name(source)
    local first_name = trim(Bridge.Framework.GetFirstname(source))
    local last_name = trim(Bridge.Framework.GetLastname(source))
    local character_name = trim((first_name .. " " .. last_name))
    return character_name ~= "" and character_name or GetPlayerName(source) or ("Player %s"):format(source)
end

local function require_admin(source, operation, maximum)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    if not Config.AdminPanel.Enabled
        or not Bridge.Framework.HasAdminGroup(source, Config.AdminPanel.AdminGroups)
    then
        Bridge.Debug("warn", "[sky_phone] Rejected admin panel access from source %s.", tostring(source))
        return nil, { success = false, error = "not_authorized" }
    end
    if not SkyPhone.AllowOperation(source, "admin_" .. operation, maximum, 60) then
        return nil, { success = false, error = "rate_limited" }
    end
    return session
end

local function normalize_source(value)
    local player_source = tonumber(value)
    if not player_source or player_source < 1 or player_source ~= math.floor(player_source) then
        return nil
    end
    if not Bridge.Framework.GetIdentifier(player_source) then
        return nil
    end
    return player_source
end

local function collect_device_imeis(source, identifier)
    local imeis = {}
    local seen = {}
    local function add_imei(imei)
        if SkyPhoneImei.IsValid(imei) and not seen[imei] then
            seen[imei] = true
            imeis[#imeis + 1] = imei
        end
    end

    for _, item in ipairs(Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)) do
        add_imei(item.metadata and item.metadata.imei)
    end

    local rows = Bridge.Database.Query([[
        SELECT `device_imei` AS `imei`
        FROM `sky_phone_character_devices`
        WHERE `owner_identifier` = ?
        UNION
        SELECT device.`imei`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        WHERE sim.`owner_identifier` = ?
    ]], { identifier, identifier })
    for _, row in ipairs(rows) do
        add_imei(row.imei)
    end

    table.sort(imeis)
    return imeis
end

local function normalize_app_ids(value)
    local normalized = {}
    local seen = {}
    if type(value) ~= "table" then
        return normalized
    end

    for index = 1, #value do
        local app_id = value[index]
        if type(app_id) == "string"
            and #app_id > 0
            and #app_id <= 64
            and not seen[app_id]
        then
            seen[app_id] = true
            normalized[#normalized + 1] = app_id
        end
    end
    return normalized
end

local function load_app_payload(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return {}, {}, {}
    end
    local payload = json.decode(encoded)
    if type(payload) ~= "table" then
        error("[sky_phone] Stored admin target app payload is not a JSON object.")
    end
    return payload, normalize_app_ids(payload.claimedApps), normalize_app_ids(payload.uninstalledApps)
end

local function load_player_devices(source, identifier)
    local imeis = collect_device_imeis(source, identifier)
    if #imeis == 0 then
        return {}
    end

    local placeholders = {}
    for index = 1, #imeis do
        placeholders[index] = "?"
    end
    local rows = Bridge.Database.Query(([[
        SELECT device.`imei`, device.`device_name`, device.`created_at`, device.`updated_at`,
            sim.`phone_number`, sim.`sim_type`, sim.`registered_at`,
            account.`id` AS `account_id`, account.`email` AS `account_email`,
            security.`passcode_length`, security.`failed_attempts`, security.`locked_until`,
            app_data.`payload` AS `apps_payload`, app_data.`revision` AS `apps_revision`
        FROM `sky_phone_devices` device
        LEFT JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        LEFT JOIN `sky_phone_accounts` account ON account.`id` = device.`account_id`
        LEFT JOIN `sky_phone_device_security` security ON security.`device_imei` = device.`imei`
        LEFT JOIN `sky_phone_device_data` app_data
            ON app_data.`device_imei` = device.`imei` AND app_data.`namespace` = 'apps'
        WHERE device.`imei` IN (%s)
        ORDER BY device.`updated_at` DESC, device.`imei` ASC
    ]]):format(table.concat(placeholders, ", ")), imeis)

    local devices = {}
    for _, row in ipairs(rows) do
        local _, claimed_apps, uninstalled_apps = load_app_payload(row.apps_payload)
        devices[#devices + 1] = {
            imei = row.imei,
            name = row.device_name,
            createdAt = row.created_at,
            updatedAt = row.updated_at,
            number = row.phone_number,
            simType = row.sim_type,
            simRegistered = row.registered_at ~= nil,
            account = row.account_id and {
                id = tonumber(row.account_id),
                email = row.account_email,
                passwordAvailable = true,
            } or nil,
            security = {
                enabled = row.passcode_length ~= nil,
                length = row.passcode_length and tonumber(row.passcode_length) or nil,
                failedAttempts = tonumber(row.failed_attempts) or 0,
                lockedUntil = tonumber(row.locked_until) or 0,
            },
            apps = {
                claimed = claimed_apps,
                uninstalled = uninstalled_apps,
                revision = tonumber(row.apps_revision) or 0,
            },
        }
    end
    return devices
end

local function build_player_summary(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    local devices = load_player_devices(source, identifier)
    local job = Bridge.Framework.GetJob(source)
    return {
        source = source,
        identifier = identifier,
        name = player_name(source),
        serverName = GetPlayerName(source) or "",
        job = job.label ~= "" and job.label or job.name,
        grade = job.grade,
        onDuty = job.onDuty,
        deviceCount = #devices,
        phoneNumber = devices[1] and devices[1].number or nil,
    }
end

local function list_players()
    local sources = Bridge.Framework.GetPlayers()
    table.sort(sources, function(left, right)
        return tonumber(left) < tonumber(right)
    end)

    local players = {}
    local maximum = math.max(1, math.floor(tonumber(Config.AdminPanel.MaximumPlayers) or 128))
    for index = 1, math.min(#sources, maximum) do
        local player_source = tonumber(sources[index])
        if player_source and Bridge.Framework.GetIdentifier(player_source) then
            players[#players + 1] = build_player_summary(player_source)
        end
    end
    return players
end

local function load_player_detail(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    local job = Bridge.Framework.GetJob(source)
    return {
        source = source,
        identifier = identifier,
        name = player_name(source),
        serverName = GetPlayerName(source) or "",
        firstName = trim(Bridge.Framework.GetFirstname(source)),
        lastName = trim(Bridge.Framework.GetLastname(source)),
        birthdate = trim(Bridge.Framework.GetBirthdate(source)),
        job = {
            name = job.name,
            label = job.label,
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            onDuty = job.onDuty,
        },
        money = {
            bank = tonumber(Bridge.Framework.GetMoney(source, "bank")) or 0,
            cash = tonumber(Bridge.Framework.GetMoney(source, "cash")) or 0,
        },
        devices = load_player_devices(source, identifier),
    }
end

local function find_owned_device(source, imei)
    local identifier = Bridge.Framework.GetIdentifier(source)
    for _, device in ipairs(load_player_devices(source, identifier)) do
        if device.imei == imei then
            return device, identifier
        end
    end
    return nil, identifier
end

local function app_metadata(app_id)
    if BUILTIN_APPS[app_id] then
        return {
            defaultInstalled = DEFAULT_INSTALLED_APPS[app_id] == true,
            removable = PROTECTED_APPS[app_id] ~= true,
        }
    end
    if SkyPhoneApps.GetPolicy(app_id) then
        return { defaultInstalled = false, removable = true }
    end
    return nil
end

local function remove_app_id(values, app_id)
    local next_values = {}
    for index = 1, #values do
        if values[index] ~= app_id then
            next_values[#next_values + 1] = values[index]
        end
    end
    return next_values
end

local function add_app_id(values, app_id)
    for index = 1, #values do
        if values[index] == app_id then
            return values
        end
    end
    values[#values + 1] = app_id
    return values
end

local function write_audit(actor_source, target_source, target_identifier, imei, action, details)
    local actor_identifier = Bridge.Framework.GetIdentifier(actor_source)
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_admin_audit`
            (`actor_identifier`, `actor_name`, `target_identifier`, `target_source`, `device_imei`, `action`, `details`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        actor_identifier,
        player_name(actor_source),
        target_identifier,
        target_source,
        imei,
        action,
        json.encode(details or {}),
    })
    if affected_rows(result) ~= 1 then
        error("[sky_phone] Admin audit insert did not affect exactly one row.")
    end
end

local function load_audit()
    local limit = math.max(1, math.min(100, math.floor(tonumber(Config.AdminPanel.AuditLimit) or 40)))
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `actor_name`, `target_identifier`, `target_source`, `device_imei`,
            `action`, `details`, `created_at`
        FROM `sky_phone_admin_audit`
        ORDER BY `id` DESC
        LIMIT %s
    ]]):format(limit), {})
    local audit = {}
    for _, row in ipairs(rows) do
        audit[#audit + 1] = {
            id = tonumber(row.id),
            actorName = row.actor_name,
            targetIdentifier = row.target_identifier,
            targetSource = row.target_source and tonumber(row.target_source) or nil,
            deviceImei = row.device_imei,
            action = row.action,
            details = json.decode(row.details),
            createdAt = row.created_at,
        }
    end
    return audit
end

Bridge.Callbacks.Register("sky_phone:admin:bootstrap", function(source)
    local session, error_response = require_admin(
        source,
        "bootstrap",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not session then
        return error_response
    end

    local players = list_players()
    local totals = Bridge.Database.Query([[
        SELECT
            (SELECT COUNT(*) FROM `sky_phone_devices`) AS `devices`,
            (SELECT COUNT(*) FROM `sky_phone_accounts`) AS `accounts`
    ]], {})
    return {
        success = true,
        data = {
            players = players,
            stats = {
                online = #players,
                devices = tonumber(totals[1] and totals[1].devices) or 0,
                accounts = tonumber(totals[1] and totals[1].accounts) or 0,
            },
            audit = load_audit(),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:admin:player", function(source, data)
    local session, error_response = require_admin(
        source,
        "player",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not session then
        return error_response
    end
    local target_source = normalize_source(data and data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:set-app", function(source, data)
    local session, error_response = require_admin(
        source,
        "set_app",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not session then
        return error_response
    end
    if type(data) ~= "table"
        or not SkyPhoneImei.IsValid(data.imei)
        or type(data.appId) ~= "string"
        or type(data.installed) ~= "boolean"
    then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local target_device, target_identifier = find_owned_device(target_source, data.imei)
    if not target_device then
        return { success = false, error = "device_not_owned" }
    end
    local metadata = app_metadata(data.appId)
    if not metadata then
        return { success = false, error = "invalid_app" }
    end
    if not data.installed and not metadata.removable then
        return { success = false, error = "app_protected" }
    end

    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision`
        FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = 'apps'
        LIMIT 1
    ]], { data.imei })
    local payload, claimed_apps, uninstalled_apps = load_app_payload(rows[1] and rows[1].payload)
    if data.installed then
        uninstalled_apps = remove_app_id(uninstalled_apps, data.appId)
        if not metadata.defaultInstalled then
            claimed_apps = add_app_id(claimed_apps, data.appId)
        end
    else
        claimed_apps = remove_app_id(claimed_apps, data.appId)
        uninstalled_apps = add_app_id(uninstalled_apps, data.appId)
    end
    payload.claimedApps = claimed_apps
    payload.uninstalledApps = #uninstalled_apps > 0 and uninstalled_apps or nil

    local encoded = json.encode(payload)
    if #encoded > 100000 then
        return { success = false, error = "payload_too_large" }
    end

    if rows[1] then
        local revision = tonumber(rows[1].revision) or 0
        local result = Bridge.Database.Query([[
            UPDATE `sky_phone_device_data`
            SET `payload` = ?, `revision` = `revision` + 1
            WHERE `device_imei` = ? AND `namespace` = 'apps' AND `revision` = ?
        ]], { encoded, data.imei, revision })
        if affected_rows(result) ~= 1 then
            return { success = false, error = "revision_conflict" }
        end
    else
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
            VALUES (?, 'apps', ?)
        ]], { data.imei, encoded })
        if affected_rows(result) ~= 1 then
            return { success = false, error = "revision_conflict" }
        end
    end

    write_audit(
        source,
        target_source,
        target_identifier,
        data.imei,
        data.installed and "grant_app" or "revoke_app",
        { appId = data.appId }
    )
    SkyPhone.RefreshDevice(data.imei)
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:reveal-password", function(source, data)
    local session, error_response = require_admin(
        source,
        "reveal_password",
        Config.AdminPanel.CredentialRevealsPerMinute
    )
    if not session then
        return error_response
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end

    local accounts = Bridge.Database.Query([[
        SELECT account.`email`, account.`password`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_accounts` account ON account.`id` = device.`account_id`
        WHERE device.`imei` = ?
        LIMIT 1
    ]], { data.imei })
    if not accounts[1] then
        return { success = false, error = "account_not_found" }
    end

    write_audit(
        source,
        target_source,
        target_identifier,
        data.imei,
        "reveal_account_password",
        { email = accounts[1].email }
    )
    return {
        success = true,
        data = {
            email = accounts[1].email,
            password = accounts[1].password,
        },
    }
end)
end)
