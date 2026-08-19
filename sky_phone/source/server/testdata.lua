Bridge.Database.AfterMigration("sky_phone", function()

if not Config.TestData.Enabled then
    return
end

local photo_urls = {
    city = "https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=80",
    car = "https://images.unsplash.com/photo-1493238792000-8113da705763?auto=format&fit=crop&w=1200&q=80",
    beach = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
    portrait = "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80",
}
local video_url = "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4"
local seed_attempts = {}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function stable_uuid(seed)
    local rows = Bridge.Database.Query([[
        SELECT LOWER(CONCAT(
            SUBSTR(MD5(?), 1, 8), '-', SUBSTR(MD5(?), 9, 4), '-',
            SUBSTR(MD5(?), 13, 4), '-', SUBSTR(MD5(?), 17, 4), '-', SUBSTR(MD5(?), 21, 12)
        )) AS `id`
    ]], { seed, seed, seed, seed, seed })
    local id = rows[1] and rows[1].id
    if type(id) ~= "string" or #id ~= 36 then
        error("[sky_phone] Test data could not generate a stable UUID.")
    end
    return id
end

local function seed_hash(seed)
    local rows = Bridge.Database.Query("SELECT LEFT(MD5(?), 12) AS `value`", { seed })
    local value = rows[1] and rows[1].value
    if type(value) ~= "string" or #value ~= 12 then
        error("[sky_phone] Test data could not generate a stable account suffix.")
    end
    return value
end

local function darkchat_identifiers(account_id)
    local account_key = tostring(account_id)
    local dark_id = "DC" .. seed_hash("darkchat:id:" .. account_key):upper()
    local invite_code = "I" .. seed_hash("darkchat:invite:" .. account_key):sub(1, 10):upper()
    return dark_id, invite_code
end

local function database_uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = rows[1] and rows[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Test data could not generate a database UUID.")
    end
    return id
end

local function ensure_account(email)
    Bridge.Database.Query(
        "INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES (?, ?)",
        { email, "sky-phone-test" }
    )
    local rows = Bridge.Database.Query(
        "SELECT `id`, `email` FROM `sky_phone_accounts` WHERE `email` = ? LIMIT 1",
        { email }
    )
    if not rows[1] then
        error(("[sky_phone] Test data account '%s' could not be loaded."):format(email))
    end
    rows[1].id = tonumber(rows[1].id)
    return rows[1]
end

local function ensure_media(account_id, remote_id, url, media_type)
    local rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_media`
        WHERE `account_id` = ? AND `remote_id` = ?
        ORDER BY `id` LIMIT 1
    ]], { account_id, remote_id })
    if rows[1] then
        Bridge.Database.Query(
            "UPDATE `sky_phone_media` SET `url` = ?, `media_type` = ? WHERE `id` = ?",
            { url, media_type, rows[1].id }
        )
        return tonumber(rows[1].id)
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_media` (`account_id`, `url`, `remote_id`, `media_type`)
        VALUES (?, ?, ?, ?)
    ]], { account_id, url, remote_id, media_type })
    rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_media`
        WHERE `account_id` = ? AND `remote_id` = ?
        ORDER BY `id` DESC LIMIT 1
    ]], { account_id, remote_id })
    if not rows[1] then
        error("[sky_phone] Test media could not be created.")
    end
    return tonumber(rows[1].id)
end

local function reserve_sim(owner_identifier, firstname, lastname)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `phone_number`, `sim_type`
        FROM `sky_phone_sims`
        WHERE `owner_identifier` = ? AND `is_virtual` = 0
        ORDER BY `created_at` LIMIT 1
    ]], { owner_identifier })
    if rows[1] then
        return rows[1]
    end

    local sim_id
    local number = SkyPhoneSimNumber.Reserve(database_uuid, function(candidate)
        if SkyPhoneCompanies.IsServiceNumber(candidate) then
            return false
        end
        sim_id = database_uuid()
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_sims`
                (`id`, `phone_number`, `sim_type`, `is_virtual`, `owner_identifier`,
                 `owner_firstname`, `owner_lastname`, `registered_at`)
            VALUES (?, ?, 'registered', 0, ?, ?, ?, CURRENT_TIMESTAMP)
        ]], { sim_id, candidate, owner_identifier, firstname, lastname })
        return affected_rows(result) == 1
    end, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        error("[sky_phone] Test data could not reserve a SIM number.")
    end
    return { id = sim_id, phone_number = number, sim_type = "registered" }
end

local function restore_sim_attachment(sim_id, current_imei, previous_imei)
    local statements = {
        {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = NULL WHERE `imei` = ? AND `sim_id` = ?",
            params = { current_imei, sim_id },
        },
    }
    if previous_imei then
        statements[#statements + 1] = {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = ? WHERE `imei` = ? AND `sim_id` IS NULL",
            params = { sim_id, previous_imei },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return false
    end

    local rows = Bridge.Database.Query(
        "SELECT `imei` FROM `sky_phone_devices` WHERE `sim_id` = ? LIMIT 1",
        { sim_id }
    )
    if previous_imei then
        return rows[1] and rows[1].imei == previous_imei
    end
    return rows[1] == nil
end

local function move_sim_to_device(sim_id, imei)
    local rows = Bridge.Database.Query(
        "SELECT `imei` FROM `sky_phone_devices` WHERE `sim_id` = ? LIMIT 1",
        { sim_id }
    )
    local previous_imei = rows[1] and rows[1].imei or nil
    if previous_imei == imei then
        return previous_imei
    end

    local moved = Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = NULL WHERE `sim_id` = ? AND `imei` <> ?",
            params = { sim_id, imei },
        },
        {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = ? WHERE `imei` = ? AND `sim_id` IS NULL",
            params = { sim_id, imei },
        },
    })
    if not moved then
        error("[sky_phone] Test data could not move the player's SIM to the selected phone.")
    end

    rows = Bridge.Database.Query(
        "SELECT `sim_id` FROM `sky_phone_devices` WHERE `imei` = ? LIMIT 1",
        { imei }
    )
    if not rows[1] or rows[1].sim_id ~= sim_id then
        if not restore_sim_attachment(sim_id, imei, previous_imei) then
            error("[sky_phone] Test data could not verify the SIM move or restore its previous device.")
        end
        error("[sky_phone] Test data could not verify the SIM move.")
    end

    return previous_imei
end

