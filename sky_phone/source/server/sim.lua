Bridge.Database.AfterMigration("sky_phone", function()

SkyPhoneSim = {}

local pending_insertions = {}
local operation_locks = {}
local sim_types = {}

local function refresh_sim_types()
    sim_types = {
        [Config.Sim.RegisteredItem] = "registered",
        [Config.Sim.AnonymousItem] = "anonymous",
    }
end

refresh_sim_types()

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a SIM UUID.")
    end
    return rows[1].id
end

local function reserve_sim(sim_type, is_virtual)
    local sim_id
    local number = SkyPhoneSimNumber.Reserve(uuid, function(candidate)
        if SkyPhoneCompanies.IsServiceNumber(candidate) then
            return false
        end
        sim_id = uuid()
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_sims` (`id`, `phone_number`, `sim_type`, `is_virtual`)
            VALUES (?, ?, ?, ?)
        ]], { sim_id, candidate, sim_type, is_virtual and 1 or 0 })
        return affected_rows(result) == 1
    end, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        error("[sky_phone] Could not reserve a unique SIM number after 20 attempts.")
    end
    return { id = sim_id, phone_number = number, sim_type = sim_type }
end

local function load_sim(sim_id)
    local rows = Bridge.Database.Query("SELECT * FROM `sky_phone_sims` WHERE `id` = ? LIMIT 1", { sim_id })
    return rows[1]
end

local function sim_metadata(sim)
    local metadata = {
        sim_metadata_version = 1,
        sim_id = sim.id,
        phone_number = sim.phone_number,
        formatted_number = SkyPhoneSimNumber.Format(sim.phone_number, Config.Sim.NumberGroups, Config.Sim.NumberLength, Config.Sim.NumberPrefix),
        sim_type = sim.sim_type,
    }
    if sim.sim_type == "registered" and sim.owner_identifier then
        metadata.firstname = sim.owner_firstname
        metadata.lastname = sim.owner_lastname
        metadata.birthdate = sim.owner_birthdate
        metadata.registered_at = sim.registered_at
    end
    return metadata
end

local function set_phone_sim_metadata(source, phone_slot, sim)
    if Config.Phone.Unique == false then
        return true
    end
    if not phone_slot then
        return false
    end

    local metadata = phone_slot.metadata or {}
    metadata.sim_id = sim and sim.id or nil
    metadata.phone_number = sim and sim.phone_number or nil
    metadata.formatted_number = sim and SkyPhoneSimNumber.Format(
        sim.phone_number,
        Config.Sim.NumberGroups,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    ) or nil
    return Bridge.Inventory.SetSlotMetadata(source, phone_slot.slot, metadata)
end

local function prepare_device(source, phone_slot, imei)
    local device = SkyPhone.LoadDevice(imei)
    if not device then
        return false, "request_failed"
    end

    local sim = device.sim_id and load_sim(device.sim_id) or nil
    if Config.Sim.Enabled ~= false then
        if sim and tonumber(sim.is_virtual) == 1 then
            local result = Bridge.Database.Query([[
                UPDATE `sky_phone_devices`
                SET `sim_id` = NULL
                WHERE `imei` = ? AND `sim_id` = ?
            ]], { imei, sim.id })
            if affected_rows(result) ~= 1 then
                return false, "request_failed"
            end
            sim = nil
        end

        if not set_phone_sim_metadata(source, phone_slot, sim) then
            return false, "metadata_unsupported"
        end
        return true
    end

    if sim then
        if not set_phone_sim_metadata(source, phone_slot, sim) then
            return false, "metadata_unsupported"
        end
        return true
    end

    local automatic_sim = reserve_sim("anonymous", true)
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_devices`
        SET `sim_id` = ?
        WHERE `imei` = ? AND `sim_id` IS NULL
    ]], { automatic_sim.id, imei })
    if affected_rows(result) ~= 1 then
        Bridge.Database.Query("DELETE FROM `sky_phone_sims` WHERE `id` = ?", { automatic_sim.id })
        device = SkyPhone.LoadDevice(imei)
        sim = device and device.sim_id and load_sim(device.sim_id) or nil
        if not sim then
            return false, "request_failed"
        end
        if not set_phone_sim_metadata(source, phone_slot, sim) then
            return false, "metadata_unsupported"
        end
        return true
    end

    if not set_phone_sim_metadata(source, phone_slot, automatic_sim) then
        Bridge.Database.Query(
            "UPDATE `sky_phone_devices` SET `sim_id` = NULL WHERE `imei` = ? AND `sim_id` = ?",
            { imei, automatic_sim.id }
        )
        Bridge.Database.Query("DELETE FROM `sky_phone_sims` WHERE `id` = ?", { automatic_sim.id })
        return false, "metadata_unsupported"
    end
    TriggerEvent("sky_phone:server:phoneNumberGenerated", source, automatic_sim.phone_number)
    return true
