local legacy_accounts = Bridge.Database.Query([[
    SELECT TABLE_NAME AS `name`
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME IN ('sky_phone_mail_accounts', 'sky_phone_accounts')
]], {})
local account_tables = {}
for _, row in ipairs(legacy_accounts) do
    account_tables[row.name] = true
end

if account_tables.sky_phone_mail_accounts and not account_tables.sky_phone_accounts then
    Bridge.Database.Query("RENAME TABLE `sky_phone_mail_accounts` TO `sky_phone_accounts`", {})
elseif account_tables.sky_phone_mail_accounts and account_tables.sky_phone_accounts then
    error("[sky_phone] Both legacy and current iFruit account tables exist; refusing an ambiguous migration.")
end

local schema = {
    {
        name = "sky_phone_accounts",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            {
                name = "email",
                type = "VARCHAR(64) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_general_ci",
            },
            { name = "password", type = "VARCHAR(64) NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_mail_email", columns = "(`email`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_mail_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL" },
            { name = "sender_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "recipients", type = "LONGTEXT NOT NULL" },
            { name = "subject", type = "VARCHAR(120) NOT NULL DEFAULT ''" },
            { name = "body", type = "LONGTEXT NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_mail_sender", columns = "(`sender_account_id`, `created_at`)" },
        },
        foreignKeys = {
            {
                column = "sender_account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_mail_entries",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "message_id", type = "CHAR(36) NOT NULL" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "folder", type = "ENUM('inbox', 'sent') NOT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "trashed_at", type = "DATETIME NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            {
                name = "uniq_sky_phone_mail_entry",
                columns = "(`message_id`, `account_id`, `folder`)",
            },
        },
        indexes = {
            { name = "idx_sky_phone_mailbox", columns = "(`account_id`, `folder`, `trashed_at`, `id`)" },
        },
        foreignKeys = {
            {
                column = "message_id",
                references = "`sky_phone_mail_messages` (`id`) ON DELETE CASCADE",
            },
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_mail_drafts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "recipients", type = "LONGTEXT NOT NULL" },
            { name = "subject", type = "VARCHAR(120) NOT NULL DEFAULT ''" },
            { name = "body", type = "LONGTEXT NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_mail_drafts", columns = "(`account_id`, `updated_at`)" },
        },
        foreignKeys = {
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_sims",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "contact_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "phone_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sim_type", type = "ENUM('registered', 'anonymous') NOT NULL" },
            { name = "owner_identifier", type = "VARCHAR(80) NULL" },
            { name = "owner_firstname", type = "VARCHAR(80) NULL" },
            { name = "owner_lastname", type = "VARCHAR(80) NULL" },
            { name = "owner_birthdate", type = "VARCHAR(32) NULL" },
            { name = "registered_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_sim_number", columns = "(`phone_number`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_devices",
        columns = {
            {
                name = "imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "device_name", type = "VARCHAR(64) NOT NULL DEFAULT 'iFruit Phone'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "imei",
        uniqueKeys = {
            { name = "uniq_sky_phone_devices_sim", columns = "(`sim_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_devices_account", columns = "(`account_id`, `updated_at`)" },
        },
        foreignKeys = {
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE SET NULL",
            },
            {
                column = "sim_id",
                references = "`sky_phone_sims` (`id`) ON DELETE SET NULL",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_device_data",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "namespace",
                type = "VARCHAR(32) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "payload", type = "LONGTEXT NOT NULL" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_device_namespace", columns = "(`device_imei`, `namespace`)" },
        },
        foreignKeys = {
            {
                column = "device_imei",
                references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_notes",
        columns = {
            { name = "id", type = "VARCHAR(64) NOT NULL" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            {
                name = "device_imei",
                type = "CHAR(15) NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "title", type = "VARCHAR(120) NOT NULL DEFAULT ''" },
            { name = "body", type = "LONGTEXT NOT NULL" },
            { name = "pinned", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_notes_account", columns = "(`account_id`, `updated_at`)" },
            { name = "idx_sky_phone_notes_device", columns = "(`device_imei`, `updated_at`)" },
        },
        foreignKeys = {
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE",
            },
            {
                column = "device_imei",
                references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_contacts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "contact_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "device_imei", type = "CHAR(15) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "name", type = "VARCHAR(80) NOT NULL" },
            { name = "phone_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_contacts_account", columns = "(`account_id`, `name`)" },
            { name = "idx_sky_phone_contacts_device", columns = "(`device_imei`, `name`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_calls",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "caller_sim_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "callee_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "caller_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "callee_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "VARCHAR(24) NOT NULL" },
            { name = "started_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "answered_at", type = "DATETIME NULL" },
            { name = "ended_at", type = "DATETIME NULL" },
            { name = "duration_seconds", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_calls_caller", columns = "(`caller_sim_id`, `started_at`)" },
            { name = "idx_sky_phone_calls_callee", columns = "(`callee_sim_id`, `started_at`)" },
        },
        foreignKeys = {
            { column = "caller_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
            { column = "callee_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_call_entries",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "call_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "device_imei", type = "CHAR(15) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "direction", type = "ENUM('incoming', 'outgoing') NOT NULL" },
            { name = "status", type = "VARCHAR(24) NOT NULL" },
            { name = "other_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_call_entries_account", columns = "(`account_id`, `created_at`)" },
            { name = "idx_sky_phone_call_entries_device", columns = "(`device_imei`, `created_at`)" },
        },
        foreignKeys = {
            { column = "call_id", references = "`sky_phone_calls` (`id`) ON DELETE CASCADE" },
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_bank_transactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "owner_identifier", type = "VARCHAR(80) NOT NULL" },
            { name = "kind", type = "ENUM('deposit', 'withdrawal', 'transfer_in', 'transfer_out') NOT NULL" },
            { name = "amount", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "label", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "reference", type = "VARCHAR(96) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_bank_owner", columns = "(`owner_identifier`, `id`)" },
            { name = "idx_sky_phone_bank_reference", columns = "(`reference`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
}

Bridge.Database.Migrate("sky_phone", schema)
Bridge.Database.EnsureIndex("sky_phone_devices", "uniq_sky_phone_devices_sim", "(`sim_id`)", { unique = true })
Bridge.Database.Query("UPDATE `sky_phone_contacts` SET `contact_id` = `id` WHERE `contact_id` IS NULL", {})
Bridge.Database.EnsureIndex("sky_phone_contacts", "uniq_sky_phone_contacts_account_contact", "(`account_id`, `contact_id`)", { unique = true })
Bridge.Database.EnsureIndex("sky_phone_contacts", "uniq_sky_phone_contacts_device_contact", "(`device_imei`, `contact_id`)", { unique = true })
Bridge.Database.CompleteMigration("sky_phone")
