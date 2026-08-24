Bridge.Database.AfterMigration("sky_phone", function()

local sessions = {}
local profile_locks = {}
local exchange_lock = false
local markets = {}
local market_order = {}
local market_dynamics = {}
local market_state = {}
local market_history = {}
local market_cursor = 1
local market_persistence_interval = 5 * 60 * 1000
local global_market_trend = 0
local global_market_cycle = {
    direction = 0,
    remaining_ticks = 0,
    target = 0,
}

local function ensure_schema()
    local statements = {
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_profiles` (
            `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `account_id` BIGINT UNSIGNED NULL,
            `handle` VARCHAR(20) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
            `crypto_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `password_hash` VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `price_alerts` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1,
            `trade_confirmations` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1,
            `hide_balances` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0,
            `status` ENUM('active','frozen','closed') NOT NULL DEFAULT 'active',
            `failed_logins` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `locked_until` DATETIME NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_sky_phone_crypto_owner` (`owner_identifier`),
            UNIQUE KEY `uniq_sky_phone_crypto_handle` (`handle`),
            UNIQUE KEY `uniq_sky_phone_crypto_key` (`crypto_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_markets` (
            `id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `asset_scale` BIGINT UNSIGNED NOT NULL,
            `price_scale` BIGINT UNSIGNED NOT NULL,
            `issued_supply` DECIMAL(36,0) UNSIGNED NOT NULL,
            `price` DECIMAL(36,0) UNSIGNED NOT NULL,
            `version` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `status` ENUM('active','halted','stale') NOT NULL DEFAULT 'active',
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_market_ticks` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `version` BIGINT UNSIGNED NOT NULL,
            `price` DECIMAL(36,0) UNSIGNED NOT NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_sky_phone_crypto_tick` (`market_id`,`version`),
            KEY `idx_sky_phone_crypto_ticks` (`market_id`,`created_at`,`id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_balances` (
            `account_id` VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `asset_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `available` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
            `locked` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
            `version` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`account_id`,`asset_id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_operations` (
            `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `type` ENUM('buy','sell','deposit','withdrawal','transfer_in','transfer_out') NOT NULL,
            `idempotency_key` VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `request_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `status` ENUM('prepared','external_pending','external_applied','ledger_applied','completed','failed','compensation_pending','manual_review','cancelled') NOT NULL,
            `amount` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
            `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
            `quantity` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
            `counterparty_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NULL,
            `detail` VARCHAR(255) NOT NULL DEFAULT '',
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_sky_phone_crypto_operation` (`profile_id`,`type`,`idempotency_key`),
            KEY `idx_sky_phone_crypto_activity` (`profile_id`,`created_at`,`id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_ledger_entries` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `operation_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `account_id` VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `asset_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `delta` DECIMAL(36,0) NOT NULL,
            `balance_after` DECIMAL(36,0) NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_sky_phone_crypto_ledger_operation` (`operation_id`,`id`),
            KEY `idx_sky_phone_crypto_ledger_account` (`account_id`,`created_at`,`id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_quotes` (
            `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `side` ENUM('buy','sell') NOT NULL,
            `quantity` DECIMAL(36,0) UNSIGNED NOT NULL,
            `price` DECIMAL(36,0) UNSIGNED NOT NULL,
            `gross` DECIMAL(36,0) UNSIGNED NOT NULL,
            `fee` DECIMAL(36,0) UNSIGNED NOT NULL,
            `net` DECIMAL(36,0) UNSIGNED NOT NULL,
            `market_version` BIGINT UNSIGNED NOT NULL,
            `expires_at` DATETIME NOT NULL,
            `consumed_operation_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_sky_phone_crypto_quote_profile` (`profile_id`,`expires_at`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_fills` (
            `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `operation_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `quote_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `side` ENUM('buy','sell') NOT NULL,
            `quantity` DECIMAL(36,0) UNSIGNED NOT NULL,
            `price` DECIMAL(36,0) UNSIGNED NOT NULL,
            `gross` DECIMAL(36,0) UNSIGNED NOT NULL,
            `fee` DECIMAL(36,0) UNSIGNED NOT NULL,
            `net` DECIMAL(36,0) UNSIGNED NOT NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_sky_phone_crypto_fill_quote` (`quote_id`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_settlements` (
            `operation_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `framework_account` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `amount` DECIMAL(36,0) UNSIGNED NOT NULL,
            `state` ENUM('prepared','external_pending','external_applied','ledger_applied','completed','failed','compensation_pending','manual_review','cancelled') NOT NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`operation_id`),
            KEY `idx_sky_phone_crypto_settlement_state` (`state`,`updated_at`)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS `sky_phone_crypto_audit_events` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
            `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
            `event_type` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            `detail` VARCHAR(255) NOT NULL DEFAULT '',
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_sky_phone_crypto_audit` (`profile_id`,`created_at`,`id`)
        ) ENGINE=InnoDB]],
    }
    for _, statement in ipairs(statements) do
        Bridge.Database.Query(statement, {})
    end
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_profiles` ADD COLUMN IF NOT EXISTS `price_alerts` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1 AFTER `password_hash`", {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_profiles` ADD COLUMN IF NOT EXISTS `trade_confirmations` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1 AFTER `price_alerts`", {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_profiles` ADD COLUMN IF NOT EXISTS `hide_balances` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 AFTER `trade_confirmations`", {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_profiles` ADD COLUMN IF NOT EXISTS `crypto_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER `handle`", {})
    Bridge.Database.Query([[ALTER TABLE `sky_phone_crypto_operations`
        MODIFY COLUMN `type` ENUM('buy','sell','deposit','withdrawal','transfer_in','transfer_out') NOT NULL]], {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_operations` ADD COLUMN IF NOT EXISTS `quantity` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0 AFTER `market_id`", {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_operations` ADD COLUMN IF NOT EXISTS `counterparty_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER `quantity`", {})
    Bridge.Database.Query("ALTER TABLE `sky_phone_crypto_operations` MODIFY COLUMN `counterparty_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NULL", {})
end

local function new_id()
    local row = Bridge.Database.Query("SELECT UUID() AS `id`", {})[1]
    if not row or type(row.id) ~= "string" then
        error("[sky_phone] Database did not generate a Crypto id.")
    end
    return row.id
end

local function crypto_key_from_entropy(entropy)
    local compact = entropy:gsub("-", ""):upper()
    return ("VX-%s-%s-%s-%s"):format(
        compact:sub(1, 4),
        compact:sub(5, 8),
        compact:sub(9, 12),
        compact:sub(13, 16)
    )
end

local function new_crypto_key()
    for _ = 1, 5 do
        local candidate = crypto_key_from_entropy(new_id())
        local duplicate = Bridge.Database.Query(
            "SELECT 1 FROM `sky_phone_crypto_profiles` WHERE `crypto_key` = ? LIMIT 1",
            { candidate }
        )[1]
        if not duplicate then
            return candidate
        end
    end
    error("[sky_phone] Database did not generate a unique Crypto key.")
end

local function migrate_crypto_keys()
    local rows = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_crypto_profiles` WHERE `crypto_key` IS NULL OR `crypto_key` = ''",
        {}
    )
    for _, row in ipairs(rows) do
        Bridge.Database.Query(
            "UPDATE `sky_phone_crypto_profiles` SET `crypto_key` = ? WHERE `id` = ? AND (`crypto_key` IS NULL OR `crypto_key` = '')",
            { new_crypto_key(), row.id }
        )
    end
    Bridge.Database.Query(
        "ALTER TABLE `sky_phone_crypto_profiles` MODIFY COLUMN `crypto_key` CHAR(22) CHARACTER SET ascii COLLATE ascii_bin NOT NULL",
        {}
    )
    local index = Bridge.Database.Query([[
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = 'sky_phone_crypto_profiles'
            AND index_name = 'uniq_sky_phone_crypto_key' LIMIT 1
    ]], {})[1]
    if not index then
        Bridge.Database.Query(
            "ALTER TABLE `sky_phone_crypto_profiles` ADD UNIQUE KEY `uniq_sky_phone_crypto_key` (`crypto_key`)",
            {}
        )
    end
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function account_id(profile_id)
    return "profile:" .. profile_id
end

local function valid_handle(value)
    if type(value) ~= "string" then
        return nil
    end
    local handle = value:match("^%s*(.-)%s*$")
    local length = utf8.len(handle)
    if not length or length < Config.Crypto.HandleMinLength or length > Config.Crypto.HandleMaxLength
        or not handle:match("^[A-Za-z0-9][A-Za-z0-9._]*[A-Za-z0-9]$")
    then
        return nil
    end
    return handle
end

local function valid_password(value)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= Config.Crypto.PasswordMinLength
        and length <= Config.Crypto.PasswordMaxLength
end

local function valid_new_password(value)
    return valid_password(value)
        and value:match("%l")
        and value:match("%u")
        and value:match("%d")
        and value:match("[^%w]")
end

local function valid_crypto_key(value)
    if type(value) ~= "string" then
        return nil
    end
    local key = value:upper():match("^%s*(.-)%s*$")
    return key:match("^VX%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x$") and key or nil
end

local function parse_whole(value, minimum, maximum)
    if type(value) ~= "string" or not value:match("^%d+$") then
        return nil
    end
    local amount = tonumber(value)
    if not amount or amount ~= math.floor(amount) or amount < minimum or amount > maximum then
        return nil
    end
    return amount
end

local function parse_quantity(value)
    if type(value) ~= "string" then
        return nil
    end
    local whole, decimal = value:match("^(%d+)%.?(%d*)$")
    if not whole or #decimal > 6 then
        return nil
    end
    decimal = decimal .. string.rep("0", 6 - #decimal)
    local quantity = tonumber(whole) * Config.Crypto.AssetScale + tonumber(decimal)
    if quantity <= 0 or quantity > 1000000 * Config.Crypto.AssetScale then
        return nil
    end
    return quantity
end

local function decimal_string(value, scale)
    value = math.floor(tonumber(value) or 0)
    if scale == 1 then
        return tostring(value)
    end
    local digits = tostring(scale):len() - 1
    local whole = math.floor(value / scale)
    local fraction = tostring(value % scale)
    fraction = string.rep("0", digits - #fraction) .. fraction
    fraction = fraction:gsub("0+$", "")
    return fraction == "" and tostring(whole) or (tostring(whole) .. "." .. fraction)
end

local function ceil_div(value, divisor)
    return math.floor((value + divisor - 1) / divisor)
end

local function initialize_markets()
    local next_markets = {}
    local next_market_order = {}
    local next_market_dynamics = {}
    for _, config in ipairs(Config.Crypto.Markets) do
        if next_markets[config.Id] then
            error(("[sky_phone] Config.Crypto.Markets contains duplicate id '%s'."):format(config.Id))
        end
        next_markets[config.Id] = config
        next_market_order[#next_market_order + 1] = config.Id
        next_market_dynamics[config.Id] = market_dynamics[config.Id]
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_crypto_markets`
                (`id`,`asset_scale`,`price_scale`,`issued_supply`,`price`,`version`,`status`)
            VALUES (?, ?, ?, ?, ?, 1, 'active') ON DUPLICATE KEY UPDATE `id` = VALUES(`id`)
        ]], {
            config.Id,
            Config.Crypto.AssetScale,
            Config.Crypto.PriceScale,
            config.IssuedSupply * Config.Crypto.AssetScale,
            config.InitialPrice,
        })
        local persisted = Bridge.Database.Query([[
            SELECT `asset_scale`,`price_scale`,`issued_supply`
            FROM `sky_phone_crypto_markets` WHERE `id` = ? LIMIT 1
        ]], { config.Id })[1]
        if not persisted
            or tonumber(persisted.asset_scale) ~= Config.Crypto.AssetScale
            or tonumber(persisted.price_scale) ~= Config.Crypto.PriceScale
            or tonumber(persisted.issued_supply) ~= config.IssuedSupply * Config.Crypto.AssetScale
        then
            error(("[sky_phone] Crypto market scale or supply changed without a migration: %s"):format(config.Id))
        end
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_crypto_balances` (`account_id`,`asset_id`,`available`)
            VALUES ('treasury', ?, ?) ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`)
        ]], { config.Id, config.TreasuryInventory * Config.Crypto.AssetScale })
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_crypto_balances` (`account_id`,`asset_id`,`available`)
            VALUES ('reserve', ?, ?) ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`)
        ]], {
            config.Id,
            (config.IssuedSupply - config.TreasuryInventory) * Config.Crypto.AssetScale,
        })
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crypto_balances` (`account_id`,`asset_id`,`available`)
        VALUES ('treasury', 'CASH', ?) ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`)
    ]], { Config.Crypto.TreasuryCash * Config.Crypto.PriceScale })
    markets = next_markets
    market_order = next_market_order
    market_dynamics = next_market_dynamics
    market_cursor = math.min(market_cursor, math.max(#market_order, 1))
end

local function load_market_cache()
    local rows = Bridge.Database.Query([[
        SELECT `id`,`price`,`version`,`status`, UNIX_TIMESTAMP(`updated_at`) AS `updated_at`
        FROM `sky_phone_crypto_markets`
    ]], {})
    local next_market_state = {}
    local next_market_history = {}
    for _, row in ipairs(rows) do
        if markets[row.id] then
            next_market_state[row.id] = {
                price = tonumber(row.price) or markets[row.id].InitialPrice,
                version = tonumber(row.version) or 1,
                status = row.status,
                updated_at = tonumber(row.updated_at) or os.time(),
                dirty = false,
            }
        end
    end
    for _, market_id in ipairs(market_order) do
        local state = next_market_state[market_id]
        if not state then
            error(("[sky_phone] Crypto market state is missing after initialization: %s"):format(market_id))
        end
        local rows_for_market = Bridge.Database.Query([[
            SELECT `price`,`version`, UNIX_TIMESTAMP(`created_at`) AS `created_at`
            FROM `sky_phone_crypto_market_ticks`
            WHERE `market_id` = ? ORDER BY `id` DESC LIMIT ?
        ]], { market_id, Config.Crypto.HistoryRetentionTicks })
        local history = {}
        for index = #rows_for_market, 1, -1 do
            local tick = rows_for_market[index]
            history[#history + 1] = {
                price = tonumber(tick.price) or state.price,
                version = tonumber(tick.version) or state.version,
                created_at = tonumber(tick.created_at) or state.updated_at,
            }
        end
        if #history == 0 then
            history[1] = {
                price = state.price,
                version = state.version,
                created_at = state.updated_at,
            }
        end
        next_market_history[market_id] = history
    end
    market_state = next_market_state
    market_history = next_market_history
end

local function persist_market_cache()
    local queries = {}
    local persisted_markets = {}
    for _, market_id in ipairs(market_order) do
        local state = market_state[market_id]
        if state and state.dirty then
            queries[#queries + 1] = {
                query = [[
                    UPDATE `sky_phone_crypto_markets`
                    SET `price` = ?, `version` = ?, `status` = ?, `updated_at` = FROM_UNIXTIME(?)
                    WHERE `id` = ?
                ]],
                params = { state.price, state.version, state.status, state.updated_at, market_id },
            }
            queries[#queries + 1] = {
                query = [[
                    INSERT INTO `sky_phone_crypto_market_ticks`
                        (`market_id`,`version`,`price`,`created_at`) VALUES (?, ?, ?, FROM_UNIXTIME(?))
                ]],
                params = { market_id, state.version, state.price, state.updated_at },
            }
            persisted_markets[#persisted_markets + 1] = market_id
        end
    end
    if #queries == 0 then
        return true
    end
    queries[#queries + 1] = {
        query = [[
            DELETE FROM `sky_phone_crypto_market_ticks`
            WHERE `created_at` < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 24 HOUR)
        ]],
        params = {},
    }
    if not Bridge.Database.Transaction(queries) then
        print("[sky_phone] Failed to persist the crypto market cache.")
        return false
    end
    for _, market_id in ipairs(persisted_markets) do
        market_state[market_id].dirty = false
    end
    return true
end

local function require_phone(source)
    local phone_session, error_response = SkyPhone.RequireSession(source)
    if not phone_session then
        return nil, nil, error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, nil, { success = false, error = "service_unavailable" }
    end
    return phone_session, identifier
end

local function profile_by_owner(identifier)
    return Bridge.Database.Query([[
        SELECT `id`,`owner_identifier`,`account_id`,`handle`,`crypto_key`,`status`,`failed_logins`,
            `price_alerts`,`trade_confirmations`,`hide_balances`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at`,
            UNIX_TIMESTAMP(`locked_until`) AS `locked_until`
        FROM `sky_phone_crypto_profiles` WHERE `owner_identifier` = ? LIMIT 1
    ]], { identifier })[1]
end

local function profile_by_crypto_key(wallet_key)
    return Bridge.Database.Query([[
        SELECT `id`,`owner_identifier`,`handle`,`crypto_key`,`status`
        FROM `sky_phone_crypto_profiles` WHERE `crypto_key` = ? LIMIT 1
    ]], { wallet_key })[1]
end

local function authenticated_profile(source)
    local phone_session, identifier, error_response = require_phone(source)
    if not phone_session then
        return nil, error_response
    end
    local session = sessions[source]
    if not session or session.identifier ~= identifier or session.imei ~= phone_session.imei
        or session.expires_at < os.time()
    then
        sessions[source] = nil
        return nil, { success = false, error = "not_authenticated" }
    end
    local profile = profile_by_owner(identifier)
    if not profile or profile.id ~= session.profile_id or profile.status ~= "active" then
        sessions[source] = nil
        return nil, { success = false, error = "not_authenticated" }
    end
    session.expires_at = os.time() + Config.Crypto.SessionSeconds
    return profile
end

local function verify_password(profile_id, password)
    if not valid_password(password) then
        return false
    end
    local row = Bridge.Database.Query(
        "SELECT `password_hash` FROM `sky_phone_crypto_profiles` WHERE `id` = ? LIMIT 1",
        { profile_id }
    )[1]
    return row and exports[GetCurrentResourceName()]:CryptoVerifyPassword(password, row.password_hash) or false
end

local function set_session(source, phone_session, profile, recently_authenticated)
    sessions[source] = {
        expires_at = os.time() + Config.Crypto.SessionSeconds,
        identifier = profile.owner_identifier,
        imei = phone_session.imei,
        profile_id = profile.id,
        recently_authenticated_at = recently_authenticated and os.time() or 0,
    }
end

local function balance(account, asset)
    local row = Bridge.Database.Query([[
        SELECT `available`,`locked`,`version` FROM `sky_phone_crypto_balances`
        WHERE `account_id` = ? AND `asset_id` = ? LIMIT 1
    ]], { account, asset })[1]
    return row and (tonumber(row.available) or 0) or 0,
        row and (tonumber(row.locked) or 0) or 0,
        row and (tonumber(row.version) or 0) or 0
end

local function market_dtos(selected_market_ids)
    local selected = nil
    if selected_market_ids then
        selected = {}
        for _, market_id in ipairs(selected_market_ids) do
            selected[market_id] = true
        end
    end
    local result = {}
    for _, market_id in ipairs(market_order) do
        if not selected or selected[market_id] then
            local config = markets[market_id]
            local row = market_state[market_id]
            local history = market_history[market_id]
            local prices = {}
            local first_history_index = math.max(1, #history - Config.Crypto.SparklinePoints + 1)
            for index = first_history_index, #history do
                prices[#prices + 1] = history[index].price
            end
            if #prices == 0 then
                prices[1] = tonumber(row.price)
            end
            local minimum = math.min(table.unpack(prices))
            local maximum = math.max(table.unpack(prices))
            local span = math.max(1, maximum - minimum)
            local sparkline = {}
            local price_history = {}
            for index, historical_price in ipairs(prices) do
                sparkline[index] = (historical_price - minimum) / span
                price_history[index] = decimal_string(historical_price, Config.Crypto.PriceScale)
            end
            local first = prices[1]
            local price = tonumber(row.price) or config.InitialPrice
            local daily_low = price
            local daily_high = price
            local daily_cutoff = os.time() - 24 * 60 * 60
            for index = #history, 1, -1 do
                local tick = history[index]
                if tick.created_at < daily_cutoff then
                    break
                end
                daily_low = math.min(daily_low, tick.price)
                daily_high = math.max(daily_high, tick.price)
            end
            result[#result + 1] = {
                id = market_id,
                symbol = config.Symbol,
                name = config.Name,
                color = config.Color,
                logo = config.Logo,
                price = decimal_string(price, Config.Crypto.PriceScale),
                changePercent = first > 0 and ((price - first) / first) * 100 or 0,
                enabled = row.status == "active",
                high24h = decimal_string(daily_high, Config.Crypto.PriceScale),
                low24h = decimal_string(daily_low, Config.Crypto.PriceScale),
                issuedSupply = decimal_string(config.IssuedSupply * Config.Crypto.AssetScale, Config.Crypto.AssetScale),
                treasuryAvailable = decimal_string(balance("treasury", market_id), Config.Crypto.AssetScale),
                priceHistory = price_history,
                sparkline = sparkline,
                updatedAt = (tonumber(row.updated_at) or os.time()) * 1000,
            }
        end
    end
    return result
end

local function activity(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT `id`,`type`,`amount`,`market_id`,`quantity`,`counterparty_key`,`status`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at`
        FROM `sky_phone_crypto_operations` WHERE `profile_id` = ?
        ORDER BY `created_at` DESC, `id` DESC LIMIT 50
    ]], { profile_id })
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = {
            id = row.id,
            type = row.type,
            amount = decimal_string(row.amount, Config.Crypto.PriceScale),
            quantity = decimal_string(row.quantity, Config.Crypto.AssetScale),
            counterpartyKey = row.counterparty_key,
            marketId = row.market_id,
            status = row.status,
            createdAt = (tonumber(row.created_at) or 0) * 1000,
        }
    end
    return result
end

local function daily_total(profile_id, operation_type)
    local row = Bridge.Database.Query([[
        SELECT COALESCE(SUM(`amount`), 0) AS `total`
        FROM `sky_phone_crypto_operations`
        WHERE `profile_id` = ? AND `type` = ? AND `status` = 'completed'
            AND `created_at` >= CURRENT_DATE
    ]], { profile_id, operation_type })[1]
    return tonumber(row and row.total) or 0
end

local function bootstrap(profile)
    local cash = balance(account_id(profile.id), "CASH")
    local holdings = {}
    local portfolio = cash
    for _, market_id in ipairs(market_order) do
        local available = balance(account_id(profile.id), market_id)
        if available > 0 then
            local price = tonumber(market_state[market_id].price) or 0
            local value = math.floor(available * price / Config.Crypto.AssetScale)
            local fill = Bridge.Database.Query([[
                SELECT FLOOR(SUM(fill.`gross`) * ? / NULLIF(SUM(fill.`quantity`), 0)) AS `price`
                FROM `sky_phone_crypto_fills` fill
                JOIN `sky_phone_crypto_operations` operation ON operation.`id` = fill.`operation_id`
                WHERE operation.`profile_id` = ? AND fill.`market_id` = ? AND fill.`side` = 'buy'
            ]], { Config.Crypto.AssetScale, profile.id, market_id })[1]
            holdings[#holdings + 1] = {
                assetId = market_id,
                quantity = decimal_string(available, Config.Crypto.AssetScale),
                value = decimal_string(value, Config.Crypto.PriceScale),
                averagePrice = decimal_string(fill and fill.price or price, Config.Crypto.PriceScale),
            }
            portfolio = portfolio + value
        end
    end
    local metrics = Bridge.Database.Query([[
        SELECT COUNT(*) AS `total_trades`, COALESCE(SUM(`amount`), 0) AS `total_volume`
        FROM `sky_phone_crypto_operations`
        WHERE `profile_id` = ? AND `type` IN ('buy','sell') AND `status` = 'completed'
    ]], { profile.id })[1]
    return {
        authenticated = true,
        profile = {
            id = profile.id,
            handle = profile.handle,
            walletKey = profile.crypto_key,
            status = profile.status,
            createdAt = (tonumber(profile.created_at) or 0) * 1000,
            hideBalances = tonumber(profile.hide_balances) == 1,
            priceAlerts = tonumber(profile.price_alerts) == 1,
            tradeConfirmations = tonumber(profile.trade_confirmations) == 1,
            totalTrades = tonumber(metrics and metrics.total_trades) or 0,
            totalVolume = decimal_string(metrics and metrics.total_volume, Config.Crypto.PriceScale),
        },
        cashBalance = decimal_string(cash, Config.Crypto.PriceScale),
        portfolioValue = decimal_string(portfolio, Config.Crypto.PriceScale),
        holdings = holdings,
        markets = market_dtos(),
        activity = activity(profile.id),
        registered = true,
    }
end

local function audit(profile_id, identifier, event_type, detail)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crypto_audit_events`
            (`profile_id`,`owner_identifier`,`event_type`,`detail`) VALUES (?, ?, ?, ?)
    ]], { profile_id, identifier, event_type, detail or "" })
end

local function idempotency_key(value)
    if type(value) ~= "string" or #value < 8 or #value > 96
        or not value:match("^[A-Za-z0-9._-]+$")
    then
        return nil
    end
    return value
end

local function with_profile_lock(profile_id, callback)
    if profile_locks[profile_id] then
        return { success = false, error = "rate_limited" }
    end
    profile_locks[profile_id] = true
    local success, result = pcall(callback)
    profile_locks[profile_id] = nil
    if not success then
        error(result)
    end
    return result
end

local function with_exchange_lock(callback)
    if exchange_lock then
        return { success = false, error = "rate_limited" }
    end
    exchange_lock = true
    local success, result = pcall(callback)
    exchange_lock = false
    if not success then
        error(result)
    end
    return result
end

Bridge.Callbacks.Register("sky_phone:crypto:bootstrap", function(source)
    if not Config.Crypto.Enabled then
        return { success = false, error = "service_unavailable" }
    end
    local profile, error_response = authenticated_profile(source)
    if profile then
        return { success = true, data = bootstrap(profile) }
    end
    local _, identifier, phone_error = require_phone(source)
    if not identifier then
        return phone_error
    end
    local existing = profile_by_owner(identifier)
    return {
        success = true,
        data = {
            authenticated = false,
            profile = nil,
            cashBalance = "0",
            portfolioValue = "0",
            holdings = {},
            markets = market_dtos(),
            activity = {},
            registered = existing ~= nil,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:crypto:register", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:register", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    local phone_session, identifier, error_response = require_phone(source)
    if not phone_session then
        return error_response
    end
    local account, account_error = SkyPhone.RequireAccount(source)
    if not account then
        return account_error
    end
    data = type(data) == "table" and data or {}
    local handle = valid_handle(data.handle)
    if not handle then
        return { success = false, error = "invalid_handle" }
    end
    if not valid_new_password(data.password) then
        return { success = false, error = "invalid_password" }
    end
    if profile_by_owner(identifier) then
        return { success = false, error = "profile_exists" }
    end
    local duplicate = Bridge.Database.Query(
        "SELECT 1 FROM `sky_phone_crypto_profiles` WHERE `handle` = ? LIMIT 1",
        { handle }
    )
    if duplicate[1] then
        return { success = false, error = "handle_taken" }
    end
    local profile_id = new_id()
    local wallet_key = new_crypto_key()
    local password_hash = exports[GetCurrentResourceName()]:CryptoHashPassword(data.password)
    if type(password_hash) ~= "string" then
        error("[sky_phone] Crypto password provider did not return a password hash.")
    end
    local queries = {
        {
            query = [[INSERT INTO `sky_phone_crypto_profiles`
                (`id`,`owner_identifier`,`account_id`,`handle`,`crypto_key`,`password_hash`)
                VALUES (?, ?, ?, ?, ?, ?)]],
            params = { profile_id, identifier, account.id, handle, wallet_key, password_hash },
        },
        {
            query = [[INSERT INTO `sky_phone_crypto_balances`
                (`account_id`,`asset_id`,`available`) VALUES (?, 'CASH', 0)]],
            params = { account_id(profile_id) },
        },
    }
    if not Bridge.Database.Transaction(queries) then
        return { success = false, error = "request_failed" }
    end
    local profile = profile_by_owner(identifier)
    set_session(source, phone_session, profile, true)
    audit(profile.id, identifier, "profile_registered", "")
    return { success = true, data = bootstrap(profile) }
end)

Bridge.Callbacks.Register("sky_phone:crypto:login", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:login", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local phone_session, identifier, error_response = require_phone(source)
    if not phone_session then
        return error_response
    end
    local profile = profile_by_owner(identifier)
    if not profile then
        return { success = false, error = "invalid_credentials" }
    end
    if tonumber(profile.locked_until) and tonumber(profile.locked_until) > os.time() then
        return { success = false, error = "locked" }
    end
    if not verify_password(profile.id, type(data) == "table" and data.password or nil) then
        local failed = (tonumber(profile.failed_logins) or 0) + 1
        local lock = failed >= Config.Crypto.LoginAttempts
        Bridge.Database.Query([[
            UPDATE `sky_phone_crypto_profiles` SET `failed_logins` = ?,
                `locked_until` = IF(?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND), NULL)
            WHERE `id` = ?
        ]], { lock and 0 or failed, lock and 1 or 0, Config.Crypto.LockoutSeconds, profile.id })
        audit(profile.id, identifier, "login_failed", lock and "profile_locked" or "invalid_password")
        return { success = false, error = lock and "locked" or "invalid_credentials" }
    end
    Bridge.Database.Query(
        "UPDATE `sky_phone_crypto_profiles` SET `failed_logins` = 0, `locked_until` = NULL WHERE `id` = ?",
        { profile.id }
    )
    set_session(source, phone_session, profile, true)
    audit(profile.id, identifier, "login_succeeded", phone_session.imei)
    return { success = true, data = bootstrap(profile) }
end)

Bridge.Callbacks.Register("sky_phone:crypto:logout", function(source)
    local session = sessions[source]
    if session then
        audit(session.profile_id, session.identifier, "logout", "")
    end
    sessions[source] = nil
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crypto:update-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:update-profile", 8, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = authenticated_profile(source)
    if not profile then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local handle = valid_handle(data.handle)
    if not handle or type(data.priceAlerts) ~= "boolean"
        or type(data.tradeConfirmations) ~= "boolean" or type(data.hideBalances) ~= "boolean"
    then
        return { success = false, error = "invalid_profile" }
    end
    local handle_changed = handle:lower() ~= profile.handle:lower()
    local new_password = type(data.newPassword) == "string" and data.newPassword or ""
    local password_changed = new_password ~= ""
    if password_changed and not valid_new_password(new_password) then
        return { success = false, error = "invalid_password" }
    end
    if handle_changed or password_changed then
        if not verify_password(profile.id, data.currentPassword) then
            audit(profile.id, profile.owner_identifier, "profile_update_reauth_failed", "")
            return { success = false, error = "invalid_credentials" }
        end
        sessions[source].recently_authenticated_at = os.time()
    end
    if handle_changed then
        local duplicate = Bridge.Database.Query(
            "SELECT 1 FROM `sky_phone_crypto_profiles` WHERE `handle` = ? AND `id` <> ? LIMIT 1",
            { handle, profile.id }
        )
        if duplicate[1] then
            return { success = false, error = "handle_taken" }
        end
    end
    if password_changed then
        local password_hash = exports[GetCurrentResourceName()]:CryptoHashPassword(new_password)
        if type(password_hash) ~= "string" then
            return { success = false, error = "service_unavailable" }
        end
        Bridge.Database.Query([[
            UPDATE `sky_phone_crypto_profiles`
            SET `handle` = ?, `password_hash` = ?, `price_alerts` = ?,
                `trade_confirmations` = ?, `hide_balances` = ?
            WHERE `id` = ?
        ]], {
            handle,
            password_hash,
            data.priceAlerts and 1 or 0,
            data.tradeConfirmations and 1 or 0,
            data.hideBalances and 1 or 0,
            profile.id,
        })
    else
        Bridge.Database.Query([[
            UPDATE `sky_phone_crypto_profiles`
            SET `handle` = ?, `price_alerts` = ?, `trade_confirmations` = ?, `hide_balances` = ?
            WHERE `id` = ?
        ]], {
            handle,
            data.priceAlerts and 1 or 0,
            data.tradeConfirmations and 1 or 0,
            data.hideBalances and 1 or 0,
            profile.id,
        })
    end
    audit(
        profile.id,
        profile.owner_identifier,
        "profile_updated",
        (handle_changed and "handle" or "preferences") .. (password_changed and ",password" or "")
    )
    return { success = true, data = bootstrap(profile_by_owner(profile.owner_identifier)) }
end)

Bridge.Callbacks.Register("sky_phone:crypto:recipient", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:recipient", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = authenticated_profile(source)
    if not profile then
        return error_response
    end
    local wallet_key = valid_crypto_key(type(data) == "table" and data.walletKey or nil)
    if not wallet_key then
        return { success = false, error = "invalid_wallet_key" }
    end
    local recipient = profile_by_crypto_key(wallet_key)
    if not recipient or recipient.status ~= "active" then
        return { success = false, error = "recipient_not_found" }
    end
    if recipient.id == profile.id then
        return { success = false, error = "self_transfer" }
    end
    return {
        success = true,
        data = {
            handle = recipient.handle,
            walletKey = recipient.crypto_key,
        },
    }
end)

local function execute_transfer(profile, data)
    local key = idempotency_key(data.idempotencyKey)
    local wallet_key = valid_crypto_key(data.walletKey)
    local quantity = parse_quantity(data.quantity)
    local market = markets[data.marketId]
    if not key or not wallet_key or not quantity or not market then
        return { success = false, error = "invalid_transfer" }
    end
    if quantity > Config.Crypto.MaximumTransferQuantity * Config.Crypto.AssetScale then
        return { success = false, error = "limit_exceeded" }
    end
    if not verify_password(profile.id, data.password) then
        audit(profile.id, profile.owner_identifier, "transfer_reauth_failed", "")
        return { success = false, error = "invalid_credentials" }
    end
    local recipient = profile_by_crypto_key(wallet_key)
    if not recipient or recipient.status ~= "active" then
        return { success = false, error = "recipient_not_found" }
    end
    if recipient.id == profile.id then
        return { success = false, error = "self_transfer" }
    end
    local existing = Bridge.Database.Query([[
        SELECT `status` FROM `sky_phone_crypto_operations`
        WHERE `profile_id` = ? AND `type` = 'transfer_out' AND `idempotency_key` = ? LIMIT 1
    ]], { profile.id, key })[1]
    if existing then
        return existing.status == "completed"
            and { success = true, data = bootstrap(profile) }
            or { success = false, error = "duplicate_request" }
    end
    local sender_account = account_id(profile.id)
    local recipient_account = account_id(recipient.id)
    if balance(sender_account, market.Id) < quantity then
        return { success = false, error = "insufficient_funds" }
    end
    if balance(recipient_account, market.Id) + quantity
        > Config.Crypto.MaximumPositionQuantity * Config.Crypto.AssetScale
    then
        return { success = false, error = "recipient_limit_exceeded" }
    end
    local sender_operation = new_id()
    local recipient_operation = new_id()
    local request_hash = Bridge.Database.Query(
        "SELECT SHA2(CONCAT(?, ':', ?, ':', ?, ':', ?), 256) AS `hash`",
        { profile.id, recipient.id, market.Id, quantity }
    )[1].hash
    local queries = {
        {
            query = [[INSERT INTO `sky_phone_crypto_operations`
                (`id`,`profile_id`,`type`,`idempotency_key`,`request_hash`,`status`,`market_id`,`quantity`,`counterparty_key`)
                VALUES (?, ?, 'transfer_out', ?, ?, 'completed', ?, ?, ?)]],
            params = {
                sender_operation,
                profile.id,
                key,
                request_hash,
                market.Id,
                quantity,
                recipient.crypto_key,
            },
        },
        {
            query = [[INSERT INTO `sky_phone_crypto_operations`
                (`id`,`profile_id`,`type`,`idempotency_key`,`request_hash`,`status`,`market_id`,`quantity`,`counterparty_key`)
                VALUES (?, ?, 'transfer_in', ?, ?, 'completed', ?, ?, ?)]],
            params = {
                recipient_operation,
                recipient.id,
                "incoming-" .. sender_operation,
                request_hash,
                market.Id,
                quantity,
                profile.crypto_key,
            },
        },
        {
            query = [[UPDATE `sky_phone_crypto_balances`
                SET `available` = `available` - ?, `version` = `version` + 1
                WHERE `account_id` = ? AND `asset_id` = ? AND `available` >= ?]],
            params = { quantity, sender_account, market.Id, quantity },
        },
        {
            query = [[INSERT INTO `sky_phone_crypto_balances`
                (`account_id`,`asset_id`,`available`,`version`) VALUES (?, ?, ?, 1)
                ON DUPLICATE KEY UPDATE `available` = `available` + VALUES(`available`),
                    `version` = `version` + 1]],
            params = { recipient_account, market.Id, quantity },
        },
        {
            query = [[INSERT INTO `sky_phone_crypto_ledger_entries`
                (`operation_id`,`account_id`,`asset_id`,`delta`)
                VALUES (?, ?, ?, ?), (?, ?, ?, ?)]],
            params = {
                sender_operation,
                sender_account,
                market.Id,
                -quantity,
                sender_operation,
                recipient_account,
                market.Id,
                quantity,
            },
        },
    }
    if not Bridge.Database.Transaction(queries) then
        return { success = false, error = "request_failed" }
    end
    sessions[source].recently_authenticated_at = os.time()
    audit(profile.id, profile.owner_identifier, "transfer_sent", sender_operation)
    audit(recipient.id, recipient.owner_identifier, "transfer_received", sender_operation)
    for target_source, session in pairs(sessions) do
        if session.profile_id == recipient.id then
            TriggerClientEvent("sky_phone:crypto:account-changed", target_source)
        end
    end
    return { success = true, data = bootstrap(profile) }
end

Bridge.Callbacks.Register("sky_phone:crypto:transfer", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:transfer", 12, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = authenticated_profile(source)
    if not profile then
        return error_response
    end
    return with_profile_lock(profile.id, function()
        return with_exchange_lock(function()
            return execute_transfer(profile, type(data) == "table" and data or {})
        end)
    end)
end)

Bridge.Callbacks.Register("sky_phone:crypto:quote", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:quote", Config.Crypto.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = authenticated_profile(source)
    if not profile then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local config = markets[data.marketId]
    local side = data.side == "buy" and "buy" or data.side == "sell" and "sell" or nil
    local quantity = parse_quantity(data.quantity)
    if not config or not side or not quantity then
        return { success = false, error = "invalid_quantity" }
    end
    local market = market_state[config.Id]
    if not market or market.status ~= "active" then
        return { success = false, error = "market_unavailable" }
    end
    local spread_bps = 40
    local reference = tonumber(market.price)
    local price = side == "buy"
        and ceil_div(reference * (10000 + spread_bps), 10000)
        or math.floor(reference * (10000 - spread_bps) / 10000)
    local gross = side == "buy"
        and ceil_div(quantity * price, Config.Crypto.AssetScale)
        or math.floor(quantity * price / Config.Crypto.AssetScale)
    local fee = math.max(Config.Crypto.MinimumFee, ceil_div(gross * Config.Crypto.FeeBasisPoints, 10000))
    local net = side == "buy" and gross + fee or gross - fee
    if gross <= 0 or net <= 0 or gross > Config.Crypto.MaximumTradeNotional * Config.Crypto.PriceScale then
        return { success = false, error = "limit_exceeded" }
    end
    if side == "buy" then
        if balance(account_id(profile.id), config.Id) + quantity
            > Config.Crypto.MaximumPositionQuantity * Config.Crypto.AssetScale
        then
            return { success = false, error = "limit_exceeded" }
        end
        if balance(account_id(profile.id), "CASH") < net then
            return { success = false, error = "insufficient_funds" }
        end
        if balance("treasury", config.Id) < quantity then
            return { success = false, error = "insufficient_liquidity" }
        end
    else
        if balance(account_id(profile.id), config.Id) < quantity then
            return { success = false, error = "insufficient_funds" }
        end
        if balance("treasury", "CASH") < net then
            return { success = false, error = "insufficient_liquidity" }
        end
    end
    if daily_total(profile.id, side) + net > Config.Crypto.DailyTradeLimit * Config.Crypto.PriceScale then
        return { success = false, error = "limit_exceeded" }
    end
    local quote_id = new_id()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crypto_quotes`
            (`id`,`profile_id`,`market_id`,`side`,`quantity`,`price`,`gross`,`fee`,`net`,`market_version`,`expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND))
    ]], {
        quote_id, profile.id, config.Id, side, quantity, price, gross, fee, net,
        market.version, Config.Crypto.QuoteLifetimeSeconds,
    })
    return {
        success = true,
        data = {
            id = quote_id,
            marketId = config.Id,
            side = side,
            quantity = decimal_string(quantity, Config.Crypto.AssetScale),
            price = decimal_string(price, Config.Crypto.PriceScale),
            gross = decimal_string(gross, Config.Crypto.PriceScale),
            fee = decimal_string(fee, Config.Crypto.PriceScale),
            net = decimal_string(net, Config.Crypto.PriceScale),
            expiresAt = (os.time() + Config.Crypto.QuoteLifetimeSeconds) * 1000,
        },
    }
end)

local function execute_trade(profile, data)
    local key = idempotency_key(data.idempotencyKey)
    if not key or type(data.quoteId) ~= "string" or #data.quoteId ~= 36 then
        return { success = false, error = "quote_unavailable" }
    end
    local existing = Bridge.Database.Query([[
        SELECT `status` FROM `sky_phone_crypto_operations`
        WHERE `profile_id` = ? AND `idempotency_key` = ? LIMIT 1
    ]], { profile.id, key })[1]
    if existing then
        return existing.status == "completed"
            and { success = true, data = bootstrap(profile) }
            or { success = false, error = "duplicate_request" }
    end
    local quote = Bridge.Database.Query([[
        SELECT quote.*
        FROM `sky_phone_crypto_quotes` quote
        WHERE quote.`id` = ? AND quote.`profile_id` = ? LIMIT 1
    ]], { data.quoteId, profile.id })[1]
    if not quote or quote.consumed_operation_id then
        return { success = false, error = "quote_unavailable" }
    end
    local expiry = Bridge.Database.Query(
        "SELECT UNIX_TIMESTAMP(`expires_at`) AS `expires_at` FROM `sky_phone_crypto_quotes` WHERE `id` = ?",
        { quote.id }
    )[1]
    if not expiry or tonumber(expiry.expires_at) < os.time() then
        return { success = false, error = "quote_expired" }
    end
    local current_market = market_state[quote.market_id]
    if not current_market or current_market.status ~= "active"
        or current_market.version ~= tonumber(quote.market_version)
    then
        return { success = false, error = "quote_expired" }
    end
    local quantity = tonumber(quote.quantity)
    local net_currency = tonumber(quote.net)
    local player_account = account_id(profile.id)
    if daily_total(profile.id, quote.side) + net_currency
        > Config.Crypto.DailyTradeLimit * Config.Crypto.PriceScale
    then
        return { success = false, error = "limit_exceeded" }
    end
    if quote.side == "buy" then
        if balance(player_account, quote.market_id) + quantity
            > Config.Crypto.MaximumPositionQuantity * Config.Crypto.AssetScale
        then
            return { success = false, error = "limit_exceeded" }
        end
        if balance(player_account, "CASH") < net_currency then
            return { success = false, error = "insufficient_funds" }
        end
        if balance("treasury", quote.market_id) < quantity then
            return { success = false, error = "insufficient_liquidity" }
        end
    else
        if balance(player_account, quote.market_id) < quantity then
            return { success = false, error = "insufficient_funds" }
        end
        if balance("treasury", "CASH") < net_currency then
            return { success = false, error = "insufficient_liquidity" }
        end
    end
    local operation_id = new_id()
    local fill_id = new_id()
    local operation_type = quote.side
    local request_hash = Bridge.Database.Query(
        "SELECT SHA2(CONCAT(?, ':', ?), 256) AS `hash`",
        { quote.id, key }
    )[1].hash
    local queries = {
        {
            query = [[INSERT INTO `sky_phone_crypto_operations`
                (`id`,`profile_id`,`type`,`idempotency_key`,`request_hash`,`status`,`amount`,`market_id`)
                VALUES (?, ?, ?, ?, ?, 'prepared', ?, ?)]],
            params = { operation_id, profile.id, operation_type, key, request_hash, net_currency, quote.market_id },
        },
    }
    if quote.side == "buy" then
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` - ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH' AND `available` >= ?]], params = { net_currency, player_account, net_currency } }
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `version` = `version` + 1 WHERE `account_id` = 'treasury' AND `asset_id` = 'CASH']], params = { net_currency } }
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` - ?, `version` = `version` + 1 WHERE `account_id` = 'treasury' AND `asset_id` = ? AND `available` >= ?]], params = { quantity, quote.market_id, quantity } }
        queries[#queries + 1] = { query = [[INSERT INTO `sky_phone_crypto_balances` (`account_id`,`asset_id`,`available`,`version`) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE `available` = `available` + VALUES(`available`), `version` = `version` + 1]], params = { player_account, quote.market_id, quantity } }
    else
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` - ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = ? AND `available` >= ?]], params = { quantity, player_account, quote.market_id, quantity } }
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `version` = `version` + 1 WHERE `account_id` = 'treasury' AND `asset_id` = ?]], params = { quantity, quote.market_id } }
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` - ?, `version` = `version` + 1 WHERE `account_id` = 'treasury' AND `asset_id` = 'CASH' AND `available` >= ?]], params = { net_currency, net_currency } }
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH']], params = { net_currency, player_account } }
    end
    queries[#queries + 1] = { query = [[INSERT INTO `sky_phone_crypto_ledger_entries` (`operation_id`,`account_id`,`asset_id`,`delta`) VALUES (?, ?, 'CASH', ?), (?, 'treasury', 'CASH', ?), (?, ?, ?, ?), (?, 'treasury', ?, ?)]], params = {
        operation_id, player_account, quote.side == "buy" and -net_currency or net_currency,
        operation_id, quote.side == "buy" and net_currency or -net_currency,
        operation_id, player_account, quote.market_id, quote.side == "buy" and quantity or -quantity,
        operation_id, quote.market_id, quote.side == "buy" and -quantity or quantity,
    } }
    queries[#queries + 1] = { query = [[INSERT INTO `sky_phone_crypto_fills` (`id`,`operation_id`,`quote_id`,`market_id`,`side`,`quantity`,`price`,`gross`,`fee`,`net`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], params = { fill_id, operation_id, quote.id, quote.market_id, quote.side, quantity, quote.price, quote.gross, quote.fee, quote.net } }
    queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_quotes` SET `consumed_operation_id` = ? WHERE `id` = ? AND `consumed_operation_id` IS NULL]], params = { operation_id, quote.id } }
    queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'completed' WHERE `id` = ?]], params = { operation_id } }
    if not Bridge.Database.Transaction(queries) then
        return { success = false, error = "request_failed" }
    end
    audit(profile.id, profile.owner_identifier, "trade_completed", operation_id)
    return { success = true, data = bootstrap(profile) }