local function ensure_bot(label, email_local, imei, firstname, lastname)
    local account = ensure_account(email_local .. "@" .. Config.Mail.Domain)
    local sim = reserve_sim("sky_phone:testbot:" .. label, firstname, lastname)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_devices` (`imei`, `account_id`, `sim_id`, `device_name`)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`), `sim_id` = VALUES(`sim_id`)
    ]], { imei, account.id, sim.id, firstname .. "'s iFruit" })
    return {
        account = account,
        sim = sim,
        imei = imei,
        name = firstname .. " " .. lastname,
    }
end

local function ensure_numeric_profile(table_name, account_id)
    local rows = Bridge.Database.Query(
        ("SELECT `id` FROM `%s` WHERE `account_id` = ? LIMIT 1"):format(table_name),
        { account_id }
    )
    if not rows[1] then
        error(("[sky_phone] Test profile in '%s' could not be loaded."):format(table_name))
    end
    return tonumber(rows[1].id)
end

local function ensure_string_profile(table_name, account_id)
    local rows = Bridge.Database.Query(
        ("SELECT `id` FROM `%s` WHERE `account_id` = ? LIMIT 1"):format(table_name),
        { account_id }
    )
    if not rows[1] or type(rows[1].id) ~= "string" then
        error(("[sky_phone] Test profile in '%s' could not be loaded."):format(table_name))
    end
    return rows[1].id
end

