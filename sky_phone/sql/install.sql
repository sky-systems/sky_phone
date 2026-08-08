-- sky_phone fresh-install schema
-- MySQL/MariaDB with InnoDB and utf8mb4 support is required.
-- Runtime migrations remain enabled and handle upgrades of existing installations.

CREATE TABLE IF NOT EXISTS `sky_phone_accounts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `email` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `password` VARCHAR(64) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_mail_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_mail_messages` (
    `id` CHAR(36) NOT NULL,
    `sender_account_id` BIGINT UNSIGNED NOT NULL,
    `recipients` LONGTEXT NOT NULL,
    `subject` VARCHAR(120) NOT NULL DEFAULT '',
    `body` LONGTEXT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_mail_sender` (`sender_account_id`, `created_at`),
    FOREIGN KEY (`sender_account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_mail_entries` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `message_id` CHAR(36) NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `folder` ENUM('inbox', 'sent') NOT NULL,
    `read_at` DATETIME NULL,
    `trashed_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_mail_entry` (`message_id`, `account_id`, `folder`),
    KEY `idx_sky_phone_mailbox` (`account_id`, `folder`, `trashed_at`, `id`),
    FOREIGN KEY (`message_id`) REFERENCES `sky_phone_mail_messages` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_mail_drafts` (
    `id` CHAR(36) NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `recipients` LONGTEXT NOT NULL,
    `subject` VARCHAR(120) NOT NULL DEFAULT '',
    `body` LONGTEXT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_mail_drafts` (`account_id`, `updated_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_sims` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `contact_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `phone_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sim_type` ENUM('registered', 'anonymous') NOT NULL,
    `owner_identifier` VARCHAR(80) NULL,
    `owner_firstname` VARCHAR(80) NULL,
    `owner_lastname` VARCHAR(80) NULL,
    `owner_birthdate` VARCHAR(32) NULL,
    `registered_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_sim_number` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_devices` (
    `imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `device_name` VARCHAR(64) NOT NULL DEFAULT 'iFruit Phone',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`imei`),
    UNIQUE KEY `uniq_sky_phone_devices_sim` (`sim_id`),
    KEY `idx_sky_phone_devices_account` (`account_id`, `updated_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE SET NULL,
    FOREIGN KEY (`sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_device_data` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `namespace` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_device_namespace` (`device_imei`, `namespace`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_device_security` (
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `passcode_hash` BINARY(32) NOT NULL,
    `passcode_salt` CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `passcode_length` TINYINT UNSIGNED NOT NULL,
    `failed_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `locked_until` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`device_imei`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_notes` (
    `id` VARCHAR(64) NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `title` VARCHAR(120) NOT NULL DEFAULT '',
    `body` LONGTEXT NOT NULL,
    `pinned` TINYINT(1) NOT NULL DEFAULT 0,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_notes_account` (`account_id`, `updated_at`),
    KEY `idx_sky_phone_notes_device` (`device_imei`, `updated_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `url` TEXT NOT NULL,
    `remote_id` VARCHAR(128) NOT NULL,
    `media_type` ENUM('photo', 'video') NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_media_account` (`account_id`, `created_at`, `id`),
    KEY `idx_sky_phone_media_device` (`device_imei`, `created_at`, `id`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_contacts` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `contact_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `name` VARCHAR(80) NOT NULL,
    `phone_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_contacts_account_contact` (`account_id`, `contact_id`),
    UNIQUE KEY `uniq_sky_phone_contacts_device_contact` (`device_imei`, `contact_id`),
    KEY `idx_sky_phone_contacts_account` (`account_id`, `name`),
    KEY `idx_sky_phone_contacts_device` (`device_imei`, `name`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_calls` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `caller_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `callee_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `caller_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `callee_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `status` VARCHAR(24) NOT NULL,
    `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `answered_at` DATETIME NULL,
    `ended_at` DATETIME NULL,
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_calls_caller` (`caller_sim_id`, `started_at`),
    KEY `idx_sky_phone_calls_callee` (`callee_sim_id`, `started_at`),
    FOREIGN KEY (`caller_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`callee_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_call_entries` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `call_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `direction` ENUM('incoming', 'outgoing') NOT NULL,
    `status` VARCHAR(24) NOT NULL,
    `other_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_call_entries_account` (`account_id`, `created_at`),
    KEY `idx_sky_phone_call_entries_device` (`device_imei`, `created_at`),
    FOREIGN KEY (`call_id`) REFERENCES `sky_phone_calls` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_bank_transactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner_identifier` VARCHAR(80) NOT NULL,
    `kind` ENUM('deposit', 'withdrawal', 'transfer_in', 'transfer_out') NOT NULL,
    `amount` BIGINT UNSIGNED NOT NULL,
    `label` VARCHAR(160) NOT NULL DEFAULT '',
    `reference` VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_bank_owner` (`owner_identifier`, `id`),
    KEY `idx_sky_phone_bank_reference` (`reference`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_sms_messages` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sender_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `recipient_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `sender_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `recipient_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `message_type` ENUM('text', 'voice', 'image', 'gif', 'video') NOT NULL DEFAULT 'text',
    `body` VARCHAR(2000) NOT NULL,
    `media_payload` MEDIUMTEXT NULL,
    `media_mime` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
    `media_duration_ms` INT UNSIGNED NULL,
    `media_waveform` TEXT NULL,
    `read_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_sms_sender` (`sender_sim_id`, `created_at`),
    KEY `idx_sky_phone_sms_recipient` (`recipient_sim_id`, `created_at`),
    FOREIGN KEY (`sender_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE SET NULL,
    FOREIGN KEY (`recipient_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_calendar_events` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `note` TEXT NOT NULL,
    `starts_at` DATETIME NOT NULL,
    `ends_at` DATETIME NOT NULL,
    `reminder_minutes` SMALLINT UNSIGNED NULL,
    `reminded_at` DATETIME NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_calendar_account` (`account_id`, `starts_at`),
    KEY `idx_sky_phone_calendar_reminders` (`reminded_at`, `starts_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
