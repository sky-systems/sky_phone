Bridge.Database.AfterMigration("sky_phone", function()

SkyPhoneCalls = {}

local calls = {}
local active_by_source = {}
local active_by_sim = {}
local dial_locks = {}
local dialing_by_sim = {}
local next_voice_channel = 10000
local reroute_company_call

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a call UUID.")
    end
    return rows[1].id
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function normalize_contact_email(value)
    local email = trim(value)
    if not email or email == "" then
        return ""
    end
    email = email:lower()
    local local_part = email
    if email:find("@", 1, true) then
        local_part = email:match("^([^@]+)@" .. Config.Mail.Domain:gsub("%.", "%%.") .. "$")
    end
    if not local_part
        or #local_part < Config.Mail.LocalPartMinLength
        or #local_part > Config.Mail.LocalPartMaxLength
        or not local_part:match("^[a-z0-9][a-z0-9._-]*[a-z0-9]$")
        or local_part:find("..", 1, true)
    then
        return nil
    end
    return local_part .. "@" .. Config.Mail.Domain
end

local function scope_for_device(device)
    if device.account_id then
        return tonumber(device.account_id), nil
    end
    return nil, device.imei
end

local function current_scope(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end
    local account_id, device_imei = scope_for_device(device)
    return {
        account_id = account_id,
        device = device,
        device_imei = device_imei,
        session = session,
    }
end

local function scope_condition(scope, alias)
    local prefix = alias and (alias .. ".") or ""
    if scope.account_id then
        return prefix .. "`account_id` = ?", { scope.account_id }
    end
    return prefix .. "`device_imei` = ?", { scope.device_imei }
end

local function find_device_holder(imei)
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local source = tonumber(player_source) or player_source
        if SkyPhone.FindDeviceSlots(source, imei)[1] then
            return source
        end
    end
    return nil
end

local function airplane_mode(imei)
    local rows = Bridge.Database.Query([[
        SELECT `payload` FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = 'settings' LIMIT 1
    ]], { imei })
    if not rows[1] then
        return false
    end
    local payload = json.decode(rows[1].payload)
    return payload and payload.settings and payload.settings.airplaneMode == true
end

local function add_call_entry(call_id, device, direction, status, other_number)
    local account_id, device_imei = scope_for_device(device)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_call_entries`
            (`call_id`, `account_id`, `device_imei`, `direction`, `status`, `other_number`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { call_id, account_id, device_imei, direction, status, other_number })
end

local function send_state(call, source, state, channel)
    local outgoing = source == call.caller_source
    local speaker_supported = Bridge.Speaker.IsEnabled() and (
        call.voice_provider == "yaca"
        or call.voice_provider == "saltychat"
        or (not call.voice_provider and Bridge.Calls.SupportsSpeaker())
    )
    local mute_supported = call.voice_provider == "yaca"
        or (not call.voice_provider and Bridge.Calls.SupportsMute())
    local payload = {
        id = call.id,
        state = state,
        direction = outgoing and "outgoing" or "incoming",
        otherNumber = outgoing and call.callee_number or call.caller_number,
        startedAt = call.started_at,
        answeredAt = call.answered_at,
        channel = channel,
        speakerEnabled = call.speakers and call.speakers[source] == true or false,
        speakerSupported = speaker_supported,
        muted = call.muted and call.muted[source] == true or false,
        muteSupported = mute_supported,
    }
    if call.payphone and outgoing then
        payload.elapsedSeconds = call.payphone.elapsed_seconds or 0
        payload.totalCost = call.payphone.total_cost or 0
        TriggerClientEvent("sky_phone:payphone:state", source, payload)
        return
    end
    TriggerClientEvent("sky_phone:call:state", source, payload)
end

local function notify_recents(device, source)
    if device.account_id then
        SkyPhone.NotifyAccount(device.account_id, "sky_phone:calls:changed", {})
    elseif source then
        TriggerClientEvent("sky_phone:calls:changed", source)
    end
end

local function settle_payphone_call(call, duration)
    local payphone = call.payphone
    local elapsed_seconds = math.max(0, math.floor(tonumber(duration) or 0))
    local price_per_second = math.max(0, math.floor(tonumber(payphone.price_per_second) or 0))
    local billable_seconds = elapsed_seconds
    local total_cost = billable_seconds * price_per_second

    if total_cost > 0 then
        local available_money = tonumber(Bridge.Framework.GetMoney(call.caller_source, Config.Payphones.PaymentAccount))
        if not available_money then
            Bridge.Debug(
                "error",
                "[sky_phone] Payphone settlement could not read the balance for source %s.",
                tostring(call.caller_source)
            )
            billable_seconds = 0
            total_cost = 0
        elseif available_money < total_cost then
            billable_seconds = math.min(elapsed_seconds, math.floor(math.max(0, available_money) / price_per_second))
            total_cost = billable_seconds * price_per_second
        end
    end

    local charged = total_cost == 0
    if total_cost > 0 then
        local success, result = pcall(
            Bridge.Framework.RemoveMoney,
            call.caller_source,
            Config.Payphones.PaymentAccount,
            total_cost
        )
        charged = success and result and true or false
        if not success then
            Bridge.Debug(
                "error",
                "[sky_phone] Payphone settlement failed for source %s: %s",
                tostring(call.caller_source),
                tostring(result)
            )
        elseif not result then
            Bridge.Debug(
                "warn",
                "[sky_phone] Payphone settlement was rejected for source %s.",
                tostring(call.caller_source)
            )
        end
    end

    payphone.elapsed_seconds = elapsed_seconds
    payphone.total_cost = charged and total_cost or 0
    return charged and billable_seconds == elapsed_seconds
end

local function send_payphone_visual(call, action, delay_ms)
    if not call.payphone then
        return
    end
    local coords = call.payphone.coords
    local payload = {
        id = call.id,
        callerSource = call.caller_source,
        model = call.payphone.model,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }
    local event_name = ("sky_phone:payphone:visual:%s"):format(action)
    local routing_bucket = call.payphone.routing_bucket
    local targets = {}
    if action == "stop" and call.payphone.visual_targets then
        for _, target in ipairs(call.payphone.visual_targets) do
            targets[#targets + 1] = target
        end
    else
        for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
            local target = tonumber(player_source) or player_source
            if GetPlayerRoutingBucket(target) == routing_bucket then
                targets[#targets + 1] = target
            end
        end
        if action == "start" then
            call.payphone.visual_targets = targets
        end
    end
    local function dispatch()
        for _, target in ipairs(targets) do
            TriggerClientEvent(event_name, target, payload)
        end
    end
    if delay_ms and delay_ms > 0 then
        SetTimeout(delay_ms, dispatch)
    else
        dispatch()
    end
end

local function finish_call(call, status)
    if not call or call.ended then
        return
    end
    call.ended = true
    if call.voice_started then
        local player_handles = { call.caller_source, call.callee_source }
        for _, player_source in ipairs(player_handles) do
            if call.speakers and call.speakers[player_source] then
                Bridge.Calls.SetSpeaker(player_source, false, call.voice_provider)
            end
        end
        Bridge.Calls.Stop(call.id, player_handles, call.voice_provider)
        call.speakers = {}
        call.muted = {}
        call.voice_started = false
    end
    local ended_at = os.time()
    local duration = call.answered_at and math.max(0, ended_at - call.answered_at) or 0
    if call.payphone and call.answered_at and not settle_payphone_call(call, duration)
        and status ~= "disconnected"
    then
        status = "insufficient_funds"
    end
    local callee_status = status
    if status == "no_answer" or status == "cancelled" then
        callee_status = "missed"
    end
    if call.payphone and call.answered_at and status == "insufficient_funds" then
        callee_status = "completed"
    end
    if not call.payphone then
        Bridge.Database.Transaction({
            {
                query = [[
                    UPDATE `sky_phone_calls`
                    SET `status` = ?, `ended_at` = CURRENT_TIMESTAMP, `duration_seconds` = ?
                    WHERE `id` = ?
                ]],
                params = { status, duration, call.id },
            },
            {
                query = [[
                    UPDATE `sky_phone_call_entries` SET `status` = ?
                    WHERE `call_id` = ? AND `direction` = 'outgoing' AND `status` IN ('ringing', 'connected')
                ]],
                params = { status, call.id },
            },
            {
                query = [[
                    UPDATE `sky_phone_call_entries` SET `status` = ?
                    WHERE `call_id` = ? AND `direction` = 'incoming' AND `status` IN ('ringing', 'connected')
                ]],
                params = { callee_status, call.id },
            },
        })
    end
    active_by_source[call.caller_source] = nil
    if call.caller_sim_id then
        active_by_sim[call.caller_sim_id] = nil
    end
    if call.callee_source then
        active_by_source[call.callee_source] = nil
    end
    if call.callee_sim_id then
        active_by_sim[call.callee_sim_id] = nil
    end
    send_state(call, call.caller_source, status)
    if call.callee_source then
        send_state(call, call.callee_source, callee_status)
    end
    if call.caller_device then
        notify_recents(call.caller_device, call.caller_source)
    end
    if call.callee_device and not call.payphone then
        notify_recents(call.callee_device, call.callee_source)
    end
    if call.payphone then
        local hangup_duration = math.max(
            250,
            math.floor(tonumber(Config.Payphones.Animation.HangupDurationMs) or 2000)
        )
        send_payphone_visual(call, "stop", hangup_duration)
    end
    calls[call.id] = nil
end

function SkyPhoneCalls.EndForSim(sim_id, reason)
    local call_id = active_by_sim[sim_id]
    local call = call_id and calls[call_id] or nil
    if not call then
        return
    end
    if call.callee_sim_id == sim_id and call.company_service_call and not call.answered_at then
        if not reroute_company_call(call, "missed") then
            finish_call(call, "unavailable")
        end
        return
    end
    finish_call(call, reason or "ended")
end

function SkyPhoneCalls.LinkAccountData(account_id, imei)
    local counts = Bridge.Database.Query([[
        SELECT
            (SELECT COUNT(*) FROM `sky_phone_contacts` WHERE `account_id` = ?) AS `contacts`,
            (SELECT COUNT(*) FROM `sky_phone_call_entries` WHERE `account_id` = ?) AS `recents`
    ]], { account_id, account_id })
    local has_cloud_data = counts[1] and ((tonumber(counts[1].contacts) or 0) > 0 or (tonumber(counts[1].recents) or 0) > 0)
    if has_cloud_data then
        return Bridge.Database.Transaction({
            { query = "DELETE FROM `sky_phone_contacts` WHERE `device_imei` = ? AND `account_id` IS NULL", params = { imei } },
            { query = "DELETE FROM `sky_phone_call_entries` WHERE `device_imei` = ? AND `account_id` IS NULL", params = { imei } },
        })
    end
    return Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_contacts` SET `account_id` = ?, `device_imei` = NULL WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { account_id, imei },
        },
        {
            query = "UPDATE `sky_phone_call_entries` SET `account_id` = ?, `device_imei` = NULL WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { account_id, imei },
        },
    })