end

Bridge.Callbacks.Register("sky_phone:crypto:execute", function(source, data)
    if not SkyPhone.AllowOperation(source, "crypto:trade", Config.Crypto.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = authenticated_profile(source)
    if not profile then
        return error_response
    end
    return with_profile_lock(profile.id, function()
        return with_exchange_lock(function()
            return execute_trade(profile, type(data) == "table" and data or {})
        end)
    end)
end)

local function settlement_ledger_queries(operation_id, profile_id, kind, ledger_amount)
    local player_account = account_id(profile_id)
    local queries = {}
    if kind == "deposit" then
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH']], params = { ledger_amount, player_account } }
        queries[#queries + 1] = { query = [[INSERT INTO `sky_phone_crypto_ledger_entries` (`operation_id`,`account_id`,`asset_id`,`delta`) VALUES (?, ?, 'CASH', ?), (?, 'external:bank', 'CASH', ?)]], params = { operation_id, player_account, ledger_amount, operation_id, -ledger_amount } }
    else
        queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `locked` = `locked` - ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH' AND `locked` >= ?]], params = { ledger_amount, player_account, ledger_amount } }
        queries[#queries + 1] = { query = [[INSERT INTO `sky_phone_crypto_ledger_entries` (`operation_id`,`account_id`,`asset_id`,`delta`) VALUES (?, ?, 'CASH', ?), (?, 'external:bank', 'CASH', ?)]], params = { operation_id, player_account, -ledger_amount, operation_id, ledger_amount } }
    end
    queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'completed' WHERE `id` = ? AND `status` = 'external_applied']], params = { operation_id } }
    queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_settlements` SET `state` = 'completed' WHERE `operation_id` = ? AND `state` = 'external_applied']], params = { operation_id } }
    return queries
end

local function settle(source, profile, kind, data)
    local key = idempotency_key(data.idempotencyKey)
    local amount = parse_whole(data.amount, Config.Crypto.MinimumSettlement, Config.Crypto.MaximumSettlement)
    if not key or not amount then
        return { success = false, error = "invalid_amount" }
    end
    if not verify_password(profile.id, data.password) then
        audit(profile.id, profile.owner_identifier, "settlement_reauth_failed", kind)
        return { success = false, error = "invalid_credentials" }
    end
    local existing = Bridge.Database.Query([[
        SELECT `status` FROM `sky_phone_crypto_operations`
        WHERE `profile_id` = ? AND `type` = ? AND `idempotency_key` = ? LIMIT 1
    ]], { profile.id, kind, key })[1]
    if existing then
        return existing.status == "completed"
            and { success = true, data = bootstrap(profile) }
            or { success = false, error = "settlement_pending" }
    end
    local ledger_amount = amount * Config.Crypto.PriceScale
    local daily_limit = kind == "deposit" and Config.Crypto.DailyDepositLimit
        or Config.Crypto.DailyWithdrawalLimit
    if daily_total(profile.id, kind) + ledger_amount > daily_limit * Config.Crypto.PriceScale then
        return { success = false, error = "limit_exceeded" }
    end
    if kind == "withdrawal" and balance(account_id(profile.id), "CASH") < ledger_amount then
        return { success = false, error = "insufficient_funds" }
    end
    local operation_id = new_id()
    local request_hash = Bridge.Database.Query(
        "SELECT SHA2(CONCAT(?, ':', ?, ':', ?), 256) AS `hash`",
        { kind, amount, key }
    )[1].hash
    local prepared = {
        {
            query = [[INSERT INTO `sky_phone_crypto_operations`
                (`id`,`profile_id`,`type`,`idempotency_key`,`request_hash`,`status`,`amount`)
                VALUES (?, ?, ?, ?, ?, 'prepared', ?)]],
            params = { operation_id, profile.id, kind, key, request_hash, ledger_amount },
        },
        {
            query = [[INSERT INTO `sky_phone_crypto_settlements`
                (`operation_id`,`owner_identifier`,`framework_account`,`amount`,`state`)
                VALUES (?, ?, ?, ?, 'prepared')]],
            params = { operation_id, profile.owner_identifier, Config.Crypto.BankAccount, amount },
        },
    }
    if kind == "withdrawal" then
        prepared[#prepared + 1] = {
            query = [[UPDATE `sky_phone_crypto_balances`
                SET `available` = `available` - ?, `locked` = `locked` + ?, `version` = `version` + 1
                WHERE `account_id` = ? AND `asset_id` = 'CASH' AND `available` >= ?]],
            params = { ledger_amount, ledger_amount, account_id(profile.id), ledger_amount },
        }
    end
    if not Bridge.Database.Transaction(prepared) then
        return { success = false, error = "request_failed" }
    end
    Bridge.Database.Query("UPDATE `sky_phone_crypto_operations` SET `status` = 'external_pending' WHERE `id` = ?", { operation_id })
    Bridge.Database.Query("UPDATE `sky_phone_crypto_settlements` SET `state` = 'external_pending' WHERE `operation_id` = ?", { operation_id })
    local money_success, money_result = pcall(
        kind == "deposit" and Bridge.Framework.RemoveMoney or Bridge.Framework.AddMoney,
        source,
        Config.Crypto.BankAccount,
        amount
    )
    if not money_success then
        Bridge.Database.Query("UPDATE `sky_phone_crypto_operations` SET `status` = 'manual_review', `detail` = 'framework_call_ambiguous' WHERE `id` = ?", { operation_id })
        Bridge.Database.Query("UPDATE `sky_phone_crypto_settlements` SET `state` = 'manual_review' WHERE `operation_id` = ?", { operation_id })
        audit(profile.id, profile.owner_identifier, "settlement_manual_review", operation_id)
        return { success = false, error = "settlement_pending" }
    end
    if not money_result then
        local failed = {
            { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'failed', `detail` = 'framework_rejected' WHERE `id` = ?]], params = { operation_id } },
            { query = [[UPDATE `sky_phone_crypto_settlements` SET `state` = 'failed' WHERE `operation_id` = ?]], params = { operation_id } },
        }
        if kind == "withdrawal" then
            failed[#failed + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `locked` = `locked` - ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH' AND `locked` >= ?]], params = { ledger_amount, ledger_amount, account_id(profile.id), ledger_amount } }
        end
        Bridge.Database.Transaction(failed)
        return { success = false, error = kind == "deposit" and "insufficient_funds" or "request_failed" }
    end
    Bridge.Database.Query("UPDATE `sky_phone_crypto_operations` SET `status` = 'external_applied' WHERE `id` = ?", { operation_id })
    Bridge.Database.Query("UPDATE `sky_phone_crypto_settlements` SET `state` = 'external_applied' WHERE `operation_id` = ?", { operation_id })
    local ledger_queries = settlement_ledger_queries(operation_id, profile.id, kind, ledger_amount)
    if not Bridge.Database.Transaction(ledger_queries) then
        Bridge.Database.Query("UPDATE `sky_phone_crypto_operations` SET `status` = 'manual_review', `detail` = 'ledger_apply_failed' WHERE `id` = ?", { operation_id })
        Bridge.Database.Query("UPDATE `sky_phone_crypto_settlements` SET `state` = 'manual_review' WHERE `operation_id` = ?", { operation_id })
        audit(profile.id, profile.owner_identifier, "settlement_manual_review", operation_id)
        return { success = false, error = "settlement_pending" }
    end
    sessions[source].recently_authenticated_at = os.time()
    audit(profile.id, profile.owner_identifier, "settlement_completed", operation_id)
    return { success = true, data = bootstrap(profile) }
end

for _, callback in ipairs({
    { name = "deposit", kind = "deposit" },
    { name = "withdraw", kind = "withdrawal" },
}) do
    Bridge.Callbacks.Register("sky_phone:crypto:" .. callback.name, function(source, data)
        if not SkyPhone.AllowOperation(source, "crypto:settlement", 8, 60) then
            return { success = false, error = "rate_limited" }
        end
        local profile, error_response = authenticated_profile(source)
        if not profile then
            return error_response
        end
        return with_profile_lock(profile.id, function()
            return settle(source, profile, callback.kind, type(data) == "table" and data or {})
        end)
    end)
end

AddEventHandler("playerDropped", function()
    sessions[source] = nil
end)

ensure_schema()
migrate_crypto_keys()
initialize_markets()
load_market_cache()

local function reconcile_settlements(include_recent)
    local age_clause = include_recent and "" or " AND settlement.`updated_at` < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE)"
    local rows = Bridge.Database.Query([[
        SELECT operation.`id`, operation.`profile_id`, operation.`type`, operation.`amount`,
            operation.`status`, settlement.`state`
        FROM `sky_phone_crypto_operations` operation
        JOIN `sky_phone_crypto_settlements` settlement ON settlement.`operation_id` = operation.`id`
        WHERE operation.`status` IN ('prepared','external_pending','external_applied')
    ]] .. age_clause, {})
    for _, operation in ipairs(rows) do
        local ledger_amount = tonumber(operation.amount)
        if operation.status == "prepared" then
            local queries = {}
            if operation.type == "withdrawal" then
                queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_balances` SET `available` = `available` + ?, `locked` = `locked` - ?, `version` = `version` + 1 WHERE `account_id` = ? AND `asset_id` = 'CASH' AND `locked` >= ?]], params = { ledger_amount, ledger_amount, account_id(operation.profile_id), ledger_amount } }
            end
            queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'cancelled', `detail` = 'reconciled_before_external_call' WHERE `id` = ? AND `status` = 'prepared']], params = { operation.id } }
            queries[#queries + 1] = { query = [[UPDATE `sky_phone_crypto_settlements` SET `state` = 'cancelled' WHERE `operation_id` = ? AND `state` = 'prepared']], params = { operation.id } }
            Bridge.Database.Transaction(queries)
        elseif operation.status == "external_pending" then
            Bridge.Database.Transaction({
                { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'manual_review', `detail` = 'reconciled_ambiguous_external_call' WHERE `id` = ? AND `status` = 'external_pending']], params = { operation.id } },
                { query = [[UPDATE `sky_phone_crypto_settlements` SET `state` = 'manual_review' WHERE `operation_id` = ? AND `state` = 'external_pending']], params = { operation.id } },
            })
        elseif operation.status == "external_applied" then
            local entries = Bridge.Database.Query(
                "SELECT COUNT(*) AS `count` FROM `sky_phone_crypto_ledger_entries` WHERE `operation_id` = ?",
                { operation.id }
            )[1]
            if tonumber(entries and entries.count) == 0 then
                Bridge.Database.Transaction(settlement_ledger_queries(
                    operation.id,
                    operation.profile_id,
                    operation.type,
                    ledger_amount
                ))
            else
                Bridge.Database.Transaction({
                    { query = [[UPDATE `sky_phone_crypto_operations` SET `status` = 'manual_review', `detail` = 'unexpected_partial_ledger' WHERE `id` = ?]], params = { operation.id } },
                    { query = [[UPDATE `sky_phone_crypto_settlements` SET `state` = 'manual_review' WHERE `operation_id` = ?]], params = { operation.id } },
                })
            end
        end
    end
