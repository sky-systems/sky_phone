local schema = {
    {
        name = "sky_phone_mail_accounts",
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
                references = "`sky_phone_mail_accounts` (`id`) ON DELETE CASCADE",
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
                references = "`sky_phone_mail_accounts` (`id`) ON DELETE CASCADE",
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
                references = "`sky_phone_mail_accounts` (`id`) ON DELETE CASCADE",
            },
        },
        tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    },
}

Sky.DB.Migrate("sky_phone", schema)