end

function SkyPhoneCalls.CopyCloudToDevice(account_id, imei)
    return Bridge.Database.Transaction({
        { query = "DELETE FROM `sky_phone_contacts` WHERE `device_imei` = ? AND `account_id` IS NULL", params = { imei } },
        { query = "DELETE FROM `sky_phone_call_entries` WHERE `device_imei` = ? AND `account_id` IS NULL", params = { imei } },
        {
            query = [[
                INSERT INTO `sky_phone_contacts`
                    (`id`, `contact_id`, `device_imei`, `name`, `notes`, `organization`, `email`, `phone_number`, `avatar_media_id`, `favorite`, `created_at`, `updated_at`)
                SELECT UUID(), `contact_id`, ?, `name`, `notes`, `organization`, `email`, `phone_number`, NULL, `favorite`, `created_at`, `updated_at`
                FROM `sky_phone_contacts` WHERE `account_id` = ?
            ]],
            params = { imei, account_id },
        },
        {
            query = [[
                INSERT INTO `sky_phone_call_entries`
                    (`call_id`, `device_imei`, `direction`, `status`, `other_number`, `created_at`)
                SELECT `call_id`, ?, `direction`, `status`, `other_number`, `created_at`
                FROM `sky_phone_call_entries` WHERE `account_id` = ?
            ]],
            params = { imei, account_id },
        },
    })
