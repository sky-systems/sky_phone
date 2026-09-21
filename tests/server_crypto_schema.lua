local profiles_table = "sky_phone_crypto_profiles"
local operations_table = "sky_phone_crypto_operations"

local function legacy_database()
    return {
        tables = {
            [profiles_table] = { id = "CHAR(36)", handle = "VARCHAR(20)", password_hash = "VARCHAR(255)" },
            [operations_table] = { id = "CHAR(36)", type = "ENUM('buy','sell')", market_id = "VARCHAR(32)" },
        },
        profiles = { { id = "existing-profile", handle = "existing-handle", password_hash = "existing-hash" } },
    }
end

local function start_crypto(database, failing_column)
    local logs, added_columns = {}, {}
    local metadata_reads, key_updates = 0, 0
    local reached_market_initialization = false
    database.tables = database.tables or {}
    database.profiles = database.profiles or {}

    local env = setmetatable({
        Config = { Crypto = {
            Enabled = false,
            Markets = {},
            TreasuryCash = 100,
            PriceScale = 100,
            HistoryRetentionTicks = 48,
            SparklinePoints = 48,
        } },
        AddEventHandler = function() end,
    }, { __index = _G })

    local function query(sql, parameters)
        assert(not sql:find("ADD COLUMN IF NOT EXISTS", 1, true),
            "MySQL does not support ADD COLUMN IF NOT EXISTS")
        local created_table = sql:match("CREATE TABLE IF NOT EXISTS `([^`]+)`")
        if created_table then
            if not database.tables[created_table] then
                local columns = {}
                for column, definition in sql:gmatch("\n%s*`([^`]+)` ([^\n]+)") do
                    columns[column] = definition:gsub(",$", "")
                end
                database.tables[created_table] = columns
                if created_table == profiles_table then
                    database.key_index = sql:find("UNIQUE KEY `uniq_sky_phone_crypto_key`", 1, true) ~= nil
                end
            end
            return {}
        end
        if sql:find("INFORMATION_SCHEMA.COLUMNS", 1, true) then
            metadata_reads = metadata_reads + 1
            assert(sql:find("TABLE_SCHEMA = DATABASE()", 1, true), "only inspect the active database")
            assert(#parameters == 2 and parameters[1] == profiles_table and parameters[2] == operations_table,
                "bind both crypto table names in one metadata read")
            local rows = {}
            for _, table_name in ipairs(parameters) do
                for column_name in pairs(database.tables[table_name]) do
                    rows[#rows + 1] = { table_name = table_name, column_name = column_name }
                end
            end
            return rows
        end
        local altered_table, column, definition = sql:match("ALTER TABLE `([^`]+)` ADD COLUMN `([^`]+)` (.+)")
        if altered_table then
            local columns = assert(database.tables[altered_table], "ALTER requires an existing table")
            assert(not columns[column], "duplicate ADD COLUMN: " .. column)
            local predecessor = definition:match("AFTER `([^`]+)`")
            assert(not predecessor or columns[predecessor], "AFTER requires its predecessor column")
            if column == failing_column then
                error("simulated ALTER permission denied for " .. column)
            end
            columns[column] = definition
            added_columns[#added_columns + 1] = column
            if altered_table == profiles_table then
                if column == "crypto_key" then
                    assert(not definition:find("NOT NULL", 1, true), "existing profiles need nullable keys before backfill")
                end
                local default = tonumber(definition:match("DEFAULT (%d+)"))
                for _, profile in ipairs(database.profiles) do
                    profile[column] = default
                end
            end
            return {}
        end
        altered_table, column, definition = sql:match("ALTER TABLE `([^`]+)`%s+MODIFY COLUMN `([^`]+)` (.+)")
        if altered_table then
            assert(database.tables[altered_table][column], "MODIFY requires an existing column")
            if altered_table == profiles_table and column == "crypto_key" then
                for _, profile in ipairs(database.profiles) do
                    assert(type(profile.crypto_key) == "string" and #profile.crypto_key == 22,
                        "backfill every existing key before making the column NOT NULL")
                end
            end
            database.tables[altered_table][column] = definition
            return {}
        end
        if sql:find("SELECT `id` FROM `sky_phone_crypto_profiles` WHERE `crypto_key` IS NULL", 1, true) then
            local rows = {}
            for _, profile in ipairs(database.profiles) do
                if not profile.crypto_key or profile.crypto_key == "" then
                    rows[#rows + 1] = { id = profile.id }
                end
            end
            return rows
        end
        if sql == "SELECT UUID() AS `id`" then
            return { { id = "12345678-1234-5678-1234-567812345678" } }
        end
        if sql:find("SELECT 1 FROM `sky_phone_crypto_profiles` WHERE `crypto_key` = ?", 1, true) then
            for _, profile in ipairs(database.profiles) do
                if profile.crypto_key == parameters[1] then return { { found = 1 } } end
            end
            return {}
        end
        if sql:find("UPDATE `sky_phone_crypto_profiles` SET `crypto_key` = ?", 1, true) then
            for _, profile in ipairs(database.profiles) do
                if profile.id == parameters[2] then
                    assert(not profile.crypto_key or profile.crypto_key == "", "preserve existing crypto keys")
                    profile.crypto_key = parameters[1]
                    key_updates = key_updates + 1
                end
            end
            return {}
        end
        if sql:find("FROM information_schema.statistics", 1, true) then
            return database.key_index and { { found = 1 } } or {}
        end
        if sql:find("ADD UNIQUE KEY `uniq_sky_phone_crypto_key`", 1, true) then
            assert(not database.key_index, "do not recreate the crypto key index")
            database.key_index = true
            return {}
        end
        if sql:find("INSERT INTO `sky_phone_crypto_balances`", 1, true) then
            reached_market_initialization = true
            return {}
        end
        if sql:find("FROM `sky_phone_crypto_markets`", 1, true) then return {} end
        error("Unexpected initialization SQL: " .. sql)
    end

    env.Bridge = {
        Database = { Query = query },
        Callbacks = { Register = function() end },
        Debug = function(level, message, ...)
            logs[#logs + 1] = { level = level, message = message:format(...) }
        end,
    }
    assert(loadfile("sky_phone/source/bridge/server/migrations.lua", "t", env))()
    assert(loadfile("sky_phone/source/server/crypto.lua", "t", env))()
    local success, reason = pcall(env.Bridge.Database.CompleteMigration, "sky_phone")
    return {
        success = success,
        reason = reason,
        logs = logs,
        added_columns = added_columns,
        metadata_reads = metadata_reads,
        key_updates = key_updates,
        reached_market_initialization = reached_market_initialization,
    }
end

local function assert_started(result)
    assert(result.success, result.reason)
    assert(result.metadata_reads == 1, "inspect the two tables once per startup")
    assert(result.reached_market_initialization, "schema initialization must finish before markets initialize")
end

local fresh = {}
local result = start_crypto(fresh)
assert_started(result)
assert(#result.added_columns == 0, "a fresh CREATE TABLE schema must not receive duplicate additions")
assert(fresh.key_index and result.key_updates == 0)

local legacy = legacy_database()
result = start_crypto(legacy)
assert_started(result)
assert(#result.added_columns == 6, "upgrade all six missing crypto columns")
local profile = legacy.profiles[1]
assert(profile.price_alerts == 1 and profile.trade_confirmations == 1 and profile.hide_balances == 0,
    "upgrades must retain the existing settings defaults")
assert(profile.handle == "existing-handle" and profile.password_hash == "existing-hash",
    "schema upgrades must preserve profile data")
assert(result.key_updates == 1 and legacy.key_index)
assert(legacy.tables[operations_table].quantity:find("DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0", 1, true))
local existing_key = profile.crypto_key
result = start_crypto(legacy)
assert_started(result)
assert(#result.added_columns == 0 and result.key_updates == 0 and profile.crypto_key == existing_key,
    "restarting an upgraded schema must not add columns or replace keys")

local partial = legacy_database()
partial.tables[profiles_table].price_alerts = "TINYINT(1) UNSIGNED NOT NULL DEFAULT 1"
partial.tables[profiles_table].crypto_key = "CHAR(22) NULL"
partial.tables[operations_table].quantity = "DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0"
partial.profiles[1].price_alerts = 0
partial.profiles[1].crypto_key = "VX-ABCD-EF01-2345-6789"
result = start_crypto(partial)
assert_started(result)
assert(#result.added_columns == 3, "a partial upgrade must add only missing columns")
assert(partial.profiles[1].price_alerts == 0 and partial.profiles[1].crypto_key == "VX-ABCD-EF01-2345-6789"
    and result.key_updates == 0, "preserve existing preferences and keys")

local interrupted = legacy_database()
result = start_crypto(interrupted, "trade_confirmations")
assert(not result.success and result.reason:find("module initialization callback", 1, true),
    "a real SQL failure must fail module initialization")
assert(not result.reached_market_initialization and not interrupted.tables[profiles_table].trade_confirmations,
    "a failed ALTER must not continue with an incomplete schema")
local found_failure = false
for _, log in ipairs(result.logs) do
    if log.level == "error" and log.message:find("simulated ALTER permission denied for trade_confirmations", 1, true) then
        found_failure = true
    end
end
assert(found_failure, "the migration bridge must retain the original SQL failure")
result = start_crypto(interrupted)
assert_started(result)
assert(#result.added_columns == 5, "a later startup must recover after an interrupted additive upgrade")

print("Crypto schema MySQL compatibility, upgrades, restart and SQL failure tests passed")
