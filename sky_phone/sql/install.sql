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
    `verified` TINYINT(1) NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), UNIQUE KEY `uniq_sky_phone_fliptok_account` (`account_id`), UNIQUE KEY `uniq_sky_phone_fliptok_handle` (`handle`),
    FOREIGN KEY (`account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
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
    `status` ENUM('draft','published','removed') NOT NULL DEFAULT 'published', `view_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `share_count` INT UNSIGNED NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`), KEY `idx_sky_phone_fliptok_feed` (`status`,`visibility`,`created_at`), KEY `idx_sky_phone_fliptok_profile` (`profile_id`,`created_at`),
    FOREIGN KEY (`profile_id`) REFERENCES `sky_phone_fliptok_profiles` (`id`) ON DELETE CASCADE,
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
    `profile_id` BIGINT UNSIGNED NOT NULL, `body` VARCHAR(300) NOT NULL, `status` ENUM('visible','removed') NOT NULL DEFAULT 'visible',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), KEY `idx_sky_phone_fliptok_comments` (`video_id`,`created_at`),
    FOREIGN KEY (`video_id`) REFERENCES `sky_phone_fliptok_videos` (`id`) ON DELETE CASCADE,
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
    `message_type` ENUM('text', 'image', 'gif', 'video') NOT NULL DEFAULT 'text',
    `media_url` VARCHAR(2048) NULL,
    `media_duration_ms` INT UNSIGNED NULL,
    `read_at` DATETIME NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sky_phone_flare_message_thread` (`match_id`, `created_at`, `id`),
    KEY `idx_sky_phone_flare_message_unread` (`match_id`, `sender_account_id`, `read_at`),
    FOREIGN KEY (`match_id`) REFERENCES `sky_phone_flare_matches` (`id`) ON DELETE CASCADE,
    FOREIGN KEY (`sender_account_id`) REFERENCES `sky_phone_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
