-- Non-destructive LB Phone importer. Every target write is idempotent and every
-- completed domain receives its own marker, so later versions can add domains
-- without replaying already migrated data. LB's source tables are read-only.
Bridge.Database.AfterMigration("sky_phone", function()
local migration_config = Config.Migrations and Config.Migrations.LbPhone or {}
local source_name = "lb-phone"
local marker_prefix = "lb-phone:"
local running = false

-- Increment a domain version whenever an idempotent repair must run for
-- installations that already recorded the previous importer as complete.
local domain_versions = {
    picstagram = 2,
    flipTok = 2,
    feather = 2,
}

local source_prefix = migration_config.SourcePrefix or "phone_"
if type(source_prefix) ~= "string" or not source_prefix:match("^[%w_]+$") then
    error("[sky_phone] LB Phone migration SourcePrefix must contain only letters, numbers, and underscores.")
end

local resolved_source_tables = {}

local function source_table(suffix)
    if resolved_source_tables[suffix] then
        return resolved_source_tables[suffix]
    end
    local table_name = source_prefix .. suffix
    local rescued_name = table_name .. "_lb"
    local rescued = Bridge.Database.Query([[
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND TABLE_TYPE = 'BASE TABLE'
        LIMIT 1
    ]], { rescued_name })
    resolved_source_tables[suffix] = rescued[1] and rescued_name or table_name
    return resolved_source_tables[suffix]
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    if type(result) == "table" then
        return tonumber(result.affectedRows) or tonumber(result.affected_rows) or 0
    end
    return 0
end

local function table_exists(table_name)
    local rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND TABLE_TYPE = 'BASE TABLE'
    ]], { table_name })
    return rows[1] and tonumber(rows[1].count) > 0 or false
end

local function table_has_column(table_name, column_name)
    local rows = Bridge.Database.Query([[
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        LIMIT 1
    ]], { table_name, column_name })
    return rows[1] ~= nil
end

local function count_rows(table_name)
    if not table_exists(table_name) then
        return 0
    end
    local rows = Bridge.Database.Query(("SELECT COUNT(*) AS `count` FROM `%s`"):format(table_name), {})
    return rows[1] and tonumber(rows[1].count) or 0
end

local function clamp_text(value, maximum)
    if value == nil then
        return ""
    end
    return tostring(value):sub(1, maximum)
end

local function normalize_number(value)
    return SkyPhoneSimNumber.Normalize(value)
end

local function deterministic_hex(namespace, value)
    local parts = {}
    for index = 1, 4 do
        local hash = joaat(("%s:%s:%s"):format(namespace, tostring(value), index))
        if hash < 0 then
            hash = hash + 4294967296
        end
        parts[index] = ("%08x"):format(hash)
    end
    return table.concat(parts)
end

local function deterministic_uuid(namespace, value)
    local value_hash = deterministic_hex(namespace, value)
    return ("%s-%s-%s-%s-%s"):format(
        value_hash:sub(1, 8),
        value_hash:sub(9, 12),
        value_hash:sub(13, 16),
        value_hash:sub(17, 20),
        value_hash:sub(21, 32)
    )
end

local function deterministic_imei(value)
    return SkyPhoneImei.FromEntropy(deterministic_hex("lb-phone-imei", value))
end

local function synthetic_email(namespace, value)
    local domain = tostring(Config.Mail.Domain or "ifruit.com"):lower()
    local suffix = "@" .. domain
    local local_maximum = math.max(3, 64 - #suffix)
    local local_part = (namespace .. "_" .. deterministic_hex(namespace, value)):sub(1, local_maximum)
    return local_part .. suffix
end

local function decode_json(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return {}
    end
    local success, decoded = pcall(json.decode, value)
    if success and type(decoded) == "table" then
        return decoded
    end
    return {}
end

local function insert_many(prefix, width, rows, suffix)
    if #rows == 0 then
        return 0
    end

    local inserted = 0
    for first = 1, #rows, 250 do
        local last = math.min(first + 249, #rows)
        local groups = {}
        local parameters = {}
        for row_index = first, last do
            local cells = {}
            local row = rows[row_index]
            for column = 1, width do
                if row[column] == nil then
                    cells[column] = "NULL"
                else
                    cells[column] = "?"
                    parameters[#parameters + 1] = row[column]
                end
            end
            groups[#groups + 1] = "(" .. table.concat(cells, ",") .. ")"
        end
        local query = prefix .. " " .. table.concat(groups, ",")
        if suffix then
            query = query .. " " .. suffix
        end
        inserted = inserted + affected_rows(Bridge.Database.Query(query, parameters))
    end
    return inserted
end

local function migration_name(domain)
    local version = domain_versions[domain]
    return marker_prefix .. domain .. (version and (":v" .. version) or "")
end

local function migration_done(domain)
    local rows = Bridge.Database.Query([[
        SELECT 1 FROM `sky_phone_migrations` WHERE `name` = ? LIMIT 1
    ]], { migration_name(domain) })
    return rows[1] ~= nil
end

local function record_migration(domain, stats)
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_migrations` (`name`, `source`, `stats`)
        VALUES (?, ?, ?)
    ]], { migration_name(domain), source_name, json.encode(stats or {}) })
end

local function load_roster()
    local rows
    local success, result = pcall(function()
        if Bridge.Framework.Name == "esx" then
            return Bridge.Database.Query("SELECT `identifier` AS `character_id`, `identifier` AS `license` FROM `users`", {})
        end
        return Bridge.Database.Query("SELECT `citizenid` AS `character_id`, `license` FROM `players`", {})
    end)
    if success then
        rows = result
    else
        Bridge.Debug(
            "error",
            "[sky_phone] LB Phone migration could not load the framework character roster: %s",
            tostring(result),
            { always = true }
        )
        rows = {}
    end

    local direct = {}
    local licenses = {}
    for index = 1, #rows do
        local character_id = tostring(rows[index].character_id or "")
        local license = tostring(rows[index].license or "")
        if character_id ~= "" and #character_id <= 80 then
            direct[character_id] = character_id
            local embedded_license = character_id:match("(license[%w]*:[%w]+)")
            if license == "" and embedded_license then
                license = embedded_license
            end
            if license ~= "" then
                licenses[license] = licenses[license] or {}
                licenses[license][#licenses[license] + 1] = character_id
            end
        end
    end
    return direct, licenses
end

local function resolve_owner(owner_id, direct, licenses)
    owner_id = tostring(owner_id or "")
    local mode = migration_config.IdentifierMode or "auto"
    if owner_id == "" or #owner_id > 100 then
        return nil, "unresolved"
    end
    if mode ~= "license" and direct[owner_id] then
        return direct[owner_id]
    end
    if mode == "identifier" then
        return nil, "unresolved"
    end
    local matches = licenses[owner_id]
    if not matches then
        return nil, "unresolved"
    end
    if #matches ~= 1 then
        return nil, "ambiguous"
    end
    return matches[1]
end

local function load_context()
    local context = {
        number_map = {},
        owner_by_number = {},
        owner_by_phone_id = {},
        sim_by_number = {},
    }
    local numbers = Bridge.Database.Query([[
        SELECT `source_number`, `phone_number`, `sim_id`, `owned`
        FROM `sky_phone_migration_numbers` WHERE `source` = ?
    ]], { source_name })
    for index = 1, #numbers do
        local row = numbers[index]
        local mapped = {
            phone_number = row.phone_number,
            sim_id = row.sim_id,
            owned = tonumber(row.owned) == 1,
        }
        context.number_map[tostring(row.source_number)] = mapped
        context.number_map[tostring(row.phone_number)] = mapped
    end

    local owners = Bridge.Database.Query([[
        SELECT `source_phone_id`, `source_phone_number`, `source_owner_id`, `owner_identifier`,
            `device_imei`, `sim_id`, `account_id`
        FROM `sky_phone_migration_owners` WHERE `source` = ?
    ]], { source_name })
    for index = 1, #owners do
        local row = owners[index]
        context.owner_by_number[tostring(row.source_phone_number)] = row
        context.owner_by_phone_id[tostring(row.source_phone_id)] = row
    end

    local sims = Bridge.Database.Query("SELECT `id`, `phone_number`, `owner_identifier`, `sim_type` FROM `sky_phone_sims`", {})
    for index = 1, #sims do
        context.sim_by_number[tostring(sims[index].phone_number)] = sims[index]
    end
    return context
end

local function ensure_number_maps(context, values, dry_run)
    local unique = {}
    local sim_rows = {}
    local mapping_rows = {}
    local invalid = 0
    for index = 1, #values do
        local source_number = tostring(values[index] or "")
        if source_number ~= "" and not unique[source_number] and not context.number_map[source_number] then
            unique[source_number] = true
            local normalized = normalize_number(source_number)
            if not normalized then
                invalid = invalid + 1
            else
                local sim = context.sim_by_number[normalized]
                if not sim then
                    local sim_id = deterministic_uuid("lb-phone-external-sim", normalized)
                    sim = {
                        id = sim_id,
                        phone_number = normalized,
                        owner_identifier = nil,
                    }
                    context.sim_by_number[normalized] = sim
                    sim_rows[#sim_rows + 1] = { sim_id, normalized, "anonymous", 1 }
                end
                mapping_rows[#mapping_rows + 1] = {
                    source_name,
                    source_number,
                    normalized,
                    sim.id,
                    0,
                }
                context.number_map[source_number] = {
                    phone_number = normalized,
                    sim_id = sim.id,
                    owned = false,
                }
            end
        end
    end

    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_sims`
                (`id`, `phone_number`, `sim_type`, `is_virtual`) VALUES
        ]], 4, sim_rows)
        insert_many([[
            INSERT IGNORE INTO `sky_phone_migration_numbers`
                (`source`, `source_number`, `phone_number`, `sim_id`, `owned`) VALUES
        ]], 5, mapping_rows)
    end
    return #mapping_rows, invalid
end

local function run_devices(dry_run)
    local phones_table = source_table("phones")
    if not table_exists(phones_table) then
        return nil, "source_missing"
    end

    local source_phones = Bridge.Database.Query(([[
        SELECT phone.*, DATE_FORMAT(phone.`last_seen`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` phone
    ]]):format(phones_table), {})
    local direct, licenses = load_roster()
    local resolved = {}
    local owners = {}
    local stats = {
        source = #source_phones,
        resolved = 0,
        unresolved = 0,
        ambiguous = 0,
        invalid_numbers = 0,
        imported = 0,
        conflicts = 0,
    }
    for index = 1, #source_phones do
        local phone = source_phones[index]
        local owner_identifier, reason = resolve_owner(phone.owner_id, direct, licenses)
        local normalized = normalize_number(phone.phone_number)
        if not owner_identifier then
            stats[reason] = (stats[reason] or 0) + 1
        elseif not normalized then
            stats.invalid_numbers = stats.invalid_numbers + 1
        else
            phone.source_phone_id = tostring(phone.id)
            phone.source_number = tostring(phone.phone_number)
            phone.normalized_number = normalized
            phone.owner_identifier = owner_identifier
            resolved[#resolved + 1] = phone
            owners[owner_identifier] = owners[owner_identifier] or {}
            owners[owner_identifier][#owners[owner_identifier] + 1] = phone
            stats.resolved = stats.resolved + 1
        end
    end
    if dry_run then
        stats.imported = #resolved
        return stats
    end

    local preferred_numbers = {}
    local last_table = source_table("last_phone")
    if table_exists(last_table) then
        local last_rows = Bridge.Database.Query(("SELECT `id`, `phone_number` FROM `%s`"):format(last_table), {})
        for index = 1, #last_rows do
            preferred_numbers[tostring(last_rows[index].id)] = tostring(last_rows[index].phone_number)
        end
    end

    local character_rows = Bridge.Database.Query([[
        SELECT c.`owner_identifier`, c.`device_imei`, d.`account_id`, d.`sim_id`, s.`phone_number`
        FROM `sky_phone_character_devices` c
        JOIN `sky_phone_devices` d ON d.`imei` = c.`device_imei`
        LEFT JOIN `sky_phone_sims` s ON s.`id` = d.`sim_id`
    ]], {})
    local character_devices = {}
    for index = 1, #character_rows do
        character_devices[tostring(character_rows[index].owner_identifier)] = character_rows[index]
    end

    local existing_mappings = Bridge.Database.Query([[
        SELECT * FROM `sky_phone_migration_owners` WHERE `source` = ?
    ]], { source_name })
    local mapping_by_phone_id = {}
    local migrated_account_by_owner = {}
    for index = 1, #existing_mappings do
        local row = existing_mappings[index]
        mapping_by_phone_id[tostring(row.source_phone_id)] = row
        if row.account_id then
            migrated_account_by_owner[tostring(row.owner_identifier)] = tonumber(row.account_id)
        end
    end

    local account_rows = {}
    local account_email_by_owner = {}
    for owner_identifier in pairs(owners) do
        local character = character_devices[owner_identifier]
        if not (character and character.account_id) and not migrated_account_by_owner[owner_identifier] then
            local email = synthetic_email("lb", owner_identifier)
            account_email_by_owner[owner_identifier] = email
            account_rows[#account_rows + 1] = { email, deterministic_hex("lb-account-password", owner_identifier) }
        end
    end
    insert_many("INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES", 2, account_rows)

    local accounts = Bridge.Database.Query("SELECT `id`, `email` FROM `sky_phone_accounts`", {})
    local account_by_email = {}
    for index = 1, #accounts do
        account_by_email[tostring(accounts[index].email):lower()] = tonumber(accounts[index].id)
    end
    local account_by_owner = {}
    for owner_identifier in pairs(owners) do
        local character = character_devices[owner_identifier]
        account_by_owner[owner_identifier] = character and tonumber(character.account_id)
            or migrated_account_by_owner[owner_identifier]
            or account_by_email[account_email_by_owner[owner_identifier]]
        if character and not character.account_id and account_by_owner[owner_identifier] then
            Bridge.Database.Query([[
                UPDATE `sky_phone_devices` SET `account_id` = ?
                WHERE `imei` = ? AND `account_id` IS NULL
            ]], { account_by_owner[owner_identifier], character.device_imei })
        end
    end

    local sim_rows = Bridge.Database.Query([[
        SELECT s.`id`, s.`phone_number`, s.`owner_identifier`, d.`imei` AS `device_imei`
        FROM `sky_phone_sims` s
        LEFT JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
    ]], {})
    local sim_by_number = {}
    for index = 1, #sim_rows do
        sim_by_number[tostring(sim_rows[index].phone_number)] = sim_rows[index]
    end

    local preferred_by_owner = {}
    for owner_identifier, owner_phones in pairs(owners) do
        local wanted = preferred_numbers[tostring(owner_phones[1].owner_id)]
            or preferred_numbers[owner_identifier]
        preferred_by_owner[owner_identifier] = owner_phones[1]
        if wanted then
            for index = 1, #owner_phones do
                if owner_phones[index].source_number == wanted then
                    preferred_by_owner[owner_identifier] = owner_phones[index]
                    break
                end
            end
        end
    end

    local new_sims = {}
    for index = 1, #resolved do
        local phone = resolved[index]
        local character = character_devices[phone.owner_identifier]
        local preferred_has_sim = preferred_by_owner[phone.owner_identifier] == phone
            and character and character.sim_id
        if not preferred_has_sim and not sim_by_number[phone.normalized_number] then
            local sim_id = deterministic_uuid("lb-phone-sim", phone.normalized_number)
            sim_by_number[phone.normalized_number] = {
                id = sim_id,
                phone_number = phone.normalized_number,
                owner_identifier = phone.owner_identifier,
            }
            new_sims[#new_sims + 1] = {
                sim_id,
                phone.normalized_number,
                "registered",
                Config.Sim.Enabled == false and 1 or 0,
                phone.owner_identifier,
                phone.migrated_at,
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_sims`
            (`id`, `phone_number`, `sim_type`, `is_virtual`, `owner_identifier`, `registered_at`) VALUES
    ]], 6, new_sims)

    local new_devices = {}
    local pending = {}
    for index = 1, #resolved do
        local phone = resolved[index]
        local existing = mapping_by_phone_id[phone.source_phone_id]
        local character = character_devices[phone.owner_identifier]
        local preferred = preferred_by_owner[phone.owner_identifier] == phone
        local sim = sim_by_number[phone.normalized_number]
        local device_imei
        local mapped_sim = sim

        if existing then
            device_imei = existing.device_imei
            mapped_sim = { id = existing.sim_id, phone_number = phone.normalized_number }
        elseif preferred and character then
            device_imei = character.device_imei
            if character.sim_id then
                mapped_sim = { id = character.sim_id, phone_number = character.phone_number }
            else
                Bridge.Database.Query([[
                    UPDATE `sky_phone_devices` SET `sim_id` = ?, `account_id` = COALESCE(`account_id`, ?)
                    WHERE `imei` = ? AND `sim_id` IS NULL
                ]], { sim.id, account_by_owner[phone.owner_identifier], device_imei })
            end
        elseif sim.owner_identifier and sim.owner_identifier ~= phone.owner_identifier then
            stats.conflicts = stats.conflicts + 1
        elseif sim.device_imei then
            device_imei = sim.device_imei
        else
            device_imei = deterministic_imei(phone.source_phone_id)
            new_devices[#new_devices + 1] = {
                device_imei,
                account_by_owner[phone.owner_identifier],
                sim.id,
                clamp_text(phone.name and phone.name ~= "" and phone.name or Config.Phone.DeviceName, 64),
                phone.migrated_at,
            }
        end

        if device_imei and mapped_sim and mapped_sim.id then
            pending[#pending + 1] = {
                phone = phone,
                preferred = preferred,
                device_imei = device_imei,
                sim_id = mapped_sim.id,
                phone_number = mapped_sim.phone_number or phone.normalized_number,
                account_id = account_by_owner[phone.owner_identifier],
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_devices`
            (`imei`, `account_id`, `sim_id`, `device_name`, `created_at`) VALUES
    ]], 5, new_devices)

    local owner_rows = {}
    local number_rows = {}
    local character_mappings = {}
    for index = 1, #pending do
        local entry = pending[index]
        local phone = entry.phone
        owner_rows[#owner_rows + 1] = {
            source_name,
            phone.source_phone_id,
            tostring(phone.owner_id),
            phone.owner_identifier,
            phone.source_number,
            entry.device_imei,
            entry.sim_id,
            entry.account_id,
        }
        number_rows[#number_rows + 1] = {
            source_name,
            phone.source_number,
            entry.phone_number,
            entry.sim_id,
            1,
        }
        if entry.preferred and not character_devices[phone.owner_identifier] then
            character_mappings[#character_mappings + 1] = { phone.owner_identifier, entry.device_imei }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_migration_owners`
            (`source`, `source_phone_id`, `source_owner_id`, `owner_identifier`, `source_phone_number`,
                `device_imei`, `sim_id`, `account_id`) VALUES
    ]], 8, owner_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_migration_numbers`
            (`source`, `source_number`, `phone_number`, `sim_id`, `owned`) VALUES
    ]], 5, number_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_character_devices` (`owner_identifier`, `device_imei`) VALUES
    ]], 2, character_mappings)

    stats.imported = #pending
    return stats