end

SkyPhoneSim.PrepareDevice = prepare_device

function SkyPhoneSim.ChangeNumber(source, imei, sim_id, value)
    local number = SkyPhoneSimNumber.Normalize(value, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number or SkyPhoneCompanies.IsServiceNumber(number) then
        return false, "invalid_phone_number"
    end

    local sim = load_sim(sim_id)
    if not sim then
        return false, "no_sim"
    end
    if sim.phone_number == number then
        return false, "phone_number_unchanged"
    end

    local existing = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_sims` WHERE `phone_number` = ? AND `id` <> ? LIMIT 1",
        { number, sim_id }
    )
    if existing[1] then
        return false, "phone_number_taken"
    end

    local phone_slot
    if Config.Phone.Unique ~= false then
        for _, slot in ipairs(Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)) do
            if slot.metadata and slot.metadata.imei == imei then
                phone_slot = slot
                break
            end
        end
    end

    local previous_number = sim.phone_number
    sim.phone_number = number
    if phone_slot and not set_phone_sim_metadata(source, phone_slot, sim) then
        return false, "metadata_unsupported"
    end

    local result = Bridge.Database.Query([[
        UPDATE IGNORE `sky_phone_sims`
        SET `phone_number` = ?
        WHERE `id` = ? AND `phone_number` = ?
    ]], { number, sim_id, previous_number })
    if affected_rows(result) ~= 1 then
        if phone_slot then
            sim.phone_number = previous_number
            if not set_phone_sim_metadata(source, phone_slot, sim) then
                error("[sky_phone] Could not restore SIM metadata after a failed admin number change.")
            end
        end
        return false, "phone_number_taken"
    end

    return true, number
end

local function resolve_used_sim(source, used_item, item_name)
    local slot_id = used_item and (used_item.slot or used_item.id)
    local slot = slot_id and Bridge.Inventory.GetSlot(source, slot_id) or nil
    if slot and slot.name == item_name then
        return slot
    end
    local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name)
    if #slots == 1 then
        return slots[1]
    end
    Bridge.Debug("warn", "[sky_phone] Could not resolve exact SIM slot for source %s.", tostring(source))
    return nil
end

local function ensure_sim(source, slot, sim_type)
    if (tonumber(slot.amount or slot.count) or 0) ~= 1 then
        return nil, "sim_stacked"
    end
    local metadata = slot.metadata or {}
    local sim = metadata.sim_id and load_sim(metadata.sim_id) or nil
    if metadata.sim_id and (
        not sim
        or tonumber(sim.is_virtual) == 1
        or sim.sim_type ~= sim_type
        or sim.phone_number ~= metadata.phone_number
    ) then
        return nil, "invalid_sim"
    end
    if sim and SkyPhoneCompanies.IsServiceNumber(sim.phone_number) then
        Bridge.Debug(
            "error",
            "[sky_phone] SIM %s uses reserved company service number %s.",
            tostring(sim.id),
            tostring(sim.phone_number)
        )
        return nil, "invalid_sim"
    end
    local generated = false
    if not sim then
        sim = reserve_sim(sim_type)
        if not Bridge.Inventory.SetSlotMetadata(source, slot.slot, sim_metadata(sim)) then
            Bridge.Database.Query("DELETE FROM `sky_phone_sims` WHERE `id` = ?", { sim.id })
            return nil, "metadata_unsupported"
        end
        generated = true
    end
    if generated then
        TriggerEvent("sky_phone:server:phoneNumberGenerated", source, sim.phone_number)
    end
    return sim
end

local function list_phone_choices(source)
    local choices = {}
    local seen = {}
    local choice_error
    for _, slot in ipairs(Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)) do
        local imei, error_code = SkyPhone.EnsureDevice(source, slot)
        if imei and not seen[imei] then
            local prepared, prepare_error = prepare_device(source, slot, imei)
            if prepared then
                local device = SkyPhone.LoadDevice(imei)
                choices[#choices + 1] = {
                    imei = imei,
                    name = device.device_name,
                    occupied = device.sim_id ~= nil,
                    number = device.phone_number,
                }
                seen[imei] = true
            else
                Bridge.Debug(
                    "error",
                    "[sky_phone] Could not prepare SIM target %s for source %s: %s.",
                    imei,
                    tostring(source),
                    tostring(prepare_error)
                )
                choice_error = choice_error or prepare_error
            end
        elseif not imei then
            choice_error = choice_error or error_code
        end
    end
    return choices, choice_error
end

local function rollback_phone_metadata(source, phone_slot, old_sim)
    set_phone_sim_metadata(source, phone_slot, old_sim)
end

local function insert_sim(source, phone_imei, confirmed)
    if Config.Sim.Enabled == false then
        return { success = false, error = "disabled" }
    end
    if operation_locks[source] then
        return { success = false, error = "operation_in_progress" }
    end
    local pending = pending_insertions[source]
    if not pending or GetGameTimer() - pending.created_at > 60000 then
        pending_insertions[source] = nil
        return { success = false, error = "sim_request_expired" }
    end
    if SkyPhoneCompanies.IsServiceNumber(pending.sim.phone_number) then
        pending_insertions[source] = nil
        Bridge.Debug(
            "error",
            "[sky_phone] Refused to insert SIM %s with reserved company service number %s.",
            tostring(pending.sim.id),
            tostring(pending.sim.phone_number)
        )
        return { success = false, error = "invalid_sim" }
    end
    local sim_slot = Bridge.Inventory.GetSlot(source, pending.slot)
    if not sim_slot or sim_slot.name ~= pending.item_name or not sim_slot.metadata
        or sim_slot.metadata.sim_id ~= pending.sim.id then
        return { success = false, error = "sim_not_owned" }
    end
    local phone_matches = SkyPhone.FindDeviceSlots(source, phone_imei)
    if not phone_matches[1] then
        return { success = false, error = "phone_not_owned" }
    end
    local phone_slot = phone_matches[1]
    local prepared, prepare_error = prepare_device(source, phone_slot, phone_imei)
    if not prepared then
        return { success = false, error = prepare_error }
    end
    local device = SkyPhone.LoadDevice(phone_imei)
    local old_sim = device.sim_id and load_sim(device.sim_id) or nil
    if old_sim and not confirmed then
        return { success = false, error = "confirmation_required", data = { requiresConfirmation = true } }
    end

    operation_locks[source] = true
    if not set_phone_sim_metadata(source, phone_slot, pending.sim) then
        operation_locks[source] = nil
        return { success = false, error = "metadata_unsupported" }
    end
    if Bridge.Inventory.RemoveItem(source, pending.item_name, 1, pending.slot) ~= 1 then
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "sim_not_owned" }
    end
    local old_item_name = old_sim and (old_sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem) or nil
    if old_sim and not Bridge.Inventory.AddItem(source, old_item_name, 1, pending.slot, sim_metadata(old_sim)) then
        Bridge.Inventory.AddItem(source, pending.item_name, 1, pending.slot, sim_metadata(pending.sim))
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "inventory_full" }
    end

    local transaction = {
        {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = ? WHERE `imei` = ?",
            params = { pending.sim.id, phone_imei },
        },
    }
    if pending.sim.sim_type == "registered" and not pending.sim.owner_identifier then
        transaction[#transaction + 1] = {
            query = [[
                UPDATE `sky_phone_sims`
                SET `owner_identifier` = ?, `owner_firstname` = ?, `owner_lastname` = ?,
                    `owner_birthdate` = ?, `registered_at` = CURRENT_TIMESTAMP
                WHERE `id` = ? AND `owner_identifier` IS NULL
            ]],
            params = {
                Bridge.Framework.GetIdentifier(source),
                Bridge.Framework.GetFirstname(source),
                Bridge.Framework.GetLastname(source),
                Bridge.Framework.GetBirthdate(source),
                pending.sim.id,
            },
        }
    end
    if not Bridge.Database.Transaction(transaction) then
        if old_sim then
            Bridge.Inventory.RemoveItem(source, old_sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem, 1, pending.slot)
        end
        Bridge.Inventory.AddItem(source, pending.item_name, 1, pending.slot, sim_metadata(pending.sim))
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "request_failed" }
    end

    pending_insertions[source] = nil
    operation_locks[source] = nil
    if old_sim then
        SkyPhoneCompanies.ClearCallAvailability(source)
        SkyPhoneCalls.EndForSim(old_sim.id, "sim_removed")
    end
    SkyPhone.RefreshDevice(phone_imei)
    TriggerClientEvent("sky_phone:sim:picker-close", source)
    return { success = true }
end

local function use_sim(source, used_item)
    if Config.Sim.Enabled == false then
        return false
    end
    local item_name = used_item and used_item.name
    local sim_type = item_name and sim_types[item_name]
    if not sim_type then
        Bridge.Debug("warn", "[sky_phone] Usable SIM callback received an invalid item for source %s.", tostring(source))
        return false
    end
    if operation_locks[source] then
        TriggerClientEvent("sky_phone:device:error", source, "operation_in_progress")
        return false
    end
    operation_locks[source] = true
    local slot = resolve_used_sim(source, used_item, item_name)
    if not slot then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, "sim_slot_missing")
        return false
    end
    local sim, error_code = ensure_sim(source, slot, sim_type)
    if not sim then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false
    end
    local choices, choice_error = list_phone_choices(source)
    if #choices == 0 then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, choice_error or "phone_required")
        return false
    end
    pending_insertions[source] = {
        created_at = GetGameTimer(),
        item_name = item_name,
        sim = sim,
        slot = slot.slot,
    }
    operation_locks[source] = nil
    if #choices == 1 and not choices[1].occupied then
        return insert_sim(source, choices[1].imei, false).success
    end
    TriggerClientEvent("sky_phone:sim:picker", source, {
        choices = choices,
        number = sim.phone_number,
    })
    return true
end

-- Register the guarded callbacks in both modes so a resource-only restart can
-- replace registrations left behind in framework-owned usable-item tables.
local registered_sim_items = {}

local function register_configured_sim_items()
    for item_name in pairs(sim_types) do
        if not registered_sim_items[item_name] then
            local registered_item_name = item_name
            Bridge.Inventory.RegisterUsableItem(registered_item_name, function(...)
                if Config.Sim.Enabled ~= false and sim_types[registered_item_name] then
                    use_sim(...)
                end
            end)
            registered_sim_items[registered_item_name] = true
        end
    end
end

register_configured_sim_items()

Bridge.Callbacks.Register("sky_phone:sim:insert", function(source, data)
    if Config.Sim.Enabled == false then
        return { success = false, error = "disabled" }
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end
    return insert_sim(source, data.imei, data.confirmed == true)
end)

Bridge.Callbacks.Register("sky_phone:sim:picker-close", function(source)
    if operation_locks[source] then
        return { success = false, error = "operation_in_progress" }
    end
    pending_insertions[source] = nil
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:sim:eject", function(source)
    if Config.Sim.Enabled == false then
        return { success = false, error = "disabled" }
    end
    if operation_locks[source] then
        return { success = false, error = "operation_in_progress" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    local sim = device and device.sim_id and load_sim(device.sim_id) or nil
    if not sim or tonumber(sim.is_virtual) == 1 then
        return { success = false, error = "no_sim" }
    end
    local phone_slot = Bridge.Inventory.GetSlot(source, session.slot)
    local item_name = sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem
    local metadata = sim_metadata(sim)
    if not Bridge.Inventory.CanCarryItem(source, item_name, 1, metadata) then
        return { success = false, error = "inventory_full" }
    end

    operation_locks[source] = true
    if not set_phone_sim_metadata(source, phone_slot, nil) then
        operation_locks[source] = nil
        return { success = false, error = "metadata_unsupported" }
    end
    if not Bridge.Inventory.AddItem(source, item_name, 1, nil, metadata) then
        rollback_phone_metadata(source, phone_slot, sim)
        operation_locks[source] = nil
        return { success = false, error = "inventory_full" }
    end
    if affected_rows(Bridge.Database.Query("UPDATE `sky_phone_devices` SET `sim_id` = NULL WHERE `imei` = ? AND `sim_id` = ?", {
        session.imei,
        sim.id,
    })) ~= 1 then
        Bridge.Inventory.RemoveItem(source, item_name, 1, nil, metadata)
        rollback_phone_metadata(source, phone_slot, sim)
        operation_locks[source] = nil
        return { success = false, error = "request_failed" }
    end
    operation_locks[source] = nil
    SkyPhoneCompanies.ClearCallAvailability(source)
    SkyPhoneCalls.EndForSim(sim.id, "sim_removed")
    SkyPhone.RefreshDevice(session.imei)
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    pending_insertions[source] = nil
    operation_locks[source] = nil
end)

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    refresh_sim_types()
    register_configured_sim_items()
end)

if Config.Sim.Enabled ~= false then
    Bridge.Database.Query([[
        UPDATE `sky_phone_devices` d
        INNER JOIN `sky_phone_sims` s ON s.`id` = d.`sim_id`
        SET d.`sim_id` = NULL
        WHERE s.`is_virtual` = 1
    ]], {})
end
end)