local function seed_core(context)
    local account_id = context.account.id
    local bot = context.bot_one
    local alarms = {
        {
            id = "test-weekday",
            enabled = true,
            time = "07:30",
            note = "Phone QA",
            sound = "radar",
            weekdays = { 1, 2, 3, 4, 5 },
            lastTriggeredMinute = nil,
        },
        {
            id = "test-weekend",
            enabled = false,
            time = "10:00",
            note = "Car Meet",
            sound = "chimes",
            weekdays = { 0, 6 },
            lastTriggeredMinute = nil,
        },
    }
    local games = {
        snake = { highScore = 42, speed = "fast" },
        memory = {
            best = {
                small = { moves = 12, timeMs = 42000 },
                medium = { moves = 28, timeMs = 96000 },
            },
            soundEnabled = true,
        },
        minesweeper = {
            best = { quick = { timeMs = 31000 }, classic = { timeMs = 124000 } },
            elapsedMs = 0,
            game = nil,
            soundEnabled = true,
        },
        ["number-merge"] = { bestScore = 8192, game = nil, highestTile = 1024, soundEnabled = true },
        ["tower-stack"] = { highHeight = 23, highScore = 4750, soundEnabled = true },
        ["sky-flappy"] = { design = "neon", highScore = 18, soundEnabled = true },
        ["neon-drop"] = { bestLines = 14, bestScore = 12600, soundEnabled = true },
    }
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, 'alarms', ?)
        ON DUPLICATE KEY UPDATE `payload` = VALUES(`payload`), `revision` = `revision` + 1
    ]], { context.imei, json.encode(alarms) })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, 'games', ?)
        ON DUPLICATE KEY UPDATE `payload` = VALUES(`payload`), `revision` = `revision` + 1
    ]], { context.imei, json.encode(games) })

    local contact_id = stable_uuid(context.key .. ":contact:alex")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_contacts`
            (`id`, `contact_id`, `account_id`, `name`, `notes`, `organization`, `phone_number`, `favorite`)
        VALUES (?, ?, ?, 'Alex Rivera', 'Test contact for calls and messages.', 'Downtown Cab Co.', ?, 1)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `notes` = VALUES(`notes`),
            `organization` = VALUES(`organization`), `phone_number` = VALUES(`phone_number`), `favorite` = 1
    ]], { contact_id, contact_id, account_id, bot.sim.phone_number })

    local sms_one = stable_uuid(context.key .. ":sms:one")
    local sms_two = stable_uuid(context.key .. ":sms:two")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_sms_messages`
            (`id`, `sender_sim_id`, `recipient_sim_id`, `sender_number`, `recipient_number`, `body`, `read_at`, `created_at`)
        VALUES (?, ?, ?, ?, ?, 'Willkommen auf dem Testserver! Alle Apps sind jetzt befüllt.', NULL,
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 8 MINUTE))
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `read_at` = NULL
    ]], { sms_one, bot.sim.id, context.sim.id, bot.sim.phone_number, context.sim.phone_number })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_sms_messages`
            (`id`, `sender_sim_id`, `recipient_sim_id`, `sender_number`, `recipient_number`, `body`, `read_at`, `created_at`)
        VALUES (?, ?, ?, ?, ?, 'Perfekt, ich teste gerade Nachrichten und Kontakte.', CURRENT_TIMESTAMP,
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE))
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `read_at` = CURRENT_TIMESTAMP
    ]], { sms_two, context.sim.id, bot.sim.id, context.sim.phone_number, bot.sim.phone_number })

    local call_id = stable_uuid(context.key .. ":call:missed")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_calls`
            (`id`, `caller_sim_id`, `callee_sim_id`, `caller_number`, `callee_number`, `status`,
             `started_at`, `ended_at`, `duration_seconds`)
        VALUES (?, ?, ?, ?, ?, 'missed', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR),
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR), 0)
        ON DUPLICATE KEY UPDATE `status` = 'missed', `duration_seconds` = 0
    ]], { call_id, bot.sim.id, context.sim.id, bot.sim.phone_number, context.sim.phone_number })
    Bridge.Database.Query("DELETE FROM `sky_phone_call_entries` WHERE `call_id` = ? AND `account_id` = ?", { call_id, account_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_call_entries`
            (`call_id`, `account_id`, `direction`, `status`, `other_number`, `created_at`)
        VALUES (?, ?, 'incoming', 'missed', ?, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR))
    ]], { call_id, account_id, bot.sim.phone_number })

    local note_one = stable_uuid(context.key .. ":note:checklist")
    local note_two = stable_uuid(context.key .. ":note:ideas")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_notes` (`id`, `account_id`, `title`, `body`, `pinned`)
        VALUES (?, ?, 'Phone Test-Checkliste', 'Kontakte\nNachrichten\nAnrufe\nSocial Apps\nMarktplatz\nFirmen', 1)
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `body` = VALUES(`body`), `pinned` = 1
    ]], { note_one, account_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_notes` (`id`, `account_id`, `title`, `body`, `pinned`)
        VALUES (?, ?, 'Ideen für später', 'DarkChat testen und eine SkyRide-Fahrt bewerten.', 0)
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `body` = VALUES(`body`)
    ]], { note_two, account_id })

    local mail_id = stable_uuid(context.key .. ":mail:welcome")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_mail_messages`
            (`id`, `sender_account_id`, `recipients`, `subject`, `body`, `created_at`)
        VALUES (?, ?, ?, 'Willkommen beim iFruit-Test',
            'Hallo! Diese Nachricht gehört zu deinem reproduzierbaren Ingame-Testdatensatz.',
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 HOUR))
        ON DUPLICATE KEY UPDATE `recipients` = VALUES(`recipients`), `subject` = VALUES(`subject`), `body` = VALUES(`body`)
    ]], { mail_id, bot.account.id, json.encode({ context.account.email }) })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_mail_entries` (`message_id`, `account_id`, `folder`)
        VALUES (?, ?, 'inbox')
    ]], { mail_id, account_id })
    local draft_id = stable_uuid(context.key .. ":mail:draft")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_mail_drafts` (`id`, `account_id`, `recipients`, `subject`, `body`)
        VALUES (?, ?, ?, 'Entwurf: Testfeedback', 'Hier kann ich später mein Testfeedback ergänzen.')
        ON DUPLICATE KEY UPDATE `recipients` = VALUES(`recipients`), `subject` = VALUES(`subject`), `body` = VALUES(`body`)
    ]], { draft_id, account_id, json.encode({ bot.account.email }) })

    Bridge.Database.Query(
        "DELETE FROM `sky_phone_bank_transactions` WHERE `owner_identifier` = ? AND `reference` LIKE 'sky-phone-test:%'",
        { context.identifier }
    )
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_bank_transactions` (`owner_identifier`, `kind`, `amount`, `label`, `reference`, `created_at`)
        VALUES (?, 'deposit', 2500, 'Test paycheck', 'sky-phone-test:paycheck', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY)),
               (?, 'withdrawal', 85, 'Los Santos Customs', 'sky-phone-test:repair', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 3 HOUR)),
               (?, 'transfer_in', 420, 'Alex Rivera', 'sky-phone-test:transfer', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 30 MINUTE))
    ]], { context.identifier, context.identifier, context.identifier })

    local invoice_id = stable_uuid(context.key .. ":invoice:repair")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_invoices`
            (`id`, `recipient_identifier`, `issuer_identifier`, `issuer_account`, `issuer_label`,
             `title`, `description`, `amount`, `currency`, `status`, `due_at`)
        VALUES (?, ?, 'sky_phone:testbot:mechanic', 'society_mechanic', 'Los Santos Customs',
            'Vehicle inspection', 'Test invoice for the Billing app.', 750, '$', 'open',
            DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 3 DAY))
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `description` = VALUES(`description`),
            `amount` = VALUES(`amount`), `status` = 'open', `read_at` = NULL
    ]], { invoice_id, context.identifier })
    Bridge.Database.Query(
        "DELETE FROM `sky_phone_billing_events` WHERE `invoice_id` = ? AND `note` = 'Generated by the phone test data command.'",
        { invoice_id }
    )
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_events` (`invoice_id`, `event`, `actor_identifier`, `note`)
        VALUES (?, 'created', 'sky_phone:testbot:mechanic', 'Generated by the phone test data command.')
    ]], { invoice_id })

    local event_id = stable_uuid(context.key .. ":calendar:meeting")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_calendar_events`
            (`id`, `account_id`, `title`, `note`, `starts_at`, `ends_at`, `reminder_minutes`)
        VALUES (?, ?, 'Phone QA Session', 'Alle Apps im Spiel durchtesten.',
            DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 25 HOUR), 30)
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `note` = VALUES(`note`),
            `starts_at` = VALUES(`starts_at`), `ends_at` = VALUES(`ends_at`), `reminder_minutes` = 30,
            `reminded_at` = NULL
    ]], { event_id, account_id })

    local marker_one = stable_uuid(context.key .. ":marker:lsc")
    local marker_two = stable_uuid(context.key .. ":marker:pier")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_map_markers` (`id`, `device_imei`, `label`, `color`, `position_x`, `position_y`, `position_z`)
        VALUES (?, ?, 'Los Santos Customs', 'orange', -337.3, -136.9, 39.0)
        ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `color` = VALUES(`color`),
            `position_x` = VALUES(`position_x`), `position_y` = VALUES(`position_y`), `position_z` = VALUES(`position_z`)
    ]], { marker_one, context.imei })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_map_markers` (`id`, `device_imei`, `label`, `color`, `position_x`, `position_y`, `position_z`)
        VALUES (?, ?, 'Del Perro Pier', 'blue', -1649.7, -1078.3, 13.0)
        ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `color` = VALUES(`color`),
            `position_x` = VALUES(`position_x`), `position_y` = VALUES(`position_y`), `position_z` = VALUES(`position_z`)
    ]], { marker_two, context.imei })

    local song_id = stable_uuid(context.key .. ":music:song")
    local playlist_id = stable_uuid(context.key .. ":music:playlist")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_music_youtube_songs` (`id`, `account_id`, `video_id`, `title`, `artist`)
        VALUES (?, ?, 'dQw4w9WgXcQ', 'Never Gonna Give You Up', 'Rick Astley')
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `artist` = VALUES(`artist`)
    ]], { song_id, account_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_music_playlists` (`id`, `account_id`, `name`)
        VALUES (?, ?, 'Test Drive Mix')
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)
    ]], { playlist_id, account_id })
    Bridge.Database.Query("DELETE FROM `sky_phone_music_playlist_items` WHERE `playlist_id` = ?", { playlist_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_music_playlist_items` (`playlist_id`, `source`, `song_id`, `position`)
        VALUES (?, 'youtube', ?, 1)
    ]], { playlist_id, song_id })

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_radio_profiles`
            (`identifier`, `history`, `settings`, `primary_frequency`, `secondary_frequency`, `badge`, `display_name`)
        VALUES (?, ?, ?, 100.1, 101.5, 'QA', ?)
        ON DUPLICATE KEY UPDATE `history` = VALUES(`history`), `settings` = VALUES(`settings`),
            `primary_frequency` = VALUES(`primary_frequency`), `secondary_frequency` = VALUES(`secondary_frequency`)
    ]], {
        context.identifier,
        json.encode({ 100.1, 101.5, 99.9 }),
        json.encode({ volume = 65, notifications = true, autoRejoin = false }),
        context.player_name,
    })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_easyshare_preferences` (`device_imei`, `visibility`)
        VALUES (?, 'everyone') ON DUPLICATE KEY UPDATE `visibility` = 'everyone'
    ]], { context.imei })
    local transfer_id = stable_uuid(context.key .. ":easyshare:transfer")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_easyshare_transfers`
            (`id`, `sender_imei`, `recipient_imei`, `sender_name`, `recipient_name`, `content_type`,
             `payload`, `status`, `progress`, `completed_at`)
        VALUES (?, ?, ?, 'Alex Rivera', ?, 'contact', ?, 'completed', 100, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE `payload` = VALUES(`payload`), `status` = 'completed',
            `progress` = 100, `completed_at` = CURRENT_TIMESTAMP
    ]], {
        transfer_id,
        bot.imei,
        context.imei,
        context.player_name,
        json.encode({ name = "Mia Chen", phoneNumber = context.bot_two.sim.phone_number }),
    })