end

local function crypto_random_int(minimum, maximum, failure_message)
    local value = exports[GetCurrentResourceName()]:CryptoRandomInt(minimum, maximum)
    if type(value) ~= "number" then
        error(failure_message)
    end
    return value
end

local function truncate_integer(value)
    if value > 0 then
        return math.floor(value)
    elseif value < 0 then
        return math.ceil(value)
    end
    return 0
end

local function advance_global_market_cycle()
    if global_market_cycle.remaining_ticks <= 0 then
        if global_market_cycle.direction == 0 then
            global_market_cycle.direction = crypto_random_int(
                0,
                2,
                "[sky_phone] Crypto entropy provider did not return a global market direction."
            ) == 0 and -1 or 1
        else
            global_market_cycle.direction = -global_market_cycle.direction
        end
        global_market_cycle.remaining_ticks = crypto_random_int(
            Config.Crypto.GlobalCycleMinimumTicks,
            Config.Crypto.GlobalCycleMaximumTicks + 1,
            "[sky_phone] Crypto entropy provider did not return a global market cycle duration."
        )
        global_market_cycle.target = global_market_cycle.direction * crypto_random_int(
            Config.Crypto.GlobalTrendMinimumBasisPoints,
            Config.Crypto.GlobalTrendMaximumBasisPoints + 1,
            "[sky_phone] Crypto entropy provider did not return a global market trend."
        )
    end

    global_market_trend = truncate_integer((
        global_market_trend * (10000 - Config.Crypto.CycleTransitionBasisPoints)
        + global_market_cycle.target * Config.Crypto.CycleTransitionBasisPoints
    ) / 10000)
    global_market_cycle.remaining_ticks = global_market_cycle.remaining_ticks - 1