end

local function percentage(value, fallback)
    local number = tonumber(value)
    if not number then
        return fallback
    end
    if number <= 1 then
        number = number * 100
    end
    return math.max(0, math.min(100, math.floor(number + 0.5)))
end

local function valid_media_url(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:match("^%s*(.-)%s*$")
    if #value > 2000000 then
        return nil
    end
    if value:match("^https?://") or value:match("^nui://") then
        return value
    end
    return nil
end

local function first_attachment(value)
    local attachments = decode_json(value)
    local attachment = attachments[1]
    if type(attachment) == "string" then
        return valid_media_url(attachment), "image"
    end
    if type(attachment) ~= "table" then
        return nil, nil
    end
    local url = valid_media_url(attachment.url or attachment.src or attachment.link or attachment.attachment)
    local media_type = tostring(attachment.type or attachment.mediaType or "image"):lower()
    if media_type:find("video", 1, true) then
        media_type = "video"
    elseif media_type:find("gif", 1, true) then
        media_type = "gif"
    else
        media_type = "image"
    end
    return url, media_type
end

local function load_media_ids(pattern)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `source_id` FROM `sky_phone_media`
        WHERE `origin` = 'website_import' AND `source_id` LIKE ?
    ]], { pattern })
    local media = {}
    for index = 1, #rows do
        media[tostring(rows[index].source_id)] = tonumber(rows[index].id)
    end
    return media
end

local function run_settings(dry_run)
    local table_name = source_table("phones")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT p.`id`, p.`pin`, p.`settings`, p.`is_setup`, owner.`device_imei`
        FROM `%s` p
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_id` = p.`id`
    ]]):format(table_name), { source_name })
    local data_rows = {}
    local security_rows = {}
    local skipped = 0
    for index = 1, #rows do
        local row = rows[index]
        local source_settings = decode_json(row.settings)
        local display = type(source_settings.display) == "table" and source_settings.display or {}
        local sound = type(source_settings.sound) == "table" and source_settings.sound or {}
        local wallpaper = type(source_settings.wallpaper) == "table" and source_settings.wallpaper or {}
        local theme = tostring(display.theme or "automatic"):lower()
        if theme ~= "light" and theme ~= "dark" then
            theme = "automatic"
        end
        local wallpaper_url = valid_media_url(wallpaper.background)
        local setup_completed = row.is_setup == true or tonumber(row.is_setup) == 1
        local payload = {
            version = 1,
            settings = {
                appearanceMode = theme,
                notificationVolume = percentage(sound.volume, 70),
                phoneScale = percentage(display.size, 100),
                ringtoneVolume = percentage(sound.callVolume, 80),
                screenBrightness = percentage(display.brightness, 100),
                setupCompleted = setup_completed,
                setupStep = setup_completed and 9 or 0,
                wallpaper = wallpaper_url and "custom" or "midnight",
                wallpaperHistory = wallpaper_url
                    and { { imageUrl = wallpaper_url, wallpaper = "custom" } }
                    or { { wallpaper = "midnight" } },
                wallpaperImageUrl = wallpaper_url,
            },
        }
        data_rows[#data_rows + 1] = { row.device_imei, "settings", json.encode(payload) }

        local pin = type(row.pin) == "string" and row.pin or ""
        if pin:match("^%d%d%d%d$") then
            security_rows[#security_rows + 1] = {
                row.device_imei,
                pin,
                deterministic_hex("lb-phone-passcode-salt", row.id),
                #pin,
            }
        elseif pin ~= "" then
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`) VALUES
        ]], 3, data_rows)
        local pepper = tostring(Config.Server.PasscodePepper or "")
        for index = 1, #security_rows do
            local row = security_rows[index]
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_device_security`
                    (`device_imei`, `passcode_hash`, `passcode_salt`, `passcode_length`)
                VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?, ?)
            ]], { row[1], pepper, row[3], row[2], row[3], row[4] })
        end
    end
    return { source = #rows, imported = #data_rows, passcodes = #security_rows, skipped = skipped }
end

local function run_alarms(dry_run)
    local table_name = source_table("clock_alarms")
    if not table_exists(table_name) then
        return { source = 0, imported = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT alarm.*, owner.`device_imei`
        FROM `%s` alarm
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = alarm.`phone_number`
        ORDER BY alarm.`phone_number`, alarm.`id`
    ]]):format(table_name), { source_name })
    local alarms_by_device = {}
    for index = 1, #rows do
        local row = rows[index]
        alarms_by_device[row.device_imei] = alarms_by_device[row.device_imei] or {}
        alarms_by_device[row.device_imei][#alarms_by_device[row.device_imei] + 1] = {
            id = "lb-alarm-" .. tostring(row.id),
            enabled = row.enabled == true or tonumber(row.enabled) == 1,
            note = clamp_text(row.label, 80),
            sound = "radar",
            time = ("%02d:%02d"):format(
                math.max(0, math.min(23, tonumber(row.hours) or 0)),
                math.max(0, math.min(59, tonumber(row.minutes) or 0))
            ),
            weekdays = {},
        }
    end
    local data_rows = {}
    for imei, alarms in pairs(alarms_by_device) do
        data_rows[#data_rows + 1] = { imei, "alarms", json.encode(alarms) }
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`) VALUES
        ]], 3, data_rows)
    end
    return { source = #rows, imported = #rows, devices = #data_rows }
end

local function run_contacts(dry_run)
    local table_name = source_table("phone_contacts")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT contact.*, owner.`account_id`, owner.`device_imei`
        FROM `%s` contact
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = contact.`phone_number`
    ]]):format(table_name), { source_name })
    local context = load_context()
    local contact_numbers = {}
    for index = 1, #rows do
        contact_numbers[#contact_numbers + 1] = rows[index].contact_phone_number
    end
    local _, invalid = ensure_number_maps(context, contact_numbers, dry_run)
    local avatar_rows = {}
    for index = 1, #rows do
        local row = rows[index]
        local avatar = valid_media_url(row.profile_image)
        if avatar then
            local key = deterministic_uuid("lb-phone-contact-avatar", tostring(row.phone_number) .. ":" .. tostring(row.contact_phone_number))
            avatar_rows[#avatar_rows + 1] = {
                row.account_id,
                avatar,
                "lb-contact-avatar:" .. key,
                "photo",
                "website_import",
                "lb-contact:" .. key,
            }
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_media`
                (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`, `verified_at`) VALUES
        ]], 7, (function()
            local with_verification = {}
            for index = 1, #avatar_rows do
                with_verification[index] = {
                    avatar_rows[index][1], avatar_rows[index][2], avatar_rows[index][3],
                    avatar_rows[index][4], avatar_rows[index][5], avatar_rows[index][6], os.date("!%Y-%m-%d %H:%M:%S"),
                }
            end
            return with_verification
        end)())
    end
    local avatar_ids = dry_run and {} or load_media_ids("lb-contact:%")
    local contact_rows = {}
    local skipped = invalid
    for index = 1, #rows do
        local row = rows[index]
        local target_number = context.number_map[tostring(row.contact_phone_number)]
        if target_number then
            local key = deterministic_uuid("lb-phone-contact-avatar", tostring(row.phone_number) .. ":" .. tostring(row.contact_phone_number))
            local contact_id = deterministic_uuid("lb-phone-contact", tostring(row.phone_number) .. ":" .. tostring(row.contact_phone_number))
            local name = (clamp_text(row.firstname, 50) .. " " .. clamp_text(row.lastname, 50)):match("^%s*(.-)%s*$")
            if name == "" then
                name = target_number.phone_number
            end
            contact_rows[#contact_rows + 1] = {
                contact_id,
                contact_id,
                row.account_id,
                clamp_text(name, 80),
                clamp_text(row.address, 500),
                clamp_text(row.email, 64) ~= "" and clamp_text(row.email, 64) or nil,
                target_number.phone_number,
                avatar_ids["lb-contact:" .. key],
                (row.favourite == true or tonumber(row.favourite) == 1) and 1 or 0,
            }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_contacts`
                (`id`, `contact_id`, `account_id`, `name`, `notes`, `email`, `phone_number`,
                    `avatar_media_id`, `favorite`) VALUES
        ]], 9, contact_rows)
    end
    return { source = #rows, imported = #contact_rows, avatars = #avatar_rows, skipped = skipped }
end

local function run_blocked(dry_run)
    local table_name = source_table("phone_blocked_numbers")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT blocked.* FROM `%s` blocked
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = blocked.`phone_number`
    ]]):format(table_name), { source_name })
    local context = load_context()
    local values = {}
    for index = 1, #rows do
        values[index] = rows[index].blocked_number
    end
    ensure_number_maps(context, values, dry_run)
    local inserts = {}
    local skipped = 0
    for index = 1, #rows do
        local blocker = context.number_map[tostring(rows[index].phone_number)]
        local blocked = context.number_map[tostring(rows[index].blocked_number)]
        if blocker and blocked and blocker.sim_id ~= blocked.sim_id then
            inserts[#inserts + 1] = { blocker.sim_id, blocked.sim_id }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_call_blocks` (`blocker_sim_id`, `blocked_sim_id`) VALUES
        ]], 2, inserts)
    end
    return { source = #rows, imported = #inserts, skipped = skipped }
end

local function run_calls(dry_run)
    local table_name = source_table("phone_calls")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT call_row.*,
            DATE_FORMAT(call_row.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` call_row
        WHERE EXISTS (
            SELECT 1 FROM `sky_phone_migration_owners` owner
            WHERE owner.`source` = ?
                AND (owner.`source_phone_number` = call_row.`caller`
                    OR owner.`source_phone_number` = call_row.`callee`)
        )
    ]]):format(table_name), { source_name })
    local context = load_context()
    local values = {}
    for index = 1, #rows do
        values[#values + 1] = rows[index].caller
        values[#values + 1] = rows[index].callee
    end
    ensure_number_maps(context, values, dry_run)
    local calls = {}
    local entries = {}
    local skipped = 0
    for index = 1, #rows do
        local row = rows[index]
        local caller = context.number_map[tostring(row.caller)]
        local callee = context.number_map[tostring(row.callee)]
        if caller and callee then
            local call_id = deterministic_uuid("lb-phone-call", row.id)
            local answered = row.answered == true or tonumber(row.answered) == 1
            local status = answered and "ended" or "missed"
            calls[#calls + 1] = {
                call_id,
                caller.sim_id,
                callee.sim_id,
                caller.phone_number,
                callee.phone_number,
                status,
                row.migrated_at,
                answered and row.migrated_at or nil,
                row.migrated_at,
                math.max(0, tonumber(row.duration) or 0),
            }
            local caller_owner = context.owner_by_number[tostring(row.caller)]
            local callee_owner = context.owner_by_number[tostring(row.callee)]
            if caller_owner then
                entries[#entries + 1] = {
                    call_id, caller_owner.account_id, nil, "outgoing", status,
                    callee.phone_number, row.migrated_at,
                }
            end
            if callee_owner then
                entries[#entries + 1] = {
                    call_id, callee_owner.account_id, nil, "incoming", status,
                    caller.phone_number, row.migrated_at,
                }
            end
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_calls`
                (`id`, `caller_sim_id`, `callee_sim_id`, `caller_number`, `callee_number`, `status`,
                    `started_at`, `answered_at`, `ended_at`, `duration_seconds`) VALUES
        ]], 10, calls)
        local existing = Bridge.Database.Query([[
            SELECT `call_id`, COALESCE(`account_id`, 0) AS `account_id`, COALESCE(`device_imei`, '') AS `device_imei`, `direction`
            FROM `sky_phone_call_entries` WHERE `call_id` LIKE '________-____-____-____-____________'
        ]], {})
        local seen = {}
        for index = 1, #existing do
            seen[("%s:%s:%s:%s"):format(
                existing[index].call_id,
                tostring(existing[index].account_id),
                tostring(existing[index].device_imei),
                existing[index].direction
            )] = true
        end
        local unique_entries = {}
        for index = 1, #entries do
            local row = entries[index]
            local key = ("%s:%s::%s"):format(row[1], tostring(row[2] or 0), row[4])
            if not seen[key] then
                seen[key] = true
                unique_entries[#unique_entries + 1] = row
            end
        end
        insert_many([[
            INSERT INTO `sky_phone_call_entries`
                (`call_id`, `account_id`, `device_imei`, `direction`, `status`, `other_number`, `created_at`) VALUES
        ]], 7, unique_entries)
    end
    return { source = #rows, imported = #calls, entries = #entries, skipped = skipped }
end

local function run_messages(dry_run)
    local channels_table = source_table("message_channels")
    local members_table = source_table("message_members")
    local messages_table = source_table("message_messages")
    if not table_exists(channels_table) or not table_exists(members_table) or not table_exists(messages_table) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT message_row.*, first_member.`phone_number` AS `first_number`,
            DATE_FORMAT(message_row.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`,
            second_member.`phone_number` AS `second_number`
        FROM `%s` message_row
        JOIN `%s` channel_row ON channel_row.`id` = message_row.`channel_id`
        JOIN `%s` first_member ON first_member.`channel_id` = message_row.`channel_id`
        JOIN `%s` second_member ON second_member.`channel_id` = message_row.`channel_id`
            AND first_member.`phone_number` < second_member.`phone_number`
        WHERE channel_row.`is_group` = 0
            AND (SELECT COUNT(*) FROM `%s` member_count
                WHERE member_count.`channel_id` = message_row.`channel_id`) = 2
            AND message_row.`sender` IN (first_member.`phone_number`, second_member.`phone_number`)
            AND EXISTS (
                SELECT 1 FROM `sky_phone_migration_owners` owner
                WHERE owner.`source` = ?
                    AND owner.`source_phone_number` IN (
                        first_member.`phone_number`, second_member.`phone_number`
                    )
            )
        ORDER BY message_row.`channel_id`, message_row.`timestamp`, message_row.`id`
    ]]):format(messages_table, channels_table, members_table, members_table, members_table), { source_name })
    local context = load_context()
    local values = {}
    for index = 1, #rows do
        values[#values + 1] = rows[index].first_number
        values[#values + 1] = rows[index].second_number
    end
    ensure_number_maps(context, values, dry_run)
    local messages = {}
    local skipped = 0
    local replies = 0
    for index = 1, #rows do
        local row = rows[index]
        local sender_number = tostring(row.sender)
        local recipient_number = sender_number == tostring(row.first_number)
            and tostring(row.second_number)
            or tostring(row.first_number)
        local sender = context.number_map[sender_number]
        local recipient = context.number_map[recipient_number]
        if sender and recipient then
            local media_payload, message_type = first_attachment(row.attachments)
            messages[#messages + 1] = {
                deterministic_uuid("lb-phone-message", row.id),
                sender.sim_id,
                recipient.sim_id,
                sender.phone_number,
                recipient.phone_number,
                media_payload and message_type or "text",
                clamp_text(row.content, Config.Messages.BodyMaxLength),
                media_payload,
                row.migrated_at,
                row.migrated_at,
            }
            if row.reply_to then
                replies = replies + 1
            end
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_sms_messages`
                (`id`, `sender_sim_id`, `recipient_sim_id`, `sender_number`, `recipient_number`,
                    `message_type`, `body`, `media_payload`, `read_at`, `created_at`) VALUES
        ]], 10, messages)
    end
    local groups = tonumber((Bridge.Database.Query(
        ("SELECT COUNT(*) AS `count` FROM `%s` WHERE `is_group` = 1"):format(channels_table), {}
    )[1] or {}).count) or 0
    local reactions = count_rows(source_table("message_reactions"))
    return {
        source = #rows,
        imported = #messages,
        skipped = skipped,
        unsupported_group_channels = groups,
        unsupported_reactions = reactions,
        unsupported_replies = replies,
    }