end

local function seed_marketplace_and_pages(context)
    local account_id = context.account.id
    local bot_id = context.bot_one.account.id
    local own_handle = "tester" .. tostring(account_id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_profiles` (`account_id`, `display_name`, `bio`, `avatar_media_id`)
        VALUES (?, ?, 'QA profile generated in game.', ?)
        ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`),
            `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], { account_id, context.player_name, context.media.user_portrait })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_profiles` (`account_id`, `display_name`, `bio`, `avatar_media_id`)
        VALUES (?, 'Alex Rivera', 'Trusted test seller.', ?)
        ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`),
            `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], { bot_id, context.media.bot_portrait })

    local bot_listing = stable_uuid(context.key .. ":market:bot-listing")
    local own_listing = stable_uuid(context.key .. ":market:own-listing")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_listings`
            (`id`, `seller_account_id`, `title`, `description`, `category`, `item_condition`,
             `price_type`, `price`, `district`, `show_phone`, `phone_number`, `status`, `expires_at`)
        VALUES (?, ?, 'Sultan RS - Test Vehicle', 'Clean test listing with negotiable price.',
            'vehicles', 'very_good', 'negotiable', 42000, 'los_santos', 1, ?, 'active', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY))
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `description` = VALUES(`description`),
            `status` = 'active', `expires_at` = VALUES(`expires_at`)
    ]], { bot_listing, bot_id, context.bot_one.sim.phone_number })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_listings`
            (`id`, `seller_account_id`, `title`, `description`, `category`, `item_condition`,
             `price_type`, `price`, `district`, `status`, `expires_at`)
        VALUES (?, ?, 'QA Headset', 'A listing owned by the test user.', 'electronics', 'used',
            'fixed', 350, 'los_santos', 'active', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY))
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `description` = VALUES(`description`),
            `status` = 'active', `expires_at` = VALUES(`expires_at`)
    ]], { own_listing, account_id })
    local car_gradient = ("url(%s)"):format(json.encode(photo_urls.car))
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_images` (`listing_id`, `media_id`, `gradient`, `sort_order`)
        VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `media_id` = VALUES(`media_id`), `gradient` = VALUES(`gradient`)
    ]], { bot_listing, tostring(context.media.bot_car), car_gradient })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_marketplace_favorites` (`account_id`, `listing_id`) VALUES (?, ?)
    ]], { account_id, bot_listing })
    local inquiry_id = stable_uuid(context.key .. ":market:inquiry")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_inquiries`
            (`id`, `listing_id`, `seller_account_id`, `buyer_account_id`, `offer_amount`,
             `offer_proposer_account_id`, `offer_status`, `offer_revision`)
        VALUES (?, ?, ?, ?, 40000, ?, 'pending', 1)
        ON DUPLICATE KEY UPDATE `offer_amount` = 40000, `offer_proposer_account_id` = VALUES(`offer_proposer_account_id`),
            `offer_status` = 'pending', `offer_revision` = 1
    ]], { inquiry_id, bot_listing, bot_id, account_id, account_id })
    Bridge.Database.Query("DELETE FROM `sky_phone_marketplace_messages` WHERE `inquiry_id` = ?", { inquiry_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_messages` (`inquiry_id`, `sender_account_id`, `body`, `read_at`)
        VALUES (?, ?, 'Ist der Sultan noch verfügbar?', CURRENT_TIMESTAMP),
               (?, ?, 'Ja, gerne Probefahrt in Burton.', NULL)
    ]], { inquiry_id, account_id, inquiry_id, bot_id })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_marketplace_offers` (`inquiry_id`, `proposer_account_id`, `amount`)
        VALUES (?, ?, 40000)
    ]], { inquiry_id, account_id })

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_pages_profiles` (`account_id`, `handle`, `bio`, `avatar_media_id`)
        VALUES (?, ?, 'Lokale Tests, Events und Angebote.', ?)
        ON DUPLICATE KEY UPDATE `handle` = VALUES(`handle`), `bio` = VALUES(`bio`),
            `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], { account_id, own_handle, context.media.user_portrait })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_pages_profiles` (`account_id`, `handle`, `bio`, `avatar_media_id`)
        VALUES (?, 'alex.local', 'News aus Los Santos.', ?)
        ON DUPLICATE KEY UPDATE `bio` = VALUES(`bio`), `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], { bot_id, context.media.bot_portrait })
    local page_post = stable_uuid(context.key .. ":pages:post")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_pages_posts`
            (`id`, `account_id`, `source_type`, `title`, `body`, `category`, `district`)
        VALUES (?, ?, 'personal', 'Car Meet am Pier', 'Heute Abend findet ein offenes Test-Car-Meet statt.',
            'event', 'los_santos')
        ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `body` = VALUES(`body`)
    ]], { page_post, bot_id })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_pages_images` (`post_id`, `media_id`, `gradient`, `sort_order`)
        VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `media_id` = VALUES(`media_id`), `gradient` = VALUES(`gradient`)
    ]], { page_post, tostring(context.media.bot_car), car_gradient })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_pages_reactions` (`post_id`, `account_id`, `kind`)
        VALUES (?, ?, 'like'), (?, ?, 'save')
    ]], { page_post, account_id, page_post, account_id })
end

