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
            { name = "media_type", type = "ENUM('photo', 'video') NOT NULL" },
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
    {
        name = "sky_phone_sms_messages",
        columns = {
            { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_sim_id", type = "CHAR(36) NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "sender_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "recipient_number", type = "VARCHAR(24) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            { name = "message_type", type = "ENUM('text', 'voice', 'image', 'gif', 'video') NOT NULL DEFAULT 'text'" },
            { name = "body", type = "VARCHAR(2000) NOT NULL" },
            { name = "media_payload", type = "MEDIUMTEXT NULL" },
            { name = "media_mime", type = "VARCHAR(64) NULL", characterSet = "ascii", collation = "ascii_general_ci" },
            { name = "media_duration_ms", type = "INT UNSIGNED NULL" },
            { name = "media_waveform", type = "TEXT NULL" },
            { name = "read_at", type = "DATETIME NULL" },
            { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
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
            { name = "message_type", type = "ENUM('text', 'emoji', 'gif', 'voice', 'image', 'video', 'system') NOT NULL DEFAULT 'text'" },
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
}

Bridge.Database.Migrate("sky_phone", schema)
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_flare_swipes`
    MODIFY COLUMN `choice` ENUM('like', 'pass', 'superlike') NOT NULL
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_sms_messages`
    MODIFY COLUMN `message_type` ENUM('text', 'voice', 'image', 'gif', 'video') NOT NULL DEFAULT 'text'
]], {})
Bridge.Database.Query([[
    ALTER TABLE `sky_phone_darkchat_messages`
    MODIFY COLUMN `message_type` ENUM('text', 'emoji', 'gif', 'voice', 'image', 'video', 'system') NOT NULL DEFAULT 'text'
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
Bridge.Database.CompleteMigration("sky_phone")