end

local function run_photos(dry_run)
    local table_name = source_table("photos")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    if not table_has_column(table_name, "phone_number") or not table_has_column(table_name, "link") then
        return {
            source = count_rows(table_name),
            imported = 0,
            skipped = count_rows(table_name),
            unsupported_schema = table_name,
        }
    end
    local rows = Bridge.Database.Query(([[
        SELECT photo.*, owner.`account_id`,
            DATE_FORMAT(photo.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` photo
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = photo.`phone_number`
    ]]):format(table_name), { source_name })
    local media_rows = {}
    local skipped = 0
    for index = 1, #rows do
        local row = rows[index]
        local url = valid_media_url(row.link)
        if url then
            local key = deterministic_uuid("lb-phone-photo", row.id)
            media_rows[#media_rows + 1] = {
                row.account_id,
                url,
                "lb-photo:" .. key,
                (row.is_video == true or tonumber(row.is_video) == 1) and "video" or "photo",
                "website_import",
                "lb-photo:" .. key,
                row.migrated_at,
                (row.is_favourite == true or tonumber(row.is_favourite) == 1) and 1 or 0,
                row.migrated_at,
            }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_media`
                (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                    `verified_at`, `favorite`, `created_at`) VALUES
        ]], 9, media_rows)
    end
    return {
        source = #rows,
        imported = #media_rows,
        skipped = skipped,
        unsupported_albums = count_rows(source_table("photo_albums")),
    }
end

local function run_notes(dry_run)
    local table_name = source_table("notes")
    if not table_exists(table_name) then
        return { source = 0, imported = 0 }
    end
    if not table_has_column(table_name, "phone_number") or not table_has_column(table_name, "content") then
        return {
            source = count_rows(table_name),
            imported = 0,
            skipped = count_rows(table_name),
            unsupported_schema = table_name,
        }
    end
    local rows = Bridge.Database.Query(([[
        SELECT note.*, owner.`account_id`,
            DATE_FORMAT(note.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` note
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = note.`phone_number`
    ]]):format(table_name), { source_name })
    local notes = {}
    for index = 1, #rows do
        notes[#notes + 1] = {
            "lb-phone-note:" .. tostring(rows[index].id),
            rows[index].account_id,
            clamp_text(rows[index].title, 120),
            tostring(rows[index].content or ""),
            rows[index].migrated_at,
            rows[index].migrated_at,
        }
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_notes`
                (`id`, `account_id`, `title`, `body`, `created_at`, `updated_at`) VALUES
        ]], 6, notes)
    end
    return { source = #rows, imported = #notes }
end

local function run_wallet(dry_run)
    local table_name = source_table("wallet_transactions")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT transaction_row.*, owner.`owner_identifier`,
            DATE_FORMAT(transaction_row.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` transaction_row
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = transaction_row.`phone_number`
    ]]):format(table_name), { source_name })
    local transactions = {}
    local skipped = 0
    for index = 1, #rows do
        local row = rows[index]
        local amount = tonumber(row.amount) or 0
        if amount ~= 0 then
            transactions[#transactions + 1] = {
                row.owner_identifier,
                amount > 0 and "deposit" or "withdrawal",
                math.abs(amount),
                clamp_text(row.company, 160),
                "lb-phone-wallet:" .. tostring(row.id),
                row.migrated_at,
            }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        for index = 1, #transactions do
            local row = transactions[index]
            Bridge.Database.Query([[
                INSERT INTO `sky_phone_bank_transactions`
                    (`owner_identifier`, `kind`, `amount`, `label`, `reference`, `created_at`)
                SELECT ?, ?, ?, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM `sky_phone_bank_transactions`
                    WHERE `owner_identifier` = ? AND `reference` = ?
                )
            ]], { row[1], row[2], row[3], row[4], row[5], row[6], row[1], row[5] })
        end
    end
    return { source = #rows, imported = #transactions, skipped = skipped }
end

local function run_voice_memos(dry_run)
    local table_name = source_table("voice_memos_recordings")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT memo.*, owner.`account_id`,
            DATE_FORMAT(memo.`created_at`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` memo
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = memo.`phone_number`
    ]]):format(table_name), { source_name })
    local media_rows = {}
    local valid_rows = {}
    local skipped = 0
    for index = 1, #rows do
        local row = rows[index]
        local url = valid_media_url(row.file_url)
        if url then
            local key = deterministic_uuid("lb-phone-voice-memo", row.id)
            local source_id = "lb-memo:" .. key
            media_rows[#media_rows + 1] = {
                row.account_id,
                url,
                source_id,
                "audio",
                "website_import",
                source_id,
                row.migrated_at,
                row.migrated_at,
            }
            valid_rows[#valid_rows + 1] = { row = row, key = key, source_id = source_id }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_media`
                (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                    `verified_at`, `created_at`) VALUES
        ]], 8, media_rows)
        local media_ids = load_media_ids("lb-memo:%")
        local memo_rows = {}
        local waveform = json.encode({ 0.24, 0.42, 0.31, 0.56, 0.38, 0.48, 0.27, 0.36 })
        for index = 1, #valid_rows do
            local entry = valid_rows[index]
            local media_id = media_ids[entry.source_id]
            if media_id then
                memo_rows[#memo_rows + 1] = {
                    entry.key,
                    media_id,
                    clamp_text(entry.row.file_name, 120),
                    math.max(0, math.floor((tonumber(entry.row.file_length) or 0) * 1000)),
                    0,
                    waveform,
                    entry.row.migrated_at,
                    entry.row.migrated_at,
                }
            end
        end
        insert_many([[
            INSERT IGNORE INTO `sky_phone_voice_memos`
                (`id`, `media_id`, `title`, `duration_ms`, `size_bytes`, `waveform`,
                    `created_at`, `updated_at`) VALUES
        ]], 8, memo_rows)
    end
    return { source = #rows, imported = #valid_rows, skipped = skipped }
end

local function normalize_picstagram_handle(value)
    local handle = tostring(value or ""):lower():gsub("^@", ""):match("^%s*(.-)%s*$")
    if #handle < 3
        or #handle > 24
        or not handle:match("^[a-z0-9][a-z0-9._]*[a-z0-9]$")
        or handle:find("..", 1, true)
    then
        return nil
    end
    return handle
end

local function extract_media(value, maximum)
    local decoded = decode_json(value)
    local result = {}
    for index = 1, math.min(#decoded, maximum) do
        local entry = decoded[index]
        local url
        local media_type = "photo"
        if type(entry) == "string" then
            url = valid_media_url(entry)
        elseif type(entry) == "table" then
            url = valid_media_url(entry.url or entry.src or entry.link)
            local raw_type = tostring(entry.type or entry.mediaType or "photo"):lower()
            if raw_type:find("video", 1, true) then
                media_type = "video"
            end
        end
        if url then
            result[#result + 1] = { url = url, media_type = media_type }
        end
    end
    return result
end

local function social_login_table_available(table_name)
    return table_exists(table_name)
        and table_has_column(table_name, "phone_number")
        and table_has_column(table_name, "app")
        and table_has_column(table_name, "username")
        and table_has_column(table_name, "active")
end

local function prepare_social_profile_accounts(entries, options)
    local profile_table = tostring(options.profile_table or "")
    if not profile_table:match("^[%w_]+$") then
        error("[sky_phone] Invalid social migration profile table.")
    end

    local preferred = {}
    local logged_table = source_table("logged_in_accounts")
    if social_login_table_available(logged_table) then
        local app_placeholders = {}
        local parameters = { source_name }
        for index = 1, #options.apps do
            app_placeholders[index] = "?"
            parameters[#parameters + 1] = tostring(options.apps[index]):lower()
        end
        local logged = Bridge.Database.Query(([[
            SELECT LOWER(login.`username`) AS `username`, owner.`account_id`
            FROM `%s` login
            JOIN `sky_phone_migration_owners` owner
                ON owner.`source` = ? AND owner.`source_phone_number` = login.`phone_number`
            WHERE login.`active` = 1 AND LOWER(login.`app`) IN (%s)
            ORDER BY owner.`account_id`, login.`phone_number`, login.`username`
        ]]):format(logged_table, table.concat(app_placeholders, ",")), parameters)
        for index = 1, #logged do
            local account_id = tonumber(logged[index].account_id)
            if account_id then
                preferred[account_id] = preferred[account_id]
                    or tostring(logged[index].username or ""):lower()
            end
        end
    end
    for index = 1, #entries do
        local owner_account_id = tonumber(entries[index].source.owner_account_id)
        if owner_account_id then
            preferred[owner_account_id] = preferred[owner_account_id]
                or tostring(entries[index].source.username or ""):lower()
        end
    end

    local cloud_rows = {}
    for index = 1, #entries do
        local entry = entries[index]
        entry.email = synthetic_email(options.synthetic_namespace, entry.handle)
        cloud_rows[#cloud_rows + 1] = {
            entry.email,
            deterministic_hex(options.account_namespace, entry.handle),
        }
    end
    insert_many("INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES", 2, cloud_rows)

    local target_accounts = Bridge.Database.Query("SELECT `id`, `email` FROM `sky_phone_accounts`", {})
    local account_by_email = {}
    local email_by_account = {}
    for index = 1, #target_accounts do
        local account_id = tonumber(target_accounts[index].id)
        local email = tostring(target_accounts[index].email or ""):lower()
        account_by_email[email] = account_id
        email_by_account[account_id] = email
    end
    for index = 1, #entries do
        entries[index].synthetic_account_id = account_by_email[entries[index].email]
    end

    local target_profiles = Bridge.Database.Query(([[
        SELECT profile.`id`, profile.`account_id`, profile.`handle`, account.`email` AS `account_email`
        FROM `%s` profile
        JOIN `sky_phone_accounts` account ON account.`id` = profile.`account_id`
    ]]):format(profile_table), {})
    local existing_by_handle = {}
    local occupied_accounts = {}
    for index = 1, #target_profiles do
        local profile = target_profiles[index]
        profile.account_id = tonumber(profile.account_id)
        profile.account_email = tostring(profile.account_email or ""):lower()
        existing_by_handle[tostring(profile.handle or ""):lower()] = profile
        occupied_accounts[profile.account_id] = profile
    end

    local entry_by_handle = {}
    local preferred_entry_by_owner = {}
    for index = 1, #entries do
        local entry = entries[index]
        entry_by_handle[entry.handle] = entry
        local owner_account_id = tonumber(entry.source.owner_account_id)
        if owner_account_id
            and preferred[owner_account_id] == tostring(entry.source.username or ""):lower()
        then
            preferred_entry_by_owner[owner_account_id] = entry
        end
    end

    local function is_imported_profile(profile, entry)
        if not profile or not entry then
            return false
        end
        if entry.profile_id and tostring(profile.id) == tostring(entry.profile_id) then
            return true
        end
        if profile.account_email == entry.email then
            return true
        end
        return tonumber(profile.account_id) == tonumber(entry.source.owner_account_id)
    end

    local repaired = 0
    local function move_profile(profile, entry, target_account_id)
        local previous_account_id = tonumber(profile.account_id)
        target_account_id = tonumber(target_account_id)
        if not previous_account_id or not target_account_id or previous_account_id == target_account_id then
            return true
        end
        if occupied_accounts[target_account_id] then
            return false
        end
        local moved = affected_rows(Bridge.Database.Query(([[
            UPDATE `%s` SET `account_id` = ? WHERE `id` = ? AND `account_id` = ?
        ]]):format(profile_table), { target_account_id, profile.id, previous_account_id }))
        if moved < 1 then
            return false
        end
        Bridge.Database.Query([[
            UPDATE `sky_phone_media` SET `account_id` = ?
            WHERE `account_id` = ? AND `origin` = 'website_import' AND `source_id` LIKE ?
        ]], { target_account_id, previous_account_id, options.media_pattern })
        occupied_accounts[previous_account_id] = nil
        occupied_accounts[target_account_id] = profile
        profile.account_id = target_account_id
        profile.account_email = email_by_account[target_account_id] or ""
        repaired = repaired + 1
        return true
    end

    -- If the active LB profile changed since a previous import, first move the
    -- old imported profile back to its deterministic cloud account.
    for owner_account_id, preferred_entry in pairs(preferred_entry_by_owner) do
        local occupant = occupied_accounts[owner_account_id]
        if occupant and tostring(occupant.handle or ""):lower() ~= preferred_entry.handle then
            local occupant_entry = entry_by_handle[tostring(occupant.handle or ""):lower()]
            if occupant_entry
                and tonumber(occupant_entry.source.owner_account_id) == owner_account_id
                and is_imported_profile(occupant, occupant_entry)
            then
                move_profile(occupant, occupant_entry, occupant_entry.synthetic_account_id)
            end
        end
    end

    local owner_assigned = {}
    for owner_account_id, preferred_entry in pairs(preferred_entry_by_owner) do
        local existing = existing_by_handle[preferred_entry.handle]
        local occupant = occupied_accounts[owner_account_id]
        if not occupant or occupant == existing then
            if not existing
                or tonumber(existing.account_id) == owner_account_id
                or (is_imported_profile(existing, preferred_entry)
                    and move_profile(existing, preferred_entry, owner_account_id))
            then
                owner_assigned[preferred_entry] = true
            end
        end
    end

    local accepted = {}
    local skipped = 0
    for index = 1, #entries do
        local entry = entries[index]
        local desired_account_id = owner_assigned[entry]
            and tonumber(entry.source.owner_account_id)
            or entry.synthetic_account_id
        local existing = existing_by_handle[entry.handle]
        if not desired_account_id then
            skipped = skipped + 1
        elseif existing then
            if tonumber(existing.account_id) == desired_account_id
                and is_imported_profile(existing, entry)
            then
                entry.account_id = desired_account_id
                accepted[#accepted + 1] = entry
            else
                skipped = skipped + 1
            end
        elseif occupied_accounts[desired_account_id] then
            skipped = skipped + 1
        else
            entry.account_id = desired_account_id
            accepted[#accepted + 1] = entry
            occupied_accounts[desired_account_id] = { pending = true, handle = entry.handle }
        end
    end
    return accepted, skipped, repaired
end

local function run_picstagram(dry_run)
    local accounts_table = source_table("instagram_accounts")
    if not table_exists(accounts_table) then
        return { source = 0, profiles = 0, skipped = 0 }
    end
    local source_accounts = Bridge.Database.Query(([[
        SELECT account.*, owner.`account_id` AS `owner_account_id`, owner.`device_imei`,
            DATE_FORMAT(account.`date_joined`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` account
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = account.`phone_number`
        ORDER BY account.`date_joined`, account.`phone_number`, account.`username`
    ]]):format(accounts_table), { source_name })

    local entries = {}
    local skipped = 0
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local handle = normalize_picstagram_handle(row.username)
        if handle then
            local profile_id = deterministic_uuid("lb-phone-picstagram-profile", handle)
            entries[#entries + 1] = {
                source = row,
                handle = handle,
                profile_id = profile_id,
            }
        else
            skipped = skipped + 1
        end
    end
    if dry_run then
        return {
            source = #source_accounts,
            profiles = #entries,
            skipped = skipped,
            posts = count_rows(source_table("instagram_posts")),
            comments = count_rows(source_table("instagram_comments")),
            follows = count_rows(source_table("instagram_follows")),
            stories = count_rows(source_table("instagram_stories")),
        }
    end

    local accepted, assignment_skipped, ownership_repaired = prepare_social_profile_accounts(entries, {
        profile_table = "sky_phone_picstagram_profiles",
        synthetic_namespace = "ig",
        account_namespace = "lb-phone-picstagram-account",
        media_pattern = "lb-ig-%",
        apps = { "instagram", "instapic", "picstagram" },
    })
    entries = accepted
    skipped = skipped + assignment_skipped

    local avatar_rows = {}
    for index = 1, #entries do
        local entry = entries[index]
        local avatar = valid_media_url(entry.source.profile_image)
        if entry.account_id and avatar then
            entry.avatar_source = "lb-ig-avatar:" .. entry.profile_id
            avatar_rows[#avatar_rows + 1] = {
                entry.account_id,
                avatar,
                entry.avatar_source,
                "photo",
                "website_import",
                entry.avatar_source,
                entry.source.migrated_at,
                entry.source.migrated_at,
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, avatar_rows)
    local avatar_ids = load_media_ids("lb-ig-avatar:%")
    local profile_rows = {}
    local profile_by_username = {}
    for index = 1, #entries do
        local entry = entries[index]
        if entry.account_id then
            entry.avatar_media_id = entry.avatar_source and avatar_ids[entry.avatar_source] or nil
            profile_rows[#profile_rows + 1] = {
                entry.profile_id,
                entry.account_id,
                entry.handle,
                clamp_text(entry.source.display_name ~= "" and entry.source.display_name or entry.handle, 40),
                clamp_text(entry.source.bio, Config.Picstagram.BioMaxLength),
                entry.avatar_media_id,
                (entry.source.private == true or tonumber(entry.source.private) == 1) and 1 or 0,
                (entry.source.verified == true or tonumber(entry.source.verified) == 1) and 1 or 0,
                entry.source.migrated_at,
            }
            profile_by_username[tostring(entry.source.username):lower()] = entry
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_profiles`
            (`id`, `account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`, `private`,
                `verified`, `created_at`) VALUES
    ]], 9, profile_rows)

    local password_pepper = tostring(Config.Server.PicstagramPasswordPepper or "")
    for index = 1, #entries do
        local entry = entries[index]
        if entry.account_id then
            local salt = deterministic_hex("lb-phone-picstagram-salt", entry.handle)
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_picstagram_credentials`
                    (`profile_id`, `password_hash`, `password_salt`)
                VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?)
            ]], { entry.profile_id, password_pepper, salt, tostring(entry.source.password or ""), salt })
        end
    end

    local session_candidates = {}
    local logged_table = source_table("logged_in_accounts")
    if social_login_table_available(logged_table) then
        local logged = Bridge.Database.Query(([[
            SELECT login.`phone_number`, login.`username`, owner.`device_imei`
            FROM `%s` login
            JOIN `sky_phone_migration_owners` owner
                ON owner.`source` = ? AND owner.`source_phone_number` = login.`phone_number`
            WHERE login.`active` = 1
                AND LOWER(login.`app`) IN ('instagram', 'instapic', 'picstagram')
        ]]):format(logged_table), { source_name })
        for index = 1, #logged do
            local profile = profile_by_username[tostring(logged[index].username):lower()]
            if profile then
                session_candidates[tostring(logged[index].device_imei)] = profile.profile_id
            end
        end
    end
    local profiles_by_device = {}
    for index = 1, #entries do
        local entry = entries[index]
        local imei = tostring(entry.source.device_imei)
        profiles_by_device[imei] = profiles_by_device[imei] or {}
        profiles_by_device[imei][#profiles_by_device[imei] + 1] = entry.profile_id
    end
    for imei, profiles in pairs(profiles_by_device) do
        if not session_candidates[imei] and #profiles == 1 then
            session_candidates[imei] = profiles[1]
        end
    end
    local session_rows = {}
    for imei, profile_id in pairs(session_candidates) do
        session_rows[#session_rows + 1] = { imei, profile_id }
    end
    insert_many([[
        INSERT INTO `sky_phone_picstagram_sessions` (`device_imei`, `profile_id`) VALUES
    ]], 2, session_rows, [[
        ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP
    ]])

    local posts_table = source_table("instagram_posts")
    local post_entries = {}
    local post_media_rows = {}
    if table_exists(posts_table) then
        local posts = Bridge.Database.Query(([[
            SELECT post.*,
                DATE_FORMAT(post.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` post
        ]]):format(posts_table), {})
        for index = 1, #posts do
            local row = posts[index]
            local profile = profile_by_username[tostring(row.username):lower()]
            local media = extract_media(row.media, Config.Picstagram.MaxPostMedia)
            if profile and #media > 0 then
                local post_id = deterministic_uuid("lb-phone-picstagram-post", row.id)
                post_entries[tostring(row.id)] = { id = post_id, profile = profile }
                for position = 1, #media do
                    local source_id = "lb-ig-post:" .. deterministic_uuid(
                        "lb-phone-picstagram-post-media",
                        tostring(row.id) .. ":" .. position
                    )
                    media[position].source_id = source_id
                    post_media_rows[#post_media_rows + 1] = {
                        profile.account_id,
                        media[position].url,
                        source_id,
                        media[position].media_type,
                        "website_import",
                        source_id,
                        row.migrated_at,
                        row.migrated_at,
                    }
                end
                post_entries[tostring(row.id)].media = media
                post_entries[tostring(row.id)].row = row
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, post_media_rows)
    local media_ids = load_media_ids("lb-ig-post:%")
    local post_rows = {}
    for _, entry in pairs(post_entries) do
        post_rows[#post_rows + 1] = {
            entry.id,
            entry.profile.profile_id,
            clamp_text(entry.row.caption, Config.Picstagram.CaptionMaxLength),
            clamp_text(entry.row.location, Config.Picstagram.LocationMaxLength),
            entry.row.migrated_at,
            entry.row.migrated_at,
        }
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_posts`
            (`id`, `profile_id`, `caption`, `location`, `created_at`, `updated_at`) VALUES
    ]], 6, post_rows)
    local post_media_links = {}
    for _, entry in pairs(post_entries) do
        for position = 1, #entry.media do
            local media_id = media_ids[entry.media[position].source_id]
            if media_id then
                post_media_links[#post_media_links + 1] = { entry.id, media_id, position - 1 }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_post_media` (`post_id`, `media_id`, `position`) VALUES
    ]], 3, post_media_links)

    local comment_entries = {}
    local comments_table = source_table("instagram_comments")
    if table_exists(comments_table) then
        local rows = Bridge.Database.Query(([[
            SELECT comment.*,
                DATE_FORMAT(comment.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` comment
        ]]):format(comments_table), {})
        for index = 1, #rows do
            local post = post_entries[tostring(rows[index].post_id)]
            local profile = profile_by_username[tostring(rows[index].username):lower()]
            if post and profile then
                local comment_id = deterministic_uuid("lb-phone-picstagram-comment", rows[index].id)
                comment_entries[tostring(rows[index].id)] = comment_id
                Bridge.Database.Query([[
                    INSERT IGNORE INTO `sky_phone_picstagram_comments`
                        (`id`, `post_id`, `profile_id`, `body`, `created_at`)
                    VALUES (?, ?, ?, ?, ?)
                ]], {
                    comment_id,
                    post.id,
                    profile.profile_id,
                    clamp_text(rows[index].comment, Config.Picstagram.CommentMaxLength),
                    rows[index].migrated_at,
                })
            end
        end
    end

    local likes_table = source_table("instagram_likes")
    if table_exists(likes_table) then
        local likes = Bridge.Database.Query(("SELECT * FROM `%s`"):format(likes_table), {})
        local post_likes = {}
        local comment_likes = {}
        for index = 1, #likes do
            local profile = profile_by_username[tostring(likes[index].username):lower()]
            if profile and (likes[index].is_comment == true or tonumber(likes[index].is_comment) == 1) then
                local comment_id = comment_entries[tostring(likes[index].id)]
                if comment_id then
                    comment_likes[#comment_likes + 1] = { comment_id, profile.profile_id }
                end
            elseif profile then
                local post = post_entries[tostring(likes[index].id)]
                if post then
                    post_likes[#post_likes + 1] = { post.id, profile.profile_id, "like" }
                end
            end
        end
        insert_many([[
            INSERT IGNORE INTO `sky_phone_picstagram_reactions` (`post_id`, `profile_id`, `kind`) VALUES
        ]], 3, post_likes)
        insert_many([[
            INSERT IGNORE INTO `sky_phone_picstagram_comment_reactions` (`comment_id`, `profile_id`) VALUES
        ]], 2, comment_likes)
    end

    local follow_rows = {}
    local follows_table = source_table("instagram_follows")
    if table_exists(follows_table) then
        local follows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(follows_table), {})
        for index = 1, #follows do
            local follower = profile_by_username[tostring(follows[index].follower):lower()]
            local following = profile_by_username[tostring(follows[index].followed):lower()]
            if follower and following and follower.profile_id ~= following.profile_id then
                follow_rows[#follow_rows + 1] = {
                    follower.profile_id,
                    following.profile_id,
                    "accepted",
                    follower.source.migrated_at,
                }
            end
        end
    end
    local requests_table = source_table("instagram_follow_requests")
    local activity_rows = {}
    if table_exists(requests_table) then
        local requests = Bridge.Database.Query(([[
            SELECT request.*,
                DATE_FORMAT(request.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` request
        ]]):format(requests_table), {})
        for index = 1, #requests do
            local requester = profile_by_username[tostring(requests[index].requester):lower()]
            local requestee = profile_by_username[tostring(requests[index].requestee):lower()]
            if requester and requestee and requester.profile_id ~= requestee.profile_id then
                follow_rows[#follow_rows + 1] = {
                    requester.profile_id, requestee.profile_id, "pending", requests[index].migrated_at,
                }
                activity_rows[#activity_rows + 1] = {
                    deterministic_uuid(
                        "lb-phone-picstagram-follow-request",
                        tostring(requests[index].requester) .. ":" .. tostring(requests[index].requestee)
                    ),
                    requestee.profile_id,
                    requester.profile_id,
                    "follow_request",
                    requests[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_follows`
            (`follower_id`, `following_id`, `status`, `created_at`) VALUES
    ]], 4, follow_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_activities`
            (`id`, `recipient_id`, `actor_id`, `kind`, `created_at`) VALUES
    ]], 5, activity_rows)

    local story_entries = {}
    local story_media_rows = {}
    local stories_table = source_table("instagram_stories")
    if table_exists(stories_table) then
        local stories = Bridge.Database.Query(([[
            SELECT story.*,
                DATE_FORMAT(story.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` story
        ]]):format(stories_table), {})
        for index = 1, #stories do
            local profile = profile_by_username[tostring(stories[index].username):lower()]
            local url = valid_media_url(stories[index].image)
            if profile and url then
                local story_id = deterministic_uuid("lb-phone-picstagram-story", stories[index].id)
                local source_id = "lb-ig-story:" .. story_id
                story_entries[tostring(stories[index].id)] = {
                    id = story_id,
                    profile = profile,
                    source_id = source_id,
                    timestamp = stories[index].migrated_at,
                }
                story_media_rows[#story_media_rows + 1] = {
                    profile.account_id, url, source_id, "photo", "website_import", source_id,
                    stories[index].migrated_at, stories[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, story_media_rows)
    local story_media_ids = load_media_ids("lb-ig-story:%")
    for _, story in pairs(story_entries) do
        local media_id = story_media_ids[story.source_id]
        if media_id then
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_picstagram_stories`
                    (`id`, `profile_id`, `media_id`, `expires_at`, `created_at`)
                VALUES (?, ?, ?, DATE_ADD(?, INTERVAL ? SECOND), ?)
            ]], {
                story.id,
                story.profile.profile_id,
                media_id,
                story.timestamp,
                Config.Picstagram.StoryLifetimeSeconds,
                story.timestamp,
            })
        end
    end
    local views_table = source_table("instagram_stories_views")
    local view_rows = {}
    if table_exists(views_table) then
        local views = Bridge.Database.Query(([[
            SELECT story_view.*,
                DATE_FORMAT(story_view.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` story_view
        ]]):format(views_table), {})
        for index = 1, #views do
            local story = story_entries[tostring(views[index].story_id)]
            local viewer = profile_by_username[tostring(views[index].viewer):lower()]
            if story and viewer then
                view_rows[#view_rows + 1] = { story.id, viewer.profile_id, views[index].migrated_at }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_picstagram_story_views` (`story_id`, `profile_id`, `created_at`) VALUES
    ]], 3, view_rows)

    return {
        source = #source_accounts,
        profiles = #profile_rows,
        sessions = #session_rows,
        posts = #post_rows,
        post_media = #post_media_links,
        comments = count_rows(comments_table),
        follows = #follow_rows,
        stories = count_rows(stories_table),
        story_views = #view_rows,
        ownership_repaired = ownership_repaired,
        skipped = skipped,
        unsupported_messages = count_rows(source_table("instagram_messages")),
        unsupported_notifications = count_rows(source_table("instagram_notifications")),
    }
end

local function valid_legacy_email(value)
    if type(value) ~= "string" then
        return nil
    end
    local address = value:lower():match("^%s*(.-)%s*$")
    if #address < 3 or #address > 64 or address:find("[^%w%._%+%-@]") then
        return nil
    end
    if not address:match("^[^@]+@[^@]+%.[^@]+$") then
        return nil
    end
    return address
end

local function normalize_social_handle(value, maximum, allow_dot)
    local handle = tostring(value or ""):lower():gsub("^@", ""):match("^%s*(.-)%s*$")
    local pattern = allow_dot and "^[a-z0-9][a-z0-9._]*[a-z0-9]$" or "^[a-z0-9][a-z0-9_]*[a-z0-9]$"
    if #handle < 3 or #handle > maximum or not handle:match(pattern) then
        return nil
    end
    if allow_dot and handle:find("..", 1, true) then
        return nil
    end
    return handle
end

local function run_mail(dry_run)
    local accounts_table = source_table("mail_accounts")
    local messages_table = source_table("mail_messages")
    local logged_table = source_table("logged_in_accounts")
    if not table_exists(accounts_table) or not table_exists(messages_table) or not table_exists(logged_table) then
        return { source = 0, mailboxes = 0, messages = 0, entries = 0, skipped = 0 }
    end
    if not table_has_column(accounts_table, "address")
        or not table_has_column(messages_table, "recipient")
        or not table_has_column(messages_table, "sender")
    then
        return {
            source = count_rows(messages_table),
            mailboxes = 0,
            messages = 0,
            entries = 0,
            skipped = count_rows(messages_table),
            unsupported_schema = accounts_table,
        }
    end

    local links = Bridge.Database.Query(([[
        SELECT login.`username` AS `address`, owner.`account_id`, owner.`device_imei`
        FROM `%s` login
        JOIN `%s` mailbox ON LOWER(mailbox.`address`) = LOWER(login.`username`)
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = login.`phone_number`
        WHERE LOWER(login.`app`) IN ('mail', 'email')
    ]]):format(logged_table, accounts_table), { source_name })
    local mailbox_accounts = {}
    local linked_accounts = {}
    for index = 1, #links do
        local address = tostring(links[index].address or ""):lower()
        local account_id = tonumber(links[index].account_id)
        if address ~= "" and account_id then
            mailbox_accounts[address] = mailbox_accounts[address] or {}
            if not mailbox_accounts[address][account_id] then
                mailbox_accounts[address][account_id] = true
                linked_accounts[#linked_accounts + 1] = { address = address, account_id = account_id }
            end
        end
    end

    local source_messages = Bridge.Database.Query(([[
        SELECT message.*,
            DATE_FORMAT(message.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` message
    ]]):format(messages_table), {})
    local relevant = {}
    local sender_addresses = {}
    local skipped = 0
    local unsupported_payloads = 0
    for index = 1, #source_messages do
        local row = source_messages[index]
        local sender = tostring(row.sender or ""):lower()
        local recipient = tostring(row.recipient or ""):lower()
        if mailbox_accounts[sender] or mailbox_accounts[recipient] then
            row.sender_address = sender
            row.recipient_address = recipient
            relevant[#relevant + 1] = row
            sender_addresses[sender] = true
            if next(decode_json(row.attachments)) or next(decode_json(row.actions)) then
                unsupported_payloads = unsupported_payloads + 1
            end
        else
            skipped = skipped + 1
        end
    end
    if dry_run then
        return {
            source = #source_messages,
            mailboxes = #linked_accounts,
            messages = #relevant,
            entries = 0,
            skipped = skipped,
            unsupported_payloads = unsupported_payloads,
        }
    end

    local account_rows = {}
    local source_email = {}
    for address in pairs(sender_addresses) do
        local email = valid_legacy_email(address) or synthetic_email("mail", address)
        source_email[address] = email
        account_rows[#account_rows + 1] = {
            email,
            deterministic_hex("lb-phone-mail-account", address),
        }
    end
    insert_many("INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES", 2, account_rows)
    local target_accounts = Bridge.Database.Query("SELECT `id`, `email` FROM `sky_phone_accounts`", {})
    local account_by_email = {}
    for index = 1, #target_accounts do
        account_by_email[tostring(target_accounts[index].email):lower()] = tonumber(target_accounts[index].id)
    end

    local deleted = {}
    local deleted_table = source_table("mail_deleted")
    if table_exists(deleted_table) then
        local deleted_rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(deleted_table), {})
        for index = 1, #deleted_rows do
            local key = tostring(deleted_rows[index].message_id) .. ":" .. tostring(deleted_rows[index].address):lower()
            deleted[key] = true
        end
    end

    local message_rows = {}
    local entry_rows = {}
    for index = 1, #relevant do
        local row = relevant[index]
        local sender_account_id = account_by_email[source_email[row.sender_address]]
        if sender_account_id then
            local message_id = deterministic_uuid("lb-phone-mail-message", row.id)
            message_rows[#message_rows + 1] = {
                message_id,
                sender_account_id,
                json.encode({ row.recipient_address }),
                clamp_text(row.subject, 120),
                tostring(row.content or ""),
                row.migrated_at,
            }
            local sent_accounts = mailbox_accounts[row.sender_address] or {}
            for account_id in pairs(sent_accounts) do
                local trash_key = tostring(row.id) .. ":" .. row.sender_address
                entry_rows[#entry_rows + 1] = {
                    message_id, account_id, "sent", nil, nil,
                    deleted[trash_key] and row.migrated_at or nil,
                }
            end
            local recipient_accounts = mailbox_accounts[row.recipient_address] or {}
            for account_id in pairs(recipient_accounts) do
                local trash_key = tostring(row.id) .. ":" .. row.recipient_address
                entry_rows[#entry_rows + 1] = {
                    message_id, account_id, "inbox", nil,
                    (row.read == true or tonumber(row.read) == 1) and row.migrated_at or nil,
                    deleted[trash_key] and row.migrated_at or nil,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_mail_messages`
            (`id`, `sender_account_id`, `recipients`, `subject`, `body`, `created_at`) VALUES
    ]], 6, message_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_mail_entries`
            (`message_id`, `account_id`, `folder`, `mailbox_id`, `read_at`, `trashed_at`) VALUES
    ]], 6, entry_rows)
    return {
        source = #source_messages,
        mailboxes = #linked_accounts,
        messages = #message_rows,
        entries = #entry_rows,
        skipped = skipped,
        unsupported_payloads = unsupported_payloads,
    }
end

local function run_map_markers(dry_run)
    local table_name = source_table("maps_locations")
    if not table_exists(table_name) then
        return { source = 0, imported = 0, skipped = 0 }
    end
    local rows = Bridge.Database.Query(([[
        SELECT location.*, owner.`device_imei`
        FROM `%s` location
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = location.`phone_number`
    ]]):format(table_name), { source_name })
    local valid = {}
    local skipped = 0
    for index = 1, #rows do
        local x = tonumber(rows[index].x_pos)
        local y = tonumber(rows[index].y_pos)
        local label = clamp_text(rows[index].name, 40):match("^%s*(.-)%s*$")
        if x and y and label ~= "" and math.abs(x) <= 10000 and math.abs(y) <= 10000 then
            valid[#valid + 1] = {
                deterministic_uuid("lb-phone-map-marker", rows[index].id),
                rows[index].device_imei,
                label,
                "blue",
                x,
                y,
                0,
            }
        else
            skipped = skipped + 1
        end
    end
    if not dry_run then
        insert_many([[
            INSERT IGNORE INTO `sky_phone_map_markers`
                (`id`, `device_imei`, `label`, `color`, `position_x`, `position_y`, `position_z`) VALUES
        ]], 7, valid)
    end
    return { source = #rows, imported = #valid, skipped = skipped }
end

local function run_dark_chat(dry_run)
    local accounts_table = source_table("darkchat_accounts")
    local channels_table = source_table("darkchat_channels")
    local members_table = source_table("darkchat_members")
    local messages_table = source_table("darkchat_messages")
    if not table_exists(accounts_table) or not table_exists(channels_table)
        or not table_exists(members_table) or not table_exists(messages_table)
    then
        return { source = 0, profiles = 0, conversations = 0, messages = 0, skipped = 0 }
    end

    local source_accounts = Bridge.Database.Query(([[
        SELECT account.*, owner.`account_id` AS `owner_account_id`, owner.`device_imei`
        FROM `%s` account
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = account.`phone_number`
        ORDER BY account.`phone_number`, account.`username`
    ]]):format(accounts_table), { source_name })
    local preferred = {}
    local logged_table = source_table("logged_in_accounts")
    if table_exists(logged_table) then
        local logged = Bridge.Database.Query(([[
            SELECT login.`username`, owner.`account_id`
            FROM `%s` login
            JOIN `sky_phone_migration_owners` owner
                ON owner.`source` = ? AND owner.`source_phone_number` = login.`phone_number`
            WHERE login.`active` = 1 AND LOWER(login.`app`) IN ('darkchat', 'dark_chat')
        ]]):format(logged_table), { source_name })
        for index = 1, #logged do
            local account_id = tonumber(logged[index].account_id)
            if account_id then
                preferred[account_id] = tostring(logged[index].username):lower()
            end
        end
    end
    for index = 1, #source_accounts do
        local account_id = tonumber(source_accounts[index].owner_account_id)
        if account_id then
            preferred[account_id] = preferred[account_id] or tostring(source_accounts[index].username):lower()
        end
    end

    if dry_run then
        return {
            source = #source_accounts,
            profiles = #source_accounts,
            conversations = count_rows(channels_table),
            messages = count_rows(messages_table),
            skipped = 0,
        }
    end

    local existing_owner_profiles = Bridge.Database.Query(
        "SELECT `account_id`, `dark_id` FROM `sky_phone_darkchat_profiles`", {}
    )
    local occupied_accounts = {}
    local existing_by_dark_id = {}
    for index = 1, #existing_owner_profiles do
        occupied_accounts[tonumber(existing_owner_profiles[index].account_id)] = true
        existing_by_dark_id[tostring(existing_owner_profiles[index].dark_id)] = existing_owner_profiles[index]
    end
    local cloud_accounts = {}
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local owner_account_id = tonumber(row.owner_account_id)
        local entropy = deterministic_hex("lb-phone-darkchat-profile", row.username):upper()
        row.dark_id = ("dark:%s-%s"):format(entropy:sub(1, 4), entropy:sub(5, 8))
        row.profile_entropy = entropy
        local existing = existing_by_dark_id[row.dark_id]
        local use_owner = owner_account_id
            and preferred[owner_account_id] == tostring(row.username):lower()
            and not occupied_accounts[owner_account_id]
        if existing then
            row.target_account_id = tonumber(existing.account_id)
        elseif use_owner then
            row.target_account_id = owner_account_id
            occupied_accounts[owner_account_id] = true
        else
            row.target_email = synthetic_email("dark", row.username)
            cloud_accounts[#cloud_accounts + 1] = {
                row.target_email,
                deterministic_hex("lb-phone-darkchat-account", row.username),
            }
        end
    end
    insert_many("INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES", 2, cloud_accounts)
    local all_accounts = Bridge.Database.Query("SELECT `id`, `email` FROM `sky_phone_accounts`", {})
    local account_by_email = {}
    for index = 1, #all_accounts do
        account_by_email[tostring(all_accounts[index].email):lower()] = tonumber(all_accounts[index].id)
    end

    local profile_rows = {}
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        row.target_account_id = row.target_account_id or account_by_email[row.target_email]
        if row.target_account_id then
            local entropy = row.profile_entropy
            row.invite_code = ("DC-%s-%s"):format(entropy:sub(9, 12), entropy:sub(13, 16))
            profile_rows[#profile_rows + 1] = {
                row.target_account_id,
                row.dark_id,
                row.invite_code,
                clamp_text(row.username, 32),
                tonumber(entropy:sub(17, 23), 16) or 1,
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_darkchat_profiles`
            (`account_id`, `dark_id`, `invite_code`, `alias`, `avatar_seed`) VALUES
    ]], 5, profile_rows)
    local target_profiles = Bridge.Database.Query(
        "SELECT `id`, `account_id`, `dark_id` FROM `sky_phone_darkchat_profiles`", {}
    )
    local profile_by_account = {}
    for index = 1, #target_profiles do
        profile_by_account[tonumber(target_profiles[index].account_id)] = tonumber(target_profiles[index].id)
    end
    local profile_by_username = {}
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local profile_id = profile_by_account[row.target_account_id]
        if profile_id then
            profile_by_username[tostring(row.username):lower()] = profile_id
        end
    end

    local channels = Bridge.Database.Query(([[
        SELECT channel.`name`, channel.`password`,
            COUNT(DISTINCT member.`username`) AS `member_count`,
            COALESCE(
                DATE_FORMAT(MIN(message.`timestamp`), '%%Y-%%m-%%d %%H:%%i:%%s'),
                DATE_FORMAT(CURRENT_TIMESTAMP, '%%Y-%%m-%%d %%H:%%i:%%s')
            ) AS `first_at`,
            COALESCE(
                DATE_FORMAT(MAX(message.`timestamp`), '%%Y-%%m-%%d %%H:%%i:%%s'),
                DATE_FORMAT(CURRENT_TIMESTAMP, '%%Y-%%m-%%d %%H:%%i:%%s')
            ) AS `last_at`
        FROM `%s` channel
        LEFT JOIN `%s` member ON member.`channel_name` = channel.`name`
        LEFT JOIN `%s` message ON message.`channel` = channel.`name`
        GROUP BY channel.`name`, channel.`password`
    ]]):format(channels_table, members_table, messages_table), {})
    local member_rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(members_table), {})
    local members_by_channel = {}
    for index = 1, #member_rows do
        local name = tostring(member_rows[index].channel_name)
        members_by_channel[name] = members_by_channel[name] or {}
        members_by_channel[name][#members_by_channel[name] + 1] = tostring(member_rows[index].username)
    end
    local conversation_by_channel = {}
    local conversation_rows = {}
    local target_member_rows = {}
    local contact_rows = {}
    local unsupported_groups = 0
    local private_channels = 0
    for index = 1, #channels do
        local channel = channels[index]
        local usernames = members_by_channel[tostring(channel.name)] or {}
        local first_profile
        local second_profile
        if tonumber(channel.member_count) == 2 and #usernames == 2 then
            first_profile = profile_by_username[usernames[1]:lower()]
            second_profile = profile_by_username[usernames[2]:lower()]
        end
        if first_profile and second_profile and first_profile ~= second_profile then
            local conversation_id = deterministic_uuid("lb-phone-darkchat-conversation", channel.name)
            conversation_by_channel[tostring(channel.name)] = conversation_id
            local first_at = channel.first_at or channel.last_at
            local last_at = channel.last_at or first_at
            conversation_rows[#conversation_rows + 1] = {
                conversation_id, 0, first_at, last_at,
            }
            target_member_rows[#target_member_rows + 1] = { conversation_id, first_profile, first_at }
            target_member_rows[#target_member_rows + 1] = { conversation_id, second_profile, first_at }
            contact_rows[#contact_rows + 1] = { first_profile, second_profile }
            contact_rows[#contact_rows + 1] = { second_profile, first_profile }
            if channel.password and tostring(channel.password) ~= "" then
                private_channels = private_channels + 1
            end
        else
            unsupported_groups = unsupported_groups + 1
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_darkchat_conversations`
            (`id`, `disappearing_seconds`, `created_at`, `updated_at`) VALUES
    ]], 4, conversation_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_darkchat_members`
            (`conversation_id`, `profile_id`, `joined_at`) VALUES
    ]], 3, target_member_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_darkchat_contacts`
            (`profile_id`, `contact_profile_id`) VALUES
    ]], 2, contact_rows)

    local messages = Bridge.Database.Query(([[
        SELECT message.*,
            DATE_FORMAT(message.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` message
    ]]):format(messages_table), {})
    local message_rows = {}
    local skipped_messages = 0
    for index = 1, #messages do
        local conversation_id = conversation_by_channel[tostring(messages[index].channel)]
        local profile_id = profile_by_username[tostring(messages[index].sender):lower()]
        if conversation_id and profile_id then
            message_rows[#message_rows + 1] = {
                deterministic_uuid("lb-phone-darkchat-message", messages[index].id),
                conversation_id,
                profile_id,
                "text",
                tostring(messages[index].content or ""),
                messages[index].migrated_at,
            }
        else
            skipped_messages = skipped_messages + 1
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_darkchat_messages`
            (`id`, `conversation_id`, `sender_profile_id`, `message_type`, `body`, `created_at`) VALUES
    ]], 6, message_rows)
    return {
        source = #source_accounts,
        profiles = #profile_rows,
        conversations = #conversation_rows,
        messages = #message_rows,
        skipped = skipped_messages,
        unsupported_groups = unsupported_groups,
        unsupported_private_passwords = private_channels,
    }
end

local function run_flip_tok(dry_run)
    local accounts_table = source_table("tiktok_accounts")
    if not table_exists(accounts_table) then
        return { source = 0, profiles = 0, videos = 0, comments = 0, skipped = 0 }
    end
    local source_accounts = Bridge.Database.Query(([[
        SELECT account.*, owner.`device_imei`, owner.`account_id` AS `owner_account_id`,
            DATE_FORMAT(account.`date_joined`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` account
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = account.`phone_number`
        ORDER BY account.`date_joined`, account.`phone_number`, account.`username`
    ]]):format(accounts_table), { source_name })
    local entries = {}
    local skipped = 0
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local handle = normalize_social_handle(row.username, 24, true)
        if handle then
            entries[#entries + 1] = {
                source = row,
                handle = handle,
            }
        else
            skipped = skipped + 1
        end
    end
    if dry_run then
        return {
            source = #source_accounts,
            profiles = #entries,
            videos = count_rows(source_table("tiktok_videos")),
            comments = count_rows(source_table("tiktok_comments")),
            follows = count_rows(source_table("tiktok_follows")),
            skipped = skipped,
        }
    end

    local accepted, assignment_skipped, ownership_repaired = prepare_social_profile_accounts(entries, {
        profile_table = "sky_phone_fliptok_profiles",
        synthetic_namespace = "flip",
        account_namespace = "lb-phone-fliptok-account",
        media_pattern = "lb-flip-%",
        apps = { "tiktok", "fliptok" },
    })
    skipped = skipped + assignment_skipped

    local avatar_rows = {}
    for index = 1, #accepted do
        local entry = accepted[index]
        local avatar = valid_media_url(entry.source.avatar)
        if avatar then
            entry.avatar_source = "lb-flip-avatar:" .. deterministic_uuid(
                "lb-phone-fliptok-avatar",
                entry.handle
            )
            avatar_rows[#avatar_rows + 1] = {
                entry.account_id,
                avatar,
                entry.avatar_source,
                "photo",
                "website_import",
                entry.avatar_source,
                entry.source.migrated_at,
                entry.source.migrated_at,
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, avatar_rows)
    local avatar_ids = load_media_ids("lb-flip-avatar:%")
    local profile_rows = {}
    for index = 1, #accepted do
        local entry = accepted[index]
        profile_rows[#profile_rows + 1] = {
            entry.account_id,
            entry.handle,
            clamp_text(entry.source.name ~= "" and entry.source.name or entry.handle, 40),
            clamp_text(entry.source.bio, Config.FlipTok.BioMaxLength),
            entry.avatar_source and avatar_ids[entry.avatar_source] or nil,
            (entry.source.verified == true or tonumber(entry.source.verified) == 1) and 1 or 0,
            entry.source.migrated_at,
        }
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_profiles`
            (`account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`, `verified`, `created_at`) VALUES
    ]], 7, profile_rows)
    local target_profiles = Bridge.Database.Query(
        "SELECT `id`, `account_id`, `handle` FROM `sky_phone_fliptok_profiles`", {}
    )
    local profile_by_handle = {}
    for index = 1, #target_profiles do
        profile_by_handle[tostring(target_profiles[index].handle):lower()] = tonumber(target_profiles[index].id)
    end
    local profile_by_username = {}
    local policy_passwords = 0
    local password_pepper = tostring(Config.Server.FlipTokPasswordPepper or "")
    for index = 1, #accepted do
        local entry = accepted[index]
        entry.profile_id = profile_by_handle[entry.handle]
        if entry.profile_id then
            profile_by_username[tostring(entry.source.username):lower()] = entry
            local password = tostring(entry.source.password or "")
            if #password < Config.FlipTok.PasswordMinLength or #password > Config.FlipTok.PasswordMaxLength then
                policy_passwords = policy_passwords + 1
            end
            local salt = deterministic_hex("lb-phone-fliptok-salt", entry.handle)
            Bridge.Database.Query([[
                INSERT IGNORE INTO `sky_phone_fliptok_credentials`
                    (`profile_id`, `password_hash`, `password_salt`)
                VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?)
            ]], { entry.profile_id, password_pepper, salt, password, salt })
        end
    end

    local session_candidates = {}
    local logged_table = source_table("logged_in_accounts")
    if social_login_table_available(logged_table) then
        local logged = Bridge.Database.Query(([[
            SELECT login.`username`, owner.`device_imei`
            FROM `%s` login
            JOIN `sky_phone_migration_owners` owner
                ON owner.`source` = ? AND owner.`source_phone_number` = login.`phone_number`
            WHERE login.`active` = 1 AND LOWER(login.`app`) IN ('tiktok', 'fliptok')
        ]]):format(logged_table), { source_name })
        for index = 1, #logged do
            local profile = profile_by_username[tostring(logged[index].username):lower()]
            if profile then
                session_candidates[tostring(logged[index].device_imei)] = profile.profile_id
            end
        end
    end
    local profiles_by_device = {}
    for index = 1, #accepted do
        local entry = accepted[index]
        local imei = tostring(entry.source.device_imei)
        profiles_by_device[imei] = profiles_by_device[imei] or {}
        profiles_by_device[imei][#profiles_by_device[imei] + 1] = entry.profile_id
    end
    for imei, profiles in pairs(profiles_by_device) do
        if not session_candidates[imei] and #profiles == 1 then
            session_candidates[imei] = profiles[1]
        end
    end
    local session_rows = {}
    for imei, profile_id in pairs(session_candidates) do
        if profile_id then
            session_rows[#session_rows + 1] = { imei, profile_id }
        end
    end
    insert_many([[
        INSERT INTO `sky_phone_fliptok_sessions` (`device_imei`, `profile_id`) VALUES
    ]], 2, session_rows, [[
        ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP
    ]])

    local videos_table = source_table("tiktok_videos")
    local video_entries = {}
    local video_media_rows = {}
    if table_exists(videos_table) then
        local videos = Bridge.Database.Query(([[
            SELECT video.*,
                DATE_FORMAT(video.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` video
        ]]):format(videos_table), {})
        for index = 1, #videos do
            local row = videos[index]
            local profile = profile_by_username[tostring(row.username):lower()]
            local url = valid_media_url(row.src)
            if profile and url then
                local video_id = deterministic_uuid("lb-phone-fliptok-video", row.id)
                local source_id = "lb-flip-video:" .. video_id
                video_entries[tostring(row.id)] = {
                    id = video_id,
                    row = row,
                    profile = profile,
                    source_id = source_id,
                }
                video_media_rows[#video_media_rows + 1] = {
                    profile.account_id,
                    url,
                    source_id,
                    "video",
                    "website_import",
                    source_id,
                    row.migrated_at,
                    row.migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, video_media_rows)
    local video_media_ids = load_media_ids("lb-flip-video:%")
    local video_rows = {}
    local video_links = {}
    for _, entry in pairs(video_entries) do
        local media_id = video_media_ids[entry.source_id]
        if media_id then
            entry.media_id = media_id
            video_rows[#video_rows + 1] = {
                entry.id,
                entry.profile.profile_id,
                media_id,
                clamp_text(entry.row.caption, Config.FlipTok.CaptionMaxLength),
                clamp_text(entry.row.music, 160),
                math.max(0, math.floor(tonumber(entry.row.views) or 0)),
                entry.row.migrated_at,
                entry.row.migrated_at,
            }
            video_links[#video_links + 1] = { entry.id, media_id, 0 }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_videos`
            (`id`, `profile_id`, `media_id`, `caption`, `custom_music_title`, `view_count`,
                `created_at`, `updated_at`) VALUES
    ]], 8, video_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_video_media`
            (`video_id`, `media_id`, `sort_order`) VALUES
    ]], 3, video_links)

    local follows = {}
    local follows_table = source_table("tiktok_follows")
    if table_exists(follows_table) then
        local rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(follows_table), {})
        for index = 1, #rows do
            local follower = profile_by_username[tostring(rows[index].follower):lower()]
            local following = profile_by_username[tostring(rows[index].followed):lower()]
            if follower and following and follower.profile_id ~= following.profile_id then
                follows[#follows + 1] = { follower.profile_id, following.profile_id }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_follows` (`follower_id`, `following_id`) VALUES
    ]], 2, follows)

    local reactions = {}
    for _, source_suffix in ipairs({ "tiktok_likes", "tiktok_saves" }) do
        local table_name = source_table(source_suffix)
        if table_exists(table_name) then
            local rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(table_name), {})
            local kind = source_suffix == "tiktok_likes" and "like" or "save"
            for index = 1, #rows do
                local profile = profile_by_username[tostring(rows[index].username):lower()]
                local video = video_entries[tostring(rows[index].video_id)]
                if profile and video and video.media_id then
                    reactions[#reactions + 1] = { video.id, profile.profile_id, kind }
                end
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_reactions` (`video_id`, `profile_id`, `kind`) VALUES
    ]], 3, reactions)

    local comments_table = source_table("tiktok_comments")
    local comment_entries = {}
    local comments = {}
    if table_exists(comments_table) then
        comments = Bridge.Database.Query(([[
            SELECT comment.*,
                DATE_FORMAT(comment.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` comment
        ]]):format(comments_table), {})
        local comment_rows = {}
        for index = 1, #comments do
            local row = comments[index]
            local profile = profile_by_username[tostring(row.username):lower()]
            local video = video_entries[tostring(row.video_id)]
            if profile and video and video.media_id then
                local comment_id = deterministic_uuid("lb-phone-fliptok-comment", row.id)
                comment_entries[tostring(row.id)] = comment_id
                comment_rows[#comment_rows + 1] = {
                    comment_id,
                    video.id,
                    profile.profile_id,
                    clamp_text(row.comment, Config.FlipTok.CommentMaxLength),
                    row.migrated_at,
                }
            end
        end
        insert_many([[
            INSERT IGNORE INTO `sky_phone_fliptok_comments`
                (`id`, `video_id`, `profile_id`, `body`, `created_at`) VALUES
        ]], 5, comment_rows)
        for index = 1, #comments do
            local comment_id = comment_entries[tostring(comments[index].id)]
            local parent_id = comment_entries[tostring(comments[index].reply_to)]
            if comment_id and parent_id and comment_id ~= parent_id then
                Bridge.Database.Query([[
                    UPDATE `sky_phone_fliptok_comments` SET `parent_id` = ?
                    WHERE `id` = ? AND `parent_id` IS NULL
                ]], { parent_id, comment_id })
            end
        end
    end
    local comment_reactions = {}
    local comment_likes_table = source_table("tiktok_comments_likes")
    if table_exists(comment_likes_table) then
        local rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(comment_likes_table), {})
        for index = 1, #rows do
            local profile = profile_by_username[tostring(rows[index].username):lower()]
            local comment_id = comment_entries[tostring(rows[index].comment_id)]
            if profile and comment_id then
                comment_reactions[#comment_reactions + 1] = { comment_id, profile.profile_id }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_comment_reactions` (`comment_id`, `profile_id`) VALUES
    ]], 2, comment_reactions)

    local notification_rows = {}
    local notifications_table = source_table("tiktok_notifications")
    if table_exists(notifications_table) then
        local rows = Bridge.Database.Query(([[
            SELECT notification.*,
                DATE_FORMAT(notification.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` notification
        ]]):format(notifications_table), {})
        for index = 1, #rows do
            local recipient = profile_by_username[tostring(rows[index].username):lower()]
            local actor = profile_by_username[tostring(rows[index].from):lower()]
            local video = video_entries[tostring(rows[index].video_id)]
            local source_kind = tostring(rows[index].type):lower()
            local kind = source_kind == "follow" and "follow"
                or source_kind == "like" and "like"
                or (source_kind == "comment" or source_kind == "reply" or source_kind == "like_comment")
                    and "comment" or nil
            if recipient and actor and kind and recipient.profile_id ~= actor.profile_id
                and (kind == "follow" or (video and video.media_id))
            then
                notification_rows[#notification_rows + 1] = {
                    deterministic_uuid("lb-phone-fliptok-notification", rows[index].id),
                    recipient.profile_id,
                    actor.profile_id,
                    video and video.id or nil,
                    kind,
                    rows[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_fliptok_notifications`
            (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`, `created_at`) VALUES
    ]], 6, notification_rows)
    return {
        source = #source_accounts,
        profiles = #accepted,
        sessions = #session_rows,
        videos = #video_rows,
        comments = #comments,
        follows = #follows,
        reactions = #reactions,
        notifications = #notification_rows,
        ownership_repaired = ownership_repaired,
        skipped = skipped,
        password_policy_mismatches = policy_passwords,
        unsupported_messages = count_rows(source_table("tiktok_messages")),
        unsupported_pins = count_rows(source_table("tiktok_pinned_videos")),
    }
end

local function run_feather(dry_run)
    local accounts_table = source_table("twitter_accounts")
    if not table_exists(accounts_table) then
        return { source = 0, profiles = 0, posts = 0, skipped = 0 }
    end
    local source_accounts = Bridge.Database.Query(([[
        SELECT account.*, owner.`device_imei`, owner.`account_id` AS `owner_account_id`,
            DATE_FORMAT(account.`date_joined`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` account
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = account.`phone_number`
        ORDER BY account.`date_joined`, account.`phone_number`, account.`username`
    ]]):format(accounts_table), { source_name })
    local entries = {}
    local skipped = 0
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local handle = normalize_social_handle(row.username, Config.Feather.HandleMaxLength, false)
        if handle then
            local entry = { source = row, handle = handle }
            entries[#entries + 1] = entry
        else
            skipped = skipped + 1
        end
    end
    if dry_run then
        return {
            source = #source_accounts,
            profiles = #entries,
            posts = count_rows(source_table("twitter_tweets")),
            replies = count_rows(source_table("twitter_tweets")),
            likes = count_rows(source_table("twitter_likes")),
            retweets = count_rows(source_table("twitter_retweets")),
            follows = count_rows(source_table("twitter_follows")),
            skipped = skipped,
        }
    end

    local accepted, assignment_skipped, ownership_repaired = prepare_social_profile_accounts(entries, {
        profile_table = "sky_phone_feather_profiles",
        synthetic_namespace = "feather",
        account_namespace = "lb-phone-feather-account",
        media_pattern = "lb-feather-%",
        apps = { "twitter", "feather" },
    })
    skipped = skipped + assignment_skipped

    local avatar_rows = {}
    for index = 1, #accepted do
        local entry = accepted[index]
        local avatar = valid_media_url(entry.source.profile_image)
        if avatar then
            entry.avatar_source = "lb-feather-avatar:" .. deterministic_uuid(
                "lb-phone-feather-avatar",
                entry.handle
            )
            avatar_rows[#avatar_rows + 1] = {
                entry.account_id,
                avatar,
                entry.avatar_source,
                "photo",
                "website_import",
                entry.avatar_source,
                entry.source.migrated_at,
                entry.source.migrated_at,
            }
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, avatar_rows)
    local avatar_ids = load_media_ids("lb-feather-avatar:%")
    local profile_rows = {}
    for index = 1, #accepted do
        local entry = accepted[index]
        profile_rows[#profile_rows + 1] = {
            entry.account_id,
            entry.handle,
            clamp_text(entry.source.display_name ~= "" and entry.source.display_name or entry.handle,
                Config.Feather.DisplayNameMaxLength),
            clamp_text(entry.source.bio, Config.Feather.BioMaxLength),
            entry.avatar_source and avatar_ids[entry.avatar_source] or nil,
            (entry.source.verified == true or tonumber(entry.source.verified) == 1) and 1 or 0,
            entry.source.migrated_at,
        }
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_profiles`
            (`account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`, `verified`, `created_at`) VALUES
    ]], 7, profile_rows)
    local target_profiles = Bridge.Database.Query(
        "SELECT `id`, `account_id`, `handle` FROM `sky_phone_feather_profiles`", {}
    )
    local profile_by_handle = {}
    for index = 1, #target_profiles do
        profile_by_handle[tostring(target_profiles[index].handle):lower()] = tonumber(target_profiles[index].id)
    end
    local profile_by_username = {}
    for index = 1, #accepted do
        accepted[index].profile_id = profile_by_handle[accepted[index].handle]
        if accepted[index].profile_id then
            profile_by_username[tostring(accepted[index].source.username):lower()] = accepted[index]
        end
    end

    local tweets_table = source_table("twitter_tweets")
    local post_entries = {}
    local post_media_rows = {}
    if table_exists(tweets_table) then
        local tweets = Bridge.Database.Query(([[
            SELECT tweet.*,
                DATE_FORMAT(tweet.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` tweet
        ]]):format(tweets_table), {})
        for index = 1, #tweets do
            local row = tweets[index]
            local profile = profile_by_username[tostring(row.username):lower()]
            local media = extract_media(row.attachments, 4)
            local body = clamp_text(row.content, 360)
            if profile and (body ~= "" or #media > 0) then
                local post_id = deterministic_uuid("lb-phone-feather-post", row.id)
                local entry = {
                    id = post_id,
                    row = row,
                    profile = profile,
                    media = media,
                }
                post_entries[tostring(row.id)] = entry
                for position = 1, #media do
                    local source_id = "lb-feather-post:" .. deterministic_uuid(
                        "lb-phone-feather-post-media",
                        tostring(row.id) .. ":" .. position
                    )
                    media[position].source_id = source_id
                    post_media_rows[#post_media_rows + 1] = {
                        profile.account_id,
                        media[position].url,
                        source_id,
                        media[position].media_type,
                        "website_import",
                        source_id,
                        row.migrated_at,
                        row.migrated_at,
                    }
                end
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, post_media_rows)
    local post_media_ids = load_media_ids("lb-feather-post:%")
    local post_rows = {}
    local post_media_links = {}
    for _, entry in pairs(post_entries) do
        post_rows[#post_rows + 1] = {
            entry.id,
            entry.profile.profile_id,
            clamp_text(entry.row.content, 360),
            entry.row.migrated_at,
        }
        for position = 1, #entry.media do
            local media_id = post_media_ids[entry.media[position].source_id]
            if media_id then
                post_media_links[#post_media_links + 1] = { entry.id, media_id, position - 1 }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_posts`
            (`id`, `profile_id`, `body`, `created_at`) VALUES
    ]], 4, post_rows)
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_post_media`
            (`post_id`, `media_id`, `sort_order`) VALUES
    ]], 3, post_media_links)
    for _, entry in pairs(post_entries) do
        local parent = post_entries[tostring(entry.row.reply_to)]
        if parent and parent.id ~= entry.id then
            Bridge.Database.Query([[
                UPDATE `sky_phone_feather_posts` SET `reply_to_id` = ?
                WHERE `id` = ? AND `reply_to_id` IS NULL
            ]], { parent.id, entry.id })
        end
    end

    local hashtag_rows = {}
    for _, entry in pairs(post_entries) do
        local seen = {}
        for tag in tostring(entry.row.content or ""):gmatch("#([%w_]+)") do
            local normalized = tag:lower()
            if #normalized <= Config.Feather.HashtagMaxLength and not seen[normalized] then
                seen[normalized] = true
                hashtag_rows[#hashtag_rows + 1] = { entry.id, normalized, entry.row.migrated_at }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_hashtags` (`post_id`, `tag`, `created_at`) VALUES
    ]], 3, hashtag_rows)

    local retweet_rows = {}
    local retweets_table = source_table("twitter_retweets")
    if table_exists(retweets_table) then
        local rows = Bridge.Database.Query(([[
            SELECT retweet.*,
                DATE_FORMAT(retweet.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` retweet
        ]]):format(retweets_table), {})
        for index = 1, #rows do
            local profile = profile_by_username[tostring(rows[index].username):lower()]
            local quoted = post_entries[tostring(rows[index].tweet_id)]
            if profile and quoted then
                retweet_rows[#retweet_rows + 1] = {
                    deterministic_uuid(
                        "lb-phone-feather-retweet",
                        tostring(rows[index].tweet_id) .. ":" .. tostring(rows[index].username)
                    ),
                    profile.profile_id,
                    "",
                    quoted.id,
                    rows[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_posts`
            (`id`, `profile_id`, `body`, `quote_id`, `created_at`) VALUES
    ]], 5, retweet_rows)

    local reaction_rows = {}
    local likes_table = source_table("twitter_likes")
    if table_exists(likes_table) then
        local rows = Bridge.Database.Query(([[
            SELECT reaction.*,
                DATE_FORMAT(reaction.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` reaction
        ]]):format(likes_table), {})
        for index = 1, #rows do
            local profile = profile_by_username[tostring(rows[index].username):lower()]
            local post = post_entries[tostring(rows[index].tweet_id)]
            if profile and post then
                reaction_rows[#reaction_rows + 1] = {
                    post.id, profile.profile_id, "like", rows[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_reactions`
            (`post_id`, `profile_id`, `kind`, `created_at`) VALUES
    ]], 4, reaction_rows)

    local follow_rows = {}
    local follows_table = source_table("twitter_follows")
    if table_exists(follows_table) then
        local rows = Bridge.Database.Query(("SELECT * FROM `%s`"):format(follows_table), {})
        for index = 1, #rows do
            local follower = profile_by_username[tostring(rows[index].follower):lower()]
            local following = profile_by_username[tostring(rows[index].followed):lower()]
            if follower and following and follower.profile_id ~= following.profile_id then
                follow_rows[#follow_rows + 1] = { follower.profile_id, following.profile_id }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_follows` (`follower_id`, `following_id`) VALUES
    ]], 2, follow_rows)

    local notification_rows = {}
    local notifications_table = source_table("twitter_notifications")
    if table_exists(notifications_table) then
        local rows = Bridge.Database.Query(([[
            SELECT notification.*,
                DATE_FORMAT(notification.`timestamp`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
            FROM `%s` notification
        ]]):format(notifications_table), {})
        for index = 1, #rows do
            local recipient = profile_by_username[tostring(rows[index].username):lower()]
            local actor = profile_by_username[tostring(rows[index].from):lower()]
            local post = post_entries[tostring(rows[index].tweet_id)]
            local source_kind = tostring(rows[index].type):lower()
            local kind = source_kind == "like" and "like"
                or source_kind == "reply" and "reply"
                or source_kind == "retweet" and "quote"
                or source_kind == "follow" and "follow" or nil
            if recipient and actor and kind and recipient.profile_id ~= actor.profile_id
                and (kind == "follow" or post)
            then
                notification_rows[#notification_rows + 1] = {
                    deterministic_uuid("lb-phone-feather-notification", rows[index].id),
                    recipient.profile_id,
                    actor.profile_id,
                    post and post.id or nil,
                    kind,
                    rows[index].migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_feather_notifications`
            (`id`, `recipient_id`, `actor_id`, `post_id`, `kind`, `created_at`) VALUES
    ]], 6, notification_rows)

    local private_profiles = 0
    for index = 1, #accepted do
        if accepted[index].source.private == true or tonumber(accepted[index].source.private) == 1 then
            private_profiles = private_profiles + 1
        end
    end
    return {
        source = #source_accounts,
        profiles = #accepted,
        posts = #post_rows,
        post_media = #post_media_links,
        retweets = #retweet_rows,
        likes = #reaction_rows,
        follows = #follow_rows,
        notifications = #notification_rows,
        ownership_repaired = ownership_repaired,
        skipped = skipped,
        unsupported_private_profiles = private_profiles,
        unsupported_follow_requests = count_rows(source_table("twitter_follow_requests")),
        unsupported_messages = count_rows(source_table("twitter_messages")),
        unsupported_promotions = count_rows(source_table("twitter_promoted")),
    }
end

local function run_flare(dry_run)
    local accounts_table = source_table("tinder_accounts")
    if not table_exists(accounts_table) then
        return { source = 0, profiles = 0, profile_photos = 0, swipes = 0, matches = 0, skipped = 0 }
    end

    local source_accounts = Bridge.Database.Query(([[
        SELECT account.*, owner.`account_id` AS `owner_account_id`,
            TIMESTAMPDIFF(YEAR, account.`dob`, CURDATE()) AS `age`,
            DATE_FORMAT(account.`last_seen`, '%%Y-%%m-%%d %%H:%%i:%%s') AS `migrated_at`
        FROM `%s` account
        JOIN `sky_phone_migration_owners` owner
            ON owner.`source` = ? AND owner.`source_phone_number` = account.`phone_number`
        ORDER BY account.`phone_number`
    ]]):format(accounts_table), { source_name })

    local entries = {}
    local photo_count = 0
    local skipped = 0
    for index = 1, #source_accounts do
        local row = source_accounts[index]
        local account_id = tonumber(row.owner_account_id)
        local name = clamp_text(row.name, 32):match("^%s*(.-)%s*$")
        if #name < 2 then
            name = "LB User"
        end
        local age = math.max(18, math.min(99, math.floor(tonumber(row.age) or 18)))
        local interested_men = row.interested_men == true or tonumber(row.interested_men) == 1
        local interested_women = row.interested_women == true or tonumber(row.interested_women) == 1
        local interested_in = interested_men and not interested_women and "man"
            or interested_women and not interested_men and "woman"
            or "everyone"
        if account_id then
            local photos = extract_media(row.photos, 6)
            local photo_entries = {}
            for position = 1, #photos do
                if photos[position].media_type == "photo" and photos[position].url:match("^https://") then
                    photo_entries[#photo_entries + 1] = {
                        url = photos[position].url,
                        source_id = "lb-flare-photo:" .. deterministic_uuid(
                            "lb-phone-flare-photo",
                            tostring(row.phone_number) .. ":" .. tostring(position)
                        ),
                    }
                end
            end
            photo_count = photo_count + #photo_entries
            entries[#entries + 1] = {
                source = row,
                account_id = account_id,
                name = name,
                age = age,
                bio = clamp_text(row.bio, 300),
                gender = (row.is_male == true or tonumber(row.is_male) == 1) and "man" or "woman",
                interested_in = interested_in,
                discoverable = (row.active == true or tonumber(row.active) == 1) and 1 or 0,
                photos = photo_entries,
            }
        else
            skipped = skipped + 1
        end
    end

    local swipes_table = source_table("tinder_swipes")
    local source_swipes = {}
    if table_exists(swipes_table) then
        source_swipes = Bridge.Database.Query(([[
            SELECT swipe.*, swiper_owner.`account_id` AS `swiper_account_id`,
                target_owner.`account_id` AS `target_account_id`
            FROM `%s` swipe
            JOIN `sky_phone_migration_owners` swiper_owner
                ON swiper_owner.`source` = ? AND swiper_owner.`source_phone_number` = swipe.`swiper`
            JOIN `sky_phone_migration_owners` target_owner
                ON target_owner.`source` = ? AND target_owner.`source_phone_number` = swipe.`swipee`
        ]]):format(swipes_table), { source_name, source_name })
    end
    if dry_run then
        return {
            source = #source_accounts,
            profiles = #entries,
            profile_photos = photo_count,
            swipes = #source_swipes,
            skipped = skipped,
        }
    end

    local existing_profiles = Bridge.Database.Query(
        "SELECT `account_id` FROM `sky_phone_flare_profiles`", {}
    )
    local existing_profile_accounts = {}
    for index = 1, #existing_profiles do
        existing_profile_accounts[tonumber(existing_profiles[index].account_id)] = true
    end
    for index = 1, #entries do
        entries[index].import_profile = not existing_profile_accounts[entries[index].account_id]
    end

    local media_rows = {}
    for index = 1, #entries do
        local entry = entries[index]
        if entry.import_profile then
            for position = 1, #entry.photos do
                local photo = entry.photos[position]
                media_rows[#media_rows + 1] = {
                    entry.account_id,
                    photo.url,
                    photo.source_id,
                    "photo",
                    "website_import",
                    photo.source_id,
                    entry.source.migrated_at,
                    entry.source.migrated_at,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_media`
            (`account_id`, `url`, `remote_id`, `media_type`, `origin`, `source_id`,
                `verified_at`, `created_at`) VALUES
    ]], 8, media_rows)

    local profile_rows = {}
    for index = 1, #entries do
        local entry = entries[index]
        if entry.import_profile then
            profile_rows[#profile_rows + 1] = {
                entry.account_id,
                entry.name,
                entry.age,
                entry.bio,
                entry.gender,
                entry.interested_in,
                18,
                99,
                0,
                json.encode({}),
                "longTerm",
                entry.discoverable,
                entry.source.migrated_at,
                entry.source.migrated_at,
            }
        end
    end
    local inserted_profiles = insert_many([[
        INSERT IGNORE INTO `sky_phone_flare_profiles`
            (`account_id`, `name`, `age`, `bio`, `gender`, `interested_in`, `min_age`, `max_age`,
                `avatar`, `interests`, `looking_for`, `discoverable`, `created_at`, `updated_at`) VALUES
    ]], 14, profile_rows)

    local target_profiles = Bridge.Database.Query(
        "SELECT `id`, `account_id` FROM `sky_phone_flare_profiles`", {}
    )
    local profile_by_account = {}
    for index = 1, #target_profiles do
        profile_by_account[tonumber(target_profiles[index].account_id)] = tonumber(target_profiles[index].id)
    end
    local media_ids = load_media_ids("lb-flare-photo:%")
    local photo_rows = {}
    for index = 1, #entries do
        local entry = entries[index]
        local profile_id = profile_by_account[entry.account_id]
        if profile_id and entry.import_profile then
            for position = 1, #entry.photos do
                local media_id = media_ids[entry.photos[position].source_id]
                if media_id then
                    photo_rows[#photo_rows + 1] = { profile_id, media_id, position }
                end
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_flare_profile_photos`
            (`profile_id`, `media_id`, `sort_order`) VALUES
    ]], 3, photo_rows)

    local swipe_rows = {}
    local liked_pairs = {}
    for index = 1, #source_swipes do
        local row = source_swipes[index]
        local swiper_account_id = tonumber(row.swiper_account_id)
        local target_account_id = tonumber(row.target_account_id)
        if swiper_account_id and target_account_id and swiper_account_id ~= target_account_id
            and profile_by_account[swiper_account_id] and profile_by_account[target_account_id]
        then
            local liked = row.liked == true or tonumber(row.liked) == 1
            swipe_rows[#swipe_rows + 1] = {
                swiper_account_id,
                target_account_id,
                liked and "like" or "pass",
            }
            if liked then
                liked_pairs[tostring(swiper_account_id) .. ":" .. tostring(target_account_id)] = true
            end
        else
            skipped = skipped + 1
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_flare_swipes`
            (`swiper_account_id`, `target_account_id`, `choice`) VALUES
    ]], 3, swipe_rows)

    local match_rows = {}
    local matched_pairs = {}
    for key in pairs(liked_pairs) do
        local first, second = key:match("^(%d+):(%d+)$")
        local first_id = tonumber(first)
        local second_id = tonumber(second)
        if first_id and second_id
            and liked_pairs[tostring(second_id) .. ":" .. tostring(first_id)]
        then
            local account_a_id = math.min(first_id, second_id)
            local account_b_id = math.max(first_id, second_id)
            local pair_key = tostring(account_a_id) .. ":" .. tostring(account_b_id)
            if not matched_pairs[pair_key] then
                matched_pairs[pair_key] = true
                match_rows[#match_rows + 1] = {
                    deterministic_uuid("lb-phone-flare-match", pair_key),
                    account_a_id,
                    account_b_id,
                }
            end
        end
    end
    insert_many([[
        INSERT IGNORE INTO `sky_phone_flare_matches` (`id`, `account_a_id`, `account_b_id`) VALUES
    ]], 3, match_rows)

    return {
        source = #source_accounts,
        profiles = inserted_profiles,
        profile_photos = #photo_rows,
        swipes = #swipe_rows,
        matches = #match_rows,
        skipped = skipped,
    }
