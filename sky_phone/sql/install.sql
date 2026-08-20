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

CREATE TABLE IF NOT EXISTS `sky_phone_mailboxes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `sort_order` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_mailbox_name` (`account_id`, `name`),
    KEY `idx_sky_phone_mailboxes` (`account_id`, `sort_order`, `id`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_mail_entries` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `message_id` CHAR(36) NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `folder` ENUM('inbox', 'sent') NOT NULL,
    `mailbox_id` BIGINT UNSIGNED NULL,
    `read_at` DATETIME NULL,
    `trashed_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_mail_entry` (`message_id`, `account_id`, `folder`),
    KEY `idx_sky_phone_mailbox` (`account_id`, `folder`, `trashed_at`, `id`),
    KEY `idx_sky_phone_custom_mailbox` (`account_id`, `mailbox_id`, `trashed_at`, `id`),
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
    `is_virtual` TINYINT(1) NOT NULL DEFAULT 0,
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

CREATE TABLE IF NOT EXISTS `sky_phone_character_devices` (
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_identifier`),
    UNIQUE KEY `uniq_sky_phone_character_devices_device` (`device_imei`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_migrations` (
    `name` VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `source` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `stats` LONGTEXT NULL,
    `completed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`name`),
    KEY `idx_sky_phone_migrations_source` (`source`, `completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_migration_numbers` (
    `source` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `source_number` VARCHAR(64) NOT NULL,
    `phone_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `owned` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`source`, `source_number`),
    UNIQUE KEY `uniq_sky_phone_migration_number` (`source`, `phone_number`),
    KEY `idx_sky_phone_migration_numbers_sim` (`sim_id`),
    FOREIGN KEY (`sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_migration_owners` (
    `source` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `source_phone_id` VARCHAR(100) NOT NULL,
    `source_owner_id` VARCHAR(100) NOT NULL,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `source_phone_number` VARCHAR(64) NOT NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`source`, `source_phone_id`),
    UNIQUE KEY `uniq_sky_phone_migration_owner_number` (`source`, `source_phone_number`),
    KEY `idx_sky_phone_migration_owner` (`source`, `owner_identifier`),
    KEY `idx_sky_phone_migration_owner_device` (`device_imei`),
    KEY `idx_sky_phone_migration_owner_account` (`account_id`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE,
    FOREIGN KEY (`sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE SET NULL
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

CREATE TABLE IF NOT EXISTS `sky_phone_custom_app_data` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `app_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `data_key` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_custom_app_data` (`device_imei`, `app_id`, `data_key`),
    KEY `idx_sky_phone_custom_app_storage` (`device_imei`, `app_id`, `updated_at`),
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

CREATE TABLE IF NOT EXISTS `sky_phone_admin_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `actor_name` VARCHAR(120) NOT NULL,
    `target_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `target_source` INT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `action` VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `details` LONGTEXT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_admin_audit_created` (`created_at`, `id`),
    KEY `idx_sky_phone_admin_audit_target` (`target_identifier`, `created_at`)
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
    `media_type` ENUM('photo', 'video', 'audio') NOT NULL,
    `mime_type` VARCHAR(120) NULL,
    `origin` ENUM('phone_upload', 'website_import') NOT NULL DEFAULT 'phone_upload',
    `source_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `verified_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_media_account_source` (`account_id`, `source_id`, `remote_id`, `origin`),
    UNIQUE KEY `uniq_sky_phone_media_device_source` (`device_imei`, `source_id`, `remote_id`, `origin`),
    KEY `idx_sky_phone_media_account` (`account_id`, `created_at`, `id`),
    KEY `idx_sky_phone_media_device` (`device_imei`, `created_at`, `id`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_voice_memos` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `note` VARCHAR(2000) NOT NULL DEFAULT '',
    `duration_ms` INT UNSIGNED NOT NULL,
    `size_bytes` INT UNSIGNED NOT NULL,
    `waveform` TEXT NOT NULL,
    `pinned` TINYINT(1) NOT NULL DEFAULT 0,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_voice_memos_media` (`media_id`),
    KEY `idx_sky_phone_voice_memos_list` (`pinned`, `updated_at`, `id`),
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_contacts` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `contact_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `name` VARCHAR(80) NOT NULL,
    `notes` VARCHAR(500) NULL,
    `organization` VARCHAR(80) NULL,
    `email` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
    `phone_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `avatar_media_id` BIGINT UNSIGNED NULL,
    `favorite` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_contacts_account_contact` (`account_id`, `contact_id`),
    UNIQUE KEY `uniq_sky_phone_contacts_device_contact` (`device_imei`, `contact_id`),
    KEY `idx_sky_phone_contacts_account` (`account_id`, `name`),
    KEY `idx_sky_phone_contacts_device` (`device_imei`, `name`),
    KEY `idx_sky_phone_contacts_avatar` (`avatar_media_id`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE,
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
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

CREATE TABLE IF NOT EXISTS `sky_phone_call_blocks` (
    `blocker_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `blocked_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`blocker_sim_id`, `blocked_sim_id`),
    KEY `idx_sky_phone_call_blocks_blocked` (`blocked_sim_id`),
    FOREIGN KEY (`blocker_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`blocked_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE
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

CREATE TABLE IF NOT EXISTS `sky_phone_health_daily` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `activity_date` DATE NOT NULL,
    `steps` INT UNSIGNED NOT NULL DEFAULT 0,
    `distance_meters` INT UNSIGNED NOT NULL DEFAULT 0,
    `active_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `energy_kcal` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_health_daily` (`owner_identifier`, `activity_date`),
    KEY `idx_sky_phone_health_history` (`owner_identifier`, `activity_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_health_profiles` (
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `blood_type` VARCHAR(3) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT '',
    `allergies` VARCHAR(500) NOT NULL DEFAULT '',
    `conditions` VARCHAR(500) NOT NULL DEFAULT '',
    `medication` VARCHAR(500) NOT NULL DEFAULT '',
    `emergency_name` VARCHAR(80) NOT NULL DEFAULT '',
    `emergency_relation` VARCHAR(40) NOT NULL DEFAULT '',
    `emergency_phone` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_billing_invoices` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `recipient_identifier` VARCHAR(80) NOT NULL,
    `issuer_identifier` VARCHAR(80) NOT NULL DEFAULT '',
    `issuer_account` VARCHAR(80) NOT NULL,
    `issuer_label` VARCHAR(80) NOT NULL,
    `title` VARCHAR(160) NOT NULL,
    `description` VARCHAR(1000) NOT NULL DEFAULT '',
    `amount` BIGINT UNSIGNED NOT NULL,
    `currency` VARCHAR(8) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `status` ENUM('open', 'processing', 'paid', 'disputed', 'cancelled', 'refunded') NOT NULL DEFAULT 'open',
    `read_at` DATETIME NULL,
    `issued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `due_at` DATETIME NULL,
    `paid_at` DATETIME NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `payment_reference` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_billing_recipient` (`recipient_identifier`, `status`, `due_at`, `id`),
    KEY `idx_sky_phone_billing_issuer` (`issuer_identifier`, `status`, `id`),
    KEY `idx_sky_phone_billing_unread` (`recipient_identifier`, `read_at`),
    KEY `idx_sky_phone_billing_account` (`issuer_account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_billing_payments` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `invoice_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `recipient_identifier` VARCHAR(80) NOT NULL,
    `amount` BIGINT UNSIGNED NOT NULL,
    `status` ENUM('processing', 'paid', 'failed') NOT NULL DEFAULT 'processing',
    `error_code` VARCHAR(48) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_billing_payment_invoice` (`invoice_id`, `id`),
    FOREIGN KEY (`invoice_id`) REFERENCES `sky_phone_billing_invoices` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_billing_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `invoice_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `event` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `actor_identifier` VARCHAR(80) NOT NULL DEFAULT '',
    `note` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_billing_event_invoice` (`invoice_id`, `id`),
    FOREIGN KEY (`invoice_id`) REFERENCES `sky_phone_billing_invoices` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_billing_accounts` (
    `account_key` VARCHAR(80) NOT NULL,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_sms_messages` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sender_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `recipient_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `sender_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `recipient_number` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `message_type` ENUM('text', 'voice', 'image', 'gif', 'video', 'contact', 'share') NOT NULL DEFAULT 'text',
    `body` VARCHAR(2000) NOT NULL,
    `media_payload` MEDIUMTEXT NULL,
    `media_mime` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
    `media_duration_ms` INT UNSIGNED NULL,
    `media_waveform` TEXT NULL,
    `read_at` DATETIME NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
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

CREATE TABLE IF NOT EXISTS `sky_phone_music_youtube_songs` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `video_id` CHAR(11) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `title` VARCHAR(160) NOT NULL,
    `artist` VARCHAR(120) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_music_youtube_account` (`account_id`, `video_id`),
    UNIQUE KEY `uniq_sky_phone_music_youtube_device` (`device_imei`, `video_id`),
    KEY `idx_sky_phone_music_youtube_account` (`account_id`, `created_at`),
    KEY `idx_sky_phone_music_youtube_device` (`device_imei`, `created_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_music_playlists` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `name` VARCHAR(80) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_music_playlists_account` (`account_id`, `updated_at`),
    KEY `idx_sky_phone_music_playlists_device` (`device_imei`, `updated_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_music_playlist_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `playlist_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `source` ENUM('server', 'youtube') NOT NULL,
    `song_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `position` SMALLINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_music_playlist_song` (`playlist_id`, `source`, `song_id`),
    KEY `idx_sky_phone_music_playlist_order` (`playlist_id`, `position`, `id`),
    FOREIGN KEY (`playlist_id`) REFERENCES `sky_phone_music_playlists` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_radio_profiles` (
    `identifier` VARCHAR(80) NOT NULL,
    `history` LONGTEXT NOT NULL,
    `settings` LONGTEXT NOT NULL,
    `primary_frequency` DOUBLE NOT NULL DEFAULT 0,
    `secondary_frequency` DOUBLE NOT NULL DEFAULT 0,
    `badge` VARCHAR(32) NOT NULL DEFAULT '',
    `display_name` VARCHAR(64) NOT NULL DEFAULT '',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_profiles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `account_id` BIGINT UNSIGNED NOT NULL,
    `handle` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL, `display_name` VARCHAR(40) NOT NULL,
    `bio` VARCHAR(160) NOT NULL DEFAULT '', `account_type` ENUM('person','business','organization','media','event') NOT NULL DEFAULT 'person',
    `avatar_media_id` BIGINT UNSIGNED NULL,
    `verified` TINYINT(1) NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_account` (`account_id`), UNIQUE KEY `uniq_sky_phone_fliptok_handle` (`handle`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_credentials` (
    `profile_id` BIGINT UNSIGNED NOT NULL, `password_hash` BINARY(32) NOT NULL,
    `password_salt` CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`profile_id`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_sessions` (
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `profile_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`device_imei`), KEY `idx_sky_phone_fliptok_sessions_profile` (`profile_id`,`updated_at`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_videos` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `profile_id` BIGINT UNSIGNED NOT NULL, `media_id` BIGINT UNSIGNED NOT NULL,
    `caption` VARCHAR(500) NOT NULL DEFAULT '', `location` VARCHAR(80) NOT NULL DEFAULT '',
    `visibility` ENUM('public','followers','private') NOT NULL DEFAULT 'public', `comments_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `trim_start_ms` INT UNSIGNED NOT NULL DEFAULT 0, `trim_end_ms` INT UNSIGNED NULL, `cover_time_ms` INT UNSIGNED NOT NULL DEFAULT 0,
    `original_volume` TINYINT UNSIGNED NOT NULL DEFAULT 100, `music_volume` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `music_track` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT '',
    `custom_music_url` VARCHAR(2048) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
    `custom_music_title` VARCHAR(160) NOT NULL DEFAULT '', `custom_music_artist` VARCHAR(120) NOT NULL DEFAULT '',
    `status` ENUM('draft','published','removed') NOT NULL DEFAULT 'published', `view_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `share_count` INT UNSIGNED NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), KEY `idx_sky_phone_fliptok_feed` (`status`,`visibility`,`created_at`), KEY `idx_sky_phone_fliptok_profile` (`profile_id`,`created_at`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_video_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `video_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL, `sort_order` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_video_media_order` (`video_id`,`sort_order`),
    UNIQUE KEY `uniq_sky_phone_fliptok_video_media` (`video_id`,`media_id`),
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_reactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `video_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` BIGINT UNSIGNED NOT NULL, `kind` ENUM('like','save') NOT NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_reaction` (`video_id`,`profile_id`,`kind`),
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_follows` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `follower_id` BIGINT UNSIGNED NOT NULL, `following_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_fliptok_follow` (`follower_id`,`following_id`),
    FOREIGN KEY (`follower_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`following_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_comments` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `video_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` BIGINT UNSIGNED NOT NULL, `parent_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `body` VARCHAR(300) NOT NULL, `status` ENUM('visible','removed') NOT NULL DEFAULT 'visible',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), KEY `idx_sky_phone_fliptok_comments` (`video_id`,`created_at`),
    KEY `idx_sky_phone_fliptok_comment_parent` (`parent_id`,`created_at`),
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`parent_id`) REFERENCES `sky_phone_fliptok_comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_comment_reactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `comment_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` BIGINT UNSIGNED NOT NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_comment_reaction` (`comment_id`,`profile_id`),
    FOREIGN KEY (`comment_id`) REFERENCES `sky_phone_fliptok_comments` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_notifications` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `recipient_id` BIGINT UNSIGNED NOT NULL, `actor_id` BIGINT UNSIGNED NOT NULL,
    `video_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL, `kind` ENUM('like','comment','follow','verified') NOT NULL,
    `read_at` DATETIME NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`),
    KEY `idx_sky_phone_fliptok_activity` (`recipient_id`,`created_at`),
    FOREIGN KEY (`recipient_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`actor_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_reports` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `reporter_id` BIGINT UNSIGNED NOT NULL,
    `video_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `reason` ENUM('spam','harassment','dangerous','illegal','other') NOT NULL,
    `details` VARCHAR(500) NOT NULL DEFAULT '', `status` ENUM('open','reviewed','dismissed') NOT NULL DEFAULT 'open',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_report` (`reporter_id`,`video_id`),
    FOREIGN KEY (`reporter_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_fliptok_blocks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `blocker_id` BIGINT UNSIGNED NOT NULL, `blocked_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_block` (`blocker_id`,`blocked_id`),
    FOREIGN KEY (`blocker_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`blocked_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_flare_profiles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(32) NOT NULL,
    `age` TINYINT UNSIGNED NOT NULL,
    `bio` VARCHAR(300) NOT NULL DEFAULT '',
    `gender` ENUM('woman', 'man', 'nonbinary') NOT NULL,
    `interested_in` ENUM('woman', 'man', 'nonbinary', 'everyone') NOT NULL DEFAULT 'everyone',
    `min_age` TINYINT UNSIGNED NOT NULL DEFAULT 18,
    `max_age` TINYINT UNSIGNED NOT NULL DEFAULT 99,
    `avatar` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `interests` JSON NOT NULL,
    `looking_for` ENUM('longTerm', 'dates', 'friends') NOT NULL DEFAULT 'longTerm',
    `discoverable` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_flare_profile_account` (`account_id`),
    KEY `idx_sky_phone_flare_discovery` (`gender`, `age`, `updated_at`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_flare_profile_photos` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `profile_id` BIGINT UNSIGNED NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `sort_order` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_flare_photo_order` (`profile_id`, `sort_order`),
    UNIQUE KEY `uniq_sky_phone_flare_photo_media` (`profile_id`, `media_id`),
    KEY `idx_sky_phone_flare_photo_media` (`media_id`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_flare_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_flare_swipes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `swiper_account_id` BIGINT UNSIGNED NOT NULL,
    `target_account_id` BIGINT UNSIGNED NOT NULL,
    `choice` ENUM('like', 'pass', 'superlike') NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_flare_swipe` (`swiper_account_id`, `target_account_id`),
    KEY `idx_sky_phone_flare_swipe_target` (`target_account_id`, `choice`),
    FOREIGN KEY (`swiper_account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`target_account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_flare_matches` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_a_id` BIGINT UNSIGNED NOT NULL,
    `account_b_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_flare_match_pair` (`account_a_id`, `account_b_id`),
    KEY `idx_sky_phone_flare_match_b` (`account_b_id`, `created_at`),
    FOREIGN KEY (`account_a_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`account_b_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_flare_messages` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `match_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sender_account_id` BIGINT UNSIGNED NOT NULL,
    `body` VARCHAR(1000) NOT NULL,
    `message_type` ENUM('text', 'image', 'gif', 'video', 'share') NOT NULL DEFAULT 'text',
    `media_url` VARCHAR(2048) NULL,
    `share_payload` LONGTEXT NULL,
    `media_duration_ms` INT UNSIGNED NULL,
    `read_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_flare_message_thread` (`match_id`, `created_at`, `id`),
    KEY `idx_sky_phone_flare_message_unread` (`match_id`, `sender_account_id`, `read_at`),
    FOREIGN KEY (`match_id`) REFERENCES `sky_phone_flare_matches` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`sender_account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_profiles` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `handle` VARCHAR(24) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `display_name` VARCHAR(40) NOT NULL,
    `bio` VARCHAR(160) NOT NULL DEFAULT '',
    `avatar_media_id` BIGINT UNSIGNED NULL,
    `private` TINYINT(1) NOT NULL DEFAULT 0,
    `verified` TINYINT(1) NOT NULL DEFAULT 0,
    `status` ENUM('active','hidden','removed') NOT NULL DEFAULT 'active',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_account` (`account_id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_handle` (`handle`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_profiles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `account_id` BIGINT UNSIGNED NOT NULL,
    `handle` VARCHAR(30) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL, `display_name` VARCHAR(50) NOT NULL,
    `bio` VARCHAR(160) NOT NULL DEFAULT '', `avatar_media_id` BIGINT UNSIGNED NULL, `verified` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_account` (`account_id`), UNIQUE KEY `uniq_sky_phone_feather_handle` (`handle`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_credentials` (
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `password_hash` BINARY(32) NOT NULL,
    `password_salt` CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`profile_id`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_sessions` (
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`device_imei`),
    KEY `idx_sky_phone_picstagram_sessions_profile` (`profile_id`,`updated_at`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_posts` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `caption` VARCHAR(800) NOT NULL DEFAULT '',
    `location` VARCHAR(80) NOT NULL DEFAULT '',
    `comments_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `status` ENUM('published','archived','hidden','removed') NOT NULL DEFAULT 'published',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_picstagram_feed` (`status`,`created_at`,`id`),
    KEY `idx_sky_phone_picstagram_profile_posts` (`profile_id`,`status`,`created_at`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_post_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `position` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_post_position` (`post_id`,`position`),
    UNIQUE KEY `uniq_sky_phone_picstagram_post_media` (`post_id`,`media_id`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_reactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `kind` ENUM('like','save') NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_reaction` (`post_id`,`profile_id`,`kind`),
    KEY `idx_sky_phone_picstagram_saved` (`profile_id`,`kind`,`created_at`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_follows` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `follower_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `following_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `status` ENUM('pending','accepted') NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_follow` (`follower_id`,`following_id`),
    KEY `idx_sky_phone_picstagram_following` (`following_id`,`status`,`created_at`),
    FOREIGN KEY (`follower_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`following_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_comments` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `parent_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `body` VARCHAR(300) NOT NULL,
    `status` ENUM('visible','removed') NOT NULL DEFAULT 'visible',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_picstagram_comments` (`post_id`,`status`,`created_at`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_picstagram_posts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`parent_id`) REFERENCES `sky_phone_picstagram_comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_comment_reactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `comment_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_comment_reaction` (`comment_id`,`profile_id`),
    FOREIGN KEY (`comment_id`) REFERENCES `sky_phone_picstagram_comments` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_stories` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `body` VARCHAR(160) NOT NULL DEFAULT '',
    `status` ENUM('active','removed') NOT NULL DEFAULT 'active',
    `expires_at` DATETIME NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_picstagram_stories` (`profile_id`,`status`,`expires_at`),
    KEY `idx_sky_phone_picstagram_story_expiry` (`status`,`expires_at`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_story_views` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `story_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_story_view` (`story_id`,`profile_id`),
    FOREIGN KEY (`story_id`) REFERENCES `sky_phone_picstagram_stories` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_activities` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `recipient_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `actor_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `kind` ENUM('follow_request','follow','request_accepted','like','comment','comment_like','reply','verified') NOT NULL,
    `read_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_picstagram_activity` (`recipient_id`,`read_at`,`created_at`),
    FOREIGN KEY (`recipient_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`actor_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_picstagram_posts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_reports` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `reporter_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `target_type` ENUM('profile','post','story','comment') NOT NULL,
    `target_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `reason` ENUM('spam','harassment','dangerous','illegal','other') NOT NULL,
    `details` VARCHAR(500) NOT NULL DEFAULT '',
    `status` ENUM('open','reviewed','dismissed') NOT NULL DEFAULT 'open',
    `resolved_action` VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
    `resolved_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_report` (`reporter_id`,`target_type`,`target_id`),
    KEY `idx_sky_phone_picstagram_reports` (`status`,`created_at`),
    FOREIGN KEY (`reporter_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_blocks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `blocker_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `blocked_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_picstagram_block` (`blocker_id`,`blocked_id`),
    FOREIGN KEY (`blocker_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`blocked_id`) REFERENCES `sky_phone_picstagram_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_picstagram_moderation_audit` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `report_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `moderator_identifier` VARCHAR(80) NOT NULL,
    `action` VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `target_type` VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `target_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_picstagram_audit_target` (`target_type`,`target_id`,`created_at`),
    FOREIGN KEY (`report_id`) REFERENCES `sky_phone_picstagram_reports` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_skyride_profiles` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `display_name` VARCHAR(50) NULL,
    `avatar_media_id` BIGINT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_skyride_owner` (`owner_identifier`),
    KEY `idx_sky_phone_skyride_profile_avatar` (`avatar_media_id`),
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_skyride_rides` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `passenger_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `driver_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `passenger_name` VARCHAR(80) NOT NULL,
    `driver_name` VARCHAR(80) NULL,
    `status` ENUM('payment_pending','searching','accepted','arrived','in_progress','completing','completed','cancelled') NOT NULL,
    `service_class` ENUM('taxi','comfort','xl','premium') NOT NULL,
    `pickup_label` VARCHAR(80) NOT NULL,
    `pickup_x` DECIMAL(10,3) NOT NULL,
    `pickup_y` DECIMAL(10,3) NOT NULL,
    `pickup_z` DECIMAL(10,3) NOT NULL,
    `destination_label` VARCHAR(80) NOT NULL,
    `destination_x` DECIMAL(10,3) NOT NULL,
    `destination_y` DECIMAL(10,3) NOT NULL,
    `destination_z` DECIMAL(10,3) NOT NULL,
    `distance_meters` INT UNSIGNED NOT NULL,
    `duration_seconds` INT UNSIGNED NOT NULL,
    `price` INT UNSIGNED NOT NULL,
    `payout_amount` INT UNSIGNED NOT NULL,
    `currency` VARCHAR(8) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `driver_vehicle_model` VARCHAR(64) NULL,
    `driver_vehicle_color` VARCHAR(64) NULL,
    `driver_vehicle_plate` VARCHAR(16) NULL,
    `cancelled_by` ENUM('passenger','driver','system') NULL,
    `cancel_reason` VARCHAR(32) NULL,
    `passenger_rating` TINYINT UNSIGNED NULL,
    `rating_comment` VARCHAR(300) NULL,
    `tip_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `refund_status` ENUM('none','pending','processing','completed') NOT NULL DEFAULT 'none',
    `tip_status` ENUM('none','processing','completed','failed') NOT NULL DEFAULT 'none',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `accepted_at` DATETIME NULL,
    `arrived_at` DATETIME NULL,
    `started_at` DATETIME NULL,
    `completed_at` DATETIME NULL,
    `cancelled_at` DATETIME NULL,
    `refunded_at` DATETIME NULL,
    `paid_out_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_skyride_passenger` (`passenger_profile_id`,`status`,`updated_at`),
    KEY `idx_sky_phone_skyride_driver` (`driver_profile_id`,`status`,`updated_at`),
    KEY `idx_sky_phone_skyride_requests` (`status`,`created_at`),
    KEY `idx_sky_phone_skyride_refunds` (`refund_status`,`status`,`updated_at`),
    FOREIGN KEY (`passenger_profile_id`) REFERENCES `sky_phone_skyride_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`driver_profile_id`) REFERENCES `sky_phone_skyride_profiles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_posts` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `profile_id` BIGINT UNSIGNED NOT NULL, `body` VARCHAR(360) NOT NULL DEFAULT '',
    `reply_to_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL, `quote_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `status` ENUM('published','removed') NOT NULL DEFAULT 'published', `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), KEY `idx_sky_phone_feather_feed` (`status`,`created_at`), KEY `idx_sky_phone_feather_profile` (`profile_id`,`created_at`),
    KEY `idx_sky_phone_feather_replies` (`reply_to_id`,`created_at`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`reply_to_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE SET NULL,
    FOREIGN KEY (`quote_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_hashtags` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `tag` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_hashtag` (`post_id`,`tag`),
    KEY `idx_sky_phone_feather_hashtag_rank` (`tag`,`post_id`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_post_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL, `sort_order` TINYINT UNSIGNED NOT NULL, PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_feather_media_order` (`post_id`,`sort_order`), UNIQUE KEY `uniq_sky_phone_feather_media` (`post_id`,`media_id`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_reactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` BIGINT UNSIGNED NOT NULL, `kind` ENUM('like','bookmark') NOT NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_reaction` (`post_id`,`profile_id`,`kind`),
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_follows` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `follower_id` BIGINT UNSIGNED NOT NULL, `following_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_follow` (`follower_id`,`following_id`),
    FOREIGN KEY (`follower_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`following_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_notifications` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `recipient_id` BIGINT UNSIGNED NOT NULL, `actor_id` BIGINT UNSIGNED NOT NULL,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL, `kind` ENUM('like','reply','follow','quote') NOT NULL,
    `read_at` DATETIME NULL, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`),
    KEY `idx_sky_phone_feather_activity` (`recipient_id`,`created_at`),
    FOREIGN KEY (`recipient_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`actor_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_blocks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `blocker_id` BIGINT UNSIGNED NOT NULL, `blocked_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_block` (`blocker_id`,`blocked_id`),
    FOREIGN KEY (`blocker_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`blocked_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_feather_reports` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `reporter_id` BIGINT UNSIGNED NOT NULL,
    `post_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, `reason` ENUM('spam','harassment','dangerous','illegal','other') NOT NULL,
    `details` VARCHAR(500) NOT NULL DEFAULT '', `status` ENUM('open','reviewed','dismissed') NOT NULL DEFAULT 'open',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_feather_report` (`reporter_id`,`post_id`),
    FOREIGN KEY (`reporter_id`) REFERENCES `sky_phone_feather_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`post_id`) REFERENCES `sky_phone_feather_posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_profiles` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `username` VARCHAR(20) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    `avatar_media_id` BIGINT UNSIGNED NULL,
    `active_group_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `map_visible` TINYINT(1) NOT NULL DEFAULT 1,
    `overhead_visible` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crewlink_account` (`account_id`),
    UNIQUE KEY `uniq_sky_phone_crewlink_username` (`username`),
    KEY `idx_sky_phone_crewlink_active` (`active_group_id`),
    KEY `idx_sky_phone_crewlink_avatar` (`avatar_media_id`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`avatar_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_credentials` (
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `password_hash` BINARY(32) NOT NULL,
    `password_salt` CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`profile_id`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_sessions` (
    `device_imei` CHAR(15) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`device_imei`),
    KEY `idx_sky_phone_crewlink_sessions_profile` (`profile_id`,`updated_at`),
    FOREIGN KEY (`device_imei`) REFERENCES `sky_phone_devices` (`imei`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_groups` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `name` VARCHAR(32) NOT NULL,
    `colour` ENUM('cyan','blue','violet','orange','green','rose') NOT NULL DEFAULT 'cyan',
    `owner_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `invite_code` VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `allow_member_pings` TINYINT(1) NOT NULL DEFAULT 1,
    `overhead_allowed` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crewlink_invite_code` (`invite_code`),
    KEY `idx_sky_phone_crewlink_owner` (`owner_profile_id`),
    FOREIGN KEY (`owner_profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_memberships` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `role` ENUM('owner','coordinator','moderator','member','guest') NOT NULL DEFAULT 'member',
    `joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crewlink_membership` (`group_id`,`profile_id`),
    KEY `idx_sky_phone_crewlink_profile_groups` (`profile_id`,`joined_at`),
    FOREIGN KEY (`group_id`) REFERENCES `sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_invitations` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `group_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `inviter_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `invitee_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `status` ENUM('pending','accepted','declined','expired') NOT NULL DEFAULT 'pending',
    `expires_at` DATETIME NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crewlink_pending_invite` (`group_id`,`invitee_profile_id`),
    KEY `idx_sky_phone_crewlink_invitee` (`invitee_profile_id`,`status`,`expires_at`),
    FOREIGN KEY (`group_id`) REFERENCES `sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`inviter_profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`invitee_profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crewlink_pings` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `group_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `creator_profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `source_resource` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
    `type` ENUM('meeting','danger','help','target','info') NOT NULL,
    `label` VARCHAR(48) NOT NULL,
    `position_x` DECIMAL(10,3) NOT NULL,
    `position_y` DECIMAL(10,3) NOT NULL,
    `position_z` DECIMAL(10,3) NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_crewlink_pings` (`group_id`,`expires_at`),
    FOREIGN KEY (`group_id`) REFERENCES `sky_phone_crewlink_groups` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`creator_profile_id`) REFERENCES `sky_phone_crewlink_profiles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_profiles` (
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `description` VARCHAR(1000) NOT NULL DEFAULT '',
    `district` VARCHAR(80) NOT NULL DEFAULT '',
    `location_label` VARCHAR(80) NOT NULL DEFAULT '',
    `address` VARCHAR(160) NOT NULL DEFAULT '',
    `location_x` DECIMAL(10,3) NULL,
    `location_y` DECIMAL(10,3) NULL,
    `location_z` DECIMAL(10,3) NULL,
    `logo_media_id` BIGINT UNSIGNED NULL,
    `cover_media_id` BIGINT UNSIGNED NULL,
    `availability` ENUM('available','busy','closed') NOT NULL DEFAULT 'closed',
    `availability_updated_by` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `availability_updated_at` DATETIME NULL,
    `availability_expires_at` DATETIME NULL,
    `accepts_requests` TINYINT(1) NOT NULL DEFAULT 1,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `mutation_token` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`company_id`),
    KEY `idx_sky_phone_company_profiles_public` (`availability`,`updated_at`),
    FOREIGN KEY (`logo_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL,
    FOREIGN KEY (`cover_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_hours` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `weekday` TINYINT UNSIGNED NOT NULL,
    `is_closed` TINYINT(1) NOT NULL DEFAULT 0,
    `opens_at` CHAR(5) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `closes_at` CHAR(5) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_company_hours_day` (`company_id`,`weekday`),
    FOREIGN KEY (`company_id`) REFERENCES `sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_services` (
    `id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `title` VARCHAR(80) NOT NULL,
    `description` VARCHAR(500) NOT NULL DEFAULT '',
    `price_text` VARCHAR(80) NOT NULL DEFAULT '',
    `requests_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `archived` TINYINT(1) NOT NULL DEFAULT 0,
    `sort_order` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_services_list` (`company_id`,`archived`,`active`,`sort_order`),
    FOREIGN KEY (`company_id`) REFERENCES `sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_announcements` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `body` VARCHAR(1000) NOT NULL,
    `created_by` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `expires_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_announcements_active` (`company_id`,`active`,`expires_at`,`created_at`),
    FOREIGN KEY (`company_id`) REFERENCES `sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_requests` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `service_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `customer_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `subject` VARCHAR(120) NOT NULL,
    `description` VARCHAR(2000) NOT NULL,
    `status` ENUM('new','assigned','in_progress','waiting_customer','completed','cancelled') NOT NULL DEFAULT 'new',
    `assigned_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `customer_unread` INT UNSIGNED NOT NULL DEFAULT 0,
    `company_activity_revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `mutation_token` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `completed_at` DATETIME NULL,
    `cancelled_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_requests_customer` (`customer_sim_id`,`updated_at`,`id`),
    KEY `idx_sky_phone_company_requests_queue` (`company_id`,`status`,`updated_at`,`id`),
    KEY `idx_sky_phone_company_requests_assignee` (`company_id`,`assigned_identifier`,`status`),
    FOREIGN KEY (`company_id`) REFERENCES `sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE,
    FOREIGN KEY (`service_id`) REFERENCES `sky_phone_company_services` (`id`) ON DELETE SET NULL,
    FOREIGN KEY (`customer_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_request_reads` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `reader_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `read_revision` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_company_request_reads_reader` (`request_id`,`reader_identifier`),
    KEY `idx_sky_phone_company_request_reads_identifier` (`reader_identifier`,`updated_at`),
    FOREIGN KEY (`request_id`) REFERENCES `sky_phone_company_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_request_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `sort_order` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_company_request_media` (`request_id`,`media_id`),
    UNIQUE KEY `uniq_sky_phone_company_request_media_order` (`request_id`,`sort_order`),
    FOREIGN KEY (`request_id`) REFERENCES `sky_phone_company_requests` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_request_messages` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `request_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `sender_type` ENUM('customer','company') NOT NULL,
    `sender_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `sender_sim_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `body` VARCHAR(2000) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_request_messages` (`request_id`,`created_at`,`id`),
    FOREIGN KEY (`request_id`) REFERENCES `sky_phone_company_requests` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`sender_sim_id`) REFERENCES `sky_phone_sims` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_request_events` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `request_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `event_type` ENUM('created','assigned','status','cancelled') NOT NULL,
    `actor_type` ENUM('customer','company','system') NOT NULL,
    `actor_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `from_status` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `to_status` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `detail` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_request_events` (`request_id`,`created_at`,`id`),
    FOREIGN KEY (`request_id`) REFERENCES `sky_phone_company_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_company_audit` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `company_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `actor_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `action` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `target_type` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `target_id` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_company_audit` (`company_id`,`created_at`,`id`),
    FOREIGN KEY (`company_id`) REFERENCES `sky_phone_company_profiles` (`company_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_weazel_articles` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `title` VARCHAR(160) NOT NULL,
    `body` LONGTEXT NOT NULL,
    `excerpt` VARCHAR(240) NOT NULL,
    `category` ENUM('official','events','jobs','news','business') NOT NULL,
    `image_media_id` BIGINT UNSIGNED NULL,
    `author_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `author_name` VARCHAR(120) NOT NULL,
    `updated_by_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `published_at` DATETIME NULL,
    `deleted_at` DATETIME NULL,
    `deleted_by_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_weazel_public` (`status`,`deleted_at`,`published_at`,`id`),
    KEY `idx_sky_phone_weazel_category` (`category`,`status`,`deleted_at`,`published_at`,`id`),
    KEY `idx_sky_phone_weazel_manage` (`deleted_at`,`status`,`updated_at`,`id`),
    KEY `idx_sky_phone_weazel_media` (`image_media_id`),
    FOREIGN KEY (`image_media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_weazel_article_media` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `article_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `media_id` BIGINT UNSIGNED NOT NULL,
    `position` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_weazel_article_position` (`article_id`,`position`),
    UNIQUE KEY `uniq_sky_phone_weazel_article_media` (`article_id`,`media_id`),
    FOREIGN KEY (`article_id`) REFERENCES `sky_phone_weazel_articles` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`media_id`) REFERENCES `sky_phone_media` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_profiles` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `handle` VARCHAR(20) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
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
    UNIQUE KEY `uniq_sky_phone_crypto_handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_markets` (
    `id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `asset_scale` BIGINT UNSIGNED NOT NULL,
    `price_scale` BIGINT UNSIGNED NOT NULL,
    `issued_supply` DECIMAL(36,0) UNSIGNED NOT NULL,
    `price` DECIMAL(36,0) UNSIGNED NOT NULL,
    `version` BIGINT UNSIGNED NOT NULL DEFAULT 1,
    `status` ENUM('active','halted','stale') NOT NULL DEFAULT 'active',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_market_ticks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `version` BIGINT UNSIGNED NOT NULL,
    `price` DECIMAL(36,0) UNSIGNED NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crypto_tick` (`market_id`,`version`),
    KEY `idx_sky_phone_crypto_ticks` (`market_id`,`created_at`,`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_balances` (
    `account_id` VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `asset_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `available` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
    `locked` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
    `version` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`,`asset_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_operations` (
    `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `type` ENUM('buy','sell','deposit','withdrawal') NOT NULL,
    `idempotency_key` VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `request_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `status` ENUM('prepared','external_pending','external_applied','ledger_applied','completed','failed','compensation_pending','manual_review','cancelled') NOT NULL,
    `amount` DECIMAL(36,0) UNSIGNED NOT NULL DEFAULT 0,
    `market_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `detail` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_sky_phone_crypto_operation` (`profile_id`,`type`,`idempotency_key`),
    KEY `idx_sky_phone_crypto_activity` (`profile_id`,`created_at`,`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_ledger_entries` (
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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_quotes` (
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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_fills` (
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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_settlements` (
    `operation_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `framework_account` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `amount` DECIMAL(36,0) UNSIGNED NOT NULL,
    `state` ENUM('prepared','external_pending','external_applied','ledger_applied','completed','failed','compensation_pending','manual_review','cancelled') NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`operation_id`),
    KEY `idx_sky_phone_crypto_settlement_state` (`state`,`updated_at`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sky_phone_crypto_audit_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `profile_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `owner_identifier` VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NULL,
    `event_type` VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `detail` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_crypto_audit` (`profile_id`,`created_at`,`id`)
) ENGINE=InnoDB;