end

Bridge.Callbacks.Register("sky_phone:contacts:list", function(source)
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    local condition, params = scope_condition(scope)
    local rows = Bridge.Database.Query(([[
        SELECT `contact_id` AS `id`, `name`, `notes`, `organization`, `email`, `phone_number`, `avatar_media_id`, `favorite`,
            (SELECT media.`url` FROM `sky_phone_media` media WHERE media.`id` = `avatar_media_id`) AS `avatar_url`,
            `created_at`, `updated_at`
        FROM `sky_phone_contacts` WHERE %s ORDER BY LOWER(`name`), `phone_number`
    ]]):format(condition), params)
    local system_contacts = SkyPhoneCompanies.GetSystemContacts()
    local system_ids = {}
    local contacts = {}
    for _, contact in ipairs(system_contacts) do
        system_ids[contact.id] = true
        contacts[#contacts + 1] = contact
    end
    for _, contact in ipairs(rows) do
        if not system_ids[contact.id] and not SkyPhoneCompanies.IsSystemContactNumber(contact.phone_number) then
            contacts[#contacts + 1] = contact
        end
    end
    table.sort(contacts, function(left, right)
        local left_name = tostring(left.name):lower()
        local right_name = tostring(right.name):lower()
        if left_name == right_name then
            return tostring(left.phone_number) < tostring(right.phone_number)
        end
        return left_name < right_name
    end)
    return { success = true, data = contacts }
end)

Bridge.Callbacks.Register("sky_phone:contacts:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "contact_save", 30, 60) or type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    local name = trim(data.name)
    local notes = trim(data.notes) or ""
    local organization = trim(data.organization) or ""
    local email = normalize_contact_email(data.email)
    local number = SkyPhoneSimNumber.Normalize(data.phoneNumber, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    local avatar_media_id = tonumber(data.avatarMediaId) or 0
    if not name or name == "" or #name > Config.Calls.ContactNameMaxLength
        or #notes > Config.Calls.ContactNotesMaxLength
        or #organization > Config.Calls.ContactNameMaxLength
        or email == nil or not number
    then
        return { success = false, error = "invalid_contact" }
    end
    if (type(data.id) == "string" and data.id:sub(1, 8) == "company:")
        or SkyPhoneCompanies.IsSystemContactNumber(number)
    then
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s attempted to modify a read-only company contact.",
            tostring(source)
        )
        return { success = false, error = "readonly_contact" }
    end
    if avatar_media_id < 0 or avatar_media_id ~= math.floor(avatar_media_id) then
        return { success = false, error = "invalid_contact" }
    end
    local avatar_url
    if avatar_media_id > 0 then
        local media_error
        avatar_url, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, tostring(avatar_media_id), "photo")
        if not avatar_url then
            return { success = false, error = media_error }
        end
    end
    local condition, condition_params = scope_condition(scope)
    local id = type(data.id) == "string" and data.id or uuid()
    if data.id then
        local owned_params = { id }
        for _, value in ipairs(condition_params) do
            owned_params[#owned_params + 1] = value
        end
        local owned = Bridge.Database.Query(("SELECT `id` FROM `sky_phone_contacts` WHERE `contact_id` = ? AND %s LIMIT 1"):format(condition), owned_params)
        if not owned[1] then
            return { success = false, error = "contact_not_found" }
        end
        local params = { name, notes, organization, email, number, avatar_media_id, id }
        for _, value in ipairs(condition_params) do
            params[#params + 1] = value
        end
        Bridge.Database.Query(([[
            UPDATE `sky_phone_contacts` SET `name` = ?, `notes` = NULLIF(?, ''), `organization` = NULLIF(?, ''), `email` = NULLIF(?, ''), `phone_number` = ?, `avatar_media_id` = NULLIF(?, 0)
            WHERE `contact_id` = ? AND %s
        ]]):format(condition), params)
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_contacts` (`id`, `contact_id`, `account_id`, `device_imei`, `name`, `notes`, `organization`, `email`, `phone_number`, `avatar_media_id`)
            VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), ?, NULLIF(?, 0))
        ]], { uuid(), id, scope.account_id, scope.device_imei, name, notes, organization, email, number, avatar_media_id })
    end
    if scope.account_id then
        SkyPhone.NotifyAccount(scope.account_id, "sky_phone:contacts:changed", {})
    end
    return {
        success = true,
        data = {
            id = id,
            name = name,
            notes = notes ~= "" and notes or nil,
            organization = organization ~= "" and organization or nil,
            email = email ~= "" and email or nil,
            phone_number = number,
            avatar_media_id = avatar_media_id > 0 and avatar_media_id or nil,
            avatar_url = avatar_url,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:contacts:favorite", function(source, data)
    if not SkyPhone.AllowOperation(source, "contact_favorite", 60, 60) or type(data) ~= "table" or type(data.id) ~= "string" or type(data.favorite) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    local condition, condition_params = scope_condition(scope)
    local owned_params = { data.id }
    for _, value in ipairs(condition_params) do
        owned_params[#owned_params + 1] = value
    end
    local owned = Bridge.Database.Query(("SELECT `id` FROM `sky_phone_contacts` WHERE `contact_id` = ? AND %s LIMIT 1"):format(condition), owned_params)
    if not owned[1] then
        return { success = false, error = "contact_not_found" }
    end
    local params = { data.favorite and 1 or 0, data.id }
    for _, value in ipairs(condition_params) do
        params[#params + 1] = value
    end
    Bridge.Database.Query(("UPDATE `sky_phone_contacts` SET `favorite` = ? WHERE `contact_id` = ? AND %s"):format(condition), params)
    if scope.account_id then
        SkyPhone.NotifyAccount(scope.account_id, "sky_phone:contacts:changed", {})
    end
    return { success = true, data = { id = data.id, favorite = data.favorite } }
end)

Bridge.Callbacks.Register("sky_phone:contacts:delete", function(source, data)
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    if data.id:sub(1, 8) == "company:" then
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s attempted to delete a read-only company contact.",
            tostring(source)
        )
        return { success = false, error = "readonly_contact" }
    end
    local condition, values = scope_condition(scope)
    local params = { data.id }
    for _, value in ipairs(values) do
        params[#params + 1] = value
    end
    Bridge.Database.Query(("DELETE FROM `sky_phone_contacts` WHERE `contact_id` = ? AND %s"):format(condition), params)
    if scope.account_id then
        SkyPhone.NotifyAccount(scope.account_id, "sky_phone:contacts:changed", {})
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:calls:recents", function(source)
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    local condition, params = scope_condition(scope, "e")
    params[#params + 1] = Config.Calls.RecentPageSize
    local rows = Bridge.Database.Query(([[
        SELECT e.`id`, e.`call_id`, e.`direction`, e.`status`, e.`other_number`, e.`created_at`,
            c.`duration_seconds`
        FROM `sky_phone_call_entries` e
        JOIN `sky_phone_calls` c ON c.`id` = e.`call_id`
        WHERE %s ORDER BY e.`created_at` DESC, e.`id` DESC LIMIT ?
    ]]):format(condition), params)
    return { success = true, data = rows }
end)

local function create_terminal_call(scope, number, target_sim, status, caller_number)
    local id = uuid()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_calls`
            (`id`, `caller_sim_id`, `callee_sim_id`, `caller_number`, `callee_number`, `status`, `ended_at`)
        VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        id,
        scope.device.sim_id,
        target_sim and target_sim.id or nil,
        caller_number or scope.device.phone_number,
        number,
        status,
    })
    add_call_entry(id, scope.device, "outgoing", status, number)
    notify_recents(scope.device, nil)
    return {
        id = id,
        state = status,
        direction = "outgoing",
        otherNumber = number,
        startedAt = os.time(),
    }
end

local function company_call_target(company_id, caller_source, caller_sim_id, excluded_sim_ids)
    local has_busy_target = false
    for _, candidate in ipairs(SkyPhoneCompanies.GetCallTargets(company_id)) do
        local candidate_source = tonumber(candidate.source)
        local candidate_sim_id = candidate.simId
        local candidate_imei = candidate.imei
        if candidate_source and type(candidate_sim_id) == "string" and type(candidate_imei) == "string"
            and candidate_source ~= caller_source and candidate_sim_id ~= caller_sim_id
            and (not excluded_sim_ids or not excluded_sim_ids[candidate_sim_id])
        then
            if active_by_source[candidate_source] or active_by_sim[candidate_sim_id]
                or dialing_by_sim[candidate_sim_id]
            then
                has_busy_target = true
            else
                dialing_by_sim[candidate_sim_id] = true
                local device = SkyPhone.LoadDevice(candidate_imei)
                local holder = device and find_device_holder(candidate_imei) or nil
                if not device or device.sim_id ~= candidate_sim_id or holder ~= candidate_source then
                    dialing_by_sim[candidate_sim_id] = nil
                elseif SkyPhoneCompanies.IsServiceNumber(device.phone_number) then
                    dialing_by_sim[candidate_sim_id] = nil
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Company call target %s uses reserved service number %s.",
                        tostring(candidate_source),
                        tostring(device.phone_number)
                    )
                elseif airplane_mode(candidate_imei) then
                    dialing_by_sim[candidate_sim_id] = nil
                else
                    return {
                        device = device,
                        sim_id = candidate_sim_id,
                        source = candidate_source,
                    }
                end
            end
        end
    end
    return nil, has_busy_target and "busy" or "unavailable"
end

local handle_no_answer

local function ring_callee(call)
    SkyPhone.OpenDeviceForCall(call.callee_source, call.callee_device.imei)
    TriggerClientEvent("sky_phone:call:incoming", call.callee_source, {
        id = call.id,
        state = "ringing",
        direction = "incoming",
        otherNumber = call.caller_number,
        startedAt = call.started_at,
        device = {
            imei = call.callee_device.imei,
            name = call.callee_device.device_name,
        },
    })
end

local function schedule_no_answer(call)
    call.ring_attempt = (call.ring_attempt or 0) + 1
    local ring_attempt = call.ring_attempt
    SetTimeout(call.ring_seconds * 1000, function()
        local active_call = calls[call.id]
        if active_call and not active_call.answered_at and active_call.ring_attempt == ring_attempt then
            handle_no_answer(active_call)
        end
    end)
end

local function start_ringing_call(call, ring_seconds)
    if not call.payphone then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_calls`
                (`id`, `caller_sim_id`, `callee_sim_id`, `caller_number`, `callee_number`, `status`)
            VALUES (?, ?, ?, ?, ?, 'ringing')
        ]], { call.id, call.caller_sim_id, call.callee_sim_id, call.caller_number, call.callee_number })
        add_call_entry(call.id, call.caller_device, "outgoing", "ringing", call.callee_number)
        add_call_entry(call.id, call.callee_device, "incoming", "ringing", call.caller_number)
    end

    calls[call.id] = call
    active_by_source[call.caller_source] = call.id
    active_by_source[call.callee_source] = call.id
    if call.caller_sim_id then
        active_by_sim[call.caller_sim_id] = call.id
        dialing_by_sim[call.caller_sim_id] = nil
    end
    active_by_sim[call.callee_sim_id] = call.id
    dialing_by_sim[call.callee_sim_id] = nil
    dial_locks[call.caller_source] = nil

    send_state(call, call.caller_source, "ringing")
    if call.payphone then
        send_payphone_visual(call, "start")
    end
    call.ring_seconds = math.max(1, math.floor(tonumber(ring_seconds) or Config.Calls.RingSeconds))
    ring_callee(call)
    schedule_no_answer(call)

    local result = {
        id = call.id,
        state = "ringing",
        direction = "outgoing",
        otherNumber = call.callee_number,
        startedAt = call.started_at,
    }
    if call.payphone then
        result.elapsedSeconds = 0
        result.totalCost = 0
    end
    return result
end

reroute_company_call = function(call, previous_status)
    if not call.company_service_call or call.company_attempts_remaining <= 0 then
        return false
    end
    if call.rerouting then
        return true
    end
    call.rerouting = true
    local next_target = company_call_target(
        call.company_id,
        call.caller_source,
        call.caller_sim_id,
        call.company_attempted_sims
    )
    if not next_target then
        call.rerouting = nil
        return false
    end
    if call.ended or calls[call.id] ~= call then
        dialing_by_sim[next_target.sim_id] = nil
        call.rerouting = nil
        return true
    end

    local previous_source = call.callee_source
    local previous_sim_id = call.callee_sim_id
    local previous_device = call.callee_device
    if not call.payphone then
        local next_account_id, next_device_imei = scope_for_device(next_target.device)
        local updated = Bridge.Database.Transaction({
            {
                query = "UPDATE `sky_phone_calls` SET `callee_sim_id` = ? WHERE `id` = ? AND `status` = 'ringing'",
                params = { next_target.sim_id, call.id },
            },
            {
                query = [[
                    UPDATE `sky_phone_call_entries` SET `status` = ?
                    WHERE `call_id` = ? AND `direction` = 'incoming' AND `status` = 'ringing'
                ]],
                params = { previous_status, call.id },
            },
            {
                query = [[
                    INSERT INTO `sky_phone_call_entries`
                        (`call_id`, `account_id`, `device_imei`, `direction`, `status`, `other_number`)
                    SELECT `id`, ?, ?, 'incoming', 'ringing', ?
                    FROM `sky_phone_calls`
                    WHERE `id` = ? AND `status` = 'ringing'
                ]],
                params = { next_account_id, next_device_imei, call.caller_number, call.id },
            },
        })
        if not updated then
            dialing_by_sim[next_target.sim_id] = nil
            call.rerouting = nil
            Bridge.Debug(
                "error",
                "[sky_phone] Could not reroute company call %s to the next target.",
                tostring(call.id)
            )
            return false
        end
        if call.ended or calls[call.id] ~= call then
            dialing_by_sim[next_target.sim_id] = nil
            call.rerouting = nil
            return true
        end
    end

    send_state(call, previous_source, previous_status)
    if active_by_source[previous_source] == call.id then
        active_by_source[previous_source] = nil
    end
    if active_by_sim[previous_sim_id] == call.id then
        active_by_sim[previous_sim_id] = nil
    end
    if not call.payphone then
        notify_recents(previous_device, previous_source)
    end
    if call.ended or calls[call.id] ~= call then
        dialing_by_sim[next_target.sim_id] = nil
        call.rerouting = nil
        return true
    end

    call.callee_source = next_target.source
    call.callee_sim_id = next_target.sim_id
    call.callee_device = next_target.device
    call.company_attempted_sims[next_target.sim_id] = true
    call.company_attempts_remaining = call.company_attempts_remaining - 1
    active_by_source[call.callee_source] = call.id
    active_by_sim[call.callee_sim_id] = call.id
    dialing_by_sim[call.callee_sim_id] = nil
    call.rerouting = nil
    ring_callee(call)
    schedule_no_answer(call)
    return true
end

handle_no_answer = function(call)
    if not reroute_company_call(call, "missed") then
        finish_call(call, "no_answer")
    end
end

local function lock_direct_target(caller_source, target, caller_sim_id)
    if not target or not target.imei then
        return nil, "unavailable"
    end
    if caller_sim_id then
        local blocks = Bridge.Database.Query([[
            SELECT 1 FROM `sky_phone_call_blocks`
            WHERE `blocker_sim_id` = ? AND `blocked_sim_id` = ? LIMIT 1
        ]], { target.id, caller_sim_id })
        if blocks[1] then
            return nil, "declined"
        end
    end
    local callee_source = find_device_holder(target.imei)
    if not callee_source or callee_source == caller_source then
        return nil, "unavailable"
    end
    if active_by_source[callee_source] or active_by_sim[target.id] or dialing_by_sim[target.id] then
        return nil, "busy"
    end
    dialing_by_sim[target.id] = true
    if airplane_mode(target.imei) then
        dialing_by_sim[target.id] = nil
        return nil, "unavailable"
    end
    return callee_source
end

function SkyPhoneCalls.StartCompanyCall(source, company_id, customer_number)
    source = tonumber(source)
    if not source or type(company_id) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    if not SkyPhoneCompanies.CanPlaceCompanyCall(source, company_id) then
        return { success = false, error = "not_authorized" }
    end
    if not SkyPhone.AllowOperation(source, "company_call_customer", 15, 60) then
        return { success = false, error = "rate_limited" }
    end
    if dial_locks[source] then
        return { success = false, error = "busy" }
    end

    local service_line = SkyPhoneCompanies.GetServiceLineForCompany(company_id)
    if not service_line or not service_line.canCall then
        return { success = false, error = "company_unavailable" }
    end
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    if not scope.device.sim_id then
        return { success = false, error = "no_sim" }
    end
    if SkyPhoneCompanies.IsServiceNumber(scope.device.phone_number) then
        Bridge.Debug(
            "error",
            "[sky_phone] Source %s attempted to call from a SIM using reserved service number %s.",
            tostring(source),
            tostring(scope.device.phone_number)
        )
        return { success = false, error = "invalid_sim" }
    end
    if airplane_mode(scope.device.imei) then
        return { success = false, error = "airplane_mode" }
    end

    local number = SkyPhoneSimNumber.Normalize(customer_number, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number or SkyPhoneCompanies.IsServiceNumber(number) then
        return { success = false, error = "invalid_number" }
    end
    if number == scope.device.phone_number then
        return { success = false, error = "self_call" }
    end
    if active_by_source[source] or active_by_sim[scope.device.sim_id] or dialing_by_sim[scope.device.sim_id] then
        return { success = false, error = "busy" }
    end

    dial_locks[source] = true
    dialing_by_sim[scope.device.sim_id] = true
    local targets = Bridge.Database.Query([[
        SELECT s.`id`, s.`phone_number`, d.`imei`, d.`account_id`, d.`device_name`
        FROM `sky_phone_sims` s LEFT JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
        WHERE s.`phone_number` = ? LIMIT 1
    ]], { number })
    local target = targets[1]
    local callee_source, target_status = lock_direct_target(source, target, scope.device.sim_id)
    if not callee_source then
        local terminal = create_terminal_call(scope, number, target, target_status, service_line.number)
        dialing_by_sim[scope.device.sim_id] = nil
        dial_locks[source] = nil
        return { success = true, data = terminal }
    end

    return {
        success = true,
        data = start_ringing_call({
            id = uuid(),
            caller_source = source,
            caller_sim_id = scope.device.sim_id,
            caller_number = service_line.number,
            caller_device = scope.device,
            callee_source = callee_source,
            callee_sim_id = target.id,
            callee_number = number,
            callee_device = target,
            company_id = company_id,
            started_at = os.time(),
        }, Config.Calls.RingSeconds),
    }
end

Bridge.Callbacks.Register("sky_phone:calls:dial", function(source, data)
    if not SkyPhone.AllowOperation(source, "call_dial", 15, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if dial_locks[source] then
        return { success = false, error = "busy" }
    end
    dial_locks[source] = true
    local scope, error_response = current_scope(source)
    if not scope then
        dial_locks[source] = nil
        return error_response
    end
    if not scope.device.sim_id then
        dial_locks[source] = nil
        return { success = false, error = "no_sim" }
    end
    if SkyPhoneCompanies.IsServiceNumber(scope.device.phone_number) then
        Bridge.Debug(
            "error",
            "[sky_phone] Source %s attempted to call from a SIM using reserved service number %s.",
            tostring(source),
            tostring(scope.device.phone_number)
        )
        dial_locks[source] = nil
        return { success = false, error = "invalid_sim" }
    end
    if airplane_mode(scope.device.imei) then
        dial_locks[source] = nil
        return { success = false, error = "airplane_mode" }
    end
    local service_line = type(data.company) == "string"
        and SkyPhoneCompanies.GetServiceLineForCompany(data.company)
        or SkyPhoneCompanies.GetServiceLine(data.phoneNumber)
    local number = service_line and service_line.number
        or SkyPhoneSimNumber.Normalize(data.phoneNumber, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        dial_locks[source] = nil
        return { success = false, error = "invalid_number" }
    end
    if number == scope.device.phone_number then
        dial_locks[source] = nil
        return { success = false, error = "self_call" }
    end
    if active_by_source[source] or active_by_sim[scope.device.sim_id] or dialing_by_sim[scope.device.sim_id] then
        dial_locks[source] = nil
        return { success = false, error = "busy" }
    end
    dialing_by_sim[scope.device.sim_id] = true
    if service_line then
        if not service_line.canCall then
            local terminal = create_terminal_call(scope, number, nil, "unavailable")
            dialing_by_sim[scope.device.sim_id] = nil
            dial_locks[source] = nil
            return { success = true, data = terminal }
        end
        local company_target, target_status = company_call_target(
            service_line.companyId,
            source,
            scope.device.sim_id
        )
        if not company_target then
            local terminal = create_terminal_call(scope, number, nil, target_status)
            dialing_by_sim[scope.device.sim_id] = nil
            dial_locks[source] = nil
            return { success = true, data = terminal }
        end
        return {
            success = true,
            data = start_ringing_call({
                id = uuid(),
                caller_source = source,
                caller_sim_id = scope.device.sim_id,
                caller_number = scope.device.phone_number,
                caller_device = scope.device,
                callee_source = company_target.source,
                callee_sim_id = company_target.sim_id,
                callee_number = service_line.number,
                callee_device = company_target.device,
                company_id = service_line.companyId,
                company_service_call = service_line.routing == "round_robin",
                company_attempted_sims = { [company_target.sim_id] = true },
                company_attempts_remaining = math.max(
                    0,
                    math.floor(tonumber(Config.Companies.CallRouting.MaxAttempts) or 1) - 1
                ),
                started_at = os.time(),
            }, Config.Companies.CallRouting.RingSeconds),
        }
    end

    local targets = Bridge.Database.Query([[
        SELECT s.`id`, s.`phone_number`, d.`imei`, d.`account_id`, d.`device_name`
        FROM `sky_phone_sims` s LEFT JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
        WHERE s.`phone_number` = ? LIMIT 1
    ]], { number })
    local target = targets[1]
    if not target then
        dialing_by_sim[scope.device.sim_id] = nil
        dial_locks[source] = nil
        return { success = false, error = "recipient_not_found" }
    end
    local callee_source, target_status = lock_direct_target(source, target, scope.device.sim_id)
    if not callee_source then
        local terminal = create_terminal_call(scope, number, target, target_status)
        dialing_by_sim[scope.device.sim_id] = nil
        dial_locks[source] = nil
        return { success = true, data = terminal }
    end

    return {
        success = true,
        data = start_ringing_call({
            id = uuid(),
            caller_source = source,
            caller_sim_id = scope.device.sim_id,
            caller_number = scope.device.phone_number,
            caller_device = scope.device,
            callee_source = callee_source,
            callee_sim_id = target.id,
            callee_number = number,
            callee_device = target,
            started_at = os.time(),
        }, Config.Calls.RingSeconds),
    }
end)

local payphone_models = {}
for _, model_name in ipairs(Config.Payphones.Props or {}) do
    if type(model_name) == "string" then
        payphone_models[model_name] = true
    end
end

if Config.Payphones.Enabled and not next(payphone_models) then
    Bridge.Debug(
        "error",
        "[sky_phone] Payphones are enabled, but Config.Payphones.Props contains no valid models; payphone calls will be rejected.",
        { always = true }
    )
end

local function valid_payphone_position(source, detected_booth)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end
    local location = SkyPhonePayphones.ValidateDetected(
        detected_booth,
        payphone_models,
        GetEntityCoords(ped),
        Config.Payphones.ServerValidationDistance
    )
    if not location then
        return nil
    end
    return vector3(location.coords.x, location.coords.y, location.coords.z), location.model
end

local function payphone_terminal(number, state)
    return {
        id = ("payphone-terminal-%s-%s"):format(os.time(), math.random(100000, 999999)),
        state = state,
        direction = "outgoing",
        otherNumber = number,
        startedAt = os.time(),
        elapsedSeconds = 0,
        totalCost = 0,
    }
end

Bridge.Callbacks.Register("sky_phone:payphone:dial", function(source, data)
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if not Config.Payphones.Enabled or not SkyPhone.AllowOperation(source, "payphone_dial", 15, 60) then
        return { success = false, error = "rate_limited" }
    end
    local booth_coords, booth_model = valid_payphone_position(source, data)
    if not booth_coords then
        return { success = false, error = "invalid_payphone" }
    end
    if active_by_source[source] or dial_locks[source] then
        return { success = false, error = "busy" }
    end

    local service_line = SkyPhoneCompanies.GetServiceLine(data.phoneNumber)
    local number = service_line and service_line.number
        or SkyPhoneSimNumber.Normalize(data.phoneNumber, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        return { success = false, error = "invalid_number" }
    end
    local price_per_second = math.max(0, math.floor(tonumber(Config.Payphones.PricePerSecond) or 0))
    local available_money = Bridge.Framework.GetMoney(source, Config.Payphones.PaymentAccount)
    if price_per_second > 0 and (not available_money or available_money < price_per_second) then
        return { success = false, error = "insufficient_funds" }
    end

    dial_locks[source] = true
    if service_line then
        if not service_line.canCall then
            dial_locks[source] = nil
            return { success = true, data = payphone_terminal(number, "unavailable") }
        end
        local company_target, target_status = company_call_target(service_line.companyId, source, nil)
        if not company_target then
            dial_locks[source] = nil
            return { success = true, data = payphone_terminal(number, target_status) }
        end
        return {
            success = true,
            data = start_ringing_call({
                id = uuid(),
                caller_source = source,
                caller_number = Config.Payphones.CallerNumber,
                callee_source = company_target.source,
                callee_sim_id = company_target.sim_id,
                callee_number = service_line.number,
                callee_device = company_target.device,
                company_id = service_line.companyId,
                company_service_call = service_line.routing == "round_robin",
                company_attempted_sims = { [company_target.sim_id] = true },
                company_attempts_remaining = math.max(
                    0,
                    math.floor(tonumber(Config.Companies.CallRouting.MaxAttempts) or 1) - 1
                ),
                started_at = os.time(),
                payphone = {
                    elapsed_seconds = 0,
                    total_cost = 0,
                    coords = booth_coords,
                    model = booth_model,
                    price_per_second = price_per_second,
                    routing_bucket = GetPlayerRoutingBucket(source),
                },
            }, Config.Companies.CallRouting.RingSeconds),
        }
    end

    local targets = Bridge.Database.Query([[
        SELECT s.`id`, s.`phone_number`, d.`imei`, d.`account_id`, d.`device_name`
        FROM `sky_phone_sims` s LEFT JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
        WHERE s.`phone_number` = ? LIMIT 1
    ]], { number })
    local target = targets[1]
    local callee_source, target_status = lock_direct_target(source, target)
    if not callee_source then
        dial_locks[source] = nil
        return { success = true, data = payphone_terminal(number, target_status) }
    end

    return {
        success = true,
        data = start_ringing_call({
            id = uuid(),
            caller_source = source,
            caller_number = Config.Payphones.CallerNumber,
            callee_source = callee_source,
            callee_sim_id = target.id,
            callee_number = number,
            callee_device = target,
            started_at = os.time(),
            payphone = {
                elapsed_seconds = 0,
                total_cost = 0,
                coords = booth_coords,
                model = booth_model,
                price_per_second = price_per_second,
                routing_bucket = GetPlayerRoutingBucket(source),
            },
        }, Config.Payphones.NoAnswerTimeoutSeconds),
    }
end)

Bridge.Callbacks.Register("sky_phone:calls:answer", function(source, data)
    local call = type(data) == "table" and calls[data.id] or nil
    if not call or call.callee_source ~= source or call.answered_at or call.rerouting then
        return { success = false, error = "call_not_found" }
    end
    if call.company_service_call and not SkyPhoneCompanies.CanAnswerCompanyCall(
        source,
        call.company_id,
        call.callee_device.imei,
        call.callee_sim_id
    ) then
        if not reroute_company_call(call, "missed") then
            finish_call(call, "unavailable")
        end
        return { success = false, error = "call_not_found" }
    end
    if not SkyPhone.FindDeviceSlots(source, call.callee_device.imei)[1] then
        finish_call(call, "unavailable")
        return { success = false, error = "phone_not_owned" }
    end
    if not Bridge.Calls.IsAvailable() then
        return { success = false, error = "voice_unavailable" }
    end
    local voice_started, voice_provider = Bridge.Calls.Start(call.id, {
        call.caller_source,
        call.callee_source,
    })
    if not voice_started then
        return { success = false, error = "voice_unavailable" }
    end
    call.voice_provider = voice_provider
    call.voice_started = true
    call.speakers = {}
    call.muted = {}
    call.answered_at = os.time()
    call.channel = next_voice_channel
    next_voice_channel = next_voice_channel + 1
    if not call.payphone then
        Bridge.Database.Query([[
            UPDATE `sky_phone_calls` SET `status` = 'connected', `answered_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `status` = 'ringing'
        ]], { call.id })
        Bridge.Database.Query([[
            UPDATE `sky_phone_call_entries` SET `status` = 'connected'
            WHERE `call_id` = ? AND `status` = 'ringing'
        ]], { call.id })
    end
    if call.ended or calls[call.id] ~= call then
        return { success = false, error = "call_not_found" }
    end
    send_state(call, call.caller_source, "connected", call.channel)
    send_state(call, call.callee_source, "connected", call.channel)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:calls:set-speaker", function(source, data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.enabled) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if not SkyPhone.AllowOperation(source, "call_speaker", 30, 60) then
        return { success = false, error = "rate_limited" }
    end

    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if not call or call.id ~= data.id or not call.answered_at or call.ended or not call.voice_started then
        return { success = false, error = "call_not_found" }
    end
    if call.voice_provider ~= "yaca" and call.voice_provider ~= "saltychat" then
        return { success = false, error = "speaker_unsupported" }
    end
    if not Bridge.Speaker.IsEnabled() then
        return { success = false, error = "speaker_unsupported" }
    end
    if not Bridge.Calls.SetSpeaker(source, data.enabled, call.voice_provider) then
        return { success = false, error = "voice_unavailable" }
    end

    call.speakers[source] = data.enabled
    send_state(call, source, "connected", call.channel)
    return {
        success = true,
        data = {
            speakerEnabled = data.enabled,
            speakerSupported = true,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:calls:set-muted", function(source, data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.enabled) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if not SkyPhone.AllowOperation(source, "call_mute", 30, 60) then
        return { success = false, error = "rate_limited" }
    end

    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if not call or call.id ~= data.id or not call.answered_at or call.ended or not call.voice_started then
        return { success = false, error = "call_not_found" }
    end
    if call.voice_provider ~= "yaca" then
        return { success = false, error = "mute_unsupported" }
    end
    if not Bridge.Calls.SetMuted(source, data.enabled, call.voice_provider) then
        return { success = false, error = "voice_unavailable" }
    end

    call.muted[source] = data.enabled
    send_state(call, source, "connected", call.channel)
    return {
        success = true,
        data = {
            muted = data.enabled,
            muteSupported = true,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:calls:decline", function(source, data)
    local call = type(data) == "table" and calls[data.id] or nil
    if not call or call.callee_source ~= source or call.answered_at or call.rerouting then
        return { success = false, error = "call_not_found" }
    end
    if not reroute_company_call(call, "declined") then
        finish_call(call, "declined")
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:calls:hangup", function(source, data)
    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if not call or (call.payphone and call.caller_source == source)
        or (type(data) == "table" and data.id and data.id ~= call.id)
    then
        return { success = false, error = "call_not_found" }
    end
    if call.company_service_call and not call.answered_at and call.callee_source == source then
        if call.rerouting then
            return { success = false, error = "call_not_found" }
        end
        if not reroute_company_call(call, "declined") then
            finish_call(call, "declined")
        end
        return { success = true }
    end
    finish_call(call, call.answered_at and "completed" or "cancelled")
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:calls:block", function(source, data)
    if not SkyPhone.AllowOperation(source, "call_block", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local scope, error_response = current_scope(source)
    if not scope then
        return error_response
    end
    if not scope.device.sim_id then
        return { success = false, error = "no_sim" }
    end
    local number = type(data) == "table" and SkyPhoneSimNumber.Normalize(
        data.phoneNumber,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    ) or nil
    if not number then
        return { success = false, error = "invalid_number" }
    end
    if number == scope.device.phone_number then
        return { success = false, error = "self_call" }
    end
    local rows = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_sims` WHERE `phone_number` = ? LIMIT 1",
        { number }
    )
    if not rows[1] then
        return { success = false, error = "recipient_not_found" }
    end
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_call_blocks` (`blocker_sim_id`, `blocked_sim_id`)
        VALUES (?, ?)
    ]], { scope.device.sim_id, rows[1].id })

    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if call then
        local other_number = source == call.caller_source and call.callee_number or call.caller_number
        if other_number == number then
            finish_call(call, call.answered_at and "completed" or "declined")
        end
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:payphone:hangup", function(source, data)
    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if not call or not call.payphone or call.caller_source ~= source
        or (type(data) == "table" and data.id and data.id ~= call.id)
    then
        return { success = false, error = "call_not_found" }
    end
    finish_call(call, call.answered_at and "completed" or "cancelled")
    return { success = true }
end)

CreateThread(function()
    while true do
        Wait(1000)
        local calls_to_finish = {}
        for call_id, call in pairs(calls) do
            local caller_valid = true
            if call.payphone then
                local caller_ped = GetPlayerPed(call.caller_source)
                caller_valid = caller_ped and caller_ped ~= 0
                if caller_valid then
                    caller_valid = #(GetEntityCoords(caller_ped) - call.payphone.coords)
                        <= Config.Payphones.MaximumCallDistance
                end
            else
                caller_valid = SkyPhone.FindDeviceSlots(call.caller_source, call.caller_device.imei)[1] ~= nil
            end
            local callee_valid = not call.callee_source
                or SkyPhone.FindDeviceSlots(call.callee_source, call.callee_device.imei)[1] ~= nil
            if not caller_valid then
                calls_to_finish[call_id] = "disconnected"
            elseif not callee_valid then
                if call.company_service_call and not call.answered_at then
                    if not reroute_company_call(call, "missed") then
                        calls_to_finish[call_id] = "unavailable"
                    end
                else
                    calls_to_finish[call_id] = "disconnected"
                end
            elseif call.payphone and call.answered_at and not call.ended then
                local elapsed_seconds = math.max(0, os.time() - call.answered_at)
                local total_cost = elapsed_seconds * call.payphone.price_per_second
                local available_money = tonumber(
                    Bridge.Framework.GetMoney(call.caller_source, Config.Payphones.PaymentAccount)
                )
                if total_cost > 0 and (not available_money or available_money < total_cost) then
                    calls_to_finish[call_id] = "insufficient_funds"
                elseif call.payphone.elapsed_seconds ~= elapsed_seconds then
                    call.payphone.elapsed_seconds = elapsed_seconds
                    call.payphone.total_cost = total_cost
                    send_state(call, call.caller_source, "connected", call.channel)
                end
            end
        end
        for call_id, status in pairs(calls_to_finish) do
            finish_call(calls[call_id], status)
        end
    end
end)

AddEventHandler("playerDropped", function()
    local call_id = active_by_source[source]
    local call = call_id and calls[call_id] or nil
    if not call then
        return
    end
    if call.callee_source == source and call.company_service_call and not call.answered_at then
        if not reroute_company_call(call, "missed") then
            finish_call(call, "unavailable")
        end
        return
    end
    finish_call(call, "disconnected")
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    local call_ids = {}
    for call_id in pairs(calls) do
        call_ids[#call_ids + 1] = call_id
    end
    for _, call_id in ipairs(call_ids) do
        finish_call(calls[call_id], "disconnected")
    end
end)
end)