end

local domain_order = {
    "devices",
    "settings",
    "alarms",
    "contacts",
    "blocked",
    "calls",
    "messages",
    "photos",
    "notes",
    "wallet",
    "voiceMemos",
    "picstagram",
    "mail",
    "mapMarkers",
    "darkChat",
    "flipTok",
    "feather",
    "flare",
}

local domain_runners = {
    devices = run_devices,
    settings = run_settings,
    alarms = run_alarms,
    contacts = run_contacts,
    blocked = run_blocked,
    calls = run_calls,
    messages = run_messages,
    photos = run_photos,
    notes = run_notes,
    wallet = run_wallet,
    voiceMemos = run_voice_memos,
    picstagram = run_picstagram,
    mail = run_mail,
    mapMarkers = run_map_markers,
    darkChat = run_dark_chat,
    flipTok = run_flip_tok,
    feather = run_feather,
    flare = run_flare,
}

local preview_tables = {
    settings = { "phones" },
    alarms = { "clock_alarms" },
    contacts = { "phone_contacts" },
    blocked = { "phone_blocked_numbers" },
    calls = { "phone_calls" },
    messages = { "message_messages", "message_reactions" },
    photos = { "photos", "photo_albums" },
    notes = { "notes" },
    wallet = { "wallet_transactions" },
    voiceMemos = { "voice_memos_recordings" },
    picstagram = {
        "instagram_accounts",
        "instagram_posts",
        "instagram_comments",
        "instagram_likes",
        "instagram_follows",
        "instagram_follow_requests",
        "instagram_stories",
        "instagram_stories_views",
    },
    mail = { "mail_accounts", "mail_messages", "mail_deleted" },
    mapMarkers = { "maps_locations" },
    darkChat = { "darkchat_accounts", "darkchat_channels", "darkchat_members", "darkchat_messages" },
    flipTok = {
        "tiktok_accounts",
        "tiktok_videos",
        "tiktok_likes",
        "tiktok_saves",
        "tiktok_follows",
        "tiktok_comments",
        "tiktok_comments_likes",
        "tiktok_notifications",
    },
    feather = {
        "twitter_accounts",
        "twitter_tweets",
        "twitter_likes",
        "twitter_retweets",
        "twitter_follows",
        "twitter_notifications",
    },
    flare = { "tinder_accounts", "tinder_swipes" },
}