end

local function advance_market_cycle(config, dynamics)
    if dynamics.cycle_remaining_ticks <= 0 then
        if dynamics.cycle_direction == 0 then
            dynamics.cycle_direction = crypto_random_int(
                0,
                2,
                "[sky_phone] Crypto entropy provider did not return a market cycle direction."
            ) == 0 and -1 or 1
        else
            dynamics.cycle_direction = -dynamics.cycle_direction
        end
        dynamics.cycle_remaining_ticks = crypto_random_int(
            Config.Crypto.CycleDurationMinimumTicks,
            Config.Crypto.CycleDurationMaximumTicks + 1,
            "[sky_phone] Crypto entropy provider did not return a market cycle duration."
        )
        local strength = crypto_random_int(
            Config.Crypto.CycleStrengthMinimumBasisPoints,
            Config.Crypto.CycleStrengthMaximumBasisPoints + 1,
            "[sky_phone] Crypto entropy provider did not return a market cycle strength."
        )
        dynamics.cycle_target = dynamics.cycle_direction * math.max(
            1,
            math.floor(config.VolatilityBasisPoints * strength / 10000)
        )
    end

    dynamics.cycle_bias = truncate_integer((
        dynamics.cycle_bias * (10000 - Config.Crypto.CycleTransitionBasisPoints)
        + dynamics.cycle_target * Config.Crypto.CycleTransitionBasisPoints
    ) / 10000)
    dynamics.cycle_remaining_ticks = dynamics.cycle_remaining_ticks - 1
    return dynamics.cycle_bias
