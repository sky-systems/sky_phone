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
    error("[sky_phone] Both legacy and current Sky Cloud account tables exist; refusing an ambiguous migration.")
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
        name = "sky_phone_mailboxes",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "name", type = "VARCHAR(50) NOT NULL" },
            { name = "sort_order", type = "SMALLINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_mailbox_name", columns = "(`account_id`, `name`)" },
        },
        indexes = {
            { name = "idx_sky_phone_mailboxes", columns = "(`account_id`, `sort_order`, `id`)" },
        },
        foreignKeys = {
            {
                column = "account_id",
                references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB",
    },
    {
        name = "sky_phone_mail_entries",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "message_id", type = "CHAR(36) NOT NULL" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "folder", type = "ENUM('inbox', 'sent') NOT NULL" },
            { name = "mailbox_id", type = "BIGINT UNSIGNED NULL" },
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
            { name = "idx_sky_phone_custom_mailbox", columns = "(`account_id`, `mailbox_id`, `trashed_at`, `id`)" },
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
            { name = "is_virtual", type = "TINYINT(1) NOT NULL DEFAULT 0" },
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
        name = "sky_phone_character_devices",
        columns = {
            {
                name = "owner_identifier",
                type = "VARCHAR(80) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "owner_identifier",
        uniqueKeys = {
            { name = "uniq_sky_phone_character_devices_device", columns = "(`device_imei`)" },
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
        name = "sky_phone_migrations",
        columns = {
            { name = "name", type = "VARCHAR(96) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "stats", type = "LONGTEXT NULL" },
            { name = "completed_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "name",
        indexes = {
            { name = "idx_sky_phone_migrations_source", columns = "(`source`, `completed_at`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_migration_numbers",
        columns = {
            { name = "source", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source_number", type = "VARCHAR(64) NOT NULL" },
            { name = "phone_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sim_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "owned", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = { "source", "source_number" },
        uniqueKeys = {
            { name = "uniq_sky_phone_migration_number", columns = "(`source`, `phone_number`)" },
        },
        indexes = {
            { name = "idx_sky_phone_migration_numbers_sim", columns = "(`sim_id`)" },
        },
        foreignKeys = {
            { column = "sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_migration_owners",
        columns = {
            { name = "source", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source_phone_id", type = "VARCHAR(100) NOT NULL" },
            { name = "source_owner_id", type = "VARCHAR(100) NOT NULL" },
            { name = "owner_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source_phone_number", type = "VARCHAR(64) NOT NULL" },
            { name = "device_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sim_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = { "source", "source_phone_id" },
        uniqueKeys = {
            { name = "uniq_sky_phone_migration_owner_number", columns = "(`source`, `source_phone_number`)" },
        },
        indexes = {
            { name = "idx_sky_phone_migration_owner", columns = "(`source`, `owner_identifier`)" },
            { name = "idx_sky_phone_migration_owner_device", columns = "(`device_imei`)" },
            { name = "idx_sky_phone_migration_owner_account", columns = "(`account_id`)" },
        },
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE SET NULL" },
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
        name = "sky_phone_custom_app_data",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "app_id",
                type = "VARCHAR(64) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "data_key",
                type = "VARCHAR(64) NOT NULL",
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
            {
                name = "uniq_sky_phone_custom_app_data",
                columns = "(`device_imei`, `app_id`, `data_key`)",
            },
        },
        indexes = {
            {
                name = "idx_sky_phone_custom_app_storage",
                columns = "(`device_imei`, `app_id`, `updated_at`)",
            },
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
        name = "sky_phone_device_security",
        columns = {
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "passcode_hash", type = "BINARY(32) NOT NULL" },
            {
                name = "passcode_salt",
                type = "CHAR(32) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "passcode_length", type = "TINYINT UNSIGNED NOT NULL" },
            { name = "failed_attempts", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "locked_until", type = "BIGINT UNSIGNED NOT NULL DEFAULT 0" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "device_imei",
        foreignKeys = {
            {
                column = "device_imei",
                references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_admin_audit",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            {
                name = "actor_identifier",
                type = "VARCHAR(80) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "actor_name", type = "VARCHAR(120) NOT NULL" },
            {
                name = "target_identifier",
                type = "VARCHAR(80) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "target_source", type = "INT UNSIGNED NULL" },
            {
                name = "device_imei",
                type = "CHAR(15) NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "action",
                type = "VARCHAR(48) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "details", type = "LONGTEXT NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_admin_audit_created", columns = "(`created_at`, `id`)" },
            { name = "idx_sky_phone_admin_audit_target", columns = "(`target_identifier`, `created_at`)" },
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
        name = "sky_phone_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            {
                name = "device_imei",
                type = "CHAR(15) NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "url", type = "TEXT NOT NULL" },
            { name = "remote_id", type = "VARCHAR(128) NOT NULL" },
            { name = "media_type", type = "ENUM('photo', 'video', 'audio') NOT NULL" },
            { name = "mime_type", type = "VARCHAR(120) NULL" },
            { name = "origin", type = "ENUM('phone_upload', 'website_import') NOT NULL DEFAULT 'phone_upload'" },
            {
                name = "source_id",
                type = "VARCHAR(64) NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "verified_at", type = "DATETIME NULL" },
            { name = "favorite", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_media_account", columns = "(`account_id`, `created_at`, `id`)" },
            { name = "idx_sky_phone_media_device", columns = "(`device_imei`, `created_at`, `id`)" },
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
        name = "sky_phone_voice_memos",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "title", type = "VARCHAR(120) NOT NULL" },
            { name = "note", type = "VARCHAR(2000) NOT NULL DEFAULT ''" },
            { name = "duration_ms", type = "INT UNSIGNED NOT NULL" },
            { name = "size_bytes", type = "INT UNSIGNED NOT NULL" },
            { name = "waveform", type = "TEXT NOT NULL" },
            { name = "pinned", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_voice_memos_media", columns = "(`media_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_voice_memos_list", columns = "(`pinned`, `updated_at`, `id`)" },
        },
        foreignKeys = {
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
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
            { name = "notes", type = "VARCHAR(500) NULL" },
            { name = "organization", type = "VARCHAR(80) NULL" },
            { name = "email", type = "VARCHAR(64) NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "phone_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "favorite", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_contacts_account", columns = "(`account_id`, `name`)" },
            { name = "idx_sky_phone_contacts_device", columns = "(`device_imei`, `name`)" },
            { name = "idx_sky_phone_contacts_avatar", columns = "(`avatar_media_id`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
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
        name = "sky_phone_call_blocks",
        columns = {
            {
                name = "blocker_sim_id",
                type = "CHAR(36) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "blocked_sim_id",
                type = "CHAR(36) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = { "blocker_sim_id", "blocked_sim_id" },
        indexes = {
            { name = "idx_sky_phone_call_blocks_blocked", columns = "(`blocked_sim_id`)" },
        },
        foreignKeys = {
            { column = "blocker_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
            { column = "blocked_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
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
    {
        name = "sky_phone_health_daily",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "owner_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "activity_date", type = "DATE NOT NULL" },
            { name = "steps", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "distance_meters", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "active_seconds", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "energy_kcal", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_health_daily", columns = "(`owner_identifier`, `activity_date`)" },
        },
        indexes = {
            { name = "idx_sky_phone_health_history", columns = "(`owner_identifier`, `activity_date`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_health_profiles",
        columns = {
            { name = "owner_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "blood_type", type = "VARCHAR(3) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "allergies", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "conditions", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "medication", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "emergency_name", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "emergency_relation", type = "VARCHAR(40) NOT NULL DEFAULT ''" },
            { name = "emergency_phone", type = "VARCHAR(24) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_bin" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "owner_identifier",
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_billing_invoices",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_identifier", type = "VARCHAR(80) NOT NULL" },
            { name = "issuer_identifier", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "issuer_account", type = "VARCHAR(80) NOT NULL" },
            { name = "issuer_label", type = "VARCHAR(80) NOT NULL" },
            { name = "title", type = "VARCHAR(160) NOT NULL" },
            { name = "description", type = "VARCHAR(1000) NOT NULL DEFAULT ''" },
            { name = "amount", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "currency", type = "VARCHAR(8) NOT NULL", characterSet = "utf8mb4", collation = "utf8mb4_unicode_ci" },
            { name = "status", type = "ENUM('open', 'processing', 'paid', 'disputed', 'cancelled', 'refunded') NOT NULL DEFAULT 'open'" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "issued_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "due_at", type = "DATETIME NULL" },
            { name = "paid_at", type = "DATETIME NULL" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
            { name = "payment_reference", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_billing_recipient", columns = "(`recipient_identifier`, `status`, `due_at`, `id`)" },
            { name = "idx_sky_phone_billing_issuer", columns = "(`issuer_identifier`, `status`, `id`)" },
            { name = "idx_sky_phone_billing_unread", columns = "(`recipient_identifier`, `read_at`)" },
            { name = "idx_sky_phone_billing_account", columns = "(`issuer_account`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_billing_payments",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "invoice_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_identifier", type = "VARCHAR(80) NOT NULL" },
            { name = "amount", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "status", type = "ENUM('processing', 'paid', 'failed') NOT NULL DEFAULT 'processing'" },
            { name = "error_code", type = "VARCHAR(48) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = { { name = "idx_sky_phone_billing_payment_invoice", columns = "(`invoice_id`, `id`)" } },
        foreignKeys = { { column = "invoice_id", references = "`sky_phone_billing_invoices` (`id`) ON DELETE CASCADE" } },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_billing_events",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "invoice_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "event", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "actor_identifier", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "note", type = "VARCHAR(255) NOT NULL DEFAULT ''" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = { { name = "idx_sky_phone_billing_event_invoice", columns = "(`invoice_id`, `id`)" } },
        foreignKeys = { { column = "invoice_id", references = "`sky_phone_billing_invoices` (`id`) ON DELETE CASCADE" } },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_billing_accounts",
        columns = {
            { name = "account_key", type = "VARCHAR(80) NOT NULL" },
            { name = "balance", type = "BIGINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "account_key",
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_sms_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "message_type", type = "ENUM('text', 'voice', 'image', 'gif', 'video', 'contact', 'share') NOT NULL DEFAULT 'text'" },
            { name = "body", type = "VARCHAR(2000) NOT NULL" },
            { name = "media_payload", type = "MEDIUMTEXT NULL" },
            { name = "media_mime", type = "VARCHAR(64) NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "media_duration_ms", type = "INT UNSIGNED NULL" },
            { name = "media_waveform", type = "TEXT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_sms_sender", columns = "(`sender_sim_id`, `created_at`)" },
            { name = "idx_sky_phone_sms_recipient", columns = "(`recipient_sim_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "sender_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE SET NULL" },
            { column = "recipient_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_profiles",
        columns = {
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "display_name", type = "VARCHAR(40) NOT NULL" },
            { name = "bio", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "account_id",
        indexes = {
            { name = "idx_sky_phone_marketplace_profile_avatar", columns = "(`avatar_media_id`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_listings",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "seller_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "reserved_account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "title", type = "VARCHAR(70) NOT NULL" },
            { name = "description", type = "TEXT NOT NULL" },
            { name = "category", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "item_condition", type = "ENUM('new', 'very_good', 'used', 'defective') NOT NULL" },
            { name = "price_type", type = "ENUM('fixed', 'negotiable', 'free') NOT NULL" },
            { name = "price", type = "BIGINT UNSIGNED NULL" },
            { name = "district", type = "VARCHAR(32) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "show_phone", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "phone_number", type = "VARCHAR(24) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "ENUM('active', 'reserved', 'sold', 'expired', 'removed') NOT NULL DEFAULT 'active'" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
            { name = "expires_at", type = "DATETIME NOT NULL" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_marketplace_feed", columns = "(`status`, `created_at`)" },
            { name = "idx_sky_phone_marketplace_category", columns = "(`category`, `status`, `created_at`)" },
            { name = "idx_sky_phone_marketplace_seller", columns = "(`seller_account_id`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "seller_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "reserved_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_images",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "listing_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "gradient", type = "VARCHAR(2200) NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_marketplace_image_order", columns = "(`listing_id`, `sort_order`)" },
        },
        foreignKeys = {
            { column = "listing_id", references = "`sky_phone_marketplace_listings` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_favorites",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "listing_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_marketplace_favorite", columns = "(`account_id`, `listing_id`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "listing_id", references = "`sky_phone_marketplace_listings` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_inquiries",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "listing_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "seller_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "buyer_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "offer_id", type = "BIGINT UNSIGNED NULL" },
            { name = "offer_amount", type = "BIGINT UNSIGNED NULL" },
            { name = "offer_proposer_account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "offer_status", type = "ENUM('pending', 'accepted', 'rejected') NULL" },
            { name = "offer_revision", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_marketplace_inquiry", columns = "(`listing_id`, `buyer_account_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_marketplace_inquiry_seller", columns = "(`seller_account_id`, `updated_at`)" },
            { name = "idx_sky_phone_marketplace_inquiry_buyer", columns = "(`buyer_account_id`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "listing_id", references = "`sky_phone_marketplace_listings` (`id`) ON DELETE CASCADE" },
            { column = "seller_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "buyer_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_messages",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "inquiry_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "body", type = "VARCHAR(1000) NOT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_marketplace_messages", columns = "(`inquiry_id`, `id`)" },
            { name = "idx_sky_phone_marketplace_unread", columns = "(`inquiry_id`, `read_at`, `sender_account_id`)" },
        },
        foreignKeys = {
            { column = "inquiry_id", references = "`sky_phone_marketplace_inquiries` (`id`) ON DELETE CASCADE" },
            { column = "sender_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_offers",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "inquiry_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "proposer_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "amount", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "status", type = "ENUM('pending', 'accepted', 'rejected', 'countered') NOT NULL DEFAULT 'pending'" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "response_read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_marketplace_offers", columns = "(`inquiry_id`, `id`)" },
            { name = "idx_sky_phone_marketplace_offer_unread", columns = "(`inquiry_id`, `read_at`, `proposer_account_id`)" },
            { name = "idx_sky_phone_marketplace_offer_response_unread", columns = "(`inquiry_id`, `response_read_at`, `proposer_account_id`)" },
        },
        foreignKeys = {
            { column = "inquiry_id", references = "`sky_phone_marketplace_inquiries` (`id`) ON DELETE CASCADE" },
            { column = "proposer_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_blocks",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "blocker_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "blocked_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_marketplace_block", columns = "(`blocker_account_id`, `blocked_account_id`)" },
        },
        foreignKeys = {
            { column = "blocker_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "blocked_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_marketplace_reports",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reporter_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "listing_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reason", type = "ENUM('prohibited', 'fraud', 'spam', 'offensive', 'other') NOT NULL" },
            { name = "details", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('open', 'reviewed', 'dismissed') NOT NULL DEFAULT 'open'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_marketplace_report", columns = "(`reporter_account_id`, `listing_id`)" },
        },
        foreignKeys = {
            { column = "reporter_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "listing_id", references = "`sky_phone_marketplace_listings` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_pages_profiles",
        columns = {
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            {
                name = "handle",
                type = "VARCHAR(24) NOT NULL",
                characterSet = "utf8mb4",
                collation = "utf8mb4_unicode_ci",
            },
            { name = "bio", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "account_id",
        uniqueKeys = {
            { name = "uniq_sky_phone_pages_profile_handle", columns = "(`handle`)" },
        },
        indexes = {
            { name = "idx_sky_phone_pages_profile_avatar", columns = "(`avatar_media_id`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_pages_posts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "source_type", type = "ENUM('personal', 'citymarkt') NOT NULL DEFAULT 'personal'" },
            { name = "share_date", type = "DATE NULL" },
            { name = "citymarkt_listing_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(80) NOT NULL" },
            { name = "body", type = "TEXT NOT NULL" },
            { name = "category", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "district", type = "VARCHAR(32) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_pages_citymarkt_listing", columns = "(`citymarkt_listing_id`)" },
            { name = "uniq_sky_phone_pages_daily_share", columns = "(`account_id`, `source_type`, `share_date`)" },
        },
        indexes = {
            { name = "idx_sky_phone_pages_feed", columns = "(`created_at`)" },
            { name = "idx_sky_phone_pages_category", columns = "(`category`, `created_at`)" },
            { name = "idx_sky_phone_pages_owner", columns = "(`account_id`, `created_at`)" },
            { name = "idx_sky_phone_pages_daily_share", columns = "(`account_id`, `source_type`, `created_at`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "citymarkt_listing_id", references = "`sky_phone_marketplace_listings` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_pages_images",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "gradient", type = "VARCHAR(2200) NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_pages_image_order", columns = "(`post_id`, `sort_order`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_pages_posts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_pages_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "kind", type = "ENUM('like', 'save') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_pages_reaction", columns = "(`post_id`, `account_id`, `kind`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_pages_posts` (`id`) ON DELETE CASCADE" },
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_map_markers",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "label", type = "VARCHAR(40) NOT NULL" },
            { name = "color", type = "VARCHAR(16) NOT NULL" },
            { name = "position_x", type = "DOUBLE NOT NULL" },
            { name = "position_y", type = "DOUBLE NOT NULL" },
            { name = "position_z", type = "DOUBLE NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_map_markers_device", columns = "(`device_imei`, `created_at`)" },
        },
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_calendar_events",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "title", type = "VARCHAR(120) NOT NULL" },
            { name = "note", type = "TEXT NOT NULL" },
            { name = "starts_at", type = "DATETIME NOT NULL" },
            { name = "ends_at", type = "DATETIME NOT NULL" },
            { name = "reminder_minutes", type = "SMALLINT UNSIGNED NULL" },
            { name = "reminded_at", type = "DATETIME NULL" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_calendar_account", columns = "(`account_id`, `starts_at`)" },
            { name = "idx_sky_phone_calendar_reminders", columns = "(`reminded_at`, `starts_at`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_music_youtube_songs",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "device_imei", type = "CHAR(15) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "video_id", type = "CHAR(11) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(160) NOT NULL" },
            { name = "artist", type = "VARCHAR(120) NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_music_youtube_account", columns = "(`account_id`, `video_id`)" },
            { name = "uniq_sky_phone_music_youtube_device", columns = "(`device_imei`, `video_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_music_youtube_account", columns = "(`account_id`, `created_at`)" },
            { name = "idx_sky_phone_music_youtube_device", columns = "(`device_imei`, `created_at`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_music_playlists",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NULL" },
            { name = "device_imei", type = "CHAR(15) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "name", type = "VARCHAR(80) NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_music_playlists_account", columns = "(`account_id`, `updated_at`)" },
            { name = "idx_sky_phone_music_playlists_device", columns = "(`device_imei`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_music_playlist_items",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "playlist_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source", type = "ENUM('server', 'youtube') NOT NULL" },
            { name = "song_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "position", type = "SMALLINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_music_playlist_song", columns = "(`playlist_id`, `source`, `song_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_music_playlist_order", columns = "(`playlist_id`, `position`, `id`)" },
        },
        foreignKeys = {
            { column = "playlist_id", references = "`sky_phone_music_playlists` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_radio_profiles",
        columns = {
            { name = "identifier", type = "VARCHAR(80) NOT NULL" },
            { name = "history", type = "LONGTEXT NOT NULL" },
            { name = "settings", type = "LONGTEXT NOT NULL" },
            { name = "primary_frequency", type = "DOUBLE NOT NULL DEFAULT 0" },
            { name = "secondary_frequency", type = "DOUBLE NOT NULL DEFAULT 0" },
            { name = "badge", type = "VARCHAR(32) NOT NULL DEFAULT ''" },
            { name = "display_name", type = "VARCHAR(64) NOT NULL DEFAULT ''" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
        },
        primaryKey = "identifier",
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_profiles",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "dark_id", type = "CHAR(14) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "invite_code", type = "CHAR(11) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "alias", type = "VARCHAR(32) NOT NULL" },
            { name = "avatar_seed", type = "INT UNSIGNED NOT NULL" },
            { name = "notification_mode", type = "ENUM('full', 'private', 'hidden') NOT NULL DEFAULT 'private'" },
            { name = "activity_visible", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_darkchat_profile_account", columns = "(`account_id`)" },
            { name = "uniq_sky_phone_darkchat_profile_dark_id", columns = "(`dark_id`)" },
            { name = "uniq_sky_phone_darkchat_profile_invite", columns = "(`invite_code`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_contacts",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "contact_profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "alias_override", type = "VARCHAR(32) NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_darkchat_contact", columns = "(`profile_id`, `contact_profile_id`)" },
        },
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
            { column = "contact_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_conversations",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "disappearing_seconds", type = "INT NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_darkchat_conversation_updated", columns = "(`updated_at`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_members",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "conversation_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "notifications_enabled", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "read_receipts", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "last_read_at", type = "DATETIME NULL" },
            { name = "cleared_at", type = "DATETIME NULL" },
            { name = "joined_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_darkchat_member", columns = "(`conversation_id`, `profile_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_darkchat_member_profile", columns = "(`profile_id`, `conversation_id`)" },
        },
        foreignKeys = {
            { column = "conversation_id", references = "`sky_phone_darkchat_conversations` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "conversation_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_profile_id", type = "BIGINT UNSIGNED NULL" },
            { name = "message_type", type = "ENUM('text', 'emoji', 'gif', 'voice', 'image', 'video', 'share', 'system') NOT NULL DEFAULT 'text'" },
            { name = "body", type = "TEXT NOT NULL" },
            { name = "media_payload", type = "LONGTEXT NULL" },
            { name = "media_mime", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_duration_ms", type = "INT UNSIGNED NULL" },
            { name = "media_waveform", type = "JSON NULL" },
            { name = "reply_to_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reactions", type = "JSON NULL" },
            { name = "deleted_for_profiles", type = "JSON NULL" },
            { name = "deleted_for_everyone", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "expires_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_darkchat_message_thread", columns = "(`conversation_id`, `created_at`, `id`)" },
            { name = "idx_sky_phone_darkchat_message_expiry", columns = "(`expires_at`)" },
        },
        foreignKeys = {
            { column = "conversation_id", references = "`sky_phone_darkchat_conversations` (`id`) ON DELETE CASCADE" },
            { column = "sender_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_blocks",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "blocker_profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "blocked_profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_darkchat_block", columns = "(`blocker_profile_id`, `blocked_profile_id`)" },
        },
        foreignKeys = {
            { column = "blocker_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
            { column = "blocked_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_darkchat_reports",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reporter_profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "reported_profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "conversation_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "message_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reason", type = "ENUM('spam', 'harassment', 'threats', 'illegal', 'other') NOT NULL" },
            { name = "details", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('open', 'reviewed', 'dismissed') NOT NULL DEFAULT 'open'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_darkchat_report_target", columns = "(`reported_profile_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "reporter_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
            { column = "reported_profile_id", references = "`sky_phone_darkchat_profiles` (`id`) ON DELETE CASCADE" },
            { column = "conversation_id", references = "`sky_phone_darkchat_conversations` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_profiles",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "handle", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "display_name", type = "VARCHAR(40) NOT NULL" },
            { name = "bio", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "private", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "verified", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "status", type = "ENUM('active', 'hidden', 'removed') NOT NULL DEFAULT 'active'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_account", columns = "(`account_id`)" },
            { name = "uniq_sky_phone_picstagram_handle", columns = "(`handle`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_credentials",
        columns = {
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "password_hash", type = "BINARY(32) NOT NULL" },
            { name = "password_salt", type = "CHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "profile_id",
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_sessions",
        columns = {
            { name = "device_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "device_imei",
        indexes = {
            { name = "idx_sky_phone_picstagram_sessions_profile", columns = "(`profile_id`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_posts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "caption", type = "VARCHAR(800) NOT NULL DEFAULT ''" },
            { name = "location", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "comments_enabled", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "status", type = "ENUM('published', 'archived', 'hidden', 'removed') NOT NULL DEFAULT 'published'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_picstagram_feed", columns = "(`status`, `created_at`, `id`)" },
            { name = "idx_sky_phone_picstagram_profile_posts", columns = "(`profile_id`, `status`, `created_at`)" },
        },
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_post_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "position", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_post_position", columns = "(`post_id`, `position`)" },
            { name = "uniq_sky_phone_picstagram_post_media", columns = "(`post_id`, `media_id`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "kind", type = "ENUM('like', 'save') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_reaction", columns = "(`post_id`, `profile_id`, `kind`)" },
        },
        indexes = {
            { name = "idx_sky_phone_picstagram_saved", columns = "(`profile_id`, `kind`, `created_at`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_follows",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "follower_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "following_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "ENUM('pending', 'accepted') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_follow", columns = "(`follower_id`, `following_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_picstagram_following", columns = "(`following_id`, `status`, `created_at`)" },
        },
        foreignKeys = {
            { column = "follower_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "following_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_comments",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "parent_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "body", type = "VARCHAR(300) NOT NULL" },
            { name = "status", type = "ENUM('visible', 'removed') NOT NULL DEFAULT 'visible'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_picstagram_comments", columns = "(`post_id`, `status`, `created_at`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "parent_id", references = "`sky_phone_picstagram_comments` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_comment_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "comment_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_comment_reaction", columns = "(`comment_id`, `profile_id`)" },
        },
        foreignKeys = {
            { column = "comment_id", references = "`sky_phone_picstagram_comments` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_stories",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "body", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('active', 'removed') NOT NULL DEFAULT 'active'" },
            { name = "expires_at", type = "DATETIME NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_picstagram_stories", columns = "(`profile_id`, `status`, `expires_at`)" },
            { name = "idx_sky_phone_picstagram_story_expiry", columns = "(`status`, `expires_at`)" },
        },
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_story_views",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "story_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_story_view", columns = "(`story_id`, `profile_id`)" },
        },
        foreignKeys = {
            { column = "story_id", references = "`sky_phone_picstagram_stories` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_activities",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "actor_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "post_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "kind", type = "ENUM('follow_request', 'follow', 'request_accepted', 'like', 'comment', 'comment_like', 'reply', 'verified') NOT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_picstagram_activity", columns = "(`recipient_id`, `read_at`, `created_at`)" },
        },
        foreignKeys = {
            { column = "recipient_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "actor_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "post_id", references = "`sky_phone_picstagram_posts` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_reports",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reporter_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "target_type", type = "ENUM('profile', 'post', 'story', 'comment') NOT NULL" },
            { name = "target_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reason", type = "ENUM('spam', 'harassment', 'dangerous', 'illegal', 'other') NOT NULL" },
            { name = "details", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('open', 'reviewed', 'dismissed') NOT NULL DEFAULT 'open'" },
            { name = "resolved_action", type = "VARCHAR(16) NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "resolved_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_report", columns = "(`reporter_id`, `target_type`, `target_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_picstagram_reports", columns = "(`status`, `created_at`)" },
        },
        foreignKeys = {
            { column = "reporter_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_blocks",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "blocker_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "blocked_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_picstagram_block", columns = "(`blocker_id`, `blocked_id`)" },
        },
        foreignKeys = {
            { column = "blocker_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
            { column = "blocked_id", references = "`sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_picstagram_moderation_audit",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "report_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "moderator_identifier", type = "VARCHAR(80) NOT NULL" },
            { name = "action", type = "VARCHAR(16) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "target_type", type = "VARCHAR(16) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "target_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_picstagram_audit_target", columns = "(`target_type`, `target_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "report_id", references = "`sky_phone_picstagram_reports` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_profiles",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "handle", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "display_name", type = "VARCHAR(40) NOT NULL" },
            { name = "bio", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "account_type", type = "ENUM('person', 'business', 'organization', 'media', 'event') NOT NULL DEFAULT 'person'" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "verified", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_fliptok_account", columns = "(`account_id`)" },
            { name = "uniq_sky_phone_fliptok_handle", columns = "(`handle`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_credentials",
        columns = {
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "password_hash", type = "BINARY(32) NOT NULL" },
            { name = "password_salt", type = "CHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "profile_id",
        foreignKeys = {{ column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" }},
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_sessions",
        columns = {
            { name = "device_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "device_imei",
        indexes = {{ name = "idx_sky_phone_fliptok_sessions_profile", columns = "(`profile_id`, `updated_at`)" }},
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_videos",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "caption", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "location", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "visibility", type = "ENUM('public', 'followers', 'private') NOT NULL DEFAULT 'public'" },
            { name = "comments_enabled", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "trim_start_ms", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "trim_end_ms", type = "INT UNSIGNED NULL" },
            { name = "cover_time_ms", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "original_volume", type = "TINYINT UNSIGNED NOT NULL DEFAULT 100" },
            { name = "music_volume", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "music_track", type = "VARCHAR(64) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "custom_music_url", type = "VARCHAR(2048) NOT NULL DEFAULT ''", characterSet = "ascii", collation = "ascii_bin" },
            { name = "custom_music_title", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "custom_music_artist", type = "VARCHAR(120) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('draft', 'published', 'removed') NOT NULL DEFAULT 'published'" },
            { name = "view_count", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "share_count", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_fliptok_feed", columns = "(`status`, `visibility`, `created_at`)" },
            { name = "idx_sky_phone_fliptok_profile", columns = "(`profile_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_video_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "video_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_fliptok_video_media_order", columns = "(`video_id`, `sort_order`)" },
            { name = "uniq_sky_phone_fliptok_video_media", columns = "(`video_id`, `media_id`)" },
        },
        foreignKeys = {
            { column = "video_id", references = "`sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "video_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "kind", type = "ENUM('like', 'save') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_fliptok_reaction", columns = "(`video_id`, `profile_id`, `kind`)" }},
        foreignKeys = {
            { column = "video_id", references = "`sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_follows",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "follower_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "following_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_fliptok_follow", columns = "(`follower_id`, `following_id`)" }},
        foreignKeys = {
            { column = "follower_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "following_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_comments",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "video_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "parent_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "body", type = "VARCHAR(300) NOT NULL" },
            { name = "status", type = "ENUM('visible', 'removed') NOT NULL DEFAULT 'visible'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_fliptok_comments", columns = "(`video_id`, `created_at`)" },
            { name = "idx_sky_phone_fliptok_comment_parent", columns = "(`parent_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "video_id", references = "`sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "parent_id", references = "`sky_phone_fliptok_comments` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_comment_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "comment_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_fliptok_comment_reaction", columns = "(`comment_id`, `profile_id`)" },
        },
        foreignKeys = {
            { column = "comment_id", references = "`sky_phone_fliptok_comments` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_notifications",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "actor_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "video_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "kind", type = "ENUM('like', 'comment', 'follow', 'verified') NOT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {{ name = "idx_sky_phone_fliptok_activity", columns = "(`recipient_id`, `created_at`)" }},
        foreignKeys = {
            { column = "recipient_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "actor_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "video_id", references = "`sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_reports",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reporter_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "video_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reason", type = "ENUM('spam', 'harassment', 'dangerous', 'illegal', 'other') NOT NULL" },
            { name = "details", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('open', 'reviewed', 'dismissed') NOT NULL DEFAULT 'open'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_fliptok_report", columns = "(`reporter_id`, `video_id`)" }},
        foreignKeys = {
            { column = "reporter_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "video_id", references = "`sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_fliptok_blocks",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "blocker_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "blocked_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_fliptok_block", columns = "(`blocker_id`, `blocked_id`)" }},
        foreignKeys = {
            { column = "blocker_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
            { column = "blocked_id", references = "`sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_flare_profiles",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "name", type = "VARCHAR(32) NOT NULL" },
            { name = "age", type = "TINYINT UNSIGNED NOT NULL" },
            { name = "bio", type = "VARCHAR(300) NOT NULL DEFAULT ''" },
            { name = "gender", type = "ENUM('woman', 'man', 'nonbinary') NOT NULL" },
            { name = "interested_in", type = "ENUM('woman', 'man', 'nonbinary', 'everyone') NOT NULL DEFAULT 'everyone'" },
            { name = "min_age", type = "TINYINT UNSIGNED NOT NULL DEFAULT 18" },
            { name = "max_age", type = "TINYINT UNSIGNED NOT NULL DEFAULT 99" },
            { name = "avatar", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "interests", type = "JSON NOT NULL" },
            { name = "looking_for", type = "ENUM('longTerm', 'dates', 'friends') NOT NULL DEFAULT 'longTerm'" },
            { name = "discoverable", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_flare_profile_account", columns = "(`account_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_flare_discovery", columns = "(`gender`, `age`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_flare_profile_photos",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_flare_photo_order", columns = "(`profile_id`, `sort_order`)" },
            { name = "uniq_sky_phone_flare_photo_media", columns = "(`profile_id`, `media_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_flare_photo_media", columns = "(`media_id`)" },
        },
        foreignKeys = {
            {
                column = "profile_id",
                references = "`sky_phone_flare_profiles` (`id`) ON DELETE CASCADE",
            },
            {
                column = "media_id",
                references = "`sky_phone_media` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_flare_swipes",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "swiper_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "target_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "choice", type = "ENUM('like', 'pass', 'superlike') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_flare_swipe", columns = "(`swiper_account_id`, `target_account_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_flare_swipe_target", columns = "(`target_account_id`, `choice`)" },
        },
        foreignKeys = {
            { column = "swiper_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "target_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_flare_matches",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_a_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "account_b_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_flare_match_pair", columns = "(`account_a_id`, `account_b_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_flare_match_b", columns = "(`account_b_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "account_a_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "account_b_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_flare_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "match_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "body", type = "VARCHAR(1000) NOT NULL" },
            { name = "message_type", type = "ENUM('text', 'image', 'gif', 'video', 'share') NOT NULL DEFAULT 'text'" },
            { name = "media_url", type = "VARCHAR(2048) NULL" },
            { name = "share_payload", type = "LONGTEXT NULL" },
            { name = "media_duration_ms", type = "INT UNSIGNED NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_flare_message_thread", columns = "(`match_id`, `created_at`, `id`)" },
            { name = "idx_sky_phone_flare_message_unread", columns = "(`match_id`, `sender_account_id`, `read_at`)" },
        },
        foreignKeys = {
            { column = "match_id", references = "`sky_phone_flare_matches` (`id`) ON DELETE CASCADE" },
            { column = "sender_account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_skyride_profiles",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            {
                name = "owner_identifier",
                type = "VARCHAR(80) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "display_name", type = "VARCHAR(50) NULL" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_skyride_owner", columns = "(`owner_identifier`)" },
        },
        indexes = {
            { name = "idx_sky_phone_skyride_profile_avatar", columns = "(`avatar_media_id`)" },
        },
        foreignKeys = {
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_profiles",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "handle", type = "VARCHAR(30) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "display_name", type = "VARCHAR(50) NOT NULL" },
            { name = "bio", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "verified", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_feather_account", columns = "(`account_id`)" },
            { name = "uniq_sky_phone_feather_handle", columns = "(`handle`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_skyride_rides",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            {
                name = "passenger_profile_id",
                type = "CHAR(36) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            {
                name = "driver_profile_id",
                type = "CHAR(36) NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "passenger_name", type = "VARCHAR(80) NOT NULL" },
            { name = "driver_name", type = "VARCHAR(80) NULL" },
            {
                name = "status",
                type = "ENUM('payment_pending','searching','accepted','arrived','in_progress','completing','completed','cancelled') NOT NULL",
            },
            {
                name = "service_class",
                type = "ENUM('taxi','comfort','xl','premium') NOT NULL",
            },
            { name = "pickup_label", type = "VARCHAR(80) NOT NULL" },
            { name = "pickup_x", type = "DECIMAL(10,3) NOT NULL" },
            { name = "pickup_y", type = "DECIMAL(10,3) NOT NULL" },
            { name = "pickup_z", type = "DECIMAL(10,3) NOT NULL" },
            { name = "destination_label", type = "VARCHAR(80) NOT NULL" },
            { name = "destination_x", type = "DECIMAL(10,3) NOT NULL" },
            { name = "destination_y", type = "DECIMAL(10,3) NOT NULL" },
            { name = "destination_z", type = "DECIMAL(10,3) NOT NULL" },
            { name = "distance_meters", type = "INT UNSIGNED NOT NULL" },
            { name = "duration_seconds", type = "INT UNSIGNED NOT NULL" },
            { name = "price", type = "INT UNSIGNED NOT NULL" },
            { name = "payout_amount", type = "INT UNSIGNED NOT NULL" },
            {
                name = "currency",
                type = "VARCHAR(8) NOT NULL",
                characterSet = "utf8mb4",
                collation = "utf8mb4_unicode_ci",
            },
            { name = "driver_vehicle_model", type = "VARCHAR(64) NULL" },
            { name = "driver_vehicle_color", type = "VARCHAR(64) NULL" },
            { name = "driver_vehicle_plate", type = "VARCHAR(16) NULL" },
            { name = "cancelled_by", type = "ENUM('passenger','driver','system') NULL" },
            { name = "cancel_reason", type = "VARCHAR(32) NULL" },
            { name = "passenger_rating", type = "TINYINT UNSIGNED NULL" },
            { name = "rating_comment", type = "VARCHAR(300) NULL" },
            { name = "tip_amount", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            {
                name = "refund_status",
                type = "ENUM('none','pending','processing','completed') NOT NULL DEFAULT 'none'",
            },
            {
                name = "tip_status",
                type = "ENUM('none','processing','completed','failed') NOT NULL DEFAULT 'none'",
            },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            {
                name = "updated_at",
                type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
            },
            { name = "accepted_at", type = "DATETIME NULL" },
            { name = "arrived_at", type = "DATETIME NULL" },
            { name = "started_at", type = "DATETIME NULL" },
            { name = "completed_at", type = "DATETIME NULL" },
            { name = "cancelled_at", type = "DATETIME NULL" },
            { name = "refunded_at", type = "DATETIME NULL" },
            { name = "paid_out_at", type = "DATETIME NULL" },
        },
        primaryKey = "id",
        indexes = {
            {
                name = "idx_sky_phone_skyride_passenger",
                columns = "(`passenger_profile_id`, `status`, `updated_at`)",
            },
            {
                name = "idx_sky_phone_skyride_driver",
                columns = "(`driver_profile_id`, `status`, `updated_at`)",
            },
            { name = "idx_sky_phone_skyride_requests", columns = "(`status`, `created_at`)" },
            {
                name = "idx_sky_phone_skyride_refunds",
                columns = "(`refund_status`, `status`, `updated_at`)",
            },
        },
        foreignKeys = {
            {
                column = "passenger_profile_id",
                references = "`sky_phone_skyride_profiles` (`id`) ON DELETE CASCADE",
            },
            {
                column = "driver_profile_id",
                references = "`sky_phone_skyride_profiles` (`id`) ON DELETE SET NULL",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_posts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "body", type = "VARCHAR(360) NOT NULL DEFAULT ''" },
            { name = "reply_to_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "quote_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "ENUM('published', 'removed') NOT NULL DEFAULT 'published'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_feather_feed", columns = "(`status`, `created_at`)" },
            { name = "idx_sky_phone_feather_profile", columns = "(`profile_id`, `created_at`)" },
            { name = "idx_sky_phone_feather_replies", columns = "(`reply_to_id`, `created_at`)" },
        },
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "reply_to_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE SET NULL" },
            { column = "quote_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_hashtags",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "tag", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_feather_hashtag", columns = "(`post_id`, `tag`)" }},
        indexes = {{ name = "idx_sky_phone_feather_hashtag_rank", columns = "(`tag`, `post_id`)" }},
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_post_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_feather_media_order", columns = "(`post_id`, `sort_order`)" },
            { name = "uniq_sky_phone_feather_media", columns = "(`post_id`, `media_id`)" },
        },
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_reactions",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "kind", type = "ENUM('like', 'bookmark') NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_feather_reaction", columns = "(`post_id`, `profile_id`, `kind`)" }},
        foreignKeys = {
            { column = "post_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_follows",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "follower_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "following_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_feather_follow", columns = "(`follower_id`, `following_id`)" }},
        foreignKeys = {
            { column = "follower_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "following_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_notifications",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "actor_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "post_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "kind", type = "ENUM('like', 'reply', 'follow', 'quote') NOT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {{ name = "idx_sky_phone_feather_activity", columns = "(`recipient_id`, `created_at`)" }},
        foreignKeys = {
            { column = "recipient_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "actor_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "post_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_blocks",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "blocker_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "blocked_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_feather_block", columns = "(`blocker_id`, `blocked_id`)" }},
        foreignKeys = {
            { column = "blocker_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "blocked_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_feather_reports",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reporter_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "post_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reason", type = "ENUM('spam', 'harassment', 'dangerous', 'illegal', 'other') NOT NULL" },
            { name = "details", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "status", type = "ENUM('open', 'reviewed', 'dismissed') NOT NULL DEFAULT 'open'" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {{ name = "uniq_sky_phone_feather_report", columns = "(`reporter_id`, `post_id`)" }},
        foreignKeys = {
            { column = "reporter_id", references = "`sky_phone_feather_profiles` (`id`) ON DELETE CASCADE" },
            { column = "post_id", references = "`sky_phone_feather_posts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_profiles",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "account_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "username", type = "VARCHAR(20) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "avatar_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "active_group_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "map_visible", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "overhead_visible", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_crewlink_account", columns = "(`account_id`)" },
            { name = "uniq_sky_phone_crewlink_username", columns = "(`username`)" },
        },
        indexes = {
            { name = "idx_sky_phone_crewlink_active", columns = "(`active_group_id`)" },
            { name = "idx_sky_phone_crewlink_avatar", columns = "(`avatar_media_id`)" },
        },
        foreignKeys = {
            { column = "account_id", references = "`sky_phone_accounts` (`id`) ON DELETE CASCADE" },
            { column = "avatar_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_credentials",
        columns = {
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "password_hash", type = "BINARY(32) NOT NULL" },
            { name = "password_salt", type = "CHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "profile_id",
        foreignKeys = {
            { column = "profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_sessions",
        columns = {
            { name = "device_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "device_imei",
        indexes = {
            { name = "idx_sky_phone_crewlink_sessions_profile", columns = "(`profile_id`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_groups",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "name", type = "VARCHAR(32) NOT NULL" },
            { name = "colour", type = "ENUM('cyan','blue','violet','orange','green','rose') NOT NULL DEFAULT 'cyan'" },
            { name = "owner_profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "invite_code", type = "VARCHAR(12) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "allow_member_pings", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "overhead_allowed", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_crewlink_invite_code", columns = "(`invite_code`)" },
        },
        indexes = {
            { name = "idx_sky_phone_crewlink_owner", columns = "(`owner_profile_id`)" },
        },
        foreignKeys = {
            { column = "owner_profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_memberships",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "group_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "role", type = "ENUM('owner','coordinator','moderator','member','guest') NOT NULL DEFAULT 'member'" },
            { name = "joined_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_crewlink_membership", columns = "(`group_id`, `profile_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_crewlink_profile_groups", columns = "(`profile_id`, `joined_at`)" },
        },
        foreignKeys = {
            { column = "group_id", references = "`sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE" },
            { column = "profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_invitations",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "group_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "inviter_profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "invitee_profile_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "ENUM('pending','accepted','declined','expired') NOT NULL DEFAULT 'pending'" },
            { name = "expires_at", type = "DATETIME NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_crewlink_pending_invite", columns = "(`group_id`, `invitee_profile_id`)" },
        },
        indexes = {
            { name = "idx_sky_phone_crewlink_invitee", columns = "(`invitee_profile_id`, `status`, `expires_at`)" },
        },
        foreignKeys = {
            { column = "group_id", references = "`sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE" },
            { column = "inviter_profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
            { column = "invitee_profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_crewlink_pings",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "group_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "creator_profile_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source_resource", type = "VARCHAR(64) NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "type", type = "ENUM('meeting','danger','help','target','info') NOT NULL" },
            { name = "label", type = "VARCHAR(48) NOT NULL" },
            { name = "position_x", type = "DECIMAL(10,3) NOT NULL" },
            { name = "position_y", type = "DECIMAL(10,3) NOT NULL" },
            { name = "position_z", type = "DECIMAL(10,3) NOT NULL" },
            { name = "expires_at", type = "DATETIME NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_crewlink_pings", columns = "(`group_id`, `expires_at`)" },
        },
        foreignKeys = {
            { column = "group_id", references = "`sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE" },
            { column = "creator_profile_id", references = "`sky_phone_crewlink_profiles` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_easyshare_preferences",
        columns = {
            {
                name = "device_imei",
                type = "CHAR(15) NOT NULL",
                characterSet = "ascii",
                collation = "ascii_bin",
            },
            { name = "visibility", type = "ENUM('everyone','contacts','hidden') NOT NULL DEFAULT 'everyone'" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "device_imei",
        foreignKeys = {
            { column = "device_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_profiles",
        columns = {
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "description", type = "VARCHAR(1000) NOT NULL DEFAULT ''" },
            { name = "district", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "location_label", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "address", type = "VARCHAR(160) NOT NULL DEFAULT ''" },
            { name = "location_x", type = "DECIMAL(10,3) NULL" },
            { name = "location_y", type = "DECIMAL(10,3) NULL" },
            { name = "location_z", type = "DECIMAL(10,3) NULL" },
            { name = "logo_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "cover_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "availability", type = "ENUM('available','busy','closed') NOT NULL DEFAULT 'closed'" },
            { name = "availability_updated_by", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "availability_updated_at", type = "DATETIME NULL" },
            { name = "availability_expires_at", type = "DATETIME NULL" },
            { name = "accepts_requests", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "mutation_token", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "company_id",
        indexes = {
            { name = "idx_sky_phone_company_profiles_public", columns = "(`availability`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "logo_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
            { column = "cover_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_easyshare_transfers",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_imei", type = "CHAR(15) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_name", type = "VARCHAR(160) NOT NULL" },
            { name = "recipient_name", type = "VARCHAR(160) NOT NULL" },
            { name = "content_type", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "payload", type = "LONGTEXT NOT NULL" },
            { name = "status", type = "ENUM('pending','transferring','completed','declined','cancelled','expired','failed') NOT NULL DEFAULT 'pending'" },
            { name = "progress", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
            { name = "completed_at", type = "DATETIME NULL" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_easyshare_sender", columns = "(`sender_imei`, `created_at`)" },
            { name = "idx_sky_phone_easyshare_recipient", columns = "(`recipient_imei`, `created_at`)" },
        },
        foreignKeys = {
            { column = "sender_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
            { column = "recipient_imei", references = "`sky_phone_devices` (`imei`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_hours",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "weekday", type = "TINYINT UNSIGNED NOT NULL" },
            { name = "is_closed", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "opens_at", type = "CHAR(5) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "closes_at", type = "CHAR(5) NULL", characterSet = "ascii", collation = "ascii_bin" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_company_hours_day", columns = "(`company_id`, `weekday`)" },
        },
        foreignKeys = {
            { column = "company_id", references = "`sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_services",
        columns = {
            { name = "id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(80) NOT NULL" },
            { name = "description", type = "VARCHAR(500) NOT NULL DEFAULT ''" },
            { name = "price_text", type = "VARCHAR(80) NOT NULL DEFAULT ''" },
            { name = "requests_enabled", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "active", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "archived", type = "TINYINT(1) NOT NULL DEFAULT 0" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_services_list", columns = "(`company_id`, `archived`, `active`, `sort_order`)" },
        },
        foreignKeys = {
            { column = "company_id", references = "`sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_announcements",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(120) NOT NULL" },
            { name = "body", type = "VARCHAR(1000) NOT NULL" },
            { name = "created_by", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "active", type = "TINYINT(1) NOT NULL DEFAULT 1" },
            { name = "expires_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_announcements_active", columns = "(`company_id`, `active`, `expires_at`, `created_at`)" },
        },
        foreignKeys = {
            { column = "company_id", references = "`sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_requests",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "service_id", type = "VARCHAR(64) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "customer_sim_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "subject", type = "VARCHAR(120) NOT NULL" },
            { name = "description", type = "VARCHAR(2000) NOT NULL" },
            { name = "status", type = "ENUM('new','assigned','in_progress','waiting_customer','completed','cancelled') NOT NULL DEFAULT 'new'" },
            { name = "assigned_identifier", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "customer_unread", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "company_activity_revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "mutation_token", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
            { name = "completed_at", type = "DATETIME NULL" },
            { name = "cancelled_at", type = "DATETIME NULL" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_requests_customer", columns = "(`customer_sim_id`, `updated_at`, `id`)" },
            { name = "idx_sky_phone_company_requests_queue", columns = "(`company_id`, `status`, `updated_at`, `id`)" },
            { name = "idx_sky_phone_company_requests_assignee", columns = "(`company_id`, `assigned_identifier`, `status`)" },
        },
        foreignKeys = {
            { column = "company_id", references = "`sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE" },
            { column = "service_id", references = "`sky_phone_company_services` (`id`) ON DELETE SET NULL" },
            { column = "customer_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_request_reads",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "request_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "reader_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "read_revision", type = "INT UNSIGNED NOT NULL DEFAULT 0" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_company_request_reads_reader", columns = "(`request_id`, `reader_identifier`)" },
        },
        indexes = {
            { name = "idx_sky_phone_company_request_reads_identifier", columns = "(`reader_identifier`, `updated_at`)" },
        },
        foreignKeys = {
            { column = "request_id", references = "`sky_phone_company_requests` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_request_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "request_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "sort_order", type = "TINYINT UNSIGNED NOT NULL DEFAULT 0" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_company_request_media", columns = "(`request_id`, `media_id`)" },
            { name = "uniq_sky_phone_company_request_media_order", columns = "(`request_id`, `sort_order`)" },
        },
        foreignKeys = {
            { column = "request_id", references = "`sky_phone_company_requests` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_request_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "request_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_type", type = "ENUM('customer','company') NOT NULL" },
            { name = "sender_identifier", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "body", type = "VARCHAR(2000) NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_request_messages", columns = "(`request_id`, `created_at`, `id`)" },
        },
        foreignKeys = {
            { column = "request_id", references = "`sky_phone_company_requests` (`id`) ON DELETE CASCADE" },
            { column = "sender_sim_id", references = "`sky_phone_sims` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_request_events",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "request_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "event_type", type = "ENUM('created','assigned','status','cancelled') NOT NULL" },
            { name = "actor_type", type = "ENUM('customer','company','system') NOT NULL" },
            { name = "actor_identifier", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "from_status", type = "VARCHAR(32) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "to_status", type = "VARCHAR(32) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "detail", type = "VARCHAR(255) NOT NULL DEFAULT ''" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_request_events", columns = "(`request_id`, `created_at`, `id`)" },
        },
        foreignKeys = {
            { column = "request_id", references = "`sky_phone_company_requests` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_company_audit",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "company_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "actor_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "action", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "target_type", type = "VARCHAR(32) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "target_id", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "metadata", type = "LONGTEXT NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_company_audit", columns = "(`company_id`, `created_at`, `id`)" },
        },
        foreignKeys = {
            { column = "company_id", references = "`sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_weazel_articles",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(160) NOT NULL" },
            { name = "body", type = "LONGTEXT NOT NULL" },
            { name = "excerpt", type = "VARCHAR(240) NOT NULL" },
            { name = "category", type = "ENUM('official','events','jobs','news','business') NOT NULL" },
            { name = "image_media_id", type = "BIGINT UNSIGNED NULL" },
            { name = "author_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "author_name", type = "VARCHAR(120) NOT NULL" },
            { name = "updated_by_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "status", type = "ENUM('draft','published') NOT NULL DEFAULT 'draft'" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
            { name = "published_at", type = "DATETIME NULL" },
            { name = "deleted_at", type = "DATETIME NULL" },
            { name = "deleted_by_identifier", type = "VARCHAR(80) NULL", characterSet = "ascii", collation = "ascii_bin" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_weazel_public", columns = "(`status`, `deleted_at`, `published_at`, `id`)" },
            { name = "idx_sky_phone_weazel_category", columns = "(`category`, `status`, `deleted_at`, `published_at`, `id`)" },
            { name = "idx_sky_phone_weazel_manage", columns = "(`deleted_at`, `status`, `updated_at`, `id`)" },
            { name = "idx_sky_phone_weazel_media", columns = "(`image_media_id`)" },
        },
        foreignKeys = {
            { column = "image_media_id", references = "`sky_phone_media` (`id`) ON DELETE SET NULL" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_weazel_article_media",
        columns = {
            { name = "id", type = "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT" },
            { name = "article_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "media_id", type = "BIGINT UNSIGNED NOT NULL" },
            { name = "position", type = "TINYINT UNSIGNED NOT NULL" },
        },
        primaryKey = "id",
        uniqueKeys = {
            { name = "uniq_sky_phone_weazel_article_position", columns = "(`article_id`, `position`)" },
            { name = "uniq_sky_phone_weazel_article_media", columns = "(`article_id`, `media_id`)" },
        },
        foreignKeys = {
            { column = "article_id", references = "`sky_phone_weazel_articles` (`id`) ON DELETE CASCADE" },
            { column = "media_id", references = "`sky_phone_media` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_citywarn_alerts",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "title", type = "VARCHAR(120) NOT NULL" },
            { name = "body", type = "VARCHAR(2000) NOT NULL" },
            { name = "instructions", type = "VARCHAR(2000) NOT NULL" },
            { name = "category", type = "ENUM('public_safety','police','fire','medical','infrastructure','evacuation') NOT NULL" },
            { name = "severity", type = "ENUM('information','warning','danger','extreme') NOT NULL" },
            { name = "status", type = "ENUM('active','resolved','expired') NOT NULL DEFAULT 'active'" },
            { name = "area_type", type = "ENUM('radius','district','city') NOT NULL" },
            { name = "area_label", type = "VARCHAR(120) NOT NULL" },
            { name = "center_x", type = "DECIMAL(12,4) NULL" },
            { name = "center_y", type = "DECIMAL(12,4) NULL" },
            { name = "radius", type = "INT UNSIGNED NULL" },
            { name = "source_job", type = "VARCHAR(64) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "source_label", type = "VARCHAR(120) NOT NULL" },
            { name = "author_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "author_name", type = "VARCHAR(120) NOT NULL" },
            { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
            { name = "starts_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "expires_at", type = "DATETIME NOT NULL" },
            { name = "resolved_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
            { name = "updated_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_citywarn_active", columns = "(`status`, `expires_at`, `created_at`, `id`)" },
            { name = "idx_sky_phone_citywarn_area", columns = "(`area_type`, `status`, `created_at`, `id`)" },
            { name = "idx_sky_phone_citywarn_source", columns = "(`source_job`, `created_at`, `id`)" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
    {
        name = "sky_phone_citywarn_updates",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "alert_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "kind", type = "ENUM('published','update','resolved') NOT NULL" },
            { name = "message", type = "VARCHAR(2000) NOT NULL" },
            { name = "actor_identifier", type = "VARCHAR(80) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "actor_name", type = "VARCHAR(120) NOT NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        },
        primaryKey = "id",
        indexes = {
            { name = "idx_sky_phone_citywarn_timeline", columns = "(`alert_id`, `created_at`, `id`)" },
        },
        foreignKeys = {
            { column = "alert_id", references = "`sky_phone_citywarn_alerts` (`id`) ON DELETE CASCADE" },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
}

schema[#schema + 1] = SkyPhoneConfiguratorSchema

Bridge.Database.Migrate("sky_phone", schema)
Bridge.Database.Query([[
    INSERT IGNORE INTO `sky_phone_fliptok_video_media` (`video_id`, `media_id`, `sort_order`)
    SELECT `id`, `media_id`, 1 FROM `sky_phone_fliptok_videos`
]], {})
Bridge.Database.Query([[
    INSERT IGNORE INTO `sky_phone_weazel_article_media` (`article_id`, `media_id`, `position`)
    SELECT `id`, `image_media_id`, 1
    FROM `sky_phone_weazel_articles`
    WHERE `image_media_id` IS NOT NULL
]], {})
Bridge.Database.Query("DELETE FROM `sky_phone_feather_notifications` WHERE `kind` = 'repost'", {})
Bridge.Database.Query("DELETE FROM `sky_phone_feather_reactions` WHERE `kind` = 'repost'", {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_feather_reactions`
    MODIFY COLUMN `kind` ENUM('like', 'bookmark') NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_feather_notifications`
    MODIFY COLUMN `kind` ENUM('like', 'reply', 'follow', 'quote') NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_picstagram_activities`
    MODIFY COLUMN `kind` ENUM('follow_request', 'follow', 'request_accepted', 'like', 'comment', 'comment_like', 'reply', 'verified') NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_flare_swipes`
    MODIFY COLUMN `choice` ENUM('like', 'pass', 'superlike') NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_flare_messages`
    MODIFY COLUMN `message_type` ENUM('text', 'image', 'gif', 'video', 'share') NOT NULL DEFAULT 'text'
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_sms_messages`
    MODIFY COLUMN `message_type` ENUM('text', 'voice', 'image', 'gif', 'video', 'contact', 'share') NOT NULL DEFAULT 'text'
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_sms_messages`
    MODIFY COLUMN `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_darkchat_messages`
    MODIFY COLUMN `message_type` ENUM('text', 'emoji', 'gif', 'voice', 'image', 'video', 'share', 'system') NOT NULL DEFAULT 'text'
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_media`
    MODIFY COLUMN `media_type` ENUM('photo', 'video', 'audio') NOT NULL
]], {})
Bridge.Database.Query([[
    UPDATE `sky_phone_media`
    SET `mime_type` = CASE
        WHEN `media_type` = 'video' AND LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.webm' THEN 'video/webm'
        WHEN `media_type` = 'video' AND LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.mp4' THEN 'video/mp4'
        WHEN `media_type` = 'photo' AND LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.png' THEN 'image/png'
        WHEN `media_type` = 'photo' AND LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.webp' THEN 'image/webp'
        WHEN `media_type` = 'photo' AND (
            LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.jpg'
            OR LOWER(SUBSTRING_INDEX(`url`, '?', 1)) LIKE '%.jpeg'
        ) THEN 'image/jpeg'
        ELSE NULL
    END
    WHERE `mime_type` IS NULL OR `mime_type` = ''
]], {})
Bridge.Database.Query([[
    UPDATE `sky_phone_sms_messages` message
    INNER JOIN `sky_phone_media` media ON media.`url` = message.`media_payload`
    SET message.`media_mime` = media.`mime_type`
    WHERE message.`message_type` = 'video'
        AND media.`mime_type` IN ('video/webm', 'video/mp4')
        AND (message.`media_mime` IS NULL OR message.`media_mime` <> media.`mime_type`)
]], {})
Bridge.Database.Query([[
    UPDATE `sky_phone_darkchat_messages` message
    INNER JOIN `sky_phone_media` media ON media.`url` = message.`media_payload`
    SET message.`media_mime` = media.`mime_type`
    WHERE message.`message_type` = 'video'
        AND media.`mime_type` IN ('video/webm', 'video/mp4')
        AND (message.`media_mime` IS NULL OR message.`media_mime` <> media.`mime_type`)
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_marketplace_images`
    MODIFY COLUMN `gradient` VARCHAR(2200) NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_pages_images`
    MODIFY COLUMN `gradient` VARCHAR(2200) NOT NULL
]], {})
Bridge.Database.EnsureIndex("sky_phone_devices", "uniq_sky_phone_devices_sim", "(`sim_id`)", { unique = true })
Bridge.Database.Query("UPDATE `sky_phone_contacts` SET `contact_id` = `id` WHERE `contact_id` IS NULL", {})
Bridge.Database.EnsureIndex("sky_phone_contacts", "uniq_sky_phone_contacts_account_contact", "(`account_id`, `contact_id`)", { unique = true })
Bridge.Database.EnsureIndex("sky_phone_contacts", "uniq_sky_phone_contacts_device_contact", "(`device_imei`, `contact_id`)", { unique = true })
Bridge.Database.EnsureIndex(
    "sky_phone_media",
    "uniq_sky_phone_media_account_source",
    "(`account_id`, `source_id`, `remote_id`, `origin`)",
    { unique = true }
)
Bridge.Database.EnsureIndex(
    "sky_phone_media",
    "uniq_sky_phone_media_device_source",
    "(`device_imei`, `source_id`, `remote_id`, `origin`)",
    { unique = true }
)
Bridge.Database.CompleteMigration("sky_phone")