local function seed_social_apps(context)
    local account_id = context.account.id
    local bot_id = context.bot_one.account.id
    local bot_two_id = context.bot_two.account.id
    local suffix = tostring(account_id)

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_profiles`
            (`id`, `account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`)
        VALUES (?, ?, ?, ?, 'Ingame QA account', ?)
        ON DUPLICATE KEY UPDATE `handle` = VALUES(`handle`), `display_name` = VALUES(`display_name`),
            `bio` = VALUES(`bio`), `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], {
        stable_uuid(context.key .. ":pic:user"), account_id, "tester" .. suffix, context.player_name,
        context.media.user_portrait,
    })
    local pic_user = ensure_string_profile("sky_phone_picstagram_profiles", account_id)
    local pic_bot_seed = stable_uuid("sky_phone:testbot:pic:alex")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_profiles`
            (`id`, `account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`, `verified`)
        VALUES (?, ?, 'alex.rivera', 'Alex Rivera', 'Cars, city lights and test content.', ?, 1)
        ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`),
            `avatar_media_id` = VALUES(`avatar_media_id`), `verified` = 1
    ]], { pic_bot_seed, bot_id, context.media.bot_portrait })
    local pic_bot = ensure_string_profile("sky_phone_picstagram_profiles", bot_id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_sessions` (`device_imei`, `profile_id`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`)
    ]], { context.imei, pic_user })
    local pic_post = stable_uuid(context.key .. ":pic:post")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_posts` (`id`, `profile_id`, `caption`, `location`)
        VALUES (?, ?, 'Night drive through Los Santos #test', 'Vinewood')
        ON DUPLICATE KEY UPDATE `caption` = VALUES(`caption`), `location` = VALUES(`location`), `status` = 'published'
    ]], { pic_post, pic_bot })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_post_media` (`post_id`, `media_id`, `position`)
        VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE `media_id` = VALUES(`media_id`)
    ]], { pic_post, context.media.bot_city })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_picstagram_follows` (`follower_id`, `following_id`, `status`)
        VALUES (?, ?, 'accepted')
    ]], { pic_user, pic_bot })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_picstagram_reactions` (`post_id`, `profile_id`, `kind`)
        VALUES (?, ?, 'like'), (?, ?, 'save')
    ]], { pic_post, pic_user, pic_post, pic_user })
    local pic_comment = stable_uuid(context.key .. ":pic:comment")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_comments` (`id`, `post_id`, `profile_id`, `body`)
        VALUES (?, ?, ?, 'Sieht richtig gut aus!')
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `status` = 'visible'
    ]], { pic_comment, pic_post, pic_user })
    local story_id = stable_uuid(context.key .. ":pic:story")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_stories` (`id`, `profile_id`, `media_id`, `body`, `expires_at`)
        VALUES (?, ?, ?, 'Test story live', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 24 HOUR))
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `status` = 'active', `expires_at` = VALUES(`expires_at`)
    ]], { story_id, pic_bot, context.media.bot_city })
    local pic_activity = stable_uuid(context.key .. ":pic:activity")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_activities` (`id`, `recipient_id`, `actor_id`, `post_id`, `kind`)
        VALUES (?, ?, ?, ?, 'like')
        ON DUPLICATE KEY UPDATE `read_at` = NULL
    ]], { pic_activity, pic_user, pic_bot, pic_post })

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_profiles` (`account_id`, `handle`, `display_name`, `bio`)
        VALUES (?, ?, ?, 'Testing every FlipTok feature.')
        ON DUPLICATE KEY UPDATE `handle` = VALUES(`handle`), `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`)
    ]], { account_id, "tester" .. suffix, context.player_name })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_profiles`
            (`account_id`, `handle`, `display_name`, `bio`, `account_type`, `verified`)
        VALUES (?, 'mia.motion', 'Mia Chen', 'Short videos from Los Santos.', 'media', 1)
        ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`), `verified` = 1
    ]], { bot_two_id })
    local flip_user = ensure_numeric_profile("sky_phone_fliptok_profiles", account_id)
    local flip_bot = ensure_numeric_profile("sky_phone_fliptok_profiles", bot_two_id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_sessions` (`device_imei`, `profile_id`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`)
    ]], { context.imei, flip_user })
    local flip_video = stable_uuid(context.key .. ":flip:video")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_videos`
            (`id`, `profile_id`, `media_id`, `caption`, `location`, `view_count`, `share_count`)
        VALUES (?, ?, ?, 'Flowers in motion #fyp #test', 'Mirror Park', 1842, 37)
        ON DUPLICATE KEY UPDATE `caption` = VALUES(`caption`), `view_count` = 1842,
            `share_count` = 37, `status` = 'published'
    ]], { flip_video, flip_bot, context.media.bot_video })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_fliptok_follows` (`follower_id`, `following_id`) VALUES (?, ?)
    ]], { flip_user, flip_bot })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_fliptok_reactions` (`video_id`, `profile_id`, `kind`)
        VALUES (?, ?, 'like'), (?, ?, 'save')
    ]], { flip_video, flip_user, flip_video, flip_user })
    local flip_comment = stable_uuid(context.key .. ":flip:comment")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_comments` (`id`, `video_id`, `profile_id`, `body`)
        VALUES (?, ?, ?, 'Der Test-Clip läuft flüssig.')
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `status` = 'visible'
    ]], { flip_comment, flip_video, flip_user })
    local flip_notification = stable_uuid(context.key .. ":flip:notification")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`)
        VALUES (?, ?, ?, ?, 'follow') ON DUPLICATE KEY UPDATE `read_at` = NULL
    ]], { flip_notification, flip_user, flip_bot, flip_video })

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_feather_profiles` (`account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`)
        VALUES (?, ?, ?, 'Testing Feather in game.', ?)
        ON DUPLICATE KEY UPDATE `handle` = VALUES(`handle`), `display_name` = VALUES(`display_name`),
            `bio` = VALUES(`bio`), `avatar_media_id` = VALUES(`avatar_media_id`)
    ]], { account_id, "tester" .. suffix, context.player_name, context.media.user_portrait })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_feather_profiles`
            (`account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`, `verified`)
        VALUES (?, 'alex_updates', 'Alex Rivera', 'Los Santos live updates.', ?, 1)
        ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`), `bio` = VALUES(`bio`),
            `avatar_media_id` = VALUES(`avatar_media_id`), `verified` = 1
    ]], { bot_id, context.media.bot_portrait })
    local feather_user = ensure_numeric_profile("sky_phone_feather_profiles", account_id)
    local feather_bot = ensure_numeric_profile("sky_phone_feather_profiles", bot_id)
    local feather_post = stable_uuid(context.key .. ":feather:post")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_feather_posts` (`id`, `profile_id`, `body`)
        VALUES (?, ?, 'Der neue iFruit-Testdatensatz ist live. #LosSantos #PhoneQA')
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `status` = 'published'
    ]], { feather_post, feather_bot })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_feather_hashtags` (`post_id`, `tag`)
        VALUES (?, 'lossantos'), (?, 'phoneqa')
    ]], { feather_post, feather_post })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_feather_follows` (`follower_id`, `following_id`) VALUES (?, ?)
    ]], { feather_user, feather_bot })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_feather_reactions` (`post_id`, `profile_id`, `kind`)
        VALUES (?, ?, 'like'), (?, ?, 'bookmark')
    ]], { feather_post, feather_user, feather_post, feather_user })
    local feather_notification = stable_uuid(context.key .. ":feather:notification")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_feather_notifications` (`id`, `recipient_id`, `actor_id`, `post_id`, `kind`)
        VALUES (?, ?, ?, ?, 'follow') ON DUPLICATE KEY UPDATE `read_at` = NULL
    ]], { feather_notification, feather_user, feather_bot, feather_post })

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_profiles`
            (`account_id`, `name`, `age`, `bio`, `gender`, `interested_in`, `min_age`, `max_age`,
             `avatar`, `interests`, `looking_for`)
        VALUES (?, ?, 27, 'Testing Flare conversations.', 'nonbinary', 'everyone', 21, 40, 0, ?, 'friends')
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `bio` = VALUES(`bio`), `interests` = VALUES(`interests`)
    ]], { account_id, context.player_name:sub(1, 32), json.encode({ "cars", "music", "gaming" }) })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_profiles`
            (`account_id`, `name`, `age`, `bio`, `gender`, `interested_in`, `min_age`, `max_age`,
             `avatar`, `interests`, `looking_for`)
        VALUES (?, 'Mia', 26, 'Coffee, sunsets and good conversations.', 'woman', 'everyone', 21, 40, 1, ?, 'friends')
        ON DUPLICATE KEY UPDATE `bio` = VALUES(`bio`), `interests` = VALUES(`interests`)
    ]], { bot_two_id, json.encode({ "coffee", "travel", "photography" }) })
    local flare_user = ensure_numeric_profile("sky_phone_flare_profiles", account_id)
    local flare_bot = ensure_numeric_profile("sky_phone_flare_profiles", bot_two_id)
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_flare_profile_photos` (`profile_id`, `media_id`, `sort_order`)
        VALUES (?, ?, 1), (?, ?, 1)
    ]], { flare_user, context.media.user_portrait, flare_bot, context.media.bot_two_portrait })
    local account_a = math.min(account_id, bot_two_id)
    local account_b = math.max(account_id, bot_two_id)
    local proposed_match_id = stable_uuid(
        ("sky_phone:testdata:flare:match:%s:%s"):format(account_a, account_b)
    )
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_matches` (`id`, `account_a_id`, `account_b_id`)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `created_at` = `created_at`
    ]], { proposed_match_id, account_a, account_b })
    local match_rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_flare_matches`
        WHERE `account_a_id` = ? AND `account_b_id` = ? LIMIT 1
    ]], { account_a, account_b })
    local match_id = match_rows[1] and match_rows[1].id or nil
    if type(match_id) ~= "string" then
        error("[sky_phone] Test data Flare match could not be loaded.")
    end
    local flare_body = "Hey! Bereit für einen vollständigen App-Test?"
    local message_rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_flare_messages`
        WHERE `match_id` = ? AND `sender_account_id` = ? AND `body` = ?
        ORDER BY `created_at`, `id` LIMIT 1
    ]], { match_id, bot_two_id, flare_body })
    local flare_message = message_rows[1] and message_rows[1].id
        or stable_uuid("sky_phone:testdata:flare:message:" .. match_id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_messages` (`id`, `match_id`, `sender_account_id`, `body`, `read_at`)
        VALUES (?, ?, ?, ?, NULL)
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `read_at` = NULL
    ]], { flare_message, match_id, bot_two_id, flare_body })