end

local scheduler_generation = 0

local function start_crypto_schedulers()
    scheduler_generation = scheduler_generation + 1
    if Config.Crypto.Enabled ~= true then
        return
    end

    local generation = scheduler_generation
    reconcile_settlements(true)

    CreateThread(function()
        while scheduler_generation == generation and Config.Crypto.Enabled == true do
            Wait(market_persistence_interval)
            if scheduler_generation ~= generation or Config.Crypto.Enabled ~= true then
                break
            end
            with_exchange_lock(persist_market_cache)
        end
    end)

    CreateThread(function()
        while scheduler_generation == generation and Config.Crypto.Enabled == true do
            Wait(5 * 60 * 1000)
            if scheduler_generation ~= generation or Config.Crypto.Enabled ~= true then
                break
            end
            reconcile_settlements(false)
        end
    end)

    CreateThread(function()
        while scheduler_generation == generation and Config.Crypto.Enabled == true do
            local tick_seconds = crypto_random_int(
                Config.Crypto.PriceTickMinimumSeconds,
                Config.Crypto.PriceTickMaximumSeconds + 1,
                "[sky_phone] Crypto entropy provider did not return a market tick interval."
            )
            Wait(tick_seconds * 1000)
            if scheduler_generation ~= generation or Config.Crypto.Enabled ~= true then
                break
            end
            with_exchange_lock(function()
                local market_count = crypto_random_int(
                    Config.Crypto.MarketsPerTickMinimum,
                    Config.Crypto.MarketsPerTickMaximum + 1,
                    "[sky_phone] Crypto entropy provider did not return a market count."
                )
                advance_global_market_cycle()
                local changed_markets = {}
                market_count = math.min(market_count, #market_order)

                for offset = 0, market_count - 1 do
                    local order_index = ((market_cursor + offset - 1) % #market_order) + 1
                    local market_id = market_order[order_index]
                    local config = markets[market_id]
                    local row = market_state[market_id]
                    if row and row.status == "active" then
                        local price = tonumber(row.price) or config.InitialPrice
                        local impulse = crypto_random_int(
                            -config.VolatilityBasisPoints,
                            config.VolatilityBasisPoints + 1,
                            "[sky_phone] Crypto entropy provider did not return a market movement."
                        )
                        if impulse > 0 then
                            impulse = math.floor(impulse / Config.Crypto.RandomImpulseDivisor)
                        elseif impulse < 0 then
                            impulse = math.ceil(impulse / Config.Crypto.RandomImpulseDivisor)
                        end
                        local shock_roll = crypto_random_int(
                            0,
                            10000,
                            "[sky_phone] Crypto entropy provider did not return a market shock roll."
                        )
                        local dynamics = market_dynamics[market_id] or {
                            momentum = 0,
                            cycle_bias = 0,
                            cycle_direction = 0,
                            cycle_remaining_ticks = 0,
                            cycle_target = 0,
                        }
                        dynamics.momentum = truncate_integer((
                            dynamics.momentum * Config.Crypto.MomentumDecayBasisPoints
                            + impulse * Config.Crypto.MomentumImpulseBasisPoints
                        ) / 10000)
                        local cycle_bias = advance_market_cycle(config, dynamics)
                        market_dynamics[market_id] = dynamics

                        local deviation = math.floor(
                            (config.InitialPrice - price) * 10000 / config.InitialPrice
                        )
                        local reversion = truncate_integer(
                            deviation * Config.Crypto.MeanReversionBasisPoints / 10000
                        )
                        local shock = 0
                        if shock_roll < Config.Crypto.MarketShockChanceBasisPoints then
                            local multiplier = crypto_random_int(
                                Config.Crypto.MarketShockMinimumMultiplier,
                                Config.Crypto.MarketShockMaximumMultiplier + 1,
                                "[sky_phone] Crypto entropy provider did not return a market shock multiplier."
                            )
                            local direction_roll = crypto_random_int(
                                0,
                                2,
                                "[sky_phone] Crypto entropy provider did not return a market shock direction."
                            )
                            local direction = direction_roll == 0 and -1 or 1
                            shock = direction * config.VolatilityBasisPoints * multiplier
                        end

                        local maximum_movement = config.VolatilityBasisPoints
                            * Config.Crypto.MaximumMovementMultiplier
                        local movement = impulse + dynamics.momentum + cycle_bias
                            + global_market_trend + reversion + shock
                        movement = math.max(-maximum_movement, math.min(maximum_movement, movement))
                        if movement > 0 then
                            movement = math.floor(movement / Config.Crypto.TickMovementDivisor)
                        elseif movement < 0 then
                            movement = math.ceil(movement / Config.Crypto.TickMovementDivisor)
                        end
                        local next_price = math.floor(price * (10000 + movement) / 10000)
                        if next_price == price and movement ~= 0 then
                            next_price = price + (movement > 0 and 1 or -1)
                        end
                        next_price = math.max(config.MinimumPrice, math.min(config.MaximumPrice, next_price))
                        local next_version = row.version + 1
                        local updated_at = os.time()
                        row.price = next_price
                        row.version = next_version
                        row.updated_at = updated_at
                        row.dirty = true
                        local history = market_history[market_id]
                        history[#history + 1] = {
                            price = next_price,
                            version = next_version,
                            created_at = updated_at,
                        }
                        if #history > Config.Crypto.HistoryRetentionTicks then
                            table.remove(history, 1)
                        end
                        changed_markets[#changed_markets + 1] = market_id
                    end
                end
                market_cursor = ((market_cursor + market_count - 1) % #market_order) + 1
                if #changed_markets > 0 then
                    TriggerClientEvent("sky_phone:crypto:changed", -1, {
                        markets = market_dtos(changed_markets),
                        updatedAt = os.time() * 1000,
                    })
                end
            end)
        end
    end)
end

local function refresh_crypto_runtime()
    if exchange_lock then
        print("[sky_phone] Crypto runtime refresh skipped because the exchange is busy.")
        return
    end
    with_exchange_lock(function()
        if not persist_market_cache() then
            return
        end
        initialize_markets()
        load_market_cache()
        start_crypto_schedulers()
    end)
end

AddEventHandler("sky_phone:configurator:serverUpdated", refresh_crypto_runtime)
AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        persist_market_cache()
    end
end)
start_crypto_schedulers()

end)