local function preview_domain(domain)
    local tables = preview_tables[domain] or {}
    local counts = { preview = true, source = 0, tables = {} }
    for index = 1, #tables do
        local rows = count_rows(source_table(tables[index]))
        counts.tables[tables[index]] = rows
        counts.source = counts.source + rows
    end
    return counts
end

local domain_labels = {
    devices = "Phones",
    settings = "Settings",
    alarms = "Alarms",
    contacts = "Contacts",
    blocked = "Blocked numbers",
    calls = "Calls",
    messages = "Messages",
    photos = "Photos",
    notes = "Notes",
    wallet = "Wallet",
    voiceMemos = "Voice memos",
    picstagram = "Picstagram",
    mail = "Mail",
    mapMarkers = "Map markers",
    darkChat = "DarkChat",
    flipTok = "FlipTok",
    feather = "Feather",
    flare = "Flare",
}

local summary_metrics = {
    { "imported", "imported" },
    { "resolved", "matched" },
    { "profiles", "profiles" },
    { "ownership_repaired", "ownership repairs" },
    { "profile_photos", "profile photos" },
    { "swipes", "swipes" },
    { "matches", "matches" },
    { "sessions", "sessions" },
    { "posts", "posts" },
    { "post_media", "media" },
    { "comments", "comments" },
    { "follows", "follows" },
    { "stories", "stories" },
    { "story_views", "story views" },
    { "mailboxes", "mailboxes" },
    { "messages", "messages" },
    { "entries", "entries" },
    { "conversations", "chats" },
    { "videos", "videos" },
    { "reactions", "reactions" },
    { "notifications", "activities" },
    { "retweets", "retweets" },
    { "likes", "likes" },
    { "devices", "devices" },
    { "avatars", "avatars" },
    { "passcodes", "passcodes" },
}