end

local function seed_private_and_services(context)
    local account_id = context.account.id
    local bot_id = context.bot_one.account.id
    local user_dark_id, user_invite_code = darkchat_identifiers(account_id)
    local bot_dark_id, bot_invite_code = darkchat_identifiers(bot_id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_profiles`
            (`account_id`, `dark_id`, `invite_code`, `alias`, `avatar_seed`, `notification_mode`, `activity_visible`)
        VALUES (?, ?, ?, 'NightTester', 42, 'private', 1)
        ON DUPLICATE KEY UPDATE `dark_id` = VALUES(`dark_id`), `invite_code` = VALUES(`invite_code`),
            `alias` = VALUES(`alias`), `notification_mode` = VALUES(`notification_mode`)
    ]], { account_id, user_dark_id, user_invite_code })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_profiles`
            (`account_id`, `dark_id`, `invite_code`, `alias`, `avatar_seed`, `notification_mode`, `activity_visible`)
        VALUES (?, ?, ?, 'GhostAlex', 17, 'full', 1)
        ON DUPLICATE KEY UPDATE `dark_id` = VALUES(`dark_id`), `invite_code` = VALUES(`invite_code`),
            `alias` = VALUES(`alias`)
    ]], { bot_id, bot_dark_id, bot_invite_code })
    local dark_user = ensure_numeric_profile("sky_phone_darkchat_profiles", account_id)
    local dark_bot = ensure_numeric_profile("sky_phone_darkchat_profiles", bot_id)
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_darkchat_contacts` (`profile_id`, `contact_profile_id`, `alias_override`)
        VALUES (?, ?, 'Ghost')
    ]], { dark_user, dark_bot })
    local conversation_id = stable_uuid(context.key .. ":dark:conversation")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_conversations` (`id`, `disappearing_seconds`)
        VALUES (?, 0) ON DUPLICATE KEY UPDATE `disappearing_seconds` = 0
    ]], { conversation_id })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_darkchat_members` (`conversation_id`, `profile_id`, `last_read_at`)
        VALUES (?, ?, CURRENT_TIMESTAMP), (?, ?, NULL)
    ]], { conversation_id, dark_user, conversation_id, dark_bot })
    local dark_one = stable_uuid(context.key .. ":dark:message:one")
    local dark_two = stable_uuid(context.key .. ":dark:message:two")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_messages` (`id`, `conversation_id`, `sender_profile_id`, `body`)
        VALUES (?, ?, ?, 'Willkommen im privaten Testchat.')
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `deleted_for_everyone` = 0
    ]], { dark_one, conversation_id, dark_bot })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_messages`
            (`id`, `conversation_id`, `sender_profile_id`, `message_type`, `body`, `reactions`)
        VALUES (?, ?, ?, 'emoji', '🔥', ?)
        ON DUPLICATE KEY UPDATE `body` = VALUES(`body`), `reactions` = VALUES(`reactions`)
    ]], { dark_two, conversation_id, dark_user, json.encode({ ["🔥"] = { dark_bot } }) })

    local crew_user_seed = stable_uuid(context.key .. ":crew:user")
    local crew_bot_seed = stable_uuid("sky_phone:testbot:crew:alex")
    local group_id = stable_uuid(context.key .. ":crew:group")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_profiles` (`id`, `account_id`, `username`, `active_group_id`)
        VALUES (?, ?, ?, NULL)
        ON DUPLICATE KEY UPDATE `username` = VALUES(`username`)
    ]], { crew_user_seed, account_id, ("tester%s"):format(account_id):sub(1, 20) })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_profiles` (`id`, `account_id`, `username`, `active_group_id`)
        VALUES (?, ?, 'alexcrew', NULL)
        ON DUPLICATE KEY UPDATE `username` = VALUES(`username`)
    ]], { crew_bot_seed, bot_id })
    local crew_user = ensure_string_profile("sky_phone_crewlink_profiles", account_id)
    local crew_bot = ensure_string_profile("sky_phone_crewlink_profiles", bot_id)
    local crew_password_salt = crew_user_seed:gsub("-", "")
    local crew_bot_password_salt = crew_bot_seed:gsub("-", "")
    local crew_password_pepper = tostring(Config.Server.CrewLinkPasswordPepper or "")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_credentials` (`profile_id`, `password_hash`, `password_salt`)
        VALUES (?, UNHEX(SHA2(CONCAT(?, ?, 'CrewLink123!'), 256)), ?),
            (?, UNHEX(SHA2(CONCAT(?, ?, 'CrewLink123!'), 256)), ?)
        ON DUPLICATE KEY UPDATE `password_hash` = VALUES(`password_hash`),
            `password_salt` = VALUES(`password_salt`)
    ]], {
        crew_user, crew_password_pepper, crew_password_salt, crew_password_salt,
        crew_bot, crew_password_pepper, crew_bot_password_salt, crew_bot_password_salt,
    })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_groups`
            (`id`, `name`, `colour`, `owner_profile_id`, `invite_code`, `allow_member_pings`, `overhead_allowed`)
        VALUES (?, 'Phone QA Crew', 'violet', ?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `colour` = VALUES(`colour`)
    ]], { group_id, crew_user, ("QA%s"):format(account_id):sub(1, 12) })
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_crewlink_memberships` (`group_id`, `profile_id`, `role`)
        VALUES (?, ?, 'owner'), (?, ?, 'member')
    ]], { group_id, crew_user, group_id, crew_bot })
    Bridge.Database.Query(
        "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = ? WHERE `id` IN (?, ?)",
        { group_id, crew_user, crew_bot }
    )
    local ping_id = stable_uuid(context.key .. ":crew:ping")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_pings`
            (`id`, `group_id`, `creator_profile_id`, `type`, `label`, `position_x`, `position_y`, `position_z`, `expires_at`)
        VALUES (?, ?, ?, 'meeting', 'QA Treffpunkt', -337.3, -136.9, 39.0,
            DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 12 HOUR))
        ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `expires_at` = VALUES(`expires_at`)
    ]], { ping_id, group_id, crew_bot })

    local ride_user_seed = stable_uuid(context.key .. ":skyride:user")
    local ride_bot_seed = stable_uuid("sky_phone:testbot:skyride:alex")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_skyride_profiles` (`id`, `owner_identifier`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `owner_identifier` = VALUES(`owner_identifier`)
    ]], { ride_user_seed, context.identifier })
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_skyride_profiles` (`id`, `owner_identifier`)
        VALUES (?, 'sky_phone:testbot:alex') ON DUPLICATE KEY UPDATE `owner_identifier` = VALUES(`owner_identifier`)
    ]], { ride_bot_seed })
    local ride_user_rows = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_skyride_profiles` WHERE `owner_identifier` = ? LIMIT 1",
        { context.identifier }
    )
    local ride_bot_rows = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_skyride_profiles` WHERE `owner_identifier` = 'sky_phone:testbot:alex' LIMIT 1",
        {}
    )
    local ride_user = ride_user_rows[1] and ride_user_rows[1].id
    local ride_bot = ride_bot_rows[1] and ride_bot_rows[1].id
    if type(ride_user) ~= "string" or type(ride_bot) ~= "string" then
        error("[sky_phone] Test SkyRide profiles could not be loaded.")
    end
    local ride_id = stable_uuid(context.key .. ":skyride:completed")
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_skyride_rides`
            (`id`, `passenger_profile_id`, `driver_profile_id`, `passenger_name`, `driver_name`,
             `status`, `service_class`, `pickup_label`, `pickup_x`, `pickup_y`, `pickup_z`,
             `destination_label`, `destination_x`, `destination_y`, `destination_z`, `distance_meters`,
             `duration_seconds`, `price`, `payout_amount`, `currency`, `driver_vehicle_model`,
             `driver_vehicle_color`, `driver_vehicle_plate`, `passenger_rating`, `rating_comment`,
             `tip_amount`, `tip_status`, `accepted_at`, `arrived_at`, `started_at`, `completed_at`, `paid_out_at`)
        VALUES (?, ?, ?, ?, 'Alex Rivera', 'completed', 'comfort', 'Legion Square', 215.8, -810.1, 30.7,
            'Del Perro Pier', -1649.7, -1078.3, 13.0, 6200, 540, 320, 240, '$', 'Sultan',
            'Midnight Blue', 'QA 2026', 5, 'Saubere Testfahrt.', 25, 'completed',
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 3 HOUR), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 170 MINUTE),
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 165 MINUTE), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR),
            DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR))
        ON DUPLICATE KEY UPDATE `status` = 'completed', `passenger_rating` = 5,
            `rating_comment` = 'Saubere Testfahrt.', `tip_amount` = 25, `tip_status` = 'completed'
    ]], { ride_id, ride_user, ride_bot, context.player_name })

    local company_rows = Bridge.Database.Query(
        "SELECT `company_id` FROM `sky_phone_company_profiles` WHERE `company_id` = 'mechanic' LIMIT 1",
        {}
    )
    if company_rows[1] then
        local request_id = stable_uuid(context.key .. ":company:request")
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_company_requests`
                (`id`, `company_id`, `service_id`, `customer_sim_id`, `subject`, `description`,
                 `status`, `customer_unread`, `company_activity_revision`, `revision`)
            VALUES (?, 'mechanic', 'mechanic-repair', ?, 'Motor verliert Leistung',
                'Testauftrag mit Chatverlauf und Status.', 'waiting_customer', 1, 3, 3)
            ON DUPLICATE KEY UPDATE `subject` = VALUES(`subject`), `description` = VALUES(`description`),
                `status` = 'waiting_customer', `customer_unread` = 1, `company_activity_revision` = 3, `revision` = 3
        ]], { request_id, context.sim.id })
        local request_message = stable_uuid(context.key .. ":company:message")
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_company_request_messages`
                (`id`, `request_id`, `sender_type`, `sender_identifier`, `body`)
            VALUES (?, ?, 'company', 'sky_phone:testbot:mechanic',
                'Bitte komm für eine Diagnose bei Los Santos Customs vorbei.')
            ON DUPLICATE KEY UPDATE `body` = VALUES(`body`)
        ]], { request_message, request_id })
        local request_event = stable_uuid(context.key .. ":company:event")
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_company_request_events`
                (`id`, `request_id`, `event_type`, `actor_type`, `actor_identifier`, `from_status`, `to_status`, `detail`)
            VALUES (?, ?, 'status', 'company', 'sky_phone:testbot:mechanic', 'in_progress', 'waiting_customer',
                'Waiting for the test customer.')
            ON DUPLICATE KEY UPDATE `detail` = VALUES(`detail`)
        ]], { request_event, request_id })
    end
end

local function seed_for_source(source)
    local slots = Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)
    local phone_slot = slots[1]
    if not phone_slot then
        error(("[sky_phone] Test data source %s has no phone item."):format(source))
    end
    local imei, device_error = SkyPhone.EnsureDevice(source, phone_slot)
    if not imei then
        error(("[sky_phone] Test data could not resolve the phone device: %s"):format(tostring(device_error)))
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        error("[sky_phone] Test data could not resolve the player identifier.")
    end

    local player_name = ((Bridge.Framework.GetFirstname(source) or "") .. " "
        .. (Bridge.Framework.GetLastname(source) or "")):match("^%s*(.-)%s*$")
    if player_name == "" then
        player_name = GetPlayerName(source) or ("Player %s"):format(source)
    end
    local device = SkyPhone.LoadDevice(imei)
    local account
    if device and device.account_id then
        local rows = Bridge.Database.Query(
            "SELECT `id`, `email` FROM `sky_phone_accounts` WHERE `id` = ? LIMIT 1",
            { device.account_id }
        )
        account = rows[1]
        if not account then
            error("[sky_phone] Test data found a device with a missing Sky Cloud account.")
        end
        account.id = tonumber(account.id)
    else
        account = ensure_account("tester_" .. seed_hash(identifier) .. "@" .. Config.Mail.Domain)
        Bridge.Database.Query("UPDATE `sky_phone_devices` SET `account_id` = ? WHERE `imei` = ?", { account.id, imei })
    end

    device = SkyPhone.LoadDevice(imei)
    local sim
    if device and device.sim_id then
        local rows = Bridge.Database.Query("SELECT * FROM `sky_phone_sims` WHERE `id` = ? LIMIT 1", { device.sim_id })
        sim = rows[1]
    else
        sim = reserve_sim(identifier, Bridge.Framework.GetFirstname(source), Bridge.Framework.GetLastname(source))
        local previous_imei = move_sim_to_device(sim.id, imei)
        local metadata = phone_slot.metadata or {}
        metadata.sim_id = sim.id
        metadata.phone_number = sim.phone_number
        metadata.formatted_number = SkyPhoneSimNumber.Format(
            sim.phone_number,
            Config.Sim.NumberGroups,
            Config.Sim.NumberLength,
            Config.Sim.NumberPrefix
        )
        if not Bridge.Inventory.SetSlotMetadata(source, phone_slot.slot, metadata) then
            if not restore_sim_attachment(sim.id, imei, previous_imei) then
                error(
                    "[sky_phone] Test data could not update the phone item's SIM metadata or restore its previous device."
                )
            end
            error("[sky_phone] Test data could not update the phone item's SIM metadata.")
        end
    end

    local bot_one = ensure_bot("alex", "phone.bot.alex", "990000000000001", "Alex", "Rivera")
    local bot_two = ensure_bot("mia", "phone.bot.mia", "990000000000002", "Mia", "Chen")
    local context = {
        source = source,
        identifier = identifier,
        player_name = player_name,
        account = account,
        imei = imei,
        sim = sim,
        bot_one = bot_one,
        bot_two = bot_two,
        key = identifier .. ":" .. imei,
        media = {},
    }
    context.media.user_portrait = ensure_media(account.id, "test-user-portrait", photo_urls.portrait, "photo")
    context.media.user_city = ensure_media(account.id, "test-user-city", photo_urls.city, "photo")
    context.media.user_video = ensure_media(account.id, "test-user-video", video_url, "video")
    context.media.bot_portrait = ensure_media(bot_one.account.id, "test-bot-alex-portrait", photo_urls.car, "photo")
    context.media.bot_car = ensure_media(bot_one.account.id, "test-bot-alex-car", photo_urls.car, "photo")
    context.media.bot_city = ensure_media(bot_one.account.id, "test-bot-alex-city", photo_urls.city, "photo")
    context.media.bot_two_portrait = ensure_media(bot_two.account.id, "test-bot-mia-portrait", photo_urls.portrait, "photo")
    context.media.bot_video = ensure_media(bot_two.account.id, "test-bot-mia-video", video_url, "video")

    seed_core(context)
    seed_marketplace_and_pages(context)
    seed_social_apps(context)
    seed_private_and_services(context)
    SkyPhone.RefreshSource(source)
    return account.email
end

RegisterCommand(Config.TestData.Command, function(source)
    if source <= 0 then
        Bridge.Debug("warn", "[sky_phone] The test data command must be run by an in-game player.")
        return
    end
    if Config.TestData.AdminOnly and not Bridge.Framework.HasAdminGroup(source, Config.TestData.AdminGroups) then
        Bridge.Debug("warn", "[sky_phone] Source %s attempted to run the restricted test data command.", tostring(source))
        TriggerClientEvent("sky_phone:testdata:feedback", source, false)
        return
    end
    local now = os.time()
    if seed_attempts[source] and now - seed_attempts[source] < 30 then
        Bridge.Debug("warn", "[sky_phone] Source %s repeated the test data command too quickly.", tostring(source))
        TriggerClientEvent("sky_phone:testdata:feedback", source, false)
        return
    end
    seed_attempts[source] = now
    local success, result = pcall(seed_for_source, source)
    if not success then
        Bridge.Debug("error", "[sky_phone] Test data seeding failed for source %s: %s", tostring(source), tostring(result))
        TriggerClientEvent("sky_phone:testdata:feedback", source, false)
        return
    end
    Bridge.Debug("info", "[sky_phone] Test data seeded for source %s.", tostring(source), { always = true })
    TriggerClientEvent("sky_phone:testdata:feedback", source, true, result)
end, false)

AddEventHandler("playerDropped", function()
    seed_attempts[source] = nil
end)

end)
