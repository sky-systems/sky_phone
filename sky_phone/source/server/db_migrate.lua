local legacy_accounts = Sky.Query([[
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
    Sky.Query("RENAME TABLE `sky_phone_mail_accounts` TO `sky_phone_accounts`", {})
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
        name = "sky_phone_devices",
        columns = {
            {
                name = "imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "device_name", type = "VARCHAR(64) NOT NULL DEFAULT 'iFruit Phone'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "imei",
        indexes = {
            { name = "idx_sky_phone_devices_account", columns = "(`account_id`, `updated_at`)" },
        },
        foreignKeys = {
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE SET NULL",
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
}

Sky.DB.Migrate("sky_phone", schema)