local function unsupported_count(stats)
    local count = 0
    for key, value in pairs(stats) do
        if tostring(key):sub(1, 12) == "unsupported_" then
            count = count + math.max(0, tonumber(value) or 0)
        end
    end
    return count
end

local function format_domain_summary(domain, stats, dry_run)
    local source = math.max(0, tonumber(stats.source) or 0)
    local skipped = math.max(0, tonumber(stats.skipped) or 0)
    local unsupported = unsupported_count(stats)
    local parts = {}
    if source > 0 then
        parts[#parts + 1] = ("%s found"):format(source)
    end
    for index = 1, #summary_metrics do
        local metric = summary_metrics[index]
        local value = math.max(0, tonumber(stats[metric[1]]) or 0)
        if value > 0 and not (dry_run and metric[1] == "resolved") then
            local label = dry_run and metric[1] == "imported" and "ready" or metric[2]
            parts[#parts + 1] = ("%s %s"):format(value, label)
        end
    end
    if skipped > 0 then
        parts[#parts + 1] = ("%s skipped"):format(skipped)
    end
    if unsupported > 0 then
        parts[#parts + 1] = ("%s unsupported"):format(unsupported)
    end
    if #parts == 0 then
        return nil
    end
    return ("[sky_phone]   %-22s %s"):format(
        (domain_labels[domain] or domain) .. ":",
        table.concat(parts, " | ")
    )
end

local function format_rollback_summary(stats)
    local devices = math.max(0, tonumber(stats.devices) or 0)
    local sims = math.max(0, tonumber(stats.sims) or 0)
    local accounts = math.max(0, tonumber(stats.accounts) or 0)
    local mappings = math.max(0, tonumber(stats.ownerMappings) or 0)
        + math.max(0, tonumber(stats.numberMappings) or 0)
        + math.max(0, tonumber(stats.characterDevices) or 0)
    local markers = math.max(0, tonumber(stats.markers) or 0)
    local ignored = {
        devices = true,
        sims = true,
        accounts = true,
        ownerMappings = true,
        numberMappings = true,
        characterDevices = true,
        markers = true,
    }
    local app_entries = 0
    for key, value in pairs(stats) do
        if not ignored[key] then
            app_entries = app_entries + math.max(0, tonumber(value) or 0)
        end
    end
    return ("%s phones | %s SIMs | %s accounts | %s app records | %s mappings | %s markers"):format(
        devices,
        sims,
        accounts,
        app_entries,
        mappings,
        markers
    )
end

local function run_migration(options)
    if running then
        Bridge.Debug("warn", "[sky_phone] An LB Phone migration is already running.", { always = true })
        return
    end
    if not table_exists(source_table("phones")) then
        Bridge.Debug(
            "info",
            "[sky_phone] LB Phone migration skipped because source table '%s' does not exist.",
            source_table("phones"),
            { always = true }
        )
        return
    end

    running = true
    local dry_run = options and options.dry_run or false
    local force = options and options.force or false
    Bridge.Debug(
        "info",
        dry_run
            and "[sky_phone] LB Phone preview started. Source data remains unchanged."
            or "[sky_phone] LB Phone import started. Source data remains unchanged.",
        { always = true }
    )

    local domains = migration_config.Domains or {}
    local failed = 0
    local shown = 0
    local completed = 0
    for index = 1, #domain_order do
        local domain = domain_order[index]
        if domains[domain] ~= false then
            if not force and migration_done(domain) then
                completed = completed + 1
            else
                local has_owner_mappings = Bridge.Database.Query([[
                    SELECT 1 FROM `sky_phone_migration_owners` WHERE `source` = ? LIMIT 1
                ]], { source_name })[1] ~= nil
                local runner = dry_run and domain ~= "devices" and not has_owner_mappings
                    and preview_domain
                    or domain_runners[domain]
                local success, stats, error_code
                if runner == preview_domain then
                    success, stats, error_code = pcall(runner, domain)
                else
                    success, stats, error_code = pcall(runner, dry_run)
                end
                if success and stats then
                    if not dry_run then
                        record_migration(domain, stats)
                    end
                    local summary = format_domain_summary(domain, stats, dry_run)
                    if summary then
                        shown = shown + 1
                        Bridge.Debug("info", summary, { always = true })
                    end
                else
                    failed = failed + 1
                    Bridge.Debug(
                        "error",
                        "[sky_phone] LB Phone migration domain '%s' failed: %s",
                        domain,
                        tostring(success and error_code or stats),
                        { always = true }
                    )
                    if domain == "devices" then
                        break
                    end
                end
            end
        end
    end
    running = false
    Bridge.Debug(
        failed == 0 and "info" or "error",
        dry_run
            and "[sky_phone] Preview complete: %s areas with data | %s already complete | %s errors."
            or "[sky_phone] Import complete: %s areas with data | %s already complete | %s errors.",
        tostring(shown),
        tostring(completed),
        tostring(failed),
        { always = true }
    )
end

local function delete_values(table_name, column_name, values)
    if not table_name:match("^[%w_]+$") or not column_name:match("^[%w_]+$") then
        error("[sky_phone] Invalid rollback table or column identifier.")
    end
    local unique = {}
    local filtered = {}
    for index = 1, #values do
        local value = values[index]
        if value ~= nil and not unique[tostring(value)] then
            unique[tostring(value)] = true
            filtered[#filtered + 1] = value
        end
    end
    local deleted = 0
    for first = 1, #filtered, 250 do
        local last = math.min(first + 249, #filtered)
        local placeholders = {}
        local parameters = {}
        for index = first, last do
            placeholders[#placeholders + 1] = "?"
            parameters[#parameters + 1] = filtered[index]
        end
        deleted = deleted + affected_rows(Bridge.Database.Query((
            "DELETE FROM `%s` WHERE `%s` IN (%s)"
        ):format(table_name, column_name, table.concat(placeholders, ",")), parameters))
    end
    return deleted
end

local function rollback_source_rows(suffix, required_columns)
    local table_name = source_table(suffix)
    if not table_exists(table_name) then
        return {}
    end
    for index = 1, #(required_columns or {}) do
        if not table_has_column(table_name, required_columns[index]) then
            return {}
        end
    end
    return Bridge.Database.Query(("SELECT * FROM `%s`"):format(table_name), {})
end

local function rollback_lb_phone()
    if running then
        Bridge.Debug("warn", "[sky_phone] An LB Phone migration or rollback is already running.", { always = true })
        return
    end
    running = true
    Bridge.Debug(
        "warn",
        "[sky_phone] LB Phone rollback started. Source data remains unchanged.",
        { always = true }
    )

    local success, result = pcall(function()
        local stats = {}
        local owners = Bridge.Database.Query([[
            SELECT * FROM `sky_phone_migration_owners` WHERE `source` = ?
        ]], { source_name })
        local owner_by_phone_id = {}
        local owner_by_number = {}
        for index = 1, #owners do
            owner_by_phone_id[tostring(owners[index].source_phone_id)] = owners[index]
            owner_by_number[tostring(owners[index].source_phone_number)] = owners[index]
        end

        local contact_ids = {}
        local contacts = rollback_source_rows("phone_contacts", {
            "phone_number", "contact_phone_number",
        })
        for index = 1, #contacts do
            contact_ids[#contact_ids + 1] = deterministic_uuid(
                "lb-phone-contact",
                tostring(contacts[index].phone_number) .. ":" .. tostring(contacts[index].contact_phone_number)
            )
        end
        stats.contacts = delete_values("sky_phone_contacts", "id", contact_ids)

        local call_ids = {}
        local calls = rollback_source_rows("phone_calls", { "id" })
        for index = 1, #calls do
            call_ids[#call_ids + 1] = deterministic_uuid("lb-phone-call", calls[index].id)
        end
        stats.calls = delete_values("sky_phone_calls", "id", call_ids)

        local message_ids = {}
        local messages = rollback_source_rows("message_messages", { "id" })
        for index = 1, #messages do
            message_ids[#message_ids + 1] = deterministic_uuid("lb-phone-message", messages[index].id)
        end
        stats.messages = delete_values("sky_phone_sms_messages", "id", message_ids)

        local map_ids = {}
        local locations = rollback_source_rows("maps_locations", { "id" })
        for index = 1, #locations do
            map_ids[#map_ids + 1] = deterministic_uuid("lb-phone-map-marker", locations[index].id)
        end
        stats.mapMarkers = delete_values("sky_phone_map_markers", "id", map_ids)

        local mail_ids = {}
        local mail_messages = rollback_source_rows("mail_messages", { "id" })
        for index = 1, #mail_messages do
            mail_ids[#mail_ids + 1] = deterministic_uuid("lb-phone-mail-message", mail_messages[index].id)
        end
        stats.mail = delete_values("sky_phone_mail_messages", "id", mail_ids)

        local dark_conversations = {}
        local dark_channels = rollback_source_rows("darkchat_channels", { "name" })
        for index = 1, #dark_channels do
            dark_conversations[#dark_conversations + 1] = deterministic_uuid(
                "lb-phone-darkchat-conversation",
                dark_channels[index].name
            )
        end
        stats.darkChatConversations = delete_values(
            "sky_phone_darkchat_conversations",
            "id",
            dark_conversations
        )
        local dark_ids = {}
        local dark_accounts = rollback_source_rows("darkchat_accounts", { "username" })
        for index = 1, #dark_accounts do
            local entropy = deterministic_hex(
                "lb-phone-darkchat-profile",
                dark_accounts[index].username
            ):upper()
            dark_ids[#dark_ids + 1] = ("dark:%s-%s"):format(entropy:sub(1, 4), entropy:sub(5, 8))
        end
        stats.darkChatProfiles = delete_values("sky_phone_darkchat_profiles", "dark_id", dark_ids)

        local picstagram_profiles = {}
        local instagram_accounts = rollback_source_rows("instagram_accounts", { "username" })
        for index = 1, #instagram_accounts do
            local handle = normalize_picstagram_handle(instagram_accounts[index].username)
            if handle then
                picstagram_profiles[#picstagram_profiles + 1] = deterministic_uuid(
                    "lb-phone-picstagram-profile",
                    handle
                )
            end
        end
        stats.picstagram = delete_values("sky_phone_picstagram_profiles", "id", picstagram_profiles)

        local flare_match_ids = {}
        local flare_swipe_rows = rollback_source_rows("tinder_swipes", { "swiper", "swipee", "liked" })
        local liked_flare_pairs = {}
        local removed_flare_swipes = 0
        for index = 1, #flare_swipe_rows do
            local swiper_owner = owner_by_number[tostring(flare_swipe_rows[index].swiper)]
            local target_owner = owner_by_number[tostring(flare_swipe_rows[index].swipee)]
            local swiper_account_id = swiper_owner and tonumber(swiper_owner.account_id)
            local target_account_id = target_owner and tonumber(target_owner.account_id)
            if swiper_account_id and target_account_id and swiper_account_id ~= target_account_id then
                removed_flare_swipes = removed_flare_swipes + affected_rows(Bridge.Database.Query([[
                    DELETE FROM `sky_phone_flare_swipes`
                    WHERE `swiper_account_id` = ? AND `target_account_id` = ?
                ]], { swiper_account_id, target_account_id }))
                if flare_swipe_rows[index].liked == true or tonumber(flare_swipe_rows[index].liked) == 1 then
                    liked_flare_pairs[tostring(swiper_account_id) .. ":" .. tostring(target_account_id)] = true
                end
            end
        end
        for key in pairs(liked_flare_pairs) do
            local first, second = key:match("^(%d+):(%d+)$")
            local first_id = tonumber(first)
            local second_id = tonumber(second)
            if first_id and second_id
                and liked_flare_pairs[tostring(second_id) .. ":" .. tostring(first_id)]
                and first_id < second_id
            then
                flare_match_ids[#flare_match_ids + 1] = deterministic_uuid(
                    "lb-phone-flare-match",
                    tostring(first_id) .. ":" .. tostring(second_id)
                )
            end
        end
        stats.flareMatches = delete_values("sky_phone_flare_matches", "id", flare_match_ids)
        stats.flareSwipes = removed_flare_swipes

        local flare_accounts = rollback_source_rows("tinder_accounts", { "phone_number", "last_seen" })
        local removed_flare_profiles = 0
        for index = 1, #flare_accounts do
            local owner = owner_by_number[tostring(flare_accounts[index].phone_number)]
            local account_id = owner and tonumber(owner.account_id)
            if account_id and flare_accounts[index].last_seen then
                removed_flare_profiles = removed_flare_profiles + affected_rows(Bridge.Database.Query([[
                    DELETE FROM `sky_phone_flare_profiles`
                    WHERE `account_id` = ? AND `created_at` = ? AND `updated_at` = ?
                ]], { account_id, flare_accounts[index].last_seen, flare_accounts[index].last_seen }))
            end
        end
        stats.flareProfiles = removed_flare_profiles

        local feather_post_ids = {}
        local tweets = rollback_source_rows("twitter_tweets", { "id" })
        for index = 1, #tweets do
            feather_post_ids[#feather_post_ids + 1] = deterministic_uuid(
                "lb-phone-feather-post",
                tweets[index].id
            )
        end
        local retweets = rollback_source_rows("twitter_retweets", { "tweet_id", "username" })
        for index = 1, #retweets do
            feather_post_ids[#feather_post_ids + 1] = deterministic_uuid(
                "lb-phone-feather-retweet",
                tostring(retweets[index].tweet_id) .. ":" .. tostring(retweets[index].username)
            )
        end
        stats.featherPosts = delete_values("sky_phone_feather_posts", "id", feather_post_ids)
        local feather_notification_ids = {}
        local twitter_notifications = rollback_source_rows("twitter_notifications", { "id" })
        for index = 1, #twitter_notifications do
            feather_notification_ids[#feather_notification_ids + 1] = deterministic_uuid(
                "lb-phone-feather-notification",
                twitter_notifications[index].id
            )
        end
        stats.featherNotifications = delete_values(
            "sky_phone_feather_notifications",
            "id",
            feather_notification_ids
        )

        local flip_notification_ids = {}
        local tiktok_notifications = rollback_source_rows("tiktok_notifications", { "id" })
        for index = 1, #tiktok_notifications do
            flip_notification_ids[#flip_notification_ids + 1] = deterministic_uuid(
                "lb-phone-fliptok-notification",
                tiktok_notifications[index].id
            )
        end
        stats.flipTokNotifications = delete_values(
            "sky_phone_fliptok_notifications",
            "id",
            flip_notification_ids
        )

        stats.notes = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_notes` WHERE `id` LIKE 'lb-phone-note:%'
        ]], {}))
        stats.wallet = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_bank_transactions` WHERE `reference` LIKE 'lb-phone-wallet:%'
        ]], {}))
        stats.media = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_media`
            WHERE `origin` = 'website_import' AND `source_id` LIKE 'lb-%'
        ]], {}))

        local phones = rollback_source_rows("phones", { "id" })
        local created_devices = {}
        local passcode_rows = 0
        for index = 1, #phones do
            local owner = owner_by_phone_id[tostring(phones[index].id)]
            if owner then
                local expected_device = deterministic_imei(phones[index].id)
                if tostring(owner.device_imei) == expected_device then
                    created_devices[#created_devices + 1] = expected_device
                end
                local salt = deterministic_hex("lb-phone-passcode-salt", phones[index].id)
                passcode_rows = passcode_rows + affected_rows(Bridge.Database.Query([[
                    DELETE FROM `sky_phone_device_security`
                    WHERE `device_imei` = ? AND `passcode_salt` = ?
                ]], { owner.device_imei, salt }))
            end
        end
        stats.passcodes = passcode_rows
        for index = 1, #owners do
            stats.alarms = (stats.alarms or 0) + affected_rows(Bridge.Database.Query([[
                DELETE FROM `sky_phone_device_data`
                WHERE `device_imei` = ? AND `namespace` = 'alarms' AND `payload` LIKE '%lb-alarm-%'
            ]], { owners[index].device_imei }))
        end

        local migration_numbers = Bridge.Database.Query([[
            SELECT * FROM `sky_phone_migration_numbers` WHERE `source` = ?
        ]], { source_name })
        local created_sims = {}
        for index = 1, #migration_numbers do
            local row = migration_numbers[index]
            local normalized = tostring(row.phone_number)
            local owned_id = deterministic_uuid("lb-phone-sim", normalized)
            local external_id = deterministic_uuid("lb-phone-external-sim", normalized)
            if tostring(row.sim_id) == owned_id or tostring(row.sim_id) == external_id then
                created_sims[#created_sims + 1] = row.sim_id
            end
        end

        stats.ownerMappings = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_migration_owners` WHERE `source` = ?
        ]], { source_name }))
        stats.numberMappings = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_migration_numbers` WHERE `source` = ?
        ]], { source_name }))
        stats.characterDevices = delete_values(
            "sky_phone_character_devices",
            "device_imei",
            created_devices
        )
        stats.devices = delete_values("sky_phone_devices", "imei", created_devices)
        stats.sims = delete_values("sky_phone_sims", "id", created_sims)

        local account_candidates = {}
        for index = 1, #owners do
            account_candidates[#account_candidates + 1] = {
                synthetic_email("lb", owners[index].owner_identifier),
                deterministic_hex("lb-account-password", owners[index].owner_identifier),
            }
        end
        for index = 1, #instagram_accounts do
            local handle = normalize_picstagram_handle(instagram_accounts[index].username)
            if handle then
                account_candidates[#account_candidates + 1] = {
                    synthetic_email("ig", handle),
                    deterministic_hex("lb-phone-picstagram-account", handle),
                }
            end
        end
        local tiktok_accounts = rollback_source_rows("tiktok_accounts", { "username" })
        for index = 1, #tiktok_accounts do
            local handle = normalize_social_handle(tiktok_accounts[index].username, 24, true)
            if handle then
                account_candidates[#account_candidates + 1] = {
                    synthetic_email("flip", handle),
                    deterministic_hex("lb-phone-fliptok-account", handle),
                }
            end
        end
        local twitter_accounts = rollback_source_rows("twitter_accounts", { "username" })
        for index = 1, #twitter_accounts do
            local handle = normalize_social_handle(
                twitter_accounts[index].username,
                Config.Feather.HandleMaxLength,
                false
            )
            if handle then
                account_candidates[#account_candidates + 1] = {
                    synthetic_email("feather", handle),
                    deterministic_hex("lb-phone-feather-account", handle),
                }
            end
        end
        for index = 1, #dark_accounts do
            account_candidates[#account_candidates + 1] = {
                synthetic_email("dark", dark_accounts[index].username),
                deterministic_hex("lb-phone-darkchat-account", dark_accounts[index].username),
            }
        end
        local sender_addresses = {}
        for index = 1, #mail_messages do
            sender_addresses[tostring(mail_messages[index].sender or ""):lower()] = true
        end
        for address in pairs(sender_addresses) do
            account_candidates[#account_candidates + 1] = {
                valid_legacy_email(address) or synthetic_email("mail", address),
                deterministic_hex("lb-phone-mail-account", address),
            }
        end
        local removed_accounts = 0
        for index = 1, #account_candidates do
            removed_accounts = removed_accounts + affected_rows(Bridge.Database.Query([[
                DELETE FROM `sky_phone_accounts` WHERE `email` = ? AND `password` = ?
            ]], account_candidates[index]))
        end
        stats.accounts = removed_accounts
        stats.markers = affected_rows(Bridge.Database.Query([[
            DELETE FROM `sky_phone_migrations` WHERE `source` = ? OR `name` LIKE 'lb-phone:%'
        ]], { source_name }))
        return stats
    end)

    running = false
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] LB Phone migration rollback failed: %s",
            tostring(result),
            { always = true }
        )
        return
    end
    Bridge.Debug(
        "info",
        "[sky_phone] Rollback complete: %s",
        format_rollback_summary(result),
        { always = true }
    )
end

local function announce_lb_phone_source()
    local success, table_count = pcall(function()
        local phones_table = source_table("phones")
        if not table_exists(phones_table)
            or not table_has_column(phones_table, "id")
            or not table_has_column(phones_table, "owner_id")
            or not table_has_column(phones_table, "phone_number")
        then
            return 0
        end

        local found = {}
        for _, tables in pairs(preview_tables) do
            for index = 1, #tables do
                local table_name = source_table(tables[index])
                if not found[table_name] and table_exists(table_name) then
                    found[table_name] = true
                end
            end
        end

        local count = 0
        for _ in pairs(found) do
            count = count + 1
        end
        return count
    end)
    table_count = success and math.max(0, tonumber(table_count) or 0) or 0
    if table_count > 0 then
        Bridge.Debug(
            "info",
            "[sky_phone] LB Phone data detected: %s tables found. Run: skyphone:migrate lb-phone",
            tostring(table_count),
            { notice = true }
        )
    end
end

RegisterCommand("skyphone:migrate", function(command_source, args)
    if command_source ~= 0 then
        Bridge.Debug(
            "warn",
            "[sky_phone] The skyphone:migrate command is server-console only.",
            { always = true }
        )
        return
    end
    local requested_source = tostring(args[1] or "lb-phone"):lower()
    local option = tostring(args[2] or ""):lower()
    if requested_source == "dry" or requested_source == "force"
        or requested_source == "remove" or requested_source == "rollback"
    then
        option = requested_source
        requested_source = "lb-phone"
    end
    if requested_source ~= "lb-phone" and requested_source ~= "lb" then
        Bridge.Debug(
            "error",
            "[sky_phone] Unsupported migration source '%s'. Available source: lb-phone.",
            requested_source,
            { always = true }
        )
        return
    end
    if option == "remove" or option == "rollback" then
        rollback_lb_phone()
        return
    end
    if option ~= "" and option ~= "dry" and option ~= "force" then
        Bridge.Debug(
            "error",
            "[sky_phone] Unsupported migration option '%s'. Use dry, force, or remove.",
            option,
            { always = true }
        )
        return
    end
    run_migration({ dry_run = option == "dry", force = option == "force" })
end, false)

announce_lb_phone_source()
end)
